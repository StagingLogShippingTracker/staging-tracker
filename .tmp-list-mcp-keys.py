import base64
import json
import os
import sqlite3
from pathlib import Path

db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
cur = con.cursor()
rows = cur.execute(
    "SELECT key, typeof(value), length(value) FROM ItemTable WHERE key LIKE '%mcp%' OR key LIKE '%supabase%' OR key LIKE '%OAuth%'"
).fetchall()
print("rows", len(rows))
for key, typ, length in rows:
    print(typ, length, key[:200])
con.close()
