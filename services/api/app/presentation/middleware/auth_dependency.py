"""Authentication dependency for FastAPI routes.

Provides JWT token validation and user extraction for protected endpoints.
Implements RBAC (Role-Based Access Control).
"""

from __future__ import annotations

from typing import Annotated

import structlog
from fastapi import Depends, Header
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.database.session import get_db_session
from app.infrastructure.repositories.sqlalchemy_repos import SQLAlchemyUserRepository
from app.shared.exceptions import AuthenticationError, AuthorizationError
from app.shared.security import decode_token

logger = structlog.get_logger(__name__)


async def get_current_user_id(
    authorization: Annotated[str | None, Header()] = None,
) -> str:
    """Extract and validate user ID from JWT Bearer token.

    Args:
        authorization: Authorization header value (Bearer <token>).

    Returns:
        User ID from the token.

    Raises:
        AuthenticationError: If token is missing, invalid, or expired.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise AuthenticationError("Missing or invalid authorization header")

    token = authorization.split(" ", 1)[1]
    payload = decode_token(token)

    if payload is None:
        raise AuthenticationError("Invalid or expired token")

    if payload.get("type") != "access":
        raise AuthenticationError("Invalid token type")

    user_id = payload.get("sub")
    if not user_id:
        raise AuthenticationError("Invalid token payload")

    return user_id


async def get_current_user(
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> dict:
    """Get the full current user from database.

    Args:
        user_id: Authenticated user's ID.
        session: Database session.

    Returns:
        User data dictionary.

    Raises:
        AuthenticationError: If user not found or inactive.
    """
    repo = SQLAlchemyUserRepository(session)
    user = await repo.get_by_id(user_id)

    if user is None or not user.is_active:
        raise AuthenticationError("User not found or inactive")

    return {
        "id": user.id,
        "email": user.email,
        "full_name": user.full_name,
        "role": user.role,
        "is_verified": user.is_verified,
    }


def require_role(*roles: str):
    """Create a dependency that requires specific user roles.

    Args:
        *roles: Allowed role names (e.g., "admin", "premium").

    Returns:
        FastAPI dependency function.
    """

    async def role_checker(
        current_user: Annotated[dict, Depends(get_current_user)],
    ) -> dict:
        user_role = current_user.get("role", "")
        if user_role not in roles:
            logger.warning(
                "authorization_denied",
                user_id=current_user["id"],
                required_roles=roles,
                user_role=user_role,
            )
            raise AuthorizationError(
                f"Role '{user_role}' is not authorized. Required: {', '.join(roles)}"
            )
        return current_user

    return role_checker
