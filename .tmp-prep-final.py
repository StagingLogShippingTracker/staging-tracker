import json
from pathlib import Path

args = json.loads(Path(".tmp-deploy-notify-pm.json").read_text(encoding="utf-8"))
out = {
    "project_id": args["project_id"],
    "name": args["name"],
    "entrypoint_path": args["entrypoint_path"],
    "verify_jwt": True,
    "files": args["files"],
}
Path(".tmp-mcp-final-args.json").write_text(
    json.dumps(out, ensure_ascii=True, separators=(",", ":")),
    encoding="ascii",
)
print("final_args", Path(".tmp-mcp-final-args.json").stat().st_size)
for f in out["files"]:
    print(f["name"], len(f["content"]))
