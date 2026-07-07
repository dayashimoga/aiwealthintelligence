"""Pydantic schemas for API request/response validation.

These schemas provide serialization, deserialization, and validation
for all API endpoints. They are separate from domain entities.
"""

from __future__ import annotations

from decimal import Decimal
from typing import TYPE_CHECKING, Any, Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field

if TYPE_CHECKING:
    from datetime import datetime

# ============================================================
# Common
# ============================================================


class HealthResponse(BaseModel):
    """Health check response."""

    status: str = "healthy"
    version: str = "0.1.0"
    environment: str = "development"
    timestamp: datetime


class ErrorResponse(BaseModel):
    """Standard error response."""

    error: str
    error_code: str
    details: dict[str, Any] = Field(default_factory=dict)


class PaginatedResponse(BaseModel):
    """Base paginated response."""

    total: int = 0
    skip: int = 0
    limit: int = 50
    items: list[Any] = Field(default_factory=list)


# ============================================================
# Auth
# ============================================================


class RegisterRequest(BaseModel):
    """User registration request."""

    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    full_name: str = Field(min_length=1, max_length=255)


class LoginRequest(BaseModel):
    """User login request."""

    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    """JWT token response."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class RefreshTokenRequest(BaseModel):
    """Token refresh request."""

    refresh_token: str


class UserResponse(BaseModel):
    """User profile response."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str
    full_name: str
    role: str
    is_verified: bool
    mfa_enabled: bool
    is_onboarded: bool
    avatar_url: str = ""
    created_at: datetime
    passkeys: list[dict] = Field(default_factory=list)
    trusted_devices: list[dict] = Field(default_factory=list)


class OAuthLoginRequest(BaseModel):
    """OAuth login/registration request."""

    email: EmailStr
    token: str
    provider: Literal["google", "apple"]
    full_name: str | None = None


class SendOTPRequest(BaseModel):
    """Send OTP request."""

    email: EmailStr


class VerifyOTPRequest(BaseModel):
    """Verify OTP request."""

    email: EmailStr
    code: str


class TOTPSetupResponse(BaseModel):
    """TOTP MFA setup response."""

    secret: str
    provisioning_uri: str


class TOTPVerifyRequest(BaseModel):
    """TOTP verification request."""

    code: str
    backup_code: str | None = None


class DeviceResponse(BaseModel):
    """Registered device response."""

    device_id: str
    name: str
    registered_at: datetime


class PasskeyOptionsResponse(BaseModel):
    """Passkey credentials options response."""

    challenge: str
    user_id: str | None = None
    rp_name: str
    rp_id: str


class PasskeyVerifyRequest(BaseModel):
    """Passkey verification request."""

    credential_id: str
    client_data_json: str
    authenticator_data: str
    signature: str
    client_extensions: dict[str, Any] = Field(default_factory=dict)


# ============================================================
# Portfolio
# ============================================================


class CreatePortfolioRequest(BaseModel):
    """Create portfolio request."""

    name: str = Field(min_length=1, max_length=255, default="My Portfolio")
    description: str = Field(max_length=1000, default="")
    currency: str = Field(default="INR", pattern="^[A-Z]{3}$")


class UpdatePortfolioRequest(BaseModel):
    """Update portfolio request."""

    name: str | None = Field(None, min_length=1, max_length=255)
    description: str | None = Field(None, max_length=1000)


