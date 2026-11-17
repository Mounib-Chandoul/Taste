"""Music Lab HTTP API.

Contract is additive: every response from v1 keeps its original fields, so
existing app builds continue to work while new clients can use search, ETag
revalidation, genres, and playlist ordering.
"""

from __future__ import annotations

import asyncio
import mimetypes
import os
import re
from contextlib import asynccontextmanager
from typing import Any

from fastapi import Depends, FastAPI, Header, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from sqlalchemy import func, text
from sqlalchemy.orm import Session

from .auth import login as auth_login
from .auth import revoke, verify, verify_flexible
from .config import MUSIC_DIR, SCAN_ON_START, WEB_DIR
from .db import get_db, get_meta, init_db, session_scope
from .models import Album, Playlist, PlaylistTrack, Track
from .scanner import ensure_cover_path, is_scanning, scan_library
from .search import fts_available, search_ids

CHUNK = 64 * 1024

MIME = {
    ".mp3": "audio/mpeg",
    ".flac": "audio/flac",
    ".m4a": "audio/mp4",
    ".mp4": "audio/mp4",
    ".ogg": "audio/ogg",
    ".opus": "audio/ogg",
    ".wav": "audio/wav",
    ".wma": "audio/x-ms-wma",
    ".aac": "audio/aac",
}


@asynccontextmanager
async def lifespan(_app: FastAPI):
    init_db()
    # Scan off the event loop so the server can answer immediately.
    if SCAN_ON_START and MUSIC_DIR and os.path.isdir(MUSIC_DIR):
        await asyncio.to_thread(scan_library, MUSIC_DIR)
    yield


app = FastAPI(title="Music Lab", version="0.2.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # phones on the LAN; auth is via bearer token
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Range", "ETag"],
)


# ------------------------------------------------------------------ helpers


def _album_dto(album: Album) -> dict[str, Any]:
    return {
        "id": album.id,
        "name": album.name,
        "artist": album.artist,
        "year": album.year,
        "cover": f"/api/cover/{album.id}",
    }


def _track_dto(track: Track, album_name: str | None = None) -> dict[str, Any]:
    return {
        "id": track.id,
        "uid": track.uid,
        "title": track.title,
        "artist": track.artist,
        "album": album_name,
        "album_id": track.album_id,
        "track_no": track.track_no,
        "disc_no": track.disc_no,
        "genre": track.genre,
        "duration": track.duration,
        "size": track.size,
        "ext": track.ext,
        "stream": f"/api/stream/{track.id}",
        "download": f"/api/download/{track.id}",
    }


def _track_info(track_id: int) -> dict[str, Any]:
    """Return plain values, never a detached ORM object."""
    with session_scope() as session:
        track = session.get(Track, track_id)
        if track is None:
            raise HTTPException(status_code=404, detail="Track not found")
        info = {
            "id": track.id,
            "path": track.path,
            "size": int(track.size or 0),
            "ext": track.ext,
            "mime": MIME.get(track.ext, "application/octet-stream"),
        }
    if not os.path.isfile(info["path"]):
        raise HTTPException(status_code=404, detail="Track file missing")
    return info


def _parse_range(header: str, size: int) -> tuple[int, int, bool]:
    """Return (start, end, partial). Raises 416 for unsatisfiable ranges."""
    if size <= 0:
        raise HTTPException(status_code=416, detail="Range not satisfiable")
    raw = header.strip()
    if "," in raw:
        # Multi-part ranges are pointless for audio players; reject clearly.
        raise HTTPException(status_code=416, detail="Multiple ranges not supported")
    match = re.fullmatch(r"bytes=(\d*)-(\d*)", raw)
    if not match or (not match.group(1) and not match.group(2)):
        raise HTTPException(status_code=416, detail="Malformed Range header")

    start_s, end_s = match.group(1), match.group(2)
    if not start_s:  # suffix range: last N bytes
        count = int(end_s)
        if count <= 0:
            raise HTTPException(status_code=416, detail="Range not satisfiable")
        start = max(0, size - count)
        end = size - 1
    else:
        start = int(start_s)
        end = int(end_s) if end_s else size - 1
        end = min(end, size - 1)

    if start >= size or start > end:
        raise HTTPException(status_code=416, detail="Range not satisfiable")
    return start, end, True


# -------------------------------------------------------------------- auth


class LoginBody(BaseModel):
    username: str
    password: str


