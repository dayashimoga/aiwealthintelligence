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
from app.infrastructure.analytics.portfolio_analytics_engine import PortfolioAnalyticsEngine
from app.infrastructure.database.session import get_db_session
from app.infrastructure.repositories.sqlalchemy_repos import (
    SQLAlchemyHoldingRepository,
    SQLAlchemyPortfolioRepository,
    SQLAlchemyTransactionRepository,
)
from app.presentation.middleware.auth_dependency import get_current_user_id
from app.presentation.schemas.api_schemas import (
    CreateHoldingRequest,
    CreatePortfolioRequest,
    HoldingListResponse,
    HoldingResponse,
    ImportResponse,
    PortfolioAnalyticsResponse,
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


from fastapi import Form

from app.infrastructure.importers.broker_report_parser import BrokerReportParser
from app.infrastructure.importers.cas_pdf_parser import CASPDFParser


@router.post("/{portfolio_id}/import/cas-pdf", response_model=ImportResponse)
async def import_cas_pdf(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
    file: UploadFile = File(...),
    password: str | None = Form(None),
) -> ImportResponse:
    """Import holdings from an NSDL/CDSL CAS or CAMS Mutual Fund CAS PDF statement.

    Supports optional password decryption.
    """
    # Verify portfolio ownership
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    if not file.filename or not file.filename.endswith(".pdf"):
        raise ValidationError("File must be a PDF file")

    content = await file.read()
    try:
        parser = CASPDFParser(content, password=password)
        holdings_data = parser.parse()
    except Exception as e:
        raise ValidationError(f"Failed parsing PDF: {e}") from e

    holdings_to_create: list[Holding] = []
    for h in holdings_data:
        holdings_to_create.append(
            Holding(
                id=str(uuid.uuid4()),
                portfolio_id=portfolio_id,
                symbol=h["symbol"],
                name=h["name"],
                asset_type=h["asset_type"],
                exchange=h["exchange"],
                quantity=h["quantity"],
                average_buy_price=h["average_buy_price"],
                current_price=h["current_price"],
                isin=h["isin"],
            )
        )

    imported_count = 0
    if holdings_to_create:
        holding_repo = SQLAlchemyHoldingRepository(session)
        await holding_repo.bulk_create(holdings_to_create)
        await session.commit()
        imported_count = len(holdings_to_create)

    logger.info("cas_pdf_imported", portfolio_id=portfolio_id, count=imported_count)
    return ImportResponse(
        imported=imported_count,
        skipped=0,
        errors=[],
    )


@router.post("/{portfolio_id}/import/broker", response_model=ImportResponse)
async def import_broker_report(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
    file: UploadFile = File(...),
) -> ImportResponse:
    """Import holdings from a Broker report (Excel or CSV).

    Supports Zerodha Kite, Groww, Upstox, etc.
    """
    # Verify portfolio ownership
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    filename = file.filename or ""
    if not (filename.endswith(".csv") or filename.endswith(".xlsx") or filename.endswith(".xls")):
        raise ValidationError("File must be a CSV or Excel file")

    content = await file.read()
    try:
        parser = BrokerReportParser(content, filename)
        holdings_data = parser.parse()
    except Exception as e:
        raise ValidationError(f"Failed parsing broker report: {e}") from e

    holdings_to_create: list[Holding] = []
    for h in holdings_data:
        holdings_to_create.append(
            Holding(
                id=str(uuid.uuid4()),
                portfolio_id=portfolio_id,
                symbol=h["symbol"],
                name=h["name"],
                asset_type=h["asset_type"],
                exchange=h["exchange"],
                quantity=h["quantity"],
                average_buy_price=h["average_buy_price"],
                current_price=h["current_price"],
                isin=h["isin"],
            )
        )

    imported_count = 0
    if holdings_to_create:
        holding_repo = SQLAlchemyHoldingRepository(session)
        await holding_repo.bulk_create(holdings_to_create)
        await session.commit()
        imported_count = len(holdings_to_create)

    logger.info("broker_report_imported", portfolio_id=portfolio_id, count=imported_count)
    return ImportResponse(
        imported=imported_count,
        skipped=0,
        errors=[],
    )


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


@router.get("/{portfolio_id}/analytics", response_model=PortfolioAnalyticsResponse)
async def get_portfolio_analytics(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> PortfolioAnalyticsResponse:
    """Get comprehensive portfolio analytics including allocations and performance metrics."""
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    holding_repo = SQLAlchemyHoldingRepository(session)
    holdings = await holding_repo.list_by_portfolio(portfolio_id)

    tx_repo = SQLAlchemyTransactionRepository(session)
    transactions = await tx_repo.list_by_portfolio(portfolio_id)

    engine = PortfolioAnalyticsEngine()
    metrics = engine.calculate_metrics(holdings, transactions)

    # Calculate real dividend income from transactions
    dividend_income = 0.0
    for tx in transactions:
        tx_type = (
            tx.transaction_type.value
            if hasattr(tx.transaction_type, "value")
            else str(tx.transaction_type)
        )
        if tx_type == "dividend":
            dividend_income += float(tx.quantity) * float(tx.price)

    return PortfolioAnalyticsResponse(
        portfolio_id=portfolio_id,
        total_invested=metrics["total_invested"],
        total_current_value=metrics["total_current_value"],
        total_gain_loss=metrics["total_gain_loss"],
        total_gain_loss_pct=metrics["total_gain_loss_pct"],
        holding_count=len(holdings),
        xirr=metrics["xirr"],
        cagr=metrics.get("cagr"),
        max_drawdown=metrics.get("max_drawdown"),
        sharpe_ratio=metrics.get("sharpe_ratio"),
        diversification_score=metrics["diversification_score"],
        risk_score=metrics["risk_score"],
        ai_health_score=metrics["ai_health_score"],
        dividend_income=round(dividend_income, 2),
        asset_allocation=metrics["asset_allocation"],
        sector_allocation=metrics["sector_allocation"],
        country_allocation=metrics["country_allocation"],
        tax_estimate=metrics.get("tax_estimate"),
        calculated_at=metrics["calculated_at"],
    )


# ============================================================
# Helpers
# ============================================================


def _portfolio_to_response(portfolio: Portfolio) -> PortfolioResponse:
    """Convert Portfolio entity to PortfolioResponse."""
    return PortfolioResponse(
        id=portfolio.id,
        name=portfolio.name,
        description=portfolio.description,
        currency=portfolio.currency.value
        if hasattr(portfolio.currency, "value")
        else portfolio.currency,
        is_default=portfolio.is_default,
        import_source=portfolio.import_source.value
        if hasattr(portfolio.import_source, "value")
        else portfolio.import_source,
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
        asset_type=holding.asset_type
        if isinstance(holding.asset_type, str)
        else holding.asset_type.value,
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
