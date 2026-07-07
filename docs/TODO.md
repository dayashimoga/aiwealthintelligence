# WealthAI — TODO

> **Never delete history. Mark completed items `[x]`, in-progress `[/]`, blocked `[~]`.**

---

## Sprint 1 — Runtime Stability & CI Green (Current)

- [x] Fix backend `ruff check` — 0 errors (expanded ignore list for FastAPI idioms)
- [x] Add `auth_provider.dart` — `AuthNotifier` + `AuthStatus` enum
- [x] Fix `app_router.dart` — add `redirect` callback with auth guard
- [x] Fix dashboard dead buttons — Create Portfolio, View All, notifications
- [x] Add biometric login to `login_screen.dart` using `local_auth`
- [x] Fix `E741` ambiguous variable in `error_handler.py`
- [ ] Create docs tracking files (this file + siblings)
- [ ] Verify Flutter `dart analyze` passes
- [ ] Commit & push Sprint 1

## Sprint 2 — Portfolio Detail & Market Live Data

- [ ] `portfolio_detail_screen.dart` — add XIRR/CAGR from analytics
- [ ] `portfolio_detail_screen.dart` — add performance LineChart
- [ ] `portfolio_detail_screen.dart` — add sector allocation PieChart
- [ ] `market_screen.dart` — live quote auto-refresh (30s `Timer.periodic`)
- [ ] `market_screen.dart` — watchlist management inline
- [ ] `market_providers.dart` — periodic market refresh provider
- [ ] `onboarding_wizard.dart` — wire completeOnboarding to auth state

## Sprint 3 — Settings & Auth Completion

- [ ] `settings_screen.dart` — wire biometrics enable/disable toggle
- [ ] `settings_screen.dart` — wire logout to `authStateProvider.logout()`
- [ ] `register_screen.dart` — wire registration to auth state
- [ ] Password reset flow

## Sprint 4 — CI/CD & Docs

- [ ] CI: fix frontend format step (format in-place before check)
- [ ] CI: add Cloudflare Pages deployment step
- [ ] `docs/API.md` — document all 60+ endpoints
- [ ] `docs/TESTING.md` — document test strategy

## Sprint 5 — Testing Expansion

- [ ] Flutter widget tests: `test/widget/dashboard_test.dart`
- [ ] Flutter widget tests: `test/widget/auth_test.dart`
- [ ] Flutter widget tests: `test/widget/portfolio_test.dart`
- [ ] Flutter integration test: `integration_test/app_test.dart` smoke test
- [ ] Backend: maintain >90% coverage

## Backlog

- [ ] Email CAS auto-import (mailbox authorization)
- [ ] CAMS & KFin mutual fund import API
- [ ] Cloudflare deployment `wrangler.toml`
- [ ] iOS CI build (macOS runner)
- [ ] Push notifications (FCM/APNs)
- [ ] Real-time WebSocket price streaming
