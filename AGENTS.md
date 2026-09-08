# AGENTS.md

## Project
Media Share Saver — mobile share-to-save app for public media the user is permitted to download.

## Stack
- Mobile: Flutter (Android first; iOS later)
- API: Python FastAPI
- Resolver: yt-dlp
- Deployment: Docker + Cloudflare Tunnel

## Architecture
Share Sheet → Flutter → FastAPI resolver → download manifest → phone downloads directly → MediaStore/Photos.

The backend resolves metadata/download information only. Do not proxy or store media files.

## Codex workflow
1. Read this file.
2. Read `docs/TASKS.md`.
3. Work only on the current task and files required for it.
4. Read `docs/SPEC.md` only when the task needs product/architecture details.
5. Do not scan/refactor the entire repository without a concrete reason.
6. Keep changes small and testable.
7. Run relevant tests before completion.
8. Update `docs/TASKS.md`: mark completed work and set the next task.
9. Never commit secrets, cookies, credentials, signing keys, or generated binaries.

## Security
- Accept only http/https URLs.
- Defend against SSRF; block localhost, loopback, link-local and private-network destinations.
- Apply resolver timeout and bounded concurrency.
- Do not accept/store user login cookies in MVP.
- MVP supports only public content the user is authorized to save.

## Engineering rules
- Prefer simple implementations over premature infrastructure.
- Keep API responses structured and versioned under `/api/v1`.
- Backend changes require tests.
- Preserve unrelated working code.
- Android is the first supported client.