@app.post("/api/login")
def do_login(body: LoginBody, request: Request):
    client_ip = request.client.host if request.client else ""
    return auth_login(body.username, body.password, client_ip)


@app.post("/api/logout")
def do_logout(authorization: str | None = Header(default=None)):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing token")
    revoke(authorization.split(" ", 1)[1].strip())
    return {"ok": True}


# ------------------------------------------------------------- health/meta


@app.get("/health")
def health():
    """Unauthenticated liveness probe for launchers and reverse proxies."""
    return {"ok": True, "service": "music-lab"}


@app.post("/api/scan")
def do_scan(user: str = Depends(verify)):
    if not MUSIC_DIR or not os.path.isdir(MUSIC_DIR):
        raise HTTPException(status_code=400, detail=f"MUSIC_DIR not found: {MUSIC_DIR!r}")
    started = scan_library(MUSIC_DIR)
    return {"status": "scanning" if started else "already_scanning", "scanning": is_scanning()}


@app.get("/api/status")
def status(user: str = Depends(verify)):
    with session_scope() as session:
        return {
            "scanning": is_scanning(),
            "tracks": session.query(Track).count(),
            "albums": session.query(Album).count(),
            "version": get_meta(session),
            "search_engine": "fts5-trigram" if fts_available() else "substring-fallback",
            "music_dir": MUSIC_DIR,
        }


# ----------------------------------------------------------------- library


@app.get("/api/library")
def library(request: Request, user: str = Depends(verify)):
    """Full library dump.

    Clients may send ``If-None-Match: <version>``; an unchanged library
    answers 304 with no body, which makes periodic sync essentially free.
    """
    with session_scope() as session:
        version = get_meta(session)
        etag = f'W/"{version}"'
        if request.headers.get("if-none-match", "").strip() in {etag, version}:
            return Response(status_code=304, headers={"ETag": etag})

        albums = session.query(Album).order_by(Album.artist, Album.name, Album.id).all()
        tracks = (
            session.query(Track)
            .outerjoin(Album, Track.album_id == Album.id)
            .order_by(Track.artist, Album.name, Track.disc_no, Track.track_no, Track.id)
            .all()
        )
        album_names = {a.id: a.name for a in albums}
        payload = {
            "version": version,
            "albums": [_album_dto(a) for a in albums],
            "tracks": [_track_dto(t, album_names.get(t.album_id)) for t in tracks],
        }
    return JSONResponse(payload, headers={"ETag": etag})


@app.get("/api/genres")
def genres(user: str = Depends(verify)):
    with session_scope() as session:
        rows = (
            session.execute(
                text(
                    "SELECT genre, count(*) AS n FROM tracks "
                    "WHERE genre IS NOT NULL AND trim(genre) <> '' "
                    "GROUP BY genre ORDER BY n DESC, genre COLLATE NOCASE"
                )
            )
            .all()
        )
        return {"genres": [{"name": name, "count": int(count)} for name, count in rows]}


@app.get("/api/random")
def random_tracks(limit: int = 20, user: str = Depends(verify)):
    limit = max(1, min(limit, 100))
    with session_scope() as session:
        tracks = (
            session.query(Track)
            .outerjoin(Album, Track.album_id == Album.id)
            .order_by(func.random())
            .limit(limit)
            .all()
        )
        album_names = {
            a.id: a.name for a in session.query(Album).filter(
                Album.id.in_([t.album_id for t in tracks])
            )
        }
        return {"tracks": [_track_dto(t, album_names.get(t.album_id)) for t in tracks]}


# ------------------------------------------------------------------ search


class SearchResponse(BaseModel):
    query: str
    tracks: list[dict[str, Any]]
    albums: list[dict[str, Any]]
    artists: list[dict[str, Any]]


