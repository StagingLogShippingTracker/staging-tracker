import json
from pathlib import Path

d = json.loads(Path(".tmp-mcp-final-args.json").read_text(encoding="utf-8"))
out = Path(".tmp-deploy-parts")
out.mkdir(exist_ok=True)
for f in d["files"]:
    p = out / f["name"].replace("/", "__")
    p.write_text(f["content"], encoding="utf-8")
    print(p.name, p.stat().st_size)
