"""Caching utilities for market price and fundamental data.

Implements short TTL (1 min) caching for live prices and longer TTL (1 hour)
caching for company fundamentals and index indicators.
"""

from __future__ import annotations

from typing import Any

from app.infrastructure.repositories.redis_cache import cache_repo

LIVE_PRICE_TTL = 60  # 1 minute
FUNDAMENTALS_TTL = 3600  # 1 hour
INDEX_TTL = 300  # 5 minutes


async def get_cached_price(symbol: str) -> float | None:
    """Retrieve cached live price for a symbol."""
    key = f"price:{symbol.upper()}"
    val = await cache_repo.get(key)
    return float(val) if val is not None else None


async def set_cached_price(symbol: str, price: float) -> None:
    """Cache live price for a symbol."""
    key = f"price:{symbol.upper()}"
    await cache_repo.set(key, price, ttl=LIVE_PRICE_TTL)


async def get_cached_fundamentals(symbol: str) -> dict[str, Any] | None:
    """Retrieve cached fundamentals for a symbol."""
    key = f"fundamental:{symbol.upper()}"
    return await cache_repo.get(key)


async def set_cached_fundamentals(symbol: str, data: dict[str, Any]) -> None:
    """Cache fundamentals for a symbol."""
    key = f"fundamental:{symbol.upper()}"
    await cache_repo.set(key, data, ttl=FUNDAMENTALS_TTL)


async def get_cached_index_performance() -> dict[str, Any] | None:
    """Retrieve cached index performance data."""
    return await cache_repo.get("index:performance")


async def set_cached_index_performance(data: dict[str, Any]) -> None:
    """Cache index performance data."""
    await cache_repo.set("index:performance", data, ttl=INDEX_TTL)
