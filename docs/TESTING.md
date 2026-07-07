# WealthAI — Testing Guide

## Backend Testing

### Run All Tests
```bash
cd services/api
pip install -e ".[dev]"
pytest --cov=app --cov-report=term-missing --cov-fail-under=90 -v
```

### Environment Variables for Tests
```
APP_ENV=development
APP_DEBUG=false
DATABASE_URL=sqlite+aiosqlite:///:memory:
JWT_SECRET_KEY=test-secret-key-for-ci-only
AI_API_KEY=test-key
```

### Test Modules
| File | Coverage |
|------|----------|
| `test_auth.py` | Registration, login, token refresh, OTP flow |
| `test_auth_advanced.py` | TOTP setup/enable, device management, biometrics |
| `test_auth_dependency.py` | JWT decode, token type validation |
| `test_api_endpoints.py` | Portfolio/holdings CRUD endpoints |
| `test_api_error_branches.py` | Error handlers, validation, 404/401/429 |
| `test_portfolio.py` | Portfolio analytics, import endpoints |
| `test_portfolio_imports.py` | AA consent, broker import |
| `test_advanced_analytics.py` | Stress test, tax harvesting, behavioral bias |
| `test_ai_provider.py` | AI recommendation, chat, copilot |
| `test_analytics_engine.py` | XIRR, CAGR, diversification scoring |
| `test_copilot_routes.py` | Scenario simulation, doctor, advanced |
| `test_database_session.py` | SQLAlchemy session lifecycle |
| `test_domain.py` | Domain entity validation |
| `test_events.py` | Domain event publishing |
| `test_importers.py` | CAS PDF, broker CSV parsers |
| `test_market_news_cache.py` | Market data, RSS news, Redis cache |
| `test_setu_aa_crypto.py` | ECDH key exchange, AES-GCM decryption |

### Coverage Target: >90%

## Flutter Testing

### Run Widget Tests
```bash
cd apps/web
flutter test --coverage
```

### Run via Docker
```bash
powershell -File .\scripts\flutter.ps1 test
```

### Test Files
| File | Type |
|------|------|
| `test/widget_test.dart` | App smoke test (renders without crash) |
| `test/screens_widget_test.dart` | Screen render tests |

### Integration Tests (Planned)
```bash
flutter test integration_test/
```

## CI Test Pipeline
1. `ruff format --check .` — formatting
2. `ruff check .` — lint (0 errors required)
3. `mypy app/ --ignore-missing-imports` — type check (non-blocking)
4. `bandit -r app/ -ll -ii` — security scan
5. `pytest --cov-fail-under=90` — unit tests with coverage gate
6. `dart format --set-exit-if-changed .` — dart formatting
7. `flutter analyze` — static analysis
8. `flutter test` — widget tests
9. `flutter build web/apk/aab` — compile check
