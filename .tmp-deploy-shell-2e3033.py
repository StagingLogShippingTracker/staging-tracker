"""MCP session init + deploy_edge_function with real notify-pm files."""
from __future__ import annotations

import base64
import json
import os
import sqlite3
import sys
from pathlib import Path

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
except ImportError:
    import subprocess

    subprocess.check_call([sys.executable, "-m", "pip", "install", "cryptography", "-q"])
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

import ctypes
from ctypes import wintypes

import httpx

ROOT = Path(r"C:\Users\Brice\Downloads\staging-tracker")
FN_ROOT = ROOT / "supabase" / "functions" / "notify-pm"
TOKEN_KEY = (
    "mcpOAuth.secret.W3BsdWdpbi1zdXBhYmFzZS1zdXBhYmFzZTo6bWNwU2NvcGU6"
    "cHJvZmlsZTpaR1ZtWVhWc2RBXSBtY3BfdG9rZW5z"
)
MCP_URL = "https://mcp.supabase.com/mcp"
FILES = [
    "index.ts",
    "email-templates/email-shared.ts",
    "email-templates/notification-email.ts",
    "email-templates/ship-confirmation.ts",
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
    return AESGCM(key).decrypt(blob[3:15], blob[15:], None)


def get_access_token() -> str:
    key = chrome_key()
    db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    row = con.execute("SELECT value FROM ItemTable WHERE key = ?", (TOKEN_KEY,)).fetchone()
    con.close()
    wrapped = json.loads(row[0])
    plain = decrypt_v10(bytes(wrapped["data"]), key)
    parsed = json.loads(plain.decode("utf-8"))
    token = parsed.get("access_token") or parsed.get("accessToken")
    if not token and isinstance(parsed.get("tokens"), dict):
        token = parsed["tokens"].get("access_token") or parsed["tokens"].get("accessToken")
    if not token:
        raise SystemExit(f"no token in {list(parsed.keys())}")
    return token


def build_args() -> dict:
    files = []
    for rel in FILES:
        content = (FN_ROOT / rel).read_text(encoding="utf-8")
        if "PLACEHOLDER" in content or "LOAD_FROM_DISK" in content:
            raise SystemExit(f"bad content in {rel}")
        files.append({"name": rel, "content": content})
    combined = "".join(f["content"] for f in files)
    assert 'D_SHELL = "#2e3033"' in combined
    assert 'ASSET_VERSION = "20260725k"' in combined
    assert 'L_SHELL = "#fbf9f5"' in combined
    assert 'D_CARD = "#151515"' in combined
    return {
        "project_id": "gdrpdiwykmnybmkadlrv",
        "name": "notify-pm",
        "entrypoint_path": "index.ts",
        "verify_jwt": True,
        "files": files,
    }


def main() -> None:
    args = build_args()
    token = get_access_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }

    init_payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "slst-deploy", "version": "1.0"},
        },
    }
    with httpx.Client(timeout=180.0) as client:
        r1 = client.post(MCP_URL, headers=headers, json=init_payload)
        print("init status", r1.status_code)
        session = r1.headers.get("mcp-session-id") or r1.headers.get("Mcp-Session-Id")
        print("session", session)
        print(r1.text[:500])
        if not session:
            raise SystemExit("no mcp session id")

        headers2 = {**headers, "Mcp-Session-Id": session}
        client.post(
            MCP_URL,
            headers=headers2,
            json={"jsonrpc": "2.0", "method": "notifications/initialized"},
        )

        deploy_payload = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {"name": "deploy_edge_function", "arguments": args},
        }
        r2 = client.post(MCP_URL, headers=headers2, json=deploy_payload)
        (ROOT / ".tmp-mcp-http-result.txt").write_text(r2.text, encoding="utf-8")
        print("deploy status", r2.status_code)
        print(r2.text[:4000])
        if r2.status_code >= 400:
            raise SystemExit(1)
        if '"isError":true' in r2.text.replace(" ", "") or "PLACEHOLDER" in r2.text:
            raise SystemExit("deploy reported error")


if __name__ == "__main__":
    main()
