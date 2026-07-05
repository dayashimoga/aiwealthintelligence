"""Background job scheduler for periodic market data syncing.

Uses APScheduler to update holding prices and fetch market news at regular intervals.
"""

from __future__ import annotations

from datetime import datetime, timezone

import structlog
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from sqlalchemy import select, update

from app.infrastructure.database.models import HoldingModel
from app.infrastructure.database.session import sessionmanager
from app.infrastructure.market.market_data_service import market_data_service
from app.infrastructure.market.news_fetcher import fetch_and_analyze_news
from app.presentation.api.v1.market_routes import get_market_news

logger = structlog.get_logger(__name__)

scheduler = AsyncIOScheduler()


async def sync_holding_prices() -> None:
    """Job to refresh all holding current_prices from yfinance."""
    logger.info("scheduler_job_started", job="sync_holding_prices")
    try:
        async with sessionmanager.session() as session:
            # Get all unique symbols in database
            stmt = select(HoldingModel.symbol).distinct()
            result = await session.execute(stmt)
            symbols = [row[0] for row in result.all() if row[0]]

            if not symbols:
                logger.info("scheduler_no_symbols_to_sync")
                return

            logger.info("scheduler_syncing_symbols", count=len(symbols))
            updated_count = 0
            for sym in symbols:
                # Fetch price
                price = await market_data_service.get_live_price(sym)
                if price > 0:
                    update_stmt = (
                        update(HoldingModel)
                        .where(HoldingModel.symbol == sym)
                        .values(current_price=price, updated_at=datetime.now(timezone.utc))
                    )
                    await session.execute(update_stmt)
                    updated_count += 1

            # Populate missing sector and industry details if empty
            missing_stmt = select(HoldingModel).where(
                (HoldingModel.sector == "") | (HoldingModel.industry == "")
            )
            missing_result = await session.execute(missing_stmt)
            missing_holdings = missing_result.scalars().all()
            
            if missing_holdings:
                logger.info("scheduler_populating_missing_metadata", count=len(missing_holdings))
                for h in missing_holdings:
                    metadata = await market_data_service.get_fundamental_data(h.symbol, h.asset_type)
                    if metadata:
                        h.sector = metadata.get("sector") or "Other"
                        h.industry = metadata.get("industry") or "Other"
                        h.updated_at = datetime.now(timezone.utc)
            
            await session.commit()
            logger.info("scheduler_job_completed", job="sync_holding_prices", updated=updated_count)
    except Exception as e:
        logger.error("scheduler_job_failed", job="sync_holding_prices", error=str(e))


async def refresh_market_news() -> None:
    """Job to pre-cache general market news."""
    logger.info("scheduler_job_started", job="refresh_market_news")
    try:
        # Calling get_market_news directly will trigger a fetch and cache
        await get_market_news()
        logger.info("scheduler_job_completed", job="refresh_market_news")
    except Exception as e:
        logger.error("scheduler_job_failed", job="refresh_market_news", error=str(e))


def start_scheduler() -> None:
    """Register jobs and start the background scheduler."""
    # Run price sync every 15 minutes
    scheduler.add_job(sync_holding_prices, "interval", minutes=15, id="sync_holding_prices")
    # Run news refresh every 30 minutes
    scheduler.add_job(refresh_market_news, "interval", minutes=30, id="refresh_market_news")
    
    scheduler.start()
    logger.info("background_scheduler_started")


def shutdown_scheduler() -> None:
    """Shutdown background scheduler."""
    if scheduler.running:
        scheduler.shutdown()
        logger.info("background_scheduler_stopped")
