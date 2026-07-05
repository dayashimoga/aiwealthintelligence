# WealthAI Platform — Changelog

This document tracks all version history and updates completed during the development iterations.

---

## [0.1.0] - 2026-07-04
### Added
- Complete Gap Analysis and checklist configuration.
- Creation of implementation tracking files: `IMPLEMENTATION.md`, `TODO.md`, `CHANGELOG.md` in the root of the workspace.
- Updated `implementation_plan.md` in the brain artifacts directory with comprehensive details on all 12 phases.
- Registered a custom FastAPI exception handler for slowapi `RateLimitExceeded` to gracefully return 429 status code instead of a 500 server error.
- Implemented `ConnectivityInterceptor` and `RetryInterceptor` on the Flutter client to handle offline detection and automatic timeout retries on GET requests.
- Implemented Database and Domain User schema updates for OAuth token, TOTP secret, backup codes, device registers and onboarding flags.
- Developed backend Email OTP code generation, logging fallbacks, and verification services.
- Created FastAPI endpoints for registration, traditional login, OAuth logins, OTP verify, TOTP setup/verification, passkey options request/assertions, and active session device controls.
- Added comprehensive unit and integration test coverage for advanced auth endpoints inside test_auth_advanced.py with 100% pass rates.
- Built a premium Flutter first-launch Onboarding Wizard screen supporting biometrics configuration, passkey triggers, and OTP setup slides.
- Complete implementation of Setu Account Aggregator service, Diffie-Hellman EC cryptographic key exchange, AES-GCM-256 decryption, and Sahamati mutual fund/equity asset parser framework.
- Built a multi-step Account Aggregator UI wizard tab inside the Flutter import holdings view with real-time status polling.
- Integrated World Bank APIs to fetch CPI Inflation and GDP growth rates cached via Redis.
- Added live Nifty 50 and Sensex tracking feeds via yfinance with sector classifications scheduler workers.
- Defined StructuredRecommendation Pydantic schema validation at the FastAPI service layer with fallback defaults.
- Updated LLM prompts to return risk_description, horizon, and confidence scoring.
- Injected yfinance news context into chat messages to contextualize assistant recommendations with live sentiment.
- Converted RecommendationScreen in Flutter to a ConsumerWidget dynamically binding all data metrics, expansion explainers, checkmarks, alternatives, and alert warning cards.
- Developed AdvancedAnalyticsEngine in the backend modeling stress tests (Repo rate hikes, Recession market crashes, Inflation spikes), Tax Loss Harvesting opportunities, Behavioral biases, and Milestone goal tracking.
- Created FastAPI route /copilot/advanced/{portfolio_id} returning the AdvancedAnalysisResponse schema.
- Added a comprehensive integration test test_advanced_analytics.py covering all mathematical tax offsets and scenario validations.
- Developed AdvancedAnalysisScreen in Flutter rendering tabs for Stress Tests, Tax Harvesting offsets, Behavioral Biases severity cards, and Wealth Goals linear progress bars.
- Designed custom circular HealthRingWidget and interactive custom-painter RiskGaugeWidget needle meter on the dashboard.
- Integrated relative multi-index fl_chart line plotting benchmarking Nifty 50 vs Sensex index growth changes.
- Developed dynamic top performance Winner and underperformance Underperformer cards inside dashboard views.
- Implemented vertical step EconomicCalendarWidget timeline rendering World Bank macro CPI Inflation, GDP, and RBI Repo policy events.
- Added DELETE /api/v1/auth/account endpoint on the backend handling profile and portfolio cascade deletions with unique email releasing logic.
- Implemented userProfileProvider to read and dynamically populate profile and security settings views.
- Developed interactive passkeys biometrics simulation flow requesting challenges and saving credentials.
- Integrated MFA TOTP setup wizard with backup code displays and 2FA disablement confirmation screens.
- Developed active sessions list rendering and device session revocation triggers.
- Wired secure storage API Key management for OpenAI and Anthropic model credentials.
- Created HiveCacheManager for local offline storage caching of API response payloads.
- Refactored userProfileProvider, portfoliosProvider, holdingsProvider, portfolioAnalyticsProvider, and marketOverviewProvider into StreamProviders supporting instant cached yields on dashboard startup.
- Implemented time-based cache TTL throttling (2 minutes) to skip redundant background API calls.
- Confirmed integration test coverage for OAuth, email OTP, TOTP MFA workflows, device listings/revocations, and passkey registration/verification.
- Added client widget tests in `screens_widget_test.dart` asserting visual layout parameters of `HealthRingWidget`, `RiskGaugeWidget`, `SettingsScreen`, and `AdvancedAnalysisScreen`.
- Configured viewport and device pixel ratio overrides inside the Flutter test suite ensuring complete offscreen widget compilation.
