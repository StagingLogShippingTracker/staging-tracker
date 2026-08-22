#!/usr/bin/env python3
"""Shared harness runner helpers for SLST improve loops."""

from __future__ import annotations

import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FLUTTER = ROOT / ".tools" / "flutter" / "bin" / (
    "flutter.bat" if sys.platform.startswith("win") else "flutter"
)


def flutter_bin() -> Path:
    if FLUTTER.is_file():
        return FLUTTER
    # Fall back to PATH flutter
    return Path("flutter")


def run_flutter_test(test_rel: str, *, cwd: Path | None = None, timeout_s: int = 600) -> tuple[bool, str]:
    flutter = flutter_bin()
    cmd = [str(flutter), "test", test_rel]
    work = cwd or ROOT
    try:
        r = subprocess.run(
            cmd,
            cwd=str(work),
            capture_output=True,
            text=True,
            timeout=timeout_s,
        )
        out = (r.stdout or "") + ("\n" + r.stderr if r.stderr else "")
        if r.returncode != 0:
            tail = "\n".join(out.strip().splitlines()[-60:])
            return False, f"flutter_test_exit_{r.returncode}\n{tail}"
        return True, "ok"
    except subprocess.TimeoutExpired:
        return False, "flutter_test_timeout"
    except Exception as e:
        return False, str(e)


def clamp01(x: float) -> float:
    return max(0.0, min(1.0, float(x)))


def speed_score(ms: float | None, budget: float) -> float:
    if ms is None:
        return 0.0
    if ms <= 0:
        return 1.0
    return clamp01(budget / max(ms, 1.0))


def write_run(
    *,
    domain: str,
    syn: Path,
    scored: dict,
    harness_ok: bool,
    harness_note: str,
    t0: float,
    top_n: int,
    next_msg: str,
) -> dict:
    from improve_loop_training import record_run_snapshot

    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    log = syn / "improve_log.jsonl"
    summary_path = syn / "improve_summary_latest.json"
    syn.mkdir(parents=True, exist_ok=True)

    cases = scored.get("cases") or []
    ok_rows = [c for c in cases if c.get("composite") is not None]

    with log.open("a", encoding="utf-8") as f:
        for row in ok_rows:
            f.write(
                json.dumps(
                    {
                        "run_id": run_id,
                        "ts": ts,
                        "case_id": row["case_id"],
                        "composite": row["composite"],
                        "metrics": row.get("metrics"),
                        "gates": row.get("gates"),
                        "duration_ms": row.get("duration_ms"),
                        "ok": row.get("ok"),
                    },
                    ensure_ascii=False,
                )
                + "\n"
            )
        if not ok_rows:
            f.write(
                json.dumps(
                    {
                        "run_id": run_id,
                        "ts": ts,
                        "ok": False,
                        "note": "no_scored_cases",
                        "harness_ok": harness_ok,
                        "harness_note": harness_note,
                    },
                    ensure_ascii=False,
                )
                + "\n"
            )

    worst = sorted(ok_rows, key=lambda r: r["composite"])[:top_n]
    best = sorted(ok_rows, key=lambda r: -r["composite"])[: min(5, top_n)]
    metric_fails: list[dict] = []
    for r in ok_rows:
        for m, v in (r.get("metrics") or {}).items():
            if isinstance(v, (int, float)) and v < 0.85:
                metric_fails.append(
                    {
                        "case_id": r["case_id"],
                        "metric": m,
                        "score": v,
                        "composite": r["composite"],
                    }
                )
    metric_fails.sort(key=lambda x: x["score"])

    summary = {
        "run_id": run_id,
        "ts": ts,
        "domain": domain,
        "ok": bool(scored.get("ok")),
        "harness_ok": harness_ok,
        "harness_note": harness_note,
        "n_cases": scored.get("n_cases"),
        "n_scored": scored.get("n_scored"),
        "mean_composite": scored.get("mean_composite"),
        "elapsed_s": round(time.time() - t0, 2),
        "gate_fails": scored.get("gate_fails") or [],
        "top_failures": [
            {
                "case_id": r["case_id"],
                "composite": r["composite"],
                "metrics": r.get("metrics"),
                "gates": r.get("gates"),
                "duration_ms": r.get("duration_ms"),
            }
            for r in worst
        ],
        "metric_hotspots": metric_fails[:15],
        "top_wins": [
            {"case_id": r["case_id"], "composite": r["composite"]} for r in best
        ],
        "notes": scored.get("notes") or [],
        "budgets_ms": scored.get("budgets_ms"),
        "log": str(log.relative_to(ROOT)).replace("\\", "/"),
        "next": next_msg,
    }
    record_run_snapshot(domain, summary)
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return summary
