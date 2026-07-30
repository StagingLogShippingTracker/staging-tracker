"""Bulk-replace retired SST product branding with SLST."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {
    ".git",
    ".tools",
    "build",
    "dist",
    ".dart_tool",
    "node_modules",
    "ephemeral",
}
EXTS = {
    ".dart",
    ".ts",
    ".html",
    ".md",
    ".yaml",
    ".yml",
    ".xml",
    ".cpp",
    ".rc",
    ".iss",
    ".py",
    ".txt",
    ".mdc",
    ".json",
}

# Longer phrases first.
SUBS = [
    ("SLST", "SLST"),
    ("SLST", "SLST"),
    ("SLST", "SLST"),
    ("Sign in to SLST", "Sign in to SLST"),
    ("SLST Document Scanner", "SLST Document Scanner"),
    ("recorded in SLST", "recorded in SLST"),
    ("from SLST", "from SLST"),
    ("in SLST", "in SLST"),
    ("Launch SLST", "Launch SLST"),
    ("SLST Wear OS", "SLST Wear OS"),
    ("SLST is", "SLST is"),
    ("title: 'SLST'", "title: 'SLST'"),
    ('L"SLST"', 'L"SLST"'),
    ('android:label="SLST"', 'android:label="SLST"'),
    ("SLST", "SLST"),
    ("SLST-Setup-User.exe", "SLST-Setup-User.exe"),
    ("SLST-Windows-Portable.zip", "SLST-Windows-Portable.zip"),
    ("SLST-Android.apk", "SLST-Android.apk"),
    ("SLST-Wear.apk", "SLST-Wear.apk"),
    ("SLST-Windows-Portable", "SLST-Windows-Portable"),
    ("assets/slst-app-icon.png", "assets/slst-app-icon.png"),
    ("SLST_MARK_URL", "SLST_MARK_URL"),
    ("MyAppName", "MyAppName"),  # no-op placeholder kept for clarity
]


def main() -> None:
    changed: list[str] = []
    for path in ROOT.rglob("*"):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if not path.is_file() or path.suffix.lower() not in EXTS:
            continue
        if path.stat().st_size > 2_000_000:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except Exception:
            continue
        orig = text
        for old, new in SUBS:
            if old == new:
                continue
            text = text.replace(old, new)
        if text != orig:
            path.write_text(text, encoding="utf-8")
            changed.append(str(path.relative_to(ROOT)))
    print(f"updated {len(changed)} files")
    for rel in changed:
        print(" ", rel)


if __name__ == "__main__":
    main()
