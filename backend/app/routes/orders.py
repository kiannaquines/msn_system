import json
from datetime import datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from ..database import get_db
from ..dependencies import current_user, require_roles
from ..integrations import route_distance_km, route_metrics
from ..models import (
    Address,
    AuditLog,
    DeliveryEvent,
    DeliveryFeeConfig,
    Feedback,
    IdempotencyRecord,
    LocationPoint,
    MenuItem,
    Order,
    OrderItem,
    OutboxEvent,
    Store,
    User,
)
from ..schemas import AssignRequest, DeliveryResponse, FeedbackCreate, LocationCreate, LocationResponse, OrderCreate, OrderResponse, StatusRequest

router = APIRouter(tags=["orders"])
ACTIVE_STATUSES = {"assigned", "picked_up", "on_the_way"}
TRANSITIONS = {
    "pending": {"confirmed", "cancelled"},
    "confirmed": {"assigned", "cancelled"},
    "assigned": {"picked_up", "cancelled"},
    "picked_up": {"on_the_way", "cancelled"},
    "on_the_way": {"delivered", "cancelled"},
    "delivered": set(),
    "cancelled": set(),
}


def load_order(db: Session, order_id: str) -> Order:
    order = db.scalar(select(Order).options(selectinload(Order.items)).where(Order.id == order_id))
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


def assert_order_access(order: Order, user: User) -> None:
    if user.role == "admin":
        return
    if user.role == "customer" and order.customer_id == user.id:
        return
    if user.role == "rider" and order.rider_id == user.id:
        return
    raise HTTPException(status_code=403, detail="Order is not accessible")


def queue_event(db: Session, order: Order, event_type: str) -> None:
    db.add(
        OutboxEvent(
            event_type=event_type,
            aggregate_id=order.id,
            payload_json=json.dumps({"order_id": order.id, "status": order.status, "rider_id": order.rider_id}),
        )
    )


@router.post("/orders", response_model=OrderResponse, status_code=201)
def create_order(
    payload: OrderCreate,
    idempotency_key: str = Header(min_length=8, max_length=100, alias="Idempotency-Key"),
    customer: User = Depends(require_roles("customer")),
    db: Session = Depends(get_db),
) -> OrderResponse:
    replay = db.scalar(
        select(IdempotencyRecord).where(
            IdempotencyRecord.user_id == customer.id,
            IdempotencyRecord.key == idempotency_key,
            IdempotencyRecord.scope == "orders.create",
        )
    )
    if replay:
        return OrderResponse.model_validate_json(replay.response_json)

    store = db.get(Store, payload.store_id)
    address = db.get(Address, payload.address_id)
    if not store or not store.is_active:
        raise HTTPException(status_code=404, detail="Store not found")
    if not address or address.customer_id != customer.id:
        raise HTTPException(status_code=404, detail="Address not found")

    requested_ids = {line.menu_item_id for line in payload.items}
    menu = {
        item.id: item
        for item in db.scalars(
            select(MenuItem).where(MenuItem.id.in_(requested_ids), MenuItem.store_id == store.id, MenuItem.is_available.is_(True))
        ).all()
    }
    if set(menu) != requested_ids:
        raise HTTPException(status_code=422, detail="Every item must be available from the selected store")

    subtotal = sum((Decimal(str(menu[line.menu_item_id].price)) * line.quantity for line in payload.items), Decimal("0"))
    distance = route_distance_km((store.latitude, store.longitude), (address.latitude, address.longitude))
    fee_config = db.get(DeliveryFeeConfig, 1) or DeliveryFeeConfig(id=1, base_fee=Decimal("40.00"), per_km_fee=Decimal("5.00"))
    db.add(fee_config)
    fee = (Decimal(str(fee_config.base_fee)) + Decimal(str(fee_config.per_km_fee)) * Decimal(str(distance))).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    order = Order(
        customer_id=customer.id,
        store_id=store.id,
        address_id=address.id,
        subtotal=subtotal,
        delivery_fee=fee,
        total=subtotal + fee,
        route_distance_km=distance,
    )
    order.items = [
        OrderItem(
            menu_item_id=line.menu_item_id,
            name_snapshot=menu[line.menu_item_id].name,
            unit_price=menu[line.menu_item_id].price,
            quantity=line.quantity,
        )
        for line in payload.items
    ]
    db.add(order)
    db.flush()
    db.add(DeliveryEvent(order_id=order.id, status="pending", actor_id=customer.id))
    response = OrderResponse.model_validate(order)
    db.add(
        IdempotencyRecord(
            user_id=customer.id,
            key=idempotency_key,
            scope="orders.create",
            response_json=response.model_dump_json(),
        )
    )
    queue_event(db, order, "order.created")
    db.commit()
    return response


