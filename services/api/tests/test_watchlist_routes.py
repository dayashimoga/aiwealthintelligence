"""Integration tests for watchlist routes matching actual API structure.

Actual routes:
  GET    /watchlists               → {"watchlists": [...]}
  POST   /watchlists               → {"id": ..., "name": ...}  (201)
  POST   /watchlists/{id}/symbols  → {"id": ..., "symbols": [...]}
  DELETE /watchlists/{id}/symbols/{symbol} → {"id": ..., "symbols": [...]}
  GET    /watchlists/{id}/intelligence → {"intelligence": [...]}
  DELETE /watchlists/{id}          → 204
"""

from __future__ import annotations

from typing import Any

import pytest
from httpx import AsyncClient


@pytest.fixture
async def sample_watchlist(
    client: AsyncClient, auth_headers: dict[str, str]
) -> dict[str, Any]:
    """Create a watchlist and return its dict."""
    resp = await client.post(
        "/api/v1/watchlists",
        json={"name": "Tech Stocks", "symbols": []},
        headers=auth_headers,
    )
    assert resp.status_code == 201, f"Create failed: {resp.text}"
    return resp.json()


@pytest.mark.asyncio
class TestWatchlistCRUD:
    async def test_create_watchlist(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        resp = await client.post(
            "/api/v1/watchlists",
            json={"name": "My Watchlist"},
            headers=auth_headers,
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["name"] == "My Watchlist"
        assert "id" in data

    async def test_list_watchlists_returns_dict(
        self, client: AsyncClient, auth_headers: dict, sample_watchlist: dict
    ) -> None:
        """List returns {'watchlists': [...]} dict."""
        resp = await client.get("/api/v1/watchlists", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert "watchlists" in data
        ids = [w["id"] for w in data["watchlists"]]
        assert sample_watchlist["id"] in ids

    async def test_list_watchlists_requires_auth(self, client: AsyncClient) -> None:
        resp = await client.get("/api/v1/watchlists")
        assert resp.status_code == 401

    async def test_delete_watchlist(
        self, client: AsyncClient, auth_headers: dict, sample_watchlist: dict
    ) -> None:
        wid = sample_watchlist["id"]
        resp = await client.delete(f"/api/v1/watchlists/{wid}", headers=auth_headers)
        assert resp.status_code == 204

    async def test_delete_nonexistent_watchlist(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        resp = await client.delete(
            "/api/v1/watchlists/00000000-0000-0000-0000-000000000000",
            headers=auth_headers,
        )
        assert resp.status_code == 404


@pytest.mark.asyncio
class TestWatchlistSymbols:
    async def test_add_symbol(
        self, client: AsyncClient, auth_headers: dict, sample_watchlist: dict
    ) -> None:
        wid = sample_watchlist["id"]
        resp = await client.post(
            f"/api/v1/watchlists/{wid}/symbols",
            json={"symbol": "RELIANCE"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "RELIANCE" in data["symbols"]

    async def test_add_duplicate_symbol_idempotent(
        self, client: AsyncClient, auth_headers: dict, sample_watchlist: dict
    ) -> None:
        """Adding the same symbol twice should not raise 500."""
        wid = sample_watchlist["id"]
        payload = {"symbol": "TCS"}
        await client.post(
            f"/api/v1/watchlists/{wid}/symbols", json=payload, headers=auth_headers
        )
        resp = await client.post(
            f"/api/v1/watchlists/{wid}/symbols", json=payload, headers=auth_headers
        )
        assert resp.status_code != 500

    async def test_remove_symbol(
        self, client: AsyncClient, auth_headers: dict, sample_watchlist: dict
    ) -> None:
        wid = sample_watchlist["id"]
        await client.post(
            f"/api/v1/watchlists/{wid}/symbols",
            json={"symbol": "INFY"},
            headers=auth_headers,
        )
        resp = await client.delete(
            f"/api/v1/watchlists/{wid}/symbols/INFY",
            headers=auth_headers,
        )
        assert resp.status_code in (200, 204)

    async def test_add_symbol_to_nonexistent_watchlist(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        resp = await client.post(
            "/api/v1/watchlists/00000000-0000-0000-0000-000000000000/symbols",
            json={"symbol": "TEST"},
            headers=auth_headers,
        )
        assert resp.status_code == 404
