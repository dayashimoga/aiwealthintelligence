"""Tests for email CAS importer and CAMS/KFin parser.

Covers:
- EmailCASImporter: trusted sender detection, subject matching, attachment
  parsing (via mocked IMAP), parse-failed graceful handling
- CAMSKFinParser: format detection, investor name extraction, scheme line
  parsing, PAN extraction, deduplication, error handling
- Import routes: CAMS/KFin PDF upload, email config, email scan trigger
"""

from __future__ import annotations

from decimal import Decimal
from typing import TYPE_CHECKING
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

if TYPE_CHECKING:
    from typing import Any


# ============================================================
# EmailCASImporter unit tests (no real IMAP)
# ============================================================


@pytest.mark.unit
class TestEmailCASImporter:
    def test_is_trusted_sender_nsdl(self) -> None:
        from app.infrastructure.importers.email_cas_importer import _is_trusted_sender

        assert _is_trusted_sender("cas@nsdl.co.in") is True

    def test_is_trusted_sender_cams(self) -> None:
        from app.infrastructure.importers.email_cas_importer import _is_trusted_sender

        assert _is_trusted_sender("statement@camsonline.com") is True

    def test_is_trusted_sender_kfin(self) -> None:
        from app.infrastructure.importers.email_cas_importer import _is_trusted_sender

        assert _is_trusted_sender("noreply@kfintech.com") is True

    def test_is_trusted_sender_cdsl(self) -> None:
        from app.infrastructure.importers.email_cas_importer import _is_trusted_sender

        assert _is_trusted_sender("info@cdslindia.com") is True

    def test_is_not_trusted_random_sender(self) -> None:
        from app.infrastructure.importers.email_cas_importer import _is_trusted_sender

        assert _is_trusted_sender("spam@evil.com") is False

    def test_has_cas_subject_matches(self) -> None:
        from app.infrastructure.importers.email_cas_importer import _has_cas_subject

        assert _has_cas_subject("Your Consolidated Account Statement - January 2024")
        assert _has_cas_subject("CAS Statement for December")
        assert _has_cas_subject("Mutual Fund Statement")

    def test_has_cas_subject_no_match(self) -> None:
        from app.infrastructure.importers.email_cas_importer import _has_cas_subject

        assert not _has_cas_subject("Invoice for Order #1234")
        assert not _has_cas_subject("Happy Birthday!")

    def test_decode_header_value_plain(self) -> None:
        from app.infrastructure.importers.email_cas_importer import _decode_header_value

        assert _decode_header_value("Hello World") == "Hello World"

    def test_importer_raises_without_credentials(self) -> None:
        from app.infrastructure.importers.email_cas_importer import EmailCASImporter

        importer = EmailCASImporter(
            imap_host="",
            email_address="",
            email_password="",
        )
        with pytest.raises(ValueError, match="credentials not configured"):
            importer._connect()

    async def test_scan_and_parse_returns_empty_when_no_credentials(self) -> None:
        """scan_and_parse with bad credentials should raise, not silently pass."""
        from app.infrastructure.importers.email_cas_importer import EmailCASImporter

        importer = EmailCASImporter(imap_host="", email_address="", email_password="")

        with pytest.raises(Exception):
            await importer.scan_and_parse()

    async def test_scan_and_parse_with_mocked_imap(self) -> None:
        """Full scan+parse cycle with a fully mocked IMAP and pdfplumber."""
        import email as email_lib

        from app.infrastructure.importers.email_cas_importer import EmailCASImporter

        # Build a fake email with a PDF attachment
        msg = email_lib.message.EmailMessage()
        msg["From"] = "cas@camsonline.com"
        msg["Subject"] = "Consolidated Account Statement"
        msg["Date"] = "Mon, 01 Jan 2024 10:00:00 +0530"

        # Attach a fake PDF
        fake_pdf = b"%PDF-1.4 fake"
        msg.add_attachment(
            fake_pdf,
            maintype="application",
            subtype="pdf",
            filename="CAS_Jan_2024.pdf",
        )

        raw_bytes = msg.as_bytes()

        # Mock IMAP4_SSL
        mock_conn = MagicMock()
        mock_conn.login.return_value = ("OK", [b"Logged in"])
        mock_conn.select.return_value = ("OK", [b"10"])
        mock_conn.search.return_value = ("OK", [b"1"])
        mock_conn.fetch.return_value = ("OK", [(None, raw_bytes)])
        mock_conn.logout.return_value = ("OK", [b""])

        # Mock CASPDFParser.parse to return one holding
        mock_holding = {
            "symbol": "INE040A01034",
            "name": "HDFC Bank",
            "isin": "INE040A01034",
            "asset_type": "stock",
            "quantity": Decimal("100"),
            "average_buy_price": Decimal("0"),
            "current_price": Decimal("1500"),
            "exchange": "NSE",
        }

        with (
            patch("imaplib.IMAP4_SSL", return_value=mock_conn),
            patch(
                "app.infrastructure.importers.email_cas_importer.CASPDFParser"
            ) as MockParser,
        ):
            MockParser.return_value.parse.return_value = [mock_holding]
            importer = EmailCASImporter(
                imap_host="imap.example.com",
                email_address="user@example.com",
                email_password="secret",
            )
            results = await importer.scan_and_parse()

        assert len(results) == 1
        assert results[0]["filename"] == "CAS_Jan_2024.pdf"
        assert results[0]["error"] is None
        assert len(results[0]["holdings"]) == 1

    async def test_scan_and_parse_handles_parse_error_gracefully(self) -> None:
        """Parse error should produce an error entry, not crash the scan."""
        import email as email_lib

        from app.infrastructure.importers.email_cas_importer import EmailCASImporter

        msg = email_lib.message.EmailMessage()
        msg["From"] = "cas@camsonline.com"
        msg["Subject"] = "Consolidated Account Statement"
        msg["Date"] = "Mon, 01 Jan 2024 10:00:00 +0530"
        msg.add_attachment(
            b"bad_pdf",
            maintype="application",
            subtype="pdf",
            filename="bad.pdf",
        )

        mock_conn = MagicMock()
        mock_conn.login.return_value = ("OK", [b""])
        mock_conn.select.return_value = ("OK", [b"1"])
        mock_conn.search.return_value = ("OK", [b"1"])
        mock_conn.fetch.return_value = ("OK", [(None, msg.as_bytes())])
        mock_conn.logout.return_value = ("OK", [b""])

        with (
            patch("imaplib.IMAP4_SSL", return_value=mock_conn),
            patch(
                "app.infrastructure.importers.email_cas_importer.CASPDFParser"
            ) as MockParser,
        ):
            MockParser.return_value.parse.side_effect = ValueError("corrupt PDF")
            importer = EmailCASImporter(
                imap_host="imap.example.com",
                email_address="user@example.com",
                email_password="secret",
            )
            results = await importer.scan_and_parse()

        assert len(results) == 1
        assert results[0]["error"] == "corrupt PDF"
        assert results[0]["holdings"] == []


