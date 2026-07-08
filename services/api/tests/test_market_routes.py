"""Integration tests for market data routes.

Tests the /api/v1/market/* endpoints with mocked external data sources
(yFinance, RSS) to avoid network calls during CI.

Patching strategy:
- Patch at the IMPORT SITE (where the name is used), not at the definition site.
- market_routes.py imports: fetch_and_analyze_news, cache_repo, _fetch_sector_perf (internal)
- market_data_service is imported INSIDE the function body, so patch at definition site is OK.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

from app.presentation.schemas.api_schemas import SectorRankingResponse


# ---------------------------------------------------------------------------
# Helpers — build valid schema-compatible test objects
# ---------------------------------------------------------------------------


def _make_news_dict(**kwargs: Any) -> dict:
    defaults = {
        "id": "news-1",
        "title": "Nifty 50 hits all-time high",
        "summary": "Indian equity markets rallied strongly today.",
        "source": "MoneyControl",
        "url": "https://moneycontrol.com/story/1",
        "sentiment": "positive",
        "relevance_score": 0.85,
        "sectors": ["Information Technology"],
        "symbols": ["NIFTY50"],
        "published_at": datetime.now(UTC).isoformat(),
    }
    defaults.update(kwargs)
    return defaults


def _make_sector_response(**kwargs: Any) -> SectorRankingResponse:
    """Return a real SectorRankingResponse so Pydantic validation passes."""
    defaults = {
        "sector": "Information Technology",
        "performance_1d": 1.5,
        "performance_1w": 3.2,
        "performance_1m": 7.8,
        "performance_3m": 12.1,
        "performance_1y": 25.4,
        "top_gainers": [],
        "top_losers": [],
    }
    defaults.update(kwargs)
    return SectorRankingResponse(**defaults)


def _make_index_performance_dict() -> dict[str, dict[str, Any]]:
    """Return a dict matching MarketOverviewResponse.index_performance type."""
    return {
        "Nifty 50": {"value": 24500.0, "change_pct": 0.8, "symbol": "^NSEI"},
        "Sensex": {"value": 80000.0, "change_pct": 0.7, "symbol": "^BSESN"},
    }


# ---------------------------------------------------------------------------
# Tests: GET /api/v1/market/news
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestMarketNews:
    """Tests for the /market/news endpoint."""

    async def test_news_returns_list_on_cache_miss(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        """News endpoint returns a list when cache is empty and fetch returns no items."""
        with (
            patch(
                "app.presentation.api.v1.market_routes.cache_repo.get",
                new_callable=AsyncMock,
                return_value=None,
            ),
            patch(
                "app.presentation.api.v1.market_routes.cache_repo.set",
                new_callable=AsyncMock,
            ),
            patch(
                "app.presentation.api.v1.market_routes.fetch_and_analyze_news",
                new_callable=AsyncMock,
                return_value=[],
            ),
        ):
            resp = await client.get("/api/v1/market/news", headers=auth_headers)
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    async def test_news_with_sector_filter(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        """News endpoint should accept a sector query param."""
        with (
            patch(
                "app.presentation.api.v1.market_routes.cache_repo.get",
                new_callable=AsyncMock,
                return_value=None,
            ),
            patch(
                "app.presentation.api.v1.market_routes.cache_repo.set",
                new_callable=AsyncMock,
            ),
            patch(
                "app.presentation.api.v1.market_routes.fetch_and_analyze_news",
                new_callable=AsyncMock,
                return_value=[],
            ),
        ):
            resp = await client.get(
                "/api/v1/market/news",
                params={"sector": "Technology"},
                headers=auth_headers,
            )
        assert resp.status_code == 200

    async def test_news_served_from_cache(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        """News endpoint serves from cache when available."""
        cached_news = [_make_news_dict()]
        with (
            patch(
                "app.presentation.api.v1.market_routes.cache_repo.get",
                new_callable=AsyncMock,
                return_value=cached_news,
            ),
        ):
            resp = await client.get("/api/v1/market/news", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["title"] == "Nifty 50 hits all-time high"

    async def test_news_skip_limit_with_cache(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        """News endpoint slices results with skip/limit from cache."""
        cached_news = [_make_news_dict(id=f"news-{i}", title=f"Story {i}") for i in range(5)]
        with (
            patch(
                "app.presentation.api.v1.market_routes.cache_repo.get",
                new_callable=AsyncMock,
                return_value=cached_news,
            ),
        ):
            resp = await client.get(
                "/api/v1/market/news",
                params={"skip": 2, "limit": 2},
                headers=auth_headers,
            )
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 2

    async def test_news_fallback_on_fetch_error(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        """News endpoint returns empty list when RSS fetch raises an exception."""
        with (
            # Patch at the import site in market_routes, not at the definition site
            patch(
                "app.presentation.api.v1.market_routes.fetch_and_analyze_news",
                new_callable=AsyncMock,
                side_effect=RuntimeError("RSS feed unavailable"),
            ),
            patch(
                "app.presentation.api.v1.market_routes.cache_repo.get",
                new_callable=AsyncMock,
                return_value=None,
            ),
            patch(
                "app.presentation.api.v1.market_routes.cache_repo.set",
                new_callable=AsyncMock,
            ),
        ):
            resp = await client.get("/api/v1/market/news", headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json() == []


# ---------------------------------------------------------------------------
# Tests: GET /api/v1/market/sectors
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestMarketSectors:
    """Tests for the /market/sectors endpoint."""

    async def test_sectors_returns_list_from_cache(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        """Sectors served from cache as list of SectorRankingResponse."""
        # Cache returns pre-serialized dicts (as the route does model_dump() before caching)
        cached = [_make_sector_response().model_dump(), _make_sector_response(sector="Finance").model_dump()]
        with (
            patch(
                "app.presentation.api.v1.market_routes.cache_repo.get",
                new_callable=AsyncMock,
                return_value=cached,
            ),
        ):
            resp = await client.get("/api/v1/market/sectors", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 2
        assert data[0]["sector"] == "Information Technology"

    async def test_sectors_live_fetch_uses_gather(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        """On cache miss, sectors are fetched via _fetch_sector_perf (mocked)."""
        fake = _make_sector_response()
        with (
            patch(
                "app.presentation.api.v1.market_routes.cache_repo.get",
                new_callable=AsyncMock,
                return_value=None,
            ),
            patch(
                "app.presentation.api.v1.market_routes.cache_repo.set",
                new_callable=AsyncMock,
            ),
            # _fetch_sector_perf is called once per sector in SECTOR_MAP (15 sectors)
            patch(
                "app.presentation.api.v1.market_routes._fetch_sector_perf",
                new_callable=AsyncMock,
                return_value=fake,
            ),
        ):
            resp = await client.get("/api/v1/market/sectors", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        # 15 entries (one per SECTOR_MAP entry)
        assert len(data) == 15
        assert data[0]["sector"] == "Information Technology"

    async def test_sectors_fallback_on_gather_error(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        """On gather failure, sectors route returns placeholder data (not 500)."""
        with (
            patch(
                "app.presentation.api.v1.market_routes.cache_repo.get",
                new_callable=AsyncMock,
                return_value=None,
            ),
            patch(
                "app.presentation.api.v1.market_routes.cache_repo.set",
                new_callable=AsyncMock,
            ),
            patch(
                "app.presentation.api.v1.market_routes._fetch_sector_perf",
                new_callable=AsyncMock,
                side_effect=RuntimeError("yFinance down"),
            ),
        ):
            resp = await client.get("/api/v1/market/sectors", headers=auth_headers)
        # Route catches Exception and returns placeholder list — NOT 500
        assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Tests: GET /api/v1/market/overview
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestMarketOverview:
    """Tests for the /market/overview endpoint."""

    def _common_patches(self) -> list:
        """Return the common set of patches needed for overview endpoint tests."""
        fake_sector = _make_sector_response()
        return [
            # cache_repo.get returns None → forces live fetch for both news and sectors
            patch(
                "app.presentation.api.v1.market_routes.cache_repo.get",
                new_callable=AsyncMock,
                return_value=None,
            ),
            patch(
                "app.presentation.api.v1.market_routes.cache_repo.set",
                new_callable=AsyncMock,
            ),
            # fetch_and_analyze_news → empty list (patched at import site)
            patch(
                "app.presentation.api.v1.market_routes.fetch_and_analyze_news",
                new_callable=AsyncMock,
                return_value=[],
            ),
            # _fetch_sector_perf → real SectorRankingResponse (NOT MagicMock)
            patch(
                "app.presentation.api.v1.market_routes._fetch_sector_perf",
                new_callable=AsyncMock,
                return_value=fake_sector,
            ),
            # market_data_service imported inside function body → patch at definition site
            patch(
                "app.infrastructure.market.market_data_service.market_data_service.get_macro_indicators",
                new_callable=AsyncMock,
                return_value={"gdp_growth": 7.2, "inflation_rate": 4.8},
            ),
            # index_performance MUST be dict[str, dict] — not a list!
            patch(
                "app.infrastructure.market.market_data_service.market_data_service.get_index_performance",
                new_callable=AsyncMock,
                return_value=_make_index_performance_dict(),
            ),
        ]

    async def test_overview_returns_correct_structure(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        """Market overview should return news, sector_rankings, and updated_at."""
        patches = self._common_patches()
        with patches[0], patches[1], patches[2], patches[3], patches[4], patches[5]:
            resp = await client.get("/api/v1/market/overview", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert "news" in data
        assert "sector_rankings" in data
        assert "updated_at" in data
        assert isinstance(data["news"], list)
        assert isinstance(data["sector_rankings"], list)

    async def test_overview_no_auth_required(self, client: AsyncClient) -> None:
        """Market overview is a public endpoint — should NOT return 401."""
        patches = self._common_patches()
        with patches[0], patches[1], patches[2], patches[3], patches[4], patches[5]:
            resp = await client.get("/api/v1/market/overview")
        # 401 would indicate auth guard accidentally added — regression
        assert resp.status_code != 401

    async def test_overview_macro_indicators_in_response(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        """Market overview response should include macro_indicators dict."""
        patches = self._common_patches()
        with patches[0], patches[1], patches[2], patches[3], patches[4], patches[5]:
            resp = await client.get("/api/v1/market/overview", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert "macro_indicators" in data
        assert isinstance(data["macro_indicators"], dict)
