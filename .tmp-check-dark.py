from pathlib import Path

d = Path(
    r"C:\Users\Brice\Downloads\staging-tracker\.tmp-email-preview\from-reference-dark.html"
).read_text(encoding="utf-8")
print("dark121314", "#121314" in d)
print("darkTitles", "#ff8a65" in d and "#4fc3f7" in d)
print("width150", d.count('width="150"'))
print("max160", d.count("max-width: 160px"))
print("size", d.__len__())
