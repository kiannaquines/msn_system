from functools import lru_cache

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "development"
    database_url: str = "sqlite:///./mns.db"
    direct_database_url: str | None = None
    jwt_private_key: str | None = Field(default=None, validation_alias=AliasChoices("JWT_SIGNING_PRIVATE_KEY", "JWT_PRIVATE_KEY"))
    jwt_public_key: str | None = Field(default=None, validation_alias=AliasChoices("JWT_VERIFYING_PUBLIC_KEY", "JWT_PUBLIC_KEY"))
    jwt_dev_secret: str = Field(default="development-only-secret-change-me-123", min_length=32)
    access_token_minutes: int = 30
    refresh_token_days: int = 30
    supabase_url: str | None = None
    supabase_secret_key: str | None = None
    mapbox_secret_token: str | None = None
    firebase_service_account_b64: str | None = None
    allowed_origins: str = "http://localhost:3000"
    cron_secret: str = "development-cron-secret"

    @property
    def cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.allowed_origins.split(",") if origin.strip()]

    def production_configuration_errors(self) -> list[str]:
        if self.app_env != "production":
            return []
        required = {
            "DATABASE_URL": self.database_url if not self.database_url.startswith("sqlite") else None,
            "DIRECT_DATABASE_URL": self.direct_database_url,
            "SUPABASE_URL": self.supabase_url,
            "SUPABASE_SECRET_KEY": self.supabase_secret_key,
            "MAPBOX_SECRET_TOKEN": self.mapbox_secret_token,
            "FIREBASE_SERVICE_ACCOUNT_B64": self.firebase_service_account_b64,
            "JWT_SIGNING_PRIVATE_KEY": self.jwt_private_key,
            "JWT_VERIFYING_PUBLIC_KEY": self.jwt_public_key,
            "ALLOWED_ORIGINS": self.allowed_origins if self.cors_origins else None,
            "CRON_SECRET": self.cron_secret if len(self.cron_secret) >= 16 and self.cron_secret != "development-cron-secret" else None,
        }
        return [name for name, value in required.items() if not value]


@lru_cache
def get_settings() -> Settings:
    return Settings()
