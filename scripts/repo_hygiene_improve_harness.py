#!/usr/bin/env python3
"""Repo hygiene improve harness + auto-cleanup.

Finds dead / legacy / scratch / fragmented paths that waste disk (and would
bloat GitHub if committed), deletes them, and writes:

  qa_hygiene/synthetic/harness_results.json
  qa_hygiene/synthetic/last_cleanup.json

Safe auto-delete only — never touches protected product trees.
"""

from __future__ import annotations

import json
import re
import shutil
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SYN = ROOT / "qa_hygiene" / "synthetic"

# Never auto-delete these top-level product trees.
PROTECTED_TOP = {
    ".cursor",
    ".git",
    ".github",
    ".tools",  # local flutter bootstrap — not on GitHub, keep for builds
    "android",
    "apps",
    "assets",
    "brand",
    "docs",
    "integration_test",
    "lib",
    "packages",
    "scripts",
    "supabase",
    "test",
    "third_party",
    "windows",
    "qa_app",
    "qa_auth",
    "qa_contacts",
    "qa_hygiene",
    "qa_location",
    "qa_make",
    "qa_notify",
    "qa_ops",
    "qa_reports",
    "qa_scanner",
    "qa_theme",
    "qa_update",
    "qa_wear",
}

# Name patterns safe to wipe at repo root (dirs or files).
SAFE_ROOT_PATTERNS = [
    re.compile(r"^_legacy", re.I),
    re.compile(r"^legacy[-_]", re.I),
    re.compile(r"^\.tmp-"),
    re.compile(r"^_mcp_deploy$"),
    re.compile(r"^_mcp_.*\.json$"),
    re.compile(r"^_deploy_args\.json$"),
    re.compile(r"^_ops_backup"),
    re.compile(r"^_wear_home"),
    re.compile(r"^_notify_pm"),
    re.compile(r"^dist-native-log\.txt$"),
    re.compile(r"^flutter_.*\.log$"),
]

# Nested junk patterns (relative path posix) — only under non-protected leaves
# or anywhere matching explicit scratch markers.
SAFE_NESTED_PATTERNS = [
    re.compile(r"(^|/)_legacy[^/]*($|/)"),
    re.compile(r"(^|/)\.tmp-[^/]+($|/)"),
]


def _posix(p: Path) -> str:
    return p.as_posix()


def _is_safe_root_name(name: str) -> bool:
    return any(rx.search(name) for rx in SAFE_ROOT_PATTERNS)


def _path_size(path: Path) -> tuple[int, int]:
    if path.is_file():
        try:
            return 1, path.stat().st_size
        except OSError:
            return 0, 0
    files = 0
    bytes_ = 0
    try:
        for f in path.rglob("*"):
            if f.is_file():
                files += 1
                try:
                    bytes_ += f.stat().st_size
                except OSError:
                    pass
    except OSError:
        pass
    return files, bytes_


def discover_candidates() -> list[dict]:
    found: list[dict] = []
    for child in ROOT.iterdir():
        name = child.name
        if name in PROTECTED_TOP:
            continue
        if _is_safe_root_name(name):
            n, b = _path_size(child)
            found.append(
                {
                    "path": name,
                    "kind": "dir" if child.is_dir() else "file",
                    "files": n,
                    "bytes": b,
                    "reason": "safe_root_pattern",
                }
            )
    return found


def delete_path(rel: str) -> dict:
    target = ROOT / rel
    if not target.exists():
        return {"path": rel, "deleted": False, "note": "already_gone"}
    top = Path(rel).parts[0] if Path(rel).parts else ""
    if top in PROTECTED_TOP and not _is_safe_root_name(top):
        return {"path": rel, "deleted": False, "note": "protected"}
    n, b = _path_size(target)
    try:
        _force_remove(target)
        gone = not target.exists()
        return {
            "path": rel,
            "deleted": gone,
            "files_removed": n if gone else 0,
            "bytes_removed": b if gone else 0,
            **({} if gone else {"note": "still_exists_after_remove"}),
        }
    except Exception as e:
        return {"path": rel, "deleted": False, "note": str(e), "files": n, "bytes": b}


