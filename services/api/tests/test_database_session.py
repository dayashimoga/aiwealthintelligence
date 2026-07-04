"""Tests for DatabaseSessionManager covering initialization, session management, and exceptions."""

from __future__ import annotations

import pytest
from sqlalchemy import text
from app.infrastructure.database.session import DatabaseSessionManager, get_db_session


@pytest.mark.asyncio
async def test_session_manager_lifecycle() -> None:
    """DatabaseSessionManager lifecycle: init, create_all, connect, session, rollback, close."""
    manager = DatabaseSessionManager()
    
    # Test error before init
    with pytest.raises(RuntimeError, match="DatabaseSessionManager is not initialized"):
        await manager.create_all()
        
    with pytest.raises(RuntimeError, match="DatabaseSessionManager is not initialized"):
        async with manager.connect():
            pass
            
    with pytest.raises(RuntimeError, match="DatabaseSessionManager is not initialized"):
        async with manager.session():
            pass

    # Initialize with in-memory SQLite and mock settings to return is_sqlite = True
    from unittest.mock import MagicMock, patch
    with patch("app.infrastructure.database.session.get_settings") as mock_get_settings:
        mock_settings = MagicMock()
        mock_settings.is_sqlite = True
        mock_settings.APP_DEBUG = False
        mock_settings.APP_ENV = "testing"
        mock_get_settings.return_value = mock_settings
        
        db_url = "sqlite+aiosqlite:///:memory:"
        manager.init(db_url)
    
    assert manager._engine is not None
    assert manager._sessionmaker is not None
    
    # Create tables
    await manager.create_all()
    
    # Test raw connection query
    async with manager.connect() as conn:
        result = await conn.execute(text("SELECT 1"))
        val = result.scalar()
        assert val == 1
        
    # Test connect rollback on error
    with pytest.raises(ValueError, match="Force rollback"):
        async with manager.connect() as conn:
            await conn.execute(text("SELECT 1"))
            raise ValueError("Force rollback")
            
    # Test ORM session commit
    async with manager.session() as session:
        res = await session.execute(text("SELECT 2"))
        assert res.scalar() == 2
        
    # Test ORM session rollback on error
    with pytest.raises(RuntimeError, match="Force rollback ORM"):
        async with manager.session() as session:
            await session.execute(text("SELECT 2"))
            raise RuntimeError("Force rollback ORM")
            
    # Test FastAPI dependency generator
    with patch("app.infrastructure.database.session.sessionmanager", manager):
        async for sess in get_db_session():
            assert sess is not None
            break # We only need to check the first yield
        
    # Close manager
    await manager.close()
    assert manager._engine is None
    
    # Close is idempotent
    await manager.close()
