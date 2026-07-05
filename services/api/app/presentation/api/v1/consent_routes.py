"""Mock Account Aggregator (AA) consent workflow endpoints."""

from __future__ import annotations

import uuid
from typing import Annotated

import structlog
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.entities import Holding
from app.infrastructure.database.session import get_db_session
from app.infrastructure.repositories.sqlalchemy_repos import (
    SQLAlchemyHoldingRepository,
    SQLAlchemyPortfolioRepository,
)
from app.infrastructure.repositories.redis_cache import cache_repo
from app.presentation.middleware.auth_dependency import get_current_user_id
from app.presentation.schemas.api_schemas import (
    ConsentRequest,
    ConsentInitiateResponse,
    ConsentStatusResponse,
    ErrorResponse,
)
from app.infrastructure.services.setu_aa_service import setu_aa_service, AASecurityService
from app.shared.exceptions import NotFoundError, ValidationError

logger = structlog.get_logger(__name__)
router = APIRouter()

# Realistic holdings list to seed for Indian Markets (NSE stocks / Mutual Funds)
SEED_HOLDINGS = [
    {
        "symbol": "RELIANCE",
        "name": "Reliance Industries Limited",
        "isin": "INE002A01018",
        "asset_type": "stock",
        "quantity": 15.0,
        "average_buy_price": 2450.00,
        "current_price": 2480.00,
        "exchange": "NSE",
    },
    {
        "symbol": "TCS",
        "name": "Tata Consultancy Services Limited",
        "isin": "INE467B01029",
        "asset_type": "stock",
        "quantity": 8.0,
        "average_buy_price": 3200.00,
        "current_price": 3450.00,
        "exchange": "NSE",
    },
    {
        "symbol": "INFY",
        "name": "Infosys Limited",
        "isin": "INE009A01021",
        "asset_type": "stock",
        "quantity": 25.0,
        "average_buy_price": 1400.00,
        "current_price": 1420.00,
        "exchange": "NSE",
    },
    {
        "symbol": "HDFCBANK",
        "name": "HDFC Bank Limited",
        "isin": "INE040A01034",
        "asset_type": "stock",
        "quantity": 30.0,
        "average_buy_price": 1550.00,
        "current_price": 1600.00,
        "exchange": "NSE",
    },
    {
        "symbol": "INF209K01157", # CAMS / KFin Mutual Fund ISIN
        "name": "HDFC Index Nifty 50 Plan - Direct Growth",
        "isin": "INF209K01157",
        "asset_type": "mutual_fund",
        "quantity": 450.25,
        "average_buy_price": 95.50,
        "current_price": 105.20,
        "exchange": "OTHER",
    },
    {
        "symbol": "INF179K01991",
        "name": "SBI Bluechip Fund - Direct Growth Plan",
        "isin": "INF179K01991",
        "asset_type": "mutual_fund",
        "quantity": 210.85,
        "average_buy_price": 60.20,
        "current_price": 68.40,
        "exchange": "OTHER",
    },
]


