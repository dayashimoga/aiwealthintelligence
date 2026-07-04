"""SQLAlchemy database session management.

Provides async session factory with connection pooling and proper lifecycle management.
Supports both SQLite (development) and PostgreSQL (production).
"""

from __future__ import annotations

import contextlib
from collections.abc import AsyncIterator
from typing import Any

from sqlalchemy.ext.asyncio import (
    AsyncConnection,
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.config import get_settings


class DatabaseSessionManager:
    """Manages database engine and session lifecycle.

    This manager ensures proper initialization and cleanup of database connections.
    It provides async context managers for both raw connections and ORM sessions.
    """

    def __init__(self) -> None:
        self._engine: AsyncEngine | None = None
        self._sessionmaker: async_sessionmaker[AsyncSession] | None = None

    def init(self, database_url: str) -> None:
        """Initialize database engine and session factory."""
        settings = get_settings()
        global engine

        engine_kwargs: dict[str, Any] = {
            "echo": settings.APP_DEBUG and settings.APP_ENV == "development",
        }

        # PostgreSQL-specific settings
        if not settings.is_sqlite:
            engine_kwargs.update(
                {
                    "pool_size": settings.DATABASE_POOL_SIZE,
                    "max_overflow": settings.DATABASE_MAX_OVERFLOW,
                    "pool_pre_ping": True,
                    "pool_recycle": 3600,
                }
            )
        else:
            # SQLite requires check_same_thread=False for async
            if "?" not in database_url:
                database_url += "?check_same_thread=False"
            else:
                database_url += "&check_same_thread=False"

        self._engine = create_async_engine(database_url, **engine_kwargs)
        engine = self._engine
        self._sessionmaker = async_sessionmaker(
            bind=self._engine,
            autocommit=False,
            autoflush=False,
            expire_on_commit=False,
        )

    async def close(self) -> None:
        """Close database engine and all connections."""
        global engine
        if self._engine is None:
            return
        await self._engine.dispose()
        self._engine = None
        self._sessionmaker = None
        engine = None

    async def create_all(self) -> None:
        """Create all database tables."""
        if self._engine is None:
            msg = "DatabaseSessionManager is not initialized"
            raise RuntimeError(msg)
        from app.infrastructure.database.models import Base
        async with self._engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

    @contextlib.asynccontextmanager
    async def connect(self) -> AsyncIterator[AsyncConnection]:
        """Get a raw database connection."""
        if self._engine is None:
            msg = "DatabaseSessionManager is not initialized"
            raise RuntimeError(msg)

        async with self._engine.begin() as connection:
            try:
                yield connection
            except Exception:
                await connection.rollback()
                raise

    @contextlib.asynccontextmanager
    async def session(self) -> AsyncIterator[AsyncSession]:
        """Get an ORM session with automatic commit/rollback."""
        if self._sessionmaker is None:
            msg = "DatabaseSessionManager is not initialized"
            raise RuntimeError(msg)

        session = self._sessionmaker()
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# Global session manager instance
sessionmanager = DatabaseSessionManager()

# Engine reference for migrations
engine: AsyncEngine | None = None


async def get_db_session() -> AsyncIterator[AsyncSession]:
    """FastAPI dependency for database session injection."""
    async with sessionmanager.session() as session:
        yield session