@app.get("/api/search", response_model=SearchResponse)
def search(q: str = "", limit: int = 30, user: str = Depends(verify)):
    """Ranked substring search across tracks, albums and artists.

    ``q`` is accent-insensitive and works on partial words ("midn", "m83").
    Results are grouped, each group capped at ``limit`` (max 50).
    """
    limit = max(1, min(limit, 50))
    with session_scope() as session:
        ids = search_ids(session, q, limit)

        tracks: list[dict[str, Any]] = []
        if ids["tracks"]:
            found = session.query(Track).filter(Track.id.in_(ids["tracks"])).all()
            by_id = {t.id: t for t in found}
            album_ids = [t.album_id for t in by_id.values()]
            album_names = {
                a.id: a.name
                for a in session.query(Album).filter(Album.id.in_(album_ids)).all()
            }
            for track_id in ids["tracks"]:
                track = by_id.get(int(track_id))
                if track:
                    tracks.append(_track_dto(track, album_names.get(track.album_id)))

        albums: list[dict[str, Any]] = []
        if ids["albums"]:
            found_albums = session.query(Album).filter(Album.id.in_(ids["albums"])).all()
            by_album = {a.id: a for a in found_albums}
            for album_id in ids["albums"]:
                album = by_album.get(int(album_id))
                if album:
                    albums.append(_album_dto(album))

        artists: list[dict[str, Any]] = []
        if ids["artists"]:
            counts = dict(
                session.query(Track.artist, func.count())
                .filter(Track.artist.in_(ids["artists"]))
                .group_by(Track.artist)
                .all()
            )
            for name in ids["artists"]:
                artists.append({"name": name, "track_count": int(counts.get(name, 0))})

        return {"query": q, "tracks": tracks, "albums": albums, "artists": artists}


# ------------------------------------------------------------------- cover


@app.get("/api/cover/{album_id}")
def cover(album_id: int, user: str = Depends(verify_flexible)):
    with session_scope() as session:
        album = session.get(Album, album_id)
        if album is None:
            raise HTTPException(status_code=404, detail="Album not found")
        path = ensure_cover_path(session, album)
    if path and os.path.isfile(path):
        media_type = mimetypes.guess_type(path)[0] or "image/jpeg"
        return FileResponse(
            path,
            media_type=media_type,
            headers={"Cache-Control": "public, max-age=604800, immutable"},
        )
    raise HTTPException(status_code=404, detail="No cover art")


# ------------------------------------------------------------------- audio


@app.api_route("/api/stream/{track_id}", methods=["GET", "HEAD"])
def stream(track_id: int, request: Request, user: str = Depends(verify_flexible)):
    """Range-capable streaming with seeking support."""
    track = _track_info(track_id)
    size = track["size"]
    start, end = 0, max(size - 1, 0)
    partial = False

    range_header = request.headers.get("range")
    if range_header:
        start, end, partial = _parse_range(range_header, size)

    length = end - start + 1 if size > 0 else 0
    headers = {
        "Content-Type": track["mime"],
        "Accept-Ranges": "bytes",
        "Content-Length": str(length),
        "Cache-Control": "no-store",
    }
    if partial:
        headers["Content-Range"] = f"bytes {start}-{end}/{size}"
        status_code = 206
    else:
        status_code = 200

    if request.method == "HEAD":
        return Response(status_code=status_code, headers=headers)

    def generate():
        if length <= 0:
            return
        try:
            with open(track["path"], "rb") as handle:
                handle.seek(start)
                remaining = length
                while remaining > 0:
                    chunk = handle.read(min(CHUNK, remaining))
                    if not chunk:
                        break
                    remaining -= len(chunk)
                    yield chunk
        except OSError:
            # The file may vanish mid-stream (external drive unplugged).
            # Closing the generator is the only safe response at this point.
            return

    return StreamingResponse(generate(), status_code=status_code, headers=headers)


@app.get("/api/download/{track_id}")
def download(track_id: int, user: str = Depends(verify_flexible)):
    """Full file for offline caching (Starlette handles Range requests here)."""
    track = _track_info(track_id)
    return FileResponse(
        track["path"],
        media_type=track["mime"],
        filename=os.path.basename(track["path"]),
        headers={"Accept-Ranges": "bytes"},
    )


# --------------------------------------------------------------- playlists


class PlaylistCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)


class PlaylistTrackAdd(BaseModel):
    track_id: int


class PlaylistOrder(BaseModel):
    track_ids: list[int]


def _owned_playlist(session: Session, playlist_id: int, user: str) -> Playlist:
    playlist = session.get(Playlist, playlist_id)
    if playlist is None or playlist.owner != user:
        raise HTTPException(status_code=404, detail="Playlist not found")
    return playlist


def _playlist_dto(session: Session, playlist: Playlist) -> dict[str, Any]:
    rows = (
        session.query(PlaylistTrack)
        .filter(PlaylistTrack.playlist_id == playlist.id)
        .order_by(PlaylistTrack.position, PlaylistTrack.id)
        .all()
    )
    return {
        "id": playlist.id,
        "name": playlist.name,
        "track_ids": [row.track_id for row in rows],
    }


