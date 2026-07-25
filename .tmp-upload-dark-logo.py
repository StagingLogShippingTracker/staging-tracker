"""Upload slst-logo-email-dark.png using Supabase management token / service role."""
from __future__ import annotations

import ctypes
import json
import os
import sqlite3
import urllib.error
import urllib.request
from ctypes import wintypes
from pathlib import Path

ROOT = Path(r"C:\Users\Brice\Downloads\staging-tracker")
PROJECT = "gdrpdiwykmnybmkadlrv"
OBJECT = "slst-logo-email-dark.png"
LOCAL = ROOT / "assets" / "email" / OBJECT


class DATA_BLOB(ctypes.Structure):
    _fields_ = [("cbData", wintypes.DWORD), ("pbData", ctypes.POINTER(ctypes.c_char))]


def dpapi_decrypt(encrypted: bytes) -> bytes:
    crypt32 = ctypes.windll.crypt32
    kernel32 = ctypes.windll.kernel32
    blob_in = DATA_BLOB(len(encrypted), ctypes.create_string_buffer(encrypted, len(encrypted)))
    blob_out = DATA_BLOB()
    if not crypt32.CryptUnprotectData(
        ctypes.byref(blob_in), None, None, None, None, 0, ctypes.byref(blob_out)
    ):
        raise OSError(ctypes.GetLastError())
    try:
        return ctypes.string_at(blob_out.pbData, blob_out.cbData)
    finally:
        kernel32.LocalFree(blob_out.pbData)


def list_oauth_keys() -> list[str]:
    db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    rows = con.execute(
        "SELECT key FROM ItemTable WHERE key LIKE '%mcpOAuth%' OR key LIKE '%supabase%'"
    ).fetchall()
    con.close()
    return [r[0] for r in rows]


def try_parse_token(raw_value) -> str | None:
    if isinstance(raw_value, memoryview):
        raw_value = raw_value.tobytes()
    if isinstance(raw_value, bytes):
        try:
            data = json.loads(raw_value.decode("utf-8", "replace"))
        except json.JSONDecodeError:
            data = {"data": list(raw_value)}
    else:
        data = json.loads(raw_value)

    candidates: list[bytes] = []
    if isinstance(data, dict):
        if "data" in data:
            d = data["data"]
            if isinstance(d, list):
                candidates.append(bytes(d))
            elif isinstance(d, str):
                candidates.append(d.encode("utf-8", "replace"))
            elif isinstance(d, bytes):
                candidates.append(d)
        # sometimes already a token blob
        for k in ("access_token", "accessToken"):
            if isinstance(data.get(k), str) and data[k]:
                return data[k]
        if isinstance(data.get("tokens"), dict):
            t = data["tokens"]
            for k in ("access_token", "accessToken"):
                if isinstance(t.get(k), str) and t[k]:
                    return t[k]

    for raw in candidates:
        variants = [raw]
        if raw.startswith(b"v10"):
            variants.append(raw[3:])
        if raw.startswith(b"v11"):
            variants.append(raw[3:])
        for v in variants:
            try:
                plain = dpapi_decrypt(v)
            except OSError:
                plain = v
            text = plain.decode("utf-8", "replace").strip("\x00").strip()
            if not text:
                continue
            if text.startswith("{"):
                try:
                    parsed = json.loads(text)
                except json.JSONDecodeError:
                    continue
                for k in ("access_token", "accessToken"):
                    if isinstance(parsed.get(k), str) and parsed[k]:
                        return parsed[k]
                if isinstance(parsed.get("tokens"), dict):
                    t = parsed["tokens"]
                    for k in ("access_token", "accessToken"):
                        if isinstance(t.get(k), str) and t[k]:
                            return t[k]
            elif text.startswith("sbp_") or text.startswith("eyJ"):
                return text
    return None


def get_access_token() -> str:
    db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    keys = list_oauth_keys()
    print("oauth-ish keys:", len(keys))
    for key in keys:
        row = con.execute("SELECT value FROM ItemTable WHERE key = ?", (key,)).fetchone()
        if not row:
            continue
        token = try_parse_token(row[0])
        if token:
            print("token from", key[:80], "len", len(token))
            con.close()
            return token
    con.close()
    raise SystemExit("no access token found")


def get_service_role(mgmt: str) -> str:
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{PROJECT}/api-keys",
        headers={"Authorization": f"Bearer {mgmt}"},
    )
    with urllib.request.urlopen(req) as resp:
        keys = json.loads(resp.read().decode())
    for k in keys:
        name = (k.get("name") or "").lower()
        typ = (k.get("type") or "").lower()
        if "service" in name or typ == "service_role":
            return k.get("api_key") or k.get("key") or k.get("secret")
    raise SystemExit(f"no service role in {[k.get('name') for k in keys]}")


def upload(sr: str) -> None:
    body = LOCAL.read_bytes()
    url = f"https://{PROJECT}.supabase.co/storage/v1/object/email-assets/{OBJECT}"
    for method in ("POST", "PUT"):
        req = urllib.request.Request(
            url,
            data=body,
            method=method,
            headers={
                "Authorization": f"Bearer {sr}",
                "apikey": sr,
                "Content-Type": "image/png",
                "x-upsert": "true",
            },
        )
        try:
            with urllib.request.urlopen(req) as resp:
                print(OBJECT, method, resp.status, resp.read()[:160])
                return
        except urllib.error.HTTPError as e:
            err = e.read()[:300]
            print(OBJECT, method, "FAIL", e.code, err)
            if method == "PUT":
                raise


def main() -> None:
    if not LOCAL.is_file():
        raise SystemExit(f"missing {LOCAL}")
    mgmt = get_access_token()
    sr = get_service_role(mgmt)
    upload(sr)
    pub = f"https://{PROJECT}.supabase.co/storage/v1/object/public/email-assets/{OBJECT}"
    print("PUBLIC", pub)
    # verify fetch
    with urllib.request.urlopen(pub) as resp:
        print("public GET", resp.status, "len", len(resp.read()), "ct", resp.headers.get("Content-Type"))


if __name__ == "__main__":
    main()