@router.get("/orders", response_model=list[OrderResponse])
def list_orders(user: User = Depends(current_user), db: Session = Depends(get_db)) -> list[Order]:
    query = select(Order).options(selectinload(Order.items)).order_by(Order.created_at.desc())
    if user.role == "customer":
        query = query.where(Order.customer_id == user.id)
    elif user.role == "rider":
        query = query.where(Order.rider_id == user.id)
    return list(db.scalars(query).all())


@router.get("/orders/{order_id}", response_model=OrderResponse)
def get_order(order_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)) -> Order:
    order = load_order(db, order_id)
    assert_order_access(order, user)
    return order


def delivery_response(db: Session, order: Order) -> DeliveryResponse:
    store = db.get(Store, order.store_id)
    customer = db.get(User, order.customer_id)
    address = db.get(Address, order.address_id)
    location = db.scalar(select(LocationPoint).where(LocationPoint.order_id == order.id).order_by(LocationPoint.captured_at.desc()).limit(1))
    # Guard: skip ETA calculation if coordinates are unavailable
    if location:
        origin = (location.latitude, location.longitude)
    elif store and store.latitude is not None:
        origin = (store.latitude, store.longitude)
    else:
        origin = None
    has_dest = address and address.latitude is not None and address.longitude is not None
    eta_minutes = route_metrics(origin, (address.latitude, address.longitude))[1] if (
        order.status in ACTIVE_STATUSES and origin and has_dest
    ) else None
    return DeliveryResponse(
        id=order.id,
        order_id=order.id,
        status=order.status,
        rider_id=order.rider_id,
        store_name=store.name if store else "Unknown Store",
        customer_name=customer.full_name if customer else "Unknown Customer",
        rider_name=db.get(User, order.rider_id).full_name if order.rider_id else None,
        delivery_address=address.line1 if address else "Unknown Address",
        pickup_latitude=store.latitude if store else None,
        pickup_longitude=store.longitude if store else None,
        destination_latitude=address.latitude if address else None,
        destination_longitude=address.longitude if address else None,
        total=order.total,
        payment_status=order.payment_status,
        latitude=location.latitude if location else None,
        longitude=location.longitude if location else None,
        eta_minutes=eta_minutes,
        last_location_at=location.captured_at if location else None,
    )


@router.get("/deliveries", response_model=list[DeliveryResponse])
def list_deliveries(user: User = Depends(current_user), db: Session = Depends(get_db)) -> list[DeliveryResponse]:
    query = select(Order).where(Order.status.in_(["assigned", "picked_up", "on_the_way", "delivered"]))
    if user.role == "customer":
        query = query.where(Order.customer_id == user.id)
    elif user.role == "rider":
        query = query.where(Order.rider_id == user.id)
    results = []
    for order in db.scalars(query.order_by(Order.updated_at.desc())).all():
        try:
            results.append(delivery_response(db, order))
        except Exception:
            pass  # Skip orders with corrupt/missing FK data
    return results


