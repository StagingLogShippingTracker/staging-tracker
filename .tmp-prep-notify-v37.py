"""Build notify-pm deploy payload JSON for MCP deploy_edge_function."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(r"C:\Users\Brice\Downloads\staging-tracker")
FN = ROOT / "supabase" / "functions" / "notify-pm"
OUT = ROOT / ".tmp-notify-pm-deploy-v37.json"

files = [
    "index.ts",
    "email-templates/ship-confirmation.ts",
    "email-templates/email-shared.ts",
    "email-templates/notification-email.ts",
]

payload = {
    "project_id": "gdrpdiwykmnybmkadlrv",
    "name": "notify-pm",
    "entrypoint_path": "index.ts",
    "verify_jwt": True,
    "files": [
        {"name": name, "content": (FN / name).read_text(encoding="utf-8")}
        for name in files
    ],
}

# sanity
shared = next(f["content"] for f in payload["files"] if f["name"].endswith("email-shared.ts"))
assert "20260725h" in shared
assert "slst-logo-email-dark" in shared
assert "logo-dark" in shared
assert "#2a2a2c" in shared
assert "prefers-color-scheme: dark" in shared
assert 'background-color: ${L_CARD}' in shared or "background-color: ${L_CARD}" in shared
assert "#f1ece4" in shared
# ensure no placeholder nonsense
for f in payload["files"]:
    assert "PLACEHOLDER" not in f["content"]
    assert len(f["content"]) > 100

OUT.write_text(json.dumps(payload), encoding="utf-8")
print("wrote", OUT, "bytes", OUT.stat().st_size)
print("files", [(f["name"], len(f["content"])) for f in payload["files"]])
