# Deployment Guide

## Zero-Cost Deployment (Cloudflare Pages)

### Prerequisites
- GitHub account with repository pushed
- Cloudflare account (free tier)

### Step 1: Set up Cloudflare Pages

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com) → Pages
2. Click "Create a project" → "Connect to Git"
3. Select your repository
4. Configure build settings:
   - **Build command**: `cd apps/web && flutter build web --release --web-renderer canvaskit`
   - **Build output directory**: `apps/web/build/web`
   - **Root directory**: `/`
5. Add environment variables:
   - `FLUTTER_VERSION`: `3.24.0`

### Step 2: Configure GitHub Actions (Automated)

Add these secrets to your GitHub repository:
- `CLOUDFLARE_API_TOKEN`: Your Cloudflare API token
- `CLOUDFLARE_ACCOUNT_ID`: Your Cloudflare account ID

The deploy workflow (`.github/workflows/deploy.yml`) will automatically:
- Build Flutter Web on every push to `main`
- Deploy to Cloudflare Pages
- Create preview deployments for PRs

### Step 3: Custom Domain (Optional)

1. In Cloudflare Pages project settings
2. Click "Custom domains" → Add domain
3. Follow DNS configuration instructions

## Backend Deployment

### Option 1: Fly.io (Free Tier)

```bash
# Install flyctl
curl -L https://fly.io/install.sh | sh

# Login and deploy
fly auth login
fly launch --name wealthai-api
fly deploy
```

### Option 2: Railway

1. Connect GitHub repository
2. Set root directory to `services/api`
3. Configure environment variables from `.env.example`
4. Deploy

### Option 3: Docker (Self-hosted)

```bash
# Build
docker compose -f docker-compose.yml build

# Deploy
docker compose -f docker-compose.yml up -d

# Check health
curl http://localhost:8000/api/v1/health
```

## Database Migration

```bash
cd services/api

# Create initial migration
alembic revision --autogenerate -m "Initial schema"

# Apply migrations
alembic upgrade head

# Rollback
alembic downgrade -1
```

## Environment Variables

See `.env.example` for all configuration options. Critical variables:

| Variable | Required | Description |
|----------|----------|-------------|
| `APP_SECRET_KEY` | Yes | 32+ char random string |
| `JWT_SECRET_KEY` | Yes | 32+ char random string |
| `DATABASE_URL` | Yes | Database connection string |
| `AI_API_KEY` | For AI | AI provider API key |
| `AI_PROVIDER` | No | `openai`, `groq`, `ollama` |

## Monitoring

### Health Check
```bash
curl http://localhost:8000/api/v1/health
```

### Prometheus Metrics
Access at: http://localhost:9090 (with observability profile)

### Grafana Dashboards
Access at: http://localhost:3001 (admin/admin)

```bash
# Start with observability stack
docker compose --profile observability up -d
```
