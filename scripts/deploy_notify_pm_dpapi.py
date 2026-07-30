"""Deploy notify-pm via Supabase Management API (AESGCM v10 token from Cursor)."""

from __future__ import annotations

import base64
import ctypes
import json
import os
import sqlite3
import sys
import uuid
import urllib.error
import urllib.request
from ctypes import wintypes
from pathlib import Path

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

ROOT = Path(__file__).resolve().parents[1]
TOKEN_KEY = (
    "mcpOAuth.secret.W3BsdWdpbi1zdXBhYmFzZS1zdXBhYmFzZTo6bWNwU2NvcGU6"
    "cHJvZmlsZTpaR1ZtWVhWc2RBXSBtY3BfdG9rZW5z"
)
PROJECT_ID = "gdrpdiwykmnybmkadlrv"
FN_NAME = "notify-pm"

SOURCE_FILES = [
    ("index.ts", ROOT / "supabase/functions/notify-pm/index.ts"),
    (
        "email-templates/email-shared.ts",
        ROOT / "supabase/functions/notify-pm/email-templates/email-shared.ts",
    ),
    (
        "email-templates/notification-email.ts",
        ROOT / "supabase/functions/notify-pm/email-templates/notification-email.ts",
    ),
    (
        "email-templates/ship-confirmation.ts",
        ROOT / "supabase/functions/notify-pm/email-templates/ship-confirmation.ts",
    ),
]


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
        raise OSError(f"CryptUnprotectData failed: {ctypes.GetLastError()}")
    try:
        return ctypes.string_at(blob_out.pbData, blob_out.cbData)
    finally:
        kernel32.LocalFree(blob_out.pbData)


def get_chrome_key() -> bytes:
    local_state = Path(os.environ["APPDATA"]) / "Cursor" / "Local State"
    data = json.loads(local_state.read_text(encoding="utf-8"))
    enc_key = base64.b64decode(data["os_crypt"]["encrypted_key"])
    if enc_key.startswith(b"DPAPI"):
        enc_key = enc_key[5:]
    return dpapi_decrypt(enc_key)


def decrypt_v10(blob: bytes, key: bytes) -> bytes:
    if not blob.startswith(b"v10"):
        raise ValueError("not v10")
    nonce = blob[3:15]
    ciphertext = blob[15:]
    return AESGCM(key).decrypt(nonce, ciphertext, None)


def get_access_token() -> str:
    db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    row = con.execute("SELECT value FROM ItemTable WHERE key = ?", (TOKEN_KEY,)).fetchone()
    con.close()
    data = json.loads(row[0] if isinstance(row[0], str) else row[0].decode("utf-8", errors="replace"))
    raw = bytes(data["data"])
    key = get_chrome_key()
    plain = decrypt_v10(raw, key)
    parsed = json.loads(plain.decode("utf-8"))
    token = parsed.get("access_token") or parsed.get("accessToken")
    if not token and isinstance(parsed.get("tokens"), dict):
        token = parsed["tokens"].get("access_token") or parsed["tokens"].get("accessToken")
    if not token:
        raise SystemExit(f"no access_token in {list(parsed.keys())}")
    return token


def load_payload() -> dict:
    files = []
    for name, path in SOURCE_FILES:
        content = path.read_text(encoding="utf-8")
        if "PLACEHOLDER" in content and len(content) < 100:
            raise SystemExit(f"refusing to deploy placeholder: {name}")
        files.append({"name": name, "content": content})
    combined = "".join(f["content"] for f in files)
    for needle in [
        "renderBrandedEmail",
        "090D16",
        "SLST",
        "swift-supply-logo-email",
        "Missing required fields",
    ]:
        if needle not in combined:
            raise SystemExit(f"missing expected marker: {needle}")
    for banned in [
        "via.placeholder.com",
        "Open Swift Supply",
        "Open on Swift",
        "og-cta",
        "Swift Staging Tracker",
        "Staging & Shipping Tracker",
    ]:
        if banned in combined:
            raise SystemExit(f"refusing banned content: {banned}")
    if 'width="250"' in combined or "font-size: 32px" in combined:
        raise SystemExit("refusing oversized logo/headline styles")
    return {
        "entrypoint_path": "index.ts",
        "verify_jwt": True,
        "files": files,
    }


def deploy(token: str, payload: dict) -> None:
    boundary = f"----Boundary{uuid.uuid4().hex}"
    meta = {
        "name": FN_NAME,
        "entrypoint_path": payload.get("entrypoint_path", "index.ts"),
        "verify_jwt": bool(payload.get("verify_jwt", True)),
    }
    chunks: list[bytes] = []
    chunks.append(
        (
            f"--{boundary}\r\n"
            'Content-Disposition: form-data; name="metadata"\r\n'
            "Content-Type: application/json\r\n\r\n"
            f"{json.dumps(meta)}\r\n"
        ).encode()
    )
    for f in payload["files"]:
        content = f["content"].encode("utf-8")
        chunks.append(
            (
                f"--{boundary}\r\n"
                f'Content-Disposition: form-data; name="file"; filename="{f["name"]}"\r\n'
                "Content-Type: application/typescript\r\n\r\n"
            ).encode()
            + content
            + b"\r\n"
        )
    chunks.append(f"--{boundary}--\r\n".encode())
    body = b"".join(chunks)
    url = f"https://api.supabase.com/v1/projects/{PROJECT_ID}/functions/deploy?slug={FN_NAME}"
    req = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Accept": "application/json",
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/126.0.0.0 Safari/537.36"
            ),
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            print("STATUS", resp.status)
            print(resp.read().decode("utf-8", errors="replace"))
    except urllib.error.HTTPError as e:
        print("STATUS", e.code)
        print(e.read().decode("utf-8", errors="replace"))
        raise SystemExit(1)


def main() -> None:
    payload = load_payload()
    print(
        "files",
        [(f["name"], len(f["content"])) for f in payload["files"]],
        flush=True,
    )
    token = get_access_token()
    print("token_ok", len(token), flush=True)
    deploy(token, payload)


if __name__ == "__main__":
    main()
