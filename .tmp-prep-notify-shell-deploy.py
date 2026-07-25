import json
import pathlib

root = pathlib.Path(r"C:\Users\Brice\Downloads\staging-tracker\supabase\functions\notify-pm")
files = [
    "index.ts",
    "email-templates/email-shared.ts",
    "email-templates/notification-email.ts",
    "email-templates/ship-confirmation.ts",
]
out = []
for rel in files:
    p = root / rel
    content = p.read_text(encoding="utf-8")
    assert "PLACEHOLDER" not in content, rel
    out.append({"name": rel, "content": content})
    print(f"{rel}: {len(content)} chars")

shared = (root / "email-templates/email-shared.ts").read_text(encoding="utf-8")
assert 'const D_SHELL = "#2e3033"' in shared
assert 'ASSET_VERSION = "20260725j"' in shared
assert ".email-container, .og-shell { background-color: ${D_SHELL}" in shared
assert 'const L_SHELL = "#fbf9f5"' in shared
print("checks ok")

payload = {
    "project_id": "gdrpdiwykmnybmkadlrv",
    "name": "notify-pm",
    "entrypoint_path": "index.ts",
    "verify_jwt": True,
    "files": out,
}
args_path = pathlib.Path(
    r"C:\Users\Brice\Downloads\staging-tracker\.tmp-deploy-notify-shell.json"
)
args_path.write_text(json.dumps(payload), encoding="utf-8")
print(f"wrote {args_path} ({args_path.stat().st_size} bytes)")
