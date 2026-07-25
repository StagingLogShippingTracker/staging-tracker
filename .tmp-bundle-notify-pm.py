"""Bundle notify-pm into a single index.ts for Edge deploy."""
import json
import pathlib
import re

root = pathlib.Path(r"C:\Users\Brice\Downloads\staging-tracker\supabase\functions\notify-pm")
index = (root / "index.ts").read_text(encoding="utf-8")
template = (root / "email-templates" / "ship-confirmation.ts").read_text(encoding="utf-8")

# Strip export keywords from template (becomes local module body)
templ_body = re.sub(r"^export\s+", "", template, flags=re.M)
# Keep type export as type alias without export for bundling simplicity
templ_body = templ_body.replace("export type ", "type ")
templ_body = templ_body.replace("export function ", "function ")
templ_body = templ_body.replace("export const ", "const ")

# Remove the import of ship-confirmation from index
bundled_index = re.sub(
    r'import \{\s*isShipConfirmationType,\s*renderShipConfirmationEmail,\s*shipDataFromPayload,\s*\} from "\./email-templates/ship-confirmation\.ts";\s*',
    "",
    index,
    count=1,
)

# Insert template after the supabase-js import
marker = 'import { createClient } from "jsr:@supabase/supabase-js@2";\n'
if marker not in bundled_index:
    raise SystemExit("import marker not found")
bundled = bundled_index.replace(
    marker,
    marker + "\n// --- inlined email-templates/ship-confirmation.ts ---\n" + templ_body + "\n// --- end inline ---\n",
    1,
)

payload = {
    "project_id": "gdrpdiwykmnybmkadlrv",
    "name": "notify-pm",
    "entrypoint_path": "index.ts",
    "verify_jwt": True,
    "files": [{"name": "index.ts", "content": bundled}],
}
out = pathlib.Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-deploy-notify-pm-bundled.json")
out.write_text(json.dumps(payload), encoding="utf-8")
print("bundled_bytes", len(bundled.encode("utf-8")))
print("payload_bytes", out.stat().st_size)
for c in [
    'ASSET_VERSION = "20260722b"',
    "email-assets",
    'width="300"',
    "watermark-gears",
    "data-ogsc",
]:
    print(("OK" if c in bundled else "MISSING"), c)
