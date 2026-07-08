.PHONY: help setup setup-backend setup-flutter test test-backend test-flutter test-docker lint format build run clean docker-up docker-down migrate build-android-docker build-web-docker

# ========================
# Variables
# ========================
PYTHON := python
PIP := pip
FLUTTER := flutter
DOCKER_COMPOSE := docker compose
API_DIR := services/api
FLUTTER_DIR := apps/web

# ========================
# Help
# ========================
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ========================
# Setup
# ========================
setup: setup-backend setup-flutter ## Setup entire project

setup-backend: ## Setup Python backend
	cd $(API_DIR) && $(PYTHON) -m venv .venv && \
	.venv/Scripts/activate && \
	$(PIP) install -e ".[dev]"

setup-flutter: ## Setup Flutter app
	cd $(FLUTTER_DIR) && $(FLUTTER) pub get && \
	dart run build_runner build --delete-conflicting-outputs

# ========================
# Development
# ========================
run: ## Run all services
	$(DOCKER_COMPOSE) up -d db redis
	cd $(API_DIR) && .venv/Scripts/activate && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000 &
	cd $(FLUTTER_DIR) && $(FLUTTER) run -d chrome --web-port 8080

run-backend: ## Run backend only
	cd $(API_DIR) && .venv/Scripts/activate && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

run-flutter: ## Run Flutter web
	cd $(FLUTTER_DIR) && $(FLUTTER) run -d chrome --web-port 8080

# ========================
# Testing
# ========================
test: test-backend test-flutter ## Run all tests

test-backend: ## Run backend tests (local venv)
	cd $(API_DIR) && .venv/Scripts/activate && pytest --cov=app --cov-report=term-missing --cov-fail-under=65

test-flutter: ## Run Flutter tests
	cd $(FLUTTER_DIR) && $(FLUTTER) test --coverage

test-integration: ## Run integration tests
	$(DOCKER_COMPOSE) -f docker-compose.yml up -d
	cd $(API_DIR) && pytest tests/integration/ -v
	$(DOCKER_COMPOSE) down

# Docker-based tests (no local Python/Flutter needed)
test-docker: ## Run backend tests via Docker (no local Python needed)
	docker build -f infra/docker/Dockerfile.api-test -t wealthai-api-test . && \
	docker run --rm \
		-v $(CURDIR)/services/api:/app \
		-e APP_ENV=development \
		"-e=DATABASE_URL=sqlite+aiosqlite:///:memory:" \
		-e JWT_SECRET_KEY=test-secret \
		-e AI_API_KEY=test-key \
		-e REDIS_URL= \
		wealthai-api-test python -m pytest tests/ --tb=short -q --cov=app --cov-report=term-missing

build-android-docker: ## Build Android APK via Docker (no local Flutter needed)
	$(DOCKER_COMPOSE) --profile build run --rm flutter flutter build apk --debug

build-web-docker: ## Build Flutter web via Docker (no local Flutter needed)
	$(DOCKER_COMPOSE) --profile build run --rm flutter flutter build web --release

# ========================
# Code Quality
# ========================
lint: lint-backend lint-flutter ## Run all linters

lint-backend: ## Lint Python
	cd $(API_DIR) && ruff check .

lint-flutter: ## Lint Flutter
	cd $(FLUTTER_DIR) && $(FLUTTER) analyze

format: format-backend format-flutter ## Format all code

format-backend: ## Format Python
	cd $(API_DIR) && ruff format .

format-flutter: ## Format Flutter
	cd $(FLUTTER_DIR) && dart format .

# ========================
# Database
# ========================
migrate: ## Run database migrations
	cd $(API_DIR) && alembic upgrade head

migrate-create: ## Create a new migration (usage: make migrate-create MSG="description")
	cd $(API_DIR) && alembic revision --autogenerate -m "$(MSG)"

migrate-rollback: ## Rollback last migration
	cd $(API_DIR) && alembic downgrade -1

# ========================
# Build
# ========================
build: build-backend build-flutter ## Build everything

build-backend: ## Build backend Docker image
	docker build -f infra/docker/Dockerfile.api -t wealthai-api .

build-flutter: ## Build Flutter web
	cd $(FLUTTER_DIR) && $(FLUTTER) build web --release --web-renderer canvaskit

build-android: ## Build Android APK + AAB
	cd $(FLUTTER_DIR) && $(FLUTTER) build apk --release && $(FLUTTER) build appbundle --release

build-ios: ## Build iOS archive
	cd $(FLUTTER_DIR) && $(FLUTTER) build ios --release --no-codesign

# ========================
# Docker
# ========================
docker-up: ## Start all Docker services
	$(DOCKER_COMPOSE) up -d

docker-down: ## Stop all Docker services
	$(DOCKER_COMPOSE) down

docker-logs: ## View Docker logs
	$(DOCKER_COMPOSE) logs -f

docker-clean: ## Clean Docker resources
	$(DOCKER_COMPOSE) down -v --rmi local

# ========================
# Cleanup
# ========================
clean: ## Clean all build artifacts
	cd $(API_DIR) && rm -rf __pycache__ .pytest_cache .ruff_cache htmlcov .coverage
	cd $(FLUTTER_DIR) && $(FLUTTER) clean
	rm -rf build/ dist/
