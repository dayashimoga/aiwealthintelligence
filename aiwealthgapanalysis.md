# AI Wealth Intelligence — Gap Analysis & Implementation Plan

## Executive Summary

The platform has a **solid architectural skeleton** (Clean Architecture, DDD patterns, proper abstractions) but is at **~15% production readiness**. The backend has real database models, working auth, and CRUD scaffolding. The Flutter frontend has good routing, theming, and component structure. However, nearly every data pathway returns mock/static data, there are no market data integrations, no portfolio import capabilities, no real analytics calculations, and the AI copilot operates without real data context.

This plan transforms the platform into production quality through **6 implementation phases**, prioritising mock-data elimination and core functionality before new features.

---

## Gap Analysis

### Backend (FastAPI) — What Exists vs What's Missing

| Component | Status | Details |
|---|---|---|
| **FastAPI app factory** | ✅ Working | Lifespan, CORS, middleware wired |
| **Configuration** | ✅ Working | Pydantic settings, env file support |
| **Auth (register/login/refresh/profile)** | ✅ Working | JWT, bcrypt, password validation, tests pass |
| **Portfolio CRUD** | ✅ Working | Create, list, get, update, delete — all functional |
| **Holding CRUD** | ✅ Working | CRUD + basic CSV import |
| **SQLAlchemy models & mappers** | ✅ Working | Full ORM models with relationships |
| **Domain entities** | ✅ Good | Rich domain model with value objects |
| **Repository interfaces** | ✅ Good | Clean abstractions, SQLAlchemy implementations |
| **Event bus** | ⚠️ Skeleton | In-memory bus defined but no handlers subscribed |
| **Error handling** | ✅ Working | Custom exceptions with HTTP codes |
| **Security (headers, rate limiting)** | ✅ Partial | SecurityHeadersMiddleware, slowapi rate limiter |
| **Structured logging** | ✅ Working | structlog configured |
| **AI provider abstraction** | ✅ Working | OpenAI/Groq/Ollama with strategy pattern |
| **AI recommendations** | ⚠️ Basic | Prompts defined but no real market data fed to AI |
| **AI chat** | ⚠️ Basic | Portfolio summary fed but no market context |
| **Market data routes** | ❌ **STUB** | Returns empty arrays or zero-value sector data |
| **Portfolio analytics** | ⚠️ Basic | Simple total/gain/loss only; no XIRR, CAGR, Sharpe |
| **CAS PDF parsing** | ❌ Missing | Not implemented |
| **Email CAS import** | ❌ Missing | Not implemented |
| **Broker integrations** | ❌ Missing | Not implemented |
| **CAMS/KFin import** | ❌ Missing | Not implemented |
| **Live market data** | ❌ Missing | No yfinance, no market data service |
| **Background jobs / scheduler** | ❌ Missing | No Celery/APScheduler/ARQ |
| **Redis cache layer** | ❌ Missing | Config exists but no cache repository impl |
| **Notification service** | ❌ Missing | |
| **Audit logging** | ⚠️ Table only | AuditLogModel exists, no write logic |
| **Exception handler middleware** | ❌ Missing | AppException not caught → raw 500s |
| **Alembic migrations** | ⚠️ Skeleton | alembic.ini exists, no migration files |
| **Database init (table creation)** | ❌ Missing | No `create_all` on startup for dev mode |
| **Tests** | ⚠️ Partial | 12 auth/health tests, 0 portfolio tests, 0 AI tests |

### Frontend (Flutter) — What Exists vs What's Missing

| Component | Status | Details |
|---|---|---|
| **Material 3 theming** | ✅ Good | Dark/light, gradients, colors |
| **App router (GoRouter)** | ✅ Working | Shell scaffold, nested routes |
| **State management (Riverpod)** | ⚠️ Basic | Providers exist but screens don't use them |
| **API client (Dio)** | ✅ Working | Auth interceptor, token refresh |
| **Repositories** | ✅ Working | Auth, Portfolio, Holding, AI repositories |
| **Data models** | ✅ Working | Match API response shapes |
| **Dashboard** | ❌ **100% MOCK** | Hardcoded ₹24,50,000, static pie chart, static holdings |
| **Portfolio list** | ⚠️ UI only | Screen exists but unclear if it calls API |
| **Portfolio detail** | ⚠️ UI only | Similar |
| **AI chat** | ⚠️ UI only | Screen exists, unclear connection to API |
| **Market screen** | ⚠️ UI only | Screen exists |
| **Settings** | ⚠️ UI only | Screen exists |
| **Skeleton loaders** | ❌ Missing | |
| **Error states** | ❌ Missing | No error recovery UI |
| **Empty states** | ❌ Missing | |
| **Offline mode** | ❌ Missing | Hive initialised but unused |
| **PWA support** | ⚠️ Basic | manifest.json exists, no service worker |
| **CAS upload flow** | ❌ Missing | |
| **Import wizard** | ❌ Missing | |
| **Real-time price updates** | ❌ Missing | |
| **Advanced charts** | ❌ Missing | Only basic pie chart |
| **Responsive layout** | ⚠️ Partial | ResponsiveGrid exists, not tested for desktop |
| **Accessibility** | ❌ Missing | No semantics, no screen reader labels |

