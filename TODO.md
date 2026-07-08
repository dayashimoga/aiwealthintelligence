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
- [x] Fix Dockerfile.api COPY order (pip install now works correctly)
- [x] Upgrade Dockerfile.flutter to Flutter 3.27.4 + Android SDK 35 + Java 17
- [x] Fix CI/deploy flutter-version to 3.27.4 (matches pubspec SDK >=3.4.0)
- [x] Fix wrangler.toml for valid Cloudflare Pages config
- [ ] Map Cloudflare pages builds and Android bundle compiles in CI scripts (pending CF secrets)
- [ ] Configure Cloudflare Pages secrets in GitHub (CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID)

## Phase 14: Smart Imports (Future Integrations)
- [x] CAS PDF parser framework
- [x] Broker CSV parser framework (Groww, Zerodha, Upstox, Angel, ICICI, Kotak)
- [x] Account Aggregator consent framework
- [x] Email CAS auto-import (user provides IMAP credentials)
- [ ] CAMS & KFin mutual fund import API integration (official API access pending)

## Phase 15: Android Production Readiness
- [x] Fix applicationId: com.example.web → com.wealthai.app
- [x] Fix minSdk = 23 (flutter_secure_storage + local_auth requirement)
- [x] Set compileSdk/targetSdk = 35
- [x] Set Java 17 compile options
- [x] Pin NDK to 27.0.12077973
- [x] Enable ProGuard/R8 for release builds
- [x] Add proguard-rules.pro for Flutter + plugins
- [x] Add network security config (HTTPS-only enforcement)
- [x] Add required permissions (biometric, camera, notifications, file)
- [x] Add deep link scheme: wealthai://app
- [x] Configure env-var-based release keystore signing
- [ ] Generate production keystore and store as CI secrets
- [ ] Submit to Play Store internal testing track

## Phase 16: Authentication Completions
- [ ] Wire Google Sign-In (firebase_auth + google_sign_in packages + google-services.json)
- [ ] Wire Apple Sign-In (sign_in_with_apple + Apple Developer entitlements)
- [ ] Passkeys (platform credential API) — full end-to-end implementation

## Phase 17: Production Database & Deployment
- [ ] Set up managed PostgreSQL (Supabase/Neon/Railway recommended)
- [ ] Set up managed Redis (Upstash recommended for serverless)
- [ ] Configure production .env with real DATABASE_URL and REDIS_URL
- [ ] Run Alembic migrations on production database
- [ ] Deploy API to Railway/Fly.io/Render

## Phase 18: Push Notifications
- [ ] Set up Firebase Cloud Messaging (FCM) for Android
- [ ] Integrate flutter_local_notifications + firebase_messaging
- [ ] Wire price alert notification triggers from backend scheduler
- [ ] Wire SIP reminder notification triggers
- [ ] Wire rebalancing notification triggers

## Phase 19: Testing Expansion (≥80% Coverage)
- [ ] Add market routes integration tests
- [ ] Add copilot routes integration tests
- [ ] Add watchlist/goal/notification route tests
- [ ] Flutter: add portfolio screen widget tests
- [ ] Flutter: add import flow widget tests
- [ ] Flutter: add E2E integration tests (register → import → view)

