from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import get_settings
from ..database import get_db
from ..dependencies import current_user
from ..models import RefreshSession, User, now
from ..schemas import LoginRequest, RefreshRequest, RegisterRequest, TokenResponse, UserResponse
from ..security import create_access_token, hash_password, new_refresh_token, refresh_hash, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


def issue_tokens(db: Session, user: User) -> TokenResponse:
    raw, hashed = new_refresh_token()
    db.add(
        RefreshSession(
            user_id=user.id,
            token_hash=hashed,
            expires_at=datetime.now(timezone.utc) + timedelta(days=get_settings().refresh_token_days),
        )
    )
    db.commit()
    return TokenResponse(access_token=create_access_token(user.id, user.role), refresh_token=raw, role=user.role)


@router.post("/register", response_model=TokenResponse, status_code=201)
def register(payload: RegisterRequest, db: Session = Depends(get_db)) -> TokenResponse:
    email = payload.email.lower()
    if db.scalar(select(User).where(User.email == email)):
        raise HTTPException(status_code=409, detail="Email is already registered")
    user = User(
        email=email,
        password_hash=hash_password(payload.password),
        full_name=payload.full_name,
        phone=payload.phone,
        role="customer",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return issue_tokens(db, user)


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    user = db.scalar(select(User).where(User.email == payload.email.lower()))
    if not user or not user.is_active or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    return issue_tokens(db, user)


@router.post("/refresh", response_model=TokenResponse)
def refresh(payload: RefreshRequest, db: Session = Depends(get_db)) -> TokenResponse:
    session = db.scalar(select(RefreshSession).where(RefreshSession.token_hash == refresh_hash(payload.refresh_token)))
    expires_at = session.expires_at.replace(tzinfo=timezone.utc) if session and session.expires_at.tzinfo is None else (session.expires_at if session else None)
    if not session or session.revoked_at or not expires_at or expires_at <= datetime.now(timezone.utc):
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    user = db.get(User, session.user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="Account is unavailable")
    session.revoked_at = now()
    db.commit()
    return issue_tokens(db, user)


@router.post("/logout", status_code=204)
def logout(payload: RefreshRequest, _: User = Depends(current_user), db: Session = Depends(get_db)) -> None:
    session = db.scalar(select(RefreshSession).where(RefreshSession.token_hash == refresh_hash(payload.refresh_token)))
    if session and not session.revoked_at:
        session.revoked_at = now()
        db.commit()


@router.get("/me", response_model=UserResponse)
def me(user: User = Depends(current_user)) -> User:
    return user
