"""AI Copilot services for Daily Brief, Scenario Simulator, and Portfolio Doctor.

Leverages the AI provider to generate structured, actionable portfolio insights
using real market news, fundamentals, and portfolio metrics.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any

import structlog

from app.infrastructure.ai.ai_provider import AIProvider
from app.shared.exceptions import AIProviderError

logger = structlog.get_logger(__name__)


# ============================================================
# Prompts
# ============================================================

DAILY_BRIEF_SYSTEM_PROMPT = """You are an expert wealth advisor and portfolio manager AI.
Your goal is to synthesize a daily brief for a client's wealth portfolio based on:
1. The client's active stock/mutual fund holdings.
2. The latest market news, sentiment, and sector performance.

You must respond in valid JSON format matching this schema:
{
  "summary": "A concise paragraph summarizing the market trend and client's portfolio state.",
  "market_sentiment": "positive",  // positive, negative, or neutral
  "top_gainers": [
     {"symbol": "TCS", "gain_pct": 2.5, "price": 3850.0}
  ],
  "top_losers": [
     {"symbol": "INFY", "loss_pct": -1.2, "price": 1420.0}
  ],
  "actionable_insights": [
     "A key recommendation or observation based on news/performance."
  ]
}

Provide ONLY the raw JSON block without markdown formatting or backticks.
"""

PORTFOLIO_DOCTOR_SYSTEM_PROMPT = """You are a senior wealth planner and portfolio doctor AI.
Your task is to analyze a client's portfolio holdings for health issues, asset allocation imbalances, diversification issues, cash drag, high fees, or overlap.
We have identified the following raw rule-based issues:
{raw_issues}

Please perform a comprehensive diagnostic review of the holdings and return a detailed report in JSON format matching this schema:
{
  "health_score": 85,  // integer 0 to 100
  "issues": [
    {
      "severity": "high",  // high, medium, or low
      "title": "Short title of the issue",
      "description": "Detailed explanation of why this is a risk",
      "recommendation": "Actionable instructions on how to remedy this issue"
    }
  ]
}

Provide ONLY the raw JSON block without markdown formatting or backticks.
"""

SCENARIO_SYSTEM_PROMPT = """You are a senior portfolio strategist AI.
Compare the original portfolio metrics with the simulated portfolio metrics after performing the user's proposed actions.
Provide an impact summary explaining the key differences and action recommendations.

Original Metrics:
{original_metrics}

Simulated Metrics:
{simulated_metrics}

Proposed Actions:
{proposed_actions}

You must respond in valid JSON format matching this schema:
{
  "impact_summary": "A detailed explanation of how these trades impact diversification, returns, risk, and asset allocation.",
  "recommendations": [
    "Alternative action or safety hedge to consider."
  ]
}