class PortfolioResponse(BaseModel):
    """Portfolio response."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    description: str
    currency: str
    is_default: bool
    import_source: str
    holding_count: int = 0
    total_invested: float = 0
    total_current_value: float = 0
    total_gain_loss: float = 0
    total_gain_loss_pct: float = 0
    created_at: datetime
    updated_at: datetime


class PortfolioListResponse(BaseModel):
    """List of portfolios response."""

    portfolios: list[PortfolioResponse]
    total: int


# ============================================================
# Holding
# ============================================================


class CreateHoldingRequest(BaseModel):
    """Create holding request."""

    symbol: str = Field(min_length=1, max_length=50)
    name: str = Field(min_length=1, max_length=255)
    asset_type: str = Field(default="stock")
    exchange: str = Field(default="NSE")
    quantity: Decimal = Field(gt=0)
    average_buy_price: Decimal = Field(ge=0)
    current_price: Decimal = Field(ge=0, default=Decimal("0"))
    sector: str = Field(max_length=100, default="")
    industry: str = Field(max_length=100, default="")
    country: str = Field(max_length=100, default="India")
    isin: str = Field(max_length=20, default="")
    notes: str = Field(max_length=1000, default="")
    buy_date: datetime | None = None


class UpdateHoldingRequest(BaseModel):
    """Update holding request."""

    quantity: Decimal | None = Field(None, gt=0)
    average_buy_price: Decimal | None = Field(None, ge=0)
    current_price: Decimal | None = Field(None, ge=0)
    sector: str | None = None
    industry: str | None = None
    notes: str | None = None


class HoldingResponse(BaseModel):
    """Holding response."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    portfolio_id: str
    symbol: str
    name: str
    asset_type: str
    exchange: str
    currency: str
    quantity: float
    average_buy_price: float
    current_price: float
    invested_value: float
    current_value: float
    gain_loss: float
    gain_loss_pct: float
    sector: str
    industry: str
    country: str
    isin: str
    notes: str
    buy_date: datetime | None
    created_at: datetime
    updated_at: datetime


class HoldingListResponse(BaseModel):
    """List of holdings response."""

    holdings: list[HoldingResponse]
    total: int


class CSVImportRequest(BaseModel):
    """CSV import metadata."""

    portfolio_id: str
    mapping: dict[str, str] = Field(default_factory=dict)


class ImportResponse(BaseModel):
    """Import result response."""

    imported: int
    skipped: int
    errors: list[str]


# ============================================================
# Analytics
# ============================================================


class PortfolioAnalyticsResponse(BaseModel):
    """Portfolio analytics response."""

    portfolio_id: str
    total_invested: float
    total_current_value: float
    total_gain_loss: float
    total_gain_loss_pct: float
    holding_count: int = 0
    xirr: float | None = None
    cagr: float | None = None
    max_drawdown: float | None = None
    sharpe_ratio: float | None = None
    diversification_score: float = 0
    risk_score: float = 0
    ai_health_score: float = 0
    dividend_income: float = 0
    asset_allocation: dict[str, float] = Field(default_factory=dict)
    sector_allocation: dict[str, float] = Field(default_factory=dict)
    country_allocation: dict[str, float] = Field(default_factory=dict)
    tax_estimate: dict[str, float] | None = None
    calculated_at: datetime


# ============================================================
# AI Recommendation
# ============================================================


class AIRecommendationResponse(BaseModel):
    """AI recommendation response."""

    id: str
    holding_id: str
    symbol: str
    action: str
    confidence: float
    reasoning: str
    evidence: list[str]
    expected_return: float
    risk_level: str
    risk_description: str
    investment_horizon: str
    alternative_suggestions: list[str]
    explainability: dict[str, str] = Field(default_factory=dict)
    generated_at: datetime


class AIChatRequest(BaseModel):
    """AI chat request."""

    message: str = Field(min_length=1, max_length=2000)
    portfolio_id: str | None = None
    context: dict[str, Any] = Field(default_factory=dict)


class AIChatResponse(BaseModel):
    """AI chat response."""

    message: str
    suggestions: list[str] = Field(default_factory=list)
    referenced_holdings: list[str] = Field(default_factory=list)
    confidence: float = 0


# ============================================================
# Market
# ============================================================


class MarketNewsResponse(BaseModel):
    """Market news response."""

    id: str
    title: str
    summary: str
    source: str
    url: str
    sentiment: str
    relevance_score: float
    sectors: list[str]
    symbols: list[str]
    published_at: datetime


