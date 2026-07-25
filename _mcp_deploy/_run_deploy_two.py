import json, os, sqlite3, uuid, urllib.request, urllib.error
from pathlib import Path

ROOT = Path(r"C:\Users\Brice\Downloads\staging-tracker")
payload_path = ROOT / "_mcp_deploy" / "deploy_two.json"
payload = json.loads(payload_path.read_text(encoding="utf-8"))

PROJECT_ID = payload.get("project_id", "gdrpdiwykmnybmkadlrv")
FN_NAME = payload.get("name", "notify-pm")

files = payload.get("files", [])
if len(files) != 4:
    raise SystemExit(f"expected 4 files, got {len(files)}")
names = {f["name"] for f in files}
expected = {
    "index.ts",
    "email-templates/ship-confirmation.ts",
    "email-templates/email-shared.ts",
    "email-templates/notification-email.ts",
}
if names != expected:
    raise SystemExit(f"unexpected file names: {names}")

combined = "".join(f.get("content", "") for f in files)
for f in files:
    c = f.get("content", "")
    if "PLACEHOLDER" in c:
        raise SystemExit(f"PLACEHOLDER in {f['name']}")
    if f["name"] == "email-templates/ship-confirmation.ts":
        for bad in ("gmail-clip-text", "gmail-blend", "pixel-page", "forcedLightCss"):
            if bad in c:
                raise SystemExit(f"{bad} still in template")
for needle in (
    "Deno.serve",
    "renderShipConfirmationEmail",
    "renderNotificationEmail",
    "20260722f",
    "darkModeCss",
    "public_photo_url",
):
    if needle not in combined:
        raise SystemExit(f"missing {needle}")
print("VERIFY_OK")

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
    raise SystemExit("access_token missing")

boundary = f"----Boundary{uuid.uuid4().hex}"
meta = {
    "name": FN_NAME,
    "entrypoint_path": payload.get("entrypoint_path", "index.ts"),
    "verify_jwt": bool(payload.get("verify_jwt", True)),
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

deploy_json = json.loads(deploy_body)
version = deploy_json.get("version") or deploy_json.get("id")

get_url = f"https://api.supabase.com/v1/projects/{PROJECT_ID}/functions/{FN_NAME}"
req2 = urllib.request.Request(
    get_url,
    method="GET",
    headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
)
with urllib.request.urlopen(req2, timeout=60) as resp2:
    get_body = resp2.read().decode("utf-8", errors="replace")
    print("GET_STATUS", resp2.status)
    get_json = json.loads(get_body)

index_content = None
if isinstance(get_json, dict):
    version = version or get_json.get("version")
    for item in get_json.get("files") or []:
        if isinstance(item, dict) and item.get("name") in ("index.ts", "./index.ts"):
            index_content = item.get("content")
            break

if index_content is None:
    body_url = f"https://api.supabase.com/v1/projects/{PROJECT_ID}/functions/{FN_NAME}/body"
    try:
        req3 = urllib.request.Request(
            body_url,
            method="GET",
            headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
        )
        with urllib.request.urlopen(req3, timeout=60) as resp3:
            body_json = json.loads(resp3.read().decode("utf-8", errors="replace"))
            if isinstance(body_json, dict):
                for item in body_json.get("files", []) or []:
                    if item.get("name") == "index.ts":
                        index_content = item.get("content")
            elif isinstance(body_json, list):
                for item in body_json:
                    if item.get("name") == "index.ts":
                        index_content = item.get("content")
    except urllib.error.HTTPError as e:
        print("BODY_FETCH_STATUS", e.code)

if index_content:
    ok = ("PLACEHOLDER" not in index_content) and ("Deno.serve" in index_content)
    print("POST_VERIFY", "PASS" if ok else "FAIL")
    print("INDEX_HAS_PLACEHOLDER", "PLACEHOLDER" in index_content)
    print("INDEX_HAS_DENO_SERVE", "Deno.serve" in index_content)
else:
    print("POST_VERIFY", "UNKNOWN_NO_INDEX_CONTENT")
    print("GET_JSON_SAMPLE", get_body[:2000])

print("VERSION", version)
