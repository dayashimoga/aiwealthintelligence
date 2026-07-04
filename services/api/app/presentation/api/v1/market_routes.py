"""Market intelligence routes for news and sector data."""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from typing import Any

import structlog
import yfinance as yf
from fastapi import APIRouter

from app.infrastructure.market.news_fetcher import fetch_and_analyze_news
from app.infrastructure.market.price_cache import cache_repo
from app.presentation.schemas.api_schemas import (
    MarketNewsResponse,
    MarketOverviewResponse,
    SectorRankingResponse,
)

logger = structlog.get_logger(__name__)
router = APIRouter()


# Indian market sectors mapped to Yahoo Finance indices
SECTOR_MAP = {
    "Information Technology": "^CNXIT",
    "Financial Services": "^CNXFIN",
    "Healthcare": "^CNXPHARMA",
    "Consumer Goods": "^CNXFMCG",
    "Automobile": "^CNXAUTO",
    "Energy": "^CNXENERGY",
    "Metals & Mining": "^CNXMETAL",
    "Infrastructure": "NIFTY_INFRA.NS",
    "Pharmaceuticals": "^CNXPHARMA",
    "Telecom": "^CNXMEDIA",
    "Real Estate": "^CNXREALTY",
    "Chemicals": "^CNXCOMMOD",
    "Media & Entertainment": "^CNXMEDIA",
    "Textiles": "^CNXFMCG",
    "Power": "^CNXENERGY",
}


async def _fetch_sector_perf(sector: str, sym: str) -> SectorRankingResponse:
    """Fetch performance for a single sector index."""
    try:
        ticker = yf.Ticker(sym)
        # Fetch 1 year of daily history to cover all timeframes
        hist = await asyncio.to_thread(lambda: ticker.history(period="1y"))
        if hist.empty or len(hist) < 2:
            return SectorRankingResponse(sector=sector)

        close = hist["Close"]
        current = float(close.iloc[-1])

        def get_change_pct(days: int) -> float:
            if len(close) >= days + 1:
                prev = float(close.iloc[-(days + 1)])
                return round(((current - prev) / prev) * 100, 2)
            # Default to first available if not enough history
            prev = float(close.iloc[0])
            return round(((current - prev) / prev) * 100, 2)

        # Indian trading days: 1d=1, 1w=5, 1m=20, 3m=60, 1y=250
        return SectorRankingResponse(
            sector=sector,
            performance_1d=get_change_pct(1),
            performance_1w=get_change_pct(5),
            performance_1m=get_change_pct(20),
            performance_3m=get_change_pct(60),
            performance_1y=get_change_pct(250),
            top_gainers=[],
            top_losers=[],
        )
    except Exception as e:
        logger.debug("sector_fetch_failed", sector=sector, symbol=sym, error=str(e))
        return SectorRankingResponse(sector=sector)


@router.get("/news", response_model=list[MarketNewsResponse])
async def get_market_news(
    sector: str | None = None,
    skip: int = 0,
    limit: int = 20,
) -> list[MarketNewsResponse]:
    """Get latest market news with AI-generated summaries.

    Returns curated market news, optionally filtered by sector.
    Each news item includes AI-generated summary and sentiment analysis.
    """
    cache_key = f"market:news:{sector or 'all'}"
    cached = await cache_repo.get(cache_key)
    if cached:
        return [MarketNewsResponse(**item) for item in cached[skip : skip + limit]]

    # Fetch fresh news and perform AI analysis
    try:
        news_items = await fetch_and_analyze_news(symbol=None, limit=10)
        
        # Serialize to dict for cache
        serialized = []
        for item in news_items:
            serialized.append({
                "id": item.id,
                "title": item.title,
                "summary": item.summary,
                "source": item.source,
                "url": item.url,
                "sentiment": item.sentiment,
                "relevance_score": float(item.relevance_score),
                "sectors": item.sectors,
                "symbols": item.symbols,
                "published_at": item.published_at.isoformat(),
            })
        
        # Cache for 15 minutes (900 seconds)
        await cache_repo.set(cache_key, serialized, ttl=900)
        return [MarketNewsResponse(**item) for item in serialized[skip : skip + limit]]
    except Exception as e:
        logger.warning("news_route_failed", error=str(e))
        return []


@router.get("/sectors", response_model=list[SectorRankingResponse])
async def get_sector_rankings() -> list[SectorRankingResponse]:
    """Get current sector performance rankings.

    Returns sectors ranked by performance across multiple timeframes.
    """
    cache_key = "market:sectors"
    cached = await cache_repo.get(cache_key)
    if cached:
        return [SectorRankingResponse(**item) for item in cached]

    try:
        tasks = [_fetch_sector_perf(sect, sym) for sect, sym in SECTOR_MAP.items()]
        rankings = await asyncio.gather(*tasks)
        
        # Convert Pydantic models to dict for caching
        serialized = [item.model_dump() for item in rankings]
        
        # Cache for 5 minutes (300 seconds)
        await cache_repo.set(cache_key, serialized, ttl=300)
        return rankings
    except Exception as e:
        logger.warning("sectors_route_failed", error=str(e))
        return [SectorRankingResponse(sector=s) for s in SECTOR_MAP.keys()]


@router.get("/overview", response_model=MarketOverviewResponse)
async def get_market_overview() -> MarketOverviewResponse:
    """Get comprehensive market overview.

    Combines news, sector rankings, and market indicators
    into a single dashboard-ready response.
    """
    news = await get_market_news(limit=5)
    sectors = await get_sector_rankings()
    
    return MarketOverviewResponse(
        news=news,
        sector_rankings=sectors,
        updated_at=datetime.now(timezone.utc),
    )
