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
