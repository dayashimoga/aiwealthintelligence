"""Tests for PortfolioAnalyticsEngine covering allocations, risk, and tax estimation."""

from __future__ import annotations

from datetime import date
from decimal import Decimal

from app.domain.entities import AssetType, Holding
from app.infrastructure.analytics.portfolio_analytics_engine import PortfolioAnalyticsEngine


def test_calculate_metrics_empty() -> None:
    """Calculating metrics for an empty portfolio returns zero values."""
    engine = PortfolioAnalyticsEngine()
    metrics = engine.calculate_metrics([])

    assert metrics["total_invested"] == 0.0
    assert metrics["total_current_value"] == 0.0
    assert metrics["total_gain_loss"] == 0.0
    assert metrics["total_gain_loss_pct"] == 0.0
    assert metrics["xirr"] is None
    assert metrics["diversification_score"] == 0.0
    assert metrics["risk_score"] == 50.0  # default risk for empty/zero allocation


def test_calculate_metrics_with_holdings() -> None:
    """Calculating metrics for a standard list of holdings."""
    engine = PortfolioAnalyticsEngine()

    holdings = [
        Holding(
            id="1",
            portfolio_id="p1",
            symbol="TCS",
            name="Tata Consultancy Services",
            asset_type=AssetType.STOCK,
            exchange="NSE",
            quantity=Decimal("10"),
            average_buy_price=Decimal("3000.00"),
            current_price=Decimal("3500.00"),
            sector="Information Technology",
            industry="IT Services",
            country="India",
            isin="INE467B01029",
            buy_date=date(2023, 1, 1),
        ),
        Holding(
            id="2",
            portfolio_id="p1",
            symbol="HDFCBANK",
            name="HDFC Bank Ltd",
            asset_type=AssetType.STOCK,
            exchange="NSE",
            quantity=Decimal("20"),
            average_buy_price=Decimal("1500.00"),
            current_price=Decimal("1600.00"),
            sector="Financial Services",
            industry="Private Banks",
            country="India",
            isin="INE040A01034",
            buy_date=date(2026, 1, 1),  # Short term (< 1 year from 2026 current date)
        ),
    ]

    metrics = engine.calculate_metrics(holdings)

    # TCS invested = 30000, current = 35000
    # HDFCBANK invested = 30000, current = 32000
    # Total invested = 60000, current = 67000
    assert metrics["total_invested"] == 60000.0
    assert metrics["total_current_value"] == 67000.0
    assert metrics["total_gain_loss"] == 7000.0
    assert metrics["total_gain_loss_pct"] == round((7000.0 / 60000.0) * 100, 2)
    assert metrics["xirr"] is not None
    assert metrics["diversification_score"] > 0.0
    assert "Information Technology" in metrics["sector_allocation"]
    assert "Financial Services" in metrics["sector_allocation"]

    # Verify tax estimations
    tax = metrics["tax_estimate"]
    assert tax["taxable_profit"] == 7000.0
    # TCS has 5000 gain, held > 1 year -> Equity LTCG @ 10% = 500
    # HDFCBANK has 2000 gain, held < 1 year -> Equity STCG @ 15% = 300
    # Total tax = 800
    assert tax["estimated_ltcg_tax"] == 500.0
    assert tax["estimated_stcg_tax"] == 300.0
    assert tax["total_tax_liability"] == 800.0
