import base64
import json
import os
import sqlite3
from pathlib import Path

db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
cur = con.cursor()
rows = cur.execute(
    "SELECT key, value FROM ItemTable WHERE key LIKE 'mcpOAuth.global.%'"
).fetchall()
for key, value in rows:
    suffix = key.split("mcpOAuth.global.", 1)[-1]
    pad = "=" * ((4 - len(suffix) % 4) % 4)
    try:
        decoded = base64.b64decode(suffix + pad).decode("utf-8", errors="replace")
    except Exception:
        decoded = suffix
    blob = value if isinstance(value, str) else value.decode("utf-8", errors="replace")
    print("---")
    print("decoded", decoded[:120])
    print("value", blob[:200].replace("\n", " "))
con.close()
