"""Prepare notify-pm deploy payload for Supabase MCP."""

import json

from pathlib import Path

root = Path(__file__).resolve().parents[1] / "supabase" / "functions" / "notify-pm"

index = (root / "index.ts").read_text(encoding="utf-8")
ship = (root / "email-templates" / "ship-confirmation.ts").read_text(encoding="utf-8")
shared = (root / "email-templates" / "email-shared.ts").read_text(encoding="utf-8")
notifications = (root / "email-templates" / "notification-email.ts").read_text(
    encoding="utf-8"
)

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

out = Path(__file__).resolve().parents[1] / "_mcp_deploy" / "deploy_two.json"
out.write_text(json.dumps(payload), encoding="utf-8")

combined = index + ship + shared + notifications
for bad in [
    "PLACEHOLDER",
    "LOAD_FROM_DISK",
    "gmail-clip-text",
    "gmail-blend",
    "gmailClipText",
    "gmailWhiteText",
    "outlookSurface",
    "pixel-page",
    "mso-keep-black",
    "forcedLightCss",
]:
    assert bad not in combined, bad

for good in [
    "Deno.serve",
    "renderShipConfirmationEmail",
    "renderNotificationEmail",
    "renderBrandedEmail",
    "20260801footer-fade",
    "FOOTER_FADE",
    "3C424C",
    "slst-wordmark-footer",
    "SLST_WORDMARK_FOOTER_URL",
    "darkModeCss",
    "surfaceBg",
    "swift-supply-logo-email",
    "headerLogosBlock",
    "publicPhotoUrl",
    "public_photo_url",
    "SLST",
]:
    assert good in combined, good

for retired in [
    "slst-logo-email",
    "20260728sst-darkforce",
    "Open Swift Supply",
    "Open on Swift",
    "OPEN SWIFT SUPPLY",
    "og-cta",
    "Swift Staging Tracker",
    "Staging & Shipping Tracker",
]:
    assert retired not in combined, retired

print("ok", out, out.stat().st_size)
