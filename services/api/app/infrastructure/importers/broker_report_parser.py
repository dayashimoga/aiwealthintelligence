"""Flexible parser for popular Indian broker holdings reports (Zerodha, Groww, Upstox, Angel, etc.).

Supports CSV and Excel file formats, automatically mapping columns based on name heuristics.
"""

from __future__ import annotations

import csv
import io
import pandas as pd
from decimal import Decimal
import structlog

logger = structlog.get_logger(__name__)

# Heuristic mappings for column detection
COLUMN_MAPPINGS = {
    "symbol": ["symbol", "ticker", "instrument", "tradingsymbol", "stock symbol", "scrip code", "security symbol"],
    "isin": ["isin", "isin code", "security isin"],
    "name": ["name", "security name", "company name", "instrument name", "company", "description"],
    "quantity": ["quantity", "qty", "qty.", "shares", "units", "balance qty", "holding qty", "available qty"],
    "average_buy_price": ["average buy price", "avg price", "avg cost", "buy price", "avg. cost", "average cost", "acquisition price"],
    "current_price": ["current price", "live price", "ltp", "last traded price", "market price", "cmp", "close price"],
    "asset_type": ["asset type", "type", "instrument type", "security type"],
}

class BrokerReportParser:
    """Parser that automatically detects and processes broker holdings statements."""

    def __init__(self, file_bytes: bytes, filename: str) -> None:
        self.file_bytes = file_bytes
        self.filename = filename.lower()

    def parse(self) -> list[dict[str, Any]]:
        """Parses holdings from the uploaded broker report file."""
        df = self._load_to_dataframe()
        if df.empty:
            return []

        # Find columns using lowercase strip matching
        detected_cols = self._detect_columns(df)
        if "symbol" not in detected_cols and "isin" not in detected_cols:
            raise ValueError("Could not identify Ticker/Symbol or ISIN column in the report.")

        holdings = []
        for index, row in df.iterrows():
            try:
                # Extract values using detected columns or sensible fallbacks
                symbol = str(row[detected_cols["symbol"]]).strip().upper() if "symbol" in detected_cols else ""
                isin = str(row[detected_cols["isin"]]).strip().upper() if "isin" in detected_cols else ""
                
                # We need at least symbol or ISIN
                if not symbol and not isin:
                    continue
                
                if not symbol:
                    symbol = isin
                    
                name = str(row[detected_cols["name"]]).strip() if "name" in detected_cols else symbol
                
                qty_val = row[detected_cols["quantity"]] if "quantity" in detected_cols else 0
                avg_price_val = row[detected_cols["average_buy_price"]] if "average_buy_price" in detected_cols else 0
                curr_price_val = row[detected_cols["current_price"]] if "current_price" in detected_cols else 0

                # Clean numeric values
                quantity = self._parse_decimal(qty_val)
                average_buy_price = self._parse_decimal(avg_price_val)
                current_price = self._parse_decimal(curr_price_val)

                if quantity <= 0:
                    continue

                asset_type = "stock"
                if "asset_type" in detected_cols:
                    raw_type = str(row[detected_cols["asset_type"]]).lower()
                    if "fund" in raw_type or "mf" in raw_type or "mutual" in raw_type:
                        asset_type = "mutual_fund"
                elif isin.startswith("INF"):
                    asset_type = "mutual_fund"

                holdings.append({
                    "symbol": symbol,
                    "name": name,
                    "isin": isin,
                    "asset_type": asset_type,
                    "exchange": "NSE" if asset_type == "stock" else "OTHER",
                    "quantity": quantity,
                    "average_buy_price": average_buy_price,
                    "current_price": current_price,
                })
            except Exception as e:
                logger.warning("broker_report_row_parse_failed", index=index, error=str(e))
                continue

        return holdings

    def _load_to_dataframe(self) -> pd.DataFrame:
        """Loads CSV or Excel data into a pandas DataFrame."""
        try:
            if self.filename.endswith(".xlsx") or self.filename.endswith(".xls"):
                # Excel file
                return pd.read_excel(io.BytesIO(self.file_bytes))
            else:
                # Fallback to CSV
                # Try UTF-8 first, then Latin-1
                try:
                    text = self.file_bytes.decode("utf-8")
                except UnicodeDecodeError:
                    text = self.file_bytes.decode("latin-1")
                return pd.read_csv(io.StringIO(text))
        except Exception as e:
            logger.error("dataframe_load_failed", error=str(e))
            raise ValueError(f"Could not load file into DataFrame: {e}") from e

    def _detect_columns(self, df: pd.DataFrame) -> dict[str, str]:
        """Detects indices or names of columns based on text patterns."""
        detected = {}
        columns = [str(c).strip().lower() for c in df.columns]
        
        for canonical, options in COLUMN_MAPPINGS.items():
            for opt in options:
                if opt in columns:
                    # Find original column name to keep case sensitivity/indexing correct
                    idx = columns.index(opt)
                    detected[canonical] = df.columns[idx]
                    break
        return detected

    def _parse_decimal(self, val: Any) -> Decimal:
        """Helper to convert float/int/str/nan to clean Decimal."""
        if pd.isna(val) or val is None:
            return Decimal("0")
        try:
            # Clean commas and currency symbols if string
            if isinstance(val, str):
                cleaned = "".join(c for c in val if c.isdigit() or c in (".", "-"))
                return Decimal(cleaned) if cleaned else Decimal("0")
            return Decimal(str(val))
        except Exception:
            return Decimal("0")
