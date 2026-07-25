"""Build a complete notify-pm Edge deploy payload (multi-file).

Prefer multi-file deploy over a fragile single-file inline bundle so ship,
return, PO, and bulk-PO templates all remain available at runtime.
"""
import json
from pathlib import Path

root = Path(__file__).resolve().parent
fn = root / "supabase" / "functions" / "notify-pm"

files = [
    ("index.ts", fn / "index.ts"),
    ("email-templates/ship-confirmation.ts", fn / "email-templates" / "ship-confirmation.ts"),
    ("email-templates/email-shared.ts", fn / "email-templates" / "email-shared.ts"),
    ("email-templates/notification-email.ts", fn / "email-templates" / "notification-email.ts"),
]

payload_files = []
combined = ""
for name, path in files:
    content = path.read_text(encoding="utf-8")
    assert "PLACEHOLDER" not in content, name
    payload_files.append({"name": name, "content": content})
    combined += content

for required in [
    "renderBrandedEmail",
    "renderShipConfirmationEmail",
    "renderNotificationEmail",
    "isShipConfirmationType",
    "https://www.swiftsupply.ca",
    "VIEW FULL TRACKING DETAILS",
]:
    assert required in combined, required

payload = {
    "project_id": "gdrpdiwykmnybmkadlrv",
    "name": "notify-pm",
    "entrypoint_path": "index.ts",
    "verify_jwt": True,
    "files": payload_files,
}

out = root / ".tmp-deploy-notify-pm-bundled.json"
out.write_text(json.dumps(payload), encoding="utf-8")
print("files", [f["name"] for f in payload_files])
print("payload_bytes", out.stat().st_size)
print("ok")
