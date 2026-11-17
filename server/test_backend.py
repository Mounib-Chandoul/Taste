"""Isolated backend test suite.

Creates a temporary music library with real ID3-tagged MP3 files, a temporary
database, and exercises the API through FastAPI's TestClient. It never reads
or writes the real MUSIC_DIR, .env, or data/ directory.

Run:  .venv\\Scripts\\python.exe test_backend.py
"""

from __future__ import annotations

import os
import shutil
import sys
import tempfile
import wave

from mutagen.id3 import ID3, TALB, TCON, TDRC, TIT2, TPE1, TPE2, TRCK

SERVER_DIR = os.path.dirname(os.path.abspath(__file__))
if SERVER_DIR not in sys.path:
    sys.path.insert(0, SERVER_DIR)

_TMP = tempfile.mkdtemp(prefix="musiclab-backend-test-")
_MUSIC = os.path.join(_TMP, "music")
os.makedirs(_MUSIC, exist_ok=True)

os.environ["DATA_DIR"] = os.path.join(_TMP, "data")
os.environ["MUSIC_DIR"] = _MUSIC
os.environ["ADMIN_USER"] = "tester"
os.environ["ADMIN_PASSWORD"] = "testpass"
os.environ["SCAN_ON_START"] = "0"
os.environ["WEB_DIR"] = ""

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402
from app.scanner import is_scanning, scan_library  # noqa: E402

RESULTS: list[tuple[str, bool, str]] = []


