"""Authentication routes for user registration, login, and token management."""

from __future__ import annotations

from typing import Annotated

import structlog
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.domain.entities import User
from app.infrastructure.database.session import get_db_session
from app.infrastructure.repositories.sqlalchemy_repos import SQLAlchemyUserRepository
from app.presentation.middleware.auth_dependency import get_current_user
from app.presentation.schemas.api_schemas import (
    ErrorResponse,
    LoginRequest,
    RefreshTokenRequest,
    RegisterRequest,
    TokenResponse,
    UserResponse,
)
from app.shared.exceptions import AuthenticationError, ConflictError, ValidationError
from app.shared.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    validate_password_strength,
    verify_password,
)

logger = structlog.get_logger(__name__)
router = APIRouter()


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=201,
    responses={409: {"model": ErrorResponse}, 422: {"model": ErrorResponse}},
)
async def register(
    request: RegisterRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> TokenResponse:
    """Register a new user account.

    Creates a user with email/password authentication and returns JWT tokens.
    Password must meet OWASP strength requirements.
    """
    # Validate password strength
    password_errors = validate_password_strength(request.password)
    if password_errors:
        raise ValidationError(
            message="Password does not meet requirements",
            details={"errors": password_errors},
        )

    repo = SQLAlchemyUserRepository(session)

    # Check if user already exists
    existing = await repo.get_by_email(request.email)
    if existing:
        raise ConflictError("A user with this email already exists")

    # Create user
    user = User(
        email=request.email,
        hashed_password=hash_password(request.password),
        full_name=request.full_name,
    )
    created_user = await repo.create(user)
    await session.commit()

    logger.info("user_registered", user_id=created_user.id, email=created_user.email)

    # Generate tokens
    settings = get_settings()
    access_token = create_access_token(
        user_id=created_user.id,
        email=created_user.email,
        role=created_user.role.value if hasattr(created_user.role, "value") else created_user.role,
    )
    refresh_token = create_refresh_token(user_id=created_user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post(
    "/login",
    response_model=TokenResponse,
    responses={401: {"model": ErrorResponse}},
)
async def login(
    request: LoginRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> TokenResponse:
    """Authenticate user with email and password.

    Returns JWT access and refresh tokens on successful authentication.
    """
    repo = SQLAlchemyUserRepository(session)

    # Find user
    user = await repo.get_by_email(request.email)
    if user is None:
        raise AuthenticationError("Invalid email or password")

    # Verify password
    if not verify_password(request.password, user.hashed_password):
        logger.warning("failed_login_attempt", email=request.email)
        raise AuthenticationError("Invalid email or password")

    # Update last login
    user.update_last_login()
    await repo.update(user)
    await session.commit()

    logger.info("user_logged_in", user_id=user.id)

    # Generate tokens
    settings = get_settings()
    role = user.role.value if hasattr(user.role, "value") else user.role
    access_token = create_access_token(
        user_id=user.id,
        email=user.email,
        role=role,
    )
    refresh_token = create_refresh_token(user_id=user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post(
    "/refresh",
    response_model=TokenResponse,
    responses={401: {"model": ErrorResponse}},
)
async def refresh_token(
    request: RefreshTokenRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> TokenResponse:
    """Refresh JWT access token using a valid refresh token."""
    payload = decode_token(request.refresh_token)

    if payload is None or payload.get("type") != "refresh":
        raise AuthenticationError("Invalid refresh token")

    user_id = payload.get("sub")
    if not user_id:
        raise AuthenticationError("Invalid refresh token")

    repo = SQLAlchemyUserRepository(session)
    user = await repo.get_by_id(user_id)

    if user is None or not user.is_active:
        raise AuthenticationError("User not found or inactive")

    settings = get_settings()
    role = user.role.value if hasattr(user.role, "value") else user.role
    access_token = create_access_token(
        user_id=user.id,
        email=user.email,
        role=role,
    )
    new_refresh_token = create_refresh_token(user_id=user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=new_refresh_token,
        expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.get(
    "/me",
    response_model=UserResponse,
    responses={401: {"model": ErrorResponse}},
)
async def get_profile(
    current_user: Annotated[dict, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> UserResponse:
    """Get the current user's profile."""
    repo = SQLAlchemyUserRepository(session)
    user = await repo.get_by_id(current_user["id"])
    if user is None:
        raise AuthenticationError("User not found")

    return UserResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        role=user.role.value if hasattr(user.role, "value") else user.role,
        is_verified=user.is_verified,
        avatar_url=user.avatar_url,
        created_at=user.created_at,
    )
