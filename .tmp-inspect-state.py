import os
import sqlite3
from pathlib import Path

db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
cur = con.cursor()
tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
print("tables", tables)
for t in tables:
    cols = [r[1] for r in cur.execute(f"PRAGMA table_info({t})").fetchall()]
    print(t, cols)

# Search ItemTable keys related to mcp/supabase/oauth
try:
    rows = cur.execute(
        "SELECT key FROM ItemTable WHERE key LIKE '%mcp%' OR key LIKE '%supabase%' OR key LIKE '%oauth%' LIMIT 50"
    ).fetchall()
    print("keys", rows)
except Exception as e:
    print("key search err", e)
