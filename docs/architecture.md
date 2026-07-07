# WealthAI — Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      WealthAI Platform                           │
├─────────────────┬───────────────────────┬───────────────────────┤
│  Flutter App    │   FastAPI Backend      │   Infrastructure      │
│  (iOS/Android/  │   (Python 3.11+)      │                       │
│   Web/Desktop)  │                        │                       │
├─────────────────┼───────────────────────┼───────────────────────┤
│ Presentation    │ Presentation Layer     │ PostgreSQL (prod)     │
│  - Screens      │  - FastAPI routes      │ SQLite (dev/test)     │
│  - Riverpod     │  - Pydantic schemas    │ Redis (cache)         │
│    providers    │  - Middleware          │ yFinance (prices)     │
│  - GoRouter     │                        │ OpenAI (GPT-4o)       │
├─────────────────┼───────────────────────┼───────────────────────┤
│ Domain          │ Domain Layer           │ APScheduler           │
│  - Models       │  - Entities            │  (background sync)    │
│  - Repositories │  - Repository ABCs     │                       │
│  - Network      │  - Domain events       │                       │
├─────────────────┼───────────────────────┼───────────────────────┤
│ Data            │ Infrastructure Layer   │ Docker                │
│  - Repositories │  - SQLAlchemy repos    │  Dockerfile.api       │
│    (Dio HTTP)   │  - Redis cache         │  Dockerfile.android   │
│  - Hive cache   │  - AI providers        │  Dockerfile.flutter   │
│  - Secure store │  - Market data         │                       │
│                 │  - Importers           │                       │
└─────────────────┴───────────────────────┴───────────────────────┘
```

## Flutter App Architecture

### State Management — Riverpod
- `StateNotifierProvider` for mutable state (auth, theme)
- `StreamProvider` for live data with Hive cache fallback
- `FutureProvider.family` for parameterized async data
- `Provider` for pure dependency injection

### Auth Flow
```
App Start → /splash → AuthNotifier._checkStoredToken()
  ├─ No token → /login
  ├─ Token invalid → clear tokens → /login
  ├─ Token valid, not onboarded → /onboarding
  └─ Token valid, onboarded → /dashboard
```

### Caching Strategy
- Hive boxes for offline-first data (portfolios, holdings, analytics)
- FlutterSecureStorage for JWT tokens (AES-256 encrypted on Android)
- 2-minute TTL for most data, 30-second for market quotes

### Navigation
- GoRouter with `redirect` callback driven by `AuthStatus`
- `ShellRoute` for main app with `ShellScaffold` (nav bar/rail)
- Deep linking ready (all routes are named)

## Backend Architecture

### Clean Architecture Layers
```
app/
├── domain/          # Pure Python, no framework deps
│   ├── entities.py  # Dataclasses with business rules
│   ├── repositories.py  # Abstract repo interfaces
│   └── events.py    # Domain events
├── infrastructure/  # Concrete implementations
│   ├── database/    # SQLAlchemy models + session
│   ├── ai/          # OpenAI provider + copilot
│   ├── analytics/   # Portfolio engine + advanced analytics
│   ├── market/      # yFinance + news + price cache
│   ├── importers/   # CAS PDF + broker CSV parsers
│   ├── repositories/ # SQLAlchemy + Redis implementations
│   ├── scheduler/   # APScheduler background jobs
│   └── services/    # Email, notification, Setu AA
├── presentation/    # FastAPI
│   ├── api/v1/      # Route handlers
│   ├── middleware/  # Auth, error, rate limit, security
│   └── schemas/     # Pydantic I/O schemas
└── shared/          # Cross-cutting: security, exceptions, observability
```

### Database Schema (SQLAlchemy)
- `users` — auth credentials, MFA, OAuth tokens, device list
- `portfolios` — user portfolios with metadata
- `holdings` — positions with live price cache
- `transactions` — trade history for XIRR calculation
- `ai_recommendations` — cached AI outputs
- `market_news` — cached news with sentiment
- `notifications` — in-app notification queue
- `watchlists` + `watchlist_symbols` — user watchlists
- `financial_goals` — goal planning with SIP calculator
- `passkey_credentials` — WebAuthn passkeys

### Security
- JWT (HS256) with 30min access / 7d refresh token rotation
- Argon2/bcrypt password hashing
- ECDH key exchange for Setu Account Aggregator
- Rate limiting: 100 req/min per IP (SlowAPI)
- OWASP headers: CSP, HSTS, X-Frame-Options, X-Content-Type-Options
- Audit logging via structlog

## CI/CD Pipeline
```
Push/PR → GitHub Actions
  ├─ backend: ruff format/check → mypy → bandit → pytest (>90% cov)
  ├─ frontend: dart format → flutter analyze → flutter test → build web/apk/aab
  ├─ security: Trivy SBOM scan
  └─ docker: build API image + SBOM
```
