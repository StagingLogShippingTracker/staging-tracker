import json
from pathlib import Path

root = Path(r"C:\Users\Brice\Downloads\staging-tracker")
args = json.loads((root / ".tmp-mcp-args-min.json").read_text(encoding="utf-8"))
# Normalize line endings to match source on disk
for f in args["files"]:
    if f["name"] == "index.ts":
        f["content"] = (root / "supabase/functions/notify-pm/index.ts").read_text(encoding="utf-8")
    elif f["name"] == "email-templates/ship-confirmation.ts":
        f["content"] = (root / "supabase/functions/notify-pm/email-templates/ship-confirmation.ts").read_text(encoding="utf-8")

out = root / ".tmp-mcp-deploy-args-out.json"
out.write_text(json.dumps(args, ensure_ascii=False), encoding="utf-8")
print("wrote", out, "bytes", out.stat().st_size)
