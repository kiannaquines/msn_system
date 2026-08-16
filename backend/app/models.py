import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, Numeric, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def new_id() -> str:
    return str(uuid.uuid4())


def now() -> datetime:
    return datetime.now(timezone.utc)


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, onupdate=now)


class User(Base, TimestampMixin):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    full_name: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str | None] = mapped_column(String(30))
    role: Mapped[str] = mapped_column(String(20), index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    rider_status: Mapped[str | None] = mapped_column(String(20))


class RefreshSession(Base):
    __tablename__ = "refresh_sessions"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class Address(Base, TimestampMixin):
    __tablename__ = "addresses"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    customer_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    label: Mapped[str] = mapped_column(String(60))
    line1: Mapped[str] = mapped_column(String(255))
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)


class Store(Base, TimestampMixin):
    __tablename__ = "stores"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    name: Mapped[str] = mapped_column(String(120), index=True)
    description: Mapped[str | None] = mapped_column(Text)
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    menu_items: Mapped[list["MenuItem"]] = relationship(back_populates="store")

    @property
    def available(self) -> bool:
        return self.is_active


class MenuItem(Base, TimestampMixin):
    __tablename__ = "menu_items"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    store_id: Mapped[str] = mapped_column(ForeignKey("stores.id", ondelete="CASCADE"), index=True)
    category: Mapped[str] = mapped_column(String(80), index=True)
    name: Mapped[str] = mapped_column(String(120))
    description: Mapped[str | None] = mapped_column(Text)
    price: Mapped[float] = mapped_column(Numeric(12, 2))
    image_path: Mapped[str | None] = mapped_column(String(500))
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    store: Mapped[Store] = relationship(back_populates="menu_items")

    @property
    def available(self) -> bool:
        return self.is_available

    @property
    def image_url(self) -> str | None:
        return self.image_path


class Order(Base, TimestampMixin):
    __tablename__ = "orders"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    customer_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    store_id: Mapped[str] = mapped_column(ForeignKey("stores.id"), index=True)
    address_id: Mapped[str] = mapped_column(ForeignKey("addresses.id"))
    status: Mapped[str] = mapped_column(String(30), default="pending", index=True)
    subtotal: Mapped[float] = mapped_column(Numeric(12, 2))
    delivery_fee: Mapped[float] = mapped_column(Numeric(12, 2))
    total: Mapped[float] = mapped_column(Numeric(12, 2))
    route_distance_km: Mapped[float] = mapped_column(Float)
    payment_method: Mapped[str] = mapped_column(String(30), default="cash_on_delivery")
    payment_status: Mapped[str] = mapped_column(String(20), default="unpaid")
    rider_id: Mapped[str | None] = mapped_column(ForeignKey("users.id"), index=True)
    items: Mapped[list["OrderItem"]] = relationship(cascade="all, delete-orphan")
    customer: Mapped[User] = relationship(foreign_keys=[customer_id])
    rider: Mapped[User | None] = relationship(foreign_keys=[rider_id])
    store: Mapped[Store] = relationship(foreign_keys=[store_id])

    @property
    def delivery_id(self) -> str:
        # The first release has a one-to-one order/delivery aggregate.
        return self.id

    @property
    def store_name(self) -> str:
        return self.store.name

    @property
    def customer_name(self) -> str:
        return self.customer.full_name

    @property
    def rider_name(self) -> str | None:
        return self.rider.full_name if self.rider else None


class OrderItem(Base):
    __tablename__ = "order_items"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    order_id: Mapped[str] = mapped_column(ForeignKey("orders.id", ondelete="CASCADE"), index=True)
    menu_item_id: Mapped[str] = mapped_column(ForeignKey("menu_items.id"))
    name_snapshot: Mapped[str] = mapped_column(String(120))
    unit_price: Mapped[float] = mapped_column(Numeric(12, 2))
    quantity: Mapped[int] = mapped_column(Integer)


class DeliveryEvent(Base):
    __tablename__ = "delivery_events"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    order_id: Mapped[str] = mapped_column(ForeignKey("orders.id", ondelete="CASCADE"), index=True)
    status: Mapped[str] = mapped_column(String(30))
    actor_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class LocationPoint(Base):
    __tablename__ = "location_points"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    order_id: Mapped[str] = mapped_column(ForeignKey("orders.id", ondelete="CASCADE"), index=True)
    rider_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    accuracy_m: Mapped[float] = mapped_column(Float)
    captured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)

    @property
    def accuracy_meters(self) -> float:
        return self.accuracy_m

    @property
    def recorded_at(self) -> datetime:
        return self.captured_at


class DeviceToken(Base, TimestampMixin):
    __tablename__ = "device_tokens"
    __table_args__ = (UniqueConstraint("user_id", "token"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token: Mapped[str] = mapped_column(String(500))
    platform: Mapped[str] = mapped_column(String(20))


class Feedback(Base):
    __tablename__ = "feedback"
    __table_args__ = (UniqueConstraint("order_id", "customer_id"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    order_id: Mapped[str] = mapped_column(ForeignKey("orders.id", ondelete="CASCADE"))
    customer_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    rating: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    customer: Mapped[User] = relationship(foreign_keys=[customer_id])

    @property
    def customer_name(self) -> str:
        return self.customer.full_name


class AuditLog(Base):
    __tablename__ = "audit_logs"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    actor_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    action: Mapped[str] = mapped_column(String(100))
    target_type: Mapped[str] = mapped_column(String(50))
    target_id: Mapped[str] = mapped_column(String(36))
    reason: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    actor: Mapped[User] = relationship(foreign_keys=[actor_id])

    @property
    def actor_name(self) -> str:
        return self.actor.full_name


class OutboxEvent(Base):
    __tablename__ = "outbox_events"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    event_type: Mapped[str] = mapped_column(String(100), index=True)
    aggregate_id: Mapped[str] = mapped_column(String(36), index=True)
    payload_json: Mapped[str] = mapped_column(Text)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class IdempotencyRecord(Base):
    __tablename__ = "idempotency_records"
    __table_args__ = (UniqueConstraint("user_id", "key", "scope"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    key: Mapped[str] = mapped_column(String(100))
    scope: Mapped[str] = mapped_column(String(100))
    response_json: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class DeliveryFeeConfig(Base):
    __tablename__ = "delivery_fee_config"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)
    base_fee: Mapped[float] = mapped_column(Numeric(12, 2), default=40)
    per_km_fee: Mapped[float] = mapped_column(Numeric(12, 2), default=5)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, onupdate=now)
