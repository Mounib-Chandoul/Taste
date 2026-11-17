# Music Lab — server

Self-hosted music server. Runs on your PC, streams to the Flutter app over
LAN / hotspot, and serves full files for offline listening. The server only
**reads** your music folder; all app state lives in `data/`.

## Setup (once)

```powershell
cd music-lab\server
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env   # then edit MUSIC_DIR + admin user/password
```

## Run

```powershell
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --host 0.0.0.0 --port 4533
```

- Health check: http://localhost:4533/health
- Interactive API docs: http://localhost:4533/docs
- The library scans automatically on startup. Status: `GET /api/status`.

**How to arrange your music, tag it, and make search work well → [MUSIC_SETUP.md](MUSIC_SETUP.md).**

## Let the phone in

Allow port 4533 through Windows Firewall (one time, admin PowerShell):

```powershell
netsh advfirewall firewall add rule name="Music Lab" dir=in action=allow protocol=TCP localport=4533
```

Then use `http://<pc-ip>:4533` as the Server in the app. To listen away from
home, enable your phone's hotspot, connect the PC to it, use the PC's hotspot
IP, and download tracks for offline in the app.

## API contract

Auth: `POST /api/login` `{username, password}` → `{token}`; send
`Authorization: Bearer <token>` on every other `/api` call. Media endpoints
also accept `?token=<token>` for clients that cannot set headers.

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Liveness probe (no auth) |
| POST | `/api/login` · `/api/logout` | Session |
| POST | `/api/scan` | Rescan (incremental, locked) |
| GET | `/api/status` | Counts, version, search engine, scanning flag |
| GET | `/api/library` | Full dump; supports `If-None-Match` → `304` |
| GET | `/api/search?q=&limit=` | Ranked substring search (tracks/albums/artists) |
| GET | `/api/genres` | Genre counts |
| GET | `/api/random?limit=` | Discovery shuffle |
| GET | `/api/cover/{album_id}` | Cached cover art |
| GET · HEAD | `/api/stream/{track_id}` | Audio with `Range` seeking |
| GET | `/api/download/{track_id}` | Full file for offline |
| GET · POST · PATCH · DELETE | `/api/playlists` | Playlist CRUD |
| POST · DELETE · PUT | `/api/playlists/{id}/tracks` | Add, remove, reorder |

Supported formats: mp3, flac, m4a/mp4, ogg, opus, wav, wma, aac. The server
never transcodes — clients must decode the original format.

## Design notes

- **SQLite WAL + tuned pragmas** — streams read while the scanner writes.
- **Incremental scan** — mtime + size + relative-path uid; corrupt files are isolated.
- **Stable `uid`** — clients can cache against it across a full rescan.
- **Monotonic `library_revision`** — robust ETag; unchanged libraries answer 304.
- **FTS5 trigram search** — accent-insensitive partial-word matching with weighted BM25 ranking and graceful fallbacks.
- **Auth** — HMAC-signed tokens, constant-time comparison, login throttling, per-token revocation.
- **Range streaming** — suffix/open-ended ranges, `416` for invalid input, `HEAD` support, safe mid-stream disconnects.
- **Additive migrations** — `init_db()` upgrades older databases in place without data loss.

## Files

- `app/config.py` — settings from `.env` (read-only)
- `app/db.py` / `app/models.py` — schema, pragmas, migrations
- `app/scanner.py` — read-only library scan, tags, cover extraction
- `app/search.py` — FTS index + ranking
- `app/auth.py` — login, tokens, throttling, revocation
- `app/main.py` — endpoints
- `test_backend.py` — 37 isolated API checks (real tagged MP3 fixtures)
- `test_migration.py` — 12 checks that an old v1 database upgrades in place
- `smoke_test.py` — legacy live-server check (hardcoded credentials/port)
- `data/` — database, cover cache, token secret (auto-created)

To run the isolated suites (no network, no real library touched):

```powershell
pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe test_backend.py
.\.venv\Scripts\python.exe test_migration.py
```
