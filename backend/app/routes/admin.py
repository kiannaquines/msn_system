from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..config import get_settings
from ..database import get_db
from ..dependencies import current_user, require_roles
from ..models import AuditLog, DeliveryFeeConfig, DeviceToken, Feedback, Order, User
from ..schemas import AdminUserCreate, AuditResponse, DeliveryFeeConfigPayload, DeviceCreate, FeedbackResponse, RiderResponse, RiderStatusRequest, UserResponse
from ..security import hash_password

router = APIRouter(tags=["administration"])


@router.post("/auth/bootstrap-admin", response_model=UserResponse, status_code=201)
def bootstrap_admin(
    payload: AdminUserCreate,
    x_bootstrap_token: str = Header(),
    db: Session = Depends(get_db),
) -> User:
    if payload.role != "admin" or x_bootstrap_token != get_settings().cron_secret:
        raise HTTPException(status_code=403, detail="Bootstrap denied")
    if db.scalar(select(func.count()).select_from(User).where(User.role == "admin")):
        raise HTTPException(status_code=409, detail="Administrator already exists")
    user = User(email=payload.email.lower(), password_hash=hash_password(payload.password), full_name=payload.full_name, phone=payload.phone, role="admin")
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/riders", response_model=UserResponse, status_code=201)
def create_operator(
    payload: AdminUserCreate,
    admin: User = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
) -> User:
    if db.scalar(select(User).where(User.email == payload.email.lower())):
        raise HTTPException(status_code=409, detail="Email is already registered")
    user = User(
        email=payload.email.lower(), password_hash=hash_password(payload.password), full_name=payload.full_name,
        phone=payload.phone, role=payload.role, rider_status="offline" if payload.role == "rider" else None,
    )
    db.add(user)
    db.flush()
    db.add(AuditLog(actor_id=admin.id, action=f"{payload.role}.created", target_type="user", target_id=user.id))
    db.commit()
    db.refresh(user)
    return user


@router.get("/riders", response_model=list[RiderResponse])
def list_riders(_: User = Depends(require_roles("admin")), db: Session = Depends(get_db)) -> list[dict]:
    riders = list(db.scalars(select(User).where(User.role == "rider").order_by(User.full_name)).all())
    result = []
    for rider in riders:
        active = db.scalar(select(Order).where(Order.rider_id == rider.id, Order.status.in_(["assigned", "picked_up", "on_the_way"])).limit(1))
        result.append({
            "id": rider.id, "name": rider.full_name, "full_name": rider.full_name,
            "phone": rider.phone, "status": rider.rider_status or "offline",
            "rider_status": rider.rider_status or "offline", "active_delivery_id": active.id if active else None,
            "is_active": rider.is_active,
        })
    return result


@router.patch("/riders/me/status", response_model=UserResponse)
@router.put("/riders/me/availability", response_model=UserResponse)
def update_rider_status(
    payload: RiderStatusRequest,
    rider: User = Depends(require_roles("rider")),
    db: Session = Depends(get_db),
) -> User:
    active = db.scalar(
        select(func.count())
        .select_from(Order)
        .where(Order.rider_id == rider.id, Order.status.in_(["assigned", "picked_up", "on_the_way"]))
    )
    if active and payload.status == "offline":
        raise HTTPException(status_code=409, detail="Cannot switch to offline while you have an active delivery.")
    rider.rider_status = "busy" if active else payload.status
    db.commit()
    db.refresh(rider)
    return rider


@router.patch("/riders/{rider_id}/status", response_model=UserResponse)
@router.put("/riders/{rider_id}/status", response_model=UserResponse)
def admin_update_rider_status(
    rider_id: str,
    payload: RiderStatusRequest,
    _: User = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
) -> User:
    rider = db.scalar(select(User).where(User.id == rider_id, User.role == "rider"))
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found")
    rider.rider_status = payload.status
    db.commit()
    db.refresh(rider)
    return rider


@router.post("/devices", status_code=201)
def register_device(payload: DeviceCreate, user: User = Depends(current_user), db: Session = Depends(get_db)) -> dict:
    existing = db.scalar(select(DeviceToken).where(DeviceToken.user_id == user.id, DeviceToken.token == payload.token))
    if existing:
        existing.platform = payload.platform
        token = existing
    else:
        token = DeviceToken(user_id=user.id, **payload.model_dump())
        db.add(token)
    db.commit()
    return {"id": token.id}


@router.get("/reports/summary")
def report_summary(_: User = Depends(require_roles("admin")), db: Session = Depends(get_db)) -> dict:
    total = db.scalar(select(func.count()).select_from(Order)) or 0
    delivered = db.scalar(select(func.count()).select_from(Order).where(Order.status == "delivered")) or 0
    sales = db.scalar(select(func.coalesce(func.sum(Order.total), 0)).where(Order.status == "delivered")) or 0
    cancelled = db.scalar(select(func.count()).select_from(Order).where(Order.status == "cancelled")) or 0
    return {"orders": total, "delivered": delivered, "cancelled": cancelled, "cod_sales": float(sales)}


@router.get("/feedback", response_model=list[FeedbackResponse])
def list_feedback(_: User = Depends(require_roles("admin")), db: Session = Depends(get_db)) -> list[Feedback]:
    return list(db.scalars(select(Feedback).order_by(Feedback.created_at.desc())).all())


@router.get("/audit", response_model=list[AuditResponse])
def list_audit(_: User = Depends(require_roles("admin")), db: Session = Depends(get_db)) -> list[AuditLog]:
    return list(db.scalars(select(AuditLog).order_by(AuditLog.created_at.desc())).all())


@router.put("/reports/delivery-fee")
def update_delivery_fee(
    payload: DeliveryFeeConfigPayload,
    admin: User = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
) -> dict:
    config = db.get(DeliveryFeeConfig, 1) or DeliveryFeeConfig(id=1)
    config.base_fee = payload.base_fee
    config.per_km_fee = payload.per_km_fee
    db.add(config)
    db.add(AuditLog(actor_id=admin.id, action="delivery_fee.updated", target_type="configuration", target_id="00000000-0000-0000-0000-000000000001"))
    db.commit()
    return payload.model_dump(mode="json")
