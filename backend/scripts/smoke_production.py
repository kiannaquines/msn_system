"""Read-only smoke checks for a deployed backend."""

import argparse

import httpx


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("base_url", help="Deployed origin, for example https://api.example.com")
    args = parser.parse_args()
    base_url = args.base_url.rstrip("/")
    with httpx.Client(base_url=base_url, timeout=15, follow_redirects=True) as client:
        live = client.get("/api/health/live")
        live.raise_for_status()
        assert live.json() == {"status": "ok"}
        ready = client.get("/api/health/ready")
        ready.raise_for_status()
        assert ready.json() == {"status": "ready"}
        schema = client.get("/api/openapi.json")
        schema.raise_for_status()
        paths = schema.json().get("paths", {})
        required = {"/api/v1/auth/login", "/api/v1/orders", "/api/v1/deliveries"}
        assert required.issubset(paths), f"Missing paths: {sorted(required - set(paths))}"
    print("Production read-only smoke checks passed.")


if __name__ == "__main__":
    main()
