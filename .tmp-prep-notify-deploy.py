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
    p = root / pathlib.Path(*rel.split("/"))
    content = p.read_text(encoding="utf-8")
    if "email-shared" in rel:
        assert "20260725j" in content, "ASSET_VERSION missing"
        assert 'D_SHELL = "#2a2a2c"' in content, "D_SHELL missing"
        assert 'D_CARD = "#151515"' in content, "D_CARD missing"
        assert 'L_SHELL = "#fbf9f5"' in content, "L_SHELL missing"
        assert ".email-container, .og-shell" in content, "shell dark override missing"
    assert "PLACEHOLDER" not in content, f"PLACEHOLDER in {rel}"
    out.append({"name": rel, "content": content})
    print(f"{rel}: {len(content)} chars")

args = {
    "project_id": "gdrpdiwykmnybmkadlrv",
    "name": "notify-pm",
    "entrypoint_path": "index.ts",
    "verify_jwt": True,
    "files": out,
}
path = pathlib.Path(
    r"C:\Users\Brice\Downloads\staging-tracker\.tmp-mcp-notify-args-only.json"
)
path.write_text(json.dumps(args), encoding="utf-8")
print("wrote", path, "total", path.stat().st_size)
print("no PLACEHOLDER ok")
