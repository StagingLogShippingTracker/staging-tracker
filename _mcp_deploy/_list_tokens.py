import os, sqlite3, base64, json
from pathlib import Path
db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
rows = con.execute("SELECT key, value FROM ItemTable WHERE key LIKE 'mcpOAuth.secret.%'").fetchall()
for k, v in rows:
    s = k.split("mcpOAuth.secret.", 1)[-1]
    try:
        d = base64.b64decode(s + "==").decode("utf-8", "replace")
    except Exception:
        d = s
    print("KEY", d)
    if isinstance(v, str):
        print("  prefix", v[:120])
        try:
            data = json.loads(v)
            print("  json keys", list(data.keys()) if isinstance(data, dict) else type(data))
        except Exception as e:
            print("  not json", e)
    else:
        print("  bytes len", len(v))
