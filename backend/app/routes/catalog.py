from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..dependencies import current_user, require_roles
from ..models import Address, AuditLog, MenuItem, Store, User
from ..schemas import AddressCreate, AddressResponse, MenuItemCreate, MenuItemResponse, MenuItemUpdate, NestedMenuItemCreate, StoreCreate, StoreResponse, StoreUpdate

router = APIRouter(tags=["catalog"])


@router.post("/customers/addresses", response_model=AddressResponse, status_code=201, include_in_schema=False)
@router.post("/customers/me/addresses", response_model=AddressResponse, status_code=201)
def create_address(
    payload: AddressCreate,
    user: User = Depends(require_roles("customer")),
    db: Session = Depends(get_db),
) -> Address:
    address = Address(customer_id=user.id, **payload.model_dump())
    db.add(address)
    db.commit()
    db.refresh(address)
    return address


@router.get("/customers/addresses", response_model=list[AddressResponse], include_in_schema=False)
@router.get("/customers/me/addresses", response_model=list[AddressResponse])
def list_addresses(user: User = Depends(require_roles("customer")), db: Session = Depends(get_db)) -> list[Address]:
    return list(db.scalars(select(Address).where(Address.customer_id == user.id)).all())


@router.delete("/customers/addresses/{address_id}", status_code=204, include_in_schema=False)
@router.delete("/customers/me/addresses/{address_id}", status_code=204)
def delete_address(
    address_id: str,
    user: User = Depends(require_roles("customer")),
    db: Session = Depends(get_db),
) -> Response:
    address = db.scalar(select(Address).where(Address.id == address_id, Address.customer_id == user.id))
    if not address:
        raise HTTPException(status_code=404, detail="Address not found")
    db.delete(address)
    db.commit()
    return Response(status_code=204)


@router.get("/stores", response_model=list[StoreResponse])
def list_stores(user: User = Depends(current_user), db: Session = Depends(get_db)) -> list[Store]:
    query = select(Store).order_by(Store.name)
    if user.role != "admin":
        query = query.where(Store.is_active.is_(True))
    return list(db.scalars(query).all())


@router.post("/stores", response_model=StoreResponse, status_code=201)
def create_store(
    payload: StoreCreate,
    _: User = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
) -> Store:
    store = Store(**payload.model_dump())
    db.add(store)
    db.commit()
    db.refresh(store)
    return store


@router.patch("/stores/{store_id}", response_model=StoreResponse)
def update_store(
    store_id: str,
    payload: StoreUpdate,
    admin: User = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
) -> Store:
    store = db.get(Store, store_id)
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")
    changes = payload.model_dump(exclude_unset=True)
    if not changes:
        raise HTTPException(status_code=422, detail="At least one field is required")
    for field, value in changes.items():
        setattr(store, field, value)
    db.add(AuditLog(actor_id=admin.id, action="store.updated", target_type="store", target_id=store.id))
    db.commit()
    db.refresh(store)
    return store


@router.delete("/stores/{store_id}", status_code=204)
def delete_store(
    store_id: str,
    reason: str = Query(min_length=3, max_length=500),
    admin: User = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
) -> Response:
    store = db.get(Store, store_id)
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")
    store.is_active = False
    for item in store.menu_items:
        item.is_available = False
    db.add(AuditLog(actor_id=admin.id, action="store.deleted", target_type="store", target_id=store.id, reason=reason))
    db.commit()
    return Response(status_code=204)


@router.get("/menu-items", response_model=list[MenuItemResponse])
def list_menu_items(store_id: str, _: User = Depends(current_user), db: Session = Depends(get_db)) -> list[MenuItem]:
    return list(
        db.scalars(
            select(MenuItem).where(MenuItem.store_id == store_id, MenuItem.is_available.is_(True)).order_by(MenuItem.category, MenuItem.name)
        ).all()
    )


@router.get("/stores/{store_id}/menu-items", response_model=list[MenuItemResponse])
def list_store_menu_items(store_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)) -> list[MenuItem]:
    return list_menu_items(store_id=store_id, _=user, db=db)


@router.post("/menu-items", response_model=MenuItemResponse, status_code=201)
def create_menu_item(
    payload: MenuItemCreate,
    _: User = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
) -> MenuItem:
    if not db.get(Store, payload.store_id):
        raise HTTPException(status_code=404, detail="Store not found")
    item = MenuItem(**payload.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.post("/stores/{store_id}/menu-items", response_model=MenuItemResponse, status_code=201)
def create_nested_menu_item(
    store_id: str,
    payload: NestedMenuItemCreate,
    admin: User = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
) -> MenuItem:
    return create_menu_item(MenuItemCreate(store_id=store_id, **payload.model_dump()), admin, db)


@router.patch("/menu-items/{item_id}", response_model=MenuItemResponse)
def update_menu_item(
    item_id: str,
    payload: MenuItemUpdate,
    admin: User = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
) -> MenuItem:
    item = db.get(MenuItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Menu item not found")
    changes = payload.model_dump(exclude_unset=True)
    if not changes:
        raise HTTPException(status_code=422, detail="At least one field is required")
    for field, value in changes.items():
        setattr(item, field, value)
    db.add(AuditLog(actor_id=admin.id, action="menu_item.updated", target_type="menu_item", target_id=item.id))
    db.commit()
    db.refresh(item)
    return item


@router.delete("/menu-items/{item_id}", status_code=204)
def delete_menu_item(
    item_id: str,
    reason: str = Query(min_length=3, max_length=500),
    admin: User = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
) -> Response:
    item = db.get(MenuItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Menu item not found")
    item.is_available = False
    db.add(AuditLog(actor_id=admin.id, action="menu_item.deleted", target_type="menu_item", target_id=item.id, reason=reason))
    db.commit()
    return Response(status_code=204)
