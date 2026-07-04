"""AI provider abstraction layer.

Supports OpenAI, Groq, Ollama, and any OpenAI-compatible API.
Implements Strategy pattern for swappable AI backends.
"""

from __future__ import annotations

import json
from abc import ABC, abstractmethod
from typing import Any, AsyncIterator

import structlog
from openai import AsyncOpenAI

from app.config import get_settings
from app.shared.exceptions import AIProviderError

logger = structlog.get_logger(__name__)


class AIProvider(ABC):
    """Abstract interface for AI providers."""

    @abstractmethod
    async def complete(
        self,
        messages: list[dict[str, str]],
        model: str | None = None,
        temperature: float | None = None,
        max_tokens: int | None = None,
        response_format: dict[str, Any] | None = None,
    ) -> str:
        """Generate a completion from the AI model.

        Args:
            messages: Chat messages in OpenAI format.
            model: Optional model override.
            temperature: Optional temperature override.
            max_tokens: Optional max tokens override.
            response_format: Optional response format (e.g., JSON mode).

        Returns:
            Generated text response.
        """

    @abstractmethod
    async def stream(
        self,
        messages: list[dict[str, str]],
        model: str | None = None,
        temperature: float | None = None,
    ) -> AsyncIterator[str]:
        """Stream a completion from the AI model.

        Args:
            messages: Chat messages.
            model: Optional model override.
            temperature: Optional temperature override.

        Yields:
            Text chunks as they are generated.
        """

    @abstractmethod
    async def embed(self, text: str) -> list[float]:
        """Generate an embedding vector for text.

        Args:
            text: Text to embed.

        Returns:
            Embedding vector as list of floats.
        """


class OpenAICompatibleProvider(AIProvider):
    """Provider for OpenAI and OpenAI-compatible APIs (Groq, Together, etc.)."""

    def __init__(
        self,
        api_key: str,
        base_url: str | None = None,
        default_model: str = "gpt-4o-mini",
        embedding_model: str = "text-embedding-3-small",
    ) -> None:
        self._client = AsyncOpenAI(api_key=api_key, base_url=base_url)
        self._default_model = default_model
        self._embedding_model = embedding_model

    async def complete(
        self,
        messages: list[dict[str, str]],
        model: str | None = None,
        temperature: float | None = None,
        max_tokens: int | None = None,
        response_format: dict[str, Any] | None = None,
    ) -> str:
        settings = get_settings()
        try:
            kwargs: dict[str, Any] = {
                "model": model or self._default_model,
                "messages": messages,
                "temperature": temperature if temperature is not None else settings.AI_TEMPERATURE,
                "max_tokens": max_tokens or settings.AI_MAX_TOKENS,
            }
            if response_format:
                kwargs["response_format"] = response_format

            response = await self._client.chat.completions.create(**kwargs)
            content = response.choices[0].message.content
            return content or ""

        except Exception as e:
            logger.error("ai_completion_failed", error=str(e))
            raise AIProviderError(f"AI completion failed: {e}") from e

    async def stream(
        self,
        messages: list[dict[str, str]],
        model: str | None = None,
        temperature: float | None = None,
    ) -> AsyncIterator[str]:
        settings = get_settings()
        try:
            stream = await self._client.chat.completions.create(
                model=model or self._default_model,
                messages=messages,
                temperature=temperature if temperature is not None else settings.AI_TEMPERATURE,
                stream=True,
            )
            async for chunk in stream:
                if chunk.choices and chunk.choices[0].delta.content:
                    yield chunk.choices[0].delta.content

        except Exception as e:
            logger.error("ai_stream_failed", error=str(e))
            raise AIProviderError(f"AI streaming failed: {e}") from e

    async def embed(self, text: str) -> list[float]:
        try:
            response = await self._client.embeddings.create(
                model=self._embedding_model,
                input=text,
            )
            return response.data[0].embedding

        except Exception as e:
            logger.error("ai_embedding_failed", error=str(e))
            raise AIProviderError(f"AI embedding failed: {e}") from e


