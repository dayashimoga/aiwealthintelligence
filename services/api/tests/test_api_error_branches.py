"""Tests targeting error branches in API routes and middleware to boost coverage."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_portfolio_routes_errors(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    """Test error handling in portfolios and holdings routes."""
    # Get non-existent portfolio
    resp = await client.get("/api/v1/portfolios/non-existent-id", headers=auth_headers)
    assert resp.status_code == 404
    
    # Update non-existent portfolio
    resp = await client.patch(
        "/api/v1/portfolios/non-existent-id",
        json={"name": "New Name"},
        headers=auth_headers,
    )
    assert resp.status_code == 404
    
    # Delete non-existent portfolio
    resp = await client.delete("/api/v1/portfolios/non-existent-id", headers=auth_headers)
    assert resp.status_code == 404

    # Create holding on non-existent portfolio
    resp = await client.post(
        "/api/v1/portfolios/non-existent-id/holdings",
        json={
            "symbol": "TCS",
            "name": "Tata Consultancy",
            "asset_type": "stock",
            "exchange": "NSE",
            "quantity": 10,
            "average_buy_price": 3000.0,
            "current_price": 3400.0,
        },
        headers=auth_headers,
    )
    assert resp.status_code == 404

    # Get holdings on non-existent portfolio
    resp = await client.get("/api/v1/portfolios/non-existent-id/holdings", headers=auth_headers)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_holding_routes_errors(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    """Test error handling on individual holding endpoints."""
    # First create a valid portfolio
    p_resp = await client.post(
        "/api/v1/portfolios",
        json={"name": "Valid Portfolio"},
        headers=auth_headers,
    )
    portfolio_id = p_resp.json()["id"]

    # Update non-existent holding
    resp = await client.patch(
        f"/api/v1/portfolios/{portfolio_id}/holdings/non-existent-holding",
        json={"quantity": 15},
        headers=auth_headers,
    )
    assert resp.status_code == 404

    # Delete non-existent holding
    resp = await client.delete(
        f"/api/v1/portfolios/{portfolio_id}/holdings/non-existent-holding",
        headers=auth_headers,
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_ai_recommendation_non_existent_ownership(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    """Test AI Copilot recommendation route checks portfolio and holding ownership."""
    # Try recommendation with invalid portfolio/holding combinations
    resp = await client.get(
        "/api/v1/ai/recommendations/non-existent-portfolio/non-existent-holding",
        headers=auth_headers,
    )
    assert resp.status_code == 404
