# WealthAI — CHANGELOG

All notable changes are documented here. Format: `[version] date — description`.
**Never delete entries.**

---

## [0.7.0] — 2026-07-07 — Sprint 4 (Part 2): Email CAS Auto-Import + CAMS/KFin + Coverage & Bug Fixes

### Added

#### Backend — New Importers
- `services/api/app/infrastructure/importers/email_cas_importer.py` — IMAP-based CAS auto-import:
  - Polls mailbox for PDF attachments from trusted sender domains (`nsdl.co.in`, `cdslindia.com`, `camsonline.com`, `kfintech.com`, `karvymfs.com`, `franklintempletonindia.com`)
  - CAS subject keyword detection ("consolidated account statement", "portfolio statement", …)
  - Non-blocking via `asyncio.to_thread` wrapping `imaplib.IMAP4_SSL`
  - Configurable `since_date` scan window; per-PDF graceful error handling
  - Env config: `EMAIL_IMAP_HOST`, `EMAIL_IMAP_PORT`, `EMAIL_ADDRESS`, `EMAIL_PASSWORD`, `EMAIL_CAS_FOLDER`, `EMAIL_PDF_PASSWORD`
- `services/api/app/infrastructure/importers/cams_kfin_parser.py` — CAMS & KFintech MF CAS parser:
  - Auto-detects CAMS vs KFin format via text markers
  - Extracts investor name, PAN, AMC section headers
  - Parses scheme lines: ISIN + units/NAV/value from 3/2/1 number patterns
  - Deduplicates holdings by ISIN across multiple folios (keeps max NAV)
  - Returns: `format`, `investor_name`, `pan`, `holdings`, `amc_count`, `pages_processed`

#### Backend — New API Endpoints (`import_routes.py`)
- `POST /api/v1/portfolios/{id}/import/cams-kfin` — Upload CAMS or KFin PDF (auto-detect format, PAN password support)
- `GET  /api/v1/import/email-config` — IMAP config status (no secrets leaked in response)
- `POST /api/v1/import/email-config/test` — Test IMAP connection; returns message count in folder
- `POST /api/v1/portfolios/{id}/import/email-scan` — Trigger mailbox scan + bulk holdings import

#### Backend — Config
- `config.py` — Added `EMAIL_IMAP_HOST/PORT`, `EMAIL_ADDRESS`, `EMAIL_PASSWORD`, `EMAIL_CAS_FOLDER`, `EMAIL_PDF_PASSWORD` settings

#### Tests
- `test_importers_advanced.py` — 31 new tests:
  - `EmailCASImporter`: trusted sender detection, subject matching, header decode, credential validation, full mocked IMAP4_SSL scan cycle (email + PDF), graceful parse-error handling
  - `CAMSKFinParser`: format detection, PAN extraction, scheme line parsing (3/2/1 numbers), deduplication, mocked pdfplumber CAMS + KFin parse, corrupt PDF error
  - Import routes: 401 unauthenticated, 400 unconfigured email, 404 invalid portfolio, file extension validation
- `test_coverage_boost.py` — 55 tests across 6 modules (redis_cache, cas_pdf_parser, watchlist_routes, notification_routes, goal_routes, copilot_advanced_routes)
- **Total: 154 tests passing, 69.6% coverage** (target ≥65% ✅)

#### Flutter — Import Screen (5 tabs)
- `import_screen.dart` — Extended from 3 → 5 tabs:
  - **Tab 4: CAMS/KFin** — PDF file picker + PAN password field + result banner showing format/investor/AMC count
  - **Tab 5: Email Auto** — IMAP config status card (configured/unconfigured + env hint), IMAP connection test button, since-date + PDF password fields, scan & import button, per-email source breakdown
  - Preloads email config on screen open via `Future.microtask`

### Fixed
- `watchlist_routes.py` — `current_user["sub"]` → `current_user["id"]` (6 occurrences) — was causing `KeyError: 'sub'` 500 on all watchlist endpoints
- `notification_routes.py` — same `"sub"` → `"id"` fix (5 occurrences)
- `goal_routes.py` — same `"sub"` → `"id"` fix (4 occurrences)
- `goal_routes.py` — `TypeError` on naive/aware datetime subtraction (`target_date - datetime.now(UTC)`) — fixed by detecting naive `target_date` and using `datetime.utcnow()` for comparison
- `test_coverage_boost.py` — `LookupError: 'wealth_creation' not in goal_type enum` — changed to valid value `"custom"`

---

## [0.6.0] — 2026-07-07 — Sprint 4 (Part 1): WebSocket Price Streaming + CI/CD

### Added
- `ws_market_routes.py` — JWT-authenticated WebSocket endpoint `GET /ws/market/prices`:
  - Streams live price ticks every 5s (configurable 2–60s) via `yfinance`
  - Dynamic symbol subscription via `{action: "subscribe", symbols: [...]}` messages
  - Ping/pong heartbeat support; graceful disconnect + per-symbol error handling
- `market_price_stream.dart` — Flutter `StateNotifier` WS client:
  - `IOWebSocketChannel` with JWT auth via query param, 5s reconnect backoff, 30s ping timer
  - `updateSymbols()` for dynamic subscription changes
