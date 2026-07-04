# Architecture Decision Records

## ADR-001: Clean Architecture with DDD

**Status**: Accepted  
**Date**: 2026-07-03

### Context
We need an architecture that supports:
- Modular monolith that can migrate to microservices
- Testability without infrastructure dependencies
- Clear separation of concerns
- Future extensibility

### Decision
Adopt Clean Architecture with Domain-Driven Design:
- **Domain Layer**: Pure Python entities with business logic, no framework dependencies
- **Application Layer**: Use cases orchestrating domain operations
- **Infrastructure Layer**: SQLAlchemy, AI providers, external APIs
- **Presentation Layer**: FastAPI routes, Pydantic schemas, middleware

### Consequences
- More initial boilerplate (repositories, mappers)
- Easy to test domain logic in isolation
- Swappable infrastructure (SQLite → PostgreSQL, OpenAI → Ollama)
- Clear boundaries enable future service extraction

---

## ADR-002: Flutter for Cross-Platform

**Status**: Accepted  
**Date**: 2026-07-03

### Context
Need to deploy on Web, Android, and iOS from a single codebase.

### Decision
Use Flutter with Material 3, Riverpod for state management, GoRouter for navigation.

### Consequences
- Single codebase for all platforms
- Material 3 provides consistent, modern UI
- Riverpod enables testable, predictable state management
- GoRouter provides declarative, deep-link-ready routing

---

## ADR-003: AI Provider Abstraction

**Status**: Accepted  
**Date**: 2026-07-03

### Context
Need to support multiple AI providers without vendor lock-in.

### Decision
Abstract AI providers behind a common interface (`AIProvider`):
- `OpenAICompatibleProvider`: OpenAI, Groq, Together
- `OllamaProvider`: Local LLM support

### Consequences
- Easy to add new providers
- User can choose cloud or local AI
- Consistent recommendation output regardless of provider
- Testable with mock providers

---

## ADR-004: SQLite for Development, PostgreSQL for Production

**Status**: Accepted  
**Date**: 2026-07-03

### Context
Need zero-cost initial deployment while supporting future scale.

### Decision
Use SQLite (via aiosqlite) for development and PostgreSQL (via asyncpg) for production. Database abstraction through SQLAlchemy ORM ensures portability.

### Consequences
- Zero infrastructure cost for development
- Production-ready with PostgreSQL + pgvector
- No schema changes needed between environments

---

## ADR-005: JWT Authentication with RBAC

**Status**: Accepted  
**Date**: 2026-07-03

### Context
Need stateless authentication for API and mobile apps.

### Decision
JWT with access tokens (30min) and refresh tokens (30 days).
Role-Based Access Control with admin, user, and premium roles.

### Consequences
- Stateless, scalable authentication
- Refresh tokens enable seamless UX
- RBAC enables premium features gating

---

# System Architecture Diagram

```mermaid
graph TB
    subgraph "Frontend"
        FW[Flutter Web]
        FA[Flutter Android]
        FI[Flutter iOS]
    end

    subgraph "API Gateway"
        API[FastAPI]
        AUTH[Auth Middleware]
        RATE[Rate Limiter]
        SEC[Security Headers]
    end

    subgraph "Domain Layer"
        UC[Use Cases]
        ENT[Entities]
        REPO[Repository Interfaces]
        EVT[Domain Events]
    end

    subgraph "Infrastructure"
        DB[(PostgreSQL + pgvector)]
        CACHE[(Redis)]
        AI[AI Provider]
        MKT[Market Data]
    end

    subgraph "AI Providers"
        OAI[OpenAI]
        GRQ[Groq]
        OLL[Ollama]
    end

    subgraph "Observability"
        LOG[Structured Logging]
        PROM[Prometheus]
        GRAF[Grafana]
    end

    FW --> API
    FA --> API
    FI --> API
    API --> AUTH
    API --> RATE
    API --> SEC
    AUTH --> UC
    UC --> ENT
    UC --> REPO
    UC --> EVT
    REPO --> DB
    REPO --> CACHE
    UC --> AI
    AI --> OAI
    AI --> GRQ
    AI --> OLL
    UC --> MKT
    API --> LOG
    LOG --> PROM
    PROM --> GRAF
```

# ER Diagram

```mermaid
erDiagram
    USERS {
        string id PK
        string email UK
        string hashed_password
        string full_name
        string role
        boolean is_active
        boolean is_verified
        datetime created_at
    }

    PORTFOLIOS {
        string id PK
        string user_id FK
        string name
        string currency
        string import_source
        datetime created_at
    }

    HOLDINGS {
        string id PK
        string portfolio_id FK
        string symbol
        string name
        string asset_type
        decimal quantity
        decimal average_buy_price
        decimal current_price
        string sector
        datetime created_at
    }

    TRANSACTIONS {
        string id PK
        string holding_id FK
        string portfolio_id FK
        string transaction_type
        decimal quantity
        decimal price
        datetime transaction_date
    }

    AI_RECOMMENDATIONS {
        string id PK
        string holding_id FK
        string action
        decimal confidence
        string reasoning
        json explainability
        datetime generated_at
    }

    WATCHLISTS {
        string id PK
        string user_id FK
        string name
        json symbols
    }

    AUDIT_LOGS {
        string id PK
        string user_id FK
        string action
        string resource_type
        json details
        datetime timestamp
    }

    USERS ||--o{ PORTFOLIOS : owns
    USERS ||--o{ WATCHLISTS : has
    PORTFOLIOS ||--o{ HOLDINGS : contains
    PORTFOLIOS ||--o{ TRANSACTIONS : records
    HOLDINGS ||--o{ TRANSACTIONS : tracks
    HOLDINGS ||--o{ AI_RECOMMENDATIONS : receives
    USERS ||--o{ AUDIT_LOGS : generates
```

# Deployment Architecture

```mermaid
graph LR
    subgraph "Cloudflare"
        CF[Cloudflare Pages]
        CDN[CDN Edge]
    end

    subgraph "GitHub"
        GH[GitHub Actions]
        GHR[GitHub Releases]
    end

    subgraph "Infrastructure"
        API[FastAPI Container]
        DB[(PostgreSQL)]
        RD[(Redis)]
    end

    GH -->|Deploy| CF
    GH -->|Build| GHR
    CF --> CDN
    CDN -->|API Calls| API
    API --> DB
    API --> RD
```
