"""Domain entities representing core business objects.

These are pure Python classes with no framework dependencies.
They encapsulate business rules and invariants.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from decimal import Decimal
from enum import Enum
from typing import Any


# ============================================================
# Enums
# ============================================================


class AssetType(str, Enum):
    """Supported asset types in the platform."""

    STOCK = "stock"
    MUTUAL_FUND = "mutual_fund"
    ETF = "etf"
    BOND = "bond"
    GOLD = "gold"
    CRYPTO = "crypto"
    REAL_ESTATE = "real_estate"
    FIXED_DEPOSIT = "fixed_deposit"
    PPF = "ppf"
    NPS = "nps"
    CASH = "cash"
    OTHER = "other"


class Currency(str, Enum):
    """Supported currencies."""

    INR = "INR"
    USD = "USD"
    EUR = "EUR"
    GBP = "GBP"


class Exchange(str, Enum):
    """Supported stock exchanges."""

    NSE = "NSE"
    BSE = "BSE"
    NYSE = "NYSE"
    NASDAQ = "NASDAQ"
    OTHER = "OTHER"


class RecommendationAction(str, Enum):
    """AI recommendation actions."""

    STRONG_BUY = "strong_buy"
    BUY = "buy"
    HOLD = "hold"
    REDUCE = "reduce"
    SELL = "sell"
    EXIT = "exit"


class RiskLevel(str, Enum):
    """Risk classification levels."""

    VERY_LOW = "very_low"
    LOW = "low"
    MODERATE = "moderate"
    HIGH = "high"
    VERY_HIGH = "very_high"


class UserRole(str, Enum):
    """User roles for RBAC."""

    ADMIN = "admin"
    USER = "user"
    PREMIUM = "premium"


class PortfolioImportSource(str, Enum):
    """Portfolio import sources."""

    MANUAL = "manual"
    CSV = "csv"
    NSDL_CAS = "nsdl_cas"
    CDSL_CAS = "cdsl_cas"
    BROKER_API = "broker_api"


# ============================================================
# Value Objects
# ============================================================


@dataclass(frozen=True)
class Money:
    """Value object representing a monetary amount with currency."""

    amount: Decimal
    currency: Currency = Currency.INR

    def __add__(self, other: Money) -> Money:
        if self.currency != other.currency:
            msg = f"Cannot add {self.currency} and {other.currency}"
            raise ValueError(msg)
        return Money(amount=self.amount + other.amount, currency=self.currency)

    def __mul__(self, factor: Decimal | int | float) -> Money:
        return Money(amount=self.amount * Decimal(str(factor)), currency=self.currency)


@dataclass(frozen=True)
class Percentage:
    """Value object representing a percentage."""

    value: Decimal

    def __post_init__(self) -> None:
        if not Decimal("-100") <= self.value <= Decimal("10000"):
            msg = f"Percentage {self.value} out of reasonable range"
            raise ValueError(msg)


# ============================================================
# Domain Entities
# ============================================================


@dataclass
class User:
    """User entity with authentication and profile data."""

    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    email: str = ""
    hashed_password: str = ""
    full_name: str = ""
    role: UserRole = UserRole.USER
    is_active: bool = True
    is_verified: bool = False
    mfa_enabled: bool = False
    avatar_url: str = ""
    preferences: dict[str, Any] = field(default_factory=dict)
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    last_login_at: datetime | None = None

    def verify(self) -> None:
        """Mark user as verified."""
        self.is_verified = True
        self.updated_at = datetime.now(timezone.utc)

    def update_last_login(self) -> None:
        """Update last login timestamp."""
        self.last_login_at = datetime.now(timezone.utc)
        self.updated_at = datetime.now(timezone.utc)


@dataclass
class Portfolio:
    """Portfolio entity containing a collection of holdings."""

    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str = ""
    name: str = "My Portfolio"
    description: str = ""
    is_default: bool = False
    currency: Currency = Currency.INR
    import_source: PortfolioImportSource = PortfolioImportSource.MANUAL
    holdings: list[Holding] = field(default_factory=list)
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    @property
    def total_invested(self) -> Decimal:
        """Calculate total amount invested across all holdings."""
        return sum(
            (h.quantity * h.average_buy_price for h in self.holdings),
            Decimal("0"),
        )

    @property
    def total_current_value(self) -> Decimal:
        """Calculate total current value of all holdings."""
        return sum(
            (h.quantity * h.current_price for h in self.holdings),
            Decimal("0"),
        )

    @property
    def total_gain_loss(self) -> Decimal:
        """Calculate total unrealized gain/loss."""
        return self.total_current_value - self.total_invested

    @property
    def total_gain_loss_percentage(self) -> Decimal:
        """Calculate total gain/loss percentage."""
        if self.total_invested == 0:
            return Decimal("0")
        return (self.total_gain_loss / self.total_invested) * 100

    @property
    def holding_count(self) -> int:
        """Number of holdings in portfolio."""
        return len(self.holdings)


@dataclass
class Holding:
    """Individual holding within a portfolio."""

    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    portfolio_id: str = ""
    symbol: str = ""
    name: str = ""
    asset_type: AssetType = AssetType.STOCK
    exchange: Exchange = Exchange.NSE
    currency: Currency = Currency.INR
    quantity: Decimal = Decimal("0")
    average_buy_price: Decimal = Decimal("0")
    current_price: Decimal = Decimal("0")
    sector: str = ""
    industry: str = ""
    country: str = "India"
    isin: str = ""
    notes: str = ""
    buy_date: datetime | None = None
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    @property
    def invested_value(self) -> Decimal:
        """Total amount invested in this holding."""
        return self.quantity * self.average_buy_price

    @property
    def current_value(self) -> Decimal:
        """Current market value of this holding."""
        return self.quantity * self.current_price

    @property
    def gain_loss(self) -> Decimal:
        """Unrealized gain or loss."""
        return self.current_value - self.invested_value

    @property
    def gain_loss_percentage(self) -> Decimal:
        """Unrealized gain or loss as percentage."""
        if self.invested_value == 0:
            return Decimal("0")
        return (self.gain_loss / self.invested_value) * 100


@dataclass
class Transaction:
    """Transaction entity for tracking buy/sell/dividend events."""

    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    holding_id: str = ""
    portfolio_id: str = ""
    transaction_type: str = "buy"  # buy, sell, dividend, split, bonus
    quantity: Decimal = Decimal("0")
    price: Decimal = Decimal("0")
    fees: Decimal = Decimal("0")
    tax: Decimal = Decimal("0")
    notes: str = ""
    transaction_date: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    @property
    def total_amount(self) -> Decimal:
        """Total transaction amount including fees and tax."""
        base = self.quantity * self.price
        if self.transaction_type == "sell":
            return base - self.fees - self.tax
        return base + self.fees + self.tax


@dataclass
class AIRecommendation:
    """AI-generated recommendation for a holding."""

    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    holding_id: str = ""
    symbol: str = ""
    action: RecommendationAction = RecommendationAction.HOLD
    confidence: Decimal = Decimal("0")  # 0-100
    reasoning: str = ""
    evidence: list[str] = field(default_factory=list)
    expected_return: Decimal = Decimal("0")
    risk_level: RiskLevel = RiskLevel.MODERATE
    investment_horizon: str = ""  # e.g., "6-12 months"
    alternative_suggestions: list[str] = field(default_factory=list)
    explainability: AIExplainability | None = None
    generated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    expires_at: datetime | None = None
    model_version: str = ""


@dataclass
class AIExplainability:
    """Structured AI explainability for a recommendation."""

    fundamentals: str = ""
    technical_indicators: str = ""
    news_sentiment: str = ""
    macroeconomics: str = ""
    valuation: str = ""
    sector_outlook: str = ""
    institutional_activity: str = ""
    insider_activity: str = ""
    market_sentiment: str = ""
    overall_summary: str = ""


@dataclass
class PortfolioAnalytics:
    """Analytics data for a portfolio."""

    portfolio_id: str = ""
    total_invested: Decimal = Decimal("0")
    total_current_value: Decimal = Decimal("0")
    total_gain_loss: Decimal = Decimal("0")
    total_gain_loss_pct: Decimal = Decimal("0")
    xirr: Decimal | None = None
    cagr: Decimal | None = None
    max_drawdown: Decimal | None = None
    sharpe_ratio: Decimal | None = None
    diversification_score: Decimal = Decimal("0")
    risk_score: Decimal = Decimal("0")
    ai_health_score: Decimal = Decimal("0")
    dividend_income: Decimal = Decimal("0")
    asset_allocation: dict[str, Decimal] = field(default_factory=dict)
    sector_allocation: dict[str, Decimal] = field(default_factory=dict)
    country_allocation: dict[str, Decimal] = field(default_factory=dict)
    calculated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


@dataclass
class PortfolioIntelligence:
    """AI-generated intelligence about portfolio health."""

    portfolio_id: str = ""
    duplicate_funds: list[dict[str, Any]] = field(default_factory=list)
    hidden_overlap: list[dict[str, Any]] = field(default_factory=list)
    sector_concentration: list[dict[str, Any]] = field(default_factory=list)
    geographic_concentration: list[dict[str, Any]] = field(default_factory=list)
    over_diversification: bool = False
    under_diversification: bool = False
    tax_inefficiency: list[dict[str, Any]] = field(default_factory=list)
    governance_risks: list[dict[str, Any]] = field(default_factory=list)
    inflation_risks: list[dict[str, Any]] = field(default_factory=list)
    interest_rate_risks: list[dict[str, Any]] = field(default_factory=list)
    suggestions: list[str] = field(default_factory=list)
    overall_health: str = ""
    generated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


@dataclass
class MarketNews:
    """Market news item with AI summary."""

    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    title: str = ""
    summary: str = ""
    source: str = ""
    url: str = ""
    sentiment: str = ""  # positive, negative, neutral
    relevance_score: Decimal = Decimal("0")
    sectors: list[str] = field(default_factory=list)
    symbols: list[str] = field(default_factory=list)
    published_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    fetched_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


@dataclass
class Watchlist:
    """User watchlist for tracking potential investments."""

    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str = ""
    name: str = "My Watchlist"
    symbols: list[str] = field(default_factory=list)
    alerts: list[dict[str, Any]] = field(default_factory=list)
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
