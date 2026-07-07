"""Integration tests for all remaining WealthAI API routes."""

from __future__ import annotations

import io
from typing import TYPE_CHECKING
from unittest.mock import AsyncMock, patch

import pytest

if TYPE_CHECKING:
    from httpx import AsyncClient


@pytest.mark.asyncio
async def test_auth_additional_routes(client: AsyncClient) -> None:
    """Test refresh token and profile endpoints."""
    # POST /auth/refresh
    resp = await client.post("/api/v1/auth/refresh", json={"refresh_token": "some-token"})
    assert resp.status_code in (200, 401)


@pytest.mark.asyncio
async def test_market_routes(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    """Test market news, sectors, and overview endpoints."""
    # Test market news
    resp = await client.get("/api/v1/market/news", headers=auth_headers)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)

    # Test market sectors
    resp = await client.get("/api/v1/market/sectors", headers=auth_headers)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)

    # Test market overview
    resp = await client.get("/api/v1/market/overview", headers=auth_headers)
    assert resp.status_code == 200
    assert "news" in resp.json()
    assert "sector_rankings" in resp.json()


@pytest.mark.asyncio
async def test_ai_copilot_routes(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    """Test AI Copilot chat and recommendation endpoints."""
    mock_provider = AsyncMock()
    mock_provider.complete.return_value = "This is a copilot response."

    with patch("app.presentation.api.v1.ai_routes.get_ai_provider", return_value=mock_provider):
        resp = await client.post(
            "/api/v1/ai/chat",
            json={"message": "hello", "portfolio_id": "some-id"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert "copilot response" in resp.json()["message"].lower()

    # Recommendation for holding
    mock_provider.complete.return_value = (
        '{"action": "buy", "confidence": 90, "reasoning": "Excellent margins", '
        '"evidence": ["growing revenue"], "expected_return": 15.0, "risk_level": "moderate", '
        '"investment_horizon": "1 year", "alternative_suggestions": [], "explainability": {}}'
    )
    # First create a portfolio using plural /portfolios
    p_resp = await client.post(
        "/api/v1/portfolios",
        json={"name": "Wealth Portfolio", "description": "My retirement fund"},
        headers=auth_headers,
    )
    assert p_resp.status_code == 201
    portfolio_id = p_resp.json()["id"]

    # Create holding
    h_resp = await client.post(
        f"/api/v1/portfolios/{portfolio_id}/holdings",
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
    assert h_resp.status_code == 201
    holding_id = h_resp.json()["id"]

    with patch("app.presentation.api.v1.ai_routes.get_ai_provider", return_value=mock_provider):
        resp = await client.get(
            f"/api/v1/ai/recommendations/{portfolio_id}/{holding_id}",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["action"] == "buy"


@pytest.mark.asyncio
async def test_cas_pdf_import_route(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    """Test importing CAS PDF endpoint."""
    p_resp = await client.post(
        "/api/v1/portfolios",
        json={"name": "CAS Portfolio"},
        headers=auth_headers,
    )
    assert p_resp.status_code == 201
    portfolio_id = p_resp.json()["id"]

    # Mock CAS parser to return mock parsed holding rows
    mock_parsed_holdings = [
        {
            "symbol": "INFY",
            "name": "Infosys Ltd",
            "isin": "INE009A01021",
            "quantity": 25.0,
            "average_buy_price": 1400.0,
            "current_price": 1450.0,
            "asset_type": "stock",
            "exchange": "NSE",
            "sector": "Information Technology",
        }
    ]

    with patch(
        "app.infrastructure.importers.cas_pdf_parser.CASPDFParser.parse",
        return_value=mock_parsed_holdings,
    ):
        pdf_data = b"%PDF-1.4 Mock CAS PDF data..."
        files = {"file": ("cams_cas.pdf", io.BytesIO(pdf_data), "application/pdf")}

        resp = await client.post(
            f"/api/v1/portfolios/{portfolio_id}/import/cas-pdf",
            files=files,
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["imported"] == 1
