"""Portfolio management routes for CRUD operations, import, and analytics."""

from __future__ import annotations

import csv
import io
import uuid
from decimal import Decimal, InvalidOperation
from typing import Annotated

import structlog
from fastapi import APIRouter, Depends, File, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.entities import Holding, Portfolio
from app.infrastructure.database.session import get_db_session
from app.infrastructure.repositories.sqlalchemy_repos import (
    SQLAlchemyHoldingRepository,
    SQLAlchemyPortfolioRepository,
)
from app.presentation.middleware.auth_dependency import get_current_user_id
from app.presentation.schemas.api_schemas import (
    CreateHoldingRequest,
    CreatePortfolioRequest,
    HoldingListResponse,
    HoldingResponse,
    ImportResponse,
    PortfolioListResponse,
    PortfolioResponse,
    UpdateHoldingRequest,
    UpdatePortfolioRequest,
)
from app.shared.exceptions import NotFoundError, ValidationError

logger = structlog.get_logger(__name__)
router = APIRouter()


# ============================================================
# Portfolio CRUD
# ============================================================


@router.post("", response_model=PortfolioResponse, status_code=201)
async def create_portfolio(
    request: CreatePortfolioRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> PortfolioResponse:
    """Create a new portfolio for the authenticated user."""
    repo = SQLAlchemyPortfolioRepository(session)

    portfolio = Portfolio(
        user_id=user_id,
        name=request.name,
        description=request.description,
        currency=request.currency,
    )
    created = await repo.create(portfolio)
    await session.commit()

    logger.info("portfolio_created", portfolio_id=created.id, user_id=user_id)

    return _portfolio_to_response(created)


@router.get("", response_model=PortfolioListResponse)
async def list_portfolios(
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
    skip: int = 0,
    limit: int = 50,
) -> PortfolioListResponse:
    """List all portfolios for the authenticated user."""
    repo = SQLAlchemyPortfolioRepository(session)
    portfolios = await repo.list_by_user(user_id, skip=skip, limit=limit)

    return PortfolioListResponse(
        portfolios=[_portfolio_to_response(p) for p in portfolios],
        total=len(portfolios),
    )


@router.get("/{portfolio_id}", response_model=PortfolioResponse)
async def get_portfolio(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> PortfolioResponse:
    """Get a specific portfolio by ID."""
    repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await repo.get_by_id(portfolio_id, user_id)

    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    return _portfolio_to_response(portfolio)


@router.patch("/{portfolio_id}", response_model=PortfolioResponse)
async def update_portfolio(
    portfolio_id: str,
    request: UpdatePortfolioRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> PortfolioResponse:
    """Update portfolio metadata."""
    repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await repo.get_by_id(portfolio_id, user_id)

    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    if request.name is not None:
        portfolio.name = request.name
    if request.description is not None:
        portfolio.description = request.description

    updated = await repo.update(portfolio)
    await session.commit()

    return _portfolio_to_response(updated)


@router.delete("/{portfolio_id}", status_code=204)
async def delete_portfolio(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> None:
    """Delete a portfolio and all its holdings."""
    repo = SQLAlchemyPortfolioRepository(session)
    deleted = await repo.delete(portfolio_id, user_id)

    if not deleted:
        raise NotFoundError("Portfolio", portfolio_id)

    await session.commit()
    logger.info("portfolio_deleted", portfolio_id=portfolio_id, user_id=user_id)


# ============================================================
# Holdings CRUD
# ============================================================


@router.post("/{portfolio_id}/holdings", response_model=HoldingResponse, status_code=201)
async def create_holding(
    portfolio_id: str,
    request: CreateHoldingRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> HoldingResponse:
    """Add a new holding to a portfolio."""
    # Verify portfolio ownership
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    holding_repo = SQLAlchemyHoldingRepository(session)
    holding = Holding(
        portfolio_id=portfolio_id,
        symbol=request.symbol.upper(),
        name=request.name,
        asset_type=request.asset_type,
        exchange=request.exchange,
        quantity=request.quantity,
        average_buy_price=request.average_buy_price,
        current_price=request.current_price,
        sector=request.sector,
        industry=request.industry,
        country=request.country,
        isin=request.isin,
        notes=request.notes,
        buy_date=request.buy_date,
    )
    created = await holding_repo.create(holding)
    await session.commit()

    logger.info(
        "holding_created",
        holding_id=created.id,
        symbol=created.symbol,
        portfolio_id=portfolio_id,
    )

    return _holding_to_response(created)


@router.get("/{portfolio_id}/holdings", response_model=HoldingListResponse)
async def list_holdings(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
    skip: int = 0,
    limit: int = 100,
) -> HoldingListResponse:
    """List all holdings in a portfolio."""
    # Verify portfolio ownership
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    holding_repo = SQLAlchemyHoldingRepository(session)
    holdings = await holding_repo.list_by_portfolio(portfolio_id, skip=skip, limit=limit)

    return HoldingListResponse(
        holdings=[_holding_to_response(h) for h in holdings],
        total=len(holdings),
    )


@router.patch("/{portfolio_id}/holdings/{holding_id}", response_model=HoldingResponse)
async def update_holding(
    portfolio_id: str,
    holding_id: str,
    request: UpdateHoldingRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> HoldingResponse:
    """Update a holding's data."""
    # Verify portfolio ownership
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    holding_repo = SQLAlchemyHoldingRepository(session)
    holding = await holding_repo.get_by_id(holding_id, portfolio_id)
    if holding is None:
        raise NotFoundError("Holding", holding_id)

    if request.quantity is not None:
        holding.quantity = request.quantity
    if request.average_buy_price is not None:
        holding.average_buy_price = request.average_buy_price
    if request.current_price is not None:
        holding.current_price = request.current_price
    if request.sector is not None:
        holding.sector = request.sector
    if request.industry is not None:
        holding.industry = request.industry
    if request.notes is not None:
        holding.notes = request.notes

    updated = await holding_repo.update(holding)
    await session.commit()

    return _holding_to_response(updated)


@router.delete("/{portfolio_id}/holdings/{holding_id}", status_code=204)
async def delete_holding(
    portfolio_id: str,
    holding_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> None:
    """Delete a holding from a portfolio."""
    # Verify portfolio ownership
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    holding_repo = SQLAlchemyHoldingRepository(session)
    deleted = await holding_repo.delete(holding_id, portfolio_id)
    if not deleted:
        raise NotFoundError("Holding", holding_id)

    await session.commit()


# ============================================================
# CSV Import
# ============================================================


@router.post("/{portfolio_id}/import", response_model=ImportResponse)
async def import_csv(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
    file: UploadFile = File(...),
) -> ImportResponse:
    """Import holdings from a CSV file.

    Expected CSV columns: symbol, name, asset_type, quantity, buy_price, current_price,
    sector, exchange, country, isin, buy_date
    """
    # Verify portfolio ownership
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    if not file.filename or not file.filename.endswith(".csv"):
        raise ValidationError("File must be a CSV file")

    content = await file.read()
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError:
        text = content.decode("latin-1")

    reader = csv.DictReader(io.StringIO(text))

    holdings_to_create: list[Holding] = []
    errors: list[str] = []
    skipped = 0

    for row_num, row in enumerate(reader, start=2):
        try:
            symbol = row.get("symbol", "").strip().upper()
            name = row.get("name", "").strip()
            if not symbol or not name:
                errors.append(f"Row {row_num}: Missing symbol or name")
                skipped += 1
                continue

            quantity_str = row.get("quantity", "0").strip()
            buy_price_str = row.get("buy_price", row.get("average_buy_price", "0")).strip()
            current_price_str = row.get("current_price", "0").strip()

            try:
                quantity = Decimal(quantity_str) if quantity_str else Decimal("0")
                buy_price = Decimal(buy_price_str) if buy_price_str else Decimal("0")
                current_price = Decimal(current_price_str) if current_price_str else Decimal("0")
            except InvalidOperation:
                errors.append(f"Row {row_num}: Invalid numeric values")
                skipped += 1
                continue

            if quantity <= 0:
                errors.append(f"Row {row_num}: Quantity must be positive")
                skipped += 1
                continue

            holding = Holding(
                id=str(uuid.uuid4()),
                portfolio_id=portfolio_id,
                symbol=symbol,
                name=name,
                asset_type=row.get("asset_type", "stock").strip().lower(),
                exchange=row.get("exchange", "NSE").strip().upper(),
                quantity=quantity,
                average_buy_price=buy_price,
                current_price=current_price,
                sector=row.get("sector", "").strip(),
                industry=row.get("industry", "").strip(),
                country=row.get("country", "India").strip(),
                isin=row.get("isin", "").strip(),
            )
            holdings_to_create.append(holding)

        except Exception as e:
            errors.append(f"Row {row_num}: {e!s}")
            skipped += 1

    imported_count = 0
    if holdings_to_create:
        holding_repo = SQLAlchemyHoldingRepository(session)
        await holding_repo.bulk_create(holdings_to_create)
        await session.commit()
        imported_count = len(holdings_to_create)

    logger.info(
        "csv_imported",
        portfolio_id=portfolio_id,
        imported=imported_count,
        skipped=skipped,
        errors=len(errors),
    )

    return ImportResponse(
        imported=imported_count,
        skipped=skipped,
        errors=errors,
    )


# ============================================================
# Analytics
# ============================================================


@router.get("/{portfolio_id}/analytics")
async def get_portfolio_analytics(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> dict:
    """Get comprehensive portfolio analytics including allocations and performance metrics."""
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    holding_repo = SQLAlchemyHoldingRepository(session)
    holdings = await holding_repo.list_by_portfolio(portfolio_id)

    # Calculate analytics
    total_invested = sum(float(h.invested_value) for h in holdings)
    total_current = sum(float(h.current_value) for h in holdings)
    total_gain_loss = total_current - total_invested
    total_gain_loss_pct = (total_gain_loss / total_invested * 100) if total_invested > 0 else 0

    # Asset allocation
    asset_allocation: dict[str, float] = {}
    sector_allocation: dict[str, float] = {}
    country_allocation: dict[str, float] = {}

    for h in holdings:
        current_val = float(h.current_value)
        asset_type = h.asset_type if isinstance(h.asset_type, str) else h.asset_type.value
        asset_allocation[asset_type] = asset_allocation.get(asset_type, 0) + current_val

        if h.sector:
            sector_allocation[h.sector] = sector_allocation.get(h.sector, 0) + current_val

        country_allocation[h.country] = country_allocation.get(h.country, 0) + current_val

    # Convert to percentages
    if total_current > 0:
        asset_allocation = {k: round(v / total_current * 100, 2) for k, v in asset_allocation.items()}
        sector_allocation = {k: round(v / total_current * 100, 2) for k, v in sector_allocation.items()}
        country_allocation = {k: round(v / total_current * 100, 2) for k, v in country_allocation.items()}

    # Diversification score (0-100, based on number of holdings and allocation spread)
    n_holdings = len(holdings)
    if n_holdings == 0:
        diversification_score = 0.0
    else:
        # Simple Herfindahl-Hirschman Index based diversification
        weights = [float(h.current_value) / total_current for h in holdings] if total_current > 0 else []
        hhi = sum(w ** 2 for w in weights) if weights else 1.0
        diversification_score = round((1 - hhi) * 100, 1)

    # Risk score (simplified - based on concentration)
    max_weight = max(weights, default=0) if total_current > 0 else 0
    risk_score = round(max_weight * 100, 1)

    return {
        "portfolio_id": portfolio_id,
        "total_invested": round(total_invested, 2),
        "total_current_value": round(total_current, 2),
        "total_gain_loss": round(total_gain_loss, 2),
        "total_gain_loss_pct": round(total_gain_loss_pct, 2),
        "holding_count": n_holdings,
        "diversification_score": diversification_score,
        "risk_score": risk_score,
        "ai_health_score": round(diversification_score * 0.7 + (100 - risk_score) * 0.3, 1),
        "asset_allocation": asset_allocation,
        "sector_allocation": sector_allocation,
        "country_allocation": country_allocation,
    }


# ============================================================
# Helpers
# ============================================================


def _portfolio_to_response(portfolio: Portfolio) -> PortfolioResponse:
    """Convert Portfolio entity to PortfolioResponse."""
    return PortfolioResponse(
        id=portfolio.id,
        name=portfolio.name,
        description=portfolio.description,
        currency=portfolio.currency.value if hasattr(portfolio.currency, "value") else portfolio.currency,
        is_default=portfolio.is_default,
        import_source=portfolio.import_source.value if hasattr(portfolio.import_source, "value") else portfolio.import_source,
        holding_count=portfolio.holding_count,
        total_invested=float(portfolio.total_invested),
        total_current_value=float(portfolio.total_current_value),
        total_gain_loss=float(portfolio.total_gain_loss),
        total_gain_loss_pct=float(portfolio.total_gain_loss_percentage),
        created_at=portfolio.created_at,
        updated_at=portfolio.updated_at,
    )


def _holding_to_response(holding: Holding) -> HoldingResponse:
    """Convert Holding entity to HoldingResponse."""
    return HoldingResponse(
        id=holding.id,
        portfolio_id=holding.portfolio_id,
        symbol=holding.symbol,
        name=holding.name,
        asset_type=holding.asset_type if isinstance(holding.asset_type, str) else holding.asset_type.value,
        exchange=holding.exchange if isinstance(holding.exchange, str) else holding.exchange.value,
        currency=holding.currency if isinstance(holding.currency, str) else holding.currency.value,
        quantity=float(holding.quantity),
        average_buy_price=float(holding.average_buy_price),
        current_price=float(holding.current_price),
        invested_value=float(holding.invested_value),
        current_value=float(holding.current_value),
        gain_loss=float(holding.gain_loss),
        gain_loss_pct=float(holding.gain_loss_percentage),
        sector=holding.sector,
        industry=holding.industry,
        country=holding.country,
        isin=holding.isin,
        notes=holding.notes,
        buy_date=holding.buy_date,
        created_at=holding.created_at,
        updated_at=holding.updated_at,
    )
