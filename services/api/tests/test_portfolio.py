"""Tests for portfolio management endpoints."""

from __future__ import annotations

from typing import Any

import pytest
from httpx import AsyncClient


@pytest.mark.unit
class TestPortfolioCRUD:
    """Tests for portfolio CRUD operations."""

    async def test_create_portfolio(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Create a portfolio successfully."""
        response = await client.post(
            "/api/v1/portfolios",
            json={"name": "Growth Portfolio", "description": "Long term growth", "currency": "INR"},
            headers=auth_headers,
        )
        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "Growth Portfolio"
        assert data["currency"] == "INR"
        assert data["holding_count"] == 0

    async def test_create_portfolio_no_auth(self, client: AsyncClient) -> None:
        """Creating portfolio without auth returns 401."""
        response = await client.post(
            "/api/v1/portfolios",
            json={"name": "Unauthorized"},
        )
        assert response.status_code == 401

    async def test_list_portfolios(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_portfolio: dict[str, Any],
    ) -> None:
        """List user's portfolios."""
        response = await client.get("/api/v1/portfolios", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["total"] >= 1
        assert any(p["id"] == sample_portfolio["id"] for p in data["portfolios"])

    async def test_get_portfolio(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_portfolio: dict[str, Any],
    ) -> None:
        """Get a specific portfolio by ID."""
        response = await client.get(
            f"/api/v1/portfolios/{sample_portfolio['id']}",
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == sample_portfolio["name"]

    async def test_get_nonexistent_portfolio(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Getting nonexistent portfolio returns 404."""
        response = await client.get(
            "/api/v1/portfolios/nonexistent-id",
            headers=auth_headers,
        )
        assert response.status_code == 404

    async def test_update_portfolio(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_portfolio: dict[str, Any],
    ) -> None:
        """Update portfolio name and description."""
        response = await client.patch(
            f"/api/v1/portfolios/{sample_portfolio['id']}",
            json={"name": "Updated Portfolio"},
            headers=auth_headers,
        )
        assert response.status_code == 200
        assert response.json()["name"] == "Updated Portfolio"

    async def test_delete_portfolio(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Delete a portfolio."""
        # Create a portfolio to delete
        create_resp = await client.post(
            "/api/v1/portfolios",
            json={"name": "To Delete"},
            headers=auth_headers,
        )
        portfolio_id = create_resp.json()["id"]

        response = await client.delete(
            f"/api/v1/portfolios/{portfolio_id}",
            headers=auth_headers,
        )
        assert response.status_code == 204

        # Verify it's gone
        get_resp = await client.get(
            f"/api/v1/portfolios/{portfolio_id}",
            headers=auth_headers,
        )
        assert get_resp.status_code == 404


@pytest.mark.unit
class TestHoldings:
    """Tests for holding CRUD operations."""

    async def test_create_holding(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_portfolio: dict[str, Any],
    ) -> None:
        """Add a holding to a portfolio."""
        response = await client.post(
            f"/api/v1/portfolios/{sample_portfolio['id']}/holdings",
            json={
                "symbol": "TCS",
                "name": "Tata Consultancy Services",
                "asset_type": "stock",
                "exchange": "NSE",
                "quantity": "50",
                "average_buy_price": "3500.00",
                "current_price": "3800.00",
                "sector": "Information Technology",
                "country": "India",
            },
            headers=auth_headers,
        )
        assert response.status_code == 201
        data = response.json()
        assert data["symbol"] == "TCS"
        assert data["quantity"] == 50.0
        assert data["invested_value"] == 175000.0
        assert data["current_value"] == 190000.0
        assert data["gain_loss"] == 15000.0

    async def test_list_holdings(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_holding: dict[str, Any],
    ) -> None:
        """List holdings in a portfolio."""
        response = await client.get(
            f"/api/v1/portfolios/{sample_holding['portfolio_id']}/holdings",
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["total"] >= 1

    async def test_update_holding(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_holding: dict[str, Any],
    ) -> None:
        """Update holding quantity and price."""
        response = await client.patch(
            f"/api/v1/portfolios/{sample_holding['portfolio_id']}/holdings/{sample_holding['id']}",
            json={"quantity": "20", "current_price": "3000.00"},
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["quantity"] == 20.0
        assert data["current_price"] == 3000.0

    async def test_delete_holding(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_portfolio: dict[str, Any],
    ) -> None:
        """Delete a holding from a portfolio."""
        # Create a holding to delete
        create_resp = await client.post(
            f"/api/v1/portfolios/{sample_portfolio['id']}/holdings",
            json={
                "symbol": "WIPRO",
                "name": "Wipro Ltd",
                "quantity": "100",
                "average_buy_price": "400",
            },
            headers=auth_headers,
        )
        holding_id = create_resp.json()["id"]

        response = await client.delete(
            f"/api/v1/portfolios/{sample_portfolio['id']}/holdings/{holding_id}",
            headers=auth_headers,
        )
        assert response.status_code == 204


@pytest.mark.unit
class TestAnalytics:
    """Tests for portfolio analytics endpoint."""

    async def test_get_analytics(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_holding: dict[str, Any],
    ) -> None:
        """Get portfolio analytics with holdings."""
        response = await client.get(
            f"/api/v1/portfolios/{sample_holding['portfolio_id']}/analytics",
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["total_invested"] > 0
        assert data["total_current_value"] > 0
        assert "asset_allocation" in data
        assert "sector_allocation" in data
        assert "diversification_score" in data
        assert "risk_score" in data
        assert "ai_health_score" in data

    async def test_get_analytics_empty_portfolio(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_portfolio: dict[str, Any],
    ) -> None:
        """Analytics for empty portfolio returns zeros."""
        response = await client.get(
            f"/api/v1/portfolios/{sample_portfolio['id']}/analytics",
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["total_invested"] == 0
        assert data["holding_count"] == 0


@pytest.mark.unit
class TestCSVImport:
    """Tests for CSV import functionality."""

    async def test_import_csv(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_portfolio: dict[str, Any],
    ) -> None:
        """Import holdings from a valid CSV file."""
        csv_content = (
            "symbol,name,asset_type,quantity,buy_price,current_price,sector,exchange\n"
            "INFY,Infosys Ltd,stock,100,1500.00,1700.00,Information Technology,NSE\n"
            "HDFCBANK,HDFC Bank Ltd,stock,50,1600.00,1650.00,Financial Services,NSE\n"
            "TATAMOTORS,Tata Motors Ltd,stock,200,500.00,600.00,Automobile,NSE\n"
        )

        response = await client.post(
            f"/api/v1/portfolios/{sample_portfolio['id']}/import",
            headers=auth_headers,
            files={"file": ("portfolio.csv", csv_content, "text/csv")},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["imported"] == 3
        assert data["skipped"] == 0
        assert len(data["errors"]) == 0

    async def test_import_csv_with_errors(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_portfolio: dict[str, Any],
    ) -> None:
        """Import CSV with invalid rows reports errors."""
        csv_content = (
            "symbol,name,quantity,buy_price\n"
            "VALID,Valid Stock,100,1500\n"
            ",Missing Symbol,50,1000\n"
            "INVALID,Invalid Quantity,abc,1000\n"
        )

        response = await client.post(
            f"/api/v1/portfolios/{sample_portfolio['id']}/import",
            headers=auth_headers,
            files={"file": ("bad.csv", csv_content, "text/csv")},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["imported"] == 1
        assert data["skipped"] >= 1
        assert len(data["errors"]) >= 1
