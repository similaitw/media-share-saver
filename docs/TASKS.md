# Development Status

## Current milestone
M1 — Backend foundation

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

## Current task — M2.1
Add SSRF protection for resolver URLs before implementing yt-dlp extraction.

### Deliverables
- Reject localhost, loopback, link-local, private-network, and otherwise
  non-public IP destinations.
- Resolve hostnames safely and validate every resolved address.
- Add focused tests for blocked and allowed destinations.

### Requirements
- Apply checks before any future yt-dlp or outbound network operation.
- Return a predictable validation error without exposing internal details.
- Keep DNS and IP validation isolated and testable.

### Acceptance
- Tests pass.
- No secrets or binaries committed.
- Mark M2.1 complete here and set the next explicit task.

## Token-saving rule
Codex should read `AGENTS.md` + this file first. Read `docs/SPEC.md` only when details are needed. Avoid repository-wide exploration for narrowly scoped tasks.
