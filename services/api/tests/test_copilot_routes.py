"""Integration tests for the AI Copilot API endpoints."""

from __future__ import annotations

from typing import TYPE_CHECKING
from unittest.mock import AsyncMock, patch

import pytest

if TYPE_CHECKING:
    from httpx import AsyncClient


@pytest.mark.asyncio
async def test_copilot_endpoints_flow(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    """Test get_daily_brief, get_portfolio_doctor, and post_scenario_simulation routes."""
    # 1. Setup a valid portfolio
    p_resp = await client.post(
        "/api/v1/portfolios",
        json={"name": "Copilot Test Portfolio"},
        headers=auth_headers,
    )
    assert p_resp.status_code == 201
    portfolio_id = p_resp.json()["id"]

    # 2. Add a holding to the portfolio
    h_resp = await client.post(
        f"/api/v1/portfolios/{portfolio_id}/holdings",
        json={
            "symbol": "TCS",
            "name": "Tata Consultancy Services",
            "asset_type": "stock",
            "exchange": "NSE",
            "quantity": 10,
            "average_buy_price": 3200.0,
            "current_price": 3500.0,
        },
        headers=auth_headers,
    )
    assert h_resp.status_code == 201

    # Mock the AI provider
    mock_provider = AsyncMock()

    # Define mock JSON responses for the three endpoints
    brief_json = (
        '{"summary": "The market is positive today.", "market_sentiment": "positive", '
        '"top_gainers": [{"symbol": "TCS", "gain_pct": 2.5, "price": 3500.0}], "top_losers": [], '
        '"actionable_insights": ["Insight 1"]}'
    )
    doctor_json = (
        '{"health_score": 90, "issues": [{"severity": "low", "title": "Diversified", '
        '"description": "Good structure", "recommendation": "None"}]}'
    )
    scenario_json = (
        '{"impact_summary": "Simulating sell of TCS", "recommendations": ["Hold the cash."]}'
    )

    with patch(
        "app.presentation.api.v1.copilot_routes.get_ai_provider", return_value=mock_provider
    ):
        # A. Test Daily Brief Endpoint
        mock_provider.complete.return_value = brief_json
        resp = await client.get(
            f"/api/v1/copilot/brief/{portfolio_id}",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["market_sentiment"] == "positive"
        assert len(data["top_gainers"]) == 1
        assert "summary" in data

        # B. Test Portfolio Doctor Endpoint
        mock_provider.complete.return_value = doctor_json
        resp = await client.get(
            f"/api/v1/copilot/portfolio-doctor/{portfolio_id}",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["health_score"] == 90
        assert len(data["issues"]) == 1

        # C. Test Scenario Simulation Endpoint
        mock_provider.complete.return_value = scenario_json
        resp = await client.post(
            f"/api/v1/copilot/scenario/{portfolio_id}",
            json={
                "portfolio_id": portfolio_id,
                "actions": [
                    {
                        "symbol": "TCS",
                        "action": "sell",
                        "quantity": 5,
                        "price": 3500.0,
                    }
                ],
            },
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "original_metrics" in data
        assert "simulated_metrics" in data
        assert (
            data["simulated_metrics"]["total_value"] == 17500.0
        )  # 10 TCS -> sell 5 @ 3500 -> 5 remaining @ 3500 = 17500
        assert "impact_summary" in data