class SectorRankingResponse(BaseModel):
    """Sector ranking response."""

    sector: str
    performance_1d: float = 0
    performance_1w: float = 0
    performance_1m: float = 0
    performance_3m: float = 0
    performance_1y: float = 0
    top_gainers: list[str] = Field(default_factory=list)
    top_losers: list[str] = Field(default_factory=list)


class MarketOverviewResponse(BaseModel):
    """Market overview response."""

    news: list[MarketNewsResponse]
    sector_rankings: list[SectorRankingResponse]
    macro_indicators: dict[str, float] = Field(default_factory=dict)
    index_performance: dict[str, dict[str, Any]] = Field(default_factory=dict)
    updated_at: datetime


# ============================================================
# Copilot
# ============================================================


class DailyBriefResponse(BaseModel):
    """Daily AI brief response."""

    summary: str
    market_sentiment: str
    top_gainers: list[dict[str, Any]] = Field(default_factory=list)
    top_losers: list[dict[str, Any]] = Field(default_factory=list)
    actionable_insights: list[str] = Field(default_factory=list)
    generated_at: datetime


class ScenarioSimulationAction(BaseModel):
    """Action to simulate in a portfolio scenario."""

    symbol: str
    action: str  # "buy", "sell"
    quantity: float
    price: float | None = None


class ScenarioSimulationRequest(BaseModel):
    """Scenario simulation request."""

    portfolio_id: str
    actions: list[ScenarioSimulationAction]


class ScenarioMetrics(BaseModel):
    """Metrics for original or simulated state in scenario analysis."""

    total_value: float
    xirr: float | None = None
    diversification_score: float = 0
    risk_score: float = 0


class ScenarioSimulationResponse(BaseModel):
    """Scenario simulation response."""

    original_metrics: ScenarioMetrics
    simulated_metrics: ScenarioMetrics
    impact_summary: str
    recommendations: list[str] = Field(default_factory=list)


class PortfolioIssue(BaseModel):
    """An issue identified in portfolio doctor health checks."""

    severity: str  # "high", "medium", "low"
    title: str
    description: str
    recommendation: str


class PortfolioDoctorResponse(BaseModel):
    """Portfolio doctor health check response."""

    health_score: int
    issues: list[PortfolioIssue]
    diversification_hhi: float = 0
    sector_concentration_pct: float = 0
    cash_drag_pct: float = 0


class ConsentRequest(BaseModel):
    """Account Aggregator consent request parameters."""

    phone_number: str
    aggregator_id: str


class ConsentInitiateResponse(BaseModel):
    """Account Aggregator consent initiation response."""

    consent_handle: str
    redirect_url: str


class ConsentStatusResponse(BaseModel):
    """Account Aggregator consent status tracking response."""

    consent_handle: str
    status: str  # "PENDING", "APPROVED", "FAILED", "COMPLETED"
    holdings_count: int = 0
    message: str = ""


# ============================================================
# Advanced Wealth Intelligence Analytics
# ============================================================


class StressScenarioResult(BaseModel):
    scenario_name: str
    scenario_description: str
    estimated_new_value: float
    change_value: float
    change_percentage: float
    impact_level: str  # "high_positive", "positive", "neutral", "negative", "high_negative"


class TaxHarvestingOpportunity(BaseModel):
    symbol: str
    name: str
    quantity: float
    current_price: float
    average_buy_price: float
    unrealized_loss: float
    potential_tax_savings: float
    holding_period_days: int
    asset_type: str


class BehavioralBias(BaseModel):
    bias_name: str
    severity: str  # "high", "medium", "low"
    description: str
    remedy: str


class GoalProgress(BaseModel):
    goal_name: str
    target_amount: float
    current_amount: float
    progress_percentage: float
    status: str  # "on_track", "behind", "ahead"


class AdvancedAnalysisResponse(BaseModel):
    portfolio_id: str
    stress_test: list[StressScenarioResult]
    tax_harvesting: list[TaxHarvestingOpportunity]
    total_potential_tax_savings: float
    behavioral_biases: list[BehavioralBias]
    goals: list[GoalProgress]
    calculated_at: datetime
