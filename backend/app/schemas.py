from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import AliasChoices, BaseModel, ConfigDict, EmailStr, Field


Role = Literal["customer", "rider", "admin"]
OrderStatus = Literal["pending", "confirmed", "assigned", "picked_up", "on_the_way", "delivered", "cancelled"]


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    full_name: str = Field(min_length=2, max_length=120, validation_alias=AliasChoices("full_name", "name"))
    phone: str | None = Field(default=None, max_length=30)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    role: str


class UserResponse(ORMModel):
    id: str
    email: str
    full_name: str
    phone: str | None
    role: str
    is_active: bool
    rider_status: str | None


class AdminUserCreate(RegisterRequest):
    role: Literal["rider", "admin"]


class AddressCreate(BaseModel):
    label: str = Field(min_length=1, max_length=60)
    line1: str = Field(min_length=3, max_length=255)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


class AddressResponse(AddressCreate, ORMModel):
    id: str
    customer_id: str


class StoreCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    description: str | None = None
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    is_active: bool = True


class StoreResponse(StoreCreate, ORMModel):
    id: str
    available: bool


class StoreUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    description: str | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    is_active: bool | None = None


class MenuItemCreate(BaseModel):
    store_id: str
    category: str = Field(min_length=1, max_length=80)
    name: str = Field(min_length=2, max_length=120)
    description: str | None = None
    price: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    image_path: str | None = None
    is_available: bool = True


class MenuItemResponse(MenuItemCreate, ORMModel):
    id: str
    available: bool
    image_url: str | None


class NestedMenuItemCreate(BaseModel):
    category: str = Field(min_length=1, max_length=80)
    name: str = Field(min_length=2, max_length=120)
    description: str | None = None
    price: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    image_path: str | None = None
    is_available: bool = True


class MenuItemUpdate(BaseModel):
    category: str | None = Field(default=None, min_length=1, max_length=80)
    name: str | None = Field(default=None, min_length=2, max_length=120)
    description: str | None = None
    price: Decimal | None = Field(default=None, gt=0, max_digits=12, decimal_places=2)
    image_path: str | None = None
    is_available: bool | None = None


class OrderLineCreate(BaseModel):
    menu_item_id: str
    quantity: int = Field(ge=1, le=99)


class OrderCreate(BaseModel):
    store_id: str
    address_id: str = Field(validation_alias=AliasChoices("address_id", "delivery_address_id"))
    items: list[OrderLineCreate] = Field(min_length=1, max_length=50)


class OrderLineResponse(ORMModel):
    menu_item_id: str
    name_snapshot: str
    unit_price: Decimal
    quantity: int


class OrderResponse(ORMModel):
    id: str
    delivery_id: str
    store_name: str
    customer_name: str
    rider_name: str | None
    customer_id: str
    store_id: str
    address_id: str
    status: str
    subtotal: Decimal
    delivery_fee: Decimal
    total: Decimal
    route_distance_km: float
    payment_method: str
    payment_status: str
    rider_id: str | None
    items: list[OrderLineResponse]
    created_at: datetime


class AssignRequest(BaseModel):
    rider_id: str


class StatusRequest(BaseModel):
    status: OrderStatus
    reason: str | None = Field(default=None, max_length=500)


class LocationCreate(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    accuracy_m: float = Field(ge=0, le=5000, validation_alias=AliasChoices("accuracy_m", "accuracy_meters"))
    captured_at: datetime = Field(validation_alias=AliasChoices("captured_at", "recorded_at"))


class LocationResponse(LocationCreate, ORMModel):
    id: str
    order_id: str
    rider_id: str
    accuracy_meters: float
    recorded_at: datetime


class DeliveryResponse(BaseModel):
    id: str
    order_id: str
    status: str
    rider_id: str | None
    store_name: str
    customer_name: str
    rider_name: str | None
    delivery_address: str
    pickup_latitude: float
    pickup_longitude: float
    destination_latitude: float
    destination_longitude: float
    total: Decimal
    payment_status: str
    latitude: float | None
    longitude: float | None
    eta_minutes: int | None
    last_location_at: datetime | None


class RiderStatusRequest(BaseModel):
    status: Literal["available", "busy", "offline"]


class DeviceCreate(BaseModel):
    token: str = Field(min_length=10, max_length=500)
    platform: Literal["android", "ios", "web"]


class FeedbackCreate(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str | None = Field(default=None, max_length=1000)


class UploadAuthorizeRequest(BaseModel):
    filename: str = Field(pattern=r"^[A-Za-z0-9_.-]+$", max_length=120)
    content_type: Literal["image/jpeg", "image/png", "image/webp"]
    size_bytes: int = Field(gt=0, le=5_000_000)


class UploadAuthorizeResponse(BaseModel):
    object_path: str
    upload_url: str
    token: str | None = None


class UploadFinalizeRequest(BaseModel):
    object_path: str = Field(pattern=r"^menu-images/[A-Za-z0-9_./-]+$")


class DeliveryFeeConfigPayload(BaseModel):
    base_fee: Decimal = Field(ge=0, max_digits=12, decimal_places=2)
    per_km_fee: Decimal = Field(ge=0, max_digits=12, decimal_places=2)


class FeedbackResponse(ORMModel):
    id: str
    order_id: str
    customer_id: str
    customer_name: str
    rating: int
    comment: str | None
    created_at: datetime


class AuditResponse(ORMModel):
    id: str
    action: str
    actor_id: str
    actor_name: str
    target_type: str
    target_id: str
    reason: str | None
    created_at: datetime


class RiderResponse(BaseModel):
    id: str
    name: str
    full_name: str
    phone: str | None
    status: str
    rider_status: str
    active_delivery_id: str | None
    is_active: bool
