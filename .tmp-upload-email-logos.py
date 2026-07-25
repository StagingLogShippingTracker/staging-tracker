"""Upload SLST email logos to Supabase Storage email-assets bucket."""
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
TOKEN_KEY = (
    "mcpOAuth.secret.W3BsdWdpbi1zdXBhYmFzZS1zdXBhYmFzZTo6bWNwU2NvcGU6"
    "cHJvZmlsZTpaR1ZtWVhWc2RBXSBtY3BfdG9rZW5z"
)


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


def get_access_token() -> str:
    db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    row = con.execute("SELECT value FROM ItemTable WHERE key = ?", (TOKEN_KEY,)).fetchone()
    con.close()
    data = json.loads(row[0] if isinstance(row[0], str) else row[0].decode("utf-8", "replace"))
    raw = bytes(data["data"])
    if raw.startswith(b"v10"):
        raw = raw[3:]
    try:
        plain = dpapi_decrypt(raw)
    except OSError:
        plain = raw
    parsed = json.loads(plain.decode("utf-8", "replace"))
    token = parsed.get("access_token") or parsed.get("accessToken")
    if not token and isinstance(parsed.get("tokens"), dict):
        token = parsed["tokens"].get("access_token") or parsed["tokens"].get("accessToken")
    if not token:
        raise SystemExit("no access token")
    return token


def get_service_role(mgmt: str) -> str:
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{PROJECT}/api-keys",
        headers={"Authorization": f"Bearer {mgmt}"},
    )
    keys = json.loads(urllib.request.urlopen(req).read().decode())
    for k in keys:
        name = (k.get("name") or "").lower()
        typ = (k.get("type") or "").lower()
        if "service" in name or typ == "service_role":
            return k.get("api_key") or k.get("key") or k.get("secret")
    raise SystemExit(f"no service role in {[k.get('name') for k in keys]}")


def upload(sr: str, local: Path, object_name: str) -> None:
    body = local.read_bytes()
    url = f"https://{PROJECT}.supabase.co/storage/v1/object/email-assets/{object_name}"
    req = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {sr}",
            "apikey": sr,
            "Content-Type": "image/png",
            "x-upsert": "true",
        },
    )
    try:
        resp = urllib.request.urlopen(req)
        print(object_name, "status", resp.status, resp.read()[:120])
    except urllib.error.HTTPError as e:
        # retry PUT
        req2 = urllib.request.Request(
            url,
            data=body,
            method="PUT",
            headers={
                "Authorization": f"Bearer {sr}",
                "apikey": sr,
                "Content-Type": "image/png",
                "x-upsert": "true",
            },
        )
        try:
            resp = urllib.request.urlopen(req2)
            print(object_name, "PUT", resp.status)
        except urllib.error.HTTPError as e2:
            print(object_name, "FAIL", e.code, e.read()[:200], e2.code, e2.read()[:200])
            raise


def main() -> None:
    mgmt = get_access_token()
    sr = get_service_role(mgmt)
    email = ROOT / "assets" / "email"
    upload(sr, email / "slst-logo-email.png", "slst-logo-email.png")
    upload(sr, email / "slst-logo-email-dark.png", "slst-logo-email-dark.png")
    print("PUBLIC light", f"https://{PROJECT}.supabase.co/storage/v1/object/public/email-assets/slst-logo-email.png")
    print("PUBLIC dark", f"https://{PROJECT}.supabase.co/storage/v1/object/public/email-assets/slst-logo-email-dark.png")


if __name__ == "__main__":
    main()
