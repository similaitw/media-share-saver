import asyncio
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor
from typing import Any, Protocol

from yt_dlp import YoutubeDL
from yt_dlp.utils import DownloadError


class Extractor(Protocol):
    def __enter__(self) -> "Extractor": ...

    def __exit__(self, *args: object) -> None: ...

    def extract_info(self, url: str, *, download: bool) -> dict[str, Any]: ...


ExtractorFactory = Callable[[dict[str, Any]], Extractor]


class ResolverError(RuntimeError):
    """Raised when media metadata cannot be extracted."""


class ResolverTimeoutError(ResolverError):
    """Raised when resolving exceeds the configured deadline."""


class YtDlpResolver:
    def __init__(
        self,
        *,
        timeout_seconds: float = 20,
        max_concurrency: int = 2,
        extractor_factory: ExtractorFactory = YoutubeDL,
    ) -> None:
        if timeout_seconds <= 0:
            raise ValueError("timeout_seconds must be positive")
        if max_concurrency <= 0:
            raise ValueError("max_concurrency must be positive")

        self.timeout_seconds = timeout_seconds
        self._extractor_factory = extractor_factory
        self._executor = ThreadPoolExecutor(
            max_workers=max_concurrency,
            thread_name_prefix="yt-dlp-resolver",
        )
        self._slots = asyncio.Semaphore(max_concurrency)

    def _extract(self, url: str) -> dict[str, Any]:
        options = {
            "cachedir": False,
            "noplaylist": True,
            "no_warnings": True,
            "quiet": True,
            "skip_download": True,
            "socket_timeout": self.timeout_seconds,
        }
        try:
            with self._extractor_factory(options) as extractor:
                result = extractor.extract_info(url, download=False)
        except DownloadError as error:
            raise ResolverError("yt-dlp could not extract this URL") from error

        if not isinstance(result, dict):
            raise ResolverError("yt-dlp returned an invalid result")
        return result

    async def resolve(self, url: str) -> dict[str, Any]:
        loop = asyncio.get_running_loop()
        acquired = False
        extraction = None
        try:
            async with asyncio.timeout(self.timeout_seconds):
                await self._slots.acquire()
                acquired = True
                extraction = loop.run_in_executor(self._executor, self._extract, url)
                return await asyncio.shield(extraction)
        except TimeoutError as error:
            raise ResolverTimeoutError("Resolver timed out") from error
        finally:
            if acquired:
                if extraction is not None and not extraction.done():
                    extraction.add_done_callback(
                        lambda _: loop.call_soon_threadsafe(self._slots.release)
                    )
                else:
                    self._slots.release()

    def close(self) -> None:
        self._executor.shutdown(wait=True, cancel_futures=True)
