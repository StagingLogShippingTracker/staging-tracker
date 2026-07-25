"""Load deploy args and print a one-line confirmation; content stays in JSON for MCP."""
import json
from pathlib import Path

args = json.loads(Path(".tmp-mcp-final-args.json").read_text(encoding="utf-8"))
# Ensure files are real
assert args["files"][0]["content"].startswith("import ")
assert "20260725l" in args["files"][1]["content"]
assert "LOAD_FROM_DISK" not in json.dumps(args)
# Write individual escaped JSON strings for each file to make CallMcpTool assembly easier
out = Path(".tmp-mcp-file-json")
out.mkdir(exist_ok=True)
for f in args["files"]:
    name = f["name"].replace("/", "__") + ".json"
    (out / name).write_text(json.dumps(f, ensure_ascii=False), encoding="utf-8")
    print(name, (out / name).stat().st_size)
print("META", json.dumps({k: args[k] for k in args if k != "files"}))
