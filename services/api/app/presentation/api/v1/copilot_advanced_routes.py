"""Advanced Wealth Intelligence copilot routes."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.analytics.advanced_analytics import AdvancedAnalyticsEngine
from app.infrastructure.database.session import get_db_session
from app.infrastructure.repositories.sqlalchemy_repos import (
    SQLAlchemyHoldingRepository,
    SQLAlchemyPortfolioRepository,
)
from app.presentation.middleware.auth_dependency import get_current_user_id
from app.presentation.schemas.api_schemas import AdvancedAnalysisResponse
from app.shared.exceptions import NotFoundError

router = APIRouter()


@router.get("/advanced/{portfolio_id}", response_model=AdvancedAnalysisResponse)
async def get_advanced_analysis(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> AdvancedAnalysisResponse:
    """Computes advanced stress testing, tax harvesting offsets, behavioral biases, and goal progressions."""
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    holding_repo = SQLAlchemyHoldingRepository(session)
    holdings = await holding_repo.list_by_portfolio(portfolio_id)

    engine = AdvancedAnalyticsEngine()
    result = engine.calculate_advanced_metrics(portfolio_id, holdings)

    return AdvancedAnalysisResponse(**result)


@router.get("/sector-rotation/{portfolio_id}")
async def get_sector_rotation(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> dict:
    """Analyze sector allocation and suggest rotation opportunities."""
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    holding_repo = SQLAlchemyHoldingRepository(session)
    holdings = await holding_repo.list_by_portfolio(portfolio_id)

    engine = AdvancedAnalyticsEngine()
    suggestions = engine.analyze_sector_rotation(holdings)

    return {
        "portfolio_id": portfolio_id,
        "sector_rotation": suggestions,
    }


@router.get("/dividend-planner/{portfolio_id}")
async def get_dividend_planner(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> dict:
    """Analyze dividend income potential and plan dividend portfolio strategy."""
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    holding_repo = SQLAlchemyHoldingRepository(session)
    holdings = await holding_repo.list_by_portfolio(portfolio_id)

    engine = AdvancedAnalyticsEngine()
    plan = engine.calculate_dividend_plan(holdings)

    return {
        "portfolio_id": portfolio_id,
        **plan,
    }


@router.get("/opportunity-radar/{portfolio_id}")
async def get_opportunity_radar(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> dict:
    """Identify investment opportunities based on portfolio gaps and market conditions."""
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    holding_repo = SQLAlchemyHoldingRepository(session)
    holdings = await holding_repo.list_by_portfolio(portfolio_id)

    engine = AdvancedAnalyticsEngine()
    opportunities = engine.find_opportunity_radar(holdings)

    return {
        "portfolio_id": portfolio_id,
        "opportunities": opportunities,
    }
