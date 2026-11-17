"""Full-text search over the library.

Design goals
------------
* Substring search ("midn", "ght cit") as well as whole words — an FTS5
  ``trigram`` tokenizer indexes every 3-character slice, so mid-word matches
  are fast instead of a full table scan with LIKE.
* Accent/case insensitive and punctuation tolerant (normalised at index time).
* Weighted BM25 ranking: title > artist > album > genre, so "m83" surfaces
  the artist's tracks rather than a random mention in a compilation name.
* Graceful degradation: short queries (<3 chars) fall back to LIKE, and
  SQLite builds without FTS5 fall back to an in-process scorer.

The search index is a denormalised snapshot rebuilt after each scan. That is
O(library size) per scan but keeps every search O(log n) and, crucially,
never blocks a stream.
"""

from __future__ import annotations

import re
import unicodedata
from typing import Any

from sqlalchemy import text
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session

from .db import session_scope

_FTS_AVAILABLE = False
_FTS_TABLE = "search_fts"

# Column order: kind, ref_id, title, artist, album, extra.
# kind/ref_id are UNINDEXED carriers used to map a hit back to a DB row.
_WEIGHTS = "0.0, 0.0, 10.0, 5.0, 2.0, 1.0"
_MAX_QUERY_TOKENS = 6


def normalize(value: Any) -> str:
    """Fold accents/case/punctuation into a stable search key."""
    raw = unicodedata.normalize("NFKD", str(value or ""))
    raw = "".join(ch for ch in raw if not unicodedata.combining(ch))
    raw = raw.casefold()
    raw = re.sub(r"[^\w]+", " ", raw, flags=re.UNICODE)
    return re.sub(r"\s+", " ", raw).strip()


def fts_available() -> bool:
    return _FTS_AVAILABLE


def init_search(engine: Engine) -> None:
    """Create the FTS table if supported and populate it when empty."""
    global _FTS_AVAILABLE
    try:
        with engine.begin() as conn:
            conn.execute(
                text(
                    f"CREATE VIRTUAL TABLE IF NOT EXISTS {_FTS_TABLE} USING fts5("
                    "kind UNINDEXED, ref_id UNINDEXED, title, artist, album, extra, "
                    "tokenize='trigram')"
                )
            )
        _FTS_AVAILABLE = True
    except Exception:  # pragma: no cover - depends on the SQLite build
        _FTS_AVAILABLE = False

    if not _FTS_AVAILABLE:
        return

    with session_scope() as session:
        count = session.execute(text(f"SELECT count(*) FROM {_FTS_TABLE}")).scalar() or 0
        if count == 0:
            rebuild_search_index(session)


def rebuild_search_index(session: Session) -> None:
    """Rebuild the denormalised search snapshot from tracks/albums."""
    if not _FTS_AVAILABLE:
        return

    session.execute(text(f"DELETE FROM {_FTS_TABLE}"))

    album_names = {
        int(row[0]): row[1]
        for row in session.execute(text("SELECT id, name FROM albums"))
    }
    rows: list[dict[str, Any]] = []

    for track_id, title, artist, album_id, genre in session.execute(
        text("SELECT id, title, artist, album_id, genre FROM tracks")
    ):
        rows.append(
            {
                "kind": "track",
                "ref_id": int(track_id),
                "title": normalize(title),
                "artist": normalize(artist),
                "album": normalize(album_names.get(int(album_id), "")),
                "extra": normalize(genre),
            }
        )

    for album_id, name, artist in session.execute(
        text("SELECT id, name, artist FROM albums")
    ):
        rows.append(
            {
                "kind": "album",
                "ref_id": int(album_id),
                "title": normalize(name),
                "artist": normalize(artist),
                "album": "",
                "extra": "",
            }
        )

    for (artist,) in session.execute(text("SELECT DISTINCT artist FROM tracks")):
        rows.append(
            {
                "kind": "artist",
                "ref_id": 0,
                "title": normalize(artist),
                "artist": "",
                "album": "",
                "extra": "",
            }
        )

    if rows:
        session.execute(
            text(
                f"INSERT INTO {_FTS_TABLE}(kind, ref_id, title, artist, album, extra) "
                "VALUES (:kind, :ref_id, :title, :artist, :album, :extra)"
            ),
            rows,
        )


def _empty() -> dict[str, list[int | str]]:
    return {"tracks": [], "albums": [], "artists": []}


