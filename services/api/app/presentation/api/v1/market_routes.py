"""Market intelligence routes for news and sector data."""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter

from app.presentation.schemas.api_schemas import (
    MarketNewsResponse,
    MarketOverviewResponse,
    SectorRankingResponse,
)

router = APIRouter()


# Indian market sectors
INDIAN_SECTORS = [
    "Information Technology",
    "Financial Services",
    "Healthcare",
    "Consumer Goods",
    "Automobile",
    "Energy",
    "Metals & Mining",
    "Infrastructure",
    "Pharmaceuticals",
    "Telecom",
    "Real Estate",
    "Chemicals",
    "Media & Entertainment",
    "Textiles",
    "Power",
]


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
    # In production, this fetches from news APIs and applies AI summarization.
    # For now, return the structure showing the expected data format.
    # The actual news fetching will be done by background workers.

    # Return current market structure (will be populated by market data workers)
    return []


@router.get("/sectors", response_model=list[SectorRankingResponse])
async def get_sector_rankings() -> list[SectorRankingResponse]:
    """Get current sector performance rankings.

    Returns sectors ranked by performance across multiple timeframes.
    """
    # In production, this is populated by market data workers.
    # Returns the API contract structure.
    return [
        SectorRankingResponse(
            sector=sector,
            performance_1d=0,
            performance_1w=0,
            performance_1m=0,
            performance_3m=0,
            performance_1y=0,
            top_gainers=[],
            top_losers=[],
        )
        for sector in INDIAN_SECTORS
    ]


@router.get("/overview", response_model=MarketOverviewResponse)
async def get_market_overview() -> MarketOverviewResponse:
    """Get comprehensive market overview.

    Combines news, sector rankings, and market indicators
    into a single dashboard-ready response.
    """
    return MarketOverviewResponse(
        news=[],
        sector_rankings=[
            SectorRankingResponse(
                sector=sector,
                performance_1d=0,
                performance_1w=0,
                performance_1m=0,
                performance_3m=0,
                performance_1y=0,
            )
            for sector in INDIAN_SECTORS
        ],
        updated_at=datetime.now(timezone.utc),
    )
