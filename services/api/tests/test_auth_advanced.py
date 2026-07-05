"""Tests for advanced authentication features (OAuth, OTP, MFA, passkeys, device management)."""

from __future__ import annotations

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from app.infrastructure.repositories.sqlalchemy_repos import SQLAlchemyUserRepository
from app.domain.entities import User
from datetime import datetime, timezone
import pyotp
from app.infrastructure.repositories.redis_cache import cache_repo

@pytest.mark.unit
class TestOAuthLogin:
    """Tests for OAuth registration and login workflows."""

    async def test_oauth_register_and_login_success(self, client: AsyncClient, db_session: AsyncSession) -> None:
        """Successful Google/Apple login registers new user if not exist."""
        response = await client.post(
            "/api/v1/auth/oauth-login",
            json={
                "email": "oauth_new@wealthai.app",
                "token": "google-mock-token-12345",
                "provider": "google",
                "full_name": "OAuth User",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data

        # Verify Google ID matches in DB
        repo = SQLAlchemyUserRepository(db_session)
        user = await repo.get_by_email("oauth_new@wealthai.app")
        assert user is not None
        assert user.google_id == "google-mock-token-12345"
        assert user.is_verified is True


@pytest.mark.unit
class TestEmailOTPFlow:
    """Tests for Email OTP send and verify."""

    async def test_otp_send_and_verify_flow(self, client: AsyncClient, db_session: AsyncSession) -> None:
        """User can request verification OTP and successfully exchange it for JWT tokens."""
        # 1. Send OTP
        email = "otp_test@wealthai.app"
        send_response = await client.post(
            "/api/v1/auth/otp/send",
            json={"email": email},
        )
        assert send_response.status_code == 200
        assert send_response.json()["message"] == "Verification code sent successfully"

        # Read generated code from cache
        code = await cache_repo.get(f"otp:{email}")
        assert code is not None
        assert len(code) == 6

        # 2. Verify OTP
        verify_response = await client.post(
            "/api/v1/auth/otp/verify",
            json={
                "email": email,
                "code": code,
            },
        )
        assert verify_response.status_code == 200
        data = verify_response.json()
        assert "access_token" in data
        assert "refresh_token" in data


@pytest.mark.unit
class TestTOTPMultiFactor:
    """Tests for TOTP 2FA setup, verification and toggle states."""

    async def test_totp_mfa_workflow(self, client: AsyncClient, db_session: AsyncSession) -> None:
        """Authenticated user can setup, enable, and disable TOTP successfully."""
        # 1. Register a test user and obtain auth headers
        register_res = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "totp_mfa@wealthai.app",
                "password": "SecurePassword@123",
                "full_name": "MFA User",
            },
        )
        assert register_res.status_code == 201
        token = register_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 2. Setup TOTP
        setup_res = await client.post("/api/v1/auth/mfa/totp/setup", headers=headers)
        assert setup_res.status_code == 200
        setup_data = setup_res.json()
        assert "secret" in setup_data
        assert "provisioning_uri" in setup_data
        secret = setup_data["secret"]

        # 3. Generate correct TOTP token code
        totp = pyotp_totp = pyotp_helper = pyotp_totp_gen = pyotp.TOTP(secret)
        code = totp.now()

        # 4. Enable TOTP
        enable_res = await client.post(
            "/api/v1/auth/mfa/totp/enable",
            headers=headers,
            json={"code": code},
        )
        assert enable_res.status_code == 200
        enable_data = enable_res.json()
        assert "backup_codes" in enable_data
        assert len(enable_data["backup_codes"]) == 8

        # Verify DB reflects MFA enabled
        repo = SQLAlchemyUserRepository(db_session)
        user = await repo.get_by_email("totp_mfa@wealthai.app")
        assert user is not None
        assert user.mfa_enabled is True
        assert user.totp_secret == secret

        # 5. Disable TOTP
        disable_res = await client.post("/api/v1/auth/mfa/totp/disable", headers=headers)
        assert disable_res.status_code == 200

        user_after = await repo.get_by_email("totp_mfa@wealthai.app")
        assert user_after.mfa_enabled is False
        assert user_after.totp_secret is None


