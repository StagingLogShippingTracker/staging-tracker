"""Try to find a usable Supabase access token in browser cookies / local storage dumps."""
from __future__ import annotations

import json
import os
import sqlite3
from pathlib import Path

candidates = []
local = Path(os.environ["LOCALAPPDATA"])
# Chrome cookies
for browser in ["Google/Chrome", "Microsoft/Edge", "BraveSoftware/Brave-Browser"]:
    cookie_db = local / browser / "User Data" / "Default" / "Network" / "Cookies"
    if cookie_db.exists():
        candidates.append(("cookies", cookie_db))
    # Local Storage leveldb may have tokens - skip binary
    ls = local / browser / "User Data" / "Default" / "Local Storage" / "leveldb"
    if ls.exists():
        for f in ls.glob("*.log"):
            try:
                text = f.read_bytes()
                if b"access_token" in text or b"supabase" in text.lower():
                    candidates.append(("leveldb", f))
            except Exception:
                pass

print("candidates", len(candidates))
for kind, p in candidates[:20]:
    print(kind, p, p.stat().st_size)
