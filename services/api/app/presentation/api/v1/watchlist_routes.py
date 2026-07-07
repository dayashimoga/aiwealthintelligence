"""Watchlist API routes with AI intelligence.

Provides endpoints for managing watchlists with price tracking
and AI-powered intelligence for watched symbols.
"""

from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.database.models import WatchlistModel
from app.infrastructure.database.session import get_db_session
from app.infrastructure.market.market_data_service import market_data_service
from app.presentation.middleware.auth_dependency import get_current_user

router = APIRouter()


class WatchlistCreate(BaseModel):
    """Schema for creating a watchlist."""

    name: str = Field(min_length=1, max_length=255, default="My Watchlist")
    symbols: list[str] = Field(default_factory=list)


class WatchlistAddSymbol(BaseModel):
    """Schema for adding a symbol to a watchlist."""

    symbol: str = Field(min_length=1, max_length=50)
    alert_above: float | None = None
    alert_below: float | None = None


@router.get("/watchlists")
async def list_watchlists(
    current_user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    """List all watchlists for the current user."""
    stmt = (
        select(WatchlistModel)
        .where(WatchlistModel.user_id == current_user["id"])
        .order_by(WatchlistModel.created_at.desc())
    )
    result = await session.execute(stmt)
    watchlists = list(result.scalars().all())
    return {
        "watchlists": [
            {
                "id": w.id,
                "name": w.name,
                "symbols": w.symbols,
                "alerts": w.alerts,
                "symbol_count": len(w.symbols),
                "created_at": w.created_at.isoformat() if w.created_at else None,
            }
            for w in watchlists
        ]
    }


@router.post("/watchlists", status_code=201)
async def create_watchlist(
    data: WatchlistCreate,
    current_user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    """Create a new watchlist."""
    watchlist = WatchlistModel(
        id=str(uuid.uuid4()),
        user_id=current_user["id"],
        name=data.name,
        symbols=data.symbols,
        alerts=[],
    )
    session.add(watchlist)
    await session.commit()
    await session.refresh(watchlist)
    return {
        "id": watchlist.id,
        "name": watchlist.name,
        "symbols": watchlist.symbols,
        "alerts": watchlist.alerts,
    }


@router.post("/watchlists/{watchlist_id}/symbols")
async def add_symbol_to_watchlist(
    watchlist_id: str,
    data: WatchlistAddSymbol,
    current_user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    """Add a symbol to a watchlist with optional price alerts."""
    stmt = select(WatchlistModel).where(
        WatchlistModel.id == watchlist_id,
        WatchlistModel.user_id == current_user["id"],
    )
    result = await session.execute(stmt)
    watchlist = result.scalar_one_or_none()
    if not watchlist:
        raise HTTPException(status_code=404, detail="Watchlist not found")

    symbol = data.symbol.upper().strip()
    if symbol not in watchlist.symbols:
        symbols = list(watchlist.symbols)
        symbols.append(symbol)
        watchlist.symbols = symbols

        if data.alert_above or data.alert_below:
            alerts = list(watchlist.alerts)
            alert_entry: dict[str, Any] = {"symbol": symbol}
            if data.alert_above:
                alert_entry["above"] = data.alert_above
            if data.alert_below:
                alert_entry["below"] = data.alert_below
            alerts.append(alert_entry)
            watchlist.alerts = alerts

        await session.commit()

    return {
        "id": watchlist.id,
        "symbols": watchlist.symbols,
        "alerts": watchlist.alerts,
    }


@router.delete("/watchlists/{watchlist_id}/symbols/{symbol}")
async def remove_symbol_from_watchlist(
    watchlist_id: str,
    symbol: str,
    current_user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    """Remove a symbol from a watchlist."""
    stmt = select(WatchlistModel).where(
        WatchlistModel.id == watchlist_id,
        WatchlistModel.user_id == current_user["id"],
    )
    result = await session.execute(stmt)
    watchlist = result.scalar_one_or_none()
    if not watchlist:
        raise HTTPException(status_code=404, detail="Watchlist not found")

    symbol_upper = symbol.upper().strip()
    symbols = [s for s in watchlist.symbols if s != symbol_upper]
    watchlist.symbols = symbols
    alerts = [a for a in watchlist.alerts if a.get("symbol") != symbol_upper]
    watchlist.alerts = alerts

    await session.commit()
    return {"id": watchlist.id, "symbols": watchlist.symbols}


@router.get("/watchlists/{watchlist_id}/intelligence")
async def get_watchlist_intelligence(
    watchlist_id: str,
    current_user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    """Get AI-powered intelligence for all symbols in a watchlist.

    Returns live prices, fundamentals, analyst estimates, and news
    for each watched symbol.
    """
    stmt = select(WatchlistModel).where(
        WatchlistModel.id == watchlist_id,
        WatchlistModel.user_id == current_user["id"],
    )
    result = await session.execute(stmt)
    watchlist = result.scalar_one_or_none()
    if not watchlist:
        raise HTTPException(status_code=404, detail="Watchlist not found")

    intelligence: list[dict[str, Any]] = []
    for symbol in watchlist.symbols[:20]:  # Limit to 20 symbols
        try:
            price = await market_data_service.get_live_price(symbol)
            fundamentals = await market_data_service.get_fundamental_data(symbol)
            estimates = await market_data_service.get_analyst_estimates(symbol)
            news = await market_data_service.get_ticker_news(symbol)

            # Check alerts
            triggered_alerts: list[str] = []
            for alert in watchlist.alerts:
                if alert.get("symbol") == symbol:
                    if alert.get("above") and price >= alert["above"]:
                        triggered_alerts.append(f"Price above ₹{alert['above']:,.2f}")
                    if alert.get("below") and price <= alert["below"]:
                        triggered_alerts.append(f"Price below ₹{alert['below']:,.2f}")

            intelligence.append(
                {
                    "symbol": symbol,
                    "current_price": price,
                    "pe_ratio": fundamentals.get("pe_ratio"),
                    "market_cap": fundamentals.get("market_cap"),
                    "fifty_two_week_high": fundamentals.get("fifty_two_week_high"),
                    "fifty_two_week_low": fundamentals.get("fifty_two_week_low"),
                    "sector": fundamentals.get("sector", ""),
                    "analyst_target": estimates.get("target_mean"),
                    "analyst_recommendation": estimates.get("recommendation_key"),
                    "recent_news": [
                        {"title": n.get("title", ""), "source": n.get("source", "")}
                        for n in (news or [])[:3]
                    ],
                    "triggered_alerts": triggered_alerts,
                }
            )
        except Exception:
            intelligence.append(
                {
                    "symbol": symbol,
                    "current_price": 0,
                    "error": "Failed to fetch data",
                }
            )

    return {
        "watchlist_id": watchlist_id,
        "watchlist_name": watchlist.name,
        "symbols_count": len(watchlist.symbols),
        "intelligence": intelligence,
    }


@router.delete("/watchlists/{watchlist_id}", status_code=204)
async def delete_watchlist(
    watchlist_id: str,
    current_user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> None:
    """Delete a watchlist."""
    stmt = select(WatchlistModel).where(
        WatchlistModel.id == watchlist_id,
        WatchlistModel.user_id == current_user["id"],
    )
    result = await session.execute(stmt)
    watchlist = result.scalar_one_or_none()
    if not watchlist:
        raise HTTPException(status_code=404, detail="Watchlist not found")
    await session.delete(watchlist)
    await session.commit()
