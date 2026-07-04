# AI Wealth Intelligence Platform — Implementation Plan

## Overview

Build a production-grade, AI-first portfolio intelligence platform deployable as a responsive website, Android app, and iOS app. The platform is an **AI financial copilot**, not a portfolio tracker.

> [!IMPORTANT]
> **Credit Budget Reality Check**: Building *everything* listed in the requirements would take a team of 10+ engineers several months. Within ~300 AI credits, this plan delivers a **fully functional, production-quality foundation** with core features working end-to-end. The architecture is designed so every subsequent feature slots in without rewrites.

## Strategy: Depth Over Breadth

Rather than shallow stubs across 50 features, we build **6 vertical slices** end-to-end (UI → API → DB → Tests → Docs):

1. **Repository scaffold + CI/CD** — full infrastructure
2. **Authentication system** — JWT + email auth + RBAC
3. **Portfolio management** — manual entry + CSV import + dashboard
4. **AI recommendation engine** — provider-abstracted AI with explainability
5. **Market intelligence** — news + sector ranking
6. **Portfolio intelligence** — overlap detection + risk analysis

Everything else is architected (interfaces, models, routes defined) so it can be implemented incrementally.

---

## User Review Required

> [!IMPORTANT]
> **Deployment Target**: The plan uses Cloudflare Pages for Flutter Web deployment. Please confirm you have a Cloudflare account or want instructions for setup.

> [!IMPORTANT]
> **Database Choice for MVP**: For zero-cost initial deployment, the plan uses SQLite (with PostgreSQL-compatible schema) locally and Cloudflare D1 for production. PostgreSQL + pgvector is architected but activated when scaling. Is this acceptable?

> [!WARNING]
> **API Keys**: The AI recommendation engine needs an OpenAI-compatible API key. The architecture supports local LLMs via Ollama but cloud AI gives better results initially. Please confirm which provider you prefer (OpenAI, Groq, Ollama, etc.).

## Open Questions

1. **India-focused or Global?** The mention of NSDL CAS, CDSL CAS, FII/DII flows suggests India-focus. Should the UI/data also support US markets?
2. **Flutter version**: Should we pin to a specific Flutter version or use latest stable?
3. **GitHub repo**: Should I initialize git and configure for `dayashimoga/investment` or a different repo name?

---

## Proposed Changes

### Phase 1: Repository Scaffold + Infrastructure

#### [NEW] Root Configuration Files

| File | Purpose |
|------|---------|
| `.gitignore` | Comprehensive ignore for Flutter, Python, Docker, IDE |
| `README.md` | Project overview, setup, architecture |
| `LICENSE` | MIT license |
| `Makefile` | Common commands (setup, test, build, deploy) |
| `docker-compose.yml` | Full local dev stack |
| `docker-compose.prod.yml` | Production stack |
| `.env.example` | Environment variable template |

#### [NEW] Repository Structure

```
h:\investment\
├── apps/
│   ├── web/                    # Flutter web app
│   └── mobile/                 # Flutter mobile app (shared codebase)
├── services/
│   ├── api/                    # FastAPI gateway
│   ├── ai/                     # AI engine service
│   ├── auth/                   # Auth service
│   ├── portfolio/              # Portfolio service
│   ├── recommendation/         # Recommendation service
│   ├── market/                 # Market data service
│   └── notification/           # Notification service
├── packages/
│   ├── shared/                 # Shared Dart packages
│   ├── ui/                     # UI component library
│   └── analytics/              # Analytics package
├── infra/
│   ├── docker/                 # Dockerfiles
│   └── terraform/              # IaC
├── docs/                       # All documentation
├── tests/                      # Integration/E2E tests
├── scripts/                    # Utility scripts
└── .github/workflows/          # CI/CD pipelines
```

#### [NEW] `.github/workflows/ci.yml`
Full CI pipeline: lint, format, type-check, test, build, coverage enforcement (>90%), SBOM, security scan.

