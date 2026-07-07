"""Redis implementation of the CacheRepository interface.

Supports async operations and provides a fallback in-memory cache
if Redis is unavailable or not configured.
"""

from __future__ import annotations

import json
from typing import Any

import redis.asyncio as aioredis
import structlog

from app.config import get_settings
from app.domain.repositories import CacheRepository

logger = structlog.get_logger(__name__)


class RedisCacheRepository(CacheRepository):
    """Cache implementation using Redis with local in-memory fallback."""

    def __init__(self, redis_url: str | None = None) -> None:
        self._redis_url = redis_url or get_settings().REDIS_URL
        self._client: aioredis.Redis | None = None
        self._memory_cache: dict[str, tuple[Any, float]] = {}  # key -> (value, expiry_timestamp)
        self._is_connected = False

    async def connect(self) -> None:
        """Initialize connection to Redis."""
        if not self._redis_url:
            logger.info("redis_url_not_configured_using_memory_cache")
            return

        try:
            self._client = aioredis.from_url(
                self._redis_url,
                decode_responses=True,
                socket_timeout=2.0,
            )
            # Ping to verify connection
            await self._client.ping()
            self._is_connected = True
            logger.info("redis_cache_connected")
        except Exception as e:
            logger.warning("redis_connection_failed_falling_back_to_memory", error=str(e))
            self._client = None
            self._is_connected = False

    def _get_time(self) -> float:
        import time

        return time.time()

    async def get(self, key: str) -> Any | None:
        if self._is_connected and self._client:
            try:
                val = await self._client.get(key)
                if val is not None:
                    return json.loads(val)
            except Exception as e:
                logger.warning("redis_get_failed", key=key, error=str(e))

        # Fallback to memory cache
        if key in self._memory_cache:
            val, expiry = self._memory_cache[key]
            if expiry is None or expiry > self._get_time():
                return val
            # Clean up expired key
            del self._memory_cache[key]
        return None

    async def set(self, key: str, value: Any, ttl: int | None = None) -> None:
        # Save to Redis
        if self._is_connected and self._client:
            try:
                serialized = json.dumps(value)
                await self._client.set(key, serialized, ex=ttl)
                return
            except Exception as e:
                logger.warning("redis_set_failed", key=key, error=str(e))

        # Fallback to memory cache
        expiry = (self._get_time() + ttl) if ttl is not None else None
        self._memory_cache[key] = (value, expiry)

    async def delete(self, key: str) -> None:
        if self._is_connected and self._client:
            try:
                await self._client.delete(key)
                return
            except Exception as e:
                logger.warning("redis_delete_failed", key=key, error=str(e))

        if key in self._memory_cache:
            del self._memory_cache[key]

    async def exists(self, key: str) -> bool:
        if self._is_connected and self._client:
            try:
                return bool(await self._client.exists(key))
            except Exception as e:
                logger.warning("redis_exists_failed", key=key, error=str(e))

        if key in self._memory_cache:
            _, expiry = self._memory_cache[key]
            if expiry is None or expiry > self._get_time():
                return True
            del self._memory_cache[key]
        return False


# Singleton instance
cache_repo = RedisCacheRepository()
