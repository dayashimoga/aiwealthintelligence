# WealthAI — Known Issues

> **Never delete entries. Mark resolved issues with `[RESOLVED vX.Y.Z]`.**

---

## Open Issues

### [KI-001] Google/Apple OAuth — Not Wired (MEDIUM)
- **Symptom**: Google/Apple buttons on login screen do nothing
- **Root cause**: Backend has `/auth/oauth-login` endpoint but no Google/Apple SDK integrated in Flutter
- **Workaround**: Use email/password or OTP login
- **Fix plan**: Integrate `google_sign_in` and `sign_in_with_apple` Flutter packages, wire to backend OAuth endpoint

### [KI-002] Push Notifications — Not Implemented (LOW)
- **Symptom**: No price/portfolio/news push alerts on device
- **Root cause**: FCM/APNs not configured; `google-services.json` and APNs cert not present
- **Fix plan**: Add `firebase_messaging` Flutter package, configure Firebase project, add secrets to CI

### [KI-003] Cloudflare Web Deployment — Not Configured (LOW)
- **Symptom**: No automated web deployment to Cloudflare Pages
- **Root cause**: No `wrangler.toml`, no CI step, no Cloudflare secrets
- **Fix plan**: Add Cloudflare Pages deploy step to `ci.yml`, add `CLOUDFLARE_API_TOKEN`/`CLOUDFLARE_ACCOUNT_ID` secrets

### [KI-004] Portfolio Detail — No Performance Chart (MEDIUM)
- **Symptom**: Portfolio detail screen shows holdings list but no XIRR/CAGR or performance chart
- **Root cause**: Analytics data is fetched but not rendered in detail screen
- **Fix plan**: Add LineChart widget in `portfolio_detail_screen.dart` using `fl_chart`

### [KI-005] Market Screen — No Live Quote Auto-Refresh (LOW)
- **Symptom**: Market prices require manual pull-to-refresh
- **Root cause**: No `Timer.periodic` auto-refresh in market screen
- **Fix plan**: Add 30s auto-refresh via `Timer.periodic` in `market_screen.dart`

### [KI-006] Biometric Login — `_checkStoredToken` is Private (MEDIUM)
- **Symptom**: Cannot call `_checkStoredToken()` from outside `AuthNotifier`
- **Root cause**: Method is private; login screen calls it directly via a workaround
- **Fix plan**: Expose a public `revalidate()` method on `AuthNotifier`

### [KI-007] iOS Build — Not in CI (LOW)
- **Symptom**: No iOS build artifact in CI pipeline
- **Root cause**: iOS requires macOS runner (cost) and codesigning
- **Fix plan**: Add macOS runner job in `ci.yml` with `--no-codesign` flag

---

## Resolved Issues

### [RESOLVED 0.3.0] Router opens unauthenticated users on `/dashboard`
- **Was**: `initialLocation: '/dashboard'`, no redirect callback
- **Fix**: Added `_SplashScreen`, `AuthNotifier`, router `redirect` callback

### [RESOLVED 0.3.0] `ruff check .` failing with 116 errors in CI
- **Was**: FastAPI `Depends()` pattern flagged as `B008`, plus `N818`, `E741`, etc.
- **Fix**: Extended `ignore` list and added `per-file-ignores` for tests

### [RESOLVED 0.3.0] Dashboard "Create Portfolio" and "View All" buttons dead
- **Was**: `onPressed: () {}`
- **Fix**: Wired to `context.go('/portfolios')`
