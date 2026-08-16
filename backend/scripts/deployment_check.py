"""Validate production configuration without printing secret values."""

import base64
import json
import sys
from urllib.parse import urlparse

import jwt
from sqlalchemy.engine import make_url

from app.config import Settings


def check() -> list[str]:
    settings = Settings()
    errors: list[str] = []
    if settings.app_env != "production":
        errors.append("APP_ENV must be production")
    errors.extend(f"{name} is missing or unsafe" for name in settings.production_configuration_errors())

    try:
        runtime_url = make_url(settings.database_url)
        if runtime_url.drivername not in {"postgresql+psycopg", "postgresql"}:
            errors.append("DATABASE_URL must use PostgreSQL with psycopg")
        if runtime_url.port != 6543:
            errors.append("DATABASE_URL must use the Supavisor transaction pooler on port 6543")
    except Exception:
        errors.append("DATABASE_URL is not a valid SQLAlchemy URL")

    try:
        direct_url = make_url(settings.direct_database_url or "")
        if direct_url.drivername not in {"postgresql+psycopg", "postgresql"}:
            errors.append("DIRECT_DATABASE_URL must use PostgreSQL")
        if direct_url.port == 6543:
            errors.append("DIRECT_DATABASE_URL must not use transaction-pooler port 6543")
    except Exception:
        errors.append("DIRECT_DATABASE_URL is not a valid SQLAlchemy URL")

    if settings.supabase_url:
        parsed = urlparse(settings.supabase_url)
        if parsed.scheme != "https" or not parsed.netloc:
            errors.append("SUPABASE_URL must be an HTTPS URL")

    for origin in settings.cors_origins:
        if origin == "*" or not origin.startswith("https://"):
            errors.append("ALLOWED_ORIGINS must contain only explicit HTTPS origins in production")
            break

    if settings.jwt_private_key and settings.jwt_public_key:
        try:
            token = jwt.encode({"sub": "deployment-check"}, settings.jwt_private_key.replace("\\n", "\n"), algorithm="RS256")
            jwt.decode(token, settings.jwt_public_key.replace("\\n", "\n"), algorithms=["RS256"])
        except Exception:
            errors.append("JWT signing and verification keys are not a valid matching RSA pair")

    if settings.firebase_service_account_b64:
        try:
            service_account = json.loads(base64.b64decode(settings.firebase_service_account_b64, validate=True))
            if not {"project_id", "client_email", "private_key"}.issubset(service_account):
                errors.append("FIREBASE_SERVICE_ACCOUNT_B64 lacks required service-account fields")
        except Exception:
            errors.append("FIREBASE_SERVICE_ACCOUNT_B64 is not valid base64-encoded JSON")

    return list(dict.fromkeys(errors))


if __name__ == "__main__":
    failures = check()
    if failures:
        print("Deployment configuration failed:")
        for failure in failures:
            print(f"- {failure}")
        sys.exit(1)
    print("Deployment configuration passed; no secret values were printed.")
