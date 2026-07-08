"""Integration tests for goal routes matching actual API structure.

Actual routes:
  GET    /goals               → {"goals": [...], "total": N}
  POST   /goals               → goal dict (201)
  PUT    /goals/{id}          → goal dict
  DELETE /goals/{id}          → 204
  (No GET /goals/{id} — list and manage by ID via PUT/DELETE)
"""

from __future__ import annotations

from typing import Any

import pytest
from httpx import AsyncClient


@pytest.fixture
async def sample_goal(
    client: AsyncClient, auth_headers: dict[str, str]
) -> dict[str, Any]:
    resp = await client.post(
        "/api/v1/goals",
        json={
            "name": "Retirement Fund",
            "target_amount": 10000000.0,
            "goal_type": "retirement",
        },
        headers=auth_headers,
    )
    assert resp.status_code == 201, f"Goal create failed: {resp.text}"
    return resp.json()


@pytest.mark.asyncio
class TestGoalCRUD:
    async def test_create_goal(self, client: AsyncClient, auth_headers: dict) -> None:
        resp = await client.post(
            "/api/v1/goals",
            json={
                "name": "Emergency Fund",
                "target_amount": 600000.0,
                "goal_type": "emergency_fund",
            },
            headers=auth_headers,
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["name"] == "Emergency Fund"
        assert "id" in data

    async def test_list_goals(
        self, client: AsyncClient, auth_headers: dict, sample_goal: dict
    ) -> None:
        """List goals — response structure is {'goals': [...], 'total': N}."""
        resp = await client.get("/api/v1/goals", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        # Either list or dict with 'goals' key
        if isinstance(data, dict):
            goals = data.get("goals", [])
        else:
            goals = data
        ids = [g["id"] for g in goals]
        assert sample_goal["id"] in ids

    async def test_goals_require_auth(self, client: AsyncClient) -> None:
        resp = await client.get("/api/v1/goals")
        assert resp.status_code == 401

    async def test_update_goal(
        self, client: AsyncClient, auth_headers: dict, sample_goal: dict
    ) -> None:
        gid = sample_goal["id"]
        resp = await client.put(
            f"/api/v1/goals/{gid}",
            json={"name": "Updated Retirement", "target_amount": 20000000.0},
            headers=auth_headers,
        )
        assert resp.status_code in (200, 204)

    async def test_delete_goal(
        self, client: AsyncClient, auth_headers: dict, sample_goal: dict
    ) -> None:
        gid = sample_goal["id"]
        resp = await client.delete(f"/api/v1/goals/{gid}", headers=auth_headers)
        assert resp.status_code == 204

    async def test_create_goal_missing_required_fields(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        """Missing target_amount should return 422."""
        resp = await client.post(
            "/api/v1/goals",
            json={"name": "Incomplete"},
            headers=auth_headers,
        )
        assert resp.status_code == 422

    async def test_update_nonexistent_goal(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        resp = await client.put(
            "/api/v1/goals/00000000-0000-0000-0000-000000000000",
            json={"name": "Ghost"},
            headers=auth_headers,
        )
        assert resp.status_code in (404, 422)

    async def test_delete_nonexistent_goal(
        self, client: AsyncClient, auth_headers: dict
    ) -> None:
        resp = await client.delete(
            "/api/v1/goals/00000000-0000-0000-0000-000000000000",
            headers=auth_headers,
        )
        assert resp.status_code in (204, 404)