# ============================================================
# CAMSKFinParser unit tests
# ============================================================


@pytest.mark.unit
class TestCAMSKFinParser:
    def test_detect_format_cams(self) -> None:
        from app.infrastructure.importers.cams_kfin_parser import _detect_format

        assert _detect_format("CAMSONLINE.COM COMPUTER AGE MANAGEMENT") == "cams"

    def test_detect_format_kfin(self) -> None:
        from app.infrastructure.importers.cams_kfin_parser import _detect_format

        assert _detect_format("KFINTECH SERVICES LIMITED") == "kfin"

    def test_detect_format_unknown(self) -> None:
        from app.infrastructure.importers.cams_kfin_parser import _detect_format

        assert _detect_format("Some random PDF text") == "unknown"

    def test_extract_pan(self) -> None:
        from app.infrastructure.importers.cams_kfin_parser import _extract_pan

        text = "Investor Name: JOHN DOE   PAN: ABCDE1234F   Email: j@j.com"
        assert _extract_pan(text) == "ABCDE1234F"

    def test_extract_pan_none_when_missing(self) -> None:
        from app.infrastructure.importers.cams_kfin_parser import _extract_pan

        assert _extract_pan("No PAN here at all") is None

    def test_parse_scheme_line_with_isin_returns_holding(self) -> None:
        from app.infrastructure.importers.cams_kfin_parser import _parse_scheme_line

        line = "INF200KA1RD2 AXIS BLUECHIP FUND DIRECT GROWTH 50.123 100.50 5031.87"
        result = _parse_scheme_line(line, "AXIS AMC")
        assert result is not None
        assert result["isin"] == "INF200KA1RD2"
        assert result["asset_type"] == "mutual_fund"
        assert result["quantity"] == Decimal("50.123")
        assert result["amc"] == "AXIS AMC"

    def test_parse_scheme_line_no_isin_returns_none(self) -> None:
        from app.infrastructure.importers.cams_kfin_parser import _parse_scheme_line

        result = _parse_scheme_line("Total Value: 100000.00", "SBI AMC")
        assert result is None

    def test_parse_scheme_line_two_numbers(self) -> None:
        from app.infrastructure.importers.cams_kfin_parser import _parse_scheme_line

        line = "INF200KA1RD2 SCHEME NAME 100 50"
        result = _parse_scheme_line(line, "AMC")
        assert result is not None
        assert result["quantity"] == Decimal("100")

    def test_parse_scheme_line_one_number(self) -> None:
        from app.infrastructure.importers.cams_kfin_parser import _parse_scheme_line

        line = "INF200KA1RD2 SCHEME NAME 75"
        result = _parse_scheme_line(line, "AMC")
        assert result is not None
        assert result["quantity"] == Decimal("75")

    def test_deduplicate_aggregates_same_isin(self) -> None:
        from app.infrastructure.importers.cams_kfin_parser import _deduplicate

        holdings = [
            {
                "isin": "INF200KA1RD2",
                "symbol": "INF200KA1RD2",
                "name": "AXIS BLUECHIP",
                "asset_type": "mutual_fund",
                "quantity": Decimal("50"),
                "current_price": Decimal("100"),
                "average_buy_price": Decimal("0"),
                "exchange": "OTHER",
                "amc": "AXIS",
            },
            {
                "isin": "INF200KA1RD2",
                "symbol": "INF200KA1RD2",
                "name": "AXIS BLUECHIP",
                "asset_type": "mutual_fund",
                "quantity": Decimal("30"),
                "current_price": Decimal("110"),
                "average_buy_price": Decimal("0"),
                "exchange": "OTHER",
                "amc": "AXIS",
            },
        ]
        result = _deduplicate(holdings)
        assert len(result) == 1
        assert result[0]["quantity"] == Decimal("80")
        assert result[0]["current_price"] == Decimal("110")

    def test_deduplicate_filters_zero_quantity(self) -> None:
        from app.infrastructure.importers.cams_kfin_parser import _deduplicate

        holdings = [
            {
                "isin": "INF200KA1RD2",
                "symbol": "INF200KA1RD2",
                "name": "X",
                "asset_type": "mutual_fund",
                "quantity": Decimal("0"),
                "current_price": Decimal("100"),
                "average_buy_price": Decimal("0"),
                "exchange": "OTHER",
                "amc": "AXIS",
            }
        ]
        assert _deduplicate(holdings) == []

    def test_parse_with_mocked_pdfplumber_cams(self) -> None:
        from app.infrastructure.importers.cams_kfin_parser import CAMSKFinParser

        page_text = (
            "CAMSONLINE.COM CONSOLIDATED ACCOUNT STATEMENT\n"
            "Investor Name: JOHN DOE\n"
            "PAN: ABCDE1234F\n"
            "AXIS MUTUAL FUND\n"
            "INF200KA1RD2 AXIS BLUECHIP FUND DIRECT GROWTH 50.123 100.50 5031.87\n"
            "SBI MUTUAL FUND\n"
            "INF200LA1AB2 SBI BLUECHIP FUND DIRECT 30.000 200.00 6000.00\n"
        )
        mock_page = MagicMock()
        mock_page.extract_text.return_value = page_text
        mock_pdf = MagicMock()
        mock_pdf.__enter__ = MagicMock(return_value=mock_pdf)
        mock_pdf.__exit__ = MagicMock(return_value=False)
        mock_pdf.pages = [mock_page]

        with patch("pdfplumber.open", return_value=mock_pdf):
            parser = CAMSKFinParser(b"fake", password="ABCDE1234F")
            result = parser.parse()

        assert result["format"] == "cams"
        assert result["pan"] == "ABCDE1234F"
        assert result["investor_name"] == "JOHN DOE"
        assert len(result["holdings"]) == 2

    def test_parse_with_mocked_pdfplumber_kfin(self) -> None:
        from app.infrastructure.importers.cams_kfin_parser import CAMSKFinParser

        page_text = (
            "KFINTECH CONSOLIDATED ACCOUNT STATEMENT\n"
            "INF200KA1RD2 SCHEME DIRECT GROWTH 25.000 150.00 3750.00\n"
        )
        mock_page = MagicMock()
        mock_page.extract_text.return_value = page_text
        mock_pdf = MagicMock()
        mock_pdf.__enter__ = MagicMock(return_value=mock_pdf)
        mock_pdf.__exit__ = MagicMock(return_value=False)
        mock_pdf.pages = [mock_page]

        with patch("pdfplumber.open", return_value=mock_pdf):
            parser = CAMSKFinParser(b"fake")
            result = parser.parse()

        assert result["format"] == "kfin"
        assert len(result["holdings"]) == 1

    def test_parse_raises_on_corrupt_bytes(self) -> None:
        from app.infrastructure.importers.cams_kfin_parser import CAMSKFinParser

        parser = CAMSKFinParser(b"not a pdf", None)
        with pytest.raises(ValueError, match="Failed to parse CAMS/KFin PDF"):
            parser.parse()

    def test_parse_skips_empty_pages(self) -> None:
        from app.infrastructure.importers.cams_kfin_parser import CAMSKFinParser

        mock_page = MagicMock()
        mock_page.extract_text.return_value = None
        mock_pdf = MagicMock()
        mock_pdf.__enter__ = MagicMock(return_value=mock_pdf)
        mock_pdf.__exit__ = MagicMock(return_value=False)
        mock_pdf.pages = [mock_page]

        with patch("pdfplumber.open", return_value=mock_pdf):
            parser = CAMSKFinParser(b"fake")
            result = parser.parse()

        assert result["holdings"] == []
        assert result["pages_processed"] == 0