def _force_remove(target: Path) -> None:
    """Remove files/dirs, including Windows MAX_PATH / broken Flutter trees."""
    import subprocess
    import sys

    if target.is_file() or target.is_symlink():
        try:
            target.unlink()
        except OSError:
            if sys.platform.startswith("win"):
                long = "\\\\?\\" + str(target.resolve())
                Path(long).unlink(missing_ok=True)  # type: ignore[arg-type]
            else:
                raise
        return

    # Prefer robocopy mirror-wipe on Windows (handles long paths better than rmtree).
    if sys.platform.startswith("win") and target.is_dir():
        empty = ROOT / ".tmp-hygiene-empty"
        try:
            if empty.exists():
                shutil.rmtree(empty, ignore_errors=True)
            empty.mkdir(parents=True, exist_ok=True)
            # Robocopy exit codes 0–7 mean copy/mirror completed with/without extras.
            subprocess.run(
                [
                    "robocopy",
                    str(empty),
                    str(target),
                    "/MIR",
                    "/R:1",
                    "/W:1",
                    "/NFL",
                    "/NDL",
                    "/NJH",
                    "/NJS",
                    "/NC",
                    "/NS",
                ],
                cwd=str(ROOT),
                capture_output=True,
                text=True,
                timeout=1800,
                check=False,
            )
            try:
                target.rmdir()
            except OSError:
                subprocess.run(
                    ["cmd", "/c", "rmdir", "/s", "/q", str(target)],
                    cwd=str(ROOT),
                    capture_output=True,
                    text=True,
                    timeout=600,
                    check=False,
                )
        finally:
            shutil.rmtree(empty, ignore_errors=True)
        if not target.exists():
            return

    # Fallback: shutil with long-path prefix on Windows.
    try:
        shutil.rmtree(target)
    except OSError:
        if sys.platform.startswith("win"):
            long = "\\\\?\\" + str(target.resolve())
            shutil.rmtree(long, ignore_errors=True)
        else:
            raise


def ensure_gitignore() -> list[str]:
    """Ensure dead-path patterns stay ignored so they never hit GitHub."""
    gi = ROOT / ".gitignore"
    text = gi.read_text(encoding="utf-8") if gi.is_file() else ""
    needed = [
        "# Dead / legacy / agent scratch (hygiene improve loop)",
        "_legacy*/",
        "legacy-*/",
        "dist-native-log.txt",
        "flutter_*.log",
    ]
    added: list[str] = []
    lines = text.splitlines()
    for item in needed:
        if item.startswith("#"):
            if item not in lines:
                lines.append(item)
                added.append(item)
            continue
        # Exact or already covered
        if any(l.strip() == item for l in lines):
            continue
        lines.append(item)
        added.append(item)
    # Ensure .tmp-* and _mcp_deploy remain
    for item in [".tmp-*", "_mcp_deploy/", "_mcp_*.json"]:
        if not any(l.strip() == item for l in lines):
            lines.append(item)
            added.append(item)
    if added:
        gi.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    return added


def _timed(case_id: str, ok: bool, *, metrics=None, gates=None, error=None, t0=None):
    return {
        "case_id": case_id,
        "ok": ok,
        "duration_ms": int((time.time() - (t0 or time.time())) * 1000),
        **({"metrics_raw": metrics} if metrics else {}),
        **({"gates_raw": gates} if gates else {}),
        **({"error": error} if error else {}),
    }


