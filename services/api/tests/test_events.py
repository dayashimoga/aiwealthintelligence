"""Tests for domain events and EventBus."""

from __future__ import annotations

from unittest.mock import AsyncMock

import pytest

from app.domain.events import (
    EventBus,
    HoldingAdded,
    PortfolioCreated,
    PortfolioImported,
    PriceAlertTriggered,
    RecommendationGenerated,
    UserRegistered,
)


@pytest.mark.asyncio
async def test_event_bus_subscribe_and_publish() -> None:
    """EventBus registers handlers and publishes events to them."""
    bus = EventBus()

    # Create mock handlers
    handler1 = AsyncMock()
    handler2 = AsyncMock()

    # Subscribe to different event types
    bus.subscribe("user.registered", handler1)
    bus.subscribe("portfolio.created", handler2)

    # Instantiate events
    event1 = UserRegistered(user_id="u123", email="user@example.com")
    event2 = PortfolioCreated(portfolio_id="p456", user_id="u123")

    # Publish events
    await bus.publish(event1)
    await bus.publish(event2)

    # Assert handlers were called
    handler1.assert_called_once_with(event1)
    handler2.assert_called_once_with(event2)

    # Clear subscriptions
    bus.clear()
    await bus.publish(event1)
    # The handler should not be called again
    assert handler1.call_count == 1


def test_instantiate_all_events() -> None:
    """All domain event classes can be instantiated with metadata."""
    e1 = HoldingAdded(holding_id="h1", portfolio_id="p1", symbol="INFY")
    e2 = PortfolioImported(portfolio_id="p1", source="csv", holding_count=5)
    e3 = RecommendationGenerated(recommendation_id="r1", holding_id="h1", action="buy")
    e4 = PriceAlertTriggered(symbol="INFY", price=1500.0, condition="above")

    assert e1.event_type == "holding.added"
    assert e2.source == "csv"
    assert e3.action == "buy"
    assert e4.price == 1500.0
