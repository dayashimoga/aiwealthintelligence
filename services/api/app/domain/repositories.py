"""Repository interfaces (ports) for the domain layer.

These abstract classes define the contracts that infrastructure implementations must fulfill.
Following the Dependency Inversion Principle, domain depends on abstractions, not concretions.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any

from app.domain.entities import (
    AIRecommendation,
    Holding,
    MarketNews,
    Portfolio,
    PortfolioAnalytics,
    PortfolioIntelligence,
    Transaction,
    User,
    Watchlist,
)


class UserRepository(ABC):
    """Repository interface for User entity persistence."""

    @abstractmethod
    async def create(self, user: User) -> User:
        """Create a new user."""

    @abstractmethod
    async def get_by_id(self, user_id: str) -> User | None:
        """Get user by ID."""

    @abstractmethod
    async def get_by_email(self, email: str) -> User | None:
        """Get user by email address."""

    @abstractmethod
    async def update(self, user: User) -> User:
        """Update an existing user."""

    @abstractmethod
    async def delete(self, user_id: str) -> bool:
        """Soft-delete a user."""

    @abstractmethod
    async def get_by_google_id(self, google_id: str) -> User | None:
        """Get user by Google OAuth ID."""

    @abstractmethod
    async def get_by_apple_id(self, apple_id: str) -> User | None:
        """Get user by Apple OAuth ID."""

    @abstractmethod
    async def list_users(
        self, skip: int = 0, limit: int = 50, filters: dict[str, Any] | None = None
    ) -> list[User]:
        """List users with pagination and optional filters."""


class PortfolioRepository(ABC):
    """Repository interface for Portfolio entity persistence."""

    @abstractmethod
    async def create(self, portfolio: Portfolio) -> Portfolio:
        """Create a new portfolio."""

    @abstractmethod
    async def get_by_id(self, portfolio_id: str, user_id: str) -> Portfolio | None:
        """Get portfolio by ID, scoped to user."""

    @abstractmethod
    async def list_by_user(
        self, user_id: str, skip: int = 0, limit: int = 50
    ) -> list[Portfolio]:
        """List all portfolios for a user."""

    @abstractmethod
    async def update(self, portfolio: Portfolio) -> Portfolio:
        """Update an existing portfolio."""

    @abstractmethod
    async def delete(self, portfolio_id: str, user_id: str) -> bool:
        """Delete a portfolio."""


class HoldingRepository(ABC):
    """Repository interface for Holding entity persistence."""

    @abstractmethod
    async def create(self, holding: Holding) -> Holding:
        """Create a new holding."""

    @abstractmethod
    async def get_by_id(self, holding_id: str, portfolio_id: str) -> Holding | None:
        """Get holding by ID within a portfolio."""

    @abstractmethod
    async def list_by_portfolio(
        self, portfolio_id: str, skip: int = 0, limit: int = 100
    ) -> list[Holding]:
        """List all holdings in a portfolio."""

    @abstractmethod
    async def update(self, holding: Holding) -> Holding:
        """Update an existing holding."""

    @abstractmethod
    async def delete(self, holding_id: str, portfolio_id: str) -> bool:
        """Delete a holding."""

    @abstractmethod
    async def bulk_create(self, holdings: list[Holding]) -> list[Holding]:
        """Create multiple holdings at once (for imports)."""


class TransactionRepository(ABC):
    """Repository interface for Transaction entity persistence."""

    @abstractmethod
    async def create(self, transaction: Transaction) -> Transaction:
        """Record a new transaction."""

    @abstractmethod
    async def list_by_holding(
        self, holding_id: str, skip: int = 0, limit: int = 100
    ) -> list[Transaction]:
        """List transactions for a holding."""

    @abstractmethod
    async def list_by_portfolio(
        self, portfolio_id: str, skip: int = 0, limit: int = 200
    ) -> list[Transaction]:
        """List all transactions in a portfolio."""


class AIRecommendationRepository(ABC):
    """Repository interface for AI recommendation persistence."""

    @abstractmethod
    async def save(self, recommendation: AIRecommendation) -> AIRecommendation:
        """Save an AI recommendation."""

    @abstractmethod
    async def get_by_holding(self, holding_id: str) -> AIRecommendation | None:
        """Get latest recommendation for a holding."""

    @abstractmethod
    async def list_by_portfolio(self, portfolio_id: str) -> list[AIRecommendation]:
        """Get all recommendations for holdings in a portfolio."""


class MarketNewsRepository(ABC):
    """Repository interface for market news persistence."""

    @abstractmethod
    async def save_batch(self, news_items: list[MarketNews]) -> list[MarketNews]:
        """Save a batch of news items."""

    @abstractmethod
    async def list_latest(
        self, skip: int = 0, limit: int = 20, sector: str | None = None
    ) -> list[MarketNews]:
        """Get latest market news with optional sector filter."""


class WatchlistRepository(ABC):
    """Repository interface for Watchlist persistence."""

    @abstractmethod
    async def create(self, watchlist: Watchlist) -> Watchlist:
        """Create a new watchlist."""

    @abstractmethod
    async def get_by_id(self, watchlist_id: str, user_id: str) -> Watchlist | None:
        """Get watchlist by ID."""

    @abstractmethod
    async def list_by_user(self, user_id: str) -> list[Watchlist]:
        """List all watchlists for a user."""

    @abstractmethod
    async def update(self, watchlist: Watchlist) -> Watchlist:
        """Update a watchlist."""

    @abstractmethod
    async def delete(self, watchlist_id: str, user_id: str) -> bool:
        """Delete a watchlist."""


class CacheRepository(ABC):
    """Repository interface for caching."""

    @abstractmethod
    async def get(self, key: str) -> Any | None:
        """Get a cached value."""

    @abstractmethod
    async def set(self, key: str, value: Any, ttl: int | None = None) -> None:
        """Set a cached value with optional TTL."""

    @abstractmethod
    async def delete(self, key: str) -> None:
        """Delete a cached value."""

    @abstractmethod
    async def exists(self, key: str) -> bool:
        """Check if a key exists in cache."""


class AnalyticsEngine(ABC):
    """Interface for portfolio analytics calculations."""

    @abstractmethod
    async def calculate_analytics(self, portfolio: Portfolio) -> PortfolioAnalytics:
        """Calculate comprehensive portfolio analytics."""

    @abstractmethod
    async def calculate_xirr(self, transactions: list[Transaction]) -> float | None:
        """Calculate XIRR from transaction history."""

    @abstractmethod
    async def calculate_portfolio_intelligence(
        self, portfolio: Portfolio
    ) -> PortfolioIntelligence:
        """Analyze portfolio for issues and improvements."""