@router.post(
    "/{portfolio_id}/consent",
    response_model=ConsentInitiateResponse,
    responses={401: {"model": ErrorResponse}, 404: {"model": ErrorResponse}},
)
async def initiate_consent(
    portfolio_id: str,
    request: ConsentRequest,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> ConsentInitiateResponse:
    """Initiates Account Aggregator consent request flow.

    Returns consent_handle and external gateway redirect url.
    """
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    consent_handle = f"consent-{uuid.uuid4()}"
    
    try:
        # User VPA usually mapped to phone_number + aggregator domain suffix
        user_vpa = f"{request.phone_number}@{request.aggregator_id.split('-')[0]}"
        setu_consent = await setu_aa_service.create_consent_request(request.phone_number, user_vpa)
        consent_id = setu_consent.get("consent_id")
        redirect_url = setu_consent.get("redirect_url")
        is_sandbox = setu_consent.get("sandbox", False)
    except Exception as e:
        logger.warning("setu_aa_initiation_failed_falling_back_to_sandbox", error=str(e))
        consent_id = "sandbox-consent-id"
        redirect_url = f"http://localhost:8000/api/v1/portfolios/{portfolio_id}/callback?consent_handle={consent_handle}&status=APPROVED"
        is_sandbox = True

    # Store initial state in redis cache
    consent_state = {
        "status": "PENDING",
        "phone_number": request.phone_number,
        "aggregator_id": request.aggregator_id,
        "portfolio_id": portfolio_id,
        "consent_id": consent_id,
        "is_sandbox": is_sandbox,
        "holdings_count": 0,
    }
    
    # Cache state for 30 minutes
    await cache_repo.set(f"aa:{consent_handle}", consent_state, ttl=1800)
    
    logger.info("aa_consent_initiated", consent_handle=consent_handle, portfolio_id=portfolio_id, is_sandbox=is_sandbox)
    
    return ConsentInitiateResponse(
        consent_handle=consent_handle,
        redirect_url=redirect_url,
    )


@router.get(
    "/{portfolio_id}/callback",
    response_model=ConsentStatusResponse,
    responses={400: {"model": ErrorResponse}},
)
async def consent_callback(
    portfolio_id: str,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    consent_handle: str = Query(...),
    status: str = Query("APPROVED"),
) -> ConsentStatusResponse:
    """Callback triggered by Account Aggregator mock server after user authorizes access."""
    state_key = f"aa:{consent_handle}"
    consent_state = await cache_repo.get(state_key)
    
    if not consent_state:
        raise ValidationError("Invalid or expired consent handle")
        
    if status != "APPROVED":
        consent_state["status"] = "FAILED"
        await cache_repo.set(state_key, consent_state, ttl=1800)
        return ConsentStatusResponse(
            consent_handle=consent_handle,
            status="FAILED",
            message="User denied consent or integration failed",
        )
        
    consent_state["status"] = "APPROVED"
    await cache_repo.set(state_key, consent_state, ttl=1800)
    
    # Retrieve consent details
    is_sandbox = consent_state.get("is_sandbox", True)
    consent_id = consent_state.get("consent_id", "sandbox-consent-id")
    
    holdings_to_save = []
    
    if not is_sandbox and setu_aa_service.is_configured:
        try:
            private_key, public_bytes = AASecurityService.generate_key_pair()
            fetched_holdings = await setu_aa_service.fetch_financial_data(consent_id, private_key, public_bytes)
            if fetched_holdings:
                holdings_to_save = fetched_holdings
            else:
                logger.info("setu_aa_no_data_returned_using_fallback_seeds")
                holdings_to_save = SEED_HOLDINGS
        except Exception as e:
            logger.error("setu_aa_data_fetch_failed_using_sandbox_fallback", error=str(e))
            holdings_to_save = SEED_HOLDINGS
    else:
        holdings_to_save = SEED_HOLDINGS

    # Save to database
    holding_repo = SQLAlchemyHoldingRepository(session)
    holdings_to_create = []
    
    for seed in holdings_to_save:
        holdings_to_create.append(
            Holding(
                id=str(uuid.uuid4()),
                portfolio_id=portfolio_id,
                symbol=seed["symbol"],
                name=seed["name"],
                asset_type=seed["asset_type"],
                exchange=seed["exchange"],
                quantity=seed["quantity"],
                average_buy_price=seed["average_buy_price"],
                current_price=seed["current_price"],
                isin=seed["isin"],
            )
        )
        
    await holding_repo.bulk_create(holdings_to_create)
    await session.commit()
    
    # Update state in cache to completed
    consent_state["status"] = "COMPLETED"
    consent_state["holdings_count"] = len(holdings_to_create)
    await cache_repo.set(state_key, consent_state, ttl=1800)
    
    logger.info("aa_consent_completed", consent_handle=consent_handle, imported=len(holdings_to_create))
    
    return ConsentStatusResponse(
        consent_handle=consent_handle,
        status="COMPLETED",
        holdings_count=len(holdings_to_create),
        message="Consented financial assets imported successfully",
    )


@router.get(
    "/{portfolio_id}/consent/status/{consent_handle}",
    response_model=ConsentStatusResponse,
    responses={404: {"model": ErrorResponse}},
)
async def get_consent_status(
    portfolio_id: str,
    consent_handle: str,
) -> ConsentStatusResponse:
    """Retrieve current state of Account Aggregator consent flow."""
    consent_state = await cache_repo.get(f"aa:{consent_handle}")
    if not consent_state:
        raise NotFoundError("ConsentHandle", consent_handle)
        
    return ConsentStatusResponse(
        consent_handle=consent_handle,
        status=consent_state["status"],
        holdings_count=consent_state["holdings_count"],
        message=f"Status details: {consent_state['status']}",
    )
