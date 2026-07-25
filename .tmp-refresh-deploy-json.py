"""Load deploy JSON and print as a single line for MCP consumption helper."""
import json
from pathlib import Path

# Re-read sources from disk to guarantee freshness (not stale JSON)
root = Path(r"C:\Users\Brice\Downloads\staging-tracker\supabase\functions\notify-pm")
files = []
for rel in [
    "email-templates/email-shared.ts",
    "email-templates/notification-email.ts",
    "email-templates/ship-confirmation.ts",
    "index.ts",
]:
    content = (root / rel).read_text(encoding="utf-8")
    assert "PLACEHOLDER" not in content
    assert "LOAD_FROM_DISK" not in content
    files.append({"name": rel, "content": content})

args = {
    "project_id": "gdrpdiwykmnybmkadlrv",
    "name": "notify-pm",
    "entrypoint_path": "index.ts",
    "verify_jwt": True,
    "files": files,
}
out = Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-notify-pm-deploy-files.json")
out.write_text(json.dumps(args), encoding="utf-8")
shared = files[0]["content"]
print("ASSET", "20260725i" in shared)
print("DCARD", "#151515" in shared)
print("FOOTER", "Swift notification via" in shared)
print("BAD39", "LOAD_FROM_DISK" in json.dumps(args))
print("SIZE", out.stat().st_size)
