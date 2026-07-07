"""Tests for advanced portfolio imports (Account Aggregator, broker, etc.)."""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

import pytest

from app.infrastructure.repositories.sqlalchemy_repos import SQLAlchemyHoldingRepository

if TYPE_CHECKING:
    from httpx import AsyncClient
    from sqlalchemy.ext.asyncio import AsyncSession


@pytest.mark.unit
class TestAccountAggregatorWorkflow:
    """Tests for mock Account Aggregator (AA) consent integration flows."""

    async def test_consent_initiate_and_callback_flow(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_portfolio: dict[str, Any],
        db_session: AsyncSession,
    ) -> None:
        """User can initiate AA consent, callback triggers sync, status is pollable."""
        portfolio_id = sample_portfolio["id"]

        # 1. Initiate consent
        initiate_res = await client.post(
            f"/api/v1/portfolios/{portfolio_id}/consent",
            headers=auth_headers,
            json={
                "phone_number": "+919876543210",
                "aggregator_id": "onemoney-aggregator",
            },
        )
        assert initiate_res.status_code == 200
        data = initiate_res.json()
        assert "consent_handle" in data
        assert "redirect_url" in data
        consent_handle = data["consent_handle"]

        # 2. Get pending status
        status_res = await client.get(
            f"/api/v1/portfolios/{portfolio_id}/consent/status/{consent_handle}",
            headers=auth_headers,
        )
        assert status_res.status_code == 200
        assert status_res.json()["status"] == "PENDING"

        # 3. Call back as mock AA gateway approving access
        callback_res = await client.get(
            f"/api/v1/portfolios/{portfolio_id}/callback",
            params={
                "consent_handle": consent_handle,
                "status": "APPROVED",
            },
        )
        assert callback_res.status_code == 200
        callback_data = callback_res.json()
        assert callback_data["status"] == "COMPLETED"
        assert callback_data["holdings_count"] > 0

        # 4. Get completed status
        status_completed = await client.get(
            f"/api/v1/portfolios/{portfolio_id}/consent/status/{consent_handle}",
            headers=auth_headers,
        )
        assert status_completed.status_code == 200
        assert status_completed.json()["status"] == "COMPLETED"
        assert status_completed.json()["holdings_count"] == callback_data["holdings_count"]

        # 5. Verify database contains the imported holdings
        holding_repo = SQLAlchemyHoldingRepository(db_session)
        holdings = await holding_repo.list_by_portfolio(portfolio_id)
        assert len(holdings) == callback_data["holdings_count"]
