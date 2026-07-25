"""Emit deploy args as a Python pickle/json that we can load for MCP.
Also print a checksum so we know content is correct before deploy.
"""
import hashlib
import json
from pathlib import Path

root = Path(r"C:\Users\Brice\Downloads\staging-tracker")
j = json.loads((root / ".tmp-deploy-notify-pm.json").read_text(encoding="utf-8"))

# Prefer disk sources (fresh)
index = (root / "supabase/functions/notify-pm/index.ts").read_text(encoding="utf-8")
ship = (root / "supabase/functions/notify-pm/email-templates/ship-confirmation.ts").read_text(
    encoding="utf-8"
)
html = (
    root / "supabase/functions/notify-pm/email-templates/ship-confirmation.html"
).read_text(encoding="utf-8")

assert "PLACEHOLDER" not in ship
assert 'ASSET_VERSION = "20260722b"' in ship
assert "storage/v1/object/public/email-assets" in ship
assert 'width="300"' in ship
assert "data-ogsc" in ship

payload = {
    "project_id": "gdrpdiwykmnybmkadlrv",
    "name": "notify-pm",
    "entrypoint_path": "index.ts",
    "verify_jwt": True,
    "files": [
        {"name": "index.ts", "content": index},
        {"name": "email-templates/ship-confirmation.ts", "content": ship},
        {"name": "email-templates/ship-confirmation.html", "content": html},
    ],
}

out = root / ".tmp-mcp-notify-fresh.json"
out.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")

# Also write a single-line NDJSON for easy consumption
(root / ".tmp-mcp-notify-args-line.json").write_text(
    json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
    encoding="utf-8",
)

h = hashlib.sha256(ship.encode("utf-8")).hexdigest()[:16]
print("ok")
print("ship_sha16", h)
print("ship_len", len(ship))
print("total_json", out.stat().st_size)
