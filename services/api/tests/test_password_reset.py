"""Tests for password reset flow (request OTP + confirm new password)."""

from __future__ import annotations

from typing import TYPE_CHECKING
from unittest.mock import AsyncMock, patch

import pytest

if TYPE_CHECKING:
    from httpx import AsyncClient


@pytest.mark.unit
class TestPasswordReset:
    """Tests for the two-step password reset flow."""

    async def test_reset_request_returns_200_for_registered_email(
        self, client: AsyncClient
    ) -> None:
        """Request endpoint returns 200 even for registered emails (anti-enumeration)."""
        # First register a user so the email exists.
        await client.post(
            "/api/v1/auth/register",
            json={
                "email": "reset_user@wealthai.app",
                "password": "SecurePass123!",
                "full_name": "Reset User",
            },
        )

        with patch(
            "app.infrastructure.services.mail_service.mail_service.send_password_reset_otp",
            new_callable=AsyncMock,
            return_value=True,
        ):
            response = await client.post(
                "/api/v1/auth/password-reset/request",
                json={"email": "reset_user@wealthai.app"},
            )

        assert response.status_code == 200
        assert "reset code has been sent" in response.json()["message"]

    async def test_reset_request_returns_200_for_unknown_email(self, client: AsyncClient) -> None:
        """Request endpoint returns 200 even for non-existent emails (anti-enumeration)."""
        response = await client.post(
            "/api/v1/auth/password-reset/request",
            json={"email": "nobody@wealthai.app"},
        )
        assert response.status_code == 200
        assert "reset code has been sent" in response.json()["message"]

    async def test_reset_confirm_invalid_code_returns_422(self, client: AsyncClient) -> None:
        """Confirm endpoint rejects wrong OTP code."""
        response = await client.post(
            "/api/v1/auth/password-reset/confirm",
            json={
                "email": "reset_user2@wealthai.app",
                "code": "000000",
                "new_password": "NewSecure456!",
            },
        )
        assert response.status_code == 422

    async def test_reset_confirm_full_flow(self, client: AsyncClient) -> None:
        """Full flow: register → request reset → inject OTP → confirm → login with new pw."""
        email = "fullreset@wealthai.app"
        old_pw = "OldPassword1!"
        new_pw = "NewPassword2@"

        # Register
        await client.post(
            "/api/v1/auth/register",
            json={"email": email, "password": old_pw, "full_name": "Full Reset"},
        )

        # Capture the OTP that would have been cached
        captured_otp: list[str] = []

        async def mock_cache_set(key: str, value: str, ttl: int = 0) -> None:
            captured_otp.append(value)

        with (
            patch(
                "app.infrastructure.repositories.redis_cache.cache_repo.set",
                new=mock_cache_set,
            ),
            patch(
                "app.infrastructure.services.mail_service.mail_service.send_password_reset_otp",
                new_callable=AsyncMock,
                return_value=True,
            ),
        ):
            await client.post(
                "/api/v1/auth/password-reset/request",
                json={"email": email},
            )

        assert len(captured_otp) == 1, "OTP should have been cached"
        otp = captured_otp[0]

        # Confirm with the OTP — mock cache.get to return our captured OTP
        with (
            patch(
                "app.infrastructure.repositories.redis_cache.cache_repo.get",
                new_callable=AsyncMock,
                return_value=otp,
            ),
            patch(
                "app.infrastructure.repositories.redis_cache.cache_repo.delete",
                new_callable=AsyncMock,
            ),
        ):
            confirm_res = await client.post(
                "/api/v1/auth/password-reset/confirm",
                json={"email": email, "code": otp, "new_password": new_pw},
            )

        assert confirm_res.status_code == 200
        assert "Password updated" in confirm_res.json()["message"]

        # Verify login works with new password
        login_res = await client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": new_pw},
        )
        assert login_res.status_code == 200
        assert "access_token" in login_res.json()

        # Verify old password no longer works
        old_login_res = await client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": old_pw},
        )
        assert old_login_res.status_code == 401
