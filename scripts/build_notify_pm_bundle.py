"""Build a single-file notify-pm bundle for MCP deploy."""
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "supabase" / "functions" / "notify-pm"
template = (root / "email-templates" / "ship-confirmation.ts").read_text(encoding="utf-8")
inline = template.replace("export type ", "type ").replace("export function ", "function ")
index = (root / "index.ts").read_text(encoding="utf-8")

import_block = '''import {
  isShipConfirmationType,
  renderShipConfirmationEmail,
  shipDataFromPayload,
} from "./email-templates/ship-confirmation.ts";

'''
if import_block not in index:
    raise SystemExit("import block not found")

merged = index.replace(import_block, "")
needle = 'import { createClient } from "jsr:@supabase/supabase-js@2";\n'
if needle not in merged:
    raise SystemExit("needle not found")

merged = merged.replace(needle, needle + "\n" + inline + "\n")
out = root / "_deploy_bundle.ts"
out.write_text(merged, encoding="utf-8")
print("bundle bytes", out.stat().st_size)
print("has renderShip", "function renderShipConfirmationEmail" in merged)
print("has isShip", "function isShipConfirmationType" in merged)

# Also write MCP-ready JSON with just index.ts = bundle
import json

payload = {
    "project_id": "gdrpdiwykmnybmkadlrv",
    "name": "notify-pm",
    "entrypoint_path": "index.ts",
    "verify_jwt": True,
    "files": [{"name": "index.ts", "content": merged}],
}
json_out = Path(__file__).resolve().parents[1] / ".tmp-deploy-notify-pm-bundle.json"
json_out.write_text(json.dumps(payload), encoding="utf-8")
print("json", json_out, json_out.stat().st_size)
