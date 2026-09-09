import ipaddress
import socket
from collections.abc import Callable, Sequence

from pydantic import AnyHttpUrl


AddressInfo = tuple[int, int, int, str, tuple]
AddressResolver = Callable[..., Sequence[AddressInfo]]


class UnsafeUrlError(ValueError):
    """Raised when a URL destination is not safe for an outbound request."""


def _require_global_address(address: str) -> None:
    try:
        parsed_address = ipaddress.ip_address(address)
    except ValueError as error:
        raise UnsafeUrlError("Destination resolved to an invalid IP address.") from error

    if not parsed_address.is_global or parsed_address.is_multicast:
        raise UnsafeUrlError("Destination does not use a public IP address.")


def validate_public_url(
    url: AnyHttpUrl,
    resolver: AddressResolver = socket.getaddrinfo,
) -> None:
    hostname = url.host.rstrip(".").lower()
    if hostname.startswith("[") and hostname.endswith("]"):
        hostname = hostname[1:-1]
    if hostname == "localhost" or hostname.endswith(".localhost"):
        raise UnsafeUrlError("Localhost destinations are not allowed.")

    try:
        ipaddress.ip_address(hostname)
    except ValueError:
        port = url.port or (443 if url.scheme == "https" else 80)
        try:
            address_info = resolver(hostname, port, type=socket.SOCK_STREAM)
        except (OSError, socket.gaierror) as error:
            raise UnsafeUrlError("Destination could not be resolved.") from error

        addresses = {entry[4][0] for entry in address_info if entry[4]}
        if not addresses:
            raise UnsafeUrlError("Destination did not resolve to an IP address.")
    else:
        addresses = {hostname}

    for address in addresses:
        _require_global_address(address)