#### [NEW] `.github/workflows/deploy.yml`
Deploy to Cloudflare Pages on main branch push, preview deployments for PRs.

---

### Phase 2: Flutter App Foundation

#### [NEW] `apps/web/` — Flutter Web + Mobile App

Single Flutter project targeting Web, Android, and iOS with:

- **Material 3** with dynamic color theming
- **Dark/Light mode** with system preference detection
- **Riverpod** for state management (code generation)
- **GoRouter** for declarative routing
- **Responsive/Adaptive layouts** (mobile, tablet, desktop breakpoints)
- **Glassmorphism** design system
- **Offline support** via Hive local storage
- **Skeleton loading**, empty states, error states
- **Premium fintech UI** with smooth animations

**Key files:**

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point, providers |
| `lib/core/theme/` | Material 3 theme, colors, typography |
| `lib/core/router/` | GoRouter configuration |
| `lib/core/widgets/` | Shared widgets (glassmorphism cards, charts) |
| `lib/features/auth/` | Auth screens + providers |
| `lib/features/dashboard/` | Portfolio dashboard |
| `lib/features/portfolio/` | Portfolio management |
| `lib/features/ai/` | AI recommendations + chat |
| `lib/features/market/` | Market intelligence |
| `lib/features/settings/` | Settings + preferences |

---

### Phase 3: FastAPI Backend

#### [NEW] `services/api/` — API Gateway

Clean Architecture + DDD structure:

```
services/api/
├── app/
│   ├── main.py                 # FastAPI app factory
│   ├── config.py               # Settings (Pydantic)
│   ├── domain/
│   │   ├── entities/           # Domain entities
│   │   ├── repositories/       # Repository interfaces
│   │   ├── services/           # Domain services
│   │   └── events/             # Domain events
│   ├── application/
│   │   ├── use_cases/          # Application use cases
│   │   ├── dto/                # Data transfer objects
│   │   └── interfaces/         # Port interfaces
│   ├── infrastructure/
│   │   ├── database/           # SQLAlchemy models, migrations
│   │   ├── repositories/       # Repository implementations
│   │   ├── ai/                 # AI provider abstraction
│   │   ├── cache/              # Redis/KV cache
│   │   └── external/           # External API clients
│   ├── presentation/
│   │   ├── api/
│   │   │   └── v1/             # Versioned API routes
│   │   ├── middleware/         # Auth, CORS, rate limiting
│   │   └── schemas/            # Pydantic request/response
│   └── shared/
│       ├── security.py         # OWASP security utilities
│       ├── observability.py    # OpenTelemetry setup
│       └── exceptions.py       # Custom exceptions
├── alembic/                    # Database migrations
├── tests/                      # Unit + integration tests
├── Dockerfile                  # Production container
├── pyproject.toml              # Dependencies
└── alembic.ini                 # Migration config
```

