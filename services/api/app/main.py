"""WealthAI API - AI Wealth Intelligence Platform.

Production-grade FastAPI application with Clean Architecture.
"""

from __future__ import annotations

import contextlib
from typing import TYPE_CHECKING

import structlog
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.infrastructure.database.session import engine, sessionmanager
from app.infrastructure.repositories.redis_cache import cache_repo
from app.infrastructure.scheduler.scheduler import shutdown_scheduler, start_scheduler
from app.presentation.api.v1.router import api_router
from app.presentation.api.v1.ws_market_routes import router as ws_router
from app.presentation.middleware.error_handler import register_exception_handlers
from app.presentation.middleware.rate_limiter import limiter
from app.presentation.middleware.security_headers import SecurityHeadersMiddleware
from app.shared.observability import setup_observability

if TYPE_CHECKING:
    from collections.abc import AsyncIterator

logger = structlog.get_logger(__name__)


@contextlib.asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Application lifespan manager for startup/shutdown events."""
    settings = get_settings()
    logger.info("starting_application", env=settings.APP_ENV, debug=settings.APP_DEBUG)

    # Initialize database
    sessionmanager.init(settings.DATABASE_URL)
    logger.info("database_initialized")

    # Initialize cache
    await cache_repo.connect()
    logger.info("cache_initialized")

    # Create tables if SQLite or development/testing
    if settings.is_sqlite or settings.APP_ENV in ("development", "testing"):
        await sessionmanager.create_all()
        logger.info("database_tables_created")

    # Setup background scheduler
    # Avoid starting scheduler during tests to prevent open event loop issues
    if settings.APP_ENV != "testing":
        start_scheduler()

    # Setup observability
    setup_observability(settings)
    logger.info("observability_initialized")

    yield

    # Shutdown
    if settings.APP_ENV != "testing":
        shutdown_scheduler()

    if engine is not None:
        await sessionmanager.close()
        logger.info("database_connections_closed")

    logger.info("application_shutdown_complete")


def create_app() -> FastAPI:
    """Application factory pattern for creating the FastAPI app."""
    settings = get_settings()

    app = FastAPI(
        title="WealthAI",
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

    # Exception handlers
    register_exception_handlers(app)

    # API routes (REST)
    app.include_router(api_router, prefix="/api/v1")

    # WebSocket routes (no /api/v1 prefix — uses clean ws:// URLs)
    app.include_router(ws_router)

    return app


app = create_app()
