# Development Status

## Current milestone
M3 — Flutter Android shell + Share Sheet

## Roadmap
- [x] M1 Backend foundation
- [x] M2 Resolver + security
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
- [x] M2.2 — Added yt-dlp metadata extraction and response mapping with an
  overall timeout, bounded concurrency, and predictable extraction errors.

## Completed — M3.1
Bootstrap the Flutter Android app shell and receive shared text URLs.

### Deliverables
- Create the Flutter application under `apps/mobile` with Android support.
- Register the app as an Android Share Sheet target for shared text.
- Show the received URL in a minimal screen with clear idle and error states.
- Add focused Flutter tests for the initial screen and shared-text handling.

### Requirements
- Android is the first supported client.
- Accept only shared HTTP/HTTPS URLs at the client boundary.
- Do not call the resolver API or download media yet.

### Acceptance
- Tests pass.
- No secrets or binaries committed.
- Implemented `apps/mobile` as an Android-only Flutter app with an
  `ACTION_SEND`/`text/plain` intent filter and a native-to-Dart method channel.
- The client accepts only HTTP/HTTPS URLs and displays idle, received, and
  invalid URL states without calling the backend or downloading media.
- Added focused widget tests for all three states.

## Completed — M3.2
Connect `POST /api/v1/resolve`, showing loading, resolve results, and error/
retry states, but do not download media yet.

### Deliverables
- Added an injectable resolver client using `POST /api/v1/resolve` with
  structured response and error parsing.
- Added loading, resolved metadata, connection/error, and retry states.
- Kept invalid URL handling at the client boundary and did not download media.
- Added focused tests for successful resolution, failures, retry, and URL
  rejection.

## Completed — M4.1
Download a selected resolved format and save it through Android MediaStore,
with progress and cancellation support.

### Deliverables
- Added selectable resolved formats and a streaming HTTP download client.
- Added download progress, cancellation, download error, and retry states.
- Added an Android MediaStore bridge that saves to the Downloads folder and
  cleans up pending or failed writes.
- Added focused tests for download progress, successful streaming, HTTP errors,
  and the download-related UI flow.

## Current task — M4.2
Make downloads resilient across app lifecycle changes and add a small local
download history view, without introducing account or cloud storage.

## Token-saving rule
Codex should read `AGENTS.md` + this file first. Read `docs/SPEC.md` only when details are needed. Avoid repository-wide exploration for narrowly scoped tasks.
