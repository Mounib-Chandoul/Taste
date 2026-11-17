"""Verifies that an old v1 database upgrades in place without losing rows."""

from __future__ import annotations

import os
import shutil
import sqlite3
import sys
import tempfile

SERVER_DIR = os.path.dirname(os.path.abspath(__file__))
if SERVER_DIR not in sys.path:
    sys.path.insert(0, SERVER_DIR)

_TMP = tempfile.mkdtemp(prefix="musiclab-migration-test-")
os.environ["DATA_DIR"] = _TMP
os.environ["MUSIC_DIR"] = ""
os.environ["SCAN_ON_START"] = "0"
os.environ["WEB_DIR"] = ""

from app.db import init_db, session_scope  # noqa: E402
from app.models import Album, Track  # noqa: E402

RESULTS: list[tuple[str, bool]] = []


def check(name: str, ok: bool) -> None:
    RESULTS.append((name, ok))
    print(f"{'PASS' if ok else 'FAIL'}  {name}")


# Build an exact copy of the v1 schema.
db_path = os.path.join(_TMP, "musiclab.db")
conn = sqlite3.connect(db_path)
conn.executescript(
    """
    CREATE TABLE albums (
        id INTEGER PRIMARY KEY,
        name VARCHAR NOT NULL,
        artist VARCHAR NOT NULL DEFAULT 'Unknown Artist',
        year INTEGER,
        cover VARCHAR
    );
    CREATE TABLE tracks (
        id INTEGER PRIMARY KEY,
        path VARCHAR NOT NULL UNIQUE,
        title VARCHAR NOT NULL,
        artist VARCHAR NOT NULL DEFAULT 'Unknown Artist',
        album_id INTEGER NOT NULL,
        track_no INTEGER,
        duration FLOAT,
        ext VARCHAR NOT NULL DEFAULT '',
        size INTEGER NOT NULL DEFAULT 0,
        mtime FLOAT NOT NULL DEFAULT 0
    );
    CREATE TABLE playlists (
        id INTEGER PRIMARY KEY,
        name VARCHAR NOT NULL,
        owner VARCHAR NOT NULL DEFAULT '',
        created_at FLOAT NOT NULL
    );
    CREATE TABLE playlist_tracks (
        id INTEGER PRIMARY KEY,
        playlist_id INTEGER NOT NULL,
        track_id INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        added_at FLOAT NOT NULL,
        CONSTRAINT uq_pl_track UNIQUE (playlist_id, track_id)
    );
    INSERT INTO albums(id, name, artist, year) VALUES (1, 'Old Album', 'Old Artist', 2020);
    INSERT INTO tracks(id, path, title, artist, album_id, ext, size, mtime)
        VALUES (1, 'C:\\music\\old.mp3', 'Old Song', 'Old Artist', 1, '.mp3', 1234, 1.0);
    """
)
conn.commit()
conn.close()

init_db()

conn = sqlite3.connect(db_path)
track_cols = {row[1] for row in conn.execute("PRAGMA table_info(tracks)")}
check("genre column added", "genre" in track_cols)
check("disc_no column added", "disc_no" in track_cols)
check("uid column added", "uid" in track_cols)
indexes = {row[1] for row in conn.execute("PRAGMA index_list(tracks)")}
check(f"uid index created ({sorted(indexes)})", "ix_tracks_uid" in indexes)
check("genre index created", "ix_tracks_genre" in indexes)
tables = {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
check("meta table created", "meta" in tables)
check("token denylist created", "token_denylist" in tables)
check("old track row preserved", conn.execute("SELECT title FROM tracks WHERE id=1").fetchone()[0] == "Old Song")
check("old album row preserved", conn.execute("SELECT name FROM albums WHERE id=1").fetchone()[0] == "Old Album")
fts_tables = {
    row[0]
    for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%fts%'")
}
check("fts table created", bool(fts_tables))
conn.close()

with session_scope() as session:
    check("old track readable via ORM", session.get(Track, 1).title == "Old Song")
    check("old album readable via ORM", session.get(Album, 1).name == "Old Album")

failed = [item for item in RESULTS if not item[1]]
print(f"\n{len(RESULTS) - len(failed)}/{len(RESULTS)} passed")
shutil.rmtree(_TMP, ignore_errors=True)
if failed:
    raise SystemExit(1)
