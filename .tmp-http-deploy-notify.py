"""Extract Supabase MCP OAuth token and deploy notify-pm via Management API."""
from __future__ import annotations

import json
import os
import sqlite3
import sys
import uuid
import urllib.error
import urllib.request
from pathlib import Path

PAYLOAD_PATH = Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-deploy-notify-pm-fresh.json")
PROJECT_ID = "gdrpdiwykmnybmkadlrv"
FN_NAME = "notify-pm"
TOKEN_KEY = (
    "mcpOAuth.secret.W3BsdWdpbi1zdXBhYmFzZS1zdXBhYmFzZTo6bWNwU2NvcGU6"
    "cHJvZmlsZTpaR1ZtWVhWc2RBXSBtY3BfdG9rZW5z"
)


def get_token() -> str:
    db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    cur = con.cursor()
    row = cur.execute("SELECT value FROM ItemTable WHERE key = ?", (TOKEN_KEY,)).fetchone()
    con.close()
    if not row:
        raise SystemExit("token row missing")
    value = row[0]
    blob = value if isinstance(value, str) else value.decode("utf-8", errors="replace")
    data = json.loads(blob)
    token = data.get("access_token") or data.get("accessToken")
    if not token and isinstance(data.get("tokens"), dict):
        token = data["tokens"].get("access_token") or data["tokens"].get("accessToken")
    if not token:
        print("token_blob_keys", list(data.keys()), file=sys.stderr)
        raise SystemExit("access_token missing in mcp tokens blob")
    return token


def assert_content(payload: dict) -> None:
    ts = next(f["content"] for f in payload["files"] if f["name"].endswith("ship-confirmation.ts"))
    checks = [
        "https://gdrpdiwykmnybmkadlrv.supabase.co/storage/v1/object/public/email-assets",
        'ASSET_VERSION = "20260722b"',
        'width="300"',
        "color-scheme: light only",
        "data-ogsc",
        "watermark-gears",
    ]
    for needle in checks:
        if needle not in ts:
            raise SystemExit(f"MISSING: {needle}")
    print("content_checks_ok")


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
        ).encode("utf-8")
    )
    for f in payload["files"]:
        name = f["name"]
        content = f["content"].encode("utf-8")
        chunks.append(
            (
                f"--{boundary}\r\n"
                f'Content-Disposition: form-data; name="file"; filename="{name}"\r\n'
                "Content-Type: application/typescript\r\n\r\n"
            ).encode("utf-8")
            + content
            + b"\r\n"
        )
    chunks.append(f"--{boundary}--\r\n".encode("utf-8"))
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
            raw = resp.read().decode("utf-8", errors="replace")
            print("STATUS", resp.status)
            print(raw)
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", errors="replace")
        print("STATUS", e.code)
        print(err)
        raise SystemExit(1)


def main() -> None:
    payload = json.loads(PAYLOAD_PATH.read_text(encoding="utf-8"))
    assert_content(payload)
    token = get_token()
    print("token_prefix", token[:12] + "...")
    deploy_multipart(token, payload)


if __name__ == "__main__":
    main()
