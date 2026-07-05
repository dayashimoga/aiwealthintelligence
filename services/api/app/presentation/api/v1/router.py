"""API v1 router aggregating all route modules."""

from __future__ import annotations

from fastapi import APIRouter

from app.presentation.api.v1 import auth_routes, health_routes, portfolio_routes, ai_routes, market_routes, copilot_routes, consent_routes, copilot_advanced_routes

api_router = APIRouter()

api_router.include_router(health_routes.router, tags=["Health"])
api_router.include_router(auth_routes.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(portfolio_routes.router, prefix="/portfolios", tags=["Portfolios"])
api_router.include_router(consent_routes.router, prefix="/portfolios", tags=["Portfolios"])
api_router.include_router(ai_routes.router, prefix="/ai", tags=["AI"])
api_router.include_router(market_routes.router, prefix="/market", tags=["Market"])
api_router.include_router(copilot_routes.router, prefix="/copilot", tags=["Copilot"])
api_router.include_router(copilot_advanced_routes.router, prefix="/copilot", tags=["Copilot"])

