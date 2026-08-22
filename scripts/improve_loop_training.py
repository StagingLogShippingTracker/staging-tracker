#!/usr/bin/env python3
"""Shared training memory for all SLST improve loops.

Each domain keeps `qa_*/synthetic/training_lessons.json`:
  - lessons[]: agent-curated durable learnings (never drop without reason)
  - run_snapshots[]: automatic appends from improve-loop runners (capped)

Agents append lessons after score-proven fixes:
  python scripts/improve_loop_training.py append-lesson notify \\
    --title "..." --lesson "..." --do-not-regress "..."
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Full product surface — every design, function, ops path, and connector.
DOMAINS = {
    "app": ROOT / "qa_app" / "synthetic",
    "notify": ROOT / "qa_notify" / "synthetic",
    "location": ROOT / "qa_location" / "synthetic",
    "ops": ROOT / "qa_ops" / "synthetic",
    "wear": ROOT / "qa_wear" / "synthetic",
    "update": ROOT / "qa_update" / "synthetic",
    "auth": ROOT / "qa_auth" / "synthetic",
    "scanner": ROOT / "qa_scanner" / "synthetic",
    "theme": ROOT / "qa_theme" / "synthetic",
    "contacts": ROOT / "qa_contacts" / "synthetic",
    "reports": ROOT / "qa_reports" / "synthetic",
    "make": ROOT / "qa_make" / "synthetic",
    "hygiene": ROOT / "qa_hygiene" / "synthetic",
}

MAX_RUN_SNAPSHOTS = 40


def lessons_path(domain: str) -> Path:
    if domain not in DOMAINS:
        raise KeyError(f"unknown domain {domain}; expected {sorted(DOMAINS)}")
    return DOMAINS[domain] / "training_lessons.json"


def _empty(domain: str) -> dict:
    return {
        "domain": domain,
        "version": 1,
        "purpose": (
            "Incremental training memory for this improve loop. "
            "Score → fix → re-score → keep lessons → expand cases. "
            "Covers every design element, function, operation, and "
            "third-party connector for this domain."
        ),
        "lessons": [],
        "run_snapshots": [],
        "updated_at": None,
    }


def load_lessons(domain: str) -> dict:
    path = lessons_path(domain)
    if not path.is_file():
        return _empty(domain)
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return _empty(domain)
    if not isinstance(data, dict):
        return _empty(domain)
    data.setdefault("domain", domain)
    data.setdefault("version", 1)
    data.setdefault("lessons", [])
    data.setdefault("run_snapshots", [])
    return data


def save_lessons(domain: str, data: dict) -> Path:
    path = lessons_path(domain)
    path.parent.mkdir(parents=True, exist_ok=True)
    data["domain"] = domain
    data["updated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    return path


def record_run_snapshot(domain: str, summary: dict) -> Path:
    data = load_lessons(domain)
    snap = {
        "ts": summary.get("ts")
        or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "run_id": summary.get("run_id"),
        "mean_composite": summary.get("mean_composite"),
        "ok": summary.get("ok", True),
        "top_failures": (summary.get("top_failures") or [])[:5],
        "gate_fails": summary.get("gate_fails") or [],
        "next": summary.get("next"),
    }
    if summary.get("metric_hotspots"):
        snap["metric_hotspots"] = summary["metric_hotspots"][:8]
    snaps = list(data.get("run_snapshots") or [])
    snaps.append(snap)
    data["run_snapshots"] = snaps[-MAX_RUN_SNAPSHOTS:]
    path = save_lessons(domain, data)
    summary["training_lessons"] = str(path.relative_to(ROOT)).replace("\\", "/")
    return path


def append_lesson(
    domain: str,
    *,
    title: str,
    lesson: str,
    do_not_regress: str | None = None,
    case_ids: list[str] | None = None,
    tags: list[str] | None = None,
) -> Path:
    data = load_lessons(domain)
    entry = {
        "id": datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"),
        "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "title": title.strip(),
        "lesson": lesson.strip(),
        "do_not_regress": (do_not_regress or "").strip() or None,
        "case_ids": case_ids or [],
        "tags": tags or [],
    }
    lessons = list(data.get("lessons") or [])
    lessons.append(entry)
    data["lessons"] = lessons
    return save_lessons(domain, data)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="SLST improve-loop training memory")
    sub = p.add_subparsers(dest="cmd", required=True)

    init_p = sub.add_parser("init", help="Ensure training_lessons.json exists")
    init_p.add_argument("domain", choices=sorted(DOMAINS) + ["all"])

    show_p = sub.add_parser("show", help="Print training_lessons.json")
    show_p.add_argument("domain", choices=sorted(DOMAINS))

    add_p = sub.add_parser("append-lesson", help="Append a durable lesson")
    add_p.add_argument("domain", choices=sorted(DOMAINS))
    add_p.add_argument("--title", required=True)
    add_p.add_argument("--lesson", required=True)
    add_p.add_argument("--do-not-regress", default="")
    add_p.add_argument("--case", action="append", default=[])
    add_p.add_argument("--tag", action="append", default=[])

    args = p.parse_args(argv)
    if args.cmd == "init":
        domains = sorted(DOMAINS) if args.domain == "all" else [args.domain]
        for d in domains:
            path = save_lessons(d, load_lessons(d))
            print(path)
        return 0
    if args.cmd == "show":
        print(json.dumps(load_lessons(args.domain), indent=2))
        return 0
    if args.cmd == "append-lesson":
        path = append_lesson(
            args.domain,
            title=args.title,
            lesson=args.lesson,
            do_not_regress=args.do_not_regress or None,
            case_ids=args.case,
            tags=args.tag,
        )
        print(path)
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