@router.get("/deliveries/{order_id}", response_model=DeliveryResponse)
def get_delivery(order_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)) -> DeliveryResponse:
    order = load_order(db, order_id)
    assert_order_access(order, user)
    return delivery_response(db, order)


@router.post("/orders/{order_id}/assign", response_model=OrderResponse)
def assign_order(
    order_id: str,
    payload: AssignRequest,
    admin: User = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
) -> Order:
    order = load_order(db, order_id)
    rider = db.get(User, payload.rider_id)
    if order.status != "confirmed":
        raise HTTPException(status_code=409, detail="Only confirmed orders can be assigned")
    if not rider or rider.role != "rider" or not rider.is_active or rider.rider_status != "available":
        raise HTTPException(status_code=422, detail="Rider is not available")
    active = db.scalar(select(func.count()).select_from(Order).where(Order.rider_id == rider.id, Order.status.in_(ACTIVE_STATUSES)))
    if active:
        raise HTTPException(status_code=409, detail="Rider already has an active delivery")
    order.rider_id = rider.id
    order.status = "assigned"
    rider.rider_status = "busy"
    db.add_all([
        DeliveryEvent(order_id=order.id, status="assigned", actor_id=admin.id),
        AuditLog(actor_id=admin.id, action="order.assigned", target_type="order", target_id=order.id),
    ])
    queue_event(db, order, "delivery.status_changed")
    db.commit()
    db.refresh(order)
    return order


@router.post("/orders/{order_id}/status", response_model=OrderResponse)
@router.post("/deliveries/{order_id}/status", response_model=OrderResponse)
def update_order_status(
    order_id: str,
    payload: StatusRequest,
    idempotency_key: str = Header(min_length=8, max_length=100, alias="Idempotency-Key"),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
) -> Order:
    order = load_order(db, order_id)
    assert_order_access(order, user)
    replay = db.scalar(select(IdempotencyRecord).where(IdempotencyRecord.user_id == user.id, IdempotencyRecord.key == idempotency_key, IdempotencyRecord.scope == f"status.{order_id}"))
    if replay:
        return order
    if payload.status not in TRANSITIONS[order.status]:
        raise HTTPException(status_code=409, detail=f"Cannot transition from {order.status} to {payload.status}")
    if user.role == "customer" and payload.status != "cancelled":
        raise HTTPException(status_code=403, detail="Customers may only cancel eligible orders")
    if user.role == "rider" and (order.rider_id != user.id or payload.status not in {"picked_up", "on_the_way", "delivered"}):
        raise HTTPException(status_code=403, detail="Rider cannot perform this transition")
    if user.role == "admin" and payload.status == "assigned":
        raise HTTPException(status_code=422, detail="Use the assignment endpoint")
    if payload.status == "cancelled" and user.role == "admin" and not payload.reason:
        raise HTTPException(status_code=422, detail="An audit reason is required")

    order.status = payload.status
    if payload.status in {"delivered", "cancelled"} and order.rider_id:
        rider = db.get(User, order.rider_id)
        if rider:
            rider.rider_status = "available"
    db.add(DeliveryEvent(order_id=order.id, status=payload.status, actor_id=user.id))
    if payload.status == "cancelled":
        db.add(AuditLog(actor_id=user.id, action="order.cancelled", target_type="order", target_id=order.id, reason=payload.reason))
    db.add(IdempotencyRecord(user_id=user.id, key=idempotency_key, scope=f"status.{order_id}", response_json=json.dumps({"order_id": order.id, "status": payload.status})))
    queue_event(db, order, f"delivery.{payload.status}")
    db.commit()
    db.refresh(order)
    return order


