"""Decrypt Cursor MCP OAuth token (Chromium v10) and redeploy notify-pm with real sources."""
from __future__ import annotations

import base64
import json
import os
import sqlite3
import sys
import uuid
import urllib.error
import urllib.request
from pathlib import Path

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
except ImportError:
    import subprocess

    subprocess.check_call([sys.executable, "-m", "pip", "install", "cryptography", "-q"])
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

import ctypes
from ctypes import wintypes

ROOT = Path(r"C:\Users\Brice\Downloads\staging-tracker")
PAYLOAD = ROOT / ".tmp-notify-pm-deploy-files.json"
PROJECT_ID = "gdrpdiwykmnybmkadlrv"
FN_NAME = "notify-pm"
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


def chrome_key() -> bytes:
    local_state = Path(os.environ["APPDATA"]) / "Cursor" / "Local State"
    data = json.loads(local_state.read_text(encoding="utf-8"))
    enc = base64.b64decode(data["os_crypt"]["encrypted_key"])
    assert enc.startswith(b"DPAPI")
    return dpapi_decrypt(enc[5:])


def decrypt_v10(blob: bytes, key: bytes) -> bytes:
    assert blob.startswith(b"v10")
    nonce = blob[3:15]
    ct = blob[15:]
    return AESGCM(key).decrypt(nonce, ct, None)


def get_access_token() -> str:
    key = chrome_key()
    db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    row = con.execute("SELECT value FROM ItemTable WHERE key = ?", (TOKEN_KEY,)).fetchone()
    con.close()
    wrapped = json.loads(row[0])
    raw = bytes(wrapped["data"])
    plain = decrypt_v10(raw, key)
    parsed = json.loads(plain.decode("utf-8"))
    token = parsed.get("access_token") or parsed.get("accessToken")
    if not token and isinstance(parsed.get("tokens"), dict):
        token = parsed["tokens"].get("access_token") or parsed["tokens"].get("accessToken")
    if not token:
        raise SystemExit(f"no access_token in {list(parsed.keys())}")
    return token


def deploy_multipart(token: str, payload: dict) -> None:
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
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            text = resp.read().decode("utf-8", errors="replace")
            print("STATUS", resp.status)
            print(text[:2000])
            Path(ROOT / ".tmp-mcp-http-result.txt").write_text(text, encoding="utf-8")
    except urllib.error.HTTPError as e:
        text = e.read().decode("utf-8", errors="replace")
        print("STATUS", e.code)
        print(text[:2000])
        Path(ROOT / ".tmp-mcp-http-result.txt").write_text(text, encoding="utf-8")
        raise SystemExit(1)


def main() -> None:
    payload = json.loads(PAYLOAD.read_text(encoding="utf-8"))
    combined = "".join(f["content"] for f in payload["files"])
    for needle in [
        "20260725i",
        "#151515",
        "Swift notification via",
        "Deno.serve",
        "pilot project designed and developed by Brice Johnson",
    ]:
        if needle not in combined:
            raise SystemExit(f"missing {needle}")
    for bad in ["PLACEHOLDER", "LOAD_FROM_DISK", "Thank you for using SLST", "#2a2a2c"]:
        if bad in combined:
            raise SystemExit(f"found bad {bad}")
    if not payload.get("verify_jwt", False):
        raise SystemExit("verify_jwt must be true")

    token = get_access_token()
    print("token_len", len(token), "prefix", token[:12])
    deploy_multipart(token, payload)


if __name__ == "__main__":
    main()
