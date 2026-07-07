"""Copilot routes for Daily Brief, Scenario Simulator, and Portfolio Doctor."""

from __future__ import annotations

from datetime import UTC
from typing import Annotated

import structlog
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.ai.ai_copilot import (
    generate_daily_brief,
    generate_portfolio_doctor,
    simulate_scenario,
)
from app.infrastructure.ai.ai_provider import get_ai_provider
from app.infrastructure.database.session import get_db_session
from app.infrastructure.market.news_fetcher import fetch_rss_news
from app.infrastructure.repositories.sqlalchemy_repos import (
    SQLAlchemyHoldingRepository,
    SQLAlchemyPortfolioRepository,
)
from app.presentation.middleware.auth_dependency import get_current_user_id
from app.presentation.schemas.api_schemas import (
    DailyBriefResponse,
    PortfolioDoctorResponse,
    ScenarioMetrics,
    ScenarioSimulationRequest,
    ScenarioSimulationResponse,
)
from app.shared.exceptions import NotFoundError

logger = structlog.get_logger(__name__)
router = APIRouter()


@router.get("/brief/{portfolio_id}", response_model=DailyBriefResponse)
async def get_daily_brief(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> DailyBriefResponse:
    """Generate a daily AI brief summarizing news, sector performance, and portfolio status."""
    # Verify portfolio ownership
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    # Get holdings
    holding_repo = SQLAlchemyHoldingRepository(session)
    all_holdings = await holding_repo.list_by_portfolio(portfolio_id)

    # Fetch general market news articles
    news_articles = await fetch_rss_news(limit=5)

    # Format holdings for AI
    holdings_data = []
    for h in all_holdings:
        holdings_data.append(
            {
                "symbol": h.symbol,
                "name": h.name,
                "quantity": float(h.quantity),
                "current_price": float(h.current_price),
                "gain_loss_pct": float(h.gain_loss_percentage),
                "sector": h.sector,
                "asset_type": h.asset_type if isinstance(h.asset_type, str) else h.asset_type.value,
            }
        )

    provider = get_ai_provider()
    result = await generate_daily_brief(provider, holdings_data, news_articles)

    from datetime import datetime

    return DailyBriefResponse(
        summary=result.get("summary", ""),
        market_sentiment=result.get("market_sentiment", "neutral"),
        top_gainers=result.get("top_gainers", []),
        top_losers=result.get("top_losers", []),
        actionable_insights=result.get("actionable_insights", []),
        generated_at=datetime.now(UTC),
    )


@router.get("/portfolio-doctor/{portfolio_id}", response_model=PortfolioDoctorResponse)
async def get_portfolio_doctor(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> PortfolioDoctorResponse:
    """Diagnose portfolio issues and offer suggestions for rebalancing and optimization."""
    # Verify portfolio ownership
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    # Get holdings
    holding_repo = SQLAlchemyHoldingRepository(session)
    all_holdings = await holding_repo.list_by_portfolio(portfolio_id)

    holdings_data = []
    for h in all_holdings:
        holdings_data.append(
            {
                "symbol": h.symbol,
                "name": h.name,
                "quantity": float(h.quantity),
                "current_price": float(h.current_price),
                "gain_loss_pct": float(h.gain_loss_percentage),
                "sector": h.sector,
                "asset_type": h.asset_type if isinstance(h.asset_type, str) else h.asset_type.value,
            }
        )

    provider = get_ai_provider()
    result = await generate_portfolio_doctor(provider, holdings_data)

    return PortfolioDoctorResponse(
        health_score=result.get("health_score", 100),
        issues=result.get("issues", []),
        diversification_hhi=result.get("diversification_hhi", 0.0),
        sector_concentration_pct=result.get("sector_concentration_pct", 0.0),
        cash_drag_pct=result.get("cash_drag_pct", 0.0),
    )


@router.post("/scenario/{portfolio_id}", response_model=ScenarioSimulationResponse)
async def post_scenario_simulation(
    portfolio_id: str,
    request: ScenarioSimulationRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> ScenarioSimulationResponse:
    """Simulate changes to portfolio holdings and evaluate impact on metrics and diversification."""
    # Verify portfolio ownership
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    # Get holdings
    holding_repo = SQLAlchemyHoldingRepository(session)
    all_holdings = await holding_repo.list_by_portfolio(portfolio_id)

    holdings_data = []
    total_val = 0.0
    hhi = 0.0

    for h in all_holdings:
        h_val = float(h.quantity) * float(h.current_price)
        total_val += h_val
        holdings_data.append(
            {
                "symbol": h.symbol,
                "name": h.name,
                "quantity": float(h.quantity),
                "current_price": float(h.current_price),
                "gain_loss_pct": float(h.gain_loss_percentage),
                "sector": h.sector,
                "asset_type": h.asset_type if isinstance(h.asset_type, str) else h.asset_type.value,
            }
        )

    if total_val > 0:
        for h in all_holdings:
            h_val = float(h.quantity) * float(h.current_price)
            hhi += (h_val / total_val * 100) ** 2

    original_metrics = {
        "total_value": total_val,
        "xirr": None,
        "diversification_score": max(0.0, min(100.0, 100.0 - (hhi / 100.0))),
        "risk_score": 3.0,  # Default
    }

    # Format simulation actions
    actions_list = []
    for action in request.actions:
        actions_list.append(
            {
                "symbol": action.symbol,
                "action": action.action,
                "quantity": action.quantity,
                "price": action.price,
            }
        )

    provider = get_ai_provider()
    result = await simulate_scenario(provider, holdings_data, actions_list, original_metrics)

    orig_m = result.get("original_metrics", {})
    sim_m = result.get("simulated_metrics", {})

    return ScenarioSimulationResponse(
        original_metrics=ScenarioMetrics(
            total_value=orig_m.get("total_value", 0.0),
            xirr=orig_m.get("xirr"),
            diversification_score=orig_m.get("diversification_score", 0.0),
            risk_score=orig_m.get("risk_score", 0.0),
        ),
        simulated_metrics=ScenarioMetrics(
            total_value=sim_m.get("total_value", 0.0),
            xirr=sim_m.get("xirr"),
            diversification_score=sim_m.get("diversification_score", 0.0),
            risk_score=sim_m.get("risk_score", 0.0),
        ),
        impact_summary=result.get("impact_summary", ""),
        recommendations=result.get("recommendations", []),
    )
