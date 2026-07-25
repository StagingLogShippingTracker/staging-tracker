import json
import re
from pathlib import Path

# Verify preview logos
p = Path(r".tmp-email-preview/from-reference-light.html").read_text(encoding="utf-8")
imgs = re.findall(r"<img[^>]+>", p)
for img in imgs:
    if any(x in img.lower() for x in ("logo", "swift", "slst")):
        w = re.search(r'width="(\d+)"', img)
        mw = re.search(r"max-width:\s*(\d+)px", img)
        print("width", w.group(1) if w else None, "max-width", mw.group(1) if mw else None)

# Verify deployed function snippet
deploy = Path(
    r"C:\Users\Brice\.cursor\projects\c-Users-Brice-Downloads-staging-tracker"
    r"\agent-tools\5a333683-ede3-430a-b64d-b8aaf2383cc7.txt"
).read_text(encoding="utf-8")
obj = json.loads(deploy)
print("version", obj.get("version"))
print("verify_jwt", obj.get("verify_jwt"))
files = {f["name"]: f["content"] for f in obj.get("files", [])}
shared = files.get("email-templates/email-shared.ts", "")
print("ASSET_VERSION", re.search(r'ASSET_VERSION = "([^"]+)"', shared).group(1) if shared else None)
print("has width=150", 'width="150"' in shared)
print("has max-width: 160px", "max-width: 160px" in shared)
print("has #fbf9f5", "#fbf9f5" in shared)
print("has #121314", "#121314" in shared)
print("has #ff8a65", "#ff8a65" in shared)
print("no Oswald", "Oswald" not in shared)
print("no PLACEHOLDER", "PLACEHOLDER" not in shared)
print("file names", list(files.keys()))
