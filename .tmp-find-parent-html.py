import json
import re
from pathlib import Path

p = Path(
    r"C:\Users\Brice\.cursor\projects\c-Users-Brice-Downloads-staging-tracker"
    r"\agent-transcripts\e1dd3032-9483-4582-ac46-0041883e8c0a"
    r"\e1dd3032-9483-4582-ac46-0041883e8c0a.jsonl"
)
out_dir = Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-email-preview")
for i, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines()):
    if "#fbf9f5" not in line and "width" not in line:
        continue
    obj = json.loads(line)
    role = obj.get("role")
    content = obj.get("message", {}).get("content", [])
    texts = []
    for c in content:
        if isinstance(c, dict) and c.get("type") == "text":
            texts.append(c.get("text", ""))
        elif isinstance(c, str):
            texts.append(c)
    text = "\n".join(texts)
    if "#fbf9f5" in text or 'width="150"' in text:
        dest = out_dir / f"_parent_msg_{i}.txt"
        dest.write_text(text, encoding="utf-8")
        print(i, role, "len", len(text), "doctype", text.count("<!DOCTYPE"), dest.name)
        blocks = list(re.finditer(r"<!DOCTYPE html>.*?</html>", text, re.I | re.S))
        print("  blocks", len(blocks))
        for j, m in enumerate(blocks):
            chunk = m.group(0)
            (out_dir / f"_parent_html_{i}_{j}.html").write_text(chunk, encoding="utf-8")
            print(" ", j, len(chunk), "#f1ece4" in chunk, "#141517" in chunk)
