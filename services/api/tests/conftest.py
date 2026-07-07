"""Test configuration and fixtures for the API test suite.

Provides async test client, database session, and common fixtures.

Architecture note:
    The `client` fixture initialises the global `sessionmanager` with an
    in-memory SQLite database BEFORE starting the AsyncClient (which triggers
    the FastAPI lifespan).  This way every route that depends on `get_db_session`
    uses the same in-memory database as our test helpers — no dependency-override
    magic required and no session-isolation issues.
"""

from __future__ import annotations

import asyncio
import os
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from collections.abc import AsyncIterator
    from sqlalchemy.ext.asyncio import AsyncSession

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

# Tell the app to use an in-memory SQLite DB for all tests.
# Must be set BEFORE importing any app modules.
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")
os.environ.setdefault("APP_ENV", "development")
os.environ.setdefault("APP_DEBUG", "false")
os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-for-ci-only-not-production")
os.environ.setdefault("AI_API_KEY", "test-key")
os.environ.setdefault("REDIS_URL", "")

from app.infrastructure.database.models import Base
from app.infrastructure.database.session import sessionmanager
from app.main import app


@pytest.fixture(scope="session")
def event_loop():
    """Create event loop for the test session."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture
async def db_session() -> AsyncIterator[AsyncSession]:
    """Provide a direct database session for tests that inspect DB state.

    Uses the same sessionmanager as the application, so committed data is visible.
    """
    from sqlalchemy.ext.asyncio import AsyncSession

    # Ensure sessionmanager is initialised.
    if sessionmanager._engine is None:
        sessionmanager.init("sqlite+aiosqlite:///:memory:")
        await sessionmanager.create_all()

    async with sessionmanager.session() as session:
        yield session


@pytest_asyncio.fixture
async def client() -> AsyncClient:
    """Create an async test client backed by a fresh in-memory SQLite DB.

    Strategy:
    1. Initialise sessionmanager with the test SQLite URL.
    2. Create all tables.
    3. Start the AsyncClient (this triggers FastAPI lifespan; because
       sessionmanager is already initialised, the lifespan's init call is
       effectively a no-op on the same URL).
    4. Yield the client.
    5. Drop all tables and close the engine.
    """
    test_url = "sqlite+aiosqlite:///:memory:"
    sessionmanager.init(test_url)
    await sessionmanager.create_all()

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    async with sessionmanager._engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await sessionmanager.close()


@pytest_asyncio.fixture
async def auth_headers(client: AsyncClient) -> dict[str, str]:
    """Register a test user via the real API and return auth headers.

    Because the client and this fixture share the same sessionmanager
    database, subsequent authenticated requests see the registered user.
    """
    register_resp = await client.post(
        "/api/v1/auth/register",
        json={
            "email": "test@wealthai.app",
            "password": "Test@1234",
            "full_name": "Test User",
        },
    )
    # If user already exists (fixture reuse edge-case), log in instead.
    if register_resp.status_code == 409:
        login_resp = await client.post(
            "/api/v1/auth/login",
            json={"email": "test@wealthai.app", "password": "Test@1234"},
        )
        assert login_resp.status_code == 200, (
            f"Login failed: {login_resp.status_code} {login_resp.text}"
        )
        token = login_resp.json()["access_token"]
    else:
        assert register_resp.status_code == 201, (
            f"Register failed: {register_resp.status_code} {register_resp.text}"
        )
        token = register_resp.json()["access_token"]

    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def sample_portfolio(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> dict[str, Any]:
    """Create a sample portfolio via the API and return its JSON."""
    resp = await client.post(
        "/api/v1/portfolios",
        json={"name": "Test Portfolio", "description": "A test portfolio"},
        headers=auth_headers,
    )
    assert resp.status_code == 201, f"Portfolio create failed: {resp.status_code} {resp.text}"
    return resp.json()


@pytest_asyncio.fixture
async def sample_holding(
    client: AsyncClient,
    auth_headers: dict[str, str],
    sample_portfolio: dict[str, Any],
) -> dict[str, Any]:
    """Create a sample holding via the API and return its JSON."""
    portfolio_id = sample_portfolio["id"]
    resp = await client.post(
        f"/api/v1/portfolios/{portfolio_id}/holdings",
        json={
            "symbol": "RELIANCE",
            "name": "Reliance Industries Ltd",
            "asset_type": "stock",
            "exchange": "NSE",
            "quantity": 10,
            "average_buy_price": 2500.0,
            "current_price": 2800.0,
            "sector": "Energy",
            "industry": "Oil & Gas",
            "country": "India",
        },
        headers=auth_headers,
    )
    assert resp.status_code == 201, f"Holding create failed: {resp.status_code} {resp.text}"
    data = resp.json()
    return {
        "id": data["id"],
        "symbol": "RELIANCE",
        "portfolio_id": portfolio_id,
    }