def _group(rows: list[tuple[str, Any, Any]], limit: int) -> dict[str, list[int | str]]:
    out: dict[str, list[int | str]] = {"tracks": [], "albums": [], "artists": []}
    seen_tracks: set[int] = set()
    seen_albums: set[int] = set()
    seen_artists: set[str] = set()

    for kind, ref, title in rows:
        # Artists have no integer id — their normalised name is the identity.
        if kind == "artist":
            ref = title
        if kind == "track":
            ref = int(ref)
            if ref not in seen_tracks and len(out["tracks"]) < limit:
                seen_tracks.add(ref)
                out["tracks"].append(ref)
        elif kind == "album":
            ref = int(ref)
            if ref not in seen_albums and len(out["albums"]) < limit:
                seen_albums.add(ref)
                out["albums"].append(ref)
        elif kind == "artist":
            ref = str(ref)
            if ref not in seen_artists and len(out["artists"]) < limit:
                seen_artists.add(ref)
                out["artists"].append(ref)
        if all(len(out[k]) >= limit for k in out):
            break
    return out


def _score_sql(where: str, params: dict[str, Any], limit: int, session: Session):
    sql = (
        f"SELECT kind, ref_id, title, bm25({_FTS_TABLE}, {_WEIGHTS}) AS score "
        f"FROM {_FTS_TABLE} WHERE {where} ORDER BY score LIMIT :lim"
    )
    return session.execute(text(sql), {**params, "lim": limit}).all()


def search_ids(session: Session, query: str, limit: int = 40) -> dict[str, list[int | str]]:
    """Return ranked track ids, album ids and artist names for a query."""
    q = normalize(query)
    if not q:
        return _empty()

    # A generous candidate pool ensures each result group can fill its quota
    # even when one group dominates the ranking.
    pool = max(60, limit * 6)

    if not _FTS_AVAILABLE:
        return _fallback_search(session, q, limit)

    tokens = q.split()
    if len(q) < 3 or any(len(token) < 3 for token in tokens):
        # Trigram tokenizer cannot index 1-2 character terms. LIKE is exact
        # but only used for these rare short queries.
        pattern = f"%{q}%"
        rows = _score_sql(
            "title LIKE :p OR artist LIKE :p OR album LIKE :p OR extra LIKE :p",
            {"p": pattern},
            pool,
            session,
        )
    else:
        # FTS5 phrase + prefix syntax: "midn"* . Quotes also neutralise any
        # characters that would otherwise be read as FTS operators.
        escaped = [
            '"' + token.replace('"', '""') + '"*' for token in tokens[:_MAX_QUERY_TOKENS]
        ]
        expr = " AND ".join(escaped)
        rows = _score_sql(f"{_FTS_TABLE} MATCH :q", {"q": expr}, pool, session)

    return _group([(row[0], row[1], row[2]) for row in rows], limit)


def _fallback_search(session: Session, q: str, limit: int):
    """Used only when SQLite has no FTS5: score rows in Python."""
    tokens = q.split()
    scored: list[tuple[float, str, Any]] = []

    for track_id, title, artist, album_name, genre in session.execute(
        text(
            "SELECT t.id, t.title, t.artist, coalesce(a.name, ''), coalesce(t.genre, '') "
            "FROM tracks t LEFT JOIN albums a ON a.id = t.album_id"
        )
    ):
        fields = [normalize(title), normalize(artist), normalize(album_name), normalize(genre)]
        score = 0.0
        for token in tokens:
            best = 0.0
            for weight, field in zip((10.0, 5.0, 2.0, 1.0), fields):
                if token in field:
                    best = max(best, weight + (2.0 if field.startswith(token) else 0.0))
            if not best:
                score = 0.0
                break
            score += best
        if score:
            scored.append((score, "track", int(track_id)))

    for album_id, name, artist in session.execute(
        text("SELECT id, name, artist FROM albums")
    ):
        fields = [normalize(name), normalize(artist)]
        score = sum(
            max((w for w, f in zip((10.0, 5.0), fields) if t in f), default=0.0)
            for t in tokens
        )
        if score:
            scored.append((score, "album", int(album_id)))

    for (artist,) in session.execute(text("SELECT DISTINCT artist FROM tracks")):
        field = normalize(artist)
        if all(t in field for t in tokens):
            scored.append((5.0, "artist", field))

    scored.sort(key=lambda item: -item[0])
    return _group([(kind, ref, ref) for _, kind, ref in scored], limit)