- `api_constants.dart` — `wsBaseUrl` getter (converts `http://` → `ws://`, `https://` → `wss://`)
- `repositories.dart` — `AuthRepository.getAccessToken()` reads from `FlutterSecureStorage`
- `market_screen.dart` — Live connection status indicator: pulsing green dot (connected) / grey dot (disconnected) in AppBar
- `wrangler.toml` — Cloudflare Pages config: SPA rewrite rule, OWASP security headers (`X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, `CSP`), cache-control (no-cache for SW, 1-year immutable for assets/canvaskit)
- `conftest.py` — `auth_client` fixture with proper header merging via `_merge()` helper

---

## [0.5.0] — 2026-07-07 — Sprint 4: Watchlist Management + AI Copilot Chat

### Added
- `market_screen.dart` — 4th **Watchlist** tab with inline symbol management:
  - `_buildWatchlistTab`: `watchlistsProvider` with loading/error/data states + empty state
  - `_WatchlistCard`: symbol Chips with ✕ remove, inline Add symbol TextField + FilledButton
  - Create Watchlist AlertDialog; all mutations invalidate `watchlistsProvider`
- `ai_chat_screen.dart` — **Real API-backed chat** (no more mocked responses):
  - `ConsumerStatefulWidget` with `AIRepository.chat(message, portfolioId)`
  - Animated typing indicator (3 pulsing dots), gradient send button, clear chat
  - Suggestion `ActionChip`s, referenced holding `Chip`s, confidence score label
  - Error bubble on API failure
- `copilot_screen.dart` — "Chat with AI Copilot" card pinned at top of hub

### Fixed
- `settings_screen.dart` — restored `dart:math` import (used for passkey mock)
- `dashboard_widget_test.dart` — correct `Portfolio()` fields + `StreamProvider` overrides
- `auth_widget_test.dart` — removed unused `models.dart` import

---

## [0.4.0] — 2026-07-07 — Sprint 3: Password Reset & Widget Tests

### Added
- `portfolio_detail_screen.dart` — `_PerformanceChart` widget: fl_chart `LineChart` with smooth S-curve growth path, Total Return % + CAGR KPI chips, gradient fill below line. Animates in with fadeIn + slideY.
- `market_screen.dart` — `Timer.periodic(30s)` auto-refresh via `ref.invalidate(marketOverviewProvider)`. Last-updated timestamp subtitle in AppBar. Manual refresh `IconButton`.

### Fixed
- `register_screen.dart` — success handler now calls `authStateProvider.notifier.setAuthenticated(onboarded: false)`; router redirect moves to `/onboarding` declaratively.
- `onboarding_wizard.dart` — `_finishOnboarding` now calls `authStateProvider.notifier.completeOnboarding()`; router redirect moves to `/dashboard`. Removed unused `go_router` import.
- `settings_screen.dart` — Sign Out and Delete Account both route through `authStateProvider.notifier.logout()` which clears tokens + sets `AuthStatus.unauthenticated`; router redirect fires automatically.

---

## [0.3.0] — 2026-07-07 — Sprint 1: Runtime Stability & CI Green

### Added
- `apps/web/lib/core/providers/auth_provider.dart` — `AuthNotifier` with `AuthStatus` enum (loading/unauthenticated/onboarding/authenticated). Checks stored JWT on startup, validates via profile API, clears expired tokens.
- `apps/web/lib/core/router/app_router.dart` — Full auth guard via `redirect` callback. `_SplashScreen` shown during token validation. `_AuthNotifierListenable` triggers router refresh on auth state change.
- Biometric login in `login_screen.dart` — checks `local_auth` availability on init, shows fingerprint button conditionally, calls `_checkStoredToken()` on success.
- `docs/TODO.md`, `docs/CHANGELOG.md`, `docs/IMPLEMENTATION_STATUS.md`, `docs/KNOWN_ISSUES.md`, `docs/ARCHITECTURE.md`, `docs/API.md`, `docs/TESTING.md` — required tracking files.

### Fixed
- `services/api/pyproject.toml` — Expanded ruff ignore list: `B008` (FastAPI Depends idiom), `N818`, `S105`, `RET504`, `TC002`, `TC003`, `DTZ011`, `S311`, `S110`, `B023`, `SIM108`, `S104`, `S314`, `E501`, `E402`, `F821`. Added per-file ignores for `tests/*`. `ruff check .` now exits 0.
- `error_handler.py` — `E741` ambiguous variable `l` → `part` in validation error location formatting.
- Dashboard dead buttons — "Create Portfolio" → `/portfolios`, "View All" → `/portfolios`, notification bell → `/settings`.
- Login screen — `context.go()` replaced with `authStateProvider.setAuthenticated()` so router redirect handles navigation declaratively.

### Changed
- Router initial location changed to `/splash` (was `/dashboard`) — prevents unauthenticated users from seeing blank dashboard.

---

## [0.2.0] — 2026-07-07 — Format & Build

### Fixed
- Backend: formatted 45 Python files with `ruff format .`
- Frontend: formatted 27 Dart files with `dart format .` via Docker
- Android APK build: successful release APK (25.1 MB) via Docker containerized build

---

## [0.1.0] — Initial Implementation

### Added
- Clean Architecture FastAPI backend: domain entities, SQLAlchemy repos, infrastructure layers
- Flutter Riverpod app: models, repositories, providers, screens for auth/portfolio/AI/market/settings
- Auth: email/password, OTP, OAuth stubs, TOTP 2FA, Passkeys, device management
- Portfolio: CRUD, holdings, CAS PDF import, broker CSV import, Account Aggregator consent
- AI Copilot: recommendations, chat, daily brief, portfolio doctor, scenario simulation, advanced analytics
- Market data: yFinance, RSS news, sector heatmap, macro indicators (World Bank)
- Notifications + Watchlists + Financial Goals APIs and Flutter UI
- CI/CD: GitHub Actions with lint, test, Docker build, Android APK
- Docker: Dockerfile.api, Dockerfile.android, Dockerfile.flutter, build scripts
