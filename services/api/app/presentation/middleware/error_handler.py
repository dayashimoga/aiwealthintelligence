"""Global exception handlers for the FastAPI application.

Catches AppException subclasses and unhandled exceptions,
returning structured JSON error responses with correct HTTP status codes.
"""

from __future__ import annotations

import uuid

import structlog
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.shared.exceptions import AppException

logger = structlog.get_logger(__name__)


def register_exception_handlers(app: FastAPI) -> None:
    """Register all exception handlers on the FastAPI application."""

    @app.exception_handler(AppException)
    async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
        """Handle application-level exceptions with structured error responses."""
        request_id = getattr(request.state, "request_id", "unknown")
        logger.warning(
            "app_exception",
            error_code=exc.error_code,
            status_code=exc.status_code,
            message=exc.message,
            request_id=request_id,
            path=str(request.url.path),
        )
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": exc.message,
                "error_code": exc.error_code,
                "details": exc.details,
                "request_id": request_id,
            },
        )

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        """Handle Pydantic validation errors with user-friendly messages."""
        errors = []
        for error in exc.errors():
            loc = " → ".join(str(l) for l in error["loc"] if l != "body")
            errors.append({"field": loc, "message": error["msg"], "type": error["type"]})

        return JSONResponse(
            status_code=422,
            content={
                "error": "Validation failed",
                "error_code": "VALIDATION_ERROR",
                "details": {"errors": errors},
            },
        )

    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(
        request: Request, exc: StarletteHTTPException
    ) -> JSONResponse:
        """Handle Starlette HTTP exceptions (404, 405, etc.)."""
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": exc.detail or "An error occurred",
                "error_code": f"HTTP_{exc.status_code}",
                "details": {},
            },
        )

    from slowapi.errors import RateLimitExceeded

    @app.exception_handler(RateLimitExceeded)
    async def rate_limit_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
        """Handle slowapi rate limit violations, returning a clean 429 response."""
        return JSONResponse(
            status_code=429,
            content={
                "error": "Rate limit exceeded. Please try again later.",
                "error_code": "RATE_LIMIT_EXCEEDED",
                "details": {"limit": getattr(exc, "detail", "Rate limit exceeded")},
            },
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
        """Catch-all for unhandled exceptions. Logs full traceback, returns safe response."""
        error_id = str(uuid.uuid4())
        logger.exception(
            "unhandled_exception",
            error_id=error_id,
            path=str(request.url.path),
            method=request.method,
            exc_type=type(exc).__name__,
        )
        return JSONResponse(
            status_code=500,
            content={
                "error": "An internal error occurred. Please try again later.",
                "error_code": "INTERNAL_ERROR",
                "details": {"error_id": error_id},
            },
        )
