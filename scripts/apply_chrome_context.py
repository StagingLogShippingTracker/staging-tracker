"""Rewrite hardcoded dark chrome tokens to theme-aware IndustrialTheme.chromeOf."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "lib"
SKIP = {ROOT / "core" / "theme.dart"}

REPLACEMENTS = [
    ("IndustrialTheme.darkBase", "IndustrialTheme.chromeOf(context).base"),
    ("IndustrialTheme.darkSurface", "IndustrialTheme.chromeOf(context).surface"),
    ("IndustrialTheme.darkHeader", "IndustrialTheme.chromeOf(context).header"),
    ("IndustrialTheme.textPrimary", "IndustrialTheme.chromeOf(context).ink"),
    ("IndustrialTheme.textMuted", "IndustrialTheme.chromeOf(context).muted"),
    ("IndustrialTheme.borderStroke", "IndustrialTheme.chromeOf(context).border"),
]


def strip_const(text: str) -> str:
    # Drop const on constructs that now reference context.
    for needle in (
        "const BoxDecoration(",
        "const BorderSide(",
        "const Divider(",
        "const ColoredBox(",
        "const TextStyle(",
        "const IconThemeData(",
        "const WidgetStatePropertyAll(",
    ):
        if "chromeOf(context)" in text:
            text = text.replace(needle, needle.replace("const ", ""))
    # Line-level: if chromeOf on the line, remove a leading const after indent.
    out = []
    for line in text.splitlines(True):
        if "chromeOf(context)" in line and "const " in line:
            line = line.replace("const ", "", 1)
        out.append(line)
    return "".join(out)


def main() -> None:
    for path in ROOT.rglob("*.dart"):
        if path in SKIP:
            continue
        original = path.read_text(encoding="utf-8")
        text = original
        for old, new in REPLACEMENTS:
            text = text.replace(old, new)
        if text == original:
            continue
        text = strip_const(text)
        path.write_text(text, encoding="utf-8")
        print("patched", path.relative_to(ROOT.parent))


if __name__ == "__main__":
    main()