class OllamaProvider(AIProvider):
    """Provider for local Ollama models."""

    def __init__(
        self,
        base_url: str = "http://localhost:11434",
        default_model: str = "llama3.1",
    ) -> None:
        self._client = AsyncOpenAI(
            api_key="ollama",
            base_url=f"{base_url}/v1",
        )
        self._default_model = default_model

    async def complete(
        self,
        messages: list[dict[str, str]],
        model: str | None = None,
        temperature: float | None = None,
        max_tokens: int | None = None,
        response_format: dict[str, Any] | None = None,
    ) -> str:
        try:
            kwargs: dict[str, Any] = {
                "model": model or self._default_model,
                "messages": messages,
                "temperature": temperature or 0.3,
                "max_tokens": max_tokens or 4096,
            }
            if response_format:
                kwargs["response_format"] = response_format

            response = await self._client.chat.completions.create(**kwargs)
            content = response.choices[0].message.content
            return content or ""

        except Exception as e:
            logger.error("ollama_completion_failed", error=str(e))
            raise AIProviderError(f"Ollama completion failed: {e}") from e

    async def stream(
        self,
        messages: list[dict[str, str]],
        model: str | None = None,
        temperature: float | None = None,
    ) -> AsyncIterator[str]:
        try:
            stream = await self._client.chat.completions.create(
                model=model or self._default_model,
                messages=messages,
                temperature=temperature or 0.3,
                stream=True,
            )
            async for chunk in stream:
                if chunk.choices and chunk.choices[0].delta.content:
                    yield chunk.choices[0].delta.content

        except Exception as e:
            logger.error("ollama_stream_failed", error=str(e))
            raise AIProviderError(f"Ollama streaming failed: {e}") from e

    async def embed(self, text: str) -> list[float]:
        try:
            response = await self._client.embeddings.create(
                model="nomic-embed-text",
                input=text,
            )
            return response.data[0].embedding

        except Exception as e:
            logger.error("ollama_embedding_failed", error=str(e))
            raise AIProviderError(f"Ollama embedding failed: {e}") from e


def get_ai_provider() -> AIProvider:
    """Factory function to get the configured AI provider.

    Returns:
        Configured AI provider instance based on settings.
    """
    settings = get_settings()

    if settings.AI_PROVIDER == "ollama":
        return OllamaProvider(
            base_url=settings.OLLAMA_BASE_URL,
            default_model=settings.OLLAMA_MODEL,
        )

    # Default: OpenAI-compatible (works for OpenAI, Groq, Together, etc.)
    base_url = None
    if settings.AI_PROVIDER == "groq":
        base_url = "https://api.groq.com/openai/v1"

    return OpenAICompatibleProvider(
        api_key=settings.AI_API_KEY,
        base_url=base_url,
        default_model=settings.AI_MODEL,
        embedding_model=settings.AI_EMBEDDING_MODEL,
    )


# ============================================================
# Recommendation Engine
# ============================================================


RECOMMENDATION_SYSTEM_PROMPT = """You are an expert financial analyst AI for the WealthAI platform.
You analyze investment holdings and provide detailed, actionable recommendations.

For each holding, you must provide:
1. Action: One of [strong_buy, buy, hold, reduce, sell, exit]
2. Confidence: 0-100 score
3. Detailed reasoning with evidence
4. Expected return range
5. Risk assessment
6. Investment horizon
7. Alternative suggestions

Your explainability analysis must cover:
- Fundamentals: Revenue, earnings, margins, debt, growth
- Technical indicators: Moving averages, RSI, support/resistance
- News sentiment: Recent news impact
- Macroeconomics: Interest rates, inflation, GDP impact
- Valuation: P/E, P/B, PEG, DCF assessment
- Sector outlook: Industry trends and competitive landscape
- Institutional activity: FII/DII flows, mutual fund holdings
- Insider activity: Promoter buying/selling patterns
- Market sentiment: Overall market conditions

Always provide honest, balanced analysis. Acknowledge uncertainty.
Never guarantee returns. Always mention risks.
Respond in valid JSON format."""

