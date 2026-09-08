# Development Status

## Current milestone
M1 — Backend foundation

## Roadmap
- [ ] M1 Backend foundation
- [ ] M2 Resolver + security
- [ ] M3 Flutter Android shell + Share Sheet
- [ ] M4 Direct download + MediaStore
- [ ] M5 End-to-end Android MVP
- [ ] M6 GitHub Actions APK build
- [ ] M7 iOS (later)

## Current task — M1.1
Bootstrap the FastAPI resolver service.

### Deliverables
Create:
- `services/resolver/app/main.py`
- `services/resolver/requirements.txt`
- `services/resolver/Dockerfile`
- `services/resolver/tests/test_health.py`
- `.gitignore` as needed

### Requirements
- `GET /health` returns HTTP 200 and JSON `{ "status": "ok" }`.
- FastAPI app starts cleanly.
- Docker image can run the API.
- Add a small pytest health endpoint test.
- Keep dependencies minimal.

### Acceptance
- Tests pass.
- No secrets or binaries committed.
- Mark M1.1 complete here.
- Set `Current task` to M1.2: implement the initial `POST /api/v1/resolve` request/response schema and URL validation. Do not implement yt-dlp extraction until M1.2/M2 unless required by the updated task.

## Token-saving rule
Codex should read `AGENTS.md` + this file first. Read `docs/SPEC.md` only when details are needed. Avoid repository-wide exploration for narrowly scoped tasks.
