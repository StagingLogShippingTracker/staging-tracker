import os, sqlite3, re
from pathlib import Path
db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
rows = con.execute("SELECT key, value FROM ItemTable").fetchall()
con.close()
pat = re.compile(r'eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,}')
found = []
for k,v in rows:
    if not isinstance(v,str):
        continue
    if 'supabase' in k.lower() or 'mcp' in k.lower() or 'access_token' in v:
        m = pat.search(v)
        if m:
            found.append((k, m.group(0)[:30]+'...', len(m.group(0))))
print('jwt_hits', len(found))
for item in found[:15]:
    print(item[0][:80], item[1], item[2])
