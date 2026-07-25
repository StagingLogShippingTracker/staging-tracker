import json
from pathlib import Path

path = Path(
    r"C:\Users\Brice\.cursor\projects\c-Users-Brice-Downloads-staging-tracker"
    r"\agent-transcripts\e1dd3032-9483-4582-ac46-0041883e8c0a"
    r"\subagents\4749545e-5be1-4541-921b-aabde0582c3f.jsonl"
)
text = json.loads(path.read_text(encoding="utf-8").splitlines()[0])["message"][
    "content"
][0]["text"]
out = Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-email-preview\_agent_prompt.txt")
out.write_text(text, encoding="utf-8")
print("saved", len(text), "to", out)
for needle in [
    "#fbf9f5",
    "#121314",
    'width="150"',
    "LIGHT",
    "DARK",
    "<!DOCTYPE",
    "prefers-color-scheme",
]:
    print(repr(needle), text.find(needle), text.count(needle))

# Extract HTML blocks if present
import re

blocks = list(re.finditer(r"<!DOCTYPE html>.*?</html>", text, re.I | re.S))
print("html blocks", len(blocks))
for i, m in enumerate(blocks):
    chunk = m.group(0)
    dest = Path(
        rf"C:\Users\Brice\Downloads\staging-tracker\.tmp-email-preview\_ref_{i}.html"
    )
    dest.write_text(chunk, encoding="utf-8")
    print(i, "len", len(chunk), "fbf9f5" in chunk, "121314" in chunk, dest.name)
