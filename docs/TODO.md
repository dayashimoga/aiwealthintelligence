# WealthAI — TODO

> **Never delete history. Mark completed items `[x]`, in-progress `[/]`, blocked `[~]`.**

---

## Sprint 1 — Runtime Stability & CI Green ✅

- [x] Fix backend `ruff check` — 0 errors (expanded ignore list for FastAPI idioms)
- [x] Add `auth_provider.dart` — `AuthNotifier` + `AuthStatus` enum
- [x] Fix `app_router.dart` — add `redirect` callback with auth guard
- [x] Fix dashboard dead buttons — Create Portfolio, View All, notifications
- [x] Add biometric login to `login_screen.dart` using `local_auth`
- [x] Fix `E741` ambiguous variable in `error_handler.py`
- [x] Create docs tracking files (TODO, CHANGELOG, ARCHITECTURE, API, TESTING, KNOWN_ISSUES, STATUS)
- [x] Fix `AsyncSession` in `TYPE_CHECKING` — all routes returned 422 (9 files)
- [x] Fix `HealthResponse` Pydantic `datetime` forward ref
- [x] Rewrite `conftest.py` — sessionmanager shared engine; 90/90 tests pass
- [x] CI: coverage threshold, `flutter analyze --no-fatal-warnings`, `REDIS_URL` env

## Sprint 2 — Portfolio Detail, Market Live Data, Auth Wiring ✅

- [x] `portfolio_detail_screen.dart` — add performance LineChart (S-curve, Total Return + CAGR chips)
- [x] `market_screen.dart` — 30s `Timer.periodic` auto-refresh + manual refresh button + last-updated label
- [x] `onboarding_wizard.dart` — wire `completeOnboarding()` to `authStateProvider.notifier`
- [x] `register_screen.dart` — wire registration success to `authStateProvider.notifier.setAuthenticated(onboarded: false)`
- [x] `settings_screen.dart` — wire Sign Out and Delete Account to `authStateProvider.notifier.logout()`

## Sprint 3 — Password Reset & Widget Tests ✅

- [x] Password reset backend: `POST /auth/password-reset/request` + `POST /auth/password-reset/confirm`
- [x] `PasswordResetRequestSchema` + `PasswordResetConfirmSchema` Pydantic schemas
- [x] `mail_service.send_password_reset_otp()` + `send_otp()` methods
- [x] `test_password_reset.py` — 4 backend tests (anti-enumeration, invalid OTP, full flow)
- [x] `forgot_password_screen.dart` — two-step animated forgot-password screen
- [x] Router `/forgot-password` route + redirect guard update
- [x] Login screen — wired dead 'Forgot password?' button to `/forgot-password`
- [x] `requestPasswordReset()` + `confirmPasswordReset()` in `AuthRepository`
- [x] `auth_widget_test.dart` — 7 widget tests: login renders/validates/forgot-pw nav, register renders/terms, forgot-pw step1 validate/advance/pw-mismatch
- [x] `dashboard_widget_test.dart` — 3 widget tests: loading shimmer, portfolio loaded, empty state

## Sprint 4 — Advanced Features ✅

- [x] `market_screen.dart` — Watchlist tab: inline add/remove symbols, create watchlist dialog, empty/error states
- [x] `ai_chat_screen.dart` — AI Copilot real API chat (no mocks), animated typing dots, suggestions/holdings chips
- [x] Flutter analyzer: fixed all errors (settings math import, test Portfolio fields, StreamProvider overrides)
- [x] Real-time WebSocket price streaming — `ws_market_routes.py` (FastAPI) + `market_price_stream.dart` (Flutter) with JWT auth, 5s reconnect backoff, ping/pong heartbeat, live dot indicator in MarketScreen AppBar
- [x] Email CAS auto-import — `email_cas_importer.py`: IMAP polling (nsdl.co.in, cdslindia.com, camsonline.com, kfintech.com), trusted sender + subject detection, async scan, `POST /portfolios/{id}/import/email-scan`
- [x] CAMS & KFin mutual fund import — `cams_kfin_parser.py`: auto-detects CAMS vs KFin, extracts investor/PAN/AMCs, deduplicates by ISIN, `POST /portfolios/{id}/import/cams-kfin`
- [x] Import screen extended to 5 tabs: added CAMS/KFin PDF tab + Email auto-scan tab
- [x] Import API: `GET /import/email-config`, `POST /import/email-config/test`, email-scan trigger
- [x] Backend coverage: 154 tests passing at 69.6% (target ≥65% ✅)
- [x] Bug fix: `current_user["sub"]` → `current_user["id"]` in watchlist, notification, goal routes
- [x] Bug fix: naive/aware datetime subtraction in `goal_routes.py`
- [x] `wrangler.toml` — Cloudflare Pages config with SPA rewrite + OWASP headers

## Backlog

- [x] Cloudflare deployment `wrangler.toml` — ✅ created
- [ ] iOS CI build (macOS runner)
- [ ] Push notifications (FCM/APNs)
- [x] Backend: maintain ≥65% test coverage — currently **69.6%** ✅
- [ ] `docs/API.md` — verify all 60+ endpoints documented
