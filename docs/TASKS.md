# Development Status

## Current milestone
M2 — Resolver + security

## Roadmap
- [x] M1 Backend foundation
- [ ] M2 Resolver + security
- [ ] M3 Flutter Android shell + Share Sheet
- [ ] M4 Direct download + MediaStore
- [ ] M5 End-to-end Android MVP
- [ ] M6 GitHub Actions APK build
- [ ] M7 iOS (later)

## Completed

- [x] M1.1 — Bootstrapped the FastAPI resolver service with a `/health`
  endpoint, minimal container configuration, and a pytest health check.
- [x] M1.2 — Added the versioned resolve request/response models, HTTP/HTTPS
  URL validation, a structured not-implemented response, and endpoint tests.
- [x] M2.1 — Added isolated SSRF validation for direct IPs and every DNS-resolved
  address, blocking localhost and non-public destinations with predictable errors.

## Current task — M2.2
Add initial yt-dlp metadata extraction with timeout and bounded concurrency.

### Deliverables
- Add yt-dlp as the resolver implementation without proxying media bytes.
- Map extracted metadata and downloadable formats to `ResolveResponse`.
- Add timeout and bounded-concurrency controls with focused tests.

### Requirements
- Preserve M2.1 URL safety checks before extraction.
- Do not accept cookies or store downloaded media.
- Return predictable errors for unsupported URLs, timeouts, and extraction failures.

### Acceptance
- Tests pass.
- No secrets or binaries committed.
- Mark M2.2 complete here and set the next explicit task.

## Token-saving rule
Codex should read `AGENTS.md` + this file first. Read `docs/SPEC.md` only when details are needed. Avoid repository-wide exploration for narrowly scoped tasks.
