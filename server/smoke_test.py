"""Full smoke test for the Music Lab server. Run with the venv python."""
import json
import urllib.request
import urllib.error

BASE = "http://127.0.0.1:4533"


def call(path, method="GET", token=None, body=None, headers=None):
    req_headers = dict(headers or {})
    if token:
        req_headers["Authorization"] = f"Bearer {token}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        f"{BASE}{path}", data=data, method=method, headers=req_headers
    )
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


results = []


def check(name, ok, detail=""):
    results.append((name, ok, detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name} {detail}")


# 1. login
status, data = call("/api/login", "POST", body={"username": "tester", "password": "testpass"})
token = json.loads(data)["token"] if status == 200 else None
check("login ok", status == 200, f"({status})")

# 2. wrong password rejected
status, _ = call("/api/login", "POST", body={"username": "tester", "password": "wrong"})
check("wrong password -> 401", status == 401, f"({status})")

# 3. no token rejected
status, _ = call("/api/library")
check("missing token -> 401", status == 401, f"({status})")

# 4. library
status, data = call("/api/library", token=token)
lib = json.loads(data)
titles = [t["title"] for t in lib["tracks"]]
check("library ok", status == 200 and len(titles) >= 2, f"tracks={titles}")
track_id = lib["tracks"][0]["id"]

# 5. range: normal
status, data = call(f"/api/stream/{track_id}", token=token, headers={"Range": "bytes=0-1023"})
check("range 0-1023 -> 206", status == 206 and len(data) == 1024, f"({status}, {len(data)}B)")

# 6. range: suffix
status, data = call(f"/api/stream/{track_id}", token=token, headers={"Range": "bytes=-500"})
check("suffix -500 -> 206", status == 206 and len(data) == 500, f"({status}, {len(data)}B)")

# 7. range: out of bounds
status, _ = call(f"/api/stream/{track_id}", token=token, headers={"Range": "bytes=999999-"})
check("bad range -> 416", status == 416, f"({status})")

# 8. full download
status, data = call(f"/api/download/{track_id}", token=token)
check("download full file", status == 200 and len(data) > 100000, f"({status}, {len(data)}B)")

# 9. cover: with header (404 expected here: WAVs have no art, but must NOT be 401)
status, _ = call("/api/cover/1", token=token)
check("cover with header (no 401)", status in (200, 404), f"({status})")

# 10. cover: token as query param (the new verify_flexible path)
status, _ = call(f"/api/cover/1?token={token}")
check("cover with query token (no 401)", status in (200, 404), f"({status})")

# 11. query token WITHOUT header must not 401 on cover
status, _ = call("/api/cover/1")
check("cover no auth -> 401", status == 401, f"({status})")

# 12. status
status, data = call("/api/status", token=token)
s = json.loads(data)
check("status endpoint", status == 200 and "tracks" in s, f"({status}, {s})")

failed = [r for r in results if not r[1]]
print(f"\n{len(results) - len(failed)}/{len(results)} passed")
if failed:
    raise SystemExit(1)
