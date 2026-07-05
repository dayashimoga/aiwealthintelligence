"""AI routes for recommendations and natural language chat."""

from __future__ import annotations

from typing import Annotated, Any

import structlog
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.ai.ai_provider import (
    chat_with_portfolio,
    generate_recommendation,
    get_ai_provider,
)
from app.infrastructure.database.session import get_db_session
from app.infrastructure.repositories.sqlalchemy_repos import (
    SQLAlchemyHoldingRepository,
    SQLAlchemyPortfolioRepository,
)
from app.presentation.middleware.auth_dependency import get_current_user_id
from app.presentation.schemas.api_schemas import (
    AIChatRequest,
    AIChatResponse,
    AIRecommendationResponse,
)
from app.shared.exceptions import NotFoundError

logger = structlog.get_logger(__name__)
router = APIRouter()


@router.get("/recommendations/{portfolio_id}/{holding_id}", response_model=AIRecommendationResponse)
async def get_recommendation(
    portfolio_id: str,
    holding_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> AIRecommendationResponse:
    """Generate an AI recommendation for a specific holding.

    Analyzes the holding using fundamentals, technicals, news, macro factors,
    and portfolio context to generate an actionable recommendation.
    """
    # Verify portfolio ownership
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    # Get holding
    holding_repo = SQLAlchemyHoldingRepository(session)
    holding = await holding_repo.get_by_id(holding_id, portfolio_id)
    if holding is None:
        raise NotFoundError("Holding", holding_id)

    # Get all holdings for context
    all_holdings = await holding_repo.list_by_portfolio(portfolio_id)
    total_value = sum(float(h.current_value) for h in all_holdings)
    holding_weight = (float(holding.current_value) / total_value * 100) if total_value > 0 else 0

    # Count sector concentration
    sector_count = sum(1 for h in all_holdings if h.sector == holding.sector)
    sector_concentration = f"{sector_count} of {len(all_holdings)} holdings in {holding.sector or 'Unknown'}"

    holding_data: dict[str, Any] = {
        "symbol": holding.symbol,
        "name": holding.name,
        "asset_type": holding.asset_type if isinstance(holding.asset_type, str) else holding.asset_type.value,
        "exchange": holding.exchange if isinstance(holding.exchange, str) else holding.exchange.value,
        "sector": holding.sector,
        "industry": holding.industry,
        "quantity": float(holding.quantity),
        "average_buy_price": float(holding.average_buy_price),
        "current_price": float(holding.current_price),
        "gain_loss_pct": float(holding.gain_loss_percentage),
        "holding_period": "Calculating...",
    }

    portfolio_context: dict[str, Any] = {
        "total_holdings": len(all_holdings),
        "weight": round(holding_weight, 1),
        "sector_concentration": sector_concentration,
    }

    # Generate recommendation
    provider = get_ai_provider()
    result = await generate_recommendation(provider, holding_data, portfolio_context)

    from datetime import datetime, timezone

    return AIRecommendationResponse(
        id=holding_id,
        holding_id=holding_id,
        symbol=holding.symbol,
        action=result.get("action", "hold"),
        confidence=float(result.get("confidence", 50)),
        reasoning=result.get("reasoning", ""),
        evidence=result.get("evidence", []),
        expected_return=float(result.get("expected_return", 0)),
        risk_level=result.get("risk_level", "moderate"),
        risk_description=result.get("risk_description", "No detailed risk analysis compiled."),
        investment_horizon=result.get("investment_horizon", "6-12 months"),
        alternative_suggestions=result.get("alternative_suggestions", []),
        explainability=result.get("explainability", {}),
        generated_at=datetime.now(timezone.utc),
    )


@router.post("/chat", response_model=AIChatResponse)
async def ai_chat(
    request: AIChatRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> AIChatResponse:
    """Natural language chat with AI financial copilot.

    The AI has context about the user's portfolio and can answer questions,
    provide insights, and suggest actions.
    """
    portfolio_summary = "No portfolio selected."

    if request.portfolio_id:
        portfolio_repo = SQLAlchemyPortfolioRepository(session)
        portfolio = await portfolio_repo.get_by_id(request.portfolio_id, user_id)

        if portfolio:
            holding_repo = SQLAlchemyHoldingRepository(session)
            holdings = await holding_repo.list_by_portfolio(request.portfolio_id)

            total_invested = sum(float(h.invested_value) for h in holdings)
            total_current = sum(float(h.current_value) for h in holdings)

            lines = [
                f"Portfolio: {portfolio.name}",
                f"Total Holdings: {len(holdings)}",
                f"Total Invested: ₹{total_invested:,.2f}",
                f"Current Value: ₹{total_current:,.2f}",
                f"Gain/Loss: ₹{total_current - total_invested:,.2f}",
                "",
                "Holdings:",
            ]
            for h in holdings[:20]:  # Limit to 20 for context window
                lines.append(
                    f"- {h.symbol} ({h.name}): {float(h.quantity)} units @ ₹{float(h.average_buy_price):,.2f}, "
                    f"current ₹{float(h.current_price):,.2f}, "
                    f"gain/loss {float(h.gain_loss_percentage):.1f}%"
                )

            portfolio_summary = "\n".join(lines)

    provider = get_ai_provider()
    result = await chat_with_portfolio(
        provider=provider,
        user_message=request.message,
        portfolio_summary=portfolio_summary,
    )

    return AIChatResponse(
        message=result["message"],
        suggestions=result.get("suggestions", []),
        referenced_holdings=result.get("referenced_holdings", []),
        confidence=result.get("confidence", 0.85),
    )
