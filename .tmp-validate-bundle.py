import json
from pathlib import Path

args = json.loads(Path(".tmp-deploy-notify-pm-bundled.json").read_text(encoding="utf-8"))
content0 = args["files"][0]["content"]
assert "PLACEHOLDER" not in content0
assert "renderShipConfirmationEmail" in content0
assert "Deno.serve" in content0
assert 'from "./email-templates/ship-confirmation.ts"' not in content0
print("bundled ok", len(content0), len(args["files"]))
Path(".tmp-bundled-mcp-args.json").write_text(
    json.dumps(args, ensure_ascii=True, separators=(",", ":")),
    encoding="ascii",
)
print("args file", Path(".tmp-bundled-mcp-args.json").stat().st_size)

# Also prepare canonical 3-file for preferred deploy
canon = json.loads(Path(".tmp-deploy-notify-pm.json").read_text(encoding="utf-8"))
Path(".tmp-canon-mcp-args.json").write_text(
    json.dumps(canon, ensure_ascii=True, separators=(",", ":")),
    encoding="ascii",
)
print("canon file", Path(".tmp-canon-mcp-args.json").stat().st_size)
