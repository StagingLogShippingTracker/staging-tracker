import json
from pathlib import Path

d = json.loads(
    Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-mcp-notify-args-only.json").read_text(
        encoding="utf-8"
    )
)
shared = d["files"][1]["content"]
print("files", [f["name"] for f in d["files"]])
print("verify_jwt", d["verify_jwt"])
print("asset", "20260725j" in shared)
print("dshell", 'D_SHELL = "#2a2a2c"' in shared)
print("dcard", 'D_CARD = "#151515"' in shared)
print("lshell", 'L_SHELL = "#fbf9f5"' in shared)
print("placeholder", "PLACEHOLDER" in json.dumps(d))
