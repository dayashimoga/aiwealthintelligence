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

## Sprint 3 — Flutter Tests & CI Polish

- [ ] Flutter widget test: `test/widget/auth_test.dart` — login, register, biometrics
- [ ] Flutter widget test: `test/widget/dashboard_test.dart` — navigation, portfolio load
- [ ] Flutter widget test: `test/widget/portfolio_detail_test.dart` — chart renders, holdings list
- [ ] Flutter integration test: `integration_test/app_test.dart` — smoke test full auth flow
- [ ] CI: Cloudflare Pages deployment step (frontend)
- [ ] Password reset flow (forgot password screen + `/auth/reset-password` API)

## Sprint 4 — Advanced Features

- [ ] `market_screen.dart` — watchlist management inline (add/remove from market quotes)
- [ ] Real-time WebSocket price streaming (replace 30s poll with WS subscription)
- [ ] `copilot_screen.dart` — AI Copilot chat UI with streaming markdown responses
- [ ] Email CAS auto-import (mailbox authorization + PDF parser trigger)
- [ ] CAMS & KFin mutual fund import API integration

## Backlog

- [ ] Cloudflare deployment `wrangler.toml`
- [ ] iOS CI build (macOS runner)
- [ ] Push notifications (FCM/APNs)
- [ ] Backend: maintain ≥65% test coverage (currently 69%)
- [ ] `docs/API.md` — verify all 60+ endpoints documented
