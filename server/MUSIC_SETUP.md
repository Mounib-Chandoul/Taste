# Feeding Music Lab: folders, tags, filenames and search

Short version: **put files in `Artist / Album / track` folders, tag them properly, and leave the filenames alone once they're tagged.** The server reads tags, not filenames, for search.

---

## 1. The folder layout to use

```
C:\Music\
├── M83\
│   └── Hurry Up, We're Dreaming (2011)\
│       ├── folder.jpg                 <- optional album art
│       ├── 01 - Intro.flac
│       ├── 02 - Midnight City.flac
│       └── 03 - Reunion.flac
├── The Killers\
│   └── Battle Born (2012)\
│       ├── 01 - Flesh and Bone.flac
│       └── 02 - The Way It Was.flac
├── Various Artists\
│   └── Indie Mix Vol 1\
│       └── ...
└── Podcasts\                         <- anything audio is indexed
    └── Episode 12.mp3
```

Rules the scanner follows:

- Any `.mp3 .flac .m4a .mp4 .ogg .opus .wav .wma .aac` file anywhere under `MUSIC_DIR` is indexed. Depth does not matter.
- The folder name is **not** used for artist/album metadata. Tags are. Folder names are only a human convenience and a fallback for cover art.
- Multi-disc albums: either set the `discnumber` tag on every track, or use `CD1 / CD2` subfolders. Both work; the tag is better. Tracks are ordered by artist → album → disc → track number.
- Compilations: use one album folder with `albumartist = Various Artists` and per-track `artist` values. The server groups albums by `(album, albumartist)`, so you get one compilation album, not 40.

Ignored automatically: hidden files/folders (`.something`, `~$temp`), `@eaDir`, `#recycle`, `__MACOSX`, `System Volume Information`, `$RECYCLE.BIN`, `.git`, `node_modules`, and `.tmp / .part / .crdownload` files. Zero-byte files are skipped too.

**You do not need to restart for changes** — call `POST /api/scan` (or just restart; startup auto-scans). The scan is incremental: it stats every file but only re-reads tags when size, mtime, or relative path changed.

---

## 2. Should you rename songs for better search?

**No — not for search.** Here is the exact precedence:

| Field | Source |
|---|---|
| Title | `title` tag → falls back to filename without extension |
| Artist | `artist` tag → falls back to `Unknown Artist` |
| Album | `album` tag → falls back to `Unknown Album` |
| Genre / year / track / disc | tags only |

Search indexes only the resolved fields. If every track has a `title`/`artist`/`album` tag, renaming the file changes **nothing** about search results.

There are two real reasons to keep filenames tidy anyway:

1. **Safety net for untagged files.** A file with no tags becomes `01 - Midnight City` as its title — including the number. A clean name makes that tolerable.
2. **`uid` stability.** Each track gets a stable id derived from its path *relative to MUSIC_DIR*. Client-side caches, downloaded files, and "recently played" references key on `uid`. Renaming or moving a file changes its uid, so the app sees an old item disappear and a new one appear. If you are going to rename, do it **before** you start downloading tracks for offline.

Recommended filename format (for browsing and as fallback):

```
NN - Title.ext          01 - Midnight City.flac
```

Optional but nice: `Artist - Title.ext` for singles/singletons.

---

## 3. Which tags to fill

Minimum set that makes the library feel like a real music app:

- `title`
- `artist` (the performing artist for that track)
- `albumartist` (the album-level artist — crucial for compilations)
- `album`
- `tracknumber`
- `discnumber` (multi-disc only)
- `date` / `year`
- `genre` ← this powers genre filtering and is a weighted search field

Tools that do the heavy lifting on Windows:

- **MusicBrainz Picard** — best for bulk automatic tagging. Drag a folder in, cluster, "Scan with AcoustID", then "Save". It fills all of the above including `genre` (via Last.fm styles) and `discnumber`.
- **Mp3tag** — best for manual cleanup and filename-from-tag operations. Format string:
  ```
  %albumartist%\%album%\$num(%track%,2) - %title%
  ```
