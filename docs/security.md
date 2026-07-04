# Security Guide

## Overview

WealthAI implements security best practices following OWASP ASVS (Application Security Verification Standard) Level 2.

## Authentication

### Password Policy (OWASP ASVS V2)
- Minimum 8 characters
- Maximum 128 characters
- Must contain: uppercase, lowercase, digit, special character
- Passwords hashed with bcrypt (cost factor 12)

### JWT Tokens
- Access tokens: 30-minute expiry
- Refresh tokens: 30-day expiry
- Signed with HS256
- Includes JTI (JWT ID) for revocation support
- Token type validation (access vs refresh)

### Role-Based Access Control (RBAC)
| Role | Permissions |
|------|------------|
| `admin` | Full access to all resources |
| `premium` | AI recommendations, advanced analytics |
| `user` | Portfolio management, basic analytics |

## API Security

### Rate Limiting
- 60 requests per minute per IP
- 1000 requests per hour per IP
- Configurable per endpoint

### Security Headers (OWASP)
| Header | Value | Purpose |
|--------|-------|---------|
| `X-Content-Type-Options` | nosniff | Prevent MIME sniffing |
| `X-Frame-Options` | DENY | Prevent clickjacking |
| `X-XSS-Protection` | 1; mode=block | XSS protection |
| `Referrer-Policy` | strict-origin-when-cross-origin | Control referrer |
| `Content-Security-Policy` | Configured | Prevent XSS/injection |
| `Strict-Transport-Security` | max-age=31536000 | Force HTTPS |
| `Permissions-Policy` | Restricted | Limit API access |

### Input Validation
- All request bodies validated with Pydantic schemas
- Email validation using `EmailStr`
- String length limits on all fields
- Numeric range validation
- SQL injection prevented by SQLAlchemy ORM

### Audit Logging
All security-relevant events are logged:
- User registration/login
- Failed authentication attempts
- Portfolio creation/deletion
- Data export operations

## Dependency Security

### CI/CD Scanning
- Trivy vulnerability scanning on every push
- Bandit static security analysis for Python
- SBOM (Software Bill of Materials) generation
- License scanning

### Secrets Management
- All secrets via environment variables
- `.env` files excluded from version control
- GitHub Secrets for CI/CD
- No hardcoded credentials

## Data Protection

### Encryption
- HTTPS enforced via HSTS
- Passwords bcrypt-hashed (never stored in plaintext)
- JWT tokens signed, not encrypted (no sensitive data in payload)

### Data Isolation
- All queries scoped to authenticated user
- Portfolio data isolated by user_id foreign key
- Cascade deletes prevent orphaned data

## Reporting Vulnerabilities

If you discover a security vulnerability, please report it responsibly:
1. **Do NOT** open a public GitHub issue
2. Email: security@wealthai.app
3. Include: description, reproduction steps, impact assessment
4. We will respond within 48 hours
