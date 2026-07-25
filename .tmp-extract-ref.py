import json
from pathlib import Path

p = Path(
    r"C:\Users\Brice\.cursor\projects\c-Users-Brice-Downloads-staging-tracker"
    r"\agent-transcripts\e1dd3032-9483-4582-ac46-0041883e8c0a"
    r"\e1dd3032-9483-4582-ac46-0041883e8c0a.jsonl"
)
for i, line in enumerate(p.read_text(encoding="utf-8").splitlines()):
    obj = json.loads(line)
    if obj.get("role") != "user":
        continue
    msg = obj.get("message", {})
    content = msg.get("content", [])
    texts = []
    if isinstance(content, list):
        for c in content:
            if isinstance(c, dict) and c.get("type") == "text":
                texts.append(c.get("text", ""))
    elif isinstance(content, str):
        texts.append(content)
    text = "\n".join(texts)
    if "Light Mode:" in text and "fbf9f5" in text:
        out = Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-user-email-ref.txt")
        out.write_text(text, encoding="utf-8")
        print("wrote", out, "len", len(text), "line", i)
        for marker in [
            "Light Mode:",
            "Dark Mode:",
            'width="150"',
            "#fbf9f5",
            "#121314",
            "</html>",
        ]:
            print(marker, text.find(marker))
        # Split light/dark HTML blocks
        light_start = text.find("<!DOCTYPE html>", text.find("Light Mode:"))
        dark_marker = text.find("Dark Mode:")
        dark_start = text.find("<!DOCTYPE html>", dark_marker) if dark_marker >= 0 else -1
        if light_start >= 0:
            light_end = text.find("</html>", light_start)
            light_html = text[light_start : light_end + len("</html>")]
            Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-user-light.html").write_text(
                light_html, encoding="utf-8"
            )
            print("light html len", len(light_html))
        if dark_start >= 0:
            dark_end = text.find("</html>", dark_start)
            dark_html = text[dark_start : dark_end + len("</html>")]
            Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-user-dark.html").write_text(
                dark_html, encoding="utf-8"
            )
            print("dark html len", len(dark_html))
        break
else:
    print("not found")
