"""CAMS & KFintech Mutual Fund CAS PDF parser and import service.

These statement formats differ slightly from NSDL/CDSL Demat CAS:
  - CAMS: Computer Age Management Services — largest MF registrar (60%+ AUM)
  - KFintech: Karvy-Financial Technologies — second largest MF registrar

Statement format characteristics:
  - Header section with investor name, PAN, email
  - One section per AMC (Asset Management Company)
  - Each scheme line: Scheme Name | Folio | Units | NAV | Value
  - ISINs appear inline or in separate column
  - Both use PDF text that can be extracted via pdfplumber

Detection heuristics:
  - CAMS PDFs contain "CAMSONLINE" or "COMPUTER AGE" in text
  - KFin PDFs contain "KFINTECH" or "KARVY" in text
"""

from __future__ import annotations

import contextlib
import io
import re
from decimal import Decimal, InvalidOperation
from typing import Any

import pdfplumber
import structlog

logger = structlog.get_logger(__name__)

# ─── Regex patterns ────────────────────────────────────────────────────────────

# Standard ISIN: 2 alpha + 9 alphanumeric + 1 digit
_ISIN_RE = re.compile(r"\b([A-Z]{2}[A-Z0-9]{9}\d)\b")

# Folio number patterns used by CAMS & KFin
_FOLIO_RE = re.compile(r"(?:Folio|folio)\s*(?:No\.?|Number)?\s*:?\s*(\S+)")

# NAV and units patterns (decimal numbers)
_DECIMAL_RE = re.compile(r"[-+]?\d{1,15}(?:\.\d{1,6})?")

# CAMS/KFin specific markers
_CAMS_MARKERS = ["camsonline", "computer age management", "cams"]
_KFIN_MARKERS = ["kfintech", "karvy financial", "kfin"]

# INF prefix = Indian mutual fund ISIN (registered with AMFI)
_MF_ISIN_PREFIX = "INF"


def _detect_format(full_text: str) -> str:
    """Detect whether the PDF is a CAMS or KFin statement."""
    text_lower = full_text.lower()
    if any(m in text_lower for m in _CAMS_MARKERS):
        return "cams"
    if any(m in text_lower for m in _KFIN_MARKERS):
        return "kfin"
    return "unknown"


def _extract_pan(text: str) -> str | None:
    """Extract PAN from statement text."""
    pan_match = re.search(r"\b([A-Z]{5}\d{4}[A-Z])\b", text)
    return pan_match.group(1) if pan_match else None


def _parse_scheme_line(line: str, current_amc: str) -> dict[str, Any] | None:
    """Parse a single scheme/holdings line from CAMS or KFin CAS.

    Expected line format variations:
      ISIN   Scheme Name   Folio   Units   NAV   Value
      Scheme Name   ISIN   Units   NAV   Value
    """
    isin_match = _ISIN_RE.search(line)
    if not isin_match:
        return None

    isin = isin_match.group(1)

    # Remove ISIN from line for further parsing
    clean = line.replace(isin, "").strip()

    # Extract all numeric values
    numbers = _DECIMAL_RE.findall(clean)

    quantity = Decimal("0")
    current_price = Decimal("0")

    if len(numbers) >= 3:
        # Pattern: ... Units  NAV  Value
        # units = numbers[-3], nav = numbers[-2], value = numbers[-1]
        try:
            quantity = Decimal(numbers[-3])
            current_price = Decimal(numbers[-2])  # NAV
        except InvalidOperation:
            pass
    elif len(numbers) == 2:
        try:
            quantity = Decimal(numbers[0])
            current_price = Decimal(numbers[1])
        except InvalidOperation:
            pass
    elif len(numbers) == 1:
        with contextlib.suppress(InvalidOperation):
            quantity = Decimal(numbers[0])

    # Build scheme name: remove numbers and ISIN from line words
    name_parts = []
    for word in clean.split():
        if (
            not _DECIMAL_RE.fullmatch(word)
            and not _ISIN_RE.match(word)
            and word not in ("-", "/", "|", ":")
        ):
            name_parts.append(word)

    name = " ".join(name_parts).strip()
    if not name:
        name = f"{current_amc} - {isin}"

    # All CAMS/KFin holdings are mutual funds (INF prefix confirms it)
    asset_type = "mutual_fund"
    if not isin.startswith(_MF_ISIN_PREFIX):
        asset_type = "stock"

    return {
        "symbol": isin,
        "name": name or f"Unknown ({isin})",
        "isin": isin,
        "asset_type": asset_type,
        "quantity": quantity,
        "average_buy_price": Decimal("0"),
        "current_price": current_price,
        "exchange": "OTHER" if asset_type == "mutual_fund" else "NSE",
        "amc": current_amc,
    }


