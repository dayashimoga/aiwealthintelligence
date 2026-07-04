"""SQLAlchemy implementations of domain repository interfaces.

These concrete implementations handle database persistence using SQLAlchemy.
They map between domain entities and ORM models.
"""

from __future__ import annotations

import uuid
from decimal import Decimal
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.entities import (
    AIRecommendation,
    Holding,
    MarketNews,
    Portfolio,
    Transaction,
    User,
    Watchlist,
)
from app.domain.repositories import (
    AIRecommendationRepository,
    HoldingRepository,
    MarketNewsRepository,
    PortfolioRepository,
    TransactionRepository,
    UserRepository,
    WatchlistRepository,
)
from app.infrastructure.database.models import (
    AIRecommendationModel,
    HoldingModel,
    MarketNewsModel,
    PortfolioModel,
    TransactionModel,
    UserModel,
    WatchlistModel,
)


# ============================================================
# Model <-> Entity Mappers
# ============================================================


def _user_model_to_entity(model: UserModel) -> User:
    """Map UserModel to User entity."""
    return User(
        id=model.id,
        email=model.email,
        hashed_password=model.hashed_password,
        full_name=model.full_name,
        role=model.role,
        is_active=model.is_active,
        is_verified=model.is_verified,
        mfa_enabled=model.mfa_enabled,
        avatar_url=model.avatar_url,
        preferences=model.preferences or {},
        created_at=model.created_at,
        updated_at=model.updated_at,
        last_login_at=model.last_login_at,
    )


def _user_entity_to_model(entity: User) -> UserModel:
    """Map User entity to UserModel."""
    return UserModel(
        id=entity.id,
        email=entity.email,
        hashed_password=entity.hashed_password,
        full_name=entity.full_name,
        role=entity.role.value if hasattr(entity.role, "value") else entity.role,
        is_active=entity.is_active,
        is_verified=entity.is_verified,
        mfa_enabled=entity.mfa_enabled,
        avatar_url=entity.avatar_url,
        preferences=entity.preferences,
        last_login_at=entity.last_login_at,
    )


