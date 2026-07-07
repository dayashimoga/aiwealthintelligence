# WealthAI Platform — TODO Task Tracker

This file lists the sequentially ordered tasks for all development phases of the AI Wealth Intelligence Platform.

---

## Phase 1: Complete Gap Analysis & Project Tracking
- [x] Review screen, service, database, AI, auth, sync, CI/CD pathways
- [x] Initialize implementation tracking metadata files
  - [x] `IMPLEMENTATION.md`
  - [x] `TODO.md`
  - [x] `CHANGELOG.md`
- [x] Verify test suites compile and run

## Phase 2: Fix All Existing Errors
- [x] Implement robust network retry interceptors in Flutter Dio client
- [x] Wrap UI state providers in Riverpod AsyncValue error catcher boundaries
- [x] Render offline fallback templates using local Hive cached profiles
- [x] Ensure uvicorn backend handles rate limit headers correctly
- [x] Fix SQLAlchemy reserved name conflict (metadata → extra_data)
- [x] Fix CI APP_ENV validation (testing → development)
- [x] Fix coverage config (remove overbroad omit patterns)
- [x] Fix Flutter print() → log() in api_client.dart

## Phase 3: Production-Ready Authentication
- [x] Update SQL schemas and user domain entities with OAuth, MFA, and Device credentials
- [x] Build OAuth endpoints `/auth/google` and `/auth/apple`
- [x] Implement OTP verification code delivery and check routines
- [x] Set up TOTP 2FA registration and backup codes
- [x] Build trusted device tracking and sessions list
- [x] Build Flutter onboarding tutorial and biometric settings toggles

## Phase 4: Portfolio Import & Automation
- [x] Build Account Aggregator consent gate workflows complying with Sahamati specs
- [x] Build background sync task workers in APScheduler fetching live prices and sectors
- [x] Implement automatic CAS PDF imports parsing transaction history
- [x] Map broker CSV configurations (Groww, Upstox, Zerodha)
- [x] Support manual holdings additions
- [x] Auto-trigger holdings re-valuation on price updates

## Phase 5: Real Data Integration
- [x] Retrieve company fundamentals and valuation ratios
- [x] Fetch historical pricing lists for charts (1M, 6M, 1Y, 5Y)
- [x] Retrieve corporate actions lists (dividends, splits, bonuses)
- [x] Integrate macroeconomic indicator lists and economic calendar via World Bank APIs

## Phase 6: AI Engine Diagnostics
- [x] Structure recommendation prompts to yield confidence, evidence list, reasoning, risk description, and horizon
- [x] Enforce output schemas via Pydantic model validation
- [x] Contextualize chats with live news feed sentiment

## Phase 7: Advanced Portfolio Features
- [x] Build stress testing engine modeling interest hikes and market variance
- [x] Model simulated scenario transaction lists side-by-side with original metrics
- [x] Calculate tax loss harvesting opportunities (STCG/LTCG offsets)
- [x] Detect behavioral bias anomalies (over-concentration, panic sells)
- [x] Support goal planning trackers
- [x] Add sector rotation analysis endpoint
- [x] Add dividend planner endpoint
- [x] Add opportunity radar endpoint

## Phase 8: Notifications & Watchlists
- [x] Create notification database model and service
- [x] Build notification REST API routes (list, mark read, count)
- [x] Create goal planning CRUD routes with SIP calculator
- [x] Create watchlist CRUD routes with AI intelligence
- [x] Wire Flutter models, repositories, and providers
- [x] Add price alert, rebalance, and dividend notification generators

## Phase 9: Premium Fintech Dashboard
- [x] Render interactive portfolio health rings and risk meter ranges
- [x] Visualize allocations, winners/losers, upcoming corporate action calendars
- [x] Integrate economic calendar timeline widgets
- [x] Add interactive charts

## Phase 10: Setting Workflows Completion
- [x] Bind Settings pages to Passkeys, device management, theme parameters, API keys, and account deletion

## Phase 11: Performance Optimization
- [x] Cache app data using local Hive store
- [x] Reduce unnecessary widget re-renders
- [x] Limit redundant network requests during startup

## Phase 12: Testing Expansion (>90% Coverage)
- [x] Write integration test coverage for MFA and biometrics
- [x] Add Flutter widget tests for all new screens
- [x] Backend: 90 tests passing

## Phase 13: CI/CD & Infrastructure
- [x] Create Dockerfile.flutter for builds without local Flutter
- [x] Update docker-compose.yml with API service + Flutter builder
- [x] Remove continue-on-error from critical CI steps
- [x] Create backend automation script (venv setup/teardown)
- [ ] Map Cloudflare pages builds and Android bundle compiles in CI scripts

## Phase 14: Smart Imports (Future Integrations)
- [x] CAS PDF parser framework
- [x] Broker CSV parser framework (Groww, Zerodha, Upstox, Angel, ICICI, Kotak)
- [x] Account Aggregator consent framework
- [ ] Email CAS auto-import (future: user authorizes mailbox)
- [ ] CAMS & KFin mutual fund import API integration
