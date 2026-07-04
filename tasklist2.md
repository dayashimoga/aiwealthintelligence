# AI Wealth Intelligence — Task Tracker

## Phase 1: Backend Foundation Fixes

- [ ] Create error handler middleware (AppException → JSON responses)
- [ ] Fix main.py (wire error handler, add DB table creation on startup)
- [ ] Fix session.py (engine reference, create_all utility)
- [ ] Generate initial Alembic migration
- [ ] Add portfolio CRUD tests
- [ ] Add portfolio analytics tests
- [ ] Verify all tests pass and CI green

## Phase 2: Market Data Pipeline
- [ ] Market data service (yfinance provider)
- [ ] Price cache (in-memory + Redis)
- [ ] News fetcher
- [ ] Background scheduler
- [ ] Wire real data into market routes
- [ ] Auto-update holding prices
- [ ] Add market data tests

## Phase 3: Smart Portfolio Imports
- [ ] CAS PDF parser (NSDL/CDSL)
- [ ] Enhanced CSV importer
- [ ] Broker adapters (file-based)
- [ ] Import API routes
- [ ] Import job tracking
- [ ] Add import tests

## Phase 4: Real Analytics & AI Copilot
- [ ] Portfolio analytics engine (XIRR, CAGR, Sharpe, tax)
- [ ] Enrich AI with real market data
- [ ] AI Copilot endpoints (brief, scenario, rebalance, doctor)
- [ ] Add analytics + AI tests

## Phase 5: Flutter Frontend Real Data
- [ ] Connect dashboard to real API
- [ ] Import wizard UI
- [ ] AI copilot screens
- [ ] Skeleton loaders / error states / empty states
- [ ] Widget tests

## Phase 6: CI/CD, Security & Deployment
- [ ] Fix CI pipeline
- [ ] Cloudflare Pages deployment
- [ ] Android build in CI
- [ ] Security hardening
- [ ] >90% test coverage
