import pytest
from fastapi.testclient import TestClient

from services.resolver.app.main import app


client = TestClient(app)


@pytest.fixture(autouse=True)
def allow_example_domain(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "services.resolver.app.main.validate_public_url", lambda _: None
    )


def test_resolve_accepts_https_url() -> None:
    response = client.post(
        "/api/v1/resolve", json={"url": "https://example.com/media"}
    )

    assert response.status_code == 501
    assert response.json() == {
        "error": {
            "code": "resolver_not_implemented",
            "message": "Media extraction is not implemented yet.",
        }
    }


def test_resolve_accepts_http_url() -> None:
    response = client.post(
        "/api/v1/resolve", json={"url": "http://example.com/media"}
    )

    assert response.status_code == 501


def test_resolve_rejects_unsupported_url_scheme() -> None:
    response = client.post(
        "/api/v1/resolve", json={"url": "ftp://example.com/media"}
    )

    assert response.status_code == 422


def test_resolve_rejects_malformed_url() -> None:
    response = client.post("/api/v1/resolve", json={"url": "not-a-url"})

    assert response.status_code == 422


def test_resolve_returns_predictable_error_for_unsafe_url(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from services.resolver.app.security import UnsafeUrlError

    def reject_url(_: object) -> None:
        raise UnsafeUrlError

    monkeypatch.setattr("services.resolver.app.main.validate_public_url", reject_url)

    response = client.post(
        "/api/v1/resolve", json={"url": "http://127.0.0.1/private"}
    )

    assert response.status_code == 400
    assert response.json() == {
        "error": {
            "code": "unsafe_url",
            "message": "The URL destination is not allowed.",
        }
    }


def test_openapi_includes_resolve_response_schema() -> None:
    operation = client.get("/openapi.json").json()["paths"]["/api/v1/resolve"]["post"]

    assert operation["responses"]["200"]["content"]["application/json"]["schema"] == {
        "$ref": "#/components/schemas/ResolveResponse"
    }
    assert operation["responses"]["501"]["content"]["application/json"]["schema"] == {
        "$ref": "#/components/schemas/ErrorResponse"
    }
    assert operation["responses"]["400"]["content"]["application/json"]["schema"] == {
        "$ref": "#/components/schemas/ErrorResponse"
    }
