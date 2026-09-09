import socket

import pytest
from pydantic import AnyHttpUrl

from services.resolver.app.security import UnsafeUrlError, validate_public_url


def address_info(address: str) -> tuple[int, int, int, str, tuple]:
    family = socket.AF_INET6 if ":" in address else socket.AF_INET
    return (family, socket.SOCK_STREAM, 6, "", (address, 443))


@pytest.mark.parametrize(
    "url",
    [
        "http://localhost/media",
        "http://video.localhost/media",
        "http://127.0.0.1/media",
        "http://10.0.0.1/media",
        "http://169.254.169.254/latest/meta-data",
        "http://192.168.1.1/media",
        "http://[::1]/media",
        "http://[fe80::1]/media",
        "http://0.0.0.0/media",
        "http://224.0.0.1/media",
    ],
)
def test_rejects_non_public_destination(url: str) -> None:
    with pytest.raises(UnsafeUrlError):
        validate_public_url(AnyHttpUrl(url))


def test_accepts_public_ip_literal() -> None:
    validate_public_url(AnyHttpUrl("https://8.8.8.8/media"))


def test_accepts_public_ipv6_literal() -> None:
    validate_public_url(AnyHttpUrl("https://[2606:4700:4700::1111]/media"))


def test_accepts_hostname_when_all_addresses_are_public() -> None:
    calls: list[tuple[str, int, int]] = []

    def resolver(hostname: str, port: int, *, type: int):
        calls.append((hostname, port, type))
        return [address_info("8.8.8.8"), address_info("2606:4700:4700::1111")]

    validate_public_url(AnyHttpUrl("https://example.com/media"), resolver=resolver)

    assert calls == [("example.com", 443, socket.SOCK_STREAM)]


def test_rejects_hostname_when_any_address_is_not_public() -> None:
    def resolver(hostname: str, port: int, *, type: int):
        return [address_info("8.8.8.8"), address_info("127.0.0.1")]

    with pytest.raises(UnsafeUrlError):
        validate_public_url(AnyHttpUrl("https://example.com/media"), resolver=resolver)


def test_rejects_hostname_when_dns_resolution_fails() -> None:
    def resolver(hostname: str, port: int, *, type: int):
        raise socket.gaierror

    with pytest.raises(UnsafeUrlError):
        validate_public_url(AnyHttpUrl("https://does-not-resolve.example/media"), resolver)


def test_rejects_hostname_with_no_resolved_addresses() -> None:
    def resolver(hostname: str, port: int, *, type: int):
        return []

    with pytest.raises(UnsafeUrlError):
        validate_public_url(AnyHttpUrl("https://example.com/media"), resolver)
