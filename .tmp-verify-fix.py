"""Print deploy args JSON to stdout for MCP; used only as a size/hash check."""
import hashlib
import json
from pathlib import Path

args = json.loads(Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-fix-deploy.json").read_text(encoding="utf-8"))
for f in args["files"]:
    print(f["name"], len(f["content"]), hashlib.sha256(f["content"].encode()).hexdigest()[:12], "PLACEHOLDER" in f["content"])
# Also ensure 2-file essential without html for smaller call
ess = {
    "project_id": args["project_id"],
    "name": args["name"],
    "entrypoint_path": args["entrypoint_path"],
    "verify_jwt": True,
    "files": [f for f in args["files"] if f["name"].endswith(".ts")],
}
Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-mcp-args-min.json").write_text(json.dumps(ess), encoding="utf-8")
print("min_bytes", Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-mcp-args-min.json").stat().st_size)
