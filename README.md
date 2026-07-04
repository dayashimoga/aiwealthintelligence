<p align="center">
  <img src="docs/assets/logo.svg" alt="WealthAI Logo" width="80" height="80">
</p>

<h1 align="center">WealthAI</h1>
<p align="center">
  <strong>AI Wealth Intelligence Platform — Your AI Financial Copilot</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#deployment">Deployment</a> •
  <a href="#testing">Testing</a> •
  <a href="#contributing">Contributing</a>
</p>

---

## Overview

WealthAI is an open-source, AI-first portfolio intelligence platform that acts as your **AI Financial Copilot** rather than a simple portfolio tracker. It provides:

- **AI Recommendations** with explainability (Strong Buy → Exit with confidence scores)
- **Portfolio Intelligence** detecting hidden risks, overlap, and tax inefficiency
- **Natural Language Chat** to interact with your portfolio data
- **Market Intelligence** with AI-summarized news and sector rankings
- **Multi-platform**: Responsive Web, Android, and iOS

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Flutter 3.24 (Web, Android, iOS), Material 3, Riverpod, GoRouter |
| **Backend** | FastAPI, Python 3.11+, SQLAlchemy, Alembic, Pydantic |
| **Database** | SQLite (dev) → PostgreSQL + pgvector (prod), Redis |
| **AI** | OpenAI-compatible API abstraction, Ollama (local LLM), LangGraph-ready |
| **Infra** | Docker, Docker Compose, Cloudflare Pages, GitHub Actions |
| **Auth** | JWT (access + refresh), bcrypt, RBAC, OWASP ASVS |
| **Observability** | Structured logging (structlog), Prometheus, Grafana, OpenTelemetry |

## Features

### Portfolio Management
- Manual entry, CSV import, NSDL/CDSL CAS (interface ready)
- Holdings with asset type, exchange, sector, ISIN tracking
- Transaction history (buy, sell, dividend, split, bonus)

### Portfolio Dashboard
- Total value, invested amount, P&L with percentage
- Asset allocation, sector allocation, country allocation
- XIRR, CAGR, drawdown, diversification score
- AI health score, risk score

### AI Recommendation Engine
Every holding gets a 6-tier recommendation:
| Action | Description |
|--------|-------------|
| **Strong Buy** | High confidence buy signal |
| **Buy** | Positive outlook |
| **Hold** | Maintain position |
| **Reduce** | Consider partial exit |
| **Sell** | Exit position |
| **Exit** | Urgent exit recommended |

Each recommendation includes **AI Explainability** covering:
fundamentals, technical indicators, news sentiment, macroeconomics,
valuation, sector outlook, institutional activity, insider activity,
and market sentiment.

### Portfolio Intelligence
Detects: duplicate funds, hidden overlap, sector/geographic concentration,
over/under-diversification, tax inefficiency, governance risks,
inflation risks, interest-rate risks.

### Market Intelligence
- AI-summarized news with sentiment analysis
- Sector performance rankings (1D, 1W, 1M, 3M, 1Y)
- Economic calendar, earnings calendar, corporate actions

### AI Copilot Chat
Natural language interface to ask questions about your portfolio:
- "How is my portfolio health?"
- "What if I sell WIPRO and buy HDFCBANK?"
- "Find hidden risks in my portfolio"
- "Suggest a rebalancing plan"

## Architecture

```
Clean Architecture + DDD + Event-Driven + Modular Monolith
```

```
┌─────────────────────────────────────────────────┐
│                  Presentation                     │
│    Flutter Web/Mobile  ←→  FastAPI Routes          │
├─────────────────────────────────────────────────┤
│                  Application                      │
│         Use Cases  ←→  DTOs  ←→  Interfaces       │
├─────────────────────────────────────────────────┤
│                    Domain                         │
│      Entities  ←→  Repositories  ←→  Events       │
├─────────────────────────────────────────────────┤
│                 Infrastructure                    │
│   SQLAlchemy  ←→  AI Providers  ←→  Cache         │
└─────────────────────────────────────────────────┘
```

### Repository Structure

```
/apps/web/          — Flutter app (Web + Android + iOS)
/services/api/      — FastAPI backend with Clean Architecture
/infra/docker/      — Dockerfiles
/infra/terraform/   — Infrastructure as Code
/docs/              — Documentation
/.github/workflows/ — CI/CD pipelines
```

## Quick Start

### Prerequisites
- Python 3.11+
- Flutter 3.24+
- Docker & Docker Compose (optional)

### Backend Setup

```bash
cd services/api
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -e ".[dev]"
cp ../../.env.example .env  # Edit with your settings
uvicorn app.main:app --reload --port 8000
```

API docs available at: http://localhost:8000/api/docs

### Frontend Setup

```bash
cd apps/web
flutter pub get
flutter run -d chrome --web-port 8080
```

### Docker (Full Stack)

```bash
docker compose up -d
# API: http://localhost:8000
# Swagger: http://localhost:8000/api/docs
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/health` | Health check |
| POST | `/api/v1/auth/register` | Register user |
| POST | `/api/v1/auth/login` | Login |
| POST | `/api/v1/auth/refresh` | Refresh token |
| GET | `/api/v1/auth/me` | Get profile |
| GET/POST | `/api/v1/portfolios` | List/Create portfolios |
| GET/PATCH/DELETE | `/api/v1/portfolios/{id}` | Portfolio CRUD |
| POST | `/api/v1/portfolios/{id}/holdings` | Add holding |
| GET | `/api/v1/portfolios/{id}/holdings` | List holdings |
| POST | `/api/v1/portfolios/{id}/import` | Import CSV |
| GET | `/api/v1/portfolios/{id}/analytics` | Portfolio analytics |
| GET | `/api/v1/ai/recommendations/{pid}/{hid}` | AI recommendation |
| POST | `/api/v1/ai/chat` | AI chat |
| GET | `/api/v1/market/news` | Market news |
| GET | `/api/v1/market/sectors` | Sector rankings |
| GET | `/api/v1/market/overview` | Market overview |

## Deployment

### Cloudflare Pages (Zero-cost)

1. Connect GitHub repo to Cloudflare Pages
2. Set build command: `cd apps/web && flutter build web --release`
3. Set output directory: `apps/web/build/web`
4. Or use GitHub Actions (already configured in `.github/workflows/deploy.yml`)

### Required Secrets

Set these in GitHub repository secrets:
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

## Testing

```bash
# Backend tests (>90% coverage enforced)
cd services/api && pytest --cov=app --cov-fail-under=90

# Flutter tests
cd apps/web && flutter test --coverage

# All tests
make test
```

## Security

- OWASP ASVS compliant authentication
- Security headers (CSP, HSTS, X-Frame-Options, etc.)
- Rate limiting per endpoint
- Input validation (Pydantic)
- Password strength validation
- JWT with access + refresh tokens
- Audit logging
- Dependency scanning in CI

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit with conventional commits (`feat: add amazing feature`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">
  Built with ❤️ by the WealthAI community
</p>
