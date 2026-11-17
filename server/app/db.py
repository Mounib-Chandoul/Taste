"""Database engine, sessions, and additive schema migrations."""

from __future__ import annotations

import os
from contextlib import contextmanager
from typing import Iterator

from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import Session, declarative_base, sessionmaker

from .config import DATA_DIR

os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(os.path.join(DATA_DIR, "covers"), exist_ok=True)

_DB_PATH = os.path.join(DATA_DIR, "musiclab.db")

engine = create_engine(
    f"sqlite:///{_DB_PATH}",
    connect_args={"check_same_thread": False, "timeout": 15},
    pool_pre_ping=True,
)


@event.listens_for(engine, "connect")
def _sqlite_pragmas(dbapi_connection, _record) -> None:
    """Tune SQLite for a read-heavy, multi-client media server.

    - WAL: readers (streams) never block the writer (scanner).
    - NORMAL synchronous: WAL is durable enough here; big speedup on scans.
    - busy_timeout: wait instead of failing on brief lock contention.
    - foreign_keys: keep playlist references honest.
    """
    cursor = dbapi_connection.cursor()
    try:
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA synchronous=NORMAL")
        cursor.execute("PRAGMA busy_timeout=15000")
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.execute("PRAGMA temp_store=MEMORY")
        cursor.execute("PRAGMA cache_size=-8000")  # 8 MiB per connection
    finally:
        cursor.close()


SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()

LIBRARY_REVISION_KEY = "library_revision"
DEFAULT_REVISION = "0"


@contextmanager
def session_scope() -> Iterator[Session]:
    """Transaction that commits on success and rolls back on any exception."""
    session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def get_db() -> Iterator[Session]:
    """FastAPI dependency variant of session_scope (read-only endpoints fine)."""
    with session_scope() as session:
        yield session


def get_meta(
    session: Session,
    key: str = LIBRARY_REVISION_KEY,
    default: str = DEFAULT_REVISION,
) -> str:
    row = session.execute(text("SELECT value FROM meta WHERE key = :k"), {"k": key}).first()
    return row[0] if row else default


def set_meta(session: Session, key: str, value: str) -> None:
    session.execute(
        text(
            "INSERT INTO meta(key, value) VALUES (:k, :v) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value"
        ),
        {"k": key, "v": str(value)},
    )


def bump_library_revision(session: Session) -> str:
    """Monotonic counter used as an ETag; never reuses an old value."""
    current = get_meta(session, LIBRARY_REVISION_KEY)
    try:
        nxt = str(int(current) + 1)
    except ValueError:
        nxt = "1"
    set_meta(session, LIBRARY_REVISION_KEY, nxt)
    return nxt


def _add_column_if_missing(table: str, column: str, decl: str) -> None:
    with engine.begin() as conn:
        names = {row[1] for row in conn.execute(text(f"PRAGMA table_info({table})"))}
        if column not in names:
            conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {decl}"))


def init_db() -> None:
    """Create tables/indexes and migrate older databases in place."""
    from . import models  # noqa: F401 — registers all mappers
    from .search import init_search

    Base.metadata.create_all(engine, checkfirst=True)

    # Additive migrations for databases created by earlier versions.
    _add_column_if_missing("tracks", "genre", "VARCHAR")
    _add_column_if_missing("tracks", "disc_no", "INTEGER")
    _add_column_if_missing("tracks", "uid", "VARCHAR")

    with engine.begin() as conn:
        conn.execute(text("CREATE INDEX IF NOT EXISTS ix_tracks_uid ON tracks(uid)"))
        conn.execute(text("CREATE INDEX IF NOT EXISTS ix_tracks_genre ON tracks(genre)"))

    with session_scope() as session:
        if get_meta(session, LIBRARY_REVISION_KEY) == DEFAULT_REVISION:
            set_meta(session, LIBRARY_REVISION_KEY, DEFAULT_REVISION)

    init_search(engine)
