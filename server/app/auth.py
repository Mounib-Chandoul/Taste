"""LAN-scale auth: HMAC-signed tokens, throttled login, revocation."""

from __future__ import annotations

import hashlib
import hmac
import threading
import time
from collections import defaultdict
from typing import Any

from fastapi import Header, HTTPException, Request
from sqlalchemy import text

from .config import (
    ADMIN_PASSWORD,
    ADMIN_USER,
    LOGIN_MAX_ATTEMPTS,
    LOGIN_WINDOW_SECONDS,
    TOKEN_TTL_DAYS,
    get_secret,
)
from .db import session_scope

_TOKEN_TTL = TOKEN_TTL_DAYS * 24 * 3600

_login_lock = threading.Lock()
_failures: dict[str, list[float]] = defaultdict(list)


def _throttled(client_ip: str) -> bool:
    now = time.time()
    with _login_lock:
        attempts = [t for t in _failures[client_ip] if now - t < LOGIN_WINDOW_SECONDS]
        _failures[client_ip] = attempts
        return len(attempts) >= LOGIN_MAX_ATTEMPTS


def _record_failure(client_ip: str) -> None:
    with _login_lock:
        _failures[client_ip].append(time.time())


def _clear_failures(client_ip: str) -> None:
    with _login_lock:
        _failures.pop(client_ip, None)


def login(username: str, password: str, client_ip: str = "") -> dict[str, Any]:
    if _throttled(client_ip):
        raise HTTPException(status_code=429, detail="Too many failed logins, try again shortly")

    user_ok = hmac.compare_digest(str(username), ADMIN_USER)
    pass_ok = hmac.compare_digest(str(password), ADMIN_PASSWORD)
    if not (user_ok and pass_ok):
        _record_failure(client_ip)
        raise HTTPException(status_code=401, detail="Wrong username or password")

    _clear_failures(client_ip)
    exp = str(int(time.time()) + _TOKEN_TTL)
    sig = hmac.new(get_secret(), f"{username}:{exp}".encode(), hashlib.sha256).hexdigest()
    return {
        "token": f"{username}.{exp}.{sig}",
        "expires_in_days": TOKEN_TTL_DAYS,
        "username": username,
    }


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _is_revoked(token: str) -> bool:
    with session_scope() as session:
        row = session.execute(
            text("SELECT 1 FROM token_denylist WHERE token_hash = :h"),
            {"h": _token_hash(token)},
        ).first()
        return row is not None


def revoke(token: str) -> None:
    """Blacklist a single token (used by /api/logout)."""
    with session_scope() as session:
        session.execute(
            text(
                "INSERT OR IGNORE INTO token_denylist(token_hash, created_at) "
                "VALUES (:h, :t)"
            ),
            {"h": _token_hash(token), "t": time.time()},
        )


def _validate_token(token: str) -> str:
    try:
        username, exp, sig = token.split(".", 2)
        expiry = int(exp)
    except (ValueError, TypeError):
        raise HTTPException(status_code=401, detail="Malformed token")

    expected = hmac.new(
        get_secret(), f"{username}:{exp}".encode(), hashlib.sha256
    ).hexdigest()
    if not hmac.compare_digest(sig, expected):
        raise HTTPException(status_code=401, detail="Invalid token")
    if expiry < time.time():
        raise HTTPException(status_code=401, detail="Token expired")
    if _is_revoked(token):
        raise HTTPException(status_code=401, detail="Token revoked")
    return username


def _extract_bearer(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing token")
    parts = authorization.split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "bearer" or not parts[1].strip():
        raise HTTPException(status_code=401, detail="Malformed Authorization header")
    return parts[1].strip()


def verify(authorization: str | None = Header(default=None)) -> str:
    """Bearer-token dependency. Returns the username or raises 401."""
    return _validate_token(_extract_bearer(authorization))


def verify_flexible(request: Request, authorization: str | None = Header(default=None)) -> str:
    """Bearer header or ?token=, for media fetched outside our HTTP stack
    (lock-screen art, <audio> elements, native players)."""
    token = request.query_params.get("token")
    if not token and authorization:
        token = _extract_bearer(authorization)
    if not token:
        raise HTTPException(status_code=401, detail="Missing token")
    if token.lower().startswith("bearer "):
        token = token.split(" ", 1)[1].strip()
    return _validate_token(token)
