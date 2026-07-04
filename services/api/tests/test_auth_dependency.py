"""Unit tests for the authentication and authorization middleware dependencies."""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.presentation.middleware.auth_dependency import (
    get_current_user,
    get_current_user_id,
    require_role,
)
from app.shared.exceptions import AuthenticationError, AuthorizationError


@pytest.mark.asyncio
async def test_get_current_user_id_invalid_type() -> None:
    """Test get_current_user_id rejects invalid token types."""
    with pytest.raises(AuthenticationError, match="Invalid token type"):
        with patch("app.presentation.middleware.auth_dependency.decode_token") as mock_decode:
            mock_decode.return_value = {"type": "refresh", "sub": "user-123"}
            await get_current_user_id("Bearer dummy-token")


@pytest.mark.asyncio
async def test_get_current_user_id_missing_sub() -> None:
    """Test get_current_user_id rejects payload without user subject."""
    with pytest.raises(AuthenticationError, match="Invalid token payload"):
        with patch("app.presentation.middleware.auth_dependency.decode_token") as mock_decode:
            mock_decode.return_value = {"type": "access"}
            await get_current_user_id("Bearer dummy-token")


@pytest.mark.asyncio
async def test_get_current_user_inactive() -> None:
    """Test get_current_user raises exception for inactive user."""
    mock_user = MagicMock()
    mock_user.id = "user-123"
    mock_user.is_active = False

    mock_session = AsyncMock()

    with pytest.raises(AuthenticationError, match="User not found or inactive"):
        with patch("app.presentation.middleware.auth_dependency.SQLAlchemyUserRepository") as mock_repo_class:
            mock_repo = AsyncMock()
            mock_repo.get_by_id.return_value = mock_user
            mock_repo_class.return_value = mock_repo
            await get_current_user("user-123", mock_session)


@pytest.mark.asyncio
async def test_require_role_checker() -> None:
    """Test require_role dependency checker validation."""
    checker = require_role("admin", "premium")

    # Valid user role should pass through
    valid_user = {"id": "user-1", "role": "admin"}
    res = await checker(valid_user)
    assert res == valid_user

    # Invalid user role should raise AuthorizationError
    invalid_user = {"id": "user-2", "role": "user"}
    with pytest.raises(AuthorizationError, match="Role 'user' is not authorized"):
        await checker(invalid_user)
