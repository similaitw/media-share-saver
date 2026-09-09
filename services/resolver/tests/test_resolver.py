import asyncio
import threading
import time

import pytest
from yt_dlp.utils import DownloadError

from services.resolver.app.resolver import (
    ResolverError,
    ResolverTimeoutError,
    YtDlpResolver,
)


class FakeExtractor:
    def __init__(self, options: dict, result: dict | None = None) -> None:
        self.options = options
        self.result = result or {"title": "Example", "formats": []}

    def __enter__(self):
        return self

    def __exit__(self, *args: object) -> None:
        return None

    def extract_info(self, url: str, *, download: bool) -> dict:
        assert download is False
        return self.result


@pytest.mark.anyio
async def test_extracts_metadata_without_downloading() -> None:
    created: list[FakeExtractor] = []

    def factory(options: dict) -> FakeExtractor:
        extractor = FakeExtractor(options)
        created.append(extractor)
        return extractor

    resolver = YtDlpResolver(extractor_factory=factory)
    try:
        result = await resolver.resolve("https://example.com/media")
    finally:
        resolver.close()

    assert result["title"] == "Example"
    assert created[0].options["skip_download"] is True
    assert created[0].options["noplaylist"] is True
    assert "cookiefile" not in created[0].options


@pytest.mark.anyio
async def test_maps_yt_dlp_failure_to_resolver_error() -> None:
    class FailingExtractor(FakeExtractor):
        def extract_info(self, url: str, *, download: bool) -> dict:
            raise DownloadError("unsupported")

    resolver = YtDlpResolver(extractor_factory=FailingExtractor)
    try:
        with pytest.raises(ResolverError):
            await resolver.resolve("https://example.com/media")
    finally:
        resolver.close()


@pytest.mark.anyio
async def test_enforces_timeout() -> None:
    class SlowExtractor(FakeExtractor):
        def extract_info(self, url: str, *, download: bool) -> dict:
            time.sleep(0.05)
            return self.result

    resolver = YtDlpResolver(timeout_seconds=0.01, extractor_factory=SlowExtractor)
    try:
        with pytest.raises(ResolverTimeoutError):
            await resolver.resolve("https://example.com/media")
    finally:
        resolver.close()


@pytest.mark.anyio
async def test_bounds_concurrent_extractions() -> None:
    lock = threading.Lock()
    active = 0
    peak = 0

    class CountingExtractor(FakeExtractor):
        def extract_info(self, url: str, *, download: bool) -> dict:
            nonlocal active, peak
            with lock:
                active += 1
                peak = max(peak, active)
            time.sleep(0.03)
            with lock:
                active -= 1
            return self.result

    resolver = YtDlpResolver(
        timeout_seconds=1,
        max_concurrency=2,
        extractor_factory=CountingExtractor,
    )
    try:
        await asyncio.gather(
            *(resolver.resolve(f"https://example.com/{index}") for index in range(5))
        )
    finally:
        resolver.close()

    assert peak == 2