@app.get("/api/playlists")
def list_playlists(user: str = Depends(verify)):
    with session_scope() as session:
        playlists = (
            session.query(Playlist)
            .filter(Playlist.owner == user)
            .order_by(Playlist.id.desc())
            .all()
        )
        return {"playlists": [_playlist_dto(session, p) for p in playlists]}


@app.post("/api/playlists")
def create_playlist(body: PlaylistCreate, user: str = Depends(verify)):
    with session_scope() as session:
        playlist = Playlist(name=body.name.strip() or "New playlist", owner=user)
        session.add(playlist)
        session.flush()
        return _playlist_dto(session, playlist)


@app.patch("/api/playlists/{playlist_id}")
def rename_playlist(playlist_id: int, body: PlaylistCreate, user: str = Depends(verify)):
    with session_scope() as session:
        playlist = _owned_playlist(session, playlist_id, user)
        playlist.name = body.name.strip() or playlist.name
        return _playlist_dto(session, playlist)


@app.delete("/api/playlists/{playlist_id}")
def delete_playlist(playlist_id: int, user: str = Depends(verify)):
    with session_scope() as session:
        playlist = _owned_playlist(session, playlist_id, user)
        session.query(PlaylistTrack).filter(
            PlaylistTrack.playlist_id == playlist_id
        ).delete(synchronize_session=False)
        session.delete(playlist)
        return {"ok": True}


@app.post("/api/playlists/{playlist_id}/tracks")
def add_playlist_track(playlist_id: int, body: PlaylistTrackAdd, user: str = Depends(verify)):
    with session_scope() as session:
        _owned_playlist(session, playlist_id, user)
        track = session.get(Track, body.track_id)
        if track is None:
            raise HTTPException(status_code=404, detail="Track not found")
        exists = (
            session.query(PlaylistTrack)
            .filter(
                PlaylistTrack.playlist_id == playlist_id,
                PlaylistTrack.track_id == body.track_id,
            )
            .first()
        )
        if exists is None:
            next_pos = (
                session.query(func.coalesce(func.max(PlaylistTrack.position), -1))
                .filter(PlaylistTrack.playlist_id == playlist_id)
                .scalar()
            ) + 1
            session.add(
                PlaylistTrack(
                    playlist_id=playlist_id, track_id=body.track_id, position=next_pos
                )
            )
            session.flush()
        return _playlist_dto(session, session.get(Playlist, playlist_id))


@app.delete("/api/playlists/{playlist_id}/tracks/{track_id}")
def remove_playlist_track(playlist_id: int, track_id: int, user: str = Depends(verify)):
    with session_scope() as session:
        _owned_playlist(session, playlist_id, user)
        session.query(PlaylistTrack).filter(
            PlaylistTrack.playlist_id == playlist_id,
            PlaylistTrack.track_id == track_id,
        ).delete(synchronize_session=False)
        return _playlist_dto(session, session.get(Playlist, playlist_id))


@app.put("/api/playlists/{playlist_id}/tracks")
def reorder_playlist(playlist_id: int, body: PlaylistOrder, user: str = Depends(verify)):
    """Replace the track order in one transaction (drag-and-drop support)."""
    with session_scope() as session:
        _owned_playlist(session, playlist_id, user)
        unique_ids = list(dict.fromkeys(body.track_ids))
        if unique_ids:
            found = {
                row[0]
                for row in session.query(Track.id).filter(Track.id.in_(unique_ids)).all()
            }
            if len(found) != len(unique_ids):
                raise HTTPException(status_code=404, detail="Unknown track in playlist")

        session.query(PlaylistTrack).filter(
            PlaylistTrack.playlist_id == playlist_id
        ).delete(synchronize_session=False)
        session.add_all(
            PlaylistTrack(playlist_id=playlist_id, track_id=track_id, position=pos)
            for pos, track_id in enumerate(unique_ids)
        )
        session.flush()
        return _playlist_dto(session, session.get(Playlist, playlist_id))


# ------------------------------------------------------------------- web UI

# If a Flutter web build is present, serve it from the same origin as the API.
_SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_WEB_CANDIDATES = [
    WEB_DIR,
    os.path.join(_SERVER_DIR, "web"),
    os.path.join(_SERVER_DIR, "..", "app", "build", "web"),
]
for _web_dir in _WEB_CANDIDATES:
    if _web_dir and os.path.isdir(_web_dir) and os.path.isfile(
        os.path.join(_web_dir, "index.html")
    ):
        app.mount("/", StaticFiles(directory=_web_dir, html=True), name="web")
        break
