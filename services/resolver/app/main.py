from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import AnyHttpUrl, BaseModel, Field

from services.resolver.app.security import UnsafeUrlError, validate_public_url


app = FastAPI(title="Media Share Saver Resolver")


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


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post(
    "/api/v1/resolve",
    response_model=ResolveResponse,
    responses={400: {"model": ErrorResponse}, 501: {"model": ErrorResponse}},
)
def resolve(request: ResolveRequest) -> JSONResponse:
    try:
        validate_public_url(request.url)
    except UnsafeUrlError:
        error = ErrorResponse(
            error=ErrorDetail(
                code="unsafe_url",
                message="The URL destination is not allowed.",
            )
        )
        return JSONResponse(status_code=400, content=error.model_dump())

    error = ErrorResponse(
        error=ErrorDetail(
            code="resolver_not_implemented",
            message="Media extraction is not implemented yet.",
        )
    )
    return JSONResponse(status_code=501, content=error.model_dump())
