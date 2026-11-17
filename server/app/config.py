"""Configuration loaded from the environment / server/.env.

Nothing here writes to .env — the file is strictly read-only input. Every
setting has a safe default so the server also works in tests and containers.
"""

from __future__ import annotations

import os

from dotenv import load_dotenv

load_dotenv()

_SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _expand(value: str) -> str:
    return os.path.abspath(os.path.expanduser(value)) if value else ""


def _bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() not in {"0", "false", "no", "off", ""}


def _int(name: str, default: int, minimum: int = 1) -> int:
    try:
        return max(minimum, int(os.getenv(name, str(default))))
    except (TypeError, ValueError):
        return default


# Where the audio lives. Scans are strictly read-only on this directory.
MUSIC_DIR = _expand(os.getenv("MUSIC_DIR", ""))

# App-owned state: database, cover cache, token secret.
DATA_DIR = _expand(os.getenv("DATA_DIR", os.path.join(_SERVER_DIR, "data")))
COVERS_DIR = os.path.join(DATA_DIR, "covers")

# Single-user auth (a real user table is deliberately out of scope for LAN use).
ADMIN_USER = os.getenv("ADMIN_USER", "admin")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "changeme")
TOKEN_TTL_DAYS = _int("TOKEN_TTL_DAYS", 90)

# Startup behaviour.
SCAN_ON_START = _bool("SCAN_ON_START", True)

# Brute-force throttle for POST /api/login (in-process, per remote address).
LOGIN_MAX_ATTEMPTS = _int("LOGIN_MAX_ATTEMPTS", 8)
LOGIN_WINDOW_SECONDS = _int("LOGIN_WINDOW_SECONDS", 60)

# Serving the Flutter web build from the same origin.
WEB_DIR = _expand(os.getenv("WEB_DIR", ""))

_SECRET_FILE = os.path.join(DATA_DIR, "secret.key")


def get_secret() -> bytes:
    """Stable per-install secret used to sign auth tokens."""
    if not os.path.exists(_SECRET_FILE):
        os.makedirs(DATA_DIR, exist_ok=True)
        try:
            # O_EXCL makes concurrent first-runs safe instead of racing to
            # overwrite each other's secret (which would invalidate tokens).
            fd = os.open(_SECRET_FILE, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "wb") as handle:
                handle.write(os.urandom(32))
        except FileExistsError:
            pass
    with open(_SECRET_FILE, "rb") as handle:
        return handle.read()
