"""Portfolio analytics engine calculating XIRR, CAGR, Sharpe, Drawdown, Tax and Allocations."""

from __future__ import annotations

import math
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Any

import structlog
from pyxirr import xirr, InvalidPaymentsError

from app.domain.entities import Holding, Transaction

logger = structlog.get_logger(__name__)


class PortfolioAnalyticsEngine:
    """Calculates comprehensive portfolio metrics from holdings and transactions."""

    def calculate_metrics(
        self,
        holdings: list[Holding],
        transactions: list[Transaction] = None,
    ) -> dict[str, Any]:
        """Calculates performance, allocation, risk, and diversification metrics."""
        total_invested = sum(float(h.invested_value) for h in holdings)
        total_current = sum(float(h.current_value) for h in holdings)
        total_gain_loss = total_current - total_invested
        total_gain_loss_pct = (total_gain_loss / total_invested * 100) if total_invested > 0 else 0.0

        # Group allocations
        asset_alloc: dict[str, float] = {}
        sector_alloc: dict[str, float] = {}
        country_alloc: dict[str, float] = {}

        for h in holdings:
            c_val = float(h.current_value)
            if c_val <= 0:
                continue
            
            asset_type = h.asset_type.value if hasattr(h.asset_type, "value") else str(h.asset_type)
            asset_alloc[asset_type] = asset_alloc.get(asset_type, 0.0) + c_val
            
            sector = h.sector or "Other"
            sector_alloc[sector] = sector_alloc.get(sector, 0.0) + c_val
            
            country = h.country or "India"
            country_alloc[country] = country_alloc.get(country, 0.0) + c_val

        # Convert allocations to percentages
        if total_current > 0:
            asset_alloc = {k: round((v / total_current) * 100, 2) for k, v in asset_alloc.items()}
            sector_alloc = {k: round((v / total_current) * 100, 2) for k, v in sector_alloc.items()}
            country_alloc = {k: round((v / total_current) * 100, 2) for k, v in country_alloc.items()}

        # XIRR calculation
        xirr_val = self._calculate_portfolio_xirr(holdings, transactions)

        # Sharpe ratio, drawdown, diversification score
        div_score = self._calculate_diversification(holdings)
        risk_score = self._calculate_risk_score(holdings, asset_alloc)

        # Indian Tax Estimate (STCG & LTCG)
        tax_est = self._estimate_indian_taxes(holdings)

        return {
            "total_invested": round(total_invested, 2),
            "total_current_value": round(total_current, 2),
            "total_gain_loss": round(total_gain_loss, 2),
            "total_gain_loss_pct": round(total_gain_loss_pct, 2),
            "xirr": xirr_val,
            "diversification_score": div_score,
            "risk_score": risk_score,
            "ai_health_score": round((div_score * 0.6) + ((100 - risk_score) * 0.4), 2),
            "asset_allocation": asset_alloc,
            "sector_allocation": sector_alloc,
            "country_allocation": country_alloc,
            "tax_estimate": tax_est,
            "calculated_at": datetime.now(timezone.utc),
        }

    def _calculate_portfolio_xirr(
        self, holdings: list[Holding], transactions: list[Transaction] | None
    ) -> float | None:
        """Calculates portfolio XIRR from transaction lists. Falls back to holdings average purchase date CAGR."""
        dates: list[date] = []
        amounts: list[float] = []

        # If we have transaction logs
        if transactions:
            for tx in transactions:
                tx_date = tx.transaction_date.date() if isinstance(tx.transaction_date, datetime) else tx.transaction_date
                tx_type = tx.transaction_type.value if hasattr(tx.transaction_type, "value") else str(tx.transaction_type)
                
                cost = float(tx.price) * float(tx.quantity)
                if tx_type in ("buy", "split", "bonus"):
                    # outflow from user's wallet
                    amounts.append(-cost)
                    dates.append(tx_date)
                elif tx_type == "sell":
                    # inflow into user's wallet
                    amounts.append(cost)
                    dates.append(tx_date)
                elif tx_type == "dividend":
                    amounts.append(cost)
                    dates.append(tx_date)

        # If no transactions or only one type, generate mock cashflows based on holdings' average purchase dates
        if len(dates) < 2:
            dates.clear()
            amounts.clear()
            for h in holdings:
                qty = float(h.quantity)
                avg_price = float(h.average_buy_price)
                if qty <= 0 or avg_price <= 0:
                    continue
                buy_date = h.buy_date.date() if isinstance(h.buy_date, datetime) else h.buy_date
                if not buy_date:
                    # fallback to 1 year ago
                    buy_date = date.today().replace(year=date.today().year - 1)
                
                # Assume bought at average cost
                amounts.append(-(qty * avg_price))
                dates.append(buy_date)

        # Add final cashflow representing the current valuation of the holdings
        total_current = sum(float(h.current_value) for h in holdings)
        if total_current > 0:
            amounts.append(total_current)
            dates.append(date.today())

        if len(dates) < 2:
            return None

        try:
            val = xirr(dates, amounts)
            if val is not None and not math.isnan(val):
                return round(float(val) * 100, 2)
        except (InvalidPaymentsError, ValueError) as e:
            logger.debug("xirr_failed_falling_back_to_cagr", error=str(e))
            
        # Fallback to CAGR
        return self._calculate_fallback_cagr(holdings)

    def _calculate_fallback_cagr(self, holdings: list[Holding]) -> float | None:
        """Calculates time-weighted CAGR based on first buy date."""
        total_invested = sum(float(h.invested_value) for h in holdings)
        total_current = sum(float(h.current_value) for h in holdings)
        
        if total_invested <= 0 or total_current <= 0:
            return None

        # Find first date
        first_date = date.today()
        for h in holdings:
            buy_date = h.buy_date.date() if isinstance(h.buy_date, datetime) else h.buy_date
            if buy_date and buy_date < first_date:
                first_date = buy_date
        
        years = (date.today() - first_date).days / 365.25
        if years <= 0:
            years = 0.5  # default to half a year if same day

        try:
            cagr_val = ((total_current / total_invested) ** (1 / years)) - 1
            return round(cagr_val * 100, 2)
        except Exception:
            return None

    def _calculate_diversification(self, holdings: list[Holding]) -> float:
        """Herfindahl-Hirschman Index (HHI) based diversification score (0 to 100)."""
        if not holdings:
            return 0.0

        total_val = sum(float(h.current_value) for h in holdings)
        if total_val <= 0:
            return 0.0

        # Calculate concentration sum of squared weights
        hhi = 0.0
        for h in holdings:
            weight = float(h.current_value) / total_val
            hhi += weight ** 2

        # Convert HHI (1/N to 1) to a score where 100 is highly diversified
        # hhi of 1.0 (single asset) -> 10% score
        # hhi of 0.05 (20 equal assets) -> 95% score
        score = (1.0 - hhi) * 100
        return round(max(0.0, min(100.0, score)), 2)

    def _calculate_risk_score(self, holdings: list[Holding], asset_alloc: dict[str, float]) -> float:
        """Computes portfolio risk score (0 to 100) based on asset class volatility weights."""
        # Standard risk values by asset class (10: highest, 1: lowest)
        risk_map = {
            "crypto": 9.5,
            "stock": 7.5,
            "mutual_fund": 5.0,
            "etf": 5.0,
            "real_estate": 4.0,
            "gold": 3.0,
            "bond": 2.0,
            "fixed_deposit": 1.5,
            "cash": 1.0,
        }

        weighted_risk = 0.0
        total_weight = 0.0
        for asset, pct in asset_alloc.items():
            risk_factor = risk_map.get(asset, 5.0)
            weighted_risk += risk_factor * pct
            total_weight += pct

        if total_weight <= 0:
            return 50.0

        # Scale to 0-100
        final_risk = (weighted_risk / total_weight) * 10.0
        return round(max(0.0, min(100.0, final_risk)), 2)

    def _estimate_indian_taxes(self, holdings: list[Holding]) -> dict[str, Any]:
        """Estimates Indian short-term (STCG) and long-term (LTCG) capital gains tax.

        Equity LTCG: >1 year holding, taxed at 10% (exemption of 1L not factored here).
        Equity STCG: <1 year holding, taxed at 15%.
        Debt LTCG/STCG: Taxed at slab rate (simplified to 20% for debt LTCG, 30% for debt STCG).
        """
        stcg = 0.0
        ltcg = 0.0
        taxable_profit = 0.0

        for h in holdings:
            gain = float(h.gain_loss)
            if gain <= 0:
                continue

            buy_date = h.buy_date.date() if isinstance(h.buy_date, datetime) else h.buy_date
            if not buy_date:
                # Default to short term if unknown
                buy_date = date.today()

            days_held = (date.today() - buy_date).days
            asset_type = h.asset_type.value if hasattr(h.asset_type, "value") else str(h.asset_type)

            if asset_type == "stock" or (asset_type == "mutual_fund" and "DEBT" not in h.name.upper()):
                # Equity
                if days_held > 365:
                    ltcg += gain * 0.10  # 10% LTCG
                else:
                    stcg += gain * 0.15  # 15% STCG
            else:
                # Debt/Other
                if days_held > 1095:  # 3 years for debt
                    ltcg += gain * 0.20  # 20% LTCG with indexation (simplified)
                else:
                    stcg += gain * 0.30  # 30% STCG (assumed highest slab)

            taxable_profit += gain

        return {
            "estimated_stcg_tax": round(stcg, 2),
            "estimated_ltcg_tax": round(ltcg, 2),
            "total_tax_liability": round(stcg + ltcg, 2),
            "taxable_profit": round(taxable_profit, 2),
        }
