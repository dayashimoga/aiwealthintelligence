"""Goal planning API routes.

Provides endpoints for creating and managing financial goals
including retirement planning, emergency fund, wealth building, etc.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.database.models import GoalModel
from app.infrastructure.database.session import get_db_session
from app.presentation.middleware.auth_dependency import get_current_user

router = APIRouter()


class GoalCreate(BaseModel):
    """Schema for creating a new goal."""

    name: str = Field(min_length=1, max_length=255)
    goal_type: str = "custom"
    target_amount: float = Field(ge=0)
    current_amount: float = Field(ge=0, default=0)
    monthly_contribution: float = Field(ge=0, default=0)
    target_date: str | None = None
    expected_return_rate: float = Field(ge=0, le=100, default=12.0)
    inflation_rate: float = Field(ge=0, le=100, default=6.0)
    linked_portfolio_id: str | None = None
    notes: str = ""


class GoalUpdate(BaseModel):
    """Schema for updating a goal."""

    name: str | None = None
    current_amount: float | None = None
    monthly_contribution: float | None = None
    target_amount: float | None = None
    target_date: str | None = None
    expected_return_rate: float | None = None
    is_active: bool | None = None
    notes: str | None = None


def _goal_to_dict(goal: GoalModel) -> dict[str, Any]:
    """Serialize a GoalModel to a dictionary."""
    progress = 0.0
    if goal.target_amount and goal.target_amount > 0:
        progress = min(100.0, (float(goal.current_amount or 0) / float(goal.target_amount)) * 100)

    # Calculate months remaining
    months_remaining = None
    if goal.target_date:
        delta = goal.target_date - datetime.now(timezone.utc)
        months_remaining = max(0, delta.days // 30)

    # Calculate required monthly SIP to reach goal
    required_monthly = 0.0
    shortfall = float(goal.target_amount or 0) - float(goal.current_amount or 0)
    if shortfall > 0 and months_remaining and months_remaining > 0:
        monthly_rate = float(goal.expected_return_rate or 12) / 100 / 12
        if monthly_rate > 0:
            # Future value of annuity formula
            factor = ((1 + monthly_rate) ** months_remaining - 1) / monthly_rate
            required_monthly = shortfall / factor if factor > 0 else shortfall / months_remaining
        else:
            required_monthly = shortfall / months_remaining

    return {
        "id": goal.id,
        "name": goal.name,
        "goal_type": goal.goal_type,
        "target_amount": float(goal.target_amount or 0),
        "current_amount": float(goal.current_amount or 0),
        "monthly_contribution": float(goal.monthly_contribution or 0),
        "target_date": goal.target_date.isoformat() if goal.target_date else None,
        "expected_return_rate": float(goal.expected_return_rate or 12),
        "inflation_rate": float(goal.inflation_rate or 6),
        "linked_portfolio_id": goal.linked_portfolio_id,
        "is_active": goal.is_active,
        "notes": goal.notes,
        "progress_pct": round(progress, 1),
        "months_remaining": months_remaining,
        "required_monthly_sip": round(required_monthly, 2),
        "shortfall": round(max(0, shortfall), 2),
        "created_at": goal.created_at.isoformat() if goal.created_at else None,
    }


@router.get("/goals")
async def list_goals(
    active_only: bool = True,
    current_user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    """List all goals for the current user."""
    stmt = (
        select(GoalModel)
        .where(GoalModel.user_id == current_user["sub"])
        .order_by(GoalModel.created_at.desc())
    )
    if active_only:
        stmt = stmt.where(GoalModel.is_active == True)  # noqa: E712
    result = await session.execute(stmt)
    goals = list(result.scalars().all())
    return {"goals": [_goal_to_dict(g) for g in goals]}


@router.post("/goals", status_code=201)
async def create_goal(
    data: GoalCreate,
    current_user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    """Create a new financial goal."""
    target_date = None
    if data.target_date:
        try:
            target_date = datetime.fromisoformat(data.target_date)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=f"Invalid date format: {e}") from e

    goal = GoalModel(
        id=str(uuid.uuid4()),
        user_id=current_user["sub"],
        name=data.name,
        goal_type=data.goal_type,
        target_amount=data.target_amount,
        current_amount=data.current_amount,
        monthly_contribution=data.monthly_contribution,
        target_date=target_date,
        expected_return_rate=data.expected_return_rate,
        inflation_rate=data.inflation_rate,
        linked_portfolio_id=data.linked_portfolio_id,
        notes=data.notes,
    )
    session.add(goal)
    await session.commit()
    await session.refresh(goal)
    return _goal_to_dict(goal)


@router.put("/goals/{goal_id}")
async def update_goal(
    goal_id: str,
    data: GoalUpdate,
    current_user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    """Update a financial goal."""
    stmt = select(GoalModel).where(
        GoalModel.id == goal_id,
        GoalModel.user_id == current_user["sub"],
    )
    result = await session.execute(stmt)
    goal = result.scalar_one_or_none()
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")

    update_data = data.model_dump(exclude_unset=True)
    if "target_date" in update_data and update_data["target_date"]:
        try:
            update_data["target_date"] = datetime.fromisoformat(update_data["target_date"])
        except ValueError as e:
            raise HTTPException(status_code=400, detail=f"Invalid date format: {e}") from e

    for key, value in update_data.items():
        setattr(goal, key, value)

    await session.commit()
    await session.refresh(goal)
    return _goal_to_dict(goal)


@router.delete("/goals/{goal_id}", status_code=204)
async def delete_goal(
    goal_id: str,
    current_user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> None:
    """Delete a financial goal."""
    stmt = select(GoalModel).where(
        GoalModel.id == goal_id,
        GoalModel.user_id == current_user["sub"],
    )
    result = await session.execute(stmt)
    goal = result.scalar_one_or_none()
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")

    await session.delete(goal)
    await session.commit()