**Key APIs (v1):**

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/auth/register` | POST | User registration |
| `/api/v1/auth/login` | POST | Login (JWT) |
| `/api/v1/auth/refresh` | POST | Token refresh |
| `/api/v1/portfolios` | GET/POST | List/Create portfolios |
| `/api/v1/portfolios/{id}/holdings` | GET/POST/PUT/DELETE | CRUD holdings |
| `/api/v1/portfolios/{id}/import` | POST | Import CSV/CAS |
| `/api/v1/portfolios/{id}/analytics` | GET | XIRR, CAGR, allocation |
| `/api/v1/portfolios/{id}/intelligence` | GET | AI analysis |
| `/api/v1/recommendations/{holding_id}` | GET | AI recommendation |
| `/api/v1/market/news` | GET | Market news summary |
| `/api/v1/market/sectors` | GET | Sector ranking |
| `/api/v1/ai/chat` | POST | Natural language chat |
| `/api/v1/health` | GET | Health check |

---

### Phase 4: Authentication System

#### Implementation in both Flutter + FastAPI

- **JWT** with access + refresh tokens
- **Email/password** registration + login
- **RBAC** (admin, user, premium roles)
- **Security headers** (OWASP)
- **Rate limiting** per endpoint
- **Input validation** (Pydantic)
- **Audit logging**
- Passkeys, Google, Apple auth **interfaces defined** (implementation ready for next phase)

---

### Phase 5: Portfolio Management

#### End-to-end portfolio features

- **Manual entry**: Add/edit/delete holdings (stocks, MFs, ETFs, bonds, gold, crypto, real estate, FDs)
- **CSV import**: Standard format parser with validation
- **Dashboard**: Holdings table, asset allocation pie chart, sector allocation, risk score
- **Analytics**: XIRR, CAGR, drawdown, dividend income calculations
- **Portfolio intelligence**: Overlap detection, concentration analysis, diversification score

---

### Phase 6: AI Engine

#### Provider-abstracted AI system

```python
# AI Provider Abstraction
class AIProvider(ABC):
    async def complete(self, messages, **kwargs) -> AIResponse
    async def embed(self, text) -> list[float]
    async def stream(self, messages, **kwargs) -> AsyncIterator[str]

class OpenAIProvider(AIProvider): ...
class OllamaProvider(AIProvider): ...
class GroqProvider(AIProvider): ...
```

- **Recommendation engine**: 5-tier (Strong Buy → Exit) with confidence, reasoning, evidence
- **Explainability**: Structured reasoning across fundamentals, technicals, news, macro, valuation
- **Natural language chat**: Ask questions about your portfolio
- **Portfolio Doctor**: Find mistakes proactively
- **Scenario Simulator**: "What if" analysis

---

### Phase 7: Documentation

#### Auto-generated documentation

| Document | Format | Tool |
|----------|--------|------|
| README.md | Markdown | Manual |
| Architecture (ADR) | Markdown + Mermaid | Manual |
| OpenAPI spec | JSON/YAML | FastAPI auto-gen |
| ER diagrams | Mermaid | From SQLAlchemy models |
| PRD/SRS | Markdown | Manual |
| Deployment guide | Markdown | Manual |
| API docs | Swagger UI | FastAPI auto-gen |

---

## Verification Plan

### Automated Tests

```bash
# Backend tests
cd services/api && pytest --cov=app --cov-report=term-missing --cov-fail-under=90

# Flutter tests  
cd apps/web && flutter test --coverage

# Integration tests
docker compose up -d && pytest tests/integration/

# Lint + Format
cd services/api && ruff check . && ruff format --check .
cd apps/web && flutter analyze && dart format --set-exit-if-changed .
```

### Manual Verification
- Run `docker compose up` and verify all services start
- Open Flutter web app and verify responsive layout
- Test auth flow (register → login → access protected routes)
- Test portfolio creation and CSV import
- Test AI recommendation generation
- Verify Cloudflare Pages deployment via GitHub Actions

---

## Execution Order

| Step | Component | Est. Credits |
|------|-----------|-------------|
| 1 | Repository scaffold + configs | ~15 |
| 2 | Flutter app foundation (theme, routing, core widgets) | ~40 |
| 3 | FastAPI backend foundation (clean arch, DB, migrations) | ~40 |
| 4 | Authentication (JWT + email + RBAC) | ~30 |
| 5 | Portfolio management (models, API, UI, CSV import) | ~40 |
| 6 | Portfolio dashboard (analytics, charts, AI scores) | ~30 |
| 7 | AI engine (provider abstraction, recommendations, chat) | ~35 |
| 8 | Market intelligence (news, sectors) | ~15 |
| 9 | CI/CD pipelines + Docker | ~20 |
| 10 | Documentation + polish | ~15 |
| **Total** | | **~280** |

> [!TIP]
> The remaining ~20 credits are reserved for bug fixes, test additions, and user-requested changes.
