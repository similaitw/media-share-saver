# Development Status

## Current milestone
M7 — iOS (later)

## Roadmap
- [x] M1 Backend foundation
- [x] M2 Resolver + security
- [x] M3 Flutter Android shell + Share Sheet
- [x] M4 Direct download + MediaStore
- [x] M5 End-to-end Android MVP
- [x] M6 GitHub Actions APK build
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

## Completed — M4.2
Make downloads resilient across app lifecycle changes and add a small local
download history view, without introducing account or cloud storage.

### Deliverables
- Persisted pending, saved, cancelled, and failed download entries in the
  app support directory using a bounded local JSON history.
- Observed app lifecycle changes so an in-flight download keeps its state and
  explains background progress when the app returns to the foreground.
- Added a local download history screen with saved and failed entries.
- Added focused tests for history serialization and the empty history state.

## Completed — M5.1
Complete the Android MVP flow with device validation, user-facing download
history details, and end-to-end Android verification.

### Deliverables
- Added a native MediaStore capability check before starting downloads.
- Added device/storage warnings for unsupported Android environments.
- Expanded download history rows with status, timestamp, and source URL
  details.
- Verified the complete Flutter flow with static analysis and widget/service
  tests. Android APK compilation remains environment-blocked when no Android
  SDK is installed.

## Completed — M5.2
Fix Android compilation and make the device/emulator verification workflow pass
for share, resolve, download, MediaStore save, and local history persistence.

### Deliverables
- Added an Android `integration_test` target covering shared URL validation,
  resolver output, download completion, MediaStore channel calls, and local
  history persistence on a device.
- Added GitHub Actions workflow coverage for Flutter analysis/unit tests and
  an API 35 Google APIs emulator.
- Fixed the Android `MethodCall` type import so `MainActivity.kt` compiles.
- Kept device tests independent of external services by injecting test
  resolver/download clients and mocking only the platform save boundary.

### Acceptance
- `flutter analyze` passes in GitHub Actions.
- `flutter test` passes in GitHub Actions.
- Android `assembleDebug` succeeds as part of the emulator workflow.
- `integration_test/app_test.dart` passes on the CI emulator.
- Mobile verification run for commit `173fc1fba7562709fedc426c8084d305e9073138`
  completed successfully.

## Completed — M6.1
Add a GitHub Actions artifact workflow for a signing-credential-free debug APK
and publish build diagnostics without committing generated binaries or credentials.

### Deliverables
- Added a `debug-apk` GitHub Actions job using `flutter build apk --debug`.
- Added APK size and SHA-256 diagnostics.
- Uploaded `app-debug.apk` as the `media-share-saver-debug-apk` workflow artifact
  with 14-day retention.
- Kept generated APK binaries out of the repository and added no signing
  credentials or secrets.
- Preserved the existing Flutter analysis/unit-test and Android emulator jobs.

### Acceptance
- `debug-apk` job succeeded for commit `45ca1d491dfddcc76a7ac46a35c8ad054deaf977`.
- APK artifact `media-share-saver-debug-apk` was created successfully.
- The same workflow run's `flutter` job passed.
- The same run's `android-integration` job failed only because the hosted runner
  emulator did not finish booting before timeout; no application compile or test
  failure was reported in that job.

## Current task — M7.1
Plan the deferred iOS implementation path for Share Extension intake, direct
media download, Photos saving, and signing/TestFlight requirements without
changing the Android MVP.

### Acceptance
- Document the iOS architecture and platform-specific constraints.
- Identify the minimum native/Flutter integration needed for a Share Extension.
- Keep Android behavior unchanged.
- Do not add Apple signing credentials or provisioning profiles to the repository.

## Token-saving rule
Codex should read `AGENTS.md` + this file first. Read `docs/SPEC.md` only when details are needed. Avoid repository-wide exploration for narrowly scoped tasks.
