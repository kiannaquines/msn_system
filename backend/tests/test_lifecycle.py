from datetime import datetime, timedelta, timezone

from app.security import decode_access_token


def auth(token: str, **headers) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}", **headers}


def create_order_fixture(client, actors):
    store_response = client.post(
        "/api/v1/stores", headers=auth(actors["admin"]),
        json={"name": "M&S Main", "description": "Main store", "latitude": 14.5995, "longitude": 120.9842},
    )
    assert store_response.status_code == 201, store_response.text
    store = store_response.json()
    item_response = client.post(
        "/api/v1/menu-items", headers=auth(actors["admin"]),
        json={"store_id": store["id"], "category": "Meals", "name": "Rice Meal", "price": "120.00"},
    )
    assert item_response.status_code == 201, item_response.text
    item = item_response.json()
    nested_menu = client.get(f"/api/v1/stores/{store['id']}/menu-items", headers=auth(actors["customer"]))
    assert nested_menu.status_code == 200
    assert nested_menu.json()[0]["available"] is True
    address_response = client.post(
        "/api/v1/customers/me/addresses", headers=auth(actors["customer"]),
        json={"label": "Home", "line1": "123 Test Street", "latitude": 14.6091, "longitude": 121.0223},
    )
    assert address_response.status_code == 201, address_response.text
    address = address_response.json()
    payload = {"store_id": store["id"], "delivery_address_id": address["id"], "items": [{"menu_item_id": item["id"], "quantity": 2}]}
    response = client.post("/api/v1/orders", headers=auth(actors["customer"], **{"Idempotency-Key": "checkout-0001"}), json=payload)
    assert response.status_code == 201, response.text
    return response.json(), payload


def test_complete_delivery_lifecycle_and_enriched_contract(client, actors):
    order, payload = create_order_fixture(client, actors)
    assert order["status"] == "pending"
    assert order["delivery_id"] == order["id"]
    assert order["subtotal"] == "240.00"
    replay = client.post("/api/v1/orders", headers=auth(actors["customer"], **{"Idempotency-Key": "checkout-0001"}), json=payload)
    assert replay.status_code == 201 and replay.json()["id"] == order["id"]
    confirmed = client.post(f"/api/v1/orders/{order['id']}/status", headers=auth(actors["admin"], **{"Idempotency-Key": "confirm-0001"}), json={"status": "confirmed"})
    assert confirmed.status_code == 200, confirmed.text
    confirmed_replay = client.post(f"/api/v1/orders/{order['id']}/status", headers=auth(actors["admin"], **{"Idempotency-Key": "confirm-0001"}), json={"status": "confirmed"})
    assert confirmed_replay.status_code == 200
    assert client.put("/api/v1/riders/me/availability", headers=auth(actors["rider"]), json={"status": "available"}).status_code == 200
    assigned = client.post(f"/api/v1/orders/{order['id']}/assign", headers=auth(actors["admin"]), json={"rider_id": actors["rider_id"]})
    assert assigned.status_code == 200, assigned.text
    delivery = client.get(f"/api/v1/deliveries/{order['id']}", headers=auth(actors["rider"]))
    assert delivery.status_code == 200
    assert delivery.json()["store_name"] == "M&S Main"
    assert delivery.json()["customer_name"] == "Customer User"
    assert delivery.json()["delivery_address"] == "123 Test Street"
    assert delivery.json()["pickup_latitude"] == 14.5995
    for state in ("picked_up", "on_the_way"):
        changed = client.post(f"/api/v1/deliveries/{order['id']}/status", headers=auth(actors["rider"], **{"Idempotency-Key": f"status-{state}"}), json={"status": state})
        assert changed.status_code == 200, changed.text
    point = {"latitude": 14.6, "longitude": 121.0, "accuracy_meters": 8, "recorded_at": (datetime.now(timezone.utc) + timedelta(seconds=10)).isoformat()}
    location = client.post(f"/api/v1/deliveries/{order['id']}/locations", headers=auth(actors["rider"], **{"Idempotency-Key": "location-0001"}), json=point)
    assert location.status_code == 201, location.text
    assert location.json()["accuracy_meters"] == 8
    duplicate = client.post(f"/api/v1/deliveries/{order['id']}/locations", headers=auth(actors["rider"], **{"Idempotency-Key": "location-0001"}), json=point)
    assert duplicate.json()["id"] == location.json()["id"]
    too_far_future = {**point, "recorded_at": (datetime.now(timezone.utc) + timedelta(seconds=31)).isoformat()}
    rejected = client.post(f"/api/v1/deliveries/{order['id']}/locations", headers=auth(actors["rider"], **{"Idempotency-Key": "location-future"}), json=too_far_future)
    assert rejected.status_code == 422
    cod = client.post(f"/api/v1/deliveries/{order['id']}/confirm-cod", headers=auth(actors["rider"], **{"Idempotency-Key": "cod-paid-001"}))
    assert cod.status_code == 200 and cod.json()["payment_status"] == "paid"
    cod_replay = client.post(f"/api/v1/orders/{order['id']}/cod/confirm", headers=auth(actors["rider"], **{"Idempotency-Key": "cod-paid-001"}))
    assert cod_replay.status_code == 200
    delivered = client.post(f"/api/v1/orders/{order['id']}/status", headers=auth(actors["rider"], **{"Idempotency-Key": "status-delivered"}), json={"status": "delivered"})
    assert delivered.status_code == 200 and delivered.json()["payment_status"] == "paid"
    feedback = client.post(f"/api/v1/orders/{order['id']}/feedback", headers=auth(actors["customer"]), json={"rating": 5, "comment": "Fast delivery"})
    assert feedback.status_code == 201
    report = client.get("/api/v1/reports/summary", headers=auth(actors["admin"]))
    assert report.json()["delivered"] == 1 and report.json()["cod_sales"] > 240
    feedback_view = client.get("/api/v1/feedback", headers=auth(actors["admin"]))
    assert feedback_view.status_code == 200
    assert feedback_view.json()[0]["customer_name"] == "Customer User"
    audit_view = client.get("/api/v1/audit", headers=auth(actors["admin"]))
    assert audit_view.status_code == 200
    assert any(entry["action"] == "cod.confirmed" for entry in audit_view.json())
    riders = client.get("/api/v1/riders", headers=auth(actors["admin"]))
    assert riders.json()[0]["name"] == "Rider User"
    assert riders.json()[0]["active_delivery_id"] is None


