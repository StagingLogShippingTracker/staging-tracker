import base64
import json
from pathlib import Path

d = json.loads(Path(".tmp-notify-pm-deploy-files.json").read_text(encoding="utf-8"))
for f in d["files"]:
    assert "LOAD_FROM_DISK" not in f["content"]
    assert "PLACEHOLDER" not in f["content"]
shared = next(f for f in d["files"] if "email-shared" in f["name"])
assert 'ASSET_VERSION = "20260725i"' in shared["content"]
assert 'const D_CARD = "#151515"' in shared["content"]
assert "Swift notification via" in shared["content"]
idx = next(f for f in d["files"] if f["name"] == "index.ts")
assert "Deno.serve" in idx["content"]
raw = json.dumps(d, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
Path(".tmp-args-b64.txt").write_text(base64.b64encode(raw).decode("ascii"), encoding="utf-8")
print("b64_bytes", Path(".tmp-args-b64.txt").stat().st_size)
print("ok")
