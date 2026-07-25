import json
import sys

path = r"C:\Users\Brice\Downloads\staging-tracker\.tmp-mcp-args-min.json"
with open(path, encoding="utf-8") as f:
    d = json.load(f)

idx = next(f["content"] for f in d["files"] if f["name"] == "index.ts")
ship = next(f["content"] for f in d["files"] if f["name"] == "email-templates/ship-confirmation.ts")
combined = idx + ship

checks = {
    "ASSET_VERSION 20260722b": "20260722b" in ship,
    "email-assets": "email-assets" in ship,
    'width="300"': 'width="300"' in ship,
    "watermark-gears": "watermark-gears" in ship,
    "Deno.serve": "Deno.serve" in idx,
    "no PLACEHOLDER": "PLACEHOLDER" not in combined,
    "no LOAD_FROM_DISK_NEXT": "LOAD_FROM_DISK_NEXT" not in combined,
}
for k, v in checks.items():
    print(f"{k}: {v}")
if not all(checks.values()):
    sys.exit(1)
print("OK", len(idx), len(ship))
