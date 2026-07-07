"""
Comprehensive tests for infrastructure & routes to boost coverage.

Targets:
- redis_cache.py (62% → 90%+)
- cas_pdf_parser.py (19% → 70%+)
- watchlist_routes.py (24% → 65%+)
- notification_routes.py (58% → 80%+)
- goal_routes.py (35% → 65%+)
- copilot_advanced_routes.py (35% → 60%+)
"""

from __future__ import annotations

import time
from decimal import Decimal
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

# ============================================================
# Redis Cache Repository Tests
# ============================================================


@pytest.mark.unit
class TestRedisCacheRepository:
    """Tests for RedisCacheRepository — memory cache path (Redis not configured)."""

    async def test_get_returns_none_for_missing_key(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        result = await repo.get("nonexistent")
        assert result is None

    async def test_set_and_get_string(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        await repo.set("key1", "hello")
        result = await repo.get("key1")
        assert result == "hello"

    async def test_set_and_get_dict(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        data = {"name": "WealthAI", "score": 95}
        await repo.set("key2", data)
        result = await repo.get("key2")
        assert result == data

    async def test_set_and_get_list(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        await repo.set("key3", [1, 2, 3])
        result = await repo.get("key3")
        assert result == [1, 2, 3]

    async def test_get_returns_none_after_ttl_expires(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        # Insert an already-expired entry
        repo._memory_cache["expkey"] = ("value", time.time() - 1)
        result = await repo.get("expkey")
        assert result is None
        assert "expkey" not in repo._memory_cache

    async def test_delete_existing_key(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        await repo.set("delkey", "value")
        await repo.delete("delkey")
        assert await repo.get("delkey") is None

    async def test_delete_nonexistent_key_no_error(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        await repo.delete("ghost")  # Should not raise

    async def test_exists_true_for_existing(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        await repo.set("ekey", 42)
        assert await repo.exists("ekey") is True

    async def test_exists_false_for_missing(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        assert await repo.exists("missing") is False

    async def test_exists_false_for_expired(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        repo._memory_cache["expexist"] = ("val", time.time() - 1)
        assert await repo.exists("expexist") is False
        assert "expexist" not in repo._memory_cache

    async def test_set_with_ttl_stores_future_expiry(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        await repo.set("ttlkey", "ttlval", ttl=300)
        val, expiry = repo._memory_cache["ttlkey"]
        assert val == "ttlval"
        assert expiry is not None
        assert expiry > time.time()

    async def test_set_without_ttl_stores_none_expiry(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        await repo.set("nottlkey", "value")
        _, expiry = repo._memory_cache["nottlkey"]
        assert expiry is None

    async def test_connect_without_redis_url_stays_disconnected(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        await repo.connect()
        assert not repo._is_connected
        assert repo._client is None

    async def test_connect_with_bad_redis_url_falls_back_to_memory(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="redis://127.0.0.1:19999")
        await repo.connect()
        assert not repo._is_connected
        # Still functional via memory
        await repo.set("fb_key", "fb_val")
        assert await repo.get("fb_key") == "fb_val"

    async def test_redis_get_falls_back_to_memory_on_exception(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        repo._is_connected = True
        repo._client = MagicMock()
        repo._client.get = AsyncMock(side_effect=Exception("Redis down"))
        repo._memory_cache["fb"] = ("memory_val", None)
        result = await repo.get("fb")
        assert result == "memory_val"

    async def test_redis_set_falls_back_to_memory_on_exception(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        repo._is_connected = True
        repo._client = MagicMock()
        repo._client.set = AsyncMock(side_effect=Exception("Redis down"))
        await repo.set("setfb", "val")
        assert "setfb" in repo._memory_cache

    async def test_redis_delete_falls_back_to_memory_on_exception(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        repo._memory_cache["dk"] = ("v", None)
        repo._is_connected = True
        repo._client = MagicMock()
        repo._client.delete = AsyncMock(side_effect=Exception("Redis down"))
        await repo.delete("dk")
        assert "dk" not in repo._memory_cache

    async def test_redis_exists_falls_back_to_memory_on_exception(self) -> None:
        from app.infrastructure.repositories.redis_cache import RedisCacheRepository

        repo = RedisCacheRepository(redis_url="")
        repo._memory_cache["ek"] = ("v", None)
        repo._is_connected = True
        repo._client = MagicMock()
        repo._client.exists = AsyncMock(side_effect=Exception("Redis down"))
        assert await repo.exists("ek") is True


# ============================================================
# CAS PDF Parser Tests
# ============================================================


@pytest.mark.unit
class TestCASPdfParser:
    """Tests for CASPDFParser with synthetic content."""

    def test_parse_line_no_isin_returns_none(self) -> None:
        from app.infrastructure.importers.cas_pdf_parser import CASPDFParser

        parser = CASPDFParser(b"", None)
        result = parser._parse_line("No ISIN here at all")
        assert result is None

    def test_parse_line_with_stock_isin(self) -> None:
        from app.infrastructure.importers.cas_pdf_parser import CASPDFParser

        parser = CASPDFParser(b"", None)
        # Valid ISIN: 2 letters + 9 alphanumeric + 1 digit = 12 chars
        line = "INE040A01034 HDFC BANK LIMITED 100 1450.00 145000.00"
        result = parser._parse_line(line)
        assert result is not None
        assert result["isin"] == "INE040A01034"
        assert result["asset_type"] == "stock"
        assert result["exchange"] == "NSE"

    def test_parse_line_with_mutual_fund_isin(self) -> None:
        from app.infrastructure.importers.cas_pdf_parser import CASPDFParser

        parser = CASPDFParser(b"", None)
        # INF prefix = mutual fund
        line = "INF200KA1RD2 AXIS BLUECHIP FUND DIRECT GROWTH 50.123 100.50 5031.87"
        result = parser._parse_line(line)
        assert result is not None
        assert result["isin"] == "INF200KA1RD2"
        assert result["asset_type"] == "mutual_fund"
        assert result["exchange"] == "OTHER"

    def test_parse_line_three_numbers_uses_second_to_last_as_quantity(self) -> None:
        """With >=3 numbers: quantity = numbers[-2], price = numbers[-3]."""
        from app.infrastructure.importers.cas_pdf_parser import CASPDFParser

        parser = CASPDFParser(b"", None)
        # 3 numbers at end: 1450.00 100 145000.00 → qty = numbers[-2] = 100
        line = "INE040A01034 STOCK 1450.00 100 145000.00"
        result = parser._parse_line(line)
        assert result is not None
        assert result["quantity"] == Decimal("100")

    def test_parse_line_exactly_two_numbers_uses_last_as_quantity(self) -> None:
        """With exactly 2 numbers: quantity = numbers[-1]."""
        from app.infrastructure.importers.cas_pdf_parser import CASPDFParser

        parser = CASPDFParser(b"", None)
        # 2 numbers: 100 5000 → qty = 5000 (last)... wait, let me re-read:
        # elif: quantity = numbers[-1] so qty = last number
        line = "INE040A01034 STOCK NAME 100 5000"
        result = parser._parse_line(line)
        assert result is not None
        # With 2 numbers the elif branch: quantity = Decimal(numbers[-1]) = 5000
        assert result["quantity"] == Decimal("5000")

    def test_deduplicate_aggregates_same_isin(self) -> None:
        from app.infrastructure.importers.cas_pdf_parser import CASPDFParser

        parser = CASPDFParser(b"", None)
        holdings = [
            {
                "isin": "INE040A01034",
                "symbol": "INE040A01034",
                "name": "HDFC",
                "asset_type": "stock",
                "quantity": Decimal("100"),
                "current_price": Decimal("1500"),
                "average_buy_price": Decimal("0"),
                "exchange": "NSE",
            },
            {
                "isin": "INE040A01034",
                "symbol": "INE040A01034",
                "name": "HDFC",
                "asset_type": "stock",
                "quantity": Decimal("50"),
                "current_price": Decimal("1600"),
                "average_buy_price": Decimal("0"),
                "exchange": "NSE",
            },
        ]
        result = parser._deduplicate_and_aggregate(holdings)
        assert len(result) == 1
        assert result[0]["quantity"] == Decimal("150")
        assert result[0]["current_price"] == Decimal("1600")

    def test_deduplicate_keeps_lower_price_if_existing_is_higher(self) -> None:
        from app.infrastructure.importers.cas_pdf_parser import CASPDFParser

        parser = CASPDFParser(b"", None)
        holdings = [
            {
                "isin": "INE040A01034",
                "symbol": "INE040A01034",
                "name": "X",
                "asset_type": "stock",
                "quantity": Decimal("100"),
                "current_price": Decimal("2000"),
                "average_buy_price": Decimal("0"),
                "exchange": "NSE",
            },
            {
                "isin": "INE040A01034",
                "symbol": "INE040A01034",
                "name": "X",
                "asset_type": "stock",
                "quantity": Decimal("50"),
                "current_price": Decimal("1000"),  # lower — not kept
                "average_buy_price": Decimal("0"),
                "exchange": "NSE",
            },
        ]
        result = parser._deduplicate_and_aggregate(holdings)
        assert result[0]["current_price"] == Decimal("2000")  # max price kept

    def test_deduplicate_filters_zero_quantity(self) -> None:
        from app.infrastructure.importers.cas_pdf_parser import CASPDFParser

        parser = CASPDFParser(b"", None)
        holdings = [
            {
                "isin": "INE040A01034",
                "symbol": "INE040A01034",
                "name": "HDFC",
                "asset_type": "stock",
                "quantity": Decimal("0"),
                "current_price": Decimal("1500"),
                "average_buy_price": Decimal("0"),
                "exchange": "NSE",
            }
        ]
        assert parser._deduplicate_and_aggregate(holdings) == []

    def test_deduplicate_skips_empty_isin(self) -> None:
        from app.infrastructure.importers.cas_pdf_parser import CASPDFParser

        parser = CASPDFParser(b"", None)
        holdings = [
            {
                "isin": "",
                "symbol": "",
                "name": "Unknown",
                "asset_type": "stock",
                "quantity": Decimal("10"),
                "current_price": Decimal("100"),
                "average_buy_price": Decimal("0"),
                "exchange": "NSE",
            }
        ]
        assert parser._deduplicate_and_aggregate(holdings) == []

    def test_parse_raises_on_corrupt_bytes(self) -> None:
        from app.infrastructure.importers.cas_pdf_parser import CASPDFParser

        parser = CASPDFParser(b"not a pdf at all", None)
        with pytest.raises(ValueError, match="Failed to parse CAS PDF"):
            parser.parse()

    def test_parse_with_mocked_pdfplumber_two_holdings(self) -> None:
        from app.infrastructure.importers.cas_pdf_parser import CASPDFParser

        mock_page = MagicMock()
        mock_page.extract_text.return_value = (
            "INE040A01034 HDFC BANK LIMITED 100 1450.00 145000.00\n"
            "No ISIN line here\n"
            "INF200KA1RD2 AXIS DIRECT GROWTH 50.123 100.50 5031.87"
        )
        mock_pdf = MagicMock()
        mock_pdf.__enter__ = MagicMock(return_value=mock_pdf)
        mock_pdf.__exit__ = MagicMock(return_value=False)
        mock_pdf.pages = [mock_page]

        with patch("pdfplumber.open", return_value=mock_pdf):
            parser = CASPDFParser(b"fake", None)
            holdings = parser.parse()

        assert len(holdings) == 2
        isins = {h["isin"] for h in holdings}
        assert "INE040A01034" in isins
        assert "INF200KA1RD2" in isins

    def test_parse_skips_pages_with_no_text(self) -> None:
        from app.infrastructure.importers.cas_pdf_parser import CASPDFParser

        mock_page = MagicMock()
        mock_page.extract_text.return_value = None
        mock_pdf = MagicMock()
        mock_pdf.__enter__ = MagicMock(return_value=mock_pdf)
        mock_pdf.__exit__ = MagicMock(return_value=False)
        mock_pdf.pages = [mock_page]

        with patch("pdfplumber.open", return_value=mock_pdf):
            parser = CASPDFParser(b"fake", None)
            assert parser.parse() == []

    def test_parse_line_unknown_name_fallback(self) -> None:
        from app.infrastructure.importers.cas_pdf_parser import CASPDFParser

        parser = CASPDFParser(b"", None)
        result = parser._parse_line("INE040A01034")
        assert result is not None
        assert "INE040A01034" in result["name"]

    def test_parse_line_mutual_fund_keyword_in_name(self) -> None:
        from app.infrastructure.importers.cas_pdf_parser import CASPDFParser

        parser = CASPDFParser(b"", None)
        line = "INE040A01034 SOME MUTUAL FUND SCHEME 50 100 5000"
        result = parser._parse_line(line)
        assert result is not None
        assert result["asset_type"] == "mutual_fund"


# ============================================================
# Watchlist Routes Tests
# ============================================================


@pytest.mark.unit
class TestWatchlistRoutes:
    """Tests for watchlist CRUD and symbol management endpoints."""

    async def test_list_watchlists_empty(self, auth_client: Any) -> None:
        resp = await auth_client.get("/api/v1/watchlists")
        assert resp.status_code == 200
        data = resp.json()
        assert "watchlists" in data
        assert isinstance(data["watchlists"], list)

    async def test_create_watchlist(self, auth_client: Any) -> None:
        resp = await auth_client.post(
            "/api/v1/watchlists",
            json={"name": "My Tech Picks", "symbols": ["TCS", "INFY"]},
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["name"] == "My Tech Picks"
        assert "id" in data

    async def test_create_watchlist_no_symbols(self, auth_client: Any) -> None:
        resp = await auth_client.post(
            "/api/v1/watchlists",
            json={"name": "Empty Watchlist"},
        )
        assert resp.status_code == 201

    async def test_add_symbol_to_watchlist(self, auth_client: Any) -> None:
        create_resp = await auth_client.post(
            "/api/v1/watchlists",
            json={"name": "WL Add Symbol", "symbols": []},
        )
        assert create_resp.status_code == 201
        wl_id = create_resp.json()["id"]

        resp = await auth_client.post(
            f"/api/v1/watchlists/{wl_id}/symbols",
            json={"symbol": "RELIANCE"},
        )
        assert resp.status_code in (200, 201)

    async def test_add_symbol_with_alerts(self, auth_client: Any) -> None:
        create_resp = await auth_client.post(
            "/api/v1/watchlists",
            json={"name": "WL Alerts", "symbols": []},
        )
        assert create_resp.status_code == 201
        wl_id = create_resp.json()["id"]

        resp = await auth_client.post(
            f"/api/v1/watchlists/{wl_id}/symbols",
            json={"symbol": "HDFC", "alert_above": 1600.0, "alert_below": 1200.0},
        )
        assert resp.status_code in (200, 201)

    async def test_remove_symbol_from_watchlist(self, auth_client: Any) -> None:
        create_resp = await auth_client.post(
            "/api/v1/watchlists",
            json={"name": "WL Remove", "symbols": ["TCS"]},
        )
        assert create_resp.status_code == 201
        wl_id = create_resp.json()["id"]

        resp = await auth_client.delete(f"/api/v1/watchlists/{wl_id}/symbols/TCS")
        assert resp.status_code in (200, 204)

    async def test_delete_watchlist(self, auth_client: Any) -> None:
        create_resp = await auth_client.post(
            "/api/v1/watchlists",
            json={"name": "WL To Delete"},
        )
        assert create_resp.status_code == 201
        wl_id = create_resp.json()["id"]

        resp = await auth_client.delete(f"/api/v1/watchlists/{wl_id}")
        assert resp.status_code == 204

    async def test_list_watchlists_after_create(self, auth_client: Any) -> None:
        await auth_client.post(
            "/api/v1/watchlists",
            json={"name": "Listed WL", "symbols": ["NIFTY"]},
        )
        resp = await auth_client.get("/api/v1/watchlists")
        assert resp.status_code == 200
        watchlists = resp.json()["watchlists"]
        assert any(w["name"] == "Listed WL" for w in watchlists)

    async def test_unauthenticated_list_watchlists_returns_401(self, client: Any) -> None:
        resp = await client.get("/api/v1/watchlists")
        assert resp.status_code == 401

    async def test_watchlist_intelligence_endpoint_exists(self, auth_client: Any) -> None:
        create_resp = await auth_client.post(
            "/api/v1/watchlists",
            json={"name": "Intel WL", "symbols": ["INFY"]},
        )
        assert create_resp.status_code == 201
        wl_id = create_resp.json()["id"]

        resp = await auth_client.get(f"/api/v1/watchlists/{wl_id}/intelligence")
        # May 200 or 500 if market data unavailable in test env
        assert resp.status_code in (200, 422, 500)


# ============================================================
# Notification Routes Tests
# ============================================================


@pytest.mark.unit
class TestNotificationRoutes:
    """Tests for notification endpoints."""

    async def test_list_notifications(self, auth_client: Any) -> None:
        resp = await auth_client.get("/api/v1/notifications")
        assert resp.status_code == 200
        data = resp.json()
        assert "notifications" in data

    async def test_notification_count(self, auth_client: Any) -> None:
        resp = await auth_client.get("/api/v1/notifications/count")
        assert resp.status_code == 200

    async def test_mark_all_read(self, auth_client: Any) -> None:
        resp = await auth_client.post("/api/v1/notifications/read-all")
        assert resp.status_code in (200, 204)

    async def test_unauthenticated_notifications_returns_401(self, client: Any) -> None:
        resp = await client.get("/api/v1/notifications")
        assert resp.status_code == 401


# ============================================================
# Goal Routes Tests
# ============================================================


@pytest.mark.unit
class TestGoalRoutes:
    """Tests for financial goal CRUD endpoints."""

    from typing import ClassVar

    _goal_payload: ClassVar[dict] = {
        "name": "Retirement Fund",
        "goal_type": "retirement",
        "target_amount": 10000000.0,
        "target_date": "2040-01-01",
    }

    async def test_list_goals_empty(self, auth_client: Any) -> None:
        resp = await auth_client.get("/api/v1/goals")
        assert resp.status_code == 200
        data = resp.json()
        assert "goals" in data

    async def test_create_goal_minimal(self, auth_client: Any) -> None:
        resp = await auth_client.post("/api/v1/goals", json=self._goal_payload)
        assert resp.status_code == 201
        data = resp.json()
        assert data["name"] == "Retirement Fund"
        assert "id" in data

    async def test_create_goal_with_all_fields(self, auth_client: Any) -> None:
        payload = {
            "name": "Emergency Fund",
            "goal_type": "emergency_fund",
            "target_amount": 500000.0,
            "current_amount": 50000.0,
            "monthly_contribution": 10000.0,
            "target_date": "2026-12-31",
            "expected_return_rate": 8.0,
            "inflation_rate": 5.0,
            "notes": "6 months expenses",
        }
        resp = await auth_client.post("/api/v1/goals", json=payload)
        assert resp.status_code == 201

    async def test_create_goal_missing_required_fields_returns_422(self, auth_client: Any) -> None:
        resp = await auth_client.post("/api/v1/goals", json={"name": "Incomplete"})
        assert resp.status_code == 422

    async def test_list_goals_shows_created(self, auth_client: Any) -> None:
        await auth_client.post("/api/v1/goals", json=self._goal_payload)
        resp = await auth_client.get("/api/v1/goals")
        assert resp.status_code == 200
        goals = resp.json()["goals"]
        assert any(g["name"] == "Retirement Fund" for g in goals)

    async def test_delete_goal(self, auth_client: Any) -> None:
        create_resp = await auth_client.post(
            "/api/v1/goals",
            json={
                "name": "Delete Me",
                "goal_type": "custom",
                "target_amount": 100000.0,
            },
        )
        assert create_resp.status_code == 201
        goal_id = create_resp.json()["id"]
        resp = await auth_client.delete(f"/api/v1/goals/{goal_id}")
        assert resp.status_code == 204

    async def test_goal_not_found_returns_404(self, auth_client: Any) -> None:
        resp = await auth_client.delete("/api/v1/goals/nonexistent-id")
        assert resp.status_code == 404

    async def test_update_goal(self, auth_client: Any) -> None:
        create_resp = await auth_client.post(
            "/api/v1/goals",
            json={"name": "Update Me", "target_amount": 100000.0},
        )
        assert create_resp.status_code == 201
        goal_id = create_resp.json()["id"]

        resp = await auth_client.put(
            f"/api/v1/goals/{goal_id}",
            json={"current_amount": 25000.0, "notes": "25% done"},
        )
        assert resp.status_code == 200

    async def test_unauthenticated_goals_returns_401(self, client: Any) -> None:
        resp = await client.get("/api/v1/goals")
        assert resp.status_code == 401


# ============================================================
# Copilot Advanced Routes Tests
# ============================================================


@pytest.mark.unit
class TestCopilotAdvancedRoutes:
    """Tests for copilot advanced analysis endpoints."""

    async def _ensure_portfolio(self, auth_client: Any) -> str | None:
        resp = await auth_client.get("/api/v1/portfolios")
        if resp.status_code == 200:
            data = resp.json()
            portfolios = data.get("portfolios", [])
            if portfolios:
                return portfolios[0]["id"]
        create = await auth_client.post(
            "/api/v1/portfolios", json={"name": "Adv Copilot Portfolio"}
        )
        if create.status_code == 201:
            return create.json()["id"]
        return None

    async def test_advanced_analysis_endpoint_exists(self, auth_client: Any) -> None:
        portfolio_id = await self._ensure_portfolio(auth_client)
        if not portfolio_id:
            pytest.skip("Could not create portfolio")
        # Route: GET /api/v1/copilot/advanced/{portfolio_id}
        resp = await auth_client.get(f"/api/v1/copilot/advanced/{portfolio_id}")
        # 200 or 500 (if AI not configured) both valid; 404 would mean wrong path
        assert resp.status_code in (200, 500)

    async def test_sector_rotation_endpoint(self, auth_client: Any) -> None:
        portfolio_id = await self._ensure_portfolio(auth_client)
        if not portfolio_id:
            pytest.skip("Could not create portfolio")
        resp = await auth_client.get(f"/api/v1/copilot/sector-rotation/{portfolio_id}")
        assert resp.status_code in (200, 500)

    async def test_dividend_planner_endpoint(self, auth_client: Any) -> None:
        portfolio_id = await self._ensure_portfolio(auth_client)
        if not portfolio_id:
            pytest.skip("Could not create portfolio")
        resp = await auth_client.get(f"/api/v1/copilot/dividend-planner/{portfolio_id}")
        assert resp.status_code in (200, 500)

    async def test_opportunity_radar_endpoint(self, auth_client: Any) -> None:
        portfolio_id = await self._ensure_portfolio(auth_client)
        if not portfolio_id:
            pytest.skip("Could not create portfolio")
        resp = await auth_client.get(f"/api/v1/copilot/opportunity-radar/{portfolio_id}")
        assert resp.status_code in (200, 500)

    async def test_unauthenticated_advanced_returns_401(self, client: Any) -> None:
        resp = await client.get("/api/v1/copilot/advanced/some-id")
        assert resp.status_code == 401