### CI/CD & DevOps

| Component | Status | Details |
|---|---|---|
| **CI pipeline** | ✅ Working | Backend + Frontend + Security + Docker |
| **Test coverage enforcement** | ✅ Set up | `--cov-fail-under=90` (but won't pass currently) |
| **Cloudflare Pages deployment** | ❌ Missing | deploy.yml exists but empty/stub |
| **Android build** | ❌ Missing | Not in CI |
| **iOS build** | ❌ Missing | Not in CI |
| **SBOM generation** | ⚠️ Partial | Configured but may fail |
| **Secret scanning** | ⚠️ Partial | Via Trivy only |
| **Preview deployments** | ❌ Missing | |

---

## Proposed Changes — Phased Implementation

> [!IMPORTANT]
> Each phase produces a **deployable, tested, non-regressed** state. Phases are ordered by dependency: foundational fixes first, then data pipelines, then AI, then new features, then polish.

---

### Phase 1: Backend Foundation Fixes (Critical)
*Goal: Make the existing backend actually run correctly and pass CI*

#### Backend Core Fixes

##### [MODIFY] [main.py](file:///h:/investment/services/api/app/main.py)
- Add global exception handler for `AppException` → proper JSON error responses
- Add startup database table creation for development mode
- Add request ID middleware for tracing

##### [MODIFY] [session.py](file:///h:/investment/services/api/app/infrastructure/database/session.py)
- Add `create_all_tables()` utility for dev/test startup
- Fix engine reference (currently always `None`)

##### [NEW] `services/api/app/presentation/middleware/error_handler.py`
- FastAPI exception handler that catches `AppException` subclasses
- Returns structured `ErrorResponse` JSON with correct status codes

##### [MODIFY] [market_routes.py](file:///h:/investment/services/api/app/presentation/api/v1/market_routes.py)
- Replace empty stubs with real market data service calls

##### [NEW] `services/api/alembic/versions/001_initial_schema.py`
- Generate initial Alembic migration from existing models

##### [MODIFY] [conftest.py](file:///h:/investment/services/api/tests/conftest.py)
- Fix `event_loop` deprecation warning
- Ensure clean test isolation

##### [NEW] `services/api/tests/test_portfolio.py` (expand existing)
- Portfolio CRUD tests, CSV import tests, analytics tests

---

### Phase 2: Market Data Pipeline
*Goal: Replace all zeros/stubs with real market data*

##### [NEW] `services/api/app/infrastructure/market/market_data_service.py`
- Abstract `MarketDataProvider` interface
- `YFinanceProvider` implementation using `yfinance` for NSE/BSE stocks and mutual funds
- Batch price fetching, caching, rate limit aware
- Company fundamentals, financial statements, valuation ratios

##### [NEW] `services/api/app/infrastructure/market/price_cache.py`
- In-memory + optional Redis price cache
- 1-minute TTL for live prices, 1-hour for fundamentals

##### [NEW] `services/api/app/infrastructure/market/index_data.py`
- Nifty 50, Sensex, sector indices
- Market breadth calculation

##### [MODIFY] [market_routes.py](file:///h:/investment/services/api/app/presentation/api/v1/market_routes.py)
- Wire market data service into routes
- Real sector performance, real news

##### [NEW] `services/api/app/infrastructure/market/news_fetcher.py`
- RSS/API-based news fetching (Google Finance RSS, MoneyControl RSS)
- AI-powered summary and sentiment

##### [MODIFY] [portfolio_routes.py](file:///h:/investment/services/api/app/presentation/api/v1/portfolio_routes.py)
- Auto-fetch `current_price` when creating/listing holdings
- Wire real XIRR calculation using `pyxirr`

##### [NEW] `services/api/app/infrastructure/scheduler/`
- APScheduler-based background job runner
- Price refresh job (every 1 min during market hours)
- Portfolio value sync job (every 5 mins)
- News fetch job (every 15 mins)

##### [MODIFY] [pyproject.toml](file:///h:/investment/services/api/pyproject.toml)
- Add `yfinance`, `apscheduler`, `beautifulsoup4` dependencies

---

### Phase 3: Smart Portfolio Imports
*Goal: Enable real portfolio data ingestion*

##### [NEW] `services/api/app/infrastructure/importers/cas_pdf_parser.py`
- NSDL CAS PDF parser using `pdfplumber`/`tabula-py`
- Extract: ISIN, scheme name, units, NAV, valuation, transaction history
- CDSL CAS PDF parser (different format)
- Validate and map ISIN to symbols

##### [NEW] `services/api/app/infrastructure/importers/csv_importer.py`
- Enhanced CSV importer with flexible column mapping
- Auto-detect common broker CSV formats (Zerodha, Groww, etc.)
- Smart column matching heuristics

##### [NEW] `services/api/app/infrastructure/importers/broker_adapters/`
- `base_adapter.py` — Abstract broker adapter
- `zerodha_adapter.py` — Kite API integration (via user-provided API key)
- `groww_adapter.py` — Groww data export parsing
- Future: Upstox, Angel, ICICI, Kotak via their APIs

##### [NEW] `services/api/app/infrastructure/importers/mf_importers/`
- `cams_parser.py` — CAMS CAS statement parser
- `kfintech_parser.py` — KFintech CAS statement parser

##### [NEW] `services/api/app/presentation/api/v1/import_routes.py`
- `POST /import/cas-pdf` — Upload and parse CAS PDF
- `POST /import/csv` — Enhanced CSV import
- `POST /import/broker/{broker_name}` — Broker-specific import
- `GET /import/status/{import_id}` — Import progress tracking

##### [MODIFY] [entities.py](file:///h:/investment/services/api/app/domain/entities.py)
- Add `PortfolioImportSource` values: `CAMS_CAS`, `KFINTECH_CAS`, `EMAIL_CAS`
- Add `ImportJob` entity for tracking async imports
- Add `ACCUMULATE` to `RecommendationAction`

##### [MODIFY] [models.py](file:///h:/investment/services/api/app/infrastructure/database/models.py)
- Add `ImportJobModel` table
- Add `SyncScheduleModel` for auto-sync configuration

##### [MODIFY] [pyproject.toml](file:///h:/investment/services/api/pyproject.toml)
- Add `pdfplumber`, `tabula-py`, `openpyxl`

---

### Phase 4: Real Analytics Engine & AI Copilot
*Goal: Replace all computed mock values with real calculations powered by real data*

##### [NEW] `services/api/app/infrastructure/analytics/portfolio_analytics_engine.py`
- Implements `AnalyticsEngine` interface
- Real XIRR calculation using `pyxirr` from transaction history
- CAGR from first investment date
- Sharpe ratio, Sortino ratio, max drawdown
- Dividend income aggregation from transaction records
- Asset/sector/market-cap/geo allocation from live data
- Mutual fund overlap detection (compare underlying holdings)
- Risk score based on volatility, beta, concentration
- Diversification score (improved HHI + correlation-based)
- Tax estimation (STCG/LTCG based on holding period + Indian tax rules)
- Benchmark comparison (vs Nifty 50, Sensex)

##### [MODIFY] [portfolio_routes.py](file:///h:/investment/services/api/app/presentation/api/v1/portfolio_routes.py)
- Wire analytics engine into `/analytics` endpoint
- Add `/analytics/tax-estimate` endpoint
- Add `/analytics/overlap` endpoint

##### [MODIFY] [ai_provider.py](file:///h:/investment/services/api/app/infrastructure/ai/ai_provider.py)
- Enrich recommendation prompts with real market data
- Feed live price, 52-week range, P/E, sector performance, news sentiment
- Add structured output parsing with Pydantic validation
- Add RAG context from recent news and fundamentals

##### [NEW] `services/api/app/infrastructure/ai/ai_copilot.py`
- Portfolio Doctor: Analyse portfolio health issues
- Scenario Simulator: "What if I sell X and buy Y?"
- Opportunity Radar: Screen market for opportunities matching user profile
- AI Rebalancer: Suggest optimal rebalancing
- Tax Optimizer: STCG/LTCG harvest suggestions
- Behavioural Bias Detector: Detect concentration, recency bias, etc.
- Daily AI Brief generator
- Explainability Graph generator

##### [NEW] `services/api/app/presentation/api/v1/copilot_routes.py`
- `GET /copilot/brief` — Daily AI brief
- `POST /copilot/scenario` — Scenario simulation
- `GET /copilot/opportunities` — AI-detected opportunities
- `POST /copilot/rebalance` — Rebalancing suggestions
- `GET /copilot/tax-optimizer` — Tax loss harvesting
- `GET /copilot/portfolio-doctor` — Portfolio health diagnosis
- `GET /copilot/bias-detector` — Behavioural bias analysis

---

### Phase 5: Flutter Frontend — Real Data & Premium UX
*Goal: Connect every UI element to real API data*

##### [MODIFY] [dashboard_screen.dart](file:///h:/investment/apps/web/lib/features/dashboard/screens/dashboard_screen.dart)
- Replace ALL hardcoded values with Riverpod providers
- Fetch real portfolio summary, analytics, AI insights from API
- Add skeleton loaders during fetch
- Add error states with retry
- Add empty state for new users (onboarding)
- Make pie chart data-driven from real allocations

##### [NEW] `apps/web/lib/features/import/` — Import wizard
- `import_screen.dart` — Hub for all import methods
- `cas_upload_screen.dart` — CAS PDF upload with drag-and-drop
- `csv_upload_screen.dart` — CSV upload with column mapping
- `broker_connect_screen.dart` — Broker API key setup
- `import_progress_screen.dart` — Live import progress

##### [MODIFY] All feature screens
- Connect to real API providers
- Add loading/error/empty states throughout
- Use `AsyncValue` from Riverpod properly

##### [NEW] `apps/web/lib/features/copilot/` — AI Copilot screens
- `copilot_screen.dart` — AI insights hub
- `scenario_screen.dart` — What-if simulator
- `portfolio_doctor_screen.dart` — Health diagnosis view
- `daily_brief_screen.dart` — AI daily brief

##### [NEW] `apps/web/lib/core/widgets/`
- `skeleton_loader.dart` — Shimmer loading placeholders
- `error_widget.dart` — Error state with retry
- `empty_state.dart` — Empty state with call-to-action
- `price_ticker.dart` — Live price display with colour change

##### [MODIFY] [app_theme.dart](file:///h:/investment/apps/web/lib/core/theme/app_theme.dart)
- Add typography scale using Google Fonts (Inter)
- Add spacing system constants
- Enhance animation curves

##### [MODIFY] [pubspec.yaml](file:///h:/investment/apps/web/pubspec.yaml)
- Add `file_picker` for CAS/CSV upload
- Add `syncfusion_flutter_charts` or enhance `fl_chart` usage

---

### Phase 6: CI/CD, Security, Testing & Deployment
*Goal: Production-grade pipeline, >90% coverage, Cloudflare deployment*

##### [MODIFY] [ci.yml](file:///h:/.github/workflows/ci.yml)
- Remove `continue-on-error` from critical steps
- Add dependency audit step
- Add secret scanning step
- Fix coverage to actually enforce 90%

##### [MODIFY] [deploy.yml](file:///h:/.github/workflows/deploy.yml)
- Cloudflare Pages deployment for Flutter web
- Preview deployments for PRs
- Android APK/AAB build
- Release artifact publishing
- Release notes generation

##### [NEW] Backend tests to reach >90% coverage
- Portfolio CRUD tests (expand test_portfolio.py)
- Market data service tests
- Import parser tests (CAS PDF, CSV)
- Analytics engine tests
- AI copilot tests (mocked AI provider)
- Middleware tests

##### [NEW] Flutter widget tests
- Dashboard screen tests
- Import flow tests
- Portfolio detail tests

##### [MODIFY] Security hardening
- Add CSRF protection for non-API routes
- Add request size limits
- Add SQL injection protection audit
- Add dependency vulnerability scanning in CI
- Implement proper token revocation list

---

## Open Questions

> [!IMPORTANT]
> **AI API Key**: Which AI provider will you use in production? The codebase supports OpenAI, Groq, and Ollama. For Groq (free tier available), we need a Groq API key. For OpenAI, we need an OpenAI key. This affects AI copilot quality.

> [!IMPORTANT]
> **Cloudflare Pages**: Do you already have a Cloudflare account set up? The deploy workflow needs `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` secrets configured in the GitHub repository.

> [!WARNING]
> **Broker API Keys**: Zerodha Kite API requires a paid subscription (₹2000/month). For Phase 3 broker integration, should we prioritise: (a) Zerodha Kite API, (b) Data export file parsing (free, no API needed), or (c) Both?

> [!NOTE]
> **Scope Management**: The full scope described is enormous (~6-12 months of a full team). This plan prioritises the most impactful items first. Phases 1-3 make the app usable with real data. Phases 4-5 add intelligence. Phase 6 makes it production-deployable. I recommend we execute Phase 1 first and iterate.

---

## Verification Plan

### Automated Tests
- `pytest --cov=app --cov-report=term-missing --cov-fail-under=90 -v` (backend)
- `flutter test --coverage` (frontend)
- `flutter analyze` (static analysis)
- `ruff check . && ruff format --check .` (backend lint)

### Manual Verification
- Register → Import CAS PDF → See real portfolio values on dashboard
- Check that all dashboard numbers match real market prices
- Verify AI recommendations reference real fundamentals
- Test responsive layout on mobile, tablet, desktop viewports
- Verify dark/light theme switching
- Test offline behaviour (cached data displayed)

### Integration Tests
- Full auth flow: register → login → refresh → profile
- Full portfolio flow: create → import holdings → get analytics → get AI recommendation
- Market data: verify live prices match external sources
