"""Email CAS auto-import service.

Polls an IMAP mailbox for CAS PDF attachments from NSDL, CDSL, CAMS and
KFintech senders, downloads them and triggers the CAS PDF parser.

Configuration (via environment variables or passed directly):
    EMAIL_IMAP_HOST     — IMAP server hostname  (e.g. imap.gmail.com)
    EMAIL_IMAP_PORT     — IMAP SSL port          (default 993)
    EMAIL_ADDRESS       — Mailbox email address
    EMAIL_PASSWORD      — App password / OAuth token
    EMAIL_CAS_FOLDER    — IMAP folder to scan    (default INBOX)
    EMAIL_PDF_PASSWORD  — Password used to decrypt CAS PDFs (optional)

Typical CAS sender domains:
    - nsdl.co.in          (NSDL Demat CAS)
    - cdslindia.com       (CDSL Demat CAS)
    - camsonline.com      (CAMS Mutual Fund CAS)
    - kfintech.com        (KFintech Mutual Fund CAS)
"""

from __future__ import annotations

import asyncio
import email
import imaplib
from email.header import decode_header
from typing import Any

import structlog

from app.config import get_settings
from app.infrastructure.importers.cas_pdf_parser import CASPDFParser

logger = structlog.get_logger(__name__)

# Sender domain whitelist — only process CAS emails from these origins
_TRUSTED_CAS_DOMAINS = frozenset(
    [
        "nsdl.co.in",
        "cdslindia.com",
        "camsonline.com",
        "kfintech.com",
        "karvymfs.com",
        "franklintempletonindia.com",
    ]
)

# Subject keywords that typically appear in CAS emails
_CAS_SUBJECT_KEYWORDS = [
    "consolidated account statement",
    "cas statement",
    "account statement",
    "portfolio statement",
    "mutual fund statement",
    "demat statement",
]


def _is_trusted_sender(from_addr: str) -> bool:
    """Return True if the sender is a trusted CAS source."""
    from_lower = from_addr.lower()
    return any(domain in from_lower for domain in _TRUSTED_CAS_DOMAINS)


def _has_cas_subject(subject: str) -> bool:
    """Return True if the subject looks like a CAS email."""
    subject_lower = subject.lower()
    return any(kw in subject_lower for kw in _CAS_SUBJECT_KEYWORDS)


def _decode_header_value(raw: str) -> str:
    """Decode RFC 2047-encoded email header to a plain string."""
    parts = decode_header(raw)
    decoded = []
    for part, charset in parts:
        if isinstance(part, bytes):
            decoded.append(part.decode(charset or "utf-8", errors="replace"))
        else:
            decoded.append(part)
    return "".join(decoded)


