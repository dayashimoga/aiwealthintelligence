"""API v1 router aggregating all route modules."""

from __future__ import annotations

from fastapi import APIRouter

from app.presentation.api.v1 import (
    ai_routes,
    auth_routes,
    consent_routes,
    copilot_advanced_routes,
    copilot_routes,
    goal_routes,
    health_routes,
    import_routes,
    market_routes,
    notification_routes,
    portfolio_routes,
    watchlist_routes,
)

api_router = APIRouter()

api_router.include_router(health_routes.router, tags=["Health"])
api_router.include_router(auth_routes.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(portfolio_routes.router, prefix="/portfolios", tags=["Portfolios"])
api_router.include_router(consent_routes.router, prefix="/portfolios", tags=["Portfolios"])
api_router.include_router(import_routes.router, tags=["Import"])
api_router.include_router(ai_routes.router, prefix="/ai", tags=["AI"])
api_router.include_router(market_routes.router, prefix="/market", tags=["Market"])
api_router.include_router(copilot_routes.router, prefix="/copilot", tags=["Copilot"])
api_router.include_router(copilot_advanced_routes.router, prefix="/copilot", tags=["Copilot"])
api_router.include_router(notification_routes.router, tags=["Notifications"])
api_router.include_router(goal_routes.router, tags=["Goals"])
api_router.include_router(watchlist_routes.router, tags=["Watchlist"])
