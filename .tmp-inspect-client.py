import base64
import json
import os
import sqlite3
from pathlib import Path

db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
cur = con.cursor()

# client information
key = (
    "mcpOAuth.secret.W3BsdWdpbi1zdXBhYmFzZS1zdXBhYmFzZTo6bWNwU2NvcGU6"
    "cHJvZmlsZTpaR1ZtWVhWc2RBXSBtY3BfY2xpZW50X2luZm9ybWF0aW9u"
)
row = cur.execute("SELECT value FROM ItemTable WHERE key = ?", (key,)).fetchone()
blob = row[0] if isinstance(row[0], str) else row[0].decode("utf-8", errors="replace")
data = json.loads(blob)
print("client_top", list(data.keys()), data.get("type"))
if data.get("type") == "Buffer":
    raw = bytes(data["data"])
    text = raw.decode("utf-8", errors="replace")
    print("client_text_len", len(text))
    try:
        parsed = json.loads(text)
        print("client_keys", list(parsed.keys()))
        for k, v in parsed.items():
            if isinstance(v, str):
                print(k, "len", len(v), "prefix", v[:24])
            else:
                print(k, type(v).__name__)
    except Exception as e:
        print("client_parse_err", e, "hex", raw[:16].hex())

# code verifier
key2 = (
    "mcpOAuth.secret.W3BsdWdpbi1zdXBhYmFzZS1zdXBhYmFzZTo6bWNwU2NvcGU6"
    "cHJvZmlsZTpaR1ZtWVhWc2RBXSBtY3BfY29kZV92ZXJpZmllcg"
)
row2 = cur.execute("SELECT value FROM ItemTable WHERE key = ?", (key2,)).fetchone()
blob2 = row2[0] if isinstance(row2[0], str) else row2[0].decode("utf-8", errors="replace")
data2 = json.loads(blob2)
print("verifier_top", list(data2.keys()), data2.get("type"))
if data2.get("type") == "Buffer":
    raw2 = bytes(data2["data"])
    print("verifier_len", len(raw2), "ascii?", all(32 <= b < 127 for b in raw2))
    try:
        print("verifier", raw2.decode("utf-8")[:40])
    except Exception:
        print("verifier_hex", raw2[:20].hex())

con.close()
