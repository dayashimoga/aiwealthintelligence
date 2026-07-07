"""Tests for AIProvider implementations and helper functions."""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.infrastructure.ai.ai_provider import (
    AIProviderError,
    OpenAICompatibleProvider,
    chat_with_portfolio,
    generate_recommendation,
    get_ai_provider,
)


@pytest.mark.asyncio
async def test_openai_compatible_provider_complete() -> None:
    """OpenAICompatibleProvider.complete calls openai client and returns text."""
    mock_client = MagicMock()
    mock_choice = MagicMock()
    mock_choice.message.content = "AI response text"
    mock_response = MagicMock()
    mock_response.choices = [mock_choice]

    mock_client.chat.completions.create = AsyncMock(return_value=mock_response)

    with patch("app.infrastructure.ai.ai_provider.AsyncOpenAI", return_value=mock_client):
        provider = OpenAICompatibleProvider(api_key="fake-key", default_model="gpt-4o-mini")
        result = await provider.complete([{"role": "user", "content": "hello"}])

        assert result == "AI response text"
        mock_client.chat.completions.create.assert_called_once()


@pytest.mark.asyncio
async def test_openai_compatible_provider_complete_error() -> None:
    """OpenAICompatibleProvider raises AIProviderError on connection/API exceptions."""
    mock_client = MagicMock()
    mock_client.chat.completions.create = AsyncMock(side_effect=Exception("API limit exceeded"))

    with patch("app.infrastructure.ai.ai_provider.AsyncOpenAI", return_value=mock_client):
        provider = OpenAICompatibleProvider(api_key="fake-key")
        with pytest.raises(AIProviderError, match="AI completion failed: API limit exceeded"):
            await provider.complete([{"role": "user", "content": "hello"}])


@pytest.mark.asyncio
async def test_openai_compatible_provider_stream() -> None:
    """OpenAICompatibleProvider.stream streams text response chunks."""
    mock_client = MagicMock()

    # Create chunks for async iteration
    chunk1 = MagicMock()
    chunk1.choices = [MagicMock()]
    chunk1.choices[0].delta.content = "hello "

    chunk2 = MagicMock()
    chunk2.choices = [MagicMock()]
    chunk2.choices[0].delta.content = "world"

    async def async_iter():
        yield chunk1
        yield chunk2

    mock_client.chat.completions.create = AsyncMock(return_value=async_iter())

    with patch("app.infrastructure.ai.ai_provider.AsyncOpenAI", return_value=mock_client):
        provider = OpenAICompatibleProvider(api_key="fake-key")
        chunks = []
        async for chunk in provider.stream([{"role": "user", "content": "hello"}]):
            chunks.append(chunk)

        assert "".join(chunks) == "hello world"


@pytest.mark.asyncio
async def test_openai_compatible_provider_embed() -> None:
    """OpenAICompatibleProvider.embed returns embedding list of floats."""
    mock_client = MagicMock()
    mock_embedding = MagicMock()
    mock_embedding.embedding = [0.1, 0.2, 0.3]
    mock_response = MagicMock()
    mock_response.data = [mock_embedding]

    mock_client.embeddings.create = AsyncMock(return_value=mock_response)

    with patch("app.infrastructure.ai.ai_provider.AsyncOpenAI", return_value=mock_client):
        provider = OpenAICompatibleProvider(api_key="fake-key")
        vector = await provider.embed("some text")
        assert vector == [0.1, 0.2, 0.3]


@pytest.mark.asyncio
async def test_get_ai_provider_factory() -> None:
    """get_ai_provider retrieves settings and instantiates provider."""
    with patch("app.infrastructure.ai.ai_provider.get_settings") as mock_settings:
        mock_settings.return_value.AI_PROVIDER = "groq"
        mock_settings.return_value.AI_API_KEY = "groq-key"
        mock_settings.return_value.AI_MODEL = "llama3"
        mock_settings.return_value.AI_EMBEDDING_MODEL = "text-embedding-3"

        provider = get_ai_provider()
        assert isinstance(provider, OpenAICompatibleProvider)
        assert provider._default_model == "llama3"


@pytest.mark.asyncio
async def test_generate_recommendation_handles_json_parse_error() -> None:
    """generate_recommendation returns generic fallback dictionary on malformed JSON response."""
    mock_provider = AsyncMock()
    mock_provider.complete.return_value = "invalid-json-string"

    holding_data = {
        "symbol": "INFY",
        "name": "Infosys",
        "asset_type": "stock",
        "quantity": 10,
        "average_buy_price": 1400.0,
    }
    context = {"total_holdings": 1, "weight": 100.0, "sector_concentration": "100% IT"}

    res = await generate_recommendation(mock_provider, holding_data, context)
    assert res["action"] == "hold"
    assert res["reasoning"] == "invalid-json-string"


@pytest.mark.asyncio
async def test_chat_with_portfolio() -> None:
    """chat_with_portfolio formats prompt and returns assistant response with suggestions."""
    mock_provider = AsyncMock()
    mock_provider.complete.return_value = "Your portfolio looks very strong!"

    res = await chat_with_portfolio(mock_provider, "analyze my portfolio", "TCS: 10 shares")
    assert "Your portfolio looks very strong!" in res["message"]
    assert "Show me my top performers" in res["suggestions"]