def check(name: str, ok: bool, detail: str = "") -> None:
    RESULTS.append((name, bool(ok), detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name} {detail}")


# ------------------------------------------------------- fixture generation


def make_mp3(path: str, title: str, artist: str, album: str, genre: str, track_no: int) -> None:
    # A few valid MPEG-1 Layer III frames so mutagen can read a duration.
    audio = (b"\xff\xfb\x90\x64" + b"\x00" * 413) * 24
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(audio)
    tags = ID3()
    tags.add(TIT2(encoding=3, text=[title]))
    tags.add(TPE1(encoding=3, text=[artist]))
    tags.add(TPE2(encoding=3, text=[artist]))
    tags.add(TALB(encoding=3, text=[album]))
    tags.add(TRCK(encoding=3, text=[str(track_no)]))
    tags.add(TDRC(encoding=3, text=["2024"]))
    tags.add(TCON(encoding=3, text=[genre]))
    tags.save(path)


def make_wav(path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(8000)
        handle.writeframes(b"\x00\x00" * 8000)


FIXTURES = [
    ("Midnight City", "M83", "Hurry Up Were Dreaming", "Synth-Pop", 1),
    ("Navy Blue", "The Killers", "Battle Born", "Rock", 2),
    ("Sweet Disposition", "The Temper Trap", "Conditions", "Indie", 1),
    ("Creme Brulee", "Cafe Noir", "Accents", "Jazz", 3),
]
for i, (title, artist, album, genre, number) in enumerate(FIXTURES):
    make_mp3(
        os.path.join(_MUSIC, artist, album, f"{number:02d} - {title}.mp3"),
        title, artist, album, genre, number,
    )
make_wav(os.path.join(_MUSIC, "Untagged", "plain tone.wav"))
with open(os.path.join(_MUSIC, ".hidden-track.mp3"), "wb") as handle:
    handle.write(b"not audio")


# ------------------------------------------------------------------- tests

with TestClient(app) as client:
    r = client.get("/health")
    check("unauthenticated health", r.status_code == 200, f"({r.status_code})")

    r = client.post("/api/login", json={"username": "tester", "password": "wrong"})
    check("wrong password -> 401", r.status_code == 401, f"({r.status_code})")

    r = client.get("/api/library")
    check("missing token -> 401", r.status_code == 401, f"({r.status_code})")

    r = client.post("/api/login", json={"username": "tester", "password": "testpass"})
    token = r.json()["token"] if r.status_code == 200 else ""
    headers = {"Authorization": f"Bearer {token}"}
    check("login", r.status_code == 200 and bool(token), f"({r.status_code})")

    scan_library(_MUSIC)
    r = client.get("/api/status", headers=headers)
    state = r.json()
    check("scan indexed files", state["tracks"] == 5 and state["albums"] == 5, str(state))
    check("fts5 engine active", state["search_engine"] == "fts5-trigram", state["search_engine"])
    version = state["version"]

    r = client.get("/api/library", headers=headers)
    lib = r.json()
    tracks = lib["tracks"]
    by_title = {t["title"]: t for t in tracks}
    check("library complete", len(tracks) == 5, f"{len(tracks)} tracks")
    check("hidden file skipped", all("hidden" not in t["title"] for t in tracks))
    check("tags read", by_title["Midnight City"]["genre"] == "Synth-Pop")
    check("stable uid present", all(t["uid"] for t in tracks))
    etag = r.headers.get("etag")
    r2 = client.get("/api/library", headers={**headers, "If-None-Match": etag})
    check("etag revalidation -> 304", r2.status_code == 304 and not r2.content, f"({r2.status_code})")

    track_id = by_title["Midnight City"]["id"]

    for query, expected in [
        ("midn", "Midnight City"),
        ("M83", "Midnight City"),
        ("navy", "Navy Blue"),
        ("cafe noir", "Creme Brulee"),  # accent/punctuation tolerant
        ("disposition", "Sweet Disposition"),
    ]:
        r = client.get("/api/search", params={"q": query}, headers=headers)
        results = r.json()["tracks"]
        ok = r.status_code == 200 and bool(results) and results[0]["title"] == expected
        check(f"search {query!r}", ok, f"top={[t['title'] for t in results[:3]]}")

    r = client.get("/api/search", params={"q": "zzzznotfound"}, headers=headers)
    check("search no matches", r.status_code == 200 and r.json()["tracks"] == [])

    r = client.get(f"/api/stream/{track_id}", headers={**headers, "Range": "bytes=0-1023"})
    check("range 0-1023 -> 206", r.status_code == 206 and len(r.content) == 1024,
          f"({r.status_code}, {len(r.content)}B)")

    r = client.get(f"/api/stream/{track_id}", headers={**headers, "Range": "bytes=-500"})
    check("suffix range -> 206", r.status_code == 206 and len(r.content) == 500,
          f"({r.status_code}, {len(r.content)}B)")

    r = client.get(f"/api/stream/{track_id}", headers={**headers, "Range": "bytes=999999-"})
    check("bad range -> 416", r.status_code == 416, f"({r.status_code})")

    r = client.get(f"/api/stream/{track_id}", headers={**headers, "Range": "bytes=0-99,200-299"})
    check("multi-range -> 416", r.status_code == 416, f"({r.status_code})")

    r = client.head(f"/api/stream/{track_id}", headers={**headers, "Range": "bytes=0-1023"})
    check("HEAD stream", r.status_code == 206 and not r.content
          and r.headers.get("content-length") == "1024",
          f"({r.status_code}, {r.headers.get('content-length')})")

    r = client.get(f"/api/download/{track_id}", headers=headers)
    check("download full file", r.status_code == 200 and len(r.content) > 5000,
          f"({r.status_code}, {len(r.content)}B)")

    r = client.get("/api/genres", headers=headers)
    check("genres aggregated", len(r.json()["genres"]) >= 4, str(r.json()["genres"]))

    r = client.get("/api/random", params={"limit": 2}, headers=headers)
    check("random discovery", r.status_code == 200 and len(r.json()["tracks"]) == 2)

    r = client.post("/api/playlists", json={"name": "Road Trip"}, headers=headers)
    playlist_id = r.json()["id"]
    check("playlist create", r.status_code == 200 and playlist_id > 0)

    ids = [t["id"] for t in tracks[:3]]
    for tid in ids:
        client.post(f"/api/playlists/{playlist_id}/tracks", json={"track_id": tid}, headers=headers)
    r = client.get("/api/playlists", headers=headers)
    order = r.json()["playlists"][0]["track_ids"]
    check("playlist add keeps order", order == ids, str(order))

    r = client.put(f"/api/playlists/{playlist_id}/tracks",
                   json={"track_ids": list(reversed(ids))}, headers=headers)
    check("playlist reorder", r.json()["track_ids"] == list(reversed(ids)))

    r = client.patch(f"/api/playlists/{playlist_id}", json={"name": "Renamed"}, headers=headers)
    check("playlist rename", r.json()["name"] == "Renamed")

    r = client.delete(f"/api/playlists/{playlist_id}", headers=headers)
    check("playlist delete", r.status_code == 200 and r.json()["ok"])

    r = client.get(f"/api/cover/{by_title['Midnight City']['album_id']}")
    check("cover without auth -> 401", r.status_code == 401, f"({r.status_code})")
    r = client.get(f"/api/cover/{by_title['Midnight City']['album_id']}?token={token}")
    check("cover with query token", r.status_code in (200, 404), f"({r.status_code})")

    # Idempotent rescan must not bump the revision.
    scan_library(_MUSIC)
    r = client.get("/api/status", headers=headers)
    check("rescan is idempotent", r.json()["version"] == version, f"{version} -> {r.json()['version']}")

    os.remove(os.path.join(_MUSIC, "M83", "Hurry Up Were Dreaming", "01 - Midnight City.mp3"))
    scan_library(_MUSIC)
    r = client.get("/api/status", headers=headers)
    check("deletion bumps revision", r.json()["version"] != version and r.json()["tracks"] == 4,
          f"{r.json()['version']}, tracks={r.json()['tracks']}")

    r = client.post("/api/logout", headers=headers)
    check("logout", r.status_code == 200, f"({r.status_code})")
    r = client.get("/api/library", headers=headers)
    check("revoked token rejected", r.status_code == 401, f"({r.status_code})")

check("scan lock released", not is_scanning())

failed = [item for item in RESULTS if not item[1]]
print(f"\n{len(RESULTS) - len(failed)}/{len(RESULTS)} passed")
shutil.rmtree(_TMP, ignore_errors=True)
if failed:
    raise SystemExit(1)
