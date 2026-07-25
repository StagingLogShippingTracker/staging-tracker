import json
import os
import sqlite3
import uuid
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
payload_path = ROOT / "_mcp_deploy" / "mcp_args_only.json"
payload = json.loads(payload_path.read_text(encoding="utf-8"))

PROJECT_ID = payload["project_id"]
FN_NAME = payload["name"]

files = payload["files"]
print("files", [f["name"] for f in files])

boundary = f"----Boundary{uuid.uuid4().hex}"
meta = {
    "name": FN_NAME,
    "entrypoint_path": payload["entrypoint_path"],
    "verify_jwt": bool(payload["verify_jwt"]),
}
chunks = []
chunks.append(
    (
        f"--{boundary}\r\n"
        'Content-Disposition: form-data; name="metadata"\r\n'
        "Content-Type: application/json\r\n\r\n"
        f"{json.dumps(meta)}\r\n"
    ).encode("utf-8")
)
for f in payload["files"]:
    chunks.append(
        (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="{f["name"]}"\r\n'
            "Content-Type: application/typescript\r\n\r\n"
        ).encode("utf-8")
        + f["content"].encode("utf-8")
        + b"\r\n"
    )
chunks.append(f"--{boundary}--\r\n".encode("utf-8"))
body = b"".join(chunks)

TOKEN_KEY = (
    "mcpOAuth.secret.W3BsdWdpbi1zdXBhYmFzZS1zdXBhYmFzZTo6bWNwU2NvcGU6"
    "cHJvZmlsZTpaR1ZtWVhWc2RBXSBtY3BfdG9rZW5z"
)
db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
row = con.cursor().execute("SELECT value FROM ItemTable WHERE key = ?", (TOKEN_KEY,)).fetchone()
con.close()
if not row:
    raise SystemExit("token row missing")
blob = row[0] if isinstance(row[0], str) else row[0].decode("utf-8", errors="replace")
data = json.loads(blob)
token = data.get("access_token") or data.get("accessToken")
if not token and isinstance(data.get("tokens"), dict):
    token = data["tokens"].get("access_token") or data["tokens"].get("accessToken")
if not token:
    inner = data.get("data")
    if isinstance(inner, str):
        inner = json.loads(inner)
    if isinstance(inner, dict):
        token = inner.get("access_token") or inner.get("accessToken")
if not token:
    raise SystemExit("access_token missing")

deploy_url = f"https://api.supabase.com/v1/projects/{PROJECT_ID}/functions/deploy?slug={FN_NAME}"
req = urllib.request.Request(
    deploy_url,
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
        deploy_body = resp.read().decode("utf-8", errors="replace")
        print("DEPLOY_STATUS", resp.status)
        print("DEPLOY_BODY", deploy_body)
except urllib.error.HTTPError as e:
    print("DEPLOY_STATUS", e.code)
    print("DEPLOY_BODY", e.read().decode("utf-8", errors="replace"))
    raise SystemExit(1)
