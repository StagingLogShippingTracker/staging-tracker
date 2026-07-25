"""Emit a complete notify-pm deploy payload from on-disk Edge Function sources.

Includes index + all email template modules required by imports
(ship-confirmation, notification-email, email-shared).
"""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent
fn = root / "supabase" / "functions" / "notify-pm"

index = (fn / "index.ts").read_text(encoding="utf-8")
ship = (fn / "email-templates" / "ship-confirmation.ts").read_text(encoding="utf-8")
shared = (fn / "email-templates" / "email-shared.ts").read_text(encoding="utf-8")
notifications = (fn / "email-templates" / "notification-email.ts").read_text(
    encoding="utf-8"
)

for label, text in [
    ("ship-confirmation.ts", ship),
    ("email-shared.ts", shared),
    ("notification-email.ts", notifications),
    ("index.ts", index),
]:
    assert "PLACEHOLDER" not in text, label
    assert "LOAD_FROM_DISK" not in text, label

assert "renderBrandedEmail" in shared
assert "renderShipConfirmationEmail" in ship
assert "renderNotificationEmail" in notifications
assert "renderNotificationEmail" in index
assert "email-templates/email-shared.ts" in ship or 'from "./email-shared.ts"' in ship

payload = {
    "project_id": "gdrpdiwykmnybmkadlrv",
    "name": "notify-pm",
    "entrypoint_path": "index.ts",
    "verify_jwt": True,
    "files": [
        {"name": "index.ts", "content": index},
        {"name": "email-templates/ship-confirmation.ts", "content": ship},
        {"name": "email-templates/email-shared.ts", "content": shared},
        {"name": "email-templates/notification-email.ts", "content": notifications},
    ],
}

out = root / ".tmp-mcp-notify-fresh.json"
out.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
(root / ".tmp-mcp-notify-args-line.json").write_text(
    json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
    encoding="utf-8",
)

h = hashlib.sha256(shared.encode("utf-8")).hexdigest()[:16]
print("ok")
print("files", [f["name"] for f in payload["files"]])
print("shared_sha16", h)
print("total_json", out.stat().st_size)
