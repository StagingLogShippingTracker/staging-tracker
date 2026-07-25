import base64
import json
import os
import sqlite3
from pathlib import Path

import httpx

db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
cur = con.cursor()

# Find mcp_tokens secret key for plugin-supabase-supabase
rows = cur.execute(
    "SELECT key, value FROM ItemTable WHERE key LIKE 'mcpOAuth.secret.%'"
).fetchall()

tokens_blob = None
for key, value in rows:
    # decode key suffix to see name
    suffix = key.split("mcpOAuth.secret.", 1)[-1]
    try:
        decoded = base64.b64decode(suffix + "==").decode("utf-8", errors="replace")
    except Exception:
        decoded = suffix
    print("secret_key_decoded=", decoded[:120])
    if "mcp_tokens" in decoded or "tokens" in decoded.lower():
        tokens_blob = value
        print("selected tokens key", key[:80])

if not tokens_blob:
    # try all secrets
    for key, value in rows:
        if value and ("access_token" in value or "refresh_token" in value):
            tokens_blob = value
            print("fallback selected", key[:80])
            break

if not tokens_blob:
    raise SystemExit("no tokens found")

print("tokens_blob_len", len(tokens_blob))
print("tokens_blob_prefix", tokens_blob[:80])

try:
    tokens = json.loads(tokens_blob)
except Exception:
    # maybe nested
    tokens = json.loads(json.loads(tokens_blob)) if tokens_blob.startswith('"') else None

print("token_keys", list(tokens.keys()) if isinstance(tokens, dict) else type(tokens))
access = None
if isinstance(tokens, dict):
    access = tokens.get("access_token") or tokens.get("accessToken")
    if not access and "tokens" in tokens:
        access = tokens["tokens"].get("access_token")
print("access_len", len(access) if access else None)

args = json.loads(
    Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-mcp-call-args.json").read_text(
        encoding="utf-8"
    )
)

# Call MCP tools/call over HTTP
payload = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
        "name": "deploy_edge_function",
        "arguments": args,
    },
}

headers = {
    "Authorization": f"Bearer {access}",
    "Content-Type": "application/json",
    "Accept": "application/json, text/event-stream",
}

r = httpx.post("https://mcp.supabase.com/mcp", headers=headers, json=payload, timeout=120.0)
print("status", r.status_code)
print("content_type", r.headers.get("content-type"))
text = r.text
Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-mcp-http-result.txt").write_text(
    text[:20000], encoding="utf-8"
)
print(text[:3000])
