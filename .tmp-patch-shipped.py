from pathlib import Path

p = Path(r"C:\Users\Brice\Downloads\staging-tracker\lib\features\shared\log_tables.dart")
text = p.read_text(encoding="utf-8")
start = text.index("    return SectionCard(\n      title: 'Shipped Log',")
end = text.index(
    "// ---------------------------------------------------------------------------\n"
    "// Small sort dropdown used by both cards"
)
new_body = Path(
    r"C:\Users\Brice\Downloads\staging-tracker\.tmp-shipped-body.dart"
).read_text(encoding="utf-8")
p.write_text(text[:start] + new_body + text[end:], encoding="utf-8")
out = p.read_text(encoding="utf-8")
assert "_wrapWithViewToggle" not in out
assert "_logViewModeToggle(ref)" in out
assert "_buildShippedEntriesBody" in out
print("patched ok", len(out))
