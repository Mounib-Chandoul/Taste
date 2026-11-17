"""SQLAlchemy schema.

All additions are backwards-compatible with the original two-table schema;
`db.init_db()` performs additive migrations for existing databases.
"""

from __future__ import annotations

import time

from sqlalchemy import Column, Float, Index, Integer, String, UniqueConstraint

from .db import Base


class Album(Base):
    __tablename__ = "albums"
    __table_args__ = (
        Index("ix_albums_name", "name"),
        Index("ix_albums_artist", "artist"),
    )

    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    artist = Column(String, nullable=False, default="Unknown Artist")
    year = Column(Integer, nullable=True)
    cover = Column(String, nullable=True)  # filename inside the covers dir


class Track(Base):
    __tablename__ = "tracks"
    __table_args__ = (
        Index("ix_tracks_title", "title"),
        Index("ix_tracks_artist", "artist"),
        Index("ix_tracks_album_id", "album_id"),
        # uid/genre indexes are created after their additive migration in
        # db.init_db(), so old databases don't fail during create_all().
    )

    id = Column(Integer, primary_key=True)
    path = Column(String, unique=True, nullable=False)
    title = Column(String, nullable=False)
    artist = Column(String, nullable=False, default="Unknown Artist")
    album_id = Column(Integer, nullable=False)
    track_no = Column(Integer, nullable=True)
    duration = Column(Float, nullable=True)
    ext = Column(String, nullable=False, default="")
    size = Column(Integer, nullable=False, default=0)
    mtime = Column(Float, nullable=False, default=0.0)

    # Added in v2 — filled by the scanner, safe to be NULL on old databases.
    genre = Column(String, nullable=True)
    disc_no = Column(Integer, nullable=True)
    # Stable identity derived from the path relative to MUSIC_DIR. Clients can
    # key caches on this; unlike the auto-increment id it survives a full
    # delete-and-rescan as long as the file stays in the same relative place.
    uid = Column(String, nullable=True)


class Playlist(Base):
    __tablename__ = "playlists"
    __table_args__ = (Index("ix_playlists_owner", "owner"),)

    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    owner = Column(String, nullable=False, default="")
    created_at = Column(Float, nullable=False, default=time.time)


class PlaylistTrack(Base):
    __tablename__ = "playlist_tracks"
    __table_args__ = (
        UniqueConstraint("playlist_id", "track_id", name="uq_pl_track"),
        Index("ix_playlist_tracks_order", "playlist_id", "position"),
    )

    id = Column(Integer, primary_key=True)
    playlist_id = Column(Integer, nullable=False)
    track_id = Column(Integer, nullable=False)
    position = Column(Integer, nullable=False, default=0)
    added_at = Column(Float, nullable=False, default=time.time)


class Meta(Base):
    """Small key/value table for library revision and other install state."""

    __tablename__ = "meta"

    key = Column(String, primary_key=True)
    value = Column(String, nullable=False)


class TokenDenylist(Base):
    """Hashed tokens revoked via /api/logout."""

    __tablename__ = "token_denylist"

    token_hash = Column(String, primary_key=True)
    created_at = Column(Float, nullable=False, default=time.time)
