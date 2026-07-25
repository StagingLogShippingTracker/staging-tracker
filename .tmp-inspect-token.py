import json
import os
import sqlite3
from pathlib import Path

TOKEN_KEY = (
    "mcpOAuth.secret.W3BsdWdpbi1zdXBhYmFzZS1zdXBhYmFzZTo6bWNwU2NvcGU6"
    "cHJvZmlsZTpaR1ZtWVhWc2RBXSBtY3BfdG9rZW5z"
)
db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
cur = con.cursor()
row = cur.execute("SELECT value FROM ItemTable WHERE key = ?", (TOKEN_KEY,)).fetchone()
con.close()
blob = row[0] if isinstance(row[0], str) else row[0].decode("utf-8", errors="replace")
data = json.loads(blob)
print("top_keys", list(data.keys()))
print("type", data.get("type"))
inner = data.get("data")
print("data_type", type(inner).__name__)
if isinstance(inner, dict):
    print("data_keys", list(inner.keys()))
    for k, v in inner.items():
        if isinstance(v, str):
            print(k, "str_len", len(v), "prefix", v[:20])
        else:
            print(k, type(v).__name__, v if not isinstance(v, (dict, list)) else str(type(v)))
elif isinstance(inner, str):
    print("data_str_len", len(inner), "prefix", inner[:40])
    try:
        parsed = json.loads(inner)
        print("parsed_keys", list(parsed.keys()) if isinstance(parsed, dict) else type(parsed))
    except Exception as e:
        print("parse_err", e)
