"""Integration tests for notification routes matching actual API structure.

Actual routes:
  GET  /notifications              → {"notifications": [...], "unread_count": N}
  POST /notifications/{id}/read   → {"success": bool}
  POST /notifications/read-all    → {"marked_read": N}
  GET  /notifications/count       → {"unread_count": N}
"""

from __future__ import annotations

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestNotificationRoutes:
    async def test_list_notifications_returns_dict(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        """List notifications returns dict with 'notifications' and 'unread_count'."""
        resp = await client.get("/api/v1/notifications", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert "notifications" in data
        assert "unread_count" in data
        assert isinstance(data["notifications"], list)
        assert isinstance(data["unread_count"], int)

    async def test_list_notifications_unauthenticated(self, client: AsyncClient) -> None:
        resp = await client.get("/api/v1/notifications")
        assert resp.status_code == 401

    async def test_notification_unread_count(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        resp = await client.get("/api/v1/notifications/count", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert "unread_count" in data
        assert isinstance(data["unread_count"], int)
        assert data["unread_count"] >= 0

    async def test_mark_all_read(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        resp = await client.post(
            "/api/v1/notifications/read-all",
            headers=auth_headers,
        )
        assert resp.status_code in (200, 204)

    async def test_mark_all_read_response_structure(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        """mark-all returns {'marked_read': N}."""
        resp = await client.post(
            "/api/v1/notifications/read-all",
            headers=auth_headers,
        )
        if resp.status_code == 200:
            data = resp.json()
            assert "marked_read" in data

    async def test_mark_read_nonexistent_graceful(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        """Marking a non-existent notification doesn't cause 500."""
        resp = await client.post(
            "/api/v1/notifications/00000000-0000-0000-0000-000000000000/read",
            headers=auth_headers,
        )
        assert resp.status_code != 500

    async def test_list_with_unread_only_filter(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        """unread_only filter is accepted (bool query param)."""
        resp = await client.get(
            "/api/v1/notifications",
            params={"unread_only": "false"},
            headers=auth_headers,
        )
        assert resp.status_code == 200

    async def test_list_with_limit(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        resp = await client.get(
            "/api/v1/notifications",
            params={"limit": 5},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["notifications"]) <= 5
