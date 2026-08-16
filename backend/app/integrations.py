import base64
import json
import math
import uuid

import httpx

from .config import get_settings


def haversine_km(origin: tuple[float, float], destination: tuple[float, float]) -> float:
    lat1, lon1 = map(math.radians, origin)
    lat2, lon2 = map(math.radians, destination)
    dlat, dlon = lat2 - lat1, lon2 - lon1
    a = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 6371 * 2 * math.asin(math.sqrt(a))


def route_metrics(origin: tuple[float, float], destination: tuple[float, float]) -> tuple[float, int]:
    settings = get_settings()
    if not settings.mapbox_secret_token:
        # Deterministic local/test fallback; production readiness rejects missing secrets.
        distance = round(haversine_km(origin, destination), 3)
        return distance, max(1, round(distance / 25 * 60))
    coordinates = f"{origin[1]},{origin[0]};{destination[1]},{destination[0]}"
    response = httpx.get(
        f"https://api.mapbox.com/directions/v5/mapbox/driving/{coordinates}",
        params={"access_token": settings.mapbox_secret_token, "overview": "false"},
        timeout=8,
    )
    response.raise_for_status()
    route = response.json()["routes"][0]
    return round(route["distance"] / 1000, 3), max(1, round(route["duration"] / 60))


def route_distance_km(origin: tuple[float, float], destination: tuple[float, float]) -> float:
    return route_metrics(origin, destination)[0]


def authorize_storage_upload(filename: str) -> tuple[str, str, str | None]:
    settings = get_settings()
    object_path = f"menu-images/{uuid.uuid4()}/{filename}"
    if not settings.supabase_url or not settings.supabase_secret_key:
        if settings.app_env == "production":
            raise RuntimeError("Supabase Storage is not configured")
        return object_path, f"http://localhost:54321/storage/mock/{object_path}", "development-token"
    response = httpx.post(
        f"{settings.supabase_url}/storage/v1/object/upload/sign/{object_path}",
        headers={"Authorization": f"Bearer {settings.supabase_secret_key}", "apikey": settings.supabase_secret_key},
        timeout=8,
    )
    response.raise_for_status()
    data = response.json()
    return object_path, f"{settings.supabase_url}/storage/v1{data['url']}", data.get("token")


def send_push_notifications(tokens: list[str], title: str, body: str, data: dict[str, str]) -> int:
    if not tokens:
        return 0
    encoded = get_settings().firebase_service_account_b64
    if not encoded:
        raise RuntimeError("Firebase messaging is not configured")

    import firebase_admin
    from firebase_admin import credentials, messaging

    try:
        firebase_admin.get_app()
    except ValueError:
        service_account = json.loads(base64.b64decode(encoded).decode("utf-8"))
        firebase_admin.initialize_app(credentials.Certificate(service_account))

    delivered = 0
    for token in tokens:
        messaging.send(messaging.Message(notification=messaging.Notification(title=title, body=body), data=data, token=token))
        delivered += 1
    return delivered