# ============================================================
# Import routes integration tests
# ============================================================


@pytest.mark.unit
class TestImportRoutes:
    """Integration tests for the new import API endpoints."""

    async def test_get_email_config_returns_status(self, auth_client: Any) -> None:
        resp = await auth_client.get("/api/v1/import/email-config")
        assert resp.status_code == 200
        data = resp.json()
        assert "configured" in data
        assert "host" in data
        assert "email" in data
        assert "folder" in data
        assert data["configured"] is False  # No env vars set in test env

    async def test_email_config_test_returns_400_when_not_configured(
        self, auth_client: Any
    ) -> None:
        resp = await auth_client.post("/api/v1/import/email-config/test")
        assert resp.status_code == 400

    async def test_email_scan_returns_400_when_not_configured(
        self, auth_client: Any, sample_portfolio: dict
    ) -> None:
        resp = await auth_client.post(
            f'/api/v1/portfolios/{sample_portfolio["id"]}/import/email-scan',
            data={"since_date": "01-Jan-2024"},
        )
        assert resp.status_code == 400

    async def test_cams_kfin_import_requires_pdf_extension(
        self, auth_client: Any, sample_portfolio: dict
    ) -> None:
        """Non-PDF files should be rejected with 422 or 400."""
        import io

        files = {"file": ("holdings.csv", io.BytesIO(b"isin,units\nINF1,10"), "text/csv")}
        resp = await auth_client.post(
            f'/api/v1/portfolios/{sample_portfolio["id"]}/import/cams-kfin',
            files=files,
        )
        assert resp.status_code in (400, 422)

    async def test_cams_kfin_import_empty_file_rejected(
        self, auth_client: Any, sample_portfolio: dict
    ) -> None:
        import io

        files = {"file": ("empty.pdf", io.BytesIO(b""), "application/pdf")}
        resp = await auth_client.post(
            f'/api/v1/portfolios/{sample_portfolio["id"]}/import/cams-kfin',
            files=files,
        )
        assert resp.status_code in (400, 422)

    async def test_cams_kfin_import_invalid_portfolio(
        self, auth_client: Any
    ) -> None:
        import io

        files = {"file": ("cas.pdf", io.BytesIO(b"%PDF-1.4 fake"), "application/pdf")}
        resp = await auth_client.post(
            "/api/v1/portfolios/nonexistent-portfolio-id/import/cams-kfin",
            files=files,
        )
        assert resp.status_code == 404

    async def test_unauthenticated_email_config_returns_401(
        self, client: Any
    ) -> None:
        resp = await client.get("/api/v1/import/email-config")
        assert resp.status_code == 401
