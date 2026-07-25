import json
import subprocess
import sys
from pathlib import Path

root = Path(r"C:\Users\Brice\Downloads\staging-tracker")
args_path = root / ".tmp-mcp-deploy-args-out.json"
args = json.loads(args_path.read_text(encoding="utf-8"))

# Invoke Cursor MCP bridge via python -c in agent context is unavailable; write args for inspection.
meta = {
    "project_id": args["project_id"],
    "name": args["name"],
    "entrypoint_path": args["entrypoint_path"],
    "verify_jwt": args["verify_jwt"],
    "file_names": [f["name"] for f in args["files"]],
    "index_has_deno_serve": "Deno.serve" in args["files"][0]["content"],
    "ship_has_20260722b": "20260722b" in args["files"][1]["content"],
    "ship_has_placeholder": "PLACEHOLDER" in args["files"][1]["content"],
}
print(json.dumps(meta, indent=2))
