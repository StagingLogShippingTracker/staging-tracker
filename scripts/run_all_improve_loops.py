#!/usr/bin/env python3
"""Run the full SLST improve-loop curriculum (all product surfaces).

Usage (repo root):
  python scripts/run_all_improve_loops.py
  python scripts/run_all_improve_loops.py --skip-harness
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from improve_loop_runner import DOMAINS, run_domain  # noqa: E402
from improve_loop_training import DOMAINS as TRAIN_DOMAINS  # noqa: E402
from improve_loop_training import save_lessons, load_lessons  # noqa: E402


def main() -> int:
    p = argparse.ArgumentParser(description="Run all SLST improve loops")
    p.add_argument("--skip-harness", action="store_true")
    p.add_argument("--top", type=int, default=12)
    p.add_argument(
        "--only",
        nargs="*",
        default=None,
        help="Optional subset of domains",
    )
    args = p.parse_args()

    # Ensure training memory exists for every domain.
    for d in TRAIN_DOMAINS:
        save_lessons(d, load_lessons(d))

    domains = args.only if args.only else sorted(DOMAINS)
    results = []
    worst = 0
    for d in domains:
        print(f"\n######## {d} ########", flush=True)
        summary = run_domain(d, skip_harness=args.skip_harness, top_n=args.top)
        row = {
            "domain": d,
            "ok": summary.get("ok"),
            "mean_composite": summary.get("mean_composite"),
            "n_cases": summary.get("n_cases"),
            "gate_fails": summary.get("gate_fails"),
            "harness_ok": summary.get("harness_ok"),
        }
        results.append(row)
        if not summary.get("ok"):
            worst = 1

    out = {
        "ok": worst == 0,
        "n_domains": len(results),
        "n_passed": sum(1 for r in results if r.get("ok")),
        "domains": results,
    }
    rollup = ROOT / "qa_app" / "synthetic" / "improve_all_latest.json"
    rollup.parent.mkdir(parents=True, exist_ok=True)
    rollup.write_text(json.dumps(out, indent=2), encoding="utf-8")
    print(json.dumps(out, indent=2))
    return worst


if __name__ == "__main__":
    raise SystemExit(main())
