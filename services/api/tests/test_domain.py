"""Tests for domain entities and business logic."""

from __future__ import annotations

from decimal import Decimal

import pytest

from app.domain.entities import (
    Holding,
    Money,
    Percentage,
    Portfolio,
    Transaction,
    User,
)
from app.shared.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    validate_password_strength,
    verify_password,
)


@pytest.mark.unit
class TestMoneyValueObject:
    """Tests for Money value object."""

    def test_money_addition(self) -> None:
        """Adding two Money objects with same currency."""
        m1 = Money(amount=Decimal("100.50"))
        m2 = Money(amount=Decimal("200.75"))
        result = m1 + m2
        assert result.amount == Decimal("301.25")

    def test_money_addition_different_currency_raises(self) -> None:
        """Adding Money with different currencies raises ValueError."""
        from app.domain.entities import Currency

        m1 = Money(amount=Decimal("100"))
        m2 = Money(amount=Decimal("200"), currency=Currency.USD)
        with pytest.raises(ValueError, match="Cannot add"):
            _ = m1 + m2

    def test_money_multiplication(self) -> None:
        """Multiplying Money by a factor."""
        m = Money(amount=Decimal("100"))
        result = m * 3
        assert result.amount == Decimal("300")


@pytest.mark.unit
class TestPercentage:
    """Tests for Percentage value object."""

    def test_valid_percentage(self) -> None:
        """Valid percentage creation."""
        p = Percentage(value=Decimal("50"))
        assert p.value == Decimal("50")

    def test_invalid_percentage_raises(self) -> None:
        """Out-of-range percentage raises ValueError."""
        with pytest.raises(ValueError):
            Percentage(value=Decimal("15000"))


@pytest.mark.unit
class TestUserEntity:
    """Tests for User entity."""

    def test_user_creation(self) -> None:
        """User creates with defaults."""
        user = User(email="test@test.com", full_name="Test")
        assert user.is_active
        assert not user.is_verified
        assert user.id

    def test_user_verify(self) -> None:
        """Verifying a user sets is_verified."""
        user = User(email="test@test.com")
        user.verify()
        assert user.is_verified

    def test_user_update_last_login(self) -> None:
        """Updating last login sets timestamp."""
        user = User(email="test@test.com")
        assert user.last_login_at is None
        user.update_last_login()
        assert user.last_login_at is not None


@pytest.mark.unit
class TestPortfolioEntity:
    """Tests for Portfolio entity."""

    def test_empty_portfolio(self) -> None:
        """Empty portfolio has zero values."""
        portfolio = Portfolio()
        assert portfolio.total_invested == Decimal("0")
        assert portfolio.total_current_value == Decimal("0")
        assert portfolio.holding_count == 0

    def test_portfolio_with_holdings(self) -> None:
        """Portfolio with holdings calculates correctly."""
        portfolio = Portfolio(
            holdings=[
                Holding(
                    symbol="TCS",
                    name="TCS",
                    quantity=Decimal("10"),
                    average_buy_price=Decimal("3500"),
                    current_price=Decimal("3800"),
                ),
                Holding(
                    symbol="INFY",
                    name="Infosys",
                    quantity=Decimal("20"),
                    average_buy_price=Decimal("1500"),
                    current_price=Decimal("1700"),
                ),
            ]
        )
        assert portfolio.total_invested == Decimal("65000")
        assert portfolio.total_current_value == Decimal("72000")
        assert portfolio.total_gain_loss == Decimal("7000")
        assert portfolio.holding_count == 2

    def test_portfolio_gain_loss_percentage(self) -> None:
        """Portfolio gain/loss percentage is calculated correctly."""
        portfolio = Portfolio(
            holdings=[
                Holding(
                    quantity=Decimal("100"),
                    average_buy_price=Decimal("100"),
                    current_price=Decimal("110"),
                ),
            ]
        )
        assert portfolio.total_gain_loss_percentage == Decimal("10")


@pytest.mark.unit
class TestHoldingEntity:
    """Tests for Holding entity."""

    def test_holding_calculations(self) -> None:
        """Holding computes invested value, current value, gain/loss."""
        h = Holding(
            symbol="TCS",
            name="TCS",
            quantity=Decimal("10"),
            average_buy_price=Decimal("3500"),
            current_price=Decimal("3800"),
        )
        assert h.invested_value == Decimal("35000")
        assert h.current_value == Decimal("38000")
        assert h.gain_loss == Decimal("3000")

    def test_holding_gain_loss_percentage(self) -> None:
        """Holding gain/loss percentage calculation."""
        h = Holding(
            quantity=Decimal("100"),
            average_buy_price=Decimal("100"),
            current_price=Decimal("120"),
        )
        assert h.gain_loss_percentage == Decimal("20")

    def test_zero_invested_value(self) -> None:
        """Zero invested value returns 0% gain/loss."""
        h = Holding(quantity=Decimal("0"), average_buy_price=Decimal("0"))
        assert h.gain_loss_percentage == Decimal("0")


@pytest.mark.unit
class TestTransactionEntity:
    """Tests for Transaction entity."""

    def test_buy_transaction_total(self) -> None:
        """Buy transaction includes fees and tax."""
        t = Transaction(
            transaction_type="buy",
            quantity=Decimal("10"),
            price=Decimal("100"),
            fees=Decimal("10"),
            tax=Decimal("5"),
        )
        assert t.total_amount == Decimal("1015")

    def test_sell_transaction_total(self) -> None:
        """Sell transaction deducts fees and tax."""
        t = Transaction(
            transaction_type="sell",
            quantity=Decimal("10"),
            price=Decimal("100"),
            fees=Decimal("10"),
            tax=Decimal("5"),
        )
        assert t.total_amount == Decimal("985")


@pytest.mark.unit
class TestSecurity:
    """Tests for security utilities."""

    def test_password_hash_verify(self) -> None:
        """Password hashing and verification works."""
        hashed = hash_password("TestPass@123")
        assert verify_password("TestPass@123", hashed)
        assert not verify_password("WrongPass@123", hashed)

    def test_access_token_creation_and_decode(self) -> None:
        """Access token can be created and decoded."""
        token = create_access_token("user-123", "test@test.com", "user")
        payload = decode_token(token)
        assert payload is not None
        assert payload["sub"] == "user-123"
        assert payload["email"] == "test@test.com"
        assert payload["type"] == "access"

    def test_refresh_token_creation(self) -> None:
        """Refresh token can be created and decoded."""
        token = create_refresh_token("user-123")
        payload = decode_token(token)
        assert payload is not None
        assert payload["sub"] == "user-123"
        assert payload["type"] == "refresh"

    def test_invalid_token_returns_none(self) -> None:
        """Invalid token returns None."""
        result = decode_token("invalid-token")
        assert result is None

    def test_password_strength_validation(self) -> None:
        """Password strength validation catches weak passwords."""
        errors = validate_password_strength("short")
        assert len(errors) > 0

        errors = validate_password_strength("StrongPass@123")
        assert len(errors) == 0

    def test_password_max_length(self) -> None:
        """Password exceeding 128 chars is rejected."""
        long_password = "A" * 130
        errors = validate_password_strength(long_password)
        assert any("128" in e for e in errors)
