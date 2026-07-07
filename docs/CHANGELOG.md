# WealthAI — CHANGELOG

All notable changes are documented here. Format: `[version] date — description`.
**Never delete entries.**

---

## [0.5.0] — 2026-07-07 — Sprint 4: Watchlist Inline Management

### Added
- `market_screen.dart` — 4th **Watchlist** tab with inline symbol management:
  - `_buildWatchlistTab`: loads `watchlistsProvider`, shows all watchlists with empty/error/data states
  - `_WatchlistCard` stateful widget: symbol Chips with ✕ remove, inline Add symbol TextField + FilledButton
  - Create New Watchlist dialog (AlertDialog with name input)
  - All mutations call `WatchlistRepository` methods + `ref.invalidate(watchlistsProvider)` for live sync

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