Provide ONLY the raw JSON block without markdown formatting or backticks.
"""


# ============================================================
# Copilot Functions
# ============================================================


async def generate_daily_brief(
    provider: AIProvider,
    holdings: list[dict[str, Any]],
    news_articles: list[dict[str, Any]],
) -> dict[str, Any]:
    """Generate a daily AI brief for the user's portfolio."""
    holdings_context = []
    for h in holdings:
        holdings_context.append(
            f"- {h.get('symbol')} ({h.get('name')}): quantity={h.get('quantity')}, "
            f"current_price=₹{h.get('current_price')}, gain/loss={h.get('gain_loss_pct')}%"
        )

    news_context = []
    for art in news_articles[:5]:
        news_context.append(f"- Title: {art.get('title')}\n  Source: {art.get('source')}\n  Summary: {art.get('description')}")

    user_prompt = f"""Generate a daily brief for my portfolio:

Holdings:
{chr(10).join(holdings_context) if holdings_context else "None"}

Market/News Context:
{chr(10).join(news_context) if news_context else "None"}
"""

    try:
        response = await provider.complete(
            messages=[
                {"role": "system", "content": DAILY_BRIEF_SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
            response_format={"type": "json_object"},
        )
        return json.loads(response)
    except Exception as e:
        logger.error("daily_brief_generation_failed", error=str(e))
        # Graceful fallback
        return {
            "summary": "Could not generate automated daily brief. Please check market news manually.",
            "market_sentiment": "neutral",
            "top_gainers": [],
            "top_losers": [],
            "actionable_insights": ["Failed to connect to AI provider to compile recommendations."],
        }


async def generate_portfolio_doctor(
    provider: AIProvider,
    holdings: list[dict[str, Any]],
) -> dict[str, Any]:
    """Perform health checks and generate portfolio doctor diagnostic report."""
    if not holdings:
        return {
            "health_score": 100,
            "issues": [
                {
                    "severity": "low",
                    "title": "Empty Portfolio",
                    "description": "You do not have any holdings in this portfolio yet.",
                    "recommendation": "Import a CAS statement or add your holdings to get started.",
                }
            ],
            "diversification_hhi": 0.0,
            "sector_concentration_pct": 0.0,
            "cash_drag_pct": 0.0,
        }

    total_val = sum(h.get("quantity", 0) * h.get("current_price", 0) for h in holdings)
    if total_val <= 0:
        total_val = 1.0  # Avoid division by zero

    # Calculate concentrations and HHI
    sector_values: dict[str, float] = {}
    hhi = 0.0
    cash_val = 0.0

    for h in holdings:
        h_val = h.get("quantity", 0) * h.get("current_price", 0)
        weight = h_val / total_val
        hhi += (weight * 100) ** 2

        sector = h.get("sector") or "Other"
        sector_values[sector] = sector_values.get(sector, 0.0) + h_val

        # Cash check
        asset_type = str(h.get("asset_type", "")).lower()
        if "cash" in asset_type or "liquid" in asset_type or "money market" in asset_type:
            cash_val += h_val

    max_sector_name = "Other"
    max_sector_pct = 0.0
    if sector_values:
        max_sector_name = max(sector_values, key=sector_values.get)
        max_sector_pct = (sector_values[max_sector_name] / total_val) * 100

    cash_drag_pct = (cash_val / total_val) * 100

    raw_issues = []
    # Concentrated single holding
    for h in holdings:
        h_val = h.get("quantity", 0) * h.get("current_price", 0)
        h_weight = (h_val / total_val) * 100
        if h_weight > 20:
            raw_issues.append(
                f"- High Concentration Risk: Single holding {h.get('symbol')} makes up {h_weight:.1f}% of the portfolio."
            )

    # Concentrated sector
    if max_sector_pct > 40:
        raw_issues.append(
            f"- Sector Concentration: Over {max_sector_pct:.1f}% of the portfolio is invested in the {max_sector_name} sector."
        )

    # Cash drag
    if cash_drag_pct > 25:
        raw_issues.append(
            f"- Cash Drag: {cash_drag_pct:.1f}% of the portfolio is in low-yielding cash/liquid assets, drag on overall returns."
        )

    # High HHI
    if hhi > 3000:
        raw_issues.append(
            f"- Poor Diversification: Herfindahl-Hirschman Index (HHI) is high ({hhi:.0f}), indicating a highly concentrated portfolio."
        )

    raw_issues_str = "\n".join(raw_issues) if raw_issues else "No automated issues detected."

    user_prompt = f"""Analyze the health of this portfolio:

Holdings:
{json.dumps(holdings, indent=2)}

HHI Score: {hhi:.1f}
Max Sector Concentration: {max_sector_name} ({max_sector_pct:.1f}%)
Cash Drag: {cash_drag_pct:.1f}%
"""

    try:
        response = await provider.complete(
            messages=[
                {"role": "system", "content": PORTFOLIO_DOCTOR_SYSTEM_PROMPT.replace("{raw_issues}", raw_issues_str)},
                {"role": "user", "content": user_prompt},
            ],
            response_format={"type": "json_object"},
        )
        data = json.loads(response)
        data["diversification_hhi"] = round(hhi, 2)
        data["sector_concentration_pct"] = round(max_sector_pct, 2)
        data["cash_drag_pct"] = round(cash_drag_pct, 2)
        return data
    except Exception as e:
        logger.error("portfolio_doctor_failed", error=str(e))
        return {
            "health_score": 75,
            "issues": [
                {
                    "severity": "medium",
                    "title": "Automated Review",
                    "description": f"Automated rule-based checks found max sector concentration of {max_sector_pct:.1f}%.",
                    "recommendation": "Review your asset allocations and diversify across multiple sectors.",
                }
            ],
            "diversification_hhi": round(hhi, 2),
            "sector_concentration_pct": round(max_sector_pct, 2),
            "cash_drag_pct": round(cash_drag_pct, 2),
        }


async def simulate_scenario(
    provider: AIProvider,
    holdings: list[dict[str, Any]],
    actions: list[dict[str, Any]],
    original_metrics: dict[str, Any],
) -> dict[str, Any]:
    """Simulate changes to portfolio holdings and evaluate impact via AI."""
    # Build simulated holdings
    simulated_holdings = {h.get("symbol"): dict(h) for h in holdings}

    for action in actions:
        sym = action.get("symbol")
        act = str(action.get("action")).lower()
        qty = float(action.get("quantity", 0))
        price = action.get("price")

        if sym not in simulated_holdings:
            # Create dummy default holding entry
            simulated_holdings[sym] = {
                "symbol": sym,
                "name": sym,
                "quantity": 0.0,
                "current_price": float(price) if price else 100.0,
                "sector": "Other",
                "asset_type": "stock",
            }

        h = simulated_holdings[sym]
        if price:
            h["current_price"] = float(price)

        if act == "buy":
            h["quantity"] = float(h.get("quantity", 0)) + qty
        elif act == "sell":
            h["quantity"] = max(0.0, float(h.get("quantity", 0)) - qty)

    # Filter out zero quantities
    sim_holdings_list = [h for h in simulated_holdings.values() if h.get("quantity", 0) > 0]

    # Calculate simulated portfolio value
    sim_total_val = sum(h.get("quantity", 0) * h.get("current_price", 0) for h in sim_holdings_list)
    orig_total_val = original_metrics.get("total_value", 0.0)

    # Calculate simulated HHI & Risk score
    sim_hhi = 0.0
    sim_risk = 0.0
    for h in sim_holdings_list:
        h_val = h.get("quantity", 0) * h.get("current_price", 0)
        weight = h_val / sim_total_val if sim_total_val > 0 else 0
        sim_hhi += (weight * 100) ** 2

        # Risk score calculation logic based on asset type
        asset_type = str(h.get("asset_type", "")).lower()
        if "stock" in asset_type:
            sim_risk += 4.0 * weight
        elif "debt" in asset_type:
            sim_risk += 2.0 * weight
        else:
            sim_risk += 3.0 * weight

    sim_risk_score = round(sim_risk, 1)

    simulated_metrics = {
        "total_value": sim_total_val,
        "xirr": original_metrics.get("xirr"),  # Simplification
        "diversification_score": max(0.0, min(100.0, 100.0 - (sim_hhi / 100.0))),
        "risk_score": sim_risk_score,
    }

    try:
        response = await provider.complete(
            messages=[
                {"role": "system", "content": SCENARIO_SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": (
                        "Compare original and simulated metrics:\n"
                        f"Original: {original_metrics}\n"
                        f"Simulated: {simulated_metrics}\n"
                        f"Proposed Actions: {actions}"
                    ),
                },
            ],
            response_format={"type": "json_object"},
        )
        data = json.loads(response)
        return {
            "original_metrics": original_metrics,
            "simulated_metrics": simulated_metrics,
            "impact_summary": data.get("impact_summary", "Simulated metrics calculated successfully."),
            "recommendations": data.get("recommendations", []),
        }
    except Exception as e:
        logger.error("scenario_simulation_failed", error=str(e))
        return {
            "original_metrics": original_metrics,
            "simulated_metrics": simulated_metrics,
            "impact_summary": f"Trade simulation results: New total portfolio valuation estimated at ₹{sim_total_val:,.2f}.",
            "recommendations": ["Review individual sector allocations for potential overlap concerns."],
        }
