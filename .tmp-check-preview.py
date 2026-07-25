from pathlib import Path

html = Path(
    r"C:\Users\Brice\Downloads\staging-tracker\.tmp-email-preview\from-reference-light.html"
).read_text(encoding="utf-8")
print("width150", html.count('width="150"'))
print("max160", html.count("max-width: 160px"))
print("has250", 'width="250"' in html)
print("has32headline", "font-size: 32px" in html)
print("has24headline", "font-size: 24px; font-weight: 800" in html)
print("fbf9f5", "#fbf9f5" in html)
print("e65100", "#e65100" in html)
print("0288d1", "#0288d1" in html)
idx = 0
while True:
    i = html.find("260", idx)
    if i < 0:
        break
    print("260 ctx:", repr(html[max(0, i - 40) : i + 40]))
    idx = i + 1