class EmailCASImporter:
    """Polls an IMAP mailbox for CAS PDFs and parses them.

    Usage::

        importer = EmailCASImporter(
            imap_host="imap.gmail.com",
            email_address="user@gmail.com",
            email_password="app-password",
        )
        results = await importer.scan_and_parse(since_date="01-Jan-2024")
        # results: list of dicts with keys: filename, sender, subject, holdings
    """

    def __init__(
        self,
        imap_host: str | None = None,
        imap_port: int = 993,
        email_address: str | None = None,
        email_password: str | None = None,
        folder: str = "INBOX",
        pdf_password: str | None = None,
    ) -> None:
        settings = get_settings()
        self._host = imap_host or getattr(settings, "EMAIL_IMAP_HOST", None)
        self._port = imap_port
        self._address = email_address or getattr(settings, "EMAIL_ADDRESS", None)
        self._password = email_password or getattr(settings, "EMAIL_PASSWORD", None)
        self._folder = folder
        self._pdf_password = pdf_password or getattr(
            settings, "EMAIL_PDF_PASSWORD", None
        )

    def _connect(self) -> imaplib.IMAP4_SSL:
        """Open an authenticated IMAP SSL connection."""
        if not self._host or not self._address or not self._password:
            raise ValueError(
                "IMAP credentials not configured. Set EMAIL_IMAP_HOST, "
                "EMAIL_ADDRESS and EMAIL_PASSWORD."
            )
        conn = imaplib.IMAP4_SSL(self._host, self._port)
        conn.login(self._address, self._password)
        return conn

    def _fetch_pdf_attachments(
        self, since_date: str = "01-Jan-2024"
    ) -> list[dict[str, Any]]:
        """Synchronous IMAP scan — returns list of PDF attachment dicts.

        Each dict has: filename, sender, subject, pdf_bytes, date.
        """
        conn = self._connect()
        try:
            conn.select(self._folder)

            # Search for emails with PDF attachments since given date
            # Also try broad subject search
            status, msg_ids = conn.search(
                None,
                f'(SINCE "{since_date}" BODY "PDF")',
            )
            if status != "OK" or not msg_ids[0]:
                return []

            results = []
            ids = msg_ids[0].split()
            # Limit to most recent 50 to avoid timeout
            for msg_id in ids[-50:]:
                try:
                    _, raw = conn.fetch(msg_id, "(RFC822)")
                    if not raw or not raw[0]:
                        continue

                    msg = email.message_from_bytes(raw[0][1])  # type: ignore[index]
                    from_addr = _decode_header_value(msg.get("From", ""))
                    subject = _decode_header_value(msg.get("Subject", ""))

                    # Apply trust filters
                    if not _is_trusted_sender(from_addr) and not _has_cas_subject(
                        subject
                    ):
                        continue

                    # Walk MIME parts for PDF attachments
                    for part in msg.walk():
                        content_type = part.get_content_type()
                        disposition = str(part.get("Content-Disposition", ""))
                        filename = part.get_filename()

                        is_pdf = content_type in (
                            "application/pdf",
                            "application/octet-stream",
                        ) or (filename and filename.lower().endswith(".pdf"))

                        if not is_pdf or "attachment" not in disposition.lower():
                            continue

                        pdf_bytes = part.get_payload(decode=True)
                        if not pdf_bytes:
                            continue

                        results.append(
                            {
                                "filename": filename or "attachment.pdf",
                                "sender": from_addr,
                                "subject": subject,
                                "pdf_bytes": pdf_bytes,
                                "date": msg.get("Date", ""),
                            }
                        )
                except Exception as e:
                    logger.warning("email_parse_error", msg_id=msg_id, error=str(e))

            return results
        finally:
            import contextlib
            with contextlib.suppress(Exception):
                conn.logout()

    async def scan_and_parse(
        self, since_date: str = "01-Jan-2024"
    ) -> list[dict[str, Any]]:
        """Scan mailbox for CAS PDFs and return parsed holdings per email.

        Returns::

            [
              {
                "filename": "CAS_January_2024.pdf",
                "sender": "cas@camsonline.com",
                "subject": "Your Consolidated Account Statement",
                "date": "Mon, 01 Jan 2024 ...",
                "holdings": [...],   # list of holding dicts from CASPDFParser
                "error": None,       # or error message string
              },
              ...
            ]
        """
        logger.info(
            "email_cas_scan_started",
            host=self._host,
            folder=self._folder,
            since=since_date,
        )

        # Run blocking IMAP I/O in a thread
        attachments = await asyncio.to_thread(
            self._fetch_pdf_attachments, since_date
        )

        logger.info("email_cas_attachments_found", count=len(attachments))

        output = []
        for att in attachments:
            try:
                parser = CASPDFParser(att["pdf_bytes"], password=self._pdf_password)
                holdings = parser.parse()
                output.append(
                    {
                        "filename": att["filename"],
                        "sender": att["sender"],
                        "subject": att["subject"],
                        "date": att["date"],
                        "holdings": holdings,
                        "error": None,
                    }
                )
                logger.info(
                    "email_cas_parsed",
                    filename=att["filename"],
                    holdings_count=len(holdings),
                )
            except Exception as e:
                logger.warning(
                    "email_cas_parse_failed",
                    filename=att["filename"],
                    error=str(e),
                )
                output.append(
                    {
                        "filename": att["filename"],
                        "sender": att["sender"],
                        "subject": att["subject"],
                        "date": att["date"],
                        "holdings": [],
                        "error": str(e),
                    }
                )

        return output


# Module-level singleton
_importer: EmailCASImporter | None = None


def get_email_cas_importer() -> EmailCASImporter:
    """Return (or create) the module-level EmailCASImporter singleton."""
    global _importer
    if _importer is None:
        _importer = EmailCASImporter()
    return _importer
