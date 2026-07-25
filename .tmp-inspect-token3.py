"""Inspect Cursor MCP OAuth token storage for Supabase."""
from __future__ import annotations

import json
import os
import sqlite3
from pathlib import Path

db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
rows = con.execute(
    "SELECT key FROM ItemTable WHERE key LIKE '%supabase%' OR key LIKE '%mcpOAuth%' OR key LIKE '%mcp_token%'"
).fetchall()
for r in rows:
    print(r[0][:200])
print("--- count", len(rows))

# Try a few known patterns
for key, in rows:
    if "token" in key.lower() or "oauth" in key.lower():
        row = con.execute("SELECT value FROM ItemTable WHERE key = ?", (key,)).fetchone()
        val = row[0]
        if isinstance(val, bytes):
            print("BYTES key", key[:80], "len", len(val), "head", val[:40])
        else:
            s = str(val)[:200]
            print("STR key", key[:80], "head", s)
con.close()
