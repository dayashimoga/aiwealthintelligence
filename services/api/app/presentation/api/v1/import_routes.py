"""Import API routes for portfolio holdings.

Provides endpoints for:
  POST /portfolios/{id}/import/cas-pdf       — NSDL/CDSL CAS PDF upload (existing)
  POST /portfolios/{id}/import/cams-kfin     — CAMS/KFin MF CAS PDF upload
  POST /portfolios/{id}/import/email-scan    — Trigger email mailbox CAS scan
  GET  /import/email-config                  — Get/validate email import configuration
  POST /import/email-config/test             — Test IMAP connection
"""

from __future__ import annotations

import uuid
from decimal import Decimal
from typing import Annotated, Any

import structlog
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.domain.entities import Holding
from app.infrastructure.database.session import get_db_session
from app.infrastructure.importers.cams_kfin_parser import CAMSKFinParser
from app.infrastructure.importers.email_cas_importer import EmailCASImporter
from app.infrastructure.repositories.sqlalchemy_repos import (
    SQLAlchemyHoldingRepository,
    SQLAlchemyPortfolioRepository,
)
from app.presentation.middleware.auth_dependency import get_current_user_id
from app.shared.exceptions import NotFoundError, ValidationError

logger = structlog.get_logger(__name__)
router = APIRouter()


# ─── Response schemas ──────────────────────────────────────────────────────────


class ImportResponse(BaseModel):
    imported: int
    skipped: int
    errors: list[str]
    message: str = ""


class CAMSKFinImportResponse(BaseModel):
    format: str  # "cams" | "kfin" | "unknown"
    investor_name: str | None
    pan: str | None
    imported: int
    skipped: int
    amc_count: int
    pages_processed: int
    errors: list[str]


class EmailScanResponse(BaseModel):
    emails_scanned: int
    pdfs_found: int
    imported: int
    skipped: int
    errors: list[str]
    sources: list[dict[str, Any]]


class EmailConfigStatus(BaseModel):
    configured: bool
    host: str
    email: str
    folder: str
    has_pdf_password: bool


# ─── CAMS / KFin PDF import ────────────────────────────────────────────────────


@router.post(
    "/portfolios/{portfolio_id}/import/cams-kfin",
    response_model=CAMSKFinImportResponse,
    summary="Import CAMS or KFintech Mutual Fund CAS PDF",
)
async def import_cams_kfin_pdf(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
    file: UploadFile = File(..., description="CAMS or KFintech CAS PDF statement"),
    password: str | None = Form(None, description="PDF password (usually PAN in UPPERCASE)"),
) -> CAMSKFinImportResponse:
    """Upload and import a CAMS or KFintech Mutual Fund CAS PDF statement.

    The endpoint auto-detects whether the file is a CAMS or KFin statement
    and parses it accordingly, creating holdings in the target portfolio.

    Password:
        Most CAMS/KFin CAS PDFs are password-protected with the investor's
        PAN in UPPERCASE (e.g. ABCDE1234F).
    """
    # Verify portfolio ownership
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise ValidationError("File must be a PDF (.pdf)")

    content = await file.read()
    if len(content) < 100:
        raise ValidationError("File appears to be empty or corrupt")

    # Parse CAMS/KFin PDF
    try:
        parser = CAMSKFinParser(content, password=password or None)
        result = parser.parse()
    except Exception as e:
        raise ValidationError(f"Failed to parse CAMS/KFin PDF: {e}") from e

    holdings_data: list[dict[str, Any]] = result["holdings"]
    errors: list[str] = []

    # Upsert holdings into the portfolio
    imported_count = 0
    skipped_count = 0

    if holdings_data:
        holding_repo = SQLAlchemyHoldingRepository(session)
        holdings_to_create: list[Holding] = []

        for h in holdings_data:
            try:
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
                        isin=h.get("isin", ""),
                        sector="",
                        industry="",
                        country="India",
                    )
                )
            except Exception as e:
                errors.append(f"Skipped {h.get('isin', '?')}: {e}")
                skipped_count += 1

        if holdings_to_create:
            await holding_repo.bulk_create(holdings_to_create)
            await session.commit()
            imported_count = len(holdings_to_create)

    logger.info(
        "cams_kfin_import_complete",
        portfolio_id=portfolio_id,
        format=result["format"],
        imported=imported_count,
    )

    return CAMSKFinImportResponse(
        format=result["format"],
        investor_name=result.get("investor_name"),
        pan=result.get("pan"),
        imported=imported_count,
        skipped=skipped_count,
        amc_count=result["amc_count"],
        pages_processed=result["pages_processed"],
        errors=errors,
    )


# ─── Email CAS scan ────────────────────────────────────────────────────────────


@router.get(
    "/import/email-config",
    response_model=EmailConfigStatus,
    summary="Get email CAS import configuration status",
)
async def get_email_config(
    user_id: Annotated[str, Depends(get_current_user_id)],
) -> EmailConfigStatus:
    """Return the current email import configuration status.

    This shows whether the IMAP connection is configured (credentials
    are set via environment variables, never returned in the response).
    """
    settings = get_settings()
    return EmailConfigStatus(
        configured=bool(settings.EMAIL_IMAP_HOST and settings.EMAIL_ADDRESS),
        host=settings.EMAIL_IMAP_HOST or "(not set)",
        email=settings.EMAIL_ADDRESS or "(not set)",
        folder=settings.EMAIL_CAS_FOLDER,
        has_pdf_password=bool(settings.EMAIL_PDF_PASSWORD),
    )


