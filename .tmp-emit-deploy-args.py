import json
from pathlib import Path

root = Path(r"C:\Users\Brice\Downloads\staging-tracker")
args = json.loads((root / ".tmp-call-args-for-mcp.json").read_text(encoding="utf-8"))
# Emit args for agent MCP call (stdout kept small)
print(json.dumps({
    "project_id": args["project_id"],
    "name": args["name"],
    "entrypoint_path": args["entrypoint_path"],
    "verify_jwt": args["verify_jwt"],
    "files": args["files"],
}))
