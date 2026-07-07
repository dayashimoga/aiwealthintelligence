# WealthAI — API Reference

> Base URL: `http://localhost:8000/api/v1` (dev) | `https://api.wealthai.app/api/v1` (prod)
> All authenticated endpoints require: `Authorization: Bearer <access_token>`

---

## Authentication

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/register` | No | Register with email/password |
| POST | `/auth/login` | No | Login → returns access+refresh tokens |
| POST | `/auth/refresh` | No | Refresh access token |
| GET | `/auth/me` | Yes | Get current user profile |
| POST | `/auth/oauth-login` | No | Google/Apple OAuth login |
| POST | `/auth/otp/send` | No | Send OTP to email |
| POST | `/auth/otp/verify` | No | Verify OTP → returns tokens |
| POST | `/auth/mfa/totp/setup` | Yes | Generate TOTP QR code |
| POST | `/auth/mfa/totp/enable` | Yes | Enable TOTP with verification code |
| POST | `/auth/mfa/totp/disable` | Yes | Disable TOTP |
| GET | `/auth/devices` | Yes | List trusted devices |
| DELETE | `/auth/devices/{device_id}` | Yes | Revoke a device |
| POST | `/auth/onboarding/complete` | Yes | Mark onboarding complete |
| POST | `/auth/passkeys/register/options` | Yes | WebAuthn registration options |
| POST | `/auth/passkeys/register/verify` | Yes | Verify passkey registration |
| POST | `/auth/passkeys/login/options` | No | WebAuthn login options |
| POST | `/auth/passkeys/login/verify` | No | Verify passkey login |
| DELETE | `/auth/account` | Yes | Delete account |

## Portfolios

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/portfolios` | Yes | List all portfolios |
| POST | `/portfolios` | Yes | Create portfolio |
| GET | `/portfolios/{id}` | Yes | Get portfolio |
| PATCH | `/portfolios/{id}` | Yes | Update portfolio |
| DELETE | `/portfolios/{id}` | Yes | Delete portfolio |
| GET | `/portfolios/{id}/analytics` | Yes | Portfolio analytics (value, P&L, CAGR, XIRR, allocation) |

## Holdings

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/portfolios/{id}/holdings` | Yes | List holdings |
| POST | `/portfolios/{id}/holdings` | Yes | Add holding manually |
| PATCH | `/portfolios/{id}/holdings/{hid}` | Yes | Update holding |
| DELETE | `/portfolios/{id}/holdings/{hid}` | Yes | Delete holding |
| POST | `/portfolios/{id}/import/cas-pdf` | Yes | Import CAS PDF (multipart) |
| POST | `/portfolios/{id}/import/broker` | Yes | Import broker CSV (multipart) |
| POST | `/portfolios/{id}/consent` | Yes | Initiate Account Aggregator consent |
| GET | `/portfolios/{id}/consent/status/{handle}` | Yes | Check consent status |

## AI Copilot

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/ai/chat` | Yes | Natural language portfolio chat |
| GET | `/ai/recommendations/{pid}/{hid}` | Yes | AI recommendation for a holding |
| GET | `/copilot/brief/{pid}` | Yes | Daily AI brief |
| GET | `/copilot/portfolio-doctor/{pid}` | Yes | Portfolio health diagnosis |
| POST | `/copilot/scenario/{pid}` | Yes | Scenario simulation |
| GET | `/copilot/advanced/{pid}` | Yes | Advanced analysis (stress, tax, bias, goals) |
| GET | `/copilot/sector-rotation/{pid}` | Yes | Sector rotation analysis |
| GET | `/copilot/dividend-planner/{pid}` | Yes | Dividend income planning |
| GET | `/copilot/opportunity-radar/{pid}` | Yes | Opportunity detection |

## Market

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/market/overview` | Yes | Full market overview (news, sectors, indices, macro) |
| GET | `/market/news` | Yes | Market news with sentiment |
| GET | `/market/sectors` | Yes | Sector performance rankings |

## Notifications

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/notifications` | Yes | List notifications (query: `unread_only`, `limit`) |
| GET | `/notifications/count` | Yes | Unread count |
| POST | `/notifications/{id}/read` | Yes | Mark as read |
| POST | `/notifications/read-all` | Yes | Mark all as read |

## Goals

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/goals` | Yes | List goals (query: `active_only`) |
| POST | `/goals` | Yes | Create goal |
| PUT | `/goals/{id}` | Yes | Update goal |
| DELETE | `/goals/{id}` | Yes | Delete goal |

## Watchlists

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/watchlists` | Yes | List watchlists |
| POST | `/watchlists` | Yes | Create watchlist |
| DELETE | `/watchlists/{id}` | Yes | Delete watchlist |
| POST | `/watchlists/{id}/symbols` | Yes | Add symbol with alerts |
| DELETE | `/watchlists/{id}/symbols/{symbol}` | Yes | Remove symbol |
| GET | `/watchlists/{id}/intelligence` | Yes | AI intelligence for watchlist symbols |

## Health

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/health` | No | Health check |

---

## Common Response Formats

### Success
```json
{ "data": {...} }
```

### Error
```json
{
  "error": "Human-readable message",
  "error_code": "MACHINE_CODE",
  "details": {}
}
```

### Auth Tokens Response
```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "bearer",
  "expires_in": 1800
}
```