@router.post(
    "/import/email-config/test",
    summary="Test IMAP connection for email CAS import",
)
async def test_email_connection(
    user_id: Annotated[str, Depends(get_current_user_id)],
) -> dict[str, Any]:
    """Test the configured IMAP connection and return status.

    Attempts to connect to the IMAP server with configured credentials.
    Does NOT download any emails — only tests connectivity.
    """
    settings = get_settings()
    if not settings.EMAIL_IMAP_HOST or not settings.EMAIL_ADDRESS:
        raise HTTPException(
            status_code=400,
            detail="Email import not configured. Set EMAIL_IMAP_HOST and EMAIL_ADDRESS.",
        )

    import asyncio
    import imaplib

    try:

        def _test_connect() -> str:
            conn = imaplib.IMAP4_SSL(settings.EMAIL_IMAP_HOST, settings.EMAIL_IMAP_PORT)
            conn.login(settings.EMAIL_ADDRESS, settings.EMAIL_PASSWORD)
            status, msgs = conn.select(settings.EMAIL_CAS_FOLDER)
            count = int(msgs[0]) if status == "OK" and msgs[0] else 0
            conn.logout()
            return count

        msg_count = await asyncio.to_thread(_test_connect)
        return {
            "status": "ok",
            "host": settings.EMAIL_IMAP_HOST,
            "folder": settings.EMAIL_CAS_FOLDER,
            "messages_in_folder": msg_count,
        }
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"IMAP connection failed: {e}",
        ) from e


@router.post(
    "/portfolios/{portfolio_id}/import/email-scan",
    response_model=EmailScanResponse,
    summary="Scan email mailbox for CAS PDFs and import holdings",
)
async def import_from_email(
    portfolio_id: str,
    user_id: Annotated[str, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
    since_date: str = Form(
        default="01-Jan-2024",
        description='Scan emails since this date (format: DD-Mon-YYYY e.g. "01-Jan-2024")',
    ),
    pdf_password: str | None = Form(
        None,
        description="PDF password for encrypted CAS files (usually PAN in uppercase)",
    ),
) -> EmailScanResponse:
    """Scan the configured email mailbox for CAS PDF attachments and import.

    Searches the IMAP mailbox (configured via environment variables) for
    emails from NSDL, CDSL, CAMS, KFin senders containing PDF attachments,
    parses each PDF and imports the holdings into the portfolio.

    Configuration required:
        EMAIL_IMAP_HOST, EMAIL_ADDRESS, EMAIL_PASSWORD environment variables.

    Returns a summary of emails scanned, PDFs found, and holdings imported.
    """
    settings = get_settings()
    if not settings.EMAIL_IMAP_HOST or not settings.EMAIL_ADDRESS:
        raise HTTPException(
            status_code=400,
            detail=(
                "Email import not configured. "
                "Set EMAIL_IMAP_HOST, EMAIL_ADDRESS, and EMAIL_PASSWORD."
            ),
        )

    # Verify portfolio
    portfolio_repo = SQLAlchemyPortfolioRepository(session)
    portfolio = await portfolio_repo.get_by_id(portfolio_id, user_id)
    if portfolio is None:
        raise NotFoundError("Portfolio", portfolio_id)

    importer = EmailCASImporter(
        imap_host=settings.EMAIL_IMAP_HOST,
        imap_port=settings.EMAIL_IMAP_PORT,
        email_address=settings.EMAIL_ADDRESS,
        email_password=settings.EMAIL_PASSWORD,
        folder=settings.EMAIL_CAS_FOLDER,
        pdf_password=pdf_password or settings.EMAIL_PDF_PASSWORD or None,
    )

    try:
        email_results = await importer.scan_and_parse(since_date=since_date)
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Email scan failed: {e}",
        ) from e

    # Import all discovered holdings
    holding_repo = SQLAlchemyHoldingRepository(session)
    total_imported = 0
    total_skipped = 0
    all_errors: list[str] = []
    sources: list[dict[str, Any]] = []

    for email_result in email_results:
        if email_result.get("error"):
            all_errors.append(f"{email_result['filename']}: {email_result['error']}")
            sources.append(
                {
                    "filename": email_result["filename"],
                    "sender": email_result["sender"],
                    "imported": 0,
                    "error": email_result["error"],
                }
            )
            continue

        holdings_data = email_result.get("holdings", [])
        email_imported = 0

        holdings_to_create: list[Holding] = []
        for h in holdings_data:
            try:
                holdings_to_create.append(
                    Holding(
                        id=str(uuid.uuid4()),
                        portfolio_id=portfolio_id,
                        symbol=h["symbol"],
                        name=h["name"],
                        asset_type=h["asset_type"],
                        exchange=h["exchange"],
                        quantity=h["quantity"],
                        average_buy_price=h.get("average_buy_price", Decimal("0")),
                        current_price=h.get("current_price", Decimal("0")),
                        isin=h.get("isin", ""),
                        sector="",
                        industry="",
                        country="India",
                    )
                )
            except Exception as e:
                total_skipped += 1
                all_errors.append(f"{h.get('isin', '?')}: {e}")

        if holdings_to_create:
            await holding_repo.bulk_create(holdings_to_create)
            email_imported = len(holdings_to_create)
            total_imported += email_imported

        sources.append(
            {
                "filename": email_result["filename"],
                "sender": email_result["sender"],
                "subject": email_result.get("subject", ""),
                "date": email_result.get("date", ""),
                "imported": email_imported,
                "error": None,
            }
        )

    if total_imported > 0:
        await session.commit()

    logger.info(
        "email_cas_import_complete",
        portfolio_id=portfolio_id,
        emails=len(email_results),
        imported=total_imported,
    )

    return EmailScanResponse(
        emails_scanned=len(email_results),
        pdfs_found=len([e for e in email_results if not e.get("error")]),
        imported=total_imported,
        skipped=total_skipped,
        errors=all_errors,
        sources=sources,
    )
