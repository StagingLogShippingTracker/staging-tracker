import json
import re
from pathlib import Path

base = Path(
    r"C:\Users\Brice\.cursor\projects\c-Users-Brice-Downloads-staging-tracker\agent-transcripts"
)
hits = []
for p in base.rglob("*.jsonl"):
    try:
        for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
            if "#fbf9f5" in line or 'width=\\"150\\"' in line or 'width="150"' in line:
                hits.append(str(p))
                break
    except Exception as e:
        print("err", p, e)
print("files with tokens:", len(hits))
for h in hits:
    print(h)
