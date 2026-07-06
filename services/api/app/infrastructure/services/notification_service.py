"""Notification service for smart alerts, reports, and user notifications.

Provides methods to create, list, mark-read, and auto-generate
notifications based on portfolio events and scheduled analysis.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

import structlog
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.database.models import NotificationModel

logger = structlog.get_logger(__name__)


class NotificationService:
    """Service for managing user notifications."""

    async def create_notification(
        self,
        session: AsyncSession,
        user_id: str,
        title: str,
        body: str,
        category: str = "system",
        priority: str = "medium",
        extra_data: dict[str, Any] | None = None,
    ) -> NotificationModel:
        """Create a new notification for a user."""
        notification = NotificationModel(
            id=str(uuid.uuid4()),
            user_id=user_id,
            title=title,
            body=body,
            category=category,
            priority=priority,
            extra_data=extra_data or {},
        )
        session.add(notification)
        await session.flush()
        logger.info(
            "notification_created",
            user_id=user_id,
            category=category,
            title=title,
        )
        return notification

    async def list_notifications(
        self,
        session: AsyncSession,
        user_id: str,
        unread_only: bool = False,
        limit: int = 50,
    ) -> list[NotificationModel]:
        """List notifications for a user, optionally filtering unread only."""
        stmt = (
            select(NotificationModel)
            .where(NotificationModel.user_id == user_id)
            .order_by(NotificationModel.created_at.desc())
            .limit(limit)
        )
        if unread_only:
            stmt = stmt.where(NotificationModel.is_read == False)  # noqa: E712
        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def mark_read(
        self,
        session: AsyncSession,
        user_id: str,
        notification_id: str,
    ) -> bool:
        """Mark a single notification as read."""
        stmt = (
            update(NotificationModel)
            .where(
                NotificationModel.id == notification_id,
                NotificationModel.user_id == user_id,
            )
            .values(is_read=True)
        )
        result = await session.execute(stmt)
        return result.rowcount > 0

    async def mark_all_read(
        self,
        session: AsyncSession,
        user_id: str,
    ) -> int:
        """Mark all notifications as read for a user."""
        stmt = (
            update(NotificationModel)
            .where(
                NotificationModel.user_id == user_id,
                NotificationModel.is_read == False,  # noqa: E712
            )
            .values(is_read=True)
        )
        result = await session.execute(stmt)
        return result.rowcount

    async def get_unread_count(
        self,
        session: AsyncSession,
        user_id: str,
    ) -> int:
        """Get count of unread notifications."""
        from sqlalchemy import func

        stmt = (
            select(func.count())
            .select_from(NotificationModel)
            .where(
                NotificationModel.user_id == user_id,
                NotificationModel.is_read == False,  # noqa: E712
            )
        )
        result = await session.execute(stmt)
        return result.scalar() or 0

    # ---- Smart Notification Generators ----

    async def generate_price_alert(
        self,
        session: AsyncSession,
        user_id: str,
        symbol: str,
        current_price: float,
        threshold_price: float,
        direction: str = "above",
    ) -> NotificationModel:
        """Generate a price alert notification."""
        title = f"Price Alert: {symbol}"
        body = (
            f"{symbol} has moved {direction} ₹{threshold_price:,.2f}. "
            f"Current price: ₹{current_price:,.2f}"
        )
        return await self.create_notification(
            session,
            user_id=user_id,
            title=title,
            body=body,
            category="price_alert",
            priority="high",
            extra_data={
                "symbol": symbol,
                "current_price": current_price,
                "threshold_price": threshold_price,
                "direction": direction,
            },
        )

    async def generate_rebalance_alert(
        self,
        session: AsyncSession,
        user_id: str,
        portfolio_name: str,
        drift_pct: float,
    ) -> NotificationModel:
        """Generate a portfolio rebalancing notification."""
        title = f"Rebalance Needed: {portfolio_name}"
        body = (
            f"Your portfolio '{portfolio_name}' has drifted {drift_pct:.1f}% "
            f"from target allocation. Consider rebalancing."
        )
        return await self.create_notification(
            session,
            user_id=user_id,
            title=title,
            body=body,
            category="rebalance",
            priority="medium",
            extra_data={
                "portfolio_name": portfolio_name,
                "drift_pct": drift_pct,
            },
        )

    async def generate_dividend_alert(
        self,
        session: AsyncSession,
        user_id: str,
        symbol: str,
        ex_date: str,
        dividend_amount: float,
    ) -> NotificationModel:
        """Generate a dividend notification."""
        title = f"Dividend: {symbol}"
        body = (
            f"{symbol} has declared a dividend of ₹{dividend_amount:,.2f}. "
            f"Ex-date: {ex_date}"
        )
        return await self.create_notification(
            session,
            user_id=user_id,
            title=title,
            body=body,
            category="dividend",
            priority="medium",
            extra_data={
                "symbol": symbol,
                "ex_date": ex_date,
                "dividend_amount": dividend_amount,
            },
        )


notification_service = NotificationService()