def test_authorization_and_invalid_transitions(client, actors):
    order, _ = create_order_fixture(client, actors)
    assert client.get(f"/api/v1/orders/{order['id']}", headers=auth(actors["rider"])).status_code == 403
    missing_key = client.post(f"/api/v1/orders/{order['id']}/status", headers=auth(actors["admin"]), json={"status": "confirmed"})
    assert missing_key.status_code == 422
    skip = client.post(f"/api/v1/orders/{order['id']}/status", headers=auth(actors["admin"], **{"Idempotency-Key": "invalid-skip"}), json={"status": "delivered"})
    assert skip.status_code == 409


def test_admin_catalog_crud_is_audited_and_soft_deleted(client, actors):
    store = client.post(
        "/api/v1/stores", headers=auth(actors["admin"]),
        json={"name": "Branch", "description": "Original", "latitude": 7.0, "longitude": 125.0},
    ).json()
    updated = client.patch(f"/api/v1/stores/{store['id']}", headers=auth(actors["admin"]), json={"description": "Updated", "is_active": False})
    assert updated.status_code == 200
    assert updated.json()["available"] is False
    item = client.post(
        f"/api/v1/stores/{store['id']}/menu-items", headers=auth(actors["admin"]),
        json={"category": "Drinks", "name": "Water", "price": "25.00"},
    )
    assert item.status_code == 201, item.text
    changed = client.patch(f"/api/v1/menu-items/{item.json()['id']}", headers=auth(actors["admin"]), json={"price": "30.00"})
    assert changed.status_code == 200
    assert changed.json()["price"] == "30.00"
    assert client.delete(f"/api/v1/menu-items/{item.json()['id']}", headers=auth(actors["admin"])).status_code == 422
    removed = client.delete(f"/api/v1/menu-items/{item.json()['id']}?reason=No%20longer%20sold", headers=auth(actors["admin"]))
    assert removed.status_code == 204
    removed_store = client.delete(f"/api/v1/stores/{store['id']}?reason=Branch%20closed", headers=auth(actors["admin"]))
    assert removed_store.status_code == 204
    assert client.get("/api/v1/audit", headers=auth(actors["customer"])).status_code == 403
    audit = client.get("/api/v1/audit", headers=auth(actors["admin"])).json()
    assert {entry["action"] for entry in audit} >= {"store.updated", "menu_item.updated", "menu_item.deleted", "store.deleted"}
    assert next(entry for entry in audit if entry["action"] == "store.deleted")["reason"] == "Branch closed"


def test_refresh_tokens_rotate(client, actors):
    login = client.post("/api/v1/auth/login", json={"email": "customer@example.com", "password": "password123"}).json()
    claims = decode_access_token(login["access_token"])
    assert claims["role"] == "authenticated"
    assert claims["business_role"] == "customer"
    refreshed = client.post("/api/v1/auth/refresh", json={"refresh_token": login["refresh_token"]})
    assert refreshed.status_code == 200
    assert client.post("/api/v1/auth/refresh", json={"refresh_token": login["refresh_token"]}).status_code == 401


def test_health_and_storage_development_fallback(client, actors):
    assert client.get("/api/health/live").json() == {"status": "ok"}
    assert client.get("/api/health/ready").status_code == 200
    upload = client.post("/api/v1/uploads/authorize", headers=auth(actors["admin"]), json={"filename": "meal.webp", "content_type": "image/webp", "size_bytes": 1024})
    assert upload.status_code == 200
    assert upload.json()["object_path"].startswith("menu-images/")
    assert client.get("/api/v1/internal/outbox/process").status_code == 401
    cron = client.get("/api/v1/internal/outbox/process", headers={"Authorization": "Bearer bootstrap-secret"})
    assert cron.status_code == 200
    assert "pending" in cron.json()
