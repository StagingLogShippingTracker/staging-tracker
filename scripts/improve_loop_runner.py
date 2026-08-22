#!/usr/bin/env python3
"""Generic SLST improve-loop runner.

Usage:
  python scripts/improve_loop_runner.py app
  python scripts/improve_loop_runner.py make --skip-harness
  python scripts/improve_loop_runner.py all
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from _improve_loop_lib import run_flutter_test, write_run  # noqa: E402
from improve_score import score_all  # noqa: E402

# domain -> (test path relative to cwd, cwd relative to ROOT or None=ROOT, next_msg)
DOMAINS: dict[str, tuple[str, str | None, str]] = {
    "app": (
        "test/app_improve_loop_test.dart",
        None,
        "Read qa_app summary + training_lessons; fix shell/KPI/validation failures; expand UI cases.",
    ),
    "notify": (
        "test/notify_improve_loop_test.dart",
        None,
        "Read qa_notify summary; keep Make active; never embed webhook URL; expand attachment/alias cases.",
    ),
    "location": (
        "test/location_improve_loop_test.dart",
        None,
        "Read qa_location summary; keep map-first aisle/floor/shipping; expand zone matrix cases.",
    ),
    "ops": (
        "test/ops_improve_loop_test.dart",
        None,
        "Read qa_ops summary; fix container/status/split/consolidate failures; expand inventory edges.",
    ),
    "wear": (
        "test/wear_improve_loop_test.dart",
        "apps/wear",
        "Read qa_wear summary; fix pair/ship/verify/update Wear regressions.",
    ),
    "update": (
        "test/update_improve_loop_test.dart",
        None,
        "Read qa_update summary; preserve Setup.exe-only Windows Update; Wear≠Android assets.",
    ),
    "auth": (
        "test/auth_improve_loop_test.dart",
        None,
        "Read qa_auth summary; keep secrets out of clients; watch-pair create≠redeem contract.",
    ),
    "scanner": (
        "test/scanner_improve_loop_test.dart",
        None,
        "Read qa_scanner summary; expand OCR/document pipeline cases as scanner matures.",
    ),
    "theme": (
        "test/theme_improve_loop_test.dart",
        None,
        "Read qa_theme summary; protect brand names, status styles, pubspec brand assets.",
    ),
    "contacts": (
        "test/contacts_improve_loop_test.dart",
        None,
        "Read qa_contacts summary; roster remember + contacts.json integrity.",
    ),
    "reports": (
        "test/reports_improve_loop_test.dart",
        None,
        "Read qa_reports summary; SVR/audit/order-inspector parity with ops location order.",
    ),
    "make": (
        "scripts/make_improve_harness.py",  # python harness, not flutter
        None,
        "Read qa_make summary; keep scenario active; webhook secret server-side only; all types deliver.",
    ),
    "hygiene": (
        "scripts/repo_hygiene_improve_harness.py",
        None,
        "Read qa_hygiene summary; delete dead/legacy/scratch paths; keep .gitignore blocking re-commit.",
    ),
}


def run_domain(domain: str, *, skip_harness: bool, top_n: int) -> dict:
    if domain not in DOMAINS:
        raise SystemExit(f"unknown domain {domain}; expected {sorted(DOMAINS)}")
    test_rel, cwd_rel, next_msg = DOMAINS[domain]
    syn = ROOT / f"qa_{domain}" / "synthetic"
    syn.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    harness_ok, harness_note = True, "skipped"
    if not skip_harness:
        print(f"=== {domain} harness ===", flush=True)
        if test_rel.endswith(".py"):
            # Python harness (make, hygiene, …) — may mutate safe dead paths.
            r = __import__("subprocess").run(
                [sys.executable, str(ROOT / test_rel)],
                cwd=str(ROOT),
                capture_output=True,
                text=True,
                timeout=600,
            )
            out = (r.stdout or "") + ("\n" + r.stderr if r.stderr else "")
            harness_ok = r.returncode == 0
            harness_note = "ok" if harness_ok else out[-4000:]
            if harness_ok and out.strip():
                print(out.strip()[-2000:], flush=True)
        else:
            cwd = ROOT / cwd_rel if cwd_rel else ROOT
            harness_ok, harness_note = run_flutter_test(test_rel, cwd=cwd)
        print(harness_note if not harness_ok else "harness ok", flush=True)
        if not harness_ok:
            summary = {
                "ok": False,
                "domain": domain,
                "harness_ok": False,
                "harness_note": harness_note,
                "mean_composite": None,
                "top_failures": [],
                "gate_fails": [],
                "next": f"Fix {domain} harness errors, then re-run.",
            }
            (syn / "improve_summary_latest.json").write_text(
                json.dumps(summary, indent=2), encoding="utf-8"
            )
            return summary

    scored = score_all(domain, syn / "harness_results.json")
    return write_run(
        domain=domain,
        syn=syn,
        scored=scored,
        harness_ok=harness_ok,
        harness_note=harness_note,
        t0=t0,
        top_n=top_n,
        next_msg=next_msg,
    )


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("domain", help="domain name or 'all'")
    p.add_argument("--skip-harness", action="store_true")
    p.add_argument("--top", type=int, default=12)
    args = p.parse_args()
    domains = sorted(DOMAINS) if args.domain == "all" else [args.domain]
    worst_code = 0
    results = []
    for d in domains:
        summary = run_domain(d, skip_harness=args.skip_harness, top_n=args.top)
        results.append(
            {
                "domain": d,
                "ok": summary.get("ok"),
                "mean_composite": summary.get("mean_composite"),
                "gate_fails": summary.get("gate_fails"),
            }
        )
        if not summary.get("ok"):
            worst_code = 1
    print(json.dumps(results if len(results) > 1 else results[0], indent=2))
    return worst_code


if __name__ == "__main__":
    raise SystemExit(main())
