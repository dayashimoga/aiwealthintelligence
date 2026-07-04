"""Tests for portfolio CAS PDF statement and Broker report importers."""

from __future__ import annotations

from decimal import Decimal
import pytest

from app.infrastructure.importers.cas_pdf_parser import CASPDFParser
from app.infrastructure.importers.broker_report_parser import BrokerReportParser


def test_broker_report_csv_parsing() -> None:
    """Tests parsing Zerodha / Groww style holdings CSV report."""
    csv_content = (
        "Instrument,ISIN,Qty.,Avg. cost,LTP,Asset Type\n"
        "RELIANCE,INE002A01018,10,2500.00,2800.00,stock\n"
        "INFY,INE009A01021,20,1500.00,1650.00,stock\n"
        "HDFCBANK,INE040A01034,15,1600.00,1580.00,stock\n"
        "SGBJUL31,,5,5500.00,6200.00,SGB\n"
    )
    
    parser = BrokerReportParser(csv_content.encode("utf-8"), "holdings_export.csv")
    holdings = parser.parse()
    
    assert len(holdings) == 4
    
    # Check Reliance
    reliance = next(h for h in holdings if h["symbol"] == "RELIANCE")
    assert reliance["isin"] == "INE002A01018"
    assert reliance["quantity"] == Decimal("10")
    assert reliance["average_buy_price"] == Decimal("2500.00")
    assert reliance["current_price"] == Decimal("2800.00")
    assert reliance["asset_type"] == "stock"
    assert reliance["exchange"] == "NSE"

    # Check SGB (non-stock, but imported with custom qty)
    sgb = next(h for h in holdings if h["symbol"] == "SGBJUL31")
    assert sgb["quantity"] == Decimal("5")
    assert sgb["average_buy_price"] == Decimal("5500.00")
    assert sgb["current_price"] == Decimal("6200.00")
    assert sgb["asset_type"] == "stock" # generic fallback if not match MF