def _portfolio_model_to_entity(model: PortfolioModel) -> Portfolio:
    """Map PortfolioModel to Portfolio entity."""
    holdings = []
    if "holdings" in model.__dict__ and model.holdings is not None:
        holdings = [_holding_model_to_entity(h) for h in model.holdings]
    return Portfolio(
        id=model.id,
        user_id=model.user_id,
        name=model.name,
        description=model.description,
        is_default=model.is_default,
        currency=model.currency,
        import_source=model.import_source,
        holdings=holdings,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


def _holding_model_to_entity(model: HoldingModel) -> Holding:
    """Map HoldingModel to Holding entity."""
    return Holding(
        id=model.id,
        portfolio_id=model.portfolio_id,
        symbol=model.symbol,
        name=model.name,
        asset_type=model.asset_type,
        exchange=model.exchange,
        currency=model.currency,
        quantity=Decimal(str(model.quantity)),
        average_buy_price=Decimal(str(model.average_buy_price)),
        current_price=Decimal(str(model.current_price)),
        sector=model.sector,
        industry=model.industry,
        country=model.country,
        isin=model.isin,
        notes=model.notes,
        buy_date=model.buy_date,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


def _transaction_model_to_entity(model: TransactionModel) -> Transaction:
    """Map TransactionModel to Transaction entity."""
    return Transaction(
        id=model.id,
        holding_id=model.holding_id,
        portfolio_id=model.portfolio_id,
        transaction_type=model.transaction_type,
        quantity=Decimal(str(model.quantity)),
        price=Decimal(str(model.price)),
        fees=Decimal(str(model.fees)),
        tax=Decimal(str(model.tax)),
        notes=model.notes,
        transaction_date=model.transaction_date,
        created_at=model.created_at,
    )


def _recommendation_model_to_entity(model: AIRecommendationModel) -> AIRecommendation:
    """Map AIRecommendationModel to AIRecommendation entity."""
    return AIRecommendation(
        id=model.id,
        holding_id=model.holding_id,
        symbol=model.symbol,
        action=model.action,
        confidence=Decimal(str(model.confidence)),
        reasoning=model.reasoning,
        evidence=model.evidence or [],
        expected_return=Decimal(str(model.expected_return)),
        risk_level=model.risk_level,
        investment_horizon=model.investment_horizon,
        alternative_suggestions=model.alternative_suggestions or [],
        model_version=model.model_version,
        generated_at=model.generated_at,
        expires_at=model.expires_at,
    )


# ============================================================
# Repository Implementations
# ============================================================


class SQLAlchemyUserRepository(UserRepository):
    """SQLAlchemy implementation of UserRepository."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(self, user: User) -> User:
        model = _user_entity_to_model(user)
        self._session.add(model)
        await self._session.flush()
        return _user_model_to_entity(model)

    async def get_by_id(self, user_id: str) -> User | None:
        result = await self._session.get(UserModel, user_id)
        return _user_model_to_entity(result) if result else None

    async def get_by_email(self, email: str) -> User | None:
        stmt = select(UserModel).where(
            UserModel.email == email, UserModel.is_active.is_(True)
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return _user_model_to_entity(model) if model else None

    async def update(self, user: User) -> User:
        model = await self._session.get(UserModel, user.id)
        if model is None:
            msg = f"User {user.id} not found"
            raise ValueError(msg)
        model.email = user.email
        model.full_name = user.full_name
        model.role = user.role.value if hasattr(user.role, "value") else user.role
        model.is_active = user.is_active
        model.is_verified = user.is_verified
        model.mfa_enabled = user.mfa_enabled
        model.avatar_url = user.avatar_url
        model.preferences = user.preferences
        model.last_login_at = user.last_login_at
        await self._session.flush()
        return _user_model_to_entity(model)

    async def delete(self, user_id: str) -> bool:
        model = await self._session.get(UserModel, user_id)
        if model is None:
            return False
        model.is_active = False
        await self._session.flush()
        return True

    async def list_users(
        self, skip: int = 0, limit: int = 50, filters: dict[str, Any] | None = None
    ) -> list[User]:
        stmt = select(UserModel).where(UserModel.is_active.is_(True))
        if filters:
            if "role" in filters:
                stmt = stmt.where(UserModel.role == filters["role"])
        stmt = stmt.offset(skip).limit(limit)
        result = await self._session.execute(stmt)
        return [_user_model_to_entity(m) for m in result.scalars().all()]


class SQLAlchemyPortfolioRepository(PortfolioRepository):
    """SQLAlchemy implementation of PortfolioRepository."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(self, portfolio: Portfolio) -> Portfolio:
        model = PortfolioModel(
            id=portfolio.id,
            user_id=portfolio.user_id,
            name=portfolio.name,
            description=portfolio.description,
            is_default=portfolio.is_default,
            currency=portfolio.currency.value
            if hasattr(portfolio.currency, "value")
            else portfolio.currency,
            import_source=portfolio.import_source.value
            if hasattr(portfolio.import_source, "value")
            else portfolio.import_source,
        )
        self._session.add(model)
        await self._session.flush()
        return _portfolio_model_to_entity(model)

    async def get_by_id(self, portfolio_id: str, user_id: str) -> Portfolio | None:
        stmt = select(PortfolioModel).where(
            PortfolioModel.id == portfolio_id,
            PortfolioModel.user_id == user_id,
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return _portfolio_model_to_entity(model) if model else None

    async def list_by_user(
        self, user_id: str, skip: int = 0, limit: int = 50
    ) -> list[Portfolio]:
        stmt = (
            select(PortfolioModel)
            .where(PortfolioModel.user_id == user_id)
            .offset(skip)
            .limit(limit)
            .order_by(PortfolioModel.created_at.desc())
        )
        result = await self._session.execute(stmt)
        return [_portfolio_model_to_entity(m) for m in result.scalars().all()]

    async def update(self, portfolio: Portfolio) -> Portfolio:
        model = await self._session.get(PortfolioModel, portfolio.id)
        if model is None:
            msg = f"Portfolio {portfolio.id} not found"
            raise ValueError(msg)
        model.name = portfolio.name
        model.description = portfolio.description
        model.is_default = portfolio.is_default
        await self._session.flush()
        return _portfolio_model_to_entity(model)

    async def delete(self, portfolio_id: str, user_id: str) -> bool:
        stmt = select(PortfolioModel).where(
            PortfolioModel.id == portfolio_id,
            PortfolioModel.user_id == user_id,
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        if model is None:
            return False
        await self._session.delete(model)
        await self._session.flush()
        return True


class SQLAlchemyHoldingRepository(HoldingRepository):
    """SQLAlchemy implementation of HoldingRepository."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(self, holding: Holding) -> Holding:
        model = HoldingModel(
            id=holding.id,
            portfolio_id=holding.portfolio_id,
            symbol=holding.symbol,
            name=holding.name,
            asset_type=holding.asset_type.value
            if hasattr(holding.asset_type, "value")
            else holding.asset_type,
            exchange=holding.exchange.value
            if hasattr(holding.exchange, "value")
            else holding.exchange,
            currency=holding.currency.value
            if hasattr(holding.currency, "value")
            else holding.currency,
            quantity=float(holding.quantity),
            average_buy_price=float(holding.average_buy_price),
            current_price=float(holding.current_price),
            sector=holding.sector,
            industry=holding.industry,
            country=holding.country,
            isin=holding.isin,
            notes=holding.notes,
            buy_date=holding.buy_date,
        )
        self._session.add(model)
        await self._session.flush()
        return _holding_model_to_entity(model)

    async def get_by_id(self, holding_id: str, portfolio_id: str) -> Holding | None:
        stmt = select(HoldingModel).where(
            HoldingModel.id == holding_id,
            HoldingModel.portfolio_id == portfolio_id,
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return _holding_model_to_entity(model) if model else None

    async def list_by_portfolio(
        self, portfolio_id: str, skip: int = 0, limit: int = 100
    ) -> list[Holding]:
        stmt = (
            select(HoldingModel)
            .where(HoldingModel.portfolio_id == portfolio_id)
            .offset(skip)
            .limit(limit)
            .order_by(HoldingModel.created_at.desc())
        )
        result = await self._session.execute(stmt)
        return [_holding_model_to_entity(m) for m in result.scalars().all()]

    async def update(self, holding: Holding) -> Holding:
        model = await self._session.get(HoldingModel, holding.id)
        if model is None:
            msg = f"Holding {holding.id} not found"
            raise ValueError(msg)
        model.symbol = holding.symbol
        model.name = holding.name
        model.quantity = float(holding.quantity)
        model.average_buy_price = float(holding.average_buy_price)
        model.current_price = float(holding.current_price)
        model.sector = holding.sector
        model.industry = holding.industry
        model.notes = holding.notes
        await self._session.flush()
        return _holding_model_to_entity(model)

    async def delete(self, holding_id: str, portfolio_id: str) -> bool:
        stmt = select(HoldingModel).where(
            HoldingModel.id == holding_id,
            HoldingModel.portfolio_id == portfolio_id,
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        if model is None:
            return False
        await self._session.delete(model)
        await self._session.flush()
        return True

    async def bulk_create(self, holdings: list[Holding]) -> list[Holding]:
        models = []
        for holding in holdings:
            model = HoldingModel(
                id=holding.id or str(uuid.uuid4()),
                portfolio_id=holding.portfolio_id,
                symbol=holding.symbol,
                name=holding.name,
                asset_type=holding.asset_type.value
                if hasattr(holding.asset_type, "value")
                else holding.asset_type,
                exchange=holding.exchange.value
                if hasattr(holding.exchange, "value")
                else holding.exchange,
                currency=holding.currency.value
                if hasattr(holding.currency, "value")
                else holding.currency,
                quantity=float(holding.quantity),
                average_buy_price=float(holding.average_buy_price),
                current_price=float(holding.current_price),
                sector=holding.sector,
                industry=holding.industry,
                country=holding.country,
                isin=holding.isin,
                notes=holding.notes,
                buy_date=holding.buy_date,
            )
            models.append(model)
        self._session.add_all(models)
        await self._session.flush()
        return [_holding_model_to_entity(m) for m in models]


class SQLAlchemyTransactionRepository(TransactionRepository):
    """SQLAlchemy implementation of TransactionRepository."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(self, transaction: Transaction) -> Transaction:
        model = TransactionModel(
            id=transaction.id,
            holding_id=transaction.holding_id,
            portfolio_id=transaction.portfolio_id,
            transaction_type=transaction.transaction_type,
            quantity=float(transaction.quantity),
            price=float(transaction.price),
            fees=float(transaction.fees),
            tax=float(transaction.tax),
            notes=transaction.notes,
            transaction_date=transaction.transaction_date,
        )
        self._session.add(model)
        await self._session.flush()
        return _transaction_model_to_entity(model)

    async def list_by_holding(
        self, holding_id: str, skip: int = 0, limit: int = 100
    ) -> list[Transaction]:
        stmt = (
            select(TransactionModel)
            .where(TransactionModel.holding_id == holding_id)
            .offset(skip)
            .limit(limit)
            .order_by(TransactionModel.transaction_date.desc())
        )
        result = await self._session.execute(stmt)
        return [_transaction_model_to_entity(m) for m in result.scalars().all()]

    async def list_by_portfolio(
        self, portfolio_id: str, skip: int = 0, limit: int = 200
    ) -> list[Transaction]:
        stmt = (
            select(TransactionModel)
            .where(TransactionModel.portfolio_id == portfolio_id)
            .offset(skip)
            .limit(limit)
            .order_by(TransactionModel.transaction_date.desc())
        )
        result = await self._session.execute(stmt)
        return [_transaction_model_to_entity(m) for m in result.scalars().all()]


class SQLAlchemyAIRecommendationRepository(AIRecommendationRepository):
    """SQLAlchemy implementation of AIRecommendationRepository."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def save(self, recommendation: AIRecommendation) -> AIRecommendation:
        explainability_dict = {}
        if recommendation.explainability:
            e = recommendation.explainability
            explainability_dict = {
                "fundamentals": e.fundamentals,
                "technical_indicators": e.technical_indicators,
                "news_sentiment": e.news_sentiment,
                "macroeconomics": e.macroeconomics,
                "valuation": e.valuation,
                "sector_outlook": e.sector_outlook,
                "institutional_activity": e.institutional_activity,
                "insider_activity": e.insider_activity,
                "market_sentiment": e.market_sentiment,
                "overall_summary": e.overall_summary,
            }

        model = AIRecommendationModel(
            id=recommendation.id,
            holding_id=recommendation.holding_id,
            symbol=recommendation.symbol,
            action=recommendation.action.value
            if hasattr(recommendation.action, "value")
            else recommendation.action,
            confidence=float(recommendation.confidence),
            reasoning=recommendation.reasoning,
            evidence=recommendation.evidence,
            expected_return=float(recommendation.expected_return),
            risk_level=recommendation.risk_level.value
            if hasattr(recommendation.risk_level, "value")
            else recommendation.risk_level,
            investment_horizon=recommendation.investment_horizon,
            alternative_suggestions=recommendation.alternative_suggestions,
            explainability=explainability_dict,
            model_version=recommendation.model_version,
            generated_at=recommendation.generated_at,
            expires_at=recommendation.expires_at,
        )
        self._session.add(model)
        await self._session.flush()
        return _recommendation_model_to_entity(model)

    async def get_by_holding(self, holding_id: str) -> AIRecommendation | None:
        stmt = (
            select(AIRecommendationModel)
            .where(AIRecommendationModel.holding_id == holding_id)
            .order_by(AIRecommendationModel.generated_at.desc())
            .limit(1)
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return _recommendation_model_to_entity(model) if model else None

    async def list_by_portfolio(self, portfolio_id: str) -> list[AIRecommendation]:
        stmt = (
            select(AIRecommendationModel)
            .join(HoldingModel)
            .where(HoldingModel.portfolio_id == portfolio_id)
            .order_by(AIRecommendationModel.generated_at.desc())
        )
        result = await self._session.execute(stmt)
        return [_recommendation_model_to_entity(m) for m in result.scalars().all()]


class SQLAlchemyMarketNewsRepository(MarketNewsRepository):
    """SQLAlchemy implementation of MarketNewsRepository."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def save_batch(self, news_items: list[MarketNews]) -> list[MarketNews]:
        models = []
        for item in news_items:
            model = MarketNewsModel(
                id=item.id,
                title=item.title,
                summary=item.summary,
                source=item.source,
                url=item.url,
                sentiment=item.sentiment,
                relevance_score=float(item.relevance_score),
                sectors=item.sectors,
                symbols=item.symbols,
                published_at=item.published_at,
                fetched_at=item.fetched_at,
            )
            models.append(model)
        self._session.add_all(models)
        await self._session.flush()
        return news_items

    async def list_latest(
        self, skip: int = 0, limit: int = 20, sector: str | None = None
    ) -> list[MarketNews]:
        stmt = select(MarketNewsModel).order_by(MarketNewsModel.published_at.desc())
        if sector:
            stmt = stmt.where(MarketNewsModel.sectors.contains([sector]))
        stmt = stmt.offset(skip).limit(limit)
        result = await self._session.execute(stmt)
        return [
            MarketNews(
                id=m.id,
                title=m.title,
                summary=m.summary,
                source=m.source,
                url=m.url,
                sentiment=m.sentiment,
                relevance_score=Decimal(str(m.relevance_score)),
                sectors=m.sectors or [],
                symbols=m.symbols or [],
                published_at=m.published_at,
                fetched_at=m.fetched_at,
            )
            for m in result.scalars().all()
        ]


class SQLAlchemyWatchlistRepository(WatchlistRepository):
    """SQLAlchemy implementation of WatchlistRepository."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(self, watchlist: Watchlist) -> Watchlist:
        model = WatchlistModel(
            id=watchlist.id,
            user_id=watchlist.user_id,
            name=watchlist.name,
            symbols=watchlist.symbols,
            alerts=watchlist.alerts,
        )
        self._session.add(model)
        await self._session.flush()
        return watchlist

    async def get_by_id(self, watchlist_id: str, user_id: str) -> Watchlist | None:
        stmt = select(WatchlistModel).where(
            WatchlistModel.id == watchlist_id,
            WatchlistModel.user_id == user_id,
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        if model is None:
            return None
        return Watchlist(
            id=model.id,
            user_id=model.user_id,
            name=model.name,
            symbols=model.symbols or [],
            alerts=model.alerts or [],
            created_at=model.created_at,
            updated_at=model.updated_at,
        )

    async def list_by_user(self, user_id: str) -> list[Watchlist]:
        stmt = (
            select(WatchlistModel)
            .where(WatchlistModel.user_id == user_id)
            .order_by(WatchlistModel.created_at.desc())
        )
        result = await self._session.execute(stmt)
        return [
            Watchlist(
                id=m.id,
                user_id=m.user_id,
                name=m.name,
                symbols=m.symbols or [],
                alerts=m.alerts or [],
                created_at=m.created_at,
                updated_at=m.updated_at,
            )
            for m in result.scalars().all()
        ]

    async def update(self, watchlist: Watchlist) -> Watchlist:
        model = await self._session.get(WatchlistModel, watchlist.id)
        if model is None:
            msg = f"Watchlist {watchlist.id} not found"
            raise ValueError(msg)
        model.name = watchlist.name
        model.symbols = watchlist.symbols
        model.alerts = watchlist.alerts
        await self._session.flush()
        return watchlist

    async def delete(self, watchlist_id: str, user_id: str) -> bool:
        stmt = select(WatchlistModel).where(
            WatchlistModel.id == watchlist_id,
            WatchlistModel.user_id == user_id,
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        if model is None:
            return False
        await self._session.delete(model)
        await self._session.flush()
        return True
