"""WealthAI API - AI Wealth Intelligence Platform.

Production-grade FastAPI application with Clean Architecture.
"""

from __future__ import annotations

import contextlib
from collections.abc import AsyncIterator

import structlog
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.infrastructure.database.session import engine, sessionmanager
from app.presentation.api.v1.router import api_router
from app.presentation.middleware.rate_limiter import limiter
from app.presentation.middleware.security_headers import SecurityHeadersMiddleware
from app.shared.observability import setup_observability

logger = structlog.get_logger(__name__)


@contextlib.asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Application lifespan manager for startup/shutdown events."""
    settings = get_settings()
    logger.info("starting_application", env=settings.APP_ENV, debug=settings.APP_DEBUG)

    # Initialize database
    sessionmanager.init(settings.DATABASE_URL)
    logger.info("database_initialized")

    # Setup observability
    setup_observability(settings)
    logger.info("observability_initialized")

    yield

    # Shutdown
    if engine is not None:
        await sessionmanager.close()
        logger.info("database_connections_closed")

    logger.info("application_shutdown_complete")


def create_app() -> FastAPI:
    """Application factory pattern for creating the FastAPI app."""
    settings = get_settings()

    app = FastAPI(
        title="WealthAI API",
        description="AI Wealth Intelligence Platform - Your AI Financial Copilot",
        version="0.1.0",
        docs_url="/api/docs" if settings.APP_DEBUG else None,
        redoc_url="/api/redoc" if settings.APP_DEBUG else None,
        openapi_url="/api/openapi.json" if settings.APP_DEBUG else None,
        lifespan=lifespan,
    )

    # CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
        allow_credentials=settings.CORS_ALLOW_CREDENTIALS,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Security headers (OWASP)
    app.add_middleware(SecurityHeadersMiddleware)

    # Rate limiter
    app.state.limiter = limiter

    # API routes
    app.include_router(api_router, prefix="/api/v1")

    return app


app = create_app()
