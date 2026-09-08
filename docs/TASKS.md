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

## Completed

- [x] M1.1 — Bootstrapped the FastAPI resolver service with a `/health`
  endpoint, minimal container configuration, and a pytest health check.

## Current task — M1.2
Implement the initial `POST /api/v1/resolve` request/response schema and URL
validation. Do not implement yt-dlp extraction yet.

### Deliverables
- Define the versioned resolve endpoint request and response models.
- Accept only HTTP and HTTPS URLs.
- Add tests for valid and invalid request URLs.

### Requirements
- Keep the endpoint response structured and suitable for later resolver output.
- Reject unsupported URL schemes with a clear validation response.
- Keep changes limited to the initial schema and validation behavior.

### Acceptance
- Tests pass.
- No secrets or binaries committed.
- Mark M1.2 complete here and set the next explicit task.

## Token-saving rule
Codex should read `AGENTS.md` + this file first. Read `docs/SPEC.md` only when details are needed. Avoid repository-wide exploration for narrowly scoped tasks.
