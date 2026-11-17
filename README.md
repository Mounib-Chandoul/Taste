# Taste — Music Lab

A self-hosted, LAN-first music player. Run the FastAPI server on your PC, point
the Flutter app at it, and stream your own library on web, Android or desktop —
no cloud account, no transcoding, no subscription.

## Features

- **FastAPI backend** with SQLite WAL, incremental scanning and additive migrations.
- **Real search** — FTS5 trigram index with accent folding and weighted BM25
  ranking (title ×10, artist ×5, album ×2, genre ×1). Partial and mid-word
  queries like `midn` or `ght cit` work.
- **Efficient sync** — monotonic library revision + `ETag` / `304` responses.
- **Range streaming** with seeking, `HEAD` support and safe mid-stream disconnects.
- **Auth** — HMAC-signed tokens, constant-time comparison, login throttling and
  per-token revocation. Media endpoints also accept `?token=` for browsers.
- **Pixel-style Flutter client** — responsive web/Android/desktop UI, ranked
  search, genres, random tracks, playlists, shuffle/repeat, and a queue-first
  Now Playing screen with a live spectrum monitor and time widgets.
- **Offline downloads on Android** — full files cached locally and played with
  zero connection.
- **No transcoding** — original bytes are streamed; the client decodes them.

## Layout

```
music-lab/
├── server/   FastAPI + SQLite API, scanner, search index, tests
└── app/      Flutter client (lib/main.dart → Pixel UI)
```

Key docs: [server setup](server/README.md),
[music folders & tagging](server/MUSIC_SETUP.md),
[Flutter app](app/README.md).

## Quick start

### 1. Server

```powershell
cd server
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env      # then set MUSIC_DIR and admin credentials
uvicorn app.main:app --host 0.0.0.0 --port 4533
```

Check: `http://localhost:4533/health` → `{"ok":true,...}`.
API docs: `http://localhost:4533/docs`.

To let a phone in on Windows, allow the port once:

```powershell
netsh advfirewall firewall add rule name="Music Lab" dir=in action=allow protocol=TCP localport=4533
```

### 2. App

```powershell
cd app
flutter pub get
flutter run        # or: flutter build web --release / flutter build apk
```

Enter `http://<pc-ip>:4533` as the Server, plus the credentials from `.env`.
Leave the Server field blank to explore the built-in demo data.

## Configuration

All server settings come from `server/.env` (see `.env.example`):

| Variable | Purpose |
|---|---|
| `MUSIC_DIR` | Folder that is scanned read-only |
| `ADMIN_USER` / `ADMIN_PASSWORD` | App login |
| `TOKEN_TTL_DAYS` | Token lifetime (default 90) |
| `SCAN_ON_START` | Auto-scan on startup (default 1) |
| `LOGIN_MAX_ATTEMPTS` / `LOGIN_WINDOW_SECONDS` | Login throttle |
| `DATA_DIR` | Database and cover cache location |
| `WEB_DIR` | Optional Flutter web build served from the same port |

Your real `.env`, database, cover cache and token secret are git-ignored.

## API

`POST /api/login` returns a token; send `Authorization: Bearer <token>` on other
`/api` calls. Endpoints: `/health`, `/api/status`, `/api/library`,
`/api/search`, `/api/genres`, `/api/random`, `/api/stream/{id}`,
`/api/download/{id}`, `/api/cover/{id}`, `/api/playlists`, `/api/scan`,
`/api/logout`. See the [server README](server/README.md#api-contract) for details.

## Tests

```powershell
# backend (49 checks, no real library touched)
cd server
.\.venv\Scripts\python.exe test_backend.py
.\.venv\Scripts\python.exe test_migration.py

# client
cd ..\app
flutter test
flutter analyze --no-fatal-infos
flutter build web --release
```

## Music sources

Use music you own or that is explicitly free. Public-domain / CC0 sources such
as [Free Music Archive](https://freemusicarchive.org/),
[Incompetech](https://incompetech.com/) and
[Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:Audio_files)
are good starting points. Some CC licenses require attribution — check each
track's license. No pirated content, please.

## License

[MIT](LICENSE).
