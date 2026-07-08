# WealthAI — Test Report

Last updated: **2026-07-08**
Sprint: **0.8.0**

---

## Backend Test Results

### Summary

| Metric | Value |
|--------|-------|
| Total Tests | 224 |
| Passed | **224** |
| Failed | **0** |
| Skipped | 0 |
| Duration | 58s |
| Coverage | **75.16%** |
| Coverage Target | ≥65% |
| Status | ✅ ALL PASSING |

### Coverage Breakdown by Module

| Date | Backend Tests | Coverage | Flutter Tests |
|------|--------------|----------|--------------|
| 2026-07-07 | 154 | 69.6% | Widget tests |
| 2026-07-08 | **198** | **75.1%** | Widget tests |
| `app/presentation/api/v1/auth_routes.py` | ~85% | auth, OTP, 2FA, OAuth, devices |
| `app/presentation/api/v1/portfolio_routes.py` | ~75% | CRUD, analytics, holdings |
| `app/presentation/api/v1/market_routes.py` | ~92% | news, sectors, overview |
| `app/presentation/api/v1/copilot_routes.py` | ~70% | brief, doctor, scenarios |
| `app/presentation/api/v1/watchlist_routes.py` | ~65% | CRUD (sub/id fixed) |
| `app/presentation/api/v1/goal_routes.py` | ~65% | CRUD, SIP calc |
| `app/presentation/api/v1/notification_routes.py` | ~65% | list, mark-read, count |
| `app/presentation/api/v1/import_routes.py` | ~70% | CAS, CSV, CAMS, email |
| `app/domain/entities.py` | ~90% | domain model |
| `app/infrastructure/repositories/` | ~75% | SQLAlchemy repos |
| `app/infrastructure/importers/` | ~75% | parsers |
| `app/infrastructure/ai/` | Excluded | Requires live AI API |
| `app/infrastructure/analytics/` | Excluded | Requires live data |
| `app/infrastructure/market/` | Excluded | Requires live market data |
| `app/infrastructure/scheduler/` | Excluded | Async scheduler |

### Test Files

| File | Tests | Status |
|------|-------|--------|
| `test_auth.py` | 12 | ✅ |
| `test_auth_advanced.py` | ~20 | ✅ |
| `test_auth_dependency.py` | 5 | ✅ |
| `test_password_reset.py` | 8 | ✅ |
| `test_domain.py` | ~15 | ✅ |
| `test_portfolio.py` | ~18 | ✅ |
| `test_portfolio_imports.py` | 6 | ✅ |
| `test_importers.py` | 5 | ✅ |
| `test_importers_advanced.py` | 31 | ✅ |
| `test_ai_provider.py` | 8 | ✅ |
| `test_analytics_engine.py` | 8 | ✅ |
| `test_advanced_analytics.py` | 5 | ✅ |
| `test_copilot_routes.py` | 6 | ✅ |
| `test_coverage_boost.py` | 55 | ✅ |
| `test_api_endpoints.py` | 8 | ✅ |
| `test_api_error_branches.py` | 6 | ✅ |
| `test_database_session.py` | 4 | ✅ |
| `test_events.py` | 3 | ✅ |
| `test_market_news_cache.py` | 5 | ✅ |
| `test_setu_aa_crypto.py` | 4 | ✅ |
| `test_market_routes.py` | 12 | ✅ (added 0.8.0) |

---

## Key Coverage Gains (0.9.0)

| Module | v0.8.0 | v0.9.0 |
|--------|--------|--------|
| `market_routes.py` | 92% | 96% |
| `notification_routes.py` | 81% | 88% |
| `goal_routes.py` | 73% | 73% |
| `watchlist_routes.py` | 48% | 48% |
| Overall | 75.1% | **75.16%** |

### New Test Files (0.9.0)
| File | Tests | Status |
|------|-------|--------|
| `test_watchlist_routes.py` | 9 | ✅ |
| `test_goal_routes.py` | 8 | ✅ |
| `test_notification_routes.py` | 7 | ✅ |

---

## Flutter Test Results

### Summary

| Metric | Value |
|--------|-------|
| Widget Tests | Basic widget tests |
| Integration Tests | Not yet implemented |
| Status | ⚠️ PARTIAL |

### Flutter Test Files

| File | Tests | Status |
|------|-------|--------|
| `test/auth_widget_test.dart` | Auth screen rendering | ✅ |
| `test/dashboard_widget_test.dart` | Dashboard with mock providers | ✅ |

---

## Security Scan Results

| Tool | Status | Findings |
|------|--------|----------|
| Bandit (Python SAST) | ✅ Passing | No high severity |
| Trivy (dependency scan) | ✅ Configured | SARIF uploaded |
| SBOM | ✅ Generated | SPDX-JSON format |
| Ruff security rules | ✅ Passing | No violations |

---

## Performance Targets (Not Yet Measured)

| Endpoint | Target | Status |
|----------|--------|--------|
| `GET /api/v1/health` | <10ms | ⏳ Not measured |
| `POST /auth/login` | <200ms | ⏳ Not measured |
| `GET /portfolios/{id}/analytics` | <500ms | ⏳ Not measured |
| `GET /market/overview` | <1000ms | ⏳ Not measured (yFinance) |
| Flutter app cold start | <3s | ⏳ Not measured |
| Flutter dashboard load | <1s after auth | ⏳ Not measured |

---

## Known Failing Paths (Not Tests)

| Issue | Status |
|-------|--------|
| Docker build (Dockerfile.api COPY order) | ✅ Fixed in 0.8.0 |
| Android applicationId com.example.web | ✅ Fixed in 0.8.0 |
| Android minSdk too low for plugins | ✅ Fixed in 0.8.0 |
| wrangler.toml invalid for CF Pages | ✅ Fixed in 0.8.0 |
| Flutter version mismatch in CI | ✅ Fixed in 0.8.0 |

---

## Test Execution Commands

```bash
# Backend (via Docker — no local Python needed)
docker compose run --rm \
  -e APP_ENV=development \
  -e DATABASE_URL="sqlite+aiosqlite:///:memory:" \
  -e JWT_SECRET_KEY="test-key" \
  -e AI_API_KEY="test-key" \
  api pytest --cov=app --cov-report=term-missing -v

# Flutter analyze
docker compose --profile build run --rm flutter flutter analyze --no-fatal-warnings

# Flutter test
docker compose --profile build run --rm flutter flutter test

# Flutter web build
docker compose --profile build run --rm flutter flutter build web --release

# Android debug APK
docker compose --profile build run --rm flutter flutter build apk --debug
```
