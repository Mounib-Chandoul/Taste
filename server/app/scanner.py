"""Read-only library scanner.

Never modifies the music directory. Files are identified by absolute path;
``uid`` is a stable, relative-path-derived id clients may use as a cache key.
The scan is incremental (mtime + size), fault-tolerant per file, and guarded
by a lock so startup scans and manual rescans cannot race.
"""

from __future__ import annotations

import hashlib
import os
import re
import threading
from typing import Any

from mutagen import File as MutagenFile
from mutagen.flac import FLAC
from mutagen.id3 import ID3
from mutagen.mp4 import MP4
from sqlalchemy import text

from .config import COVERS_DIR
from .db import SessionLocal, bump_library_revision
from .models import Album, Track
from .search import rebuild_search_index

AUDIO_EXTS = {".mp3", ".flac", ".m4a", ".mp4", ".ogg", ".opus", ".wav", ".wma", ".aac"}

_SKIP_DIRS = {
    "@eaDir", "#recycle", ".AppleDouble", "__MACOSX", "System Volume Information",
    "$RECYCLE.BIN", ".git", "node_modules", "lost+found",
}

FOLDER_ART_NAMES = (
    "folder.jpg", "folder.png", "cover.jpg", "cover.png", "front.jpg",
    "front.png", "album.jpg", "album.png", "art.jpg", "art.png",
)

_scan_lock = threading.Lock()
_cover_locks_guard = threading.Lock()
_cover_locks: dict[int, threading.Lock] = {}


def is_scanning() -> bool:
    return _scan_lock.locked()


def scan_library(music_dir: str) -> bool:
    """Start a scan if one is not running. Returns False if already scanning."""
    if not _scan_lock.acquire(blocking=False):
        return False
    try:
        _scan(music_dir)
        return True
    finally:
        _scan_lock.release()


def _is_junk(name: str) -> bool:
    return (
        name in _SKIP_DIRS
        or name.startswith(".")
        or name.startswith("~$")
        or name.endswith((".tmp", ".part", ".crdownload", ".!ut"))
    )


def _uid_for(path: str, music_dir: str) -> str:
    relative = os.path.relpath(path, music_dir).replace("\\", "/").casefold()
    return hashlib.sha1(relative.encode("utf-8")).hexdigest()[:20]


def _scan(music_dir: str) -> None:
    session = SessionLocal()
    changed = False
    try:
        existing: dict[str, Track] = {t.path: t for t in session.query(Track).all()}
        albums: dict[tuple[str, str], Album] = {
            (a.name.casefold(), a.artist.casefold()): a for a in session.query(Album).all()
        }
        seen: set[str] = set()

        for root, dirs, files in os.walk(music_dir):
            dirs[:] = [d for d in dirs if not _is_junk(d)]
            for name in files:
                if _is_junk(name) or os.path.splitext(name)[1].lower() not in AUDIO_EXTS:
                    continue
                path = os.path.join(root, name)
                seen.add(path)
                try:
                    stat = os.stat(path)
                    mtime, size = stat.st_mtime, stat.st_size
                    if size <= 0:
                        continue
                except OSError:
                    continue

                track = existing.get(path)
                uid = _uid_for(path, music_dir)
                if (
                    track is not None
                    and track.mtime == mtime
                    and track.size == size
                    and track.uid == uid
                ):
                    continue  # unchanged — the common case, no tag read

                try:
                    tags = _read_tags(path)
                except Exception:
                    # One corrupt/unreadable file must never abort the scan.
                    continue
                if tags is None:
                    continue

                album = _get_or_create_album(session, albums, tags)

                if track is None:
                    track = Track(path=path)
                    session.add(track)
                track.title = tags["title"]
                track.artist = tags["artist"]
                track.album_id = album.id
                track.track_no = tags["track_no"]
                track.disc_no = tags["disc_no"]
                track.genre = tags["genre"]
                track.duration = tags["duration"]
                track.ext = os.path.splitext(name)[1].lower()
                track.size = size
                track.mtime = mtime
                track.uid = uid
                changed = True

        for path, track in existing.items():
            if path not in seen:
                session.delete(track)
                changed = True

        if changed:
            # autoflush is off, so pending inserts must be written inside this
            # transaction before the cleanup/index queries can see them.
            session.flush()

            # Drop albums left with no tracks (e.g. an unplugged drive).
            used_album_ids = {
                int(row[0]) for row in session.execute(text("SELECT DISTINCT album_id FROM tracks"))
            }
            for album in albums.values():
                if album.id not in used_album_ids:
                    session.delete(album)

            # Make the orphan deletions visible to the index rebuild below.
            session.flush()

            bump_library_revision(session)
            rebuild_search_index(session)

        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def _read_tags(path: str) -> dict[str, Any] | None:
    mf = MutagenFile(path, easy=True)
    if mf is None or getattr(mf, "info", None) is None:
        return None

    def first(key: str, default: str = "") -> str:
        vals = mf.get(key) or []
        return str(vals[0]).strip() if vals else default

    track_no = _leading_int(first("tracknumber"))
    disc_no = _leading_int(first("discnumber"))

    raw_date = first("date")
    year = int(raw_date[:4]) if len(raw_date) >= 4 and raw_date[:4].isdigit() else None

    # Fall back to the filename when tags are missing. A predictable filename
    # format is therefore useful, but correctly tagged files always win.
    filename = os.path.splitext(os.path.basename(path))[0]
    title = first("title") or filename
    artist = first("artist") or "Unknown Artist"
    album = first("album") or "Unknown Album"
    albumartist = first("albumartist") or artist

    return {
        "title": title,
        "artist": artist,
        "album": album,
        "albumartist": albumartist,
        "track_no": track_no,
        "disc_no": disc_no,
        "genre": first("genre") or None,
        "year": year,
        "duration": float(mf.info.length or 0.0),
    }


