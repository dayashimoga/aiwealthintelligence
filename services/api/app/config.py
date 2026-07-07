"""Application configuration using Pydantic Settings.

Supports environment variables, .env files, and sensible defaults.
All secrets are loaded from environment variables, never hardcoded.
"""

from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings with validation and type safety."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    # Application
    APP_NAME: str = "WealthAI"
    APP_ENV: Literal["development", "staging", "production"] = "development"
    APP_DEBUG: bool = True
    APP_SECRET_KEY: str = "change-me-to-a-random-secret-key-min-32-chars"
    APP_HOST: str = "0.0.0.0"  # nosec B104 — intentional: container/Docker binding
    APP_PORT: int = 8000
    APP_WORKERS: int = 4
    APP_LOG_LEVEL: str = "INFO"

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./data/wealthai.db"
    DATABASE_POOL_SIZE: int = 20
    DATABASE_MAX_OVERFLOW: int = 10

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    REDIS_CACHE_TTL: int = 3600

    # Authentication
    JWT_SECRET_KEY: str = "change-me-to-another-random-secret-key"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # AI Provider
    AI_PROVIDER: Literal["openai", "groq", "ollama", "anthropic"] = "openai"
    AI_API_KEY: str = ""
    AI_MODEL: str = "gpt-4o-mini"
    AI_EMBEDDING_MODEL: str = "text-embedding-3-small"
    AI_MAX_TOKENS: int = 4096
    AI_TEMPERATURE: float = 0.3
    OLLAMA_BASE_URL: str = "http://localhost:11434"
    OLLAMA_MODEL: str = "llama3.1"

    # Cloudflare
    CLOUDFLARE_ACCOUNT_ID: str = ""
    CLOUDFLARE_API_TOKEN: str = ""

    # SMTP Configuration
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USERNAME: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM: str = "noreply@wealthai.com"
    SMTP_USE_TLS: bool = True

    # Email CAS Auto-Import (IMAP)
    EMAIL_IMAP_HOST: str = ""  # e.g. imap.gmail.com
    EMAIL_IMAP_PORT: int = 993
    EMAIL_ADDRESS: str = ""  # mailbox to poll
    EMAIL_PASSWORD: str = ""  # app password / OAuth token
    EMAIL_CAS_FOLDER: str = "INBOX"  # IMAP folder to scan
    EMAIL_PDF_PASSWORD: str = ""  # CAS PDF decryption password (PAN-based)

    # Third Party Authentication
    GOOGLE_CLIENT_ID: str = ""
    APPLE_CLIENT_ID: str = ""

    # Setu Account Aggregator
    SETU_AA_CLIENT_ID: str = ""
    SETU_AA_CLIENT_SECRET: str = ""
    SETU_AA_BASE_URL: str = "https://fiiu-api.setu.co"

    # Market Data
    MARKET_DATA_PROVIDER: Literal["yahoo", "alpha_vantage", "polygon"] = "yahoo"

    # Observability
    OTEL_EXPORTER_OTLP_ENDPOINT: str = "http://localhost:4317"
    OTEL_SERVICE_NAME: str = "wealthai-api"

    # CORS
    CORS_ORIGINS: str = "http://localhost:8080,http://localhost:3000,http://localhost:5000"
    CORS_ALLOW_CREDENTIALS: bool = True

    # Rate Limiting
    RATE_LIMIT_PER_MINUTE: int = 60
    RATE_LIMIT_PER_HOUR: int = 1000

    @property
    def cors_origins_list(self) -> list[str]:
        """Parse CORS origins from comma-separated string."""
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]

    @property
    def is_production(self) -> bool:
        """Check if running in production environment."""
        return self.APP_ENV == "production"

    @property
    def is_sqlite(self) -> bool:
        """Check if using SQLite database."""
        return "sqlite" in self.DATABASE_URL


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance. Thread-safe singleton."""
    return Settings()
