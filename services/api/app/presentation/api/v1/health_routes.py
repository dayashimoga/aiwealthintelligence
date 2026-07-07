"""Health check endpoint for infrastructure monitoring."""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter

from app.presentation.schemas.api_schemas import HealthResponse

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    """Health check endpoint for load balancers and monitoring.

    Returns basic application health status, version, and environment.
    This endpoint is unauthenticated for infrastructure probe access.
    """
    from app.config import get_settings

    settings = get_settings()
    return HealthResponse(
        status="healthy",
        version="0.1.0",
        environment=settings.APP_ENV,
        timestamp=datetime.now(UTC),
    )
