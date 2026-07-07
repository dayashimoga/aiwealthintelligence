"""Notification API routes.

Provides endpoints for listing, reading, and managing user notifications.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.database.session import get_db_session
from app.infrastructure.services.notification_service import notification_service
from app.presentation.middleware.auth_dependency import get_current_user

router = APIRouter()


@router.get("/notifications")
async def list_notifications(
    unread_only: bool = False,
    limit: int = 50,
    current_user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    """List notifications for the current user."""
    notifications = await notification_service.list_notifications(
        session,
        user_id=current_user["sub"],
        unread_only=unread_only,
        limit=limit,
    )
    unread_count = await notification_service.get_unread_count(session, user_id=current_user["sub"])
    return {
        "notifications": [
            {
                "id": n.id,
                "title": n.title,
                "body": n.body,
                "category": n.category,
                "priority": n.priority,
                "is_read": n.is_read,
                "metadata": n.extra_data,
                "created_at": n.created_at.isoformat() if n.created_at else None,
            }
            for n in notifications
        ],
        "unread_count": unread_count,
    }


@router.post("/notifications/{notification_id}/read")
async def mark_notification_read(
    notification_id: str,
    current_user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    """Mark a single notification as read."""
    success = await notification_service.mark_read(
        session,
        user_id=current_user["sub"],
        notification_id=notification_id,
    )
    await session.commit()
    return {"success": success}


@router.post("/notifications/read-all")
async def mark_all_notifications_read(
    current_user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    """Mark all notifications as read for the current user."""
    count = await notification_service.mark_all_read(session, user_id=current_user["sub"])
    await session.commit()
    return {"marked_read": count}


@router.get("/notifications/count")
async def get_unread_count(
    current_user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    """Get count of unread notifications."""
    count = await notification_service.get_unread_count(session, user_id=current_user["sub"])
    return {"unread_count": count}
