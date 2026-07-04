"""SQLAlchemy ORM models mapping domain entities to database tables.

These models define the database schema and handle ORM mapping.
They are infrastructure concerns and should not contain business logic.
"""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Numeric,
    String,
    Text,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy models."""

    pass


class TimestampMixin:
    """Mixin for created_at and updated_at timestamps."""

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class UserModel(TimestampMixin, Base):
    """User database model."""

    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False, default="")
    role: Mapped[str] = mapped_column(
        Enum("admin", "user", "premium", name="user_role"),
        nullable=False,
        default="user",
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    mfa_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    avatar_url: Mapped[str] = mapped_column(String(500), nullable=False, default="")
    preferences: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    last_login_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Relationships
    portfolios: Mapped[list["PortfolioModel"]] = relationship(
        back_populates="user", cascade="all, delete-orphan", lazy="selectin"
    )
    watchlists: Mapped[list["WatchlistModel"]] = relationship(
        back_populates="user", cascade="all, delete-orphan", lazy="selectin"
    )

    __table_args__ = (Index("ix_users_email_active", "email", "is_active"),)


class PortfolioModel(TimestampMixin, Base):
    """Portfolio database model."""

    __tablename__ = "portfolios"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False, default="My Portfolio")
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    is_default: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="INR")
    import_source: Mapped[str] = mapped_column(String(50), nullable=False, default="manual")

    # Relationships
    user: Mapped["UserModel"] = relationship(back_populates="portfolios")
    holdings: Mapped[list["HoldingModel"]] = relationship(
        back_populates="portfolio", cascade="all, delete-orphan", lazy="selectin"
    )
    transactions: Mapped[list["TransactionModel"]] = relationship(
        back_populates="portfolio", cascade="all, delete-orphan", lazy="selectin"
    )

    __table_args__ = (Index("ix_portfolios_user_default", "user_id", "is_default"),)


class HoldingModel(TimestampMixin, Base):
    """Holding database model."""

    __tablename__ = "holdings"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    portfolio_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("portfolios.id", ondelete="CASCADE"), nullable=False, index=True
    )
    symbol: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    asset_type: Mapped[str] = mapped_column(
        Enum(
            "stock", "mutual_fund", "etf", "bond", "gold", "crypto",
            "real_estate", "fixed_deposit", "ppf", "nps", "cash", "other",
            name="asset_type",
        ),
        nullable=False,
        default="stock",
    )
    exchange: Mapped[str] = mapped_column(String(20), nullable=False, default="NSE")
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="INR")
    quantity: Mapped[float] = mapped_column(Numeric(18, 6), nullable=False, default=0)
    average_buy_price: Mapped[float] = mapped_column(Numeric(18, 4), nullable=False, default=0)
    current_price: Mapped[float] = mapped_column(Numeric(18, 4), nullable=False, default=0)
    sector: Mapped[str] = mapped_column(String(100), nullable=False, default="")
    industry: Mapped[str] = mapped_column(String(100), nullable=False, default="")
    country: Mapped[str] = mapped_column(String(100), nullable=False, default="India")
    isin: Mapped[str] = mapped_column(String(20), nullable=False, default="")
    notes: Mapped[str] = mapped_column(Text, nullable=False, default="")
    buy_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationships
    portfolio: Mapped["PortfolioModel"] = relationship(back_populates="holdings")
    transactions: Mapped[list["TransactionModel"]] = relationship(
        back_populates="holding", cascade="all, delete-orphan", lazy="selectin"
    )
    recommendations: Mapped[list["AIRecommendationModel"]] = relationship(
        back_populates="holding", cascade="all, delete-orphan", lazy="selectin"
    )

    __table_args__ = (
        Index("ix_holdings_portfolio_symbol", "portfolio_id", "symbol"),
        Index("ix_holdings_asset_type", "asset_type"),
    )


class TransactionModel(TimestampMixin, Base):
    """Transaction database model."""

    __tablename__ = "transactions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    holding_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("holdings.id", ondelete="CASCADE"), nullable=False, index=True
    )
    portfolio_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("portfolios.id", ondelete="CASCADE"), nullable=False, index=True
    )
    transaction_type: Mapped[str] = mapped_column(
        Enum("buy", "sell", "dividend", "split", "bonus", name="transaction_type"),
        nullable=False,
        default="buy",
    )
    quantity: Mapped[float] = mapped_column(Numeric(18, 6), nullable=False, default=0)
    price: Mapped[float] = mapped_column(Numeric(18, 4), nullable=False, default=0)
    fees: Mapped[float] = mapped_column(Numeric(18, 4), nullable=False, default=0)
    tax: Mapped[float] = mapped_column(Numeric(18, 4), nullable=False, default=0)
    notes: Mapped[str] = mapped_column(Text, nullable=False, default="")
    transaction_date: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    holding: Mapped["HoldingModel"] = relationship(back_populates="transactions")
    portfolio: Mapped["PortfolioModel"] = relationship(back_populates="transactions")

    __table_args__ = (
        Index("ix_transactions_date", "transaction_date"),
        Index("ix_transactions_type", "transaction_type"),
    )


class AIRecommendationModel(TimestampMixin, Base):
    """AI Recommendation database model."""

    __tablename__ = "ai_recommendations"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    holding_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("holdings.id", ondelete="CASCADE"), nullable=False, index=True
    )
    symbol: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    action: Mapped[str] = mapped_column(
        Enum(
            "strong_buy", "buy", "hold", "reduce", "sell", "exit",
            name="recommendation_action",
        ),
        nullable=False,
        default="hold",
    )
    confidence: Mapped[float] = mapped_column(Numeric(5, 2), nullable=False, default=0)
    reasoning: Mapped[str] = mapped_column(Text, nullable=False, default="")
    evidence: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    expected_return: Mapped[float] = mapped_column(Numeric(8, 2), nullable=False, default=0)
    risk_level: Mapped[str] = mapped_column(String(20), nullable=False, default="moderate")
    investment_horizon: Mapped[str] = mapped_column(String(50), nullable=False, default="")
    alternative_suggestions: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    explainability: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    model_version: Mapped[str] = mapped_column(String(50), nullable=False, default="")
    generated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Relationships
    holding: Mapped["HoldingModel"] = relationship(back_populates="recommendations")


class MarketNewsModel(Base):
    """Market news database model."""

    __tablename__ = "market_news"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    summary: Mapped[str] = mapped_column(Text, nullable=False, default="")
    source: Mapped[str] = mapped_column(String(100), nullable=False, default="")
    url: Mapped[str] = mapped_column(String(1000), nullable=False, default="")
    sentiment: Mapped[str] = mapped_column(String(20), nullable=False, default="neutral")
    relevance_score: Mapped[float] = mapped_column(Numeric(5, 2), nullable=False, default=0)
    sectors: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    symbols: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    published_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )
    fetched_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class WatchlistModel(TimestampMixin, Base):
    """Watchlist database model."""

    __tablename__ = "watchlists"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False, default="My Watchlist")
    symbols: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    alerts: Mapped[list] = mapped_column(JSON, nullable=False, default=list)

    # Relationships
    user: Mapped["UserModel"] = relationship(back_populates="watchlists")


class AuditLogModel(Base):
    """Audit log for security and compliance tracking."""

    __tablename__ = "audit_logs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    action: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    resource_type: Mapped[str] = mapped_column(String(50), nullable=False)
    resource_id: Mapped[str] = mapped_column(String(36), nullable=False)
    details: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    ip_address: Mapped[str] = mapped_column(String(45), nullable=False, default="")
    user_agent: Mapped[str] = mapped_column(String(500), nullable=False, default="")
    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )
