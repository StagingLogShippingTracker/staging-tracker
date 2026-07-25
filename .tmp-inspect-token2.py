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
raw = bytes(data["data"])
print("raw_len", len(raw))
text = raw.decode("utf-8", errors="replace")
print("text_prefix", text[:80])
try:
    parsed = json.loads(text)
    print("parsed_keys", list(parsed.keys()) if isinstance(parsed, dict) else type(parsed).__name__)
    if isinstance(parsed, dict):
        for k, v in parsed.items():
            if isinstance(v, str) and ("token" in k.lower() or k in ("access_token", "refresh_token")):
                print(k, "len", len(v), "prefix", v[:16])
            else:
                print(k, type(v).__name__)
except Exception as e:
    print("not_json", e)
    # maybe it's encrypted; show hex prefix
    print("hex", raw[:32].hex())
