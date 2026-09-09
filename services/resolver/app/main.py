import asyncio
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from urllib.parse import urlparse

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import AnyHttpUrl, BaseModel, Field

from services.resolver.app.resolver import (
    ResolverError,
    ResolverTimeoutError,
    YtDlpResolver,
)
from services.resolver.app.security import UnsafeUrlError, validate_public_url


media_resolver = YtDlpResolver()


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    yield
    media_resolver.close()


app = FastAPI(title="Media Share Saver Resolver", lifespan=lifespan)


class ResolveRequest(BaseModel):
    url: AnyHttpUrl


class MediaFormat(BaseModel):
    format_id: str
    url: AnyHttpUrl
    ext: str | None = None
    width: int | None = None
    height: int | None = None
    filesize: int | None = None
    headers: dict[str, str] = Field(default_factory=dict)


class ResolveResponse(BaseModel):
    title: str
    source: str
    thumbnail: AnyHttpUrl | None = None
    duration: float | None = None
    formats: list[MediaFormat]


class ErrorDetail(BaseModel):
    code: str
    message: str


class ErrorResponse(BaseModel):
    error: ErrorDetail


def _media_format(item: dict) -> MediaFormat | None:
    url = item.get("url")
    if not isinstance(url, str) or not url.startswith(("http://", "https://")):
        return None

    raw_headers = item.get("http_headers") or {}
    if not isinstance(raw_headers, dict):
        raw_headers = {}
    headers = {
        str(key): str(value)
        for key, value in raw_headers.items()
        if value is not None
    }
    return MediaFormat(
        format_id=str(item.get("format_id") or "unknown"),
        url=url,
        ext=item.get("ext"),
        width=item.get("width"),
        height=item.get("height"),
        filesize=item.get("filesize") or item.get("filesize_approx"),
        headers=headers,
    )


def _resolve_response(info: dict, original_url: str) -> ResolveResponse:
    raw_formats = info.get("formats")
    if not isinstance(raw_formats, list):
        raw_formats = [info]
    formats = [
        media_format
        for item in raw_formats
        if isinstance(item, dict) and (media_format := _media_format(item))
    ]
    if not formats:
        raise ValueError("No downloadable formats were returned")

    webpage_url = info.get("webpage_url") or original_url
    source = info.get("extractor_key") or info.get("extractor")
    if not source:
        source = urlparse(str(webpage_url)).hostname or "unknown"

    return ResolveResponse(
        title=str(info.get("title") or "Untitled media"),
        source=str(source),
        thumbnail=info.get("thumbnail"),
        duration=info.get("duration"),
        formats=formats,
    )


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post(
    "/api/v1/resolve",
    response_model=ResolveResponse,
    responses={
        400: {"model": ErrorResponse},
        408: {"model": ErrorResponse},
        502: {"model": ErrorResponse},
    },
)
async def resolve(request: ResolveRequest) -> ResolveResponse | JSONResponse:
    try:
        await asyncio.to_thread(validate_public_url, request.url)
    except UnsafeUrlError:
        error = ErrorResponse(
            error=ErrorDetail(
                code="unsafe_url",
                message="The URL destination is not allowed.",
            )
        )
        return JSONResponse(status_code=400, content=error.model_dump())

    try:
        info = await media_resolver.resolve(str(request.url))
        return _resolve_response(info, str(request.url))
    except ResolverTimeoutError:
        error = ErrorResponse(
            error=ErrorDetail(
                code="resolver_timeout",
                message="Media resolution timed out.",
            )
        )
        return JSONResponse(status_code=408, content=error.model_dump())
    except (ResolverError, ValueError):
        error = ErrorResponse(
            error=ErrorDetail(
                code="extraction_failed",
                message="Media information could not be resolved.",
            )
        )
        return JSONResponse(status_code=502, content=error.model_dump())
