"""Tests for health check and auth endpoints."""

from __future__ import annotations

import pytest
from httpx import AsyncClient


# ============================================================
# Health Check Tests
# ============================================================


@pytest.mark.unit
class TestHealthCheck:
    """Tests for the health check endpoint."""

    async def test_health_returns_200(self, client: AsyncClient) -> None:
        """Health endpoint returns 200 with status healthy."""
        response = await client.get("/api/v1/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["version"] == "0.1.0"
        assert "timestamp" in data

    async def test_health_includes_environment(self, client: AsyncClient) -> None:
        """Health endpoint includes environment info."""
        response = await client.get("/api/v1/health")
        data = response.json()
        assert "environment" in data


# ============================================================
# Auth Tests
# ============================================================


@pytest.mark.unit
class TestRegistration:
    """Tests for user registration."""

    async def test_register_success(self, client: AsyncClient) -> None:
        """Successful registration returns tokens."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "new@wealthai.app",
                "password": "Secure@1234",
                "full_name": "New User",
            },
        )
        assert response.status_code == 201
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"
        assert data["expires_in"] > 0

    async def test_register_weak_password(self, client: AsyncClient) -> None:
        """Registration with weak password returns 422."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "weak@wealthai.app",
                "password": "short",
                "full_name": "Weak Password User",
            },
        )
        assert response.status_code == 422

    async def test_register_duplicate_email(self, client: AsyncClient) -> None:
        """Registration with existing email returns 409."""
        payload = {
            "email": "dup@wealthai.app",
            "password": "Secure@1234",
            "full_name": "First User",
        }
        await client.post("/api/v1/auth/register", json=payload)
        response = await client.post("/api/v1/auth/register", json=payload)
        assert response.status_code == 409

    async def test_register_invalid_email(self, client: AsyncClient) -> None:
        """Registration with invalid email returns 422."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "not-an-email",
                "password": "Secure@1234",
                "full_name": "Invalid Email",
            },
        )
        assert response.status_code == 422


@pytest.mark.unit
class TestLogin:
    """Tests for user login."""

    async def test_login_success(self, client: AsyncClient) -> None:
        """Successful login returns tokens."""
        # First register
        await client.post(
            "/api/v1/auth/register",
            json={
                "email": "login@wealthai.app",
                "password": "Secure@1234",
                "full_name": "Login User",
            },
        )
        # Then login
        response = await client.post(
            "/api/v1/auth/login",
            json={"email": "login@wealthai.app", "password": "Secure@1234"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data

    async def test_login_wrong_password(self, client: AsyncClient) -> None:
        """Login with wrong password returns 401."""
        await client.post(
            "/api/v1/auth/register",
            json={
                "email": "wrong@wealthai.app",
                "password": "Secure@1234",
                "full_name": "Wrong Password",
            },
        )
        response = await client.post(
            "/api/v1/auth/login",
            json={"email": "wrong@wealthai.app", "password": "WrongPass@1234"},
        )
        assert response.status_code == 401

    async def test_login_nonexistent_user(self, client: AsyncClient) -> None:
        """Login with nonexistent email returns 401."""
        response = await client.post(
            "/api/v1/auth/login",
            json={"email": "noone@wealthai.app", "password": "Secure@1234"},
        )
        assert response.status_code == 401


@pytest.mark.unit
class TestProfile:
    """Tests for user profile endpoint."""

    async def test_get_profile(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Authenticated user can get their profile."""
        response = await client.get("/api/v1/auth/me", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["email"] == "test@wealthai.app"
        assert data["full_name"] == "Test User"

    async def test_get_profile_no_auth(self, client: AsyncClient) -> None:
        """Unauthenticated profile request returns 401."""
        response = await client.get("/api/v1/auth/me")
        assert response.status_code == 401

    async def test_get_profile_invalid_token(self, client: AsyncClient) -> None:
        """Invalid token returns 401."""
        response = await client.get(
            "/api/v1/auth/me",
            headers={"Authorization": "Bearer invalid-token"},
        )
        assert response.status_code == 401

    async def test_delete_account_success(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Authenticated user can delete their account."""
        response = await client.delete("/api/v1/auth/account", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["message"] == "Account deleted successfully"

        # Subsequent profile checks should fail
        me_resp = await client.get("/api/v1/auth/me", headers=auth_headers)
        assert me_resp.status_code == 401

    async def test_delete_account_no_auth(self, client: AsyncClient) -> None:
        """Unauthenticated delete account request returns 401."""
        response = await client.delete("/api/v1/auth/account")
        assert response.status_code == 401
