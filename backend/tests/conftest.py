import os
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

TEST_DB = Path(__file__).parent / "test.db"
os.environ["DATABASE_URL"] = f"sqlite:///{TEST_DB}"
os.environ["JWT_DEV_SECRET"] = "tests-only-secret-that-is-long-enough-12345"
os.environ["CRON_SECRET"] = "bootstrap-secret"

from app.database import Base, engine  # noqa: E402
from app.main import app  # noqa: E402


@pytest.fixture(autouse=True)
def clean_database():
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    yield
    Base.metadata.drop_all(engine)


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


def login(client: TestClient, email: str, password: str = "password123") -> str:
    response = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


@pytest.fixture
def actors(client: TestClient):
    admin_data = {"email": "admin@example.com", "password": "password123", "full_name": "Admin User", "role": "admin"}
    assert client.post("/api/v1/auth/bootstrap-admin", headers={"X-Bootstrap-Token": "bootstrap-secret"}, json=admin_data).status_code == 201
    admin_token = login(client, "admin@example.com")
    registered = client.post(
        "/api/v1/auth/register",
        json={"email": "customer@example.com", "password": "password123", "name": "Customer User"},
    )
    assert registered.status_code == 201
    assert registered.json()["role"] == "customer"
    customer_token = login(client, "customer@example.com")
    rider_response = client.post(
        "/api/v1/riders",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"email": "rider@example.com", "password": "password123", "full_name": "Rider User", "role": "rider"},
    )
    assert rider_response.status_code == 201, rider_response.text
    rider_token = login(client, "rider@example.com")
    return {"admin": admin_token, "customer": customer_token, "rider": rider_token, "rider_id": rider_response.json()["id"]}
