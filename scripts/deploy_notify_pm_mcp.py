"""Deploy notify-pm via Supabase MCP using Cursor oauth blob."""
from __future__ import annotations

import json
import os
import sqlite3
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parents[1]
payload = json.loads((ROOT / "_mcp_deploy" / "deploy_two.json").read_text(encoding="utf-8"))

TOKEN_KEY = (
    "mcpOAuth.secret.W3BsdWdpbi1zdXBhYmFzZS1zdXBhYmFzZTo6bWNwU2NvcGU6"
    "cHJvZmlsZTpaR1ZtWVhWc2RBXSBtY3BfdG9rZW5z"
)

db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
row = con.execute("SELECT value FROM ItemTable WHERE key = ?", (TOKEN_KEY,)).fetchone()
con.close()
if not row:
    raise SystemExit("no token row")

blob = row[0] if isinstance(row[0], str) else row[0].decode("utf-8", errors="replace")
data = json.loads(blob)
# Blob shapes vary across Cursor versions
candidates = [data]
if isinstance(data.get("data"), str):
    try:
        candidates.append(json.loads(data["data"]))
    except json.JSONDecodeError:
        pass
elif isinstance(data.get("data"), dict):
    candidates.append(data["data"])
if isinstance(data.get("tokens"), dict):
    candidates.append(data["tokens"])

access = None
for c in candidates:
    if not isinstance(c, dict):
        continue
    access = c.get("access_token") or c.get("accessToken")
    if access:
        break
    toks = c.get("tokens")
    if isinstance(toks, dict):
        access = toks.get("access_token") or toks.get("accessToken")
        if access:
            break

if not access:
    print("blob_keys", list(data.keys()))
    raise SystemExit("no access token in MCP blob")

req = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {"name": "deploy_edge_function", "arguments": payload},
}
headers = {
    "Authorization": f"Bearer {access}",
    "Content-Type": "application/json",
    "Accept": "application/json, text/event-stream",
}
response = httpx.post(
    "https://mcp.supabase.com/mcp",
    json=req,
    headers=headers,
    timeout=180.0,
)
print("status", response.status_code)
print(response.text[:4000])
