import json
import os
import sqlite3
import sys
from pathlib import Path

# Load deploy args for CallMcpTool verification / fallback HTTP deploy
root = Path(r"C:\Users\Brice\Downloads\staging-tracker")
args = json.loads((root / ".tmp-call-args-for-mcp.json").read_text(encoding="utf-8"))
idx = args["files"][0]["content"]
ship = args["files"][1]["content"]
combined = idx + ship
assert "Deno.serve" in idx
assert "20260722b" in ship
assert "email-assets" in ship
assert 'width="300"' in ship
assert "watermark-gears" in ship
assert "PLACEHOLDER" not in combined
assert "LOAD_FROM_DISK_NEXT" not in combined
# Emit compact summary for agent; full args remain in .tmp-call-args-for-mcp.json
print(json.dumps({
    "ready": True,
    "project_id": args["project_id"],
    "name": args["name"],
    "index_len": len(idx),
    "ship_len": len(ship),
}))
