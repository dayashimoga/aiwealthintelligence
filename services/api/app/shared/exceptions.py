"""Custom exception classes for the application.

Provides structured error handling with HTTP status codes and error codes.
"""

from __future__ import annotations

from typing import Any


class AppException(Exception):
    """Base exception for all application errors."""

    def __init__(
        self,
        message: str,
        status_code: int = 500,
        error_code: str = "INTERNAL_ERROR",
        details: dict[str, Any] | None = None,
    ) -> None:
        self.message = message
        self.status_code = status_code
        self.error_code = error_code
        self.details = details or {}
        super().__init__(self.message)


class AuthenticationError(AppException):
    """Raised for authentication failures."""

    def __init__(self, message: str = "Authentication failed") -> None:
        super().__init__(
            message=message,
            status_code=401,
            error_code="AUTHENTICATION_ERROR",
        )


class AuthorizationError(AppException):
    """Raised for authorization/permission failures."""

    def __init__(self, message: str = "Insufficient permissions") -> None:
        super().__init__(
            message=message,
            status_code=403,
            error_code="AUTHORIZATION_ERROR",
        )


class NotFoundError(AppException):
    """Raised when a requested resource is not found."""

    def __init__(self, resource: str, resource_id: str = "") -> None:
        detail = f"{resource} not found"
        if resource_id:
            detail = f"{resource} with ID '{resource_id}' not found"
        super().__init__(
            message=detail,
            status_code=404,
            error_code="NOT_FOUND",
            details={"resource": resource, "id": resource_id},
        )


class ValidationError(AppException):
    """Raised for business logic validation failures."""

    def __init__(self, message: str, details: dict[str, Any] | None = None) -> None:
        super().__init__(
            message=message,
            status_code=422,
            error_code="VALIDATION_ERROR",
            details=details or {},
        )


class ConflictError(AppException):
    """Raised when a resource already exists."""

    def __init__(self, message: str = "Resource already exists") -> None:
        super().__init__(
            message=message,
            status_code=409,
            error_code="CONFLICT",
        )


class RateLimitError(AppException):
    """Raised when rate limit is exceeded."""

    def __init__(self, message: str = "Rate limit exceeded") -> None:
        super().__init__(
            message=message,
            status_code=429,
            error_code="RATE_LIMIT_EXCEEDED",
        )


class AIProviderError(AppException):
    """Raised when AI provider encounters an error."""

    def __init__(self, message: str = "AI service unavailable") -> None:
        super().__init__(
            message=message,
            status_code=503,
            error_code="AI_PROVIDER_ERROR",
        )