def _deduplicate(holdings: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Aggregate holdings by ISIN (same scheme across multiple folios)."""
    aggregated: dict[str, dict[str, Any]] = {}
    for h in holdings:
        isin = h["isin"]
        if not isin:
            continue
        if isin in aggregated:
            aggregated[isin]["quantity"] += h["quantity"]
            if h["current_price"] > aggregated[isin]["current_price"]:
                aggregated[isin]["current_price"] = h["current_price"]
        else:
            aggregated[isin] = dict(h)

    return [h for h in aggregated.values() if h["quantity"] > 0]


class CAMSKFinParser:
    """Parser for CAMS and KFintech Mutual Fund CAS PDF statements.

    Handles both CAMS and KFin formats, automatically detecting which
    format the PDF uses based on text markers.

    Usage::

        with open("cams_cas.pdf", "rb") as f:
            parser = CAMSKFinParser(f.read(), password="PAN1234A")
            result = parser.parse()
            # result.holdings: list of holding dicts
            # result.investor_name: str
            # result.pan: str | None
            # result.format: "cams" | "kfin" | "unknown"
    """

    def __init__(self, file_bytes: bytes, password: str | None = None) -> None:
        self.file_bytes = file_bytes
        self.password = password

    def parse(self) -> dict[str, Any]:
        """Parse the PDF and return structured result.

        Returns::

            {
                "format": "cams" | "kfin" | "unknown",
                "investor_name": str | None,
                "pan": str | None,
                "holdings": list[dict],
                "amc_count": int,
                "pages_processed": int,
            }
        """
        holdings: list[dict[str, Any]] = []
        full_text_parts: list[str] = []
        pages_processed = 0
        current_amc = "Unknown AMC"

        try:
            with pdfplumber.open(
                io.BytesIO(self.file_bytes), password=self.password
            ) as pdf:
                for page in pdf.pages:
                    text = page.extract_text()
                    if not text:
                        continue
                    full_text_parts.append(text)
                    pages_processed += 1

                    for line in text.split("\n"):
                        line = line.strip()
                        if not line:
                            continue

                        # Detect AMC header lines (typically all-caps fund house names)
                        if self._is_amc_header(line):
                            current_amc = line.strip(": -")
                            continue

                        # Try to parse as a scheme/holding line
                        holding = _parse_scheme_line(line, current_amc)
                        if holding and holding["quantity"] > 0:
                            holdings.append(holding)

        except Exception as e:
            logger.error("cams_kfin_parse_failed", error=str(e))
            raise ValueError(f"Failed to parse CAMS/KFin PDF: {e}") from e

        full_text = "\n".join(full_text_parts)
        detected_format = _detect_format(full_text)
        pan = _extract_pan(full_text)

        # Extract investor name (usually first non-empty line of first page)
        investor_name = self._extract_investor_name(full_text)

        deduped = _deduplicate(holdings)
        amcs_seen = {h["amc"] for h in deduped}

        logger.info(
            "cams_kfin_parsed",
            format=detected_format,
            holdings=len(deduped),
            amcs=len(amcs_seen),
            pages=pages_processed,
        )

        return {
            "format": detected_format,
            "investor_name": investor_name,
            "pan": pan,
            "holdings": deduped,
            "amc_count": len(amcs_seen),
            "pages_processed": pages_processed,
        }

    def _is_amc_header(self, line: str) -> bool:
        """Heuristic: line is an AMC header if it's mostly uppercase and no ISIN."""
        if _ISIN_RE.search(line):
            return False
        words = line.split()
        if not words or len(words) > 12:
            return False
        upper_words = sum(1 for w in words if w.isupper() and len(w) > 2)
        # AMC name lines: at least half words all-caps, no numbers
        numbers_in_line = _DECIMAL_RE.findall(line)
        return upper_words >= max(1, len(words) // 2) and len(numbers_in_line) == 0

    def _extract_investor_name(self, text: str) -> str | None:
        """Try to extract investor name from statement header."""
        # Common patterns: "Name: JOHN DOE" or "Mr./Ms. JOHN DOE"
        name_match = re.search(
            r"(?:Investor\s+Name|Name)\s*:\s*([A-Z][A-Za-z ]{2,50})", text
        )
        if name_match:
            return name_match.group(1).strip()
        # Try Mr/Mrs prefix
        title_match = re.search(r"\b(?:Mr\.|Ms\.|Mrs\.)\s+([A-Z][A-Za-z ]{2,40})", text)
        if title_match:
            return title_match.group(1).strip()
        return None
