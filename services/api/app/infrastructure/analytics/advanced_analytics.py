"""Advanced analytics calculating stress testing, tax loss harvesting, bias detection, and goal tracking."""

from __future__ import annotations

from datetime import UTC, date, datetime
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from app.domain.entities import Holding


class AdvancedAnalyticsEngine:
    """Performs stress testing, tax loss harvesting, bias detection, and goal tracking."""

    def calculate_advanced_metrics(
        self, portfolio_id: str, holdings: list[Holding]
    ) -> dict[str, Any]:
        total_value = sum(float(h.current_value) for h in holdings)

        # 1. Stress Tests
        stress_tests = self._run_stress_tests(total_value, holdings)

        # 2. Tax Harvesting
        tax_harv, total_tax_savings = self._calculate_tax_harvesting(holdings)

        # 3. Behavioral Biases
        biases = self._detect_biases(total_value, holdings)

        # 4. Goal Progressions
        goals = self._evaluate_goals(total_value)

        return {
            "portfolio_id": portfolio_id,
            "stress_test": stress_tests,
            "tax_harvesting": tax_harv,
            "total_potential_tax_savings": round(total_tax_savings, 2),
            "behavioral_biases": biases,
            "goals": goals,
            "calculated_at": datetime.now(UTC),
        }

    def _run_stress_tests(self, total_val: float, holdings: list[Holding]) -> list[dict[str, Any]]:
        if total_val <= 0:
            return []

        # Scenario A: RBI Repo Rate Hike (+1.50% basis points)
        new_val_rate = 0.0
        for h in holdings:
            asset_type = h.asset_type.value if hasattr(h.asset_type, "value") else str(h.asset_type)
            c_val = float(h.current_value)
            if asset_type in ("stock", "crypto"):
                new_val_rate += c_val * 0.92  # -8%
            elif asset_type in ("mutual_fund", "real_estate"):
                new_val_rate += c_val * 0.95  # -5%
            else:
                new_val_rate += c_val

        change_rate = new_val_rate - total_val
        change_rate_pct = change_rate / total_val * 100

        # Scenario B: Recession Crash (-20%)
        new_val_recession = 0.0
        for h in holdings:
            asset_type = h.asset_type.value if hasattr(h.asset_type, "value") else str(h.asset_type)
            c_val = float(h.current_value)
            if asset_type == "stock":
                new_val_recession += c_val * 0.80  # -20%
            elif asset_type == "crypto":
                new_val_recession += c_val * 0.60  # -40%
            elif asset_type in ("gold", "bond"):
                new_val_recession += c_val * 1.10  # +10%
            elif asset_type == "mutual_fund":
                new_val_recession += c_val * 0.85  # -15%
            else:
                new_val_recession += c_val

        change_recess = new_val_recession - total_val
        change_recess_pct = change_recess / total_val * 100

        # Scenario C: High Inflation Spike (+2.0%)
        new_val_inflation = 0.0
        for h in holdings:
            asset_type = h.asset_type.value if hasattr(h.asset_type, "value") else str(h.asset_type)
            c_val = float(h.current_value)
            if asset_type == "stock":
                new_val_inflation += c_val * 0.90  # -10%
            elif asset_type == "gold":
                new_val_inflation += c_val * 1.08  # +8%
            elif asset_type == "bond":
                new_val_inflation += c_val * 0.95  # -5%
            elif asset_type == "mutual_fund":
                new_val_inflation += c_val * 0.92  # -8%
            else:
                new_val_inflation += c_val

        change_infl = new_val_inflation - total_val
        change_infl_pct = change_infl / total_val * 100

        return [
            {
                "scenario_name": "RBI Repo Rate Hike (+1.50%)",
                "scenario_description": "Models a credit tightening scenario. Equity valuations compress by ~8% due to higher borrowing costs.",
                "estimated_new_value": round(new_val_rate, 2),
                "change_value": round(change_rate, 2),
                "change_percentage": round(change_rate_pct, 2),
                "impact_level": "negative" if change_rate_pct < -2 else "neutral",
            },
            {
                "scenario_name": "Broad Market Recession (-20%)",
                "scenario_description": "Models a major macro recession. Equities drop 20%, crypto retreats 40%, while safe-haven assets (gold/bonds) appreciate 10%.",
                "estimated_new_value": round(new_val_recession, 2),
                "change_value": round(change_recess, 2),
                "change_percentage": round(change_recess_pct, 2),
                "impact_level": "high_negative" if change_recess_pct < -15 else "negative",
            },
            {
                "scenario_name": "High Inflation Spike (+2.0%)",
                "scenario_description": "Models a stagflationary spike. Equities retreat 10% on margin pressures, commodities gain 8%, and bonds lose 5%.",
                "estimated_new_value": round(new_val_inflation, 2),
                "change_value": round(change_infl, 2),
                "change_percentage": round(change_infl_pct, 2),
                "impact_level": "negative" if change_infl_pct < -4 else "neutral",
            },
        ]

    def _calculate_tax_harvesting(
        self, holdings: list[Holding]
    ) -> tuple[list[dict[str, Any]], float]:
        opportunities = []
        total_savings = 0.0

        for h in holdings:
            gain_loss = float(h.gain_loss)
            if gain_loss >= 0:
                continue

            # Unrealized loss found
            loss = abs(gain_loss)
            buy_date = h.buy_date.date() if isinstance(h.buy_date, datetime) else h.buy_date
            if not buy_date:
                buy_date = date.today()
            days_held = (date.today() - buy_date).days

            asset_type = h.asset_type.value if hasattr(h.asset_type, "value") else str(h.asset_type)

            # Tax offset savings rate (STCG: 15% for equities, LTCG: 10% for equities)
            if asset_type == "stock" or (
                asset_type == "mutual_fund" and "DEBT" not in h.name.upper()
            ):
                if days_held > 365:
                    rate = 0.10  # 10% LTCG offset
                else:
                    rate = 0.15  # 15% STCG offset
            else:
                if days_held > 1095:
                    rate = 0.20  # 20% Debt LTCG offset
                else:
                    rate = 0.30  # 30% slab rate STCG offset

            savings = loss * rate
            total_savings += savings

            opportunities.append(
                {
                    "symbol": h.symbol,
                    "name": h.name,
                    "quantity": float(h.quantity),
                    "current_price": float(h.current_price),
                    "average_buy_price": float(h.average_buy_price),
                    "unrealized_loss": round(loss, 2),
                    "potential_tax_savings": round(savings, 2),
                    "holding_period_days": days_held,
                    "asset_type": asset_type,
                }
            )

        return opportunities, total_savings

    def _detect_biases(self, total_val: float, holdings: list[Holding]) -> list[dict[str, Any]]:
        biases = []
        if total_val <= 0:
            return []

        # Bias A: Concentration Bias
        single_cap_warn = False
        sector_cap_warn = False
        sector_weights: dict[str, float] = {}
        for h in holdings:
            c_val = float(h.current_value)
            weight = c_val / total_val
            if weight > 0.20:
                single_cap_warn = True
            sector = h.sector or "Other"
            sector_weights[sector] = sector_weights.get(sector, 0.0) + weight

        for _sect, w in sector_weights.items():
            if w > 0.40:
                sector_cap_warn = True

        if single_cap_warn or sector_cap_warn:
            biases.append(
                {
                    "bias_name": "Over-Concentration Bias",
                    "severity": "high" if single_cap_warn else "medium",
                    "description": "A high portion of capital is tied up in individual holdings or sectors, compounding volatility risk.",
                    "remedy": "Reallocate holdings to alternative sectors/instruments to cap individual assets at 15% weight.",
                }
            )

        # Bias B: Portfolio Fragmentation / FOMO Bias
        small_positions = sum(1 for h in holdings if (float(h.current_value) / total_val) < 0.03)
        if small_positions >= 5:
            biases.append(
                {
                    "bias_name": "Portfolio Fragmentation / FOMO Bias",
                    "severity": "medium",
                    "description": "Your portfolio holds many tiny positions. This represents potential impulse chasing (FOMO) and creates cash drag.",
                    "remedy": "Consolidate smaller trial positions into primary high-conviction index ETFs or bluechip assets.",
                }
            )

        # Bias C: Loss Aversion
        total_invested = sum(float(h.invested_value) for h in holdings)
        if total_invested > 0:
            overall_return = (total_val - total_invested) / total_invested
            if overall_return < -0.15:
                biases.append(
                    {
                        "bias_name": "Loss Aversion / Sunk Cost Fallacy",
                        "severity": "medium",
                        "description": "Holding onto underperforming positions to avoid realizing a loss, despite better investment opportunities.",
                        "remedy": "Use our tax harvesting suggestions to offset gains and redeploy capital to rising-conviction holdings.",
                    }
                )

        if not biases:
            biases.append(
                {
                    "bias_name": "None Detected",
                    "severity": "low",
                    "description": "No significant behavioral anomalies or over-concentration issues were detected in this portfolio.",
                    "remedy": "Maintain regular rebalancing schedules and dollar-cost average into index funds.",
                }
            )

        return biases

    def _evaluate_goals(self, total_val: float) -> list[dict[str, Any]]:
        standard_goals = [
            ("Emergency Reserve", 100000.0),
            ("Child Education Fund", 1500000.0),
            ("Retirement Nest Egg", 7500000.0),
        ]

        results = []
        for name, target in standard_goals:
            prog = (total_val / target) * 100
            prog = min(100.0, round(prog, 2))

            status = "on_track"
            if prog < 30:
                status = "behind"
            elif prog >= 75:
                status = "ahead"

            results.append(
                {
                    "goal_name": name,
                    "target_amount": target,
                    "current_amount": round(min(total_val, target), 2),
                    "progress_percentage": prog,
                    "status": status,
                }
            )

        return results

    def analyze_sector_rotation(self, holdings: list[Holding]) -> list[dict[str, Any]]:
        """Analyze sector allocation and suggest rotation opportunities.

        Uses economic cycle phases to suggest sector weight adjustments.
        """
        total_val = sum(float(h.current_value) for h in holdings)
        if total_val <= 0:
            return []

        sector_weights: dict[str, float] = {}
        for h in holdings:
            sector = h.sector or "Other"
            sector_weights[sector] = sector_weights.get(sector, 0.0) + float(h.current_value)

        # Convert to percentages
        sector_pcts = {k: round((v / total_val) * 100, 2) for k, v in sector_weights.items()}

        # Recommended weights for balanced Indian portfolio (mid-cycle)
        recommended = {
            "Information Technology": 18.0,
            "Financial Services": 20.0,
            "Consumer Goods": 12.0,
            "Healthcare": 10.0,
            "Energy": 8.0,
            "Industrials": 8.0,
            "Materials": 6.0,
            "Utilities": 4.0,
            "Real Estate": 4.0,
            "Communication": 5.0,
            "Other": 5.0,
        }

        suggestions = []
        for sector, current_pct in sector_pcts.items():
            target_pct = recommended.get(sector, 5.0)
            diff = current_pct - target_pct
            action = "hold"
            if diff > 5:
                action = "reduce"
            elif diff < -5:
                action = "increase"

            suggestions.append(
                {
                    "sector": sector,
                    "current_weight_pct": current_pct,
                    "recommended_weight_pct": target_pct,
                    "deviation_pct": round(diff, 2),
                    "action": action,
                }
            )

        # Sort by absolute deviation (largest first)
        suggestions.sort(key=lambda x: abs(x["deviation_pct"]), reverse=True)
        return suggestions

    def calculate_dividend_plan(self, holdings: list[Holding]) -> dict[str, Any]:
        """Analyze dividend income potential from current holdings.

        Estimates annual dividend income and identifies top dividend payers.
        """
        dividend_holdings = []
        total_annual_dividend = 0.0

        for h in holdings:
            qty = float(h.quantity)
            current_price = float(h.current_price)
            asset_type = h.asset_type.value if hasattr(h.asset_type, "value") else str(h.asset_type)

            # Estimate dividend based on asset type averages
            if asset_type == "stock":
                # Average Indian stock dividend yield ~1.5%
                est_yield = 0.015
            elif asset_type == "mutual_fund":
                est_yield = 0.0  # Growth MFs don't pay dividends
            elif asset_type in ("bond", "fixed_deposit"):
                est_yield = 0.065  # ~6.5% coupon
            elif asset_type == "gold":
                est_yield = 0.0  # Gold doesn't pay dividends
            else:
                est_yield = 0.005

            annual_div = qty * current_price * est_yield
            if annual_div > 0:
                total_annual_dividend += annual_div
                dividend_holdings.append(
                    {
                        "symbol": h.symbol,
                        "name": h.name,
                        "asset_type": asset_type,
                        "estimated_yield_pct": round(est_yield * 100, 2),
                        "annual_dividend": round(annual_div, 2),
                        "current_value": round(qty * current_price, 2),
                    }
                )

        # Sort by annual dividend (highest first)
        dividend_holdings.sort(key=lambda x: x["annual_dividend"], reverse=True)

        monthly_income = total_annual_dividend / 12 if total_annual_dividend > 0 else 0.0

        return {
            "total_annual_dividend": round(total_annual_dividend, 2),
            "monthly_income": round(monthly_income, 2),
            "top_dividend_holdings": dividend_holdings[:10],
            "total_dividend_holdings": len(dividend_holdings),
        }

    def find_opportunity_radar(self, holdings: list[Holding]) -> list[dict[str, Any]]:
        """Identify investment opportunities based on portfolio gaps and fundamentals.

        Analyzes current portfolio for missing asset classes, sectors, and
        suggests areas for potential investment.
        """
        total_val = sum(float(h.current_value) for h in holdings)
        if total_val <= 0:
            return []

        # Current allocations
        asset_alloc: dict[str, float] = {}
        sector_alloc: dict[str, float] = {}
        for h in holdings:
            asset_type = h.asset_type.value if hasattr(h.asset_type, "value") else str(h.asset_type)
            asset_alloc[asset_type] = asset_alloc.get(asset_type, 0.0) + float(h.current_value)
            sector = h.sector or "Other"
            sector_alloc[sector] = sector_alloc.get(sector, 0.0) + float(h.current_value)

        asset_pcts = {k: (v / total_val) * 100 for k, v in asset_alloc.items()}

        opportunities = []

        # Check for missing asset classes
        essential_assets = {
            "gold": {
                "min_pct": 5.0,
                "reason": "Portfolio hedge against inflation and market crashes",
            },
            "bond": {"min_pct": 10.0, "reason": "Stable income and capital preservation"},
            "mutual_fund": {"min_pct": 15.0, "reason": "Diversified professional management"},
            "etf": {"min_pct": 5.0, "reason": "Low-cost diversified market exposure"},
        }

        for asset, info in essential_assets.items():
            current = asset_pcts.get(asset, 0.0)
            if current < info["min_pct"]:
                opportunities.append(
                    {
                        "type": "missing_asset_class",
                        "asset_class": asset,
                        "current_allocation_pct": round(current, 2),
                        "recommended_min_pct": info["min_pct"],
                        "reason": info["reason"],
                        "priority": "high" if current == 0 else "medium",
                    }
                )

        # Check for over-concentration
        for asset, pct in asset_pcts.items():
            if pct > 60:
                opportunities.append(
                    {
                        "type": "over_concentration",
                        "asset_class": asset,
                        "current_allocation_pct": round(pct, 2),
                        "recommended_max_pct": 50.0,
                        "reason": f"Over {pct:.0f}% in {asset} creates unnecessary risk. Diversify.",
                        "priority": "high",
                    }
                )

        # Check if international exposure exists
        has_international = any(h.country and h.country.lower() != "india" for h in holdings)
        if not has_international:
            opportunities.append(
                {
                    "type": "geographic_gap",
                    "asset_class": "international",
                    "current_allocation_pct": 0.0,
                    "recommended_min_pct": 10.0,
                    "reason": "No international exposure. Consider US/global ETFs for geographic diversification.",
                    "priority": "medium",
                }
            )

        # Sort by priority
        priority_order = {"high": 0, "medium": 1, "low": 2}
        opportunities.sort(key=lambda x: priority_order.get(x.get("priority", "low"), 2))

        return opportunities