@router.post("/orders/{order_id}/cod/confirm", response_model=OrderResponse)
@router.post("/deliveries/{order_id}/confirm-cod", response_model=OrderResponse)
def confirm_cod(
    order_id: str,
    idempotency_key: str = Header(min_length=8, max_length=100, alias="Idempotency-Key"),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
) -> Order:
    order = load_order(db, order_id)
    if user.role not in {"rider", "admin"} or (user.role == "rider" and order.rider_id != user.id):
        raise HTTPException(status_code=403, detail="Only the assigned rider or an administrator may confirm COD")
    replay = db.scalar(select(IdempotencyRecord).where(IdempotencyRecord.user_id == user.id, IdempotencyRecord.key == idempotency_key, IdempotencyRecord.scope == f"cod.{order_id}"))
    if replay:
        return order
    if order.status not in {"on_the_way", "delivered"}:
        raise HTTPException(status_code=409, detail="COD can only be confirmed during delivery or after completion")
    order.payment_status = "paid"
    db.add(IdempotencyRecord(user_id=user.id, key=idempotency_key, scope=f"cod.{order_id}", response_json=json.dumps({"order_id": order.id})))
    db.add(AuditLog(actor_id=user.id, action="cod.confirmed", target_type="order", target_id=order.id))
    queue_event(db, order, "payment.cod_confirmed")
    db.commit()
    db.refresh(order)
    return order


@router.post("/deliveries/{order_id}/locations", response_model=LocationResponse, status_code=201)
def add_location(
    order_id: str,
    payload: LocationCreate,
    idempotency_key: str = Header(min_length=8, max_length=100, alias="Idempotency-Key"),
    rider: User = Depends(require_roles("rider")),
    db: Session = Depends(get_db),
) -> LocationPoint:
    order = load_order(db, order_id)
    if order.rider_id != rider.id or order.status not in {"picked_up", "on_the_way"}:
        raise HTTPException(status_code=403, detail="Location sharing is not active for this rider")
    replay = db.scalar(select(IdempotencyRecord).where(IdempotencyRecord.user_id == rider.id, IdempotencyRecord.key == idempotency_key, IdempotencyRecord.scope == f"locations.{order_id}"))
    if replay:
        location_id = json.loads(replay.response_json)["id"]
        return db.get(LocationPoint, location_id)
    captured = payload.captured_at if payload.captured_at.tzinfo else payload.captured_at.replace(tzinfo=timezone.utc)
    if captured > datetime.now(timezone.utc) + timedelta(seconds=30):
        raise HTTPException(status_code=422, detail="captured_at cannot be more than 30 seconds in the future")
    point = LocationPoint(order_id=order.id, rider_id=rider.id, **payload.model_dump())
    db.add(point)
    db.flush()
    db.add(IdempotencyRecord(user_id=rider.id, key=idempotency_key, scope=f"locations.{order_id}", response_json=json.dumps({"id": point.id})))
    queue_event(db, order, "location.updated")
    db.commit()
    db.refresh(point)
    return point


@router.get("/deliveries/{order_id}/location", response_model=LocationResponse | None)
def latest_location(order_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)) -> LocationPoint | None:
    order = load_order(db, order_id)
    assert_order_access(order, user)
    return db.scalar(select(LocationPoint).where(LocationPoint.order_id == order.id).order_by(LocationPoint.captured_at.desc()).limit(1))


@router.post("/orders/{order_id}/feedback", status_code=201)
def create_feedback(
    order_id: str,
    payload: FeedbackCreate,
    customer: User = Depends(require_roles("customer")),
    db: Session = Depends(get_db),
) -> dict:
    order = load_order(db, order_id)
    if order.customer_id != customer.id or order.status != "delivered":
        raise HTTPException(status_code=403, detail="Only the customer may review a delivered order")
    if db.scalar(select(Feedback).where(Feedback.order_id == order.id, Feedback.customer_id == customer.id)):
        raise HTTPException(status_code=409, detail="Feedback already submitted")
    feedback = Feedback(order_id=order.id, customer_id=customer.id, **payload.model_dump())
    db.add(feedback)
    db.commit()
    return {"id": feedback.id}
