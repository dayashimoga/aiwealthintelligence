"""NSDL/CDSL and CAMS/KFintech CAS PDF statement parser using pdfplumber."""

from __future__ import annotations

import io
import re
from decimal import Decimal

import pdfplumber
import structlog

logger = structlog.get_logger(__name__)

# Regular expressions for data matching
ISIN_regex = re.compile(r"\b[A-Z]{2}[A-Z0-9]{9}\d\b")
folio_regex = re.compile(r"\b\d+/\d+\b|\b\d{6,12}\b")
decimal_regex = re.compile(r"[-+]?\d*\.\d+|\d+")


class CASPDFParser:
    """Parser for NSDL/CDSL Demat Consolidated Account Statements (CAS) and CAMS/KFin Mutual Fund CAS PDFs."""

    def __init__(self, file_bytes: bytes, password: str | None = None) -> None:
        self.file_bytes = file_bytes
        self.password = password

    def parse(self) -> list[dict[str, Any]]:
        """Parses the CAS PDF and returns a list of extracted holdings."""
        holdings = []
        try:
            with pdfplumber.open(io.BytesIO(self.file_bytes), password=self.password) as pdf:
                logger.info("pdf_opened_successfully", total_pages=len(pdf.pages))
                for _page_num, page in enumerate(pdf.pages, start=1):
                    text = page.extract_text()
                    if not text:
                        continue

                    lines = text.split("\n")
                    for line in lines:
                        parsed_holding = self._parse_line(line)
                        if parsed_holding:
                            holdings.append(parsed_holding)
        except Exception as e:
            logger.error("cas_pdf_parse_failed", error=str(e))
            raise ValueError(f"Failed to parse CAS PDF: {e}") from e

        return self._deduplicate_and_aggregate(holdings)

    def _parse_line(self, line: str) -> dict[str, Any] | None:
        """Parses a single line from the PDF to identify a holding."""
        isin_match = ISIN_regex.search(line)
        if not isin_match:
            return None

        isin = isin_match.group(0)

        # Strip the ISIN out of the line to parse other parts
        remaining_text = line.replace(isin, "").strip()

        # Try to find mutual fund units or stock quantity
        # Typically towards the end of the line, preceded by NAV/Price
        numbers = decimal_regex.findall(remaining_text)

        quantity = Decimal("0")
        current_price = Decimal("0")

        # Parse numbers from the end of the line
        # CAMS/NSDL CAS rows usually end with: ... [NAV/Price] [Balance Units] [Current Value]
        if len(numbers) >= 2:
            try:
                # Last number is usually Current Value, second to last is Units/Qty, third to last is NAV/Price
                # We prioritize the last few elements
                if len(numbers) >= 3:
                    quantity = Decimal(numbers[-2])
                    current_price = Decimal(numbers[-3])
                else:
                    quantity = Decimal(numbers[-1])
            except Exception:
                pass

        # Extract a clean security/scheme name
        # Remove numbers and other metadata from the start
        name_parts = []
        for word in remaining_text.split():
            if not decimal_regex.match(word) and word not in ("-", "/"):
                name_parts.append(word)

        name = " ".join(name_parts).strip()

        # Determine asset type based on name indicators or ISIN
        # INF is generally Indian Mutual Funds
        asset_type = "stock"
        if (
            isin.startswith("INF")
            or "MUTUAL FUND" in name.upper()
            or "GROWTH" in name.upper()
            or "DIRECT" in name.upper()
        ):
            asset_type = "mutual_fund"

        # Sector matching helper mapping (to be enriched by market data later)
        return {
            "symbol": isin,  # fallback to ISIN as symbol for tracking
            "name": name if name else f"Unknown ({isin})",
            "isin": isin,
            "asset_type": asset_type,
            "quantity": quantity,
            "average_buy_price": Decimal(
                "0"
            ),  # Average buy price is not in standard CAS balance statements
            "current_price": current_price,
            "exchange": "NSE" if asset_type == "stock" else "OTHER",
        }

    def _deduplicate_and_aggregate(self, holdings: list[dict[str, Any]]) -> list[dict[str, Any]]:
        """Deduplicates and groups holdings by ISIN."""
        aggregated: dict[str, dict[str, Any]] = {}
        for h in holdings:
            isin = h["isin"]
            if not isin:
                continue

            if isin in aggregated:
                # Accumulate quantity
                aggregated[isin]["quantity"] += h["quantity"]
                # Keep maximum current price if non-zero
                if h["current_price"] > aggregated[isin]["current_price"]:
                    aggregated[isin]["current_price"] = h["current_price"]
            else:
                aggregated[isin] = h

        # Filter out holdings with 0 or negative quantity
        return [h for h in aggregated.values() if h["quantity"] > 0]