def main() -> int:
    SYN.mkdir(parents=True, exist_ok=True)
    cases: list[dict] = []
    notes: list[str] = []

    t0 = time.time()
    before = discover_candidates()
    deleted: list[dict] = []
    for c in before:
        deleted.append(delete_path(c["path"]))
    after = discover_candidates()
    bytes_freed = sum(d.get("bytes_removed", 0) for d in deleted if d.get("deleted"))
    files_freed = sum(d.get("files_removed", 0) for d in deleted if d.get("deleted"))
    failed_deletes = [d for d in deleted if not d.get("deleted") and d.get("note") != "already_gone"]

    cases.append(
        _timed(
            "auto_delete_safe_dead_paths",
            len(failed_deletes) == 0,
            metrics={
                "integrity": len(failed_deletes) == 0,
                "coverage": 1.0 if not after else max(0.0, 1.0 - len(after) / max(len(before), 1)),
            },
            gates={"delete_errors_zero": len(failed_deletes) == 0},
            error=None if not failed_deletes else json.dumps(failed_deletes[:5]),
            t0=t0,
        )
    )

    t0 = time.time()
    cases.append(
        _timed(
            "no_remaining_safe_dead_roots",
            len(after) == 0,
            gates={"clean_roots": len(after) == 0},
            error=None if not after else json.dumps(after[:10]),
            t0=t0,
        )
    )

    t0 = time.time()
    gi_added = ensure_gitignore()
    gi_text = (ROOT / ".gitignore").read_text(encoding="utf-8")
    ignore_ok = "_legacy" in gi_text and ".tmp-*" in gi_text and "_mcp_deploy" in gi_text
    cases.append(
        _timed(
            "gitignore_blocks_dead_patterns",
            ignore_ok,
            gates={"legacy_ignored": "_legacy" in gi_text, "tmp_ignored": ".tmp-*" in gi_text},
            t0=t0,
        )
    )

    t0 = time.time()
    # Protected trees must still exist
    missing_protected = [n for n in ("lib", "packages", "apps", "supabase", "scripts") if not (ROOT / n).exists()]
    cases.append(
        _timed(
            "protected_trees_intact",
            len(missing_protected) == 0,
            gates={"protected_ok": len(missing_protected) == 0},
            error=None if not missing_protected else str(missing_protected),
            t0=t0,
        )
    )

    t0 = time.time()
    # No second full-repo mirror (common storage killer)
    mirror_hits = []
    for child in ROOT.iterdir():
        if not child.is_dir():
            continue
        if child.name in PROTECTED_TOP or child.name.startswith("."):
            continue
        if (child / "pubspec.yaml").is_file() and (child / "lib").is_dir() and (child / "android").is_dir():
            mirror_hits.append(child.name)
    cases.append(
        _timed(
            "no_nested_full_repo_mirror",
            len(mirror_hits) == 0,
            gates={"no_mirror": len(mirror_hits) == 0},
            error=None if not mirror_hits else str(mirror_hits),
            t0=t0,
        )
    )

    cleanup = {
        "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "before": before,
        "deleted": deleted,
        "after": after,
        "bytes_freed": bytes_freed,
        "files_freed": files_freed,
        "gitignore_added": gi_added,
    }
    (SYN / "last_cleanup.json").write_text(json.dumps(cleanup, indent=2), encoding="utf-8")

    notes.append(f"freed_files={files_freed} freed_bytes={bytes_freed}")
    if before:
        notes.append(f"candidates_before={len(before)}")
    if gi_added:
        notes.append(f"gitignore_added={gi_added}")

    out = {
        "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "domain": "hygiene",
        "cases": cases,
        "notes": notes,
    }
    (SYN / "harness_results.json").write_text(json.dumps(out, indent=2), encoding="utf-8")
    failed = [c["case_id"] for c in cases if not c["ok"]]
    print(
        json.dumps(
            {
                "ok": not failed,
                "failed": failed,
                "bytes_freed": bytes_freed,
                "files_freed": files_freed,
                "deleted": [d["path"] for d in deleted if d.get("deleted")],
            },
            indent=2,
        )
    )
    return 0 if not failed else 1


if __name__ == "__main__":
    raise SystemExit(main())
