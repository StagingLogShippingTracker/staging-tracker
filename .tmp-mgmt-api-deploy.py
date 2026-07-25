"""Deploy notify-pm via Management API using access token from supabase CLI login if present."""
from __future__ import annotations

import json
import os
import uuid
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(r"C:\Users\Brice\Downloads\staging-tracker")
PAYLOAD = ROOT / ".tmp-notify-pm-deploy-files.json"
PROJECT_ID = "gdrpdiwykmnybmkadlrv"
FN_NAME = "notify-pm"


def find_token() -> str | None:
    candidates: list[Path] = []
    home = Path.home()
    candidates.append(home / ".supabase" / "access-token")
    candidates.append(home / "AppData" / "Roaming" / "supabase" / "access-token")
    # CLI credentials file
    for p in [
        home / ".supabase" / "credentials.json",
        home / "AppData" / "Roaming" / "supabase" / "credentials.json",
    ]:
        if p.exists():
            try:
                data = json.loads(p.read_text(encoding="utf-8"))
                for k in ("access_token", "token", "accessToken"):
                    if isinstance(data.get(k), str) and data[k]:
                        return data[k]
            except Exception:
                pass
    for p in candidates:
        if p.exists():
            t = p.read_text(encoding="utf-8").strip()
            if t:
                return t
    # env
    for k in ("SUPABASE_ACCESS_TOKEN", "SUPABASE_TOKEN"):
        if os.environ.get(k):
            return os.environ[k]
    return None


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
    payload = json.loads(PAYLOAD.read_text(encoding="utf-8"))
    combined = "".join(f["content"] for f in payload["files"])
    assert "PLACEHOLDER" not in combined
    assert "LOAD_FROM_DISK" not in combined
    assert "20260725i" in combined
    assert "#151515" in combined
    token = find_token()
    if not token:
        raise SystemExit("NO_TOKEN")
    print("token_len", len(token))
    deploy(token, payload)


if __name__ == "__main__":
    main()
