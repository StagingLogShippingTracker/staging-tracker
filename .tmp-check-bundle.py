import json
from pathlib import Path

bundled = json.loads(Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-onefile-deploy.json").read_text(encoding="utf-8"))
c = bundled["files"][0]["content"]
print("bundled_len", len(c))
print("has_relative_import", 'from "./email-templates' in c)
print("has_ASSET", "20260722b" in c)
print("has_inline_marker", "inlined email-templates" in c)
