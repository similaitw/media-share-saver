# Media Share Saver — Product Specification

## Goal
Build a mobile app that appears in the system Share Sheet. When a user shares a supported public media URL, the app asks a resolver API for downloadable media information, downloads directly from the source to the phone, and saves it to the device gallery.

Only content the user has permission to download is in scope. The product must not be designed to bypass DRM, access controls, paywalls, or platform restrictions.

## MVP
Android first.

User flow:
1. User taps Share in another app/browser.
2. Selects Media Share Saver.
3. App extracts an http/https URL.
4. App calls `POST /api/v1/resolve`.
5. API validates the target and extracts metadata with yt-dlp.
6. API returns a download manifest.
7. Phone downloads directly from the media source.
8. File is saved through Android MediaStore and appears in the gallery.

## API
### GET /health
Returns service health.

### POST /api/v1/resolve
Request:
```json
{"url":"https://example.com/media"}
```

Conceptual response:
```json
{
  "title":"Example",
  "source":"example.com",
  "thumbnail":null,
  "duration":120,
  "formats":[
    {
      "format_id":"...",
      "url":"...",
      "ext":"mp4",
      "width":1280,
      "height":720,
      "filesize":null,
      "headers":{}
    }
  ]
}
```

The exact schema may evolve, but the client must not assume there is always one permanent `.mp4` URL. Direct URLs may expire or require headers, and some sources expose separate audio/video streams.

## Backend
- Python + FastAPI
- yt-dlp metadata extraction
- Docker deployment
- Cloudflare Tunnel can expose the API without router port forwarding.
- Resolver does not proxy media bytes in MVP.

Required protections:
- URL scheme validation
- SSRF protection
- DNS/IP validation where applicable
- timeout
- bounded concurrency
- predictable error responses
- no cookie storage
- no secrets in source control

## Mobile
Flutter application with native Android integration where needed.

Android requirements:
- Receive `ACTION_SEND` text/plain shares.
- Extract URL safely.
- Call resolver API.
- Show title/thumbnail/status when available.
- Download in a background-capable manner.
- Save through MediaStore.
- Display useful errors and allow retry.

## Later phases
- Download progress/history
- format/quality selection
- share multiple URLs
- iOS Share Extension + Photos integration
- production authentication/rate limiting/observability

## Out of scope for MVP
- DRM circumvention
- bypassing access controls
- downloading private/account-only content by uploading user cookies
- cloud media proxy/storage
- desktop clients
- account system
