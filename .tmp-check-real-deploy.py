import json
from pathlib import Path

args = json.loads(
    Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-mcp-notify-args-only.json").read_text(
        encoding="utf-8"
    )
)
for i, f in enumerate(args["files"]):
    c = f["content"]
    bad = "PLACEHOLDER" in c or "LOAD_FROM_DISK" in c
    print(
        f"{i}|{f['name']}|{len(c)}|j={'20260725j' in c}|shell={'#2a2a2c' in c}|card={'#151515' in c}|bad={bad}"
    )