- **beets** — scriptable CLI if you like automation:
  ```yaml
  # ~/.config/beets/config.yaml
  directory: C:\Users\salty\Music
  library: C:\Music\beets.db
  import:
    copy: yes      # keep your originals
    write: yes     # write tags into the copied files
  paths:
    default: $albumartist/$album%aunique{}/$disc-$track $title
    singleton: $artist/$title
    comp: Various Artists/$album/$track $title
  ```
  Then `beet import "D:\Downloads\new stuff"`.

Do not transcode FLAC → MP3 → FLAC. Keep one canonical lossless copy; transcode *down* only if you need smaller files for a phone.

---

## 4. Formats

| Format | Streams to web? | Notes |
|---|---|---|
| FLAC | Chrome/Firefox/Edge yes, Safari varies | Best quality, embedded art + tags. Recommended. |
| MP3 | everywhere | Safest for maximum device compatibility. 320 kbps or VBR V0. |
| M4A / AAC | yes | Good for Apple devices. |
| OGG / Opus | Chrome/Firefox yes, Safari limited | Efficient, small. |
| WAV | yes | Untagged, big. Fine for short clips. |
| WMA | browser support poor | Server streams it, but most browsers cannot decode it. Avoid for web playback. |

The server **never transcodes**. It streams the original bytes with HTTP Range support, so decoding happens entirely on the client.

---

## 5. Cover art

The server tries, in order:

1. Embedded picture in the first track that has one (ID3 APIC for MP3, FLAC pictures, MP4 `covr`, Ogg/Opus pictures).
2. A sibling image named `folder.jpg`, `folder.png`, `cover.jpg`, `cover.png`, `front.jpg`, `front.png`, `album.jpg`, `album.png`, `art.jpg`, `art.png`.

The first successful extraction is cached once in `data/covers/` and never re-read. If you add art later, delete the matching file in `data/covers/` (or just restart after removing it) and hit `GET /api/cover/{id}` again.

---

## 6. How the search actually works

The "algo" in one paragraph:

- On each scan the server rebuilds an **SQLite FTS5 trigram index** over normalised `title`, `artist`, `album` and `genre`. Normalisation = Unicode accent folding, lowercase, punctuation → spaces. So `Café Noir` is stored as `cafe noir`, and `Créme Brûlée` as `creme brulee`.
- A trigram index stores every 3-character slice, which is why **mid-word and partial matches work**: `midn`, `ght cit`, `dispo` all find the right track. Multi-word queries AND together, each token as a prefix: `mid cit` → `Midnight City`.
- Hits are ranked with **weighted BM25**: title ×10, artist ×5, album ×2, genre ×1. Searching `m83` therefore returns M83's tracks instead of a compilation that happens to mention the word.
- Queries shorter than 3 characters fall back to a `LIKE` scan (trigrams cannot index 1–2 character terms). Builds without FTS5 fall back to an in-process scorer. Both are transparent.
- Results are deduplicated and grouped into `tracks`, `albums`, `artists`.

Try it:

```powershell
curl "http://localhost:4533/api/search?q=midn" -H "Authorization: Bearer <token>"
```

Other discovery endpoints added for future UI work: `GET /api/genres` (genre counts) and `GET /api/random?limit=20`.

---

## 7. Sync flow for the app

`GET /api/library` returns a `version` (a monotonic revision counter) and an `ETag` header. The client should:

1. Store `version` locally.
2. On refresh, send `If-None-Match: W/"<version>"`.
3. If the response is `304`, do nothing — no JSON download.
4. Otherwise replace the cached library with the new response.

The old `count-max_id-max_mtime` version could stay constant if you deleted the newest track and added an older one. The monotonic counter cannot.

---

## 8. Operational checklist

```powershell
cd music-lab\server
.\.venv\Scripts\Activate.ps1

# 1. confirm config (edit .env if needed; the server never writes it)
type .env

# 2. start the server (it auto-scans on startup)
uvicorn app.main:app --host 0.0.0.0 --port 4533

# 3. from another terminal: check what it found
curl http://localhost:4533/health
```

Then in the app: Server = `http://localhost:4533` (or `http://<pc-lan-ip>:4533`), user/password from `.env`.

After adding music: call `POST /api/scan` (needs the bearer token) or restart the server, then check `GET /api/status`.

Run the isolated self-tests any time without touching your real library:

```powershell
.\.venv\Scripts\python.exe test_backend.py
.\.venv\Scripts\python.exe test_migration.py
```
