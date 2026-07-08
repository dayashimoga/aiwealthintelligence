# WealthAI — Architecture

## System Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         WealthAI Platform                                 │
├─────────────────────┬─────────────────────┬──────────────────────────────┤
│   Flutter Clients   │   FastAPI Backend    │   Zero-Cost Infrastructure   │
│                     │   (Python 3.11+)     │                              │
├─────────────────────┼─────────────────────┼──────────────────────────────┤
│ Android App (APK)   │ Presentation Layer  │ Cloudflare Pages (web host)  │
│ Web PWA (CF Pages)  │  - FastAPI routes   │ Render.com (API host, free)  │
│ iOS (future)        │  - Pydantic schemas │ Supabase PostgreSQL (free)   │
│                     │  - Middleware       │ Upstash Redis (free)         │
├─────────────────────┼─────────────────────┼──────────────────────────────┤
│ Presentation        │ Domain Layer        │ yFinance (market data)       │
│  - Screens          │  - Entities         │ OpenAI / Groq (AI copilot)   │
│  - Riverpod         │  - Repository ABCs  │ RSS feeds (market news)      │
│  - GoRouter         │  - Domain events    │ APScheduler (background)     │
├─────────────────────┼─────────────────────┼──────────────────────────────┤
│ Domain              │ Infrastructure      │ GitHub Actions (CI/CD free)  │
│  - Models           │  - SQLAlchemy repos │  Build → Test → Deploy       │
│  - Repositories     │  - Redis cache      │  Android APK/AAB artifacts   │
│  - Network (Dio)    │  - AI providers     │  Cloudflare Pages deploy     │
│                     │  - Market data      │  Docker builds               │
├─────────────────────┼─────────────────────┼──────────────────────────────┤
│ Data                │ Importers           │ Docker (local dev)           │
│  - Hive cache       │  - CAS PDF parser   │  Dockerfile.api (prod)       │
│  - Secure storage   │  - CAMS/KFin parser │  Dockerfile.api-test (CI)    │
│  - flutter_secure   │  - Broker CSV       │  Dockerfile.flutter (build)  │
│    _storage         │  - Email IMAP       │  docker-compose.yml          │
└─────────────────────┴─────────────────────┴──────────────────────────────┘
```

## Production Deployment

```
Developer → git push main
                │
                ▼
        GitHub Actions
        ┌──────────────────────────────────────┐
        │  1. backend-ci    (pytest, ruff)      │
        │  2. flutter-ci    (analyze, test)     │
        │  3. docker-build  (Trivy scan, SBOM)  │
        │  4. deploy-web    → Cloudflare Pages  │
        │  5. build-android → APK/AAB artifact  │
        └──────────────────────────────────────┘
                │
    ┌───────────┴───────────────┐
    ▼                           ▼
Cloudflare Pages           Render.com
(Flutter Web PWA)          (FastAPI API)
    │                           │
    │                    ┌──────┴──────┐
    │                    ▼             ▼
    │              Supabase       Upstash
    │              PostgreSQL     Redis
    │              (500MB free)   (10k/day)
    │
    └── HTTPS → API_BASE_URL (dart-define)
              → https://wealthai-api.onrender.com
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
