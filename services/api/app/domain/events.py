"""Domain events for event-driven architecture.

Events are raised by domain entities and handled by application services.
This enables loose coupling between bounded contexts.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any


@dataclass(frozen=True)
class DomainEvent:
    """Base class for all domain events."""

    event_type: str = ""
    aggregate_id: str = ""
    timestamp: datetime = field(default_factory=lambda: datetime.now(UTC))
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class UserRegistered(DomainEvent):
    """Raised when a new user registers."""

    event_type: str = "user.registered"
    user_id: str = ""
    email: str = ""


@dataclass(frozen=True)
class PortfolioCreated(DomainEvent):
    """Raised when a new portfolio is created."""

    event_type: str = "portfolio.created"
    portfolio_id: str = ""
    user_id: str = ""


@dataclass(frozen=True)
class HoldingAdded(DomainEvent):
    """Raised when a holding is added to a portfolio."""

    event_type: str = "holding.added"
    holding_id: str = ""
    portfolio_id: str = ""
    symbol: str = ""


@dataclass(frozen=True)
class PortfolioImported(DomainEvent):
    """Raised when a portfolio is imported from external source."""

    event_type: str = "portfolio.imported"
    portfolio_id: str = ""
    source: str = ""
    holding_count: int = 0


@dataclass(frozen=True)
class RecommendationGenerated(DomainEvent):
    """Raised when AI generates a recommendation."""

    event_type: str = "recommendation.generated"
    recommendation_id: str = ""
    holding_id: str = ""
    action: str = ""


@dataclass(frozen=True)
class PriceAlertTriggered(DomainEvent):
    """Raised when a price alert condition is met."""

    event_type: str = "alert.price_triggered"
    symbol: str = ""
    price: float = 0.0
    condition: str = ""


class EventBus:
    """Simple in-memory event bus for domain events.

    In production, this can be replaced with a message broker (Redis Streams, Kafka, etc.)
    without changing the domain layer.
    """

    def __init__(self) -> None:
        self._handlers: dict[str, list[Any]] = {}

    def subscribe(self, event_type: str, handler: Any) -> None:
        """Subscribe a handler to an event type."""
        if event_type not in self._handlers:
            self._handlers[event_type] = []
        self._handlers[event_type].append(handler)

    async def publish(self, event: DomainEvent) -> None:
        """Publish an event to all subscribed handlers."""
        handlers = self._handlers.get(event.event_type, [])
        for handler in handlers:
            await handler(event)

    def clear(self) -> None:
        """Clear all subscriptions (useful for testing)."""
        self._handlers.clear()


# Global event bus instance
event_bus = EventBus()
