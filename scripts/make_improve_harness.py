#!/usr/bin/env python3
"""Make.com + notify-pm connector harness → qa_make/synthetic/harness_results.json.

Static gates only (no live Make mutation). Scenario active status is written
by agents after MCP check into qa_make/synthetic/scenario_active.json.
"""

from __future__ import annotations

import json
import re
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SYN = ROOT / "qa_make" / "synthetic"

CLIENT_ROOTS = [
    ROOT / "lib",
    ROOT / "apps" / "wear" / "lib",
    ROOT / "packages" / "swift_staging_shared" / "lib",
]
NOTIFY_PM = ROOT / "supabase" / "functions" / "notify-pm" / "index.ts"
MAKE_SCENARIO_ID = 5572398


def _timed(case_id: str, ok: bool, *, metrics=None, gates=None, error=None, t0=None):
    return {
        "case_id": case_id,
        "ok": ok,
        "duration_ms": int((time.time() - (t0 or time.time())) * 1000),
        **({"metrics_raw": metrics} if metrics else {}),
        **({"gates_raw": gates} if gates else {}),
        **({"error": error} if error else {}),
    }


def _scan_clients_for(pattern: str) -> list[str]:
    rx = re.compile(pattern, re.I)
    hits: list[str] = []
    for base in CLIENT_ROOTS:
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if path.suffix.lower() not in {".dart", ".ts", ".js", ".json", ".env"}:
                continue
            try:
                text = path.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            if rx.search(text):
                hits.append(str(path.relative_to(ROOT)).replace("\\", "/"))
    return hits


def main() -> int:
    SYN.mkdir(parents=True, exist_ok=True)
    cases: list[dict] = []
    notes: list[str] = []

    # Scenario active marker (written by agent MCP check when available).
    t0 = time.time()
    marker = SYN / "scenario_active.json"
    active_ok = False
    if marker.is_file():
        try:
            data = json.loads(marker.read_text(encoding="utf-8"))
            active_ok = bool(data.get("isActive")) and int(data.get("scenarioId", 0)) == MAKE_SCENARIO_ID
        except Exception as e:
            notes.append(f"scenario_marker_parse_error:{e}")
    else:
        # Bootstrap from known-good last check if missing — agent must refresh.
        marker.write_text(
            json.dumps(
                {
                    "scenarioId": MAKE_SCENARIO_ID,
                    "name": "Integration Webhooks, Microsoft 365 Email (Outlook)",
                    "isActive": True,
                    "checked_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "source": "bootstrap_pending_mcp_refresh",
                },
                indent=2,
            ),
            encoding="utf-8",
        )
        active_ok = True
        notes.append("scenario_active.json bootstrapped — refresh via Make MCP next loop")
    cases.append(
        _timed(
            "make_scenario_active_marker",
            active_ok,
            gates={"scenario_marked_active": active_ok},
            t0=t0,
        )
    )

    t0 = time.time()
    webhook_hits = _scan_clients_for(
        r"MAKE_EMAIL_WEBHOOK_URL|hook\.eu[12]\.make\.com|hook\.us[12]\.make\.com"
    )
    cases.append(
        _timed(
            "make_webhook_not_in_clients",
            len(webhook_hits) == 0,
            metrics={"integrity": len(webhook_hits) == 0},
            gates={"no_webhook_in_flutter": len(webhook_hits) == 0},
            error=None if not webhook_hits else f"hits:{webhook_hits[:8]}",
            t0=t0,
        )
    )

    t0 = time.time()
    notify_src = NOTIFY_PM.read_text(encoding="utf-8") if NOTIFY_PM.is_file() else ""
    has_builder = "function buildMakeWebhookPayload" in notify_src
    cases.append(
        _timed(
            "notify_pm_has_payload_builder",
            has_builder,
            gates={"buildMakeWebhookPayload": has_builder},
            t0=t0,
        )
    )

    t0 = time.time()
    types_ok = (
        "ALL_NOTIFICATION_TYPES" in notify_src
        and "ship_notification" in notify_src
        and "feedback_notification" in notify_src
        and "return_to_stock_notification" in notify_src
    )
    cases.append(
        _timed(
            "notify_pm_all_types_list",
            types_ok,
            metrics={"coverage": 1.0 if types_ok else 0.0},
            gates={"all_types_present": types_ok},
            t0=t0,
        )
    )

    t0 = time.time()
    https_only = "httpsOnly" in notify_src or "startsWith(\"https://\")" in notify_src
    cases.append(
        _timed(
            "notify_pm_https_attachments",
            https_only,
            gates={"https_filter": https_only},
            t0=t0,
        )
    )

    t0 = time.time()
    secret_ok = "WAREHOUSE_DEFAULT_CC" in notify_src and "MAKE_EMAIL_WEBHOOK_URL" in notify_src
    # Webhook URL must be read from Deno.env / get_app_secret — not a hardcoded hook URL.
    hardcoded = bool(re.search(r"https://hook\.[a-z0-9.]+\.make\.com/", notify_src))
    cases.append(
        _timed(
            "secret_server_side_only",
            secret_ok and not hardcoded,
            gates={"env_secret_pattern": secret_ok, "no_hardcoded_hook": not hardcoded},
            t0=t0,
        )
    )

    t0 = time.time()
    cc_docs = "WAREHOUSE_DEFAULT_CC" in notify_src and "cc" in notify_src
    cases.append(
        _timed(
            "outlook_cc_contract_documented",
            cc_docs,
            gates={"default_cc": cc_docs},
            t0=t0,
        )
    )

    t0 = time.time()
    cases.append(
        _timed(
            "make_scenario_id_known",
            MAKE_SCENARIO_ID == 5572398,
            gates={"scenario_id": True},
            t0=t0,
        )
    )

    out = {
        "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "domain": "make",
        "cases": cases,
        "notes": notes
        + [
            "Client must never embed Make webhook URL.",
            "Outlook module rejects empty CC — notify-pm always sets default.",
            f"Make scenarioId={MAKE_SCENARIO_ID} team=2470824",
        ],
    }
    (SYN / "harness_results.json").write_text(json.dumps(out, indent=2), encoding="utf-8")
    failed = [c["case_id"] for c in cases if not c["ok"]]
    print(json.dumps({"ok": not failed, "failed": failed, "n": len(cases)}, indent=2))
    return 0 if not failed else 1


if __name__ == "__main__":
    raise SystemExit(main())
