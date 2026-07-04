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

## Phase 3: Production-Ready Authentication
- [ ] Update SQL schemas and user domain entities with OAuth, MFA, and Device credentials
- [ ] Build OAuth endpoints `/auth/google` and `/auth/apple`
- [ ] Implement OTP verification code delivery and check routines
- [ ] Set up TOTP 2FA registration and backup codes
- [ ] Build trusted device tracking and sessions list
- [ ] Build Flutter onboarding tutorial and biometric settings toggles

## Phase 4: Portfolio Import & Automation
- [ ] Build Account Aggregator consent gate mock workflows
- [ ] Build background sync task workers in APScheduler
- [ ] Implement automatic CAS PDF imports parsing transaction history
- [ ] Map broker CSV configurations (Groww, Upstox, Zerodha)
- [ ] Support manual holdings additions
- [ ] Auto-trigger holdings re-valuation on price updates

## Phase 5: Real Data Integration
- [ ] Retrieve company fundamentals and valuation ratios
- [ ] Fetch historical pricing lists for charts (1M, 6M, 1Y, 5Y)
- [ ] Retrieve corporate actions lists (dividends, splits, bonuses)
- [ ] Integrate macroeconomic indicator lists and economic calendar

## Phase 6: AI Engine Diagnostics
- [ ] Structure recommendation prompts to yield confidence, evidence list, reasoning, risk description, and horizon
- [ ] Enforce output schemas via Pydantic model validation
- [ ] Contextualize chats with live news feed sentiment

## Phase 7: Advanced Portfolio Features
- [ ] Build stress testing engine modeling interest hikes and market variance
- [ ] Model simulated scenario transaction lists side-by-side with original metrics
- [ ] Calculate tax loss harvesting opportunities (STCG/LTCG offsets)
- [ ] Detect behavioral bias anomalies (over-concentration, panic sells)
- [ ] Support goal planning trackers

## Phase 8: Premium Fintech Dashboard
- [ ] Render interactive portfolio health rings and risk meter ranges
- [ ] Visualize allocations, winners/losers, upcoming corporate action calendars
- [ ] Integrate economic calendar timeline widgets
- [ ] Add interactive charts

## Phase 9: Setting Workflows Completion
- [ ] Bind Settings pages to Passkeys, device management, theme parameters, API keys, and account deletion

## Phase 10: Performance Optimization
- [ ] Cache app data using local Hive store
- [ ] Reduce unnecessary widget re-renders
- [ ] Limit redundant network requests during startup

## Phase 11: Testing Expansion (>90% Coverage)
- [ ] Write integration test coverage for MFA and biometrics
- [ ] Add Flutter widget tests for all new screens

## Phase 12: CI/CD automation
- [ ] Map Cloudflare pages builds and Android bundle compiles in CI scripts