RECOMMENDATION_USER_TEMPLATE = """Analyze this holding and provide a recommendation:

Symbol: {symbol}
Name: {name}
Asset Type: {asset_type}
Exchange: {exchange}
Sector: {sector}
Industry: {industry}
Quantity: {quantity}
Average Buy Price: ₹{avg_price}
Current Price: ₹{current_price}
Gain/Loss: {gain_loss_pct}%
Holding Period: {holding_period}

Portfolio Context:
- Total Holdings: {total_holdings}
- This holding is {weight}% of portfolio
- Sector concentration: {sector_concentration}

Provide your analysis as a JSON object with these keys:
action, confidence, reasoning, evidence (array), expected_return, risk_level,
investment_horizon, alternative_suggestions (array), explainability (object with keys:
fundamentals, technical_indicators, news_sentiment, macroeconomics, valuation,
sector_outlook, institutional_activity, insider_activity, market_sentiment, overall_summary)"""


async def generate_recommendation(
    provider: AIProvider,
    holding_data: dict[str, Any],
    portfolio_context: dict[str, Any],
) -> dict[str, Any]:
    """Generate an AI recommendation for a holding.

    Args:
        provider: AI provider to use.
        holding_data: Holding information.
        portfolio_context: Portfolio-level context.

    Returns:
        Recommendation data dictionary.
    """
    user_message = RECOMMENDATION_USER_TEMPLATE.format(
        symbol=holding_data.get("symbol", ""),
        name=holding_data.get("name", ""),
        asset_type=holding_data.get("asset_type", "stock"),
        exchange=holding_data.get("exchange", "NSE"),
        sector=holding_data.get("sector", "Unknown"),
        industry=holding_data.get("industry", "Unknown"),
        quantity=holding_data.get("quantity", 0),
        avg_price=holding_data.get("average_buy_price", 0),
        current_price=holding_data.get("current_price", 0),
        gain_loss_pct=holding_data.get("gain_loss_pct", 0),
        holding_period=holding_data.get("holding_period", "Unknown"),
        total_holdings=portfolio_context.get("total_holdings", 0),
        weight=portfolio_context.get("weight", 0),
        sector_concentration=portfolio_context.get("sector_concentration", "N/A"),
    )

    messages = [
        {"role": "system", "content": RECOMMENDATION_SYSTEM_PROMPT},
        {"role": "user", "content": user_message},
    ]

    response = await provider.complete(
        messages=messages,
        response_format={"type": "json_object"},
    )

    try:
        result = json.loads(response)
    except json.JSONDecodeError:
        logger.error("ai_recommendation_json_parse_failed", response=response[:500])
        result = {
            "action": "hold",
            "confidence": 50,
            "reasoning": response,
            "evidence": [],
            "expected_return": 0,
            "risk_level": "moderate",
            "investment_horizon": "6-12 months",
            "alternative_suggestions": [],
            "explainability": {},
        }

    return result


# ============================================================
# Chat Engine
# ============================================================


CHAT_SYSTEM_PROMPT = """You are WealthAI, an intelligent financial copilot.
You help users understand their investments, make better financial decisions,
and manage their portfolios effectively.

You have access to the user's portfolio data. Be conversational, helpful,
and provide actionable insights. Always be honest about limitations and risks.

When discussing specific investments:
- Provide balanced analysis
- Mention both risks and opportunities
- Never guarantee returns
- Suggest consulting a financial advisor for major decisions

Respond naturally in conversation. Use data to support your points.
Format currency in INR (₹) by default."""


async def chat_with_portfolio(
    provider: AIProvider,
    user_message: str,
    portfolio_summary: str,
    conversation_history: list[dict[str, str]] | None = None,
) -> dict[str, Any]:
    """Handle natural language portfolio chat.

    Args:
        provider: AI provider to use.
        user_message: User's question/message.
        portfolio_summary: Summary of user's portfolio for context.
        conversation_history: Optional prior conversation messages.

    Returns:
        Chat response with message and metadata.
    """
    messages = [
        {"role": "system", "content": CHAT_SYSTEM_PROMPT},
        {
            "role": "system",
            "content": f"User's Portfolio Summary:\n{portfolio_summary}",
        },
    ]

    if conversation_history:
        messages.extend(conversation_history[-10:])  # Keep last 10 messages

    messages.append({"role": "user", "content": user_message})

    response = await provider.complete(messages=messages)

    return {
        "message": response,
        "suggestions": [
            "Show me my top performers",
            "What should I rebalance?",
            "Analyze my sector exposure",
        ],
        "referenced_holdings": [],
        "confidence": 0.85,
    }