def _leading_int(value: str) -> int | None:
    match = re.match(r"\s*(\d+)", value or "")
    return int(match.group(1)) if match else None


def _get_or_create_album(
    session, albums: dict[tuple[str, str], Album], tags: dict[str, Any]
) -> Album:
    key = (tags["album"].casefold(), tags["albumartist"].casefold())
    album = albums.get(key)
    if album is None:
        album = Album(
            name=tags["album"],
            artist=tags["albumartist"],
            year=tags["year"],
        )
        session.add(album)
        session.flush()  # obtain album.id before tracks reference it
        albums[key] = album
    elif album.year is None and tags["year"] is not None:
        album.year = tags["year"]
    return album


def cover_filename(album: Album) -> str:
    """Stable filename for an album's cover art (lazily filled by ensure_cover_path)."""
    key = f"{album.name.lower()}|{album.artist.lower()}".encode()
    return f"{hashlib.md5(key).hexdigest()}_a{album.id}.jpg"


def _cover_lock(album_id: int) -> threading.Lock:
    with _cover_locks_guard:
        lock = _cover_locks.get(album_id)
        if lock is None:
            lock = threading.Lock()
            _cover_locks[album_id] = lock
        return lock


def ensure_cover_path(session, album: Album) -> str | None:
    """Extract embedded art (then folder art) once, atomically, and cache it."""
    os.makedirs(COVERS_DIR, exist_ok=True)
    filename = cover_filename(album)
    path = os.path.join(COVERS_DIR, filename)
    if os.path.isfile(path):
        return path

    with _cover_lock(album.id):
        if os.path.isfile(path):
            return path
        tracks = (
            session.query(Track)
            .filter(Track.album_id == album.id)
            .order_by(Track.track_no, Track.id)
            .limit(12)
            .all()
        )
        data = None
        for track in tracks:
            data = extract_cover_data(track.path, track.ext)
            if data:
                break
        if data is None and tracks:
            data = find_folder_art([t.path for t in tracks])
        if data is None:
            return None

        image_bytes, mime = data
        ext = ".png" if mime == "image/png" or image_bytes[:4] == b"\x89PNG" else ".jpg"
        filename = os.path.splitext(filename)[0] + ext
        path = os.path.join(COVERS_DIR, filename)
        tmp = f"{path}.{threading.get_ident()}.tmp"
        with open(tmp, "wb") as handle:
            handle.write(image_bytes)
        os.replace(tmp, path)

        album.cover = filename
        session.commit()
        return path


def find_folder_art(track_paths: list[str]) -> tuple[bytes, str] | None:
    """Look for an image file sitting next to the tracks (folder.jpg style)."""
    checked_dirs: set[str] = set()
    for path in track_paths:
        directory = os.path.dirname(path)
        if directory in checked_dirs:
            continue
        checked_dirs.add(directory)
        try:
            lowered = {name.lower(): name for name in os.listdir(directory)}
        except OSError:
            continue
        for candidate in FOLDER_ART_NAMES:
            actual = lowered.get(candidate)
            if not actual:
                continue
            try:
                with open(os.path.join(directory, actual), "rb") as handle:
                    data = handle.read()
            except OSError:
                continue
            mime = "image/png" if candidate.endswith(".png") else "image/jpeg"
            if data[:4] == b"\x89PNG":
                mime = "image/png"
            return data, mime
    return None


def extract_cover_data(path: str, ext: str) -> tuple[bytes, str] | None:
    """Return (image_bytes, mime) for embedded artwork, if any."""
    try:
        if ext == ".mp3":
            for pic in ID3(path).getall("APIC:"):
                return pic.data, pic.mime
        if ext == ".flac":
            pictures = FLAC(path).pictures
            if pictures:
                return pictures[0].data, pictures[0].mime
        if ext in (".m4a", ".mp4"):
            tags = MP4(path).tags or {}
            covr = tags.get("covr")
            if covr:
                data = bytes(covr[0])
                mime = "image/png" if data[:4] == b"\x89PNG" else "image/jpeg"
                return data, mime
        if ext in (".ogg", ".opus"):
            mf = MutagenFile(path)
            pictures = getattr(mf, "pictures", []) or []
            if pictures:
                return pictures[0].data, pictures[0].mime
    except Exception:
        return None
    return None
