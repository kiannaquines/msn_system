import hmac
import json
from datetime import datetime, timezone

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.orm import Session

from .config import get_settings
from .database import get_db
from .routes import admin, auth, catalog, orders, uploads

settings = get_settings()
app = FastAPI(title="M&S Delivery API", version="1.0.0", openapi_url="/api/openapi.json", docs_url="/api/docs")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?$" if settings.app_env != "production" else None,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

for router in (auth.router, catalog.router, orders.router, admin.router, uploads.router):
    app.include_router(router, prefix="/api/v1")


@app.get("/api/health/live", tags=["health"])
def live() -> dict:
    return {"status": "ok"}


@app.get("/api/health/ready", tags=["health"])
def ready(db: Session = Depends(get_db)) -> dict:
    try:
        db.execute(text("SELECT 1"))
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    missing = settings.production_configuration_errors()
    if missing:
        raise HTTPException(status_code=503, detail={"missing_configuration": missing})
    return {"status": "ready"}


@app.get("/api/v1/internal/outbox/process", tags=["internal"])
def process_outbox(authorization: str | None = Header(default=None), db: Session = Depends(get_db)) -> dict:
    expected = f"Bearer {settings.cron_secret}"
    if authorization is None or not hmac.compare_digest(authorization, expected):
        raise HTTPException(status_code=401, detail="Invalid cron authorization")
    from .integrations import send_push_notifications
    from .models import DeviceToken, Order, OutboxEvent, User
    from sqlalchemy import select

    pending = list(db.scalars(select(OutboxEvent).where(OutboxEvent.processed_at.is_(None)).limit(100)).all())
    processed = 0
    failed = 0
    for event in pending:
        event.attempts += 1
        try:
            payload = json.loads(event.payload_json)
            order = db.get(Order, event.aggregate_id)
            if not order or event.event_type == "location.updated":
                event.processed_at = datetime.now(timezone.utc)
                processed += 1
                continue

            recipient_ids: set[str] = {order.customer_id}
            if event.event_type == "order.created":
                recipient_ids = set(db.scalars(select(User.id).where(User.role == "admin", User.is_active.is_(True))).all())
            elif order.rider_id:
                recipient_ids.add(order.rider_id)
            tokens = list(db.scalars(select(DeviceToken.token).where(DeviceToken.user_id.in_(recipient_ids))).all()) if recipient_ids else []
            title = "M&S Delivery update"
            body = f"Order {order.id[:8]} is now {order.status.replace('_', ' ')}."
            send_push_notifications(tokens, title, body, {"type": event.event_type, "order_id": order.id, "status": order.status})
            event.processed_at = datetime.now(timezone.utc)
            processed += 1
        except Exception:
            failed += 1
    db.commit()
    return {"pending": len(pending), "processed": processed, "failed": failed}
