import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import HTTPException, status

from .config import get_settings


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    derived = hashlib.scrypt(password.encode(), salt=salt, n=2**14, r=8, p=1)
    return f"scrypt${salt.hex()}${derived.hex()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        algorithm, salt_hex, expected_hex = stored.split("$", 2)
        if algorithm != "scrypt":
            return False
        actual = hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt_hex), n=2**14, r=8, p=1)
        return hmac.compare_digest(actual.hex(), expected_hex)
    except (ValueError, TypeError):
        return False


def _jwt_material() -> tuple[str, str, str]:
    settings = get_settings()
    if settings.jwt_private_key and settings.jwt_public_key:
        return settings.jwt_private_key.replace("\\n", "\n"), settings.jwt_public_key.replace("\\n", "\n"), "RS256"
    if settings.app_env == "production":
        raise RuntimeError("JWT_PRIVATE_KEY and JWT_PUBLIC_KEY are required in production")
    return settings.jwt_dev_secret, settings.jwt_dev_secret, "HS256"


def create_access_token(user_id: str, role: str) -> str:
    signing_key, _, algorithm = _jwt_material()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user_id,
        "role": "authenticated",
        "business_role": role,
        "type": "access",
        "iat": now,
        "exp": now + timedelta(minutes=get_settings().access_token_minutes),
        "jti": secrets.token_hex(16),
    }
    return jwt.encode(payload, signing_key, algorithm=algorithm)


def decode_access_token(token: str) -> dict:
    _, verifying_key, algorithm = _jwt_material()
    try:
        payload = jwt.decode(token, verifying_key, algorithms=[algorithm])
        if payload.get("type") != "access":
            raise jwt.InvalidTokenError
        return payload
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired access token") from exc


def new_refresh_token() -> tuple[str, str]:
    token = secrets.token_urlsafe(48)
    return token, hashlib.sha256(token.encode()).hexdigest()


def refresh_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()
