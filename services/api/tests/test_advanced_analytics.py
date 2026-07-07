"""Tests for advanced analytics engine and router."""

from __future__ import annotations

from typing import TYPE_CHECKING

import pytest

if TYPE_CHECKING:
    from httpx import AsyncClient


@pytest.mark.asyncio
async def test_get_advanced_analysis_route(
    client: AsyncClient, auth_headers: dict[str, str]
) -> None:
    """Test get advanced analysis calculation endpoint."""
    # Create portfolio
    p_resp = await client.post(
        "/api/v1/portfolios",
        json={"name": "Goal Portfolio", "description": "Goal Tracking"},
        headers=auth_headers,
    )
    assert p_resp.status_code == 201
    portfolio_id = p_resp.json()["id"]

    # Create loss-making holding to trigger tax harvesting opportunity
    await client.post(
        f"/api/v1/portfolios/{portfolio_id}/holdings",
        json={
            "symbol": "INFY",
            "name": "Infosys",
            "asset_type": "stock",
            "exchange": "NSE",
            "quantity": 10,
            "average_buy_price": 1600.0,
            "current_price": 1400.0,  # 16,000 invested, 14,000 current, loss of 2,000
        },
        headers=auth_headers,
    )

    # Fetch advanced diagnostics
    resp = await client.get(
        f"/api/v1/copilot/advanced/{portfolio_id}",
        headers=auth_headers,
    )
    assert resp.status_code == 200
    data = resp.json()

    # Verify stress testing output
    assert "stress_test" in data
    assert len(data["stress_test"]) == 3
    assert data["stress_test"][0]["scenario_name"] == "RBI Repo Rate Hike (+1.50%)"

    # Verify tax loss harvesting opportunities
    assert "tax_harvesting" in data
    assert len(data["tax_harvesting"]) >= 1
    assert data["tax_harvesting"][0]["symbol"] == "INFY"
    # Loss is 2000, 15% STCG tax offset = 300
    assert data["tax_harvesting"][0]["unrealized_loss"] == 2000.0
    assert data["tax_harvesting"][0]["potential_tax_savings"] == 300.0
    assert data["total_potential_tax_savings"] == 300.0

    # Verify behavioral biases
    assert "behavioral_biases" in data
    assert len(data["behavioral_biases"]) >= 1

    # Verify goal progression tracking
    assert "goals" in data
    assert len(data["goals"]) == 3
    assert data["goals"][0]["goal_name"] == "Emergency Reserve"
