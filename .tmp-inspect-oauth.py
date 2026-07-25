"""Inspect Cursor MCP OAuth token blobs for Supabase."""
from __future__ import annotations

import ctypes
import json
import os
import sqlite3
from ctypes import wintypes
from pathlib import Path


class DATA_BLOB(ctypes.Structure):
    _fields_ = [("cbData", wintypes.DWORD), ("pbData", ctypes.POINTER(ctypes.c_char))]


def dpapi_decrypt(encrypted: bytes) -> bytes:
    crypt32 = ctypes.windll.crypt32
    kernel32 = ctypes.windll.kernel32
    blob_in = DATA_BLOB(len(encrypted), ctypes.create_string_buffer(encrypted, len(encrypted)))
    blob_out = DATA_BLOB()
    ok = crypt32.CryptUnprotectData(
        ctypes.byref(blob_in), None, None, None, None, 0, ctypes.byref(blob_out)
    )
    if not ok:
        raise OSError(ctypes.GetLastError())
    try:
        return ctypes.string_at(blob_out.pbData, blob_out.cbData)
    finally:
        kernel32.LocalFree(blob_out.pbData)


db = Path(os.environ["APPDATA"]) / "Cursor" / "User" / "globalStorage" / "state.vscdb"
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
rows = con.execute(
    "SELECT key, value FROM ItemTable WHERE key LIKE '%mcpOAuth%' OR key LIKE '%supabase%' OR key LIKE '%Supabase%'"
).fetchall()
print("count", len(rows))
for key, value in rows:
    print("\nKEY:", key)
    if isinstance(value, memoryview):
        value = value.tobytes()
    if isinstance(value, bytes):
        text = value.decode("utf-8", "replace")
        print(" bytes len", len(value), "text prefix", repr(text[:120]))
        try:
            data = json.loads(text)
        except Exception as e:
            print(" not json", e)
            continue
    else:
        print(" str len", len(value), "prefix", repr(value[:120]))
        data = json.loads(value)

    print(" json type", type(data).__name__, "keys", list(data)[:20] if isinstance(data, dict) else "")
    if not isinstance(data, dict):
        continue
    raw = data.get("data")
    if isinstance(raw, list):
        b = bytes(raw)
        print(" data list -> bytes", len(b), "prefix", b[:16])
        for label, candidate in [("raw", b), ("v10", b[3:] if b.startswith(b"v10") else None), ("v11", b[3:] if b.startswith(b"v11") else None)]:
            if candidate is None:
                continue
            try:
                plain = dpapi_decrypt(candidate)
                print("  decrypt", label, "ok", len(plain), repr(plain[:80]))
            except Exception as e:
                print("  decrypt", label, "fail", e)
    elif isinstance(raw, str):
        print(" data str", repr(raw[:80]))
con.close()
