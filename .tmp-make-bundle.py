"""Bundle notify-pm into a single index.ts for reliable MCP deploy, then also keep multi-file args."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(r"C:\Users\Brice\Downloads\staging-tracker")
FN = ROOT / "supabase" / "functions" / "notify-pm"

shared = (FN / "email-templates" / "email-shared.ts").read_text(encoding="utf-8")
notif = (FN / "email-templates" / "notification-email.ts").read_text(encoding="utf-8")
ship = (FN / "email-templates" / "ship-confirmation.ts").read_text(encoding="utf-8")
index = (FN / "index.ts").read_text(encoding="utf-8")

# Strip imports that become local; keep jsr imports in index.
def strip_relative_imports(src: str) -> str:
    lines = []
    for line in src.splitlines():
        if line.startswith("import ") and "./" in line:
            continue
        if line.startswith("} from \"./"):
            continue
        lines.append(line)
    return "\n".join(lines)

# email-shared has no relative imports
shared_body = shared

# notification imports from email-shared — remove those import lines
notif_body = "\n".join(
    ln
    for ln in notif.splitlines()
    if not (
        ln.strip().startswith("import ")
        or ln.strip().startswith("} from \"./email-shared")
        or ln.strip() in ("displayOrNone,", "renderBrandedEmail,", "DEFAULT_EMAIL_ASSET_BASE,")
        or (ln.strip().startswith("DEFAULT_EMAIL_ASSET_BASE,") )
    )
)
# Cleaner strip for multi-line import
import re
notif_body = re.sub(
    r"import\s*\{[^}]*\}\s*from\s*\"./email-shared\.ts\";\s*",
    "",
    notif,
    flags=re.S,
)
ship_body = re.sub(
    r"import\s*\{[^}]*\}\s*from\s*\"./email-shared\.ts\";\s*",
    "",
    ship,
    flags=re.S,
)
index_body = re.sub(
    r"import\s*\{[^}]*\}\s*from\s*\"./email-templates/ship-confirmation\.ts\";\s*",
    "",
    index,
    flags=re.S,
)
index_body = re.sub(
    r"import\s*\{[^}]*\}\s*from\s*\"./email-templates/notification-email\.ts\";\s*",
    "",
    index_body,
    flags=re.S,
)

bundled = "\n".join(
    [
        'import "jsr:@supabase/functions-js/edge-runtime.d.ts";',
        'import { createClient } from "jsr:@supabase/supabase-js@2";',
        "",
        "// --- email-shared.ts ---",
        shared_body,
        "",
        "// --- ship-confirmation.ts ---",
        ship_body,
        "",
        "// --- notification-email.ts ---",
        notif_body,
        "",
        "// --- index.ts ---",
        # drop the jsr imports already added
        "\n".join(
            ln
            for ln in index_body.splitlines()
            if not ln.startswith('import "jsr:')
            and not ln.startswith("import { createClient }")
        ),
    ]
)

assert "20260725l" in bundled
assert "width: 49%" in bundled
assert "Deno.serve" in bundled
assert "LOAD_FROM_DISK" not in bundled
assert "PLACEHOLDER" not in bundled

out = ROOT / ".tmp-bundled-index.ts"
out.write_text(bundled, encoding="utf-8")
print("bundled bytes", len(bundled.encode("utf-8")))

# Multi-file real deploy args (preferred)
files = [
    {"name": "index.ts", "content": index},
    {"name": "email-templates/email-shared.ts", "content": shared},
    {"name": "email-templates/notification-email.ts", "content": notif},
    {"name": "email-templates/ship-confirmation.ts", "content": ship},
]
args = {
    "project_id": "gdrpdiwykmnybmkadlrv",
    "name": "notify-pm",
    "entrypoint_path": "index.ts",
    "verify_jwt": True,
    "files": files,
}
(ROOT / ".tmp-mcp-final-args.json").write_text(
    json.dumps(args, ensure_ascii=False), encoding="utf-8"
)
print("multi-file args ready", (ROOT / ".tmp-mcp-final-args.json").stat().st_size)

# Single-file fallback args
args1 = {
    "project_id": "gdrpdiwykmnybmkadlrv",
    "name": "notify-pm",
    "entrypoint_path": "index.ts",
    "verify_jwt": True,
    "files": [{"name": "index.ts", "content": bundled}],
}
(ROOT / ".tmp-mcp-bundled-args.json").write_text(
    json.dumps(args1, ensure_ascii=False), encoding="utf-8"
)
print("bundled args ready", (ROOT / ".tmp-mcp-bundled-args.json").stat().st_size)
