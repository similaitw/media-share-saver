from fastapi import FastAPI


app = FastAPI(title="Media Share Saver Resolver")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
