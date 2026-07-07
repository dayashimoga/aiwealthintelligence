"""Tests for market data services, news fetching, and caching modules."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from app.infrastructure.market.market_data_service import _format_symbol
from app.infrastructure.market.news_fetcher import analyze_news_sentiment
from app.infrastructure.market.price_cache import get_cached_price, set_cached_price
from app.infrastructure.repositories.redis_cache import RedisCacheRepository


def test_format_symbol() -> None:
    """Symbols are formatted properly for Yahoo Finance API."""
    assert _format_symbol("TCS") == "TCS.NS"
    assert _format_symbol("RELIANCE.BO") == "RELIANCE.BO"
    assert _format_symbol("SBI", "mutual_fund") == "SBI.BO"


@pytest.mark.asyncio
async def test_price_cache() -> None:
    """Live prices can be stored in and retrieved from cache."""
    # We patch cache_repo in price_cache
    with patch(
        "app.infrastructure.market.price_cache.cache_repo", new_callable=AsyncMock
    ) as mock_cache:
        mock_cache.get.return_value = 1500.50

        price = await get_cached_price("INFY")
        assert price == 1500.50
        mock_cache.get.assert_called_once_with("price:INFY")

        await set_cached_price("INFY", 1520.00)
        mock_cache.set.assert_called_once_with("price:INFY", 1520.00, ttl=60)


@pytest.mark.asyncio
async def test_redis_cache_fallback() -> None:
    """RedisCacheRepository falls back to in-memory dictionary if Redis is disconnected."""
    cache = RedisCacheRepository(redis_url="redis://invalid_host:9999")
    await cache.connect()  # fails and enables memory cache

    assert not cache._is_connected

    await cache.set("test_key", {"foo": "bar"}, ttl=10)
    assert await cache.exists("test_key")

    val = await cache.get("test_key")
    assert val == {"foo": "bar"}

    await cache.delete("test_key")
    assert not await cache.exists("test_key")


@pytest.mark.asyncio
async def test_analyze_news_sentiment() -> None:
    """analyze_news_sentiment calls AI provider and returns structured sentiment."""
    mock_provider = AsyncMock()
    mock_provider.complete.return_value = (
        '{"sentiment": "positive", "relevance_score": 8.5, "summary": "TCS beats estimates", '
        '"sectors": ["Technology"], "symbols": ["TCS"]}'
    )

    with patch(
        "app.infrastructure.market.news_fetcher.get_ai_provider", return_value=mock_provider
    ):
        analysis = await analyze_news_sentiment(
            "TCS Q3 Results", "TCS reports 15% growth in net profit."
        )
        assert analysis["sentiment"] == "positive"
        assert analysis["relevance_score"] == 8.5
        assert analysis["summary"] == "TCS beats estimates"
