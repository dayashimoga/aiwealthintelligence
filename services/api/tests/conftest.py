"""Test configuration and fixtures for the API test suite.

Provides async test client, database session, and common fixtures.
"""

from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator
from typing import Any

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.infrastructure.database.models import Base
from app.infrastructure.database.session import get_db_session
from app.main import app
from app.shared.security import create_access_token, hash_password


# Use in-memory SQLite for tests
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


@pytest.fixture(scope="session")
def event_loop():
    """Create event loop for the test session."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture
async def db_session() -> AsyncIterator[AsyncSession]:
    """Create a fresh database session for each test."""
    engine = create_async_engine(TEST_DATABASE_URL, echo=False)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_factory = async_sessionmaker(
        bind=engine,
        autocommit=False,
        autoflush=False,
        expire_on_commit=False,
    )

    async with session_factory() as session:
        yield session

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    await engine.dispose()


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncIterator[AsyncClient]:
    """Create an async test client with overridden DB session."""

    async def override_db_session() -> AsyncIterator[AsyncSession]:
        yield db_session

    app.dependency_overrides[get_db_session] = override_db_session

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def auth_headers(db_session: AsyncSession) -> dict[str, str]:
    """Create a test user and return auth headers."""
    from app.infrastructure.database.models import UserModel

    user = UserModel(
        id="test-user-id",
        email="test@wealthai.app",
        hashed_password=hash_password("Test@1234"),
        full_name="Test User",
        role="user",
        is_active=True,
        is_verified=True,
    )
    db_session.add(user)
    await db_session.commit()

    token = create_access_token(
        user_id="test-user-id",
        email="test@wealthai.app",
        role="user",
    )
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def sample_portfolio(
    db_session: AsyncSession, auth_headers: dict[str, str]
) -> dict[str, Any]:
    """Create a sample portfolio for testing."""
    from app.infrastructure.database.models import PortfolioModel

    portfolio = PortfolioModel(
        id="test-portfolio-id",
        user_id="test-user-id",
        name="Test Portfolio",
        description="A test portfolio",
        currency="INR",
        import_source="manual",
    )
    db_session.add(portfolio)
    await db_session.commit()

    return {"id": "test-portfolio-id", "name": "Test Portfolio"}


@pytest_asyncio.fixture
async def sample_holding(
    db_session: AsyncSession, sample_portfolio: dict[str, Any]
) -> dict[str, Any]:
    """Create a sample holding for testing."""
    from app.infrastructure.database.models import HoldingModel

    holding = HoldingModel(
        id="test-holding-id",
        portfolio_id="test-portfolio-id",
        symbol="RELIANCE",
        name="Reliance Industries Ltd",
        asset_type="stock",
        exchange="NSE",
        currency="INR",
        quantity=10,
        average_buy_price=2500.0,
        current_price=2800.0,
        sector="Energy",
        industry="Oil & Gas",
        country="India",
    )
    db_session.add(holding)
    await db_session.commit()

    return {
        "id": "test-holding-id",
        "symbol": "RELIANCE",
        "portfolio_id": "test-portfolio-id",
    }