@pytest.mark.unit
class TestDeviceManagement:
    """Tests for listing and revoking device sessions."""

    async def test_device_list_and_revoke(self, client: AsyncClient, db_session: AsyncSession) -> None:
        """Authenticated user can list active devices and revoke a device session."""
        register_res = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "devices_test@wealthai.app",
                "password": "SecurePassword@123",
                "full_name": "Device User",
            },
        )
        assert register_res.status_code == 201
        token = register_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # Seed device list in DB
        repo = SQLAlchemyUserRepository(db_session)
        user = await repo.get_by_email("devices_test@wealthai.app")
        user.trusted_devices = [
            {"device_id": "dev-id-1", "name": "iPhone 15", "registered_at": datetime.now(timezone.utc).isoformat()},
            {"device_id": "dev-id-2", "name": "MacBook Pro", "registered_at": datetime.now(timezone.utc).isoformat()},
        ]
        await repo.update(user)
        await db_session.commit()

        # List devices
        list_res = await client.get("/api/v1/auth/devices", headers=headers)
        assert list_res.status_code == 200
        list_data = list_res.json()
        assert len(list_data) == 2
        assert list_data[0]["name"] == "iPhone 15"

        # Revoke device
        revoke_res = await client.delete("/api/v1/auth/devices/dev-id-1", headers=headers)
        assert revoke_res.status_code == 200

        # Verify device revoked in DB
        user_after = await repo.get_by_email("devices_test@wealthai.app")
        assert len(user_after.trusted_devices) == 1
        assert user_after.trusted_devices[0]["device_id"] == "dev-id-2"


@pytest.mark.unit
class TestPasskeyFramework:
    """Tests for passkey registration and authentication option workflows."""

    async def test_passkey_register_and_login_flow(self, client: AsyncClient, db_session: AsyncSession) -> None:
        """User can request passkey registration options and verify credentials."""
        # 1. Obtain auth headers
        register_res = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "passkey_test@wealthai.app",
                "password": "SecurePassword@123",
                "full_name": "Passkey User",
            },
        )
        assert register_res.status_code == 201
        token = register_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 2. Get registration options
        opt_res = await client.post("/api/v1/auth/passkeys/register/options", headers=headers)
        assert opt_res.status_code == 200
        assert "challenge" in opt_res.json()

        # 3. Verify/Register passkey credentials
        verify_res = await client.post(
            "/api/v1/auth/passkeys/register/verify",
            headers=headers,
            json={
                "credential_id": "cred-id-98765",
                "client_data_json": "mock-public-key-val",
                "authenticator_data": "mock-auth-data",
                "signature": "mock-sig",
            },
        )
        assert verify_res.status_code == 200
        assert verify_res.json()["message"] == "Passkey registered successfully"

        # Verify DB passkey exists
        repo = SQLAlchemyUserRepository(db_session)
        user = await repo.get_by_email("passkey_test@wealthai.app")
        assert len(user.passkeys) == 1
        assert user.passkeys[0]["credential_id"] == "cred-id-98765"

        # 4. Get login options
        login_opt = await client.post("/api/v1/auth/passkeys/login/options", json={"email": "passkey_test@wealthai.app"})
        assert login_opt.status_code == 200
        assert "challenge" in login_opt.json()

        # 5. Verify/Login via passkey credentials
        login_verify = await client.post(
            "/api/v1/auth/passkeys/login/verify",
            json={
                "credential_id": "cred-id-98765",
                "client_data_json": "mock-public-key-val",
                "authenticator_data": "mock-auth-data",
                "signature": "mock-sig",
            },
        )
        assert login_verify.status_code == 200
        assert "access_token" in login_verify.json()

