#!/usr/bin/env python3
"""Score qa_*/synthetic/harness_results.json → per-case composites (0–1)."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from _improve_loop_lib import clamp01, speed_score  # noqa: E402

# Per-domain budgets (ms). Gate-only cases omit speed weight via scoring.
BUDGETS = {
    "app": {
        "shared_validation_ship": 200,
        "shared_validation_po": 200,
        "shared_validation_return_notif": 200,
        "email_subject_casing": 200,
        "audit_location_order": 200,
        "kpi_math_smoke": 500,
        "router_shell_routes_complete": 300,
        "status_ui_to_db_roundtrip": 300,
        "status_urgency_weights": 300,
        "status_overdue_ymd": 300,
        "product_brand_constants": 200,
    },
    "notify": {
        "payload_keys_ship": 200,
        "payload_keys_quick_ship": 200,
        "payload_keys_return_to_stock": 200,
        "payload_keys_po": 200,
        "payload_keys_bulk_po": 200,
        "payload_keys_return": 200,
        "payload_keys_feedback": 200,
        "subject_uppercase_all_types": 300,
        "cc_required_contract": 200,
        "type_alias_coverage": 200,
        "no_make_webhook_in_flutter": 800,
        "feedback_to_warehouse2": 200,
        "warehouse_cc_default": 200,
    },
    "location": {
        "location_parse_aisle": 300,
        "location_category_filter": 500,
        "map_pick_mode_blocks_freetext": 300,
        "outside_tiles_ok": 300,
        "floor_zone_pickable_matrix": 400,
        "canonical_location_labels": 300,
        "b02_partial_supersedes_slots": 300,
        "partial_bay_conflict_skids_crates": 300,
        "drive_gap_bays_reserved": 300,
        "seeded_outside_no_freetext": 200,
        "classify_shipping_w2": 200,
    },
    "ops": {
        "container_counts_total": 300,
        "container_type_label": 300,
        "container_parse_mixed": 300,
        "container_add_commutative": 300,
        "ship_fields_reject_empty": 200,
        "return_fields_reject_empty": 200,
        "so_advisories_smoke": 500,
        "rpc_method_names_stable": 400,
        "consolidate_undo_window_2m": 200,
        "status_urgency_weights": 300,
    },
    "wear": {
        "wear_brand_title": 200,
        "wear_theme_dark_only": 200,
        "wear_ship_payload_cc": 200,
        "wear_ship_validation_empty_carrier": 200,
        "wear_update_platform_is_wear": 200,
        "wear_pair_redeem_six_digit": 200,
        "wear_verify_audit_order": 300,
    },
    "update": {
        "classify_windows_setup_exe": 200,
        "classify_windows_portable_zip": 200,
        "classify_android_apk": 200,
        "classify_wear_apk": 200,
        "wear_wins_over_android_token": 200,
        "generic_apk_unknown": 200,
        "windows_update_requires_setup_not_portable": 200,
        "android_never_reads_wear_url": 200,
        "wear_never_reads_android_url": 200,
        "github_latest_api_configured": 200,
        "denver_prompt_1500": 200,
        "snooze_three_days": 200,
    },
    "auth": {
        "no_service_role_in_clients": 800,
        "no_make_webhook_in_clients": 800,
        "watch_pair_create_redeem_split": 400,
        "watch_pair_six_digit_contract": 300,
        "rls_staging_select_authenticated": 400,
        "rls_writes_authenticated": 400,
        "app_config_anon_key_only": 200,
        "login_empty_field_messages": 300,
    },
    "scanner": {
        "scan_work_state_machine": 300,
        "document_corners_full_default": 200,
        "enhancement_enum_stable": 200,
        "ocr_result_model_fields": 300,
        "offline_ocr_service_constructs": 400,
        "scan_screen_exports": 400,
    },
    "theme": {
        "product_name_official": 200,
        "product_compact_name": 200,
        "theme_preference_modes": 300,
        "status_color_rush_distinct": 300,
        "no_bare_slst_product_title": 500,
    },
    "contacts": {
        "bundled_contacts_json_parses": 500,
        "contact_required_fields": 400,
        "roster_types_stable": 300,
        "contacts_asset_present": 200,
    },
    "reports": {
        "audit_location_order_box_before_aisle": 300,
        "audit_mode_enum_roundtrip": 200,
        "loc_key_priority_bands": 300,
        "wear_svr_same_comparator": 300,
    },
    "make": {
        "make_scenario_active_marker": 200,
        "make_webhook_not_in_clients": 800,
        "notify_pm_has_payload_builder": 400,
        "notify_pm_all_types_list": 400,
        "notify_pm_https_attachments": 400,
        "secret_server_side_only": 400,
        "outlook_cc_contract_documented": 300,
        "make_scenario_id_known": 200,
    },
    "hygiene": {
        "auto_delete_safe_dead_paths": 120000,
        "no_remaining_safe_dead_roots": 5000,
        "gitignore_blocks_dead_patterns": 500,
        "protected_trees_intact": 500,
        "no_nested_full_repo_mirror": 5000,
    },
}


def score_case(domain: str, row: dict) -> dict:
    case_id = str(row.get("case_id") or "unknown")
    ok = bool(row.get("ok"))
    ms = row.get("duration_ms")
    try:
        ms_f = float(ms) if ms is not None else None
    except (TypeError, ValueError):
        ms_f = None

    metrics: dict[str, float] = {"success": 1.0 if ok else 0.0}
    gates: dict[str, bool] = {"success": ok}
    raw_gates = row.get("gates_raw") or {}
    for k, v in raw_gates.items():
        gates[str(k)] = bool(v)
    all_gate = all(gates.values()) if gates else ok
    gates["all_ok"] = all_gate and ok

    budget = BUDGETS.get(domain, {}).get(case_id, 1000)
    metrics["speed"] = speed_score(ms_f, budget) if ok else 0.0

    raw = row.get("metrics_raw") or {}
    if "integrity" in raw:
        metrics["integrity"] = 1.0 if raw["integrity"] else 0.0
    if "coverage" in raw:
        try:
            metrics["coverage"] = clamp01(float(raw["coverage"]))
        except (TypeError, ValueError):
            metrics["coverage"] = 0.0

    if "coverage" in metrics:
        composite = (
            0.45 * metrics["success"]
            + 0.35 * metrics["coverage"]
            + 0.20 * metrics["speed"]
        )
    elif "integrity" in metrics:
        composite = (
            0.50 * metrics["success"]
            + 0.30 * metrics["integrity"]
            + 0.20 * metrics["speed"]
        )
    else:
        composite = 0.70 * metrics["success"] + 0.30 * metrics["speed"]

    if not all_gate:
        composite = min(composite, 0.49)

    return {
        "case_id": case_id,
        "ok": ok,
        "duration_ms": ms_f,
        "composite": round(composite, 4),
        "metrics": {k: round(v, 4) for k, v in metrics.items()},
        "gates": gates,
    }


def score_all(domain: str, results_path: Path) -> dict:
    if not results_path.is_file():
        return {
            "ok": False,
            "n_cases": 0,
            "n_scored": 0,
            "mean_composite": None,
            "cases": [],
            "gate_fails": [],
            "notes": [f"missing_results:{results_path}"],
            "budgets_ms": BUDGETS.get(domain, {}),
        }
    data = json.loads(results_path.read_text(encoding="utf-8"))
    rows = data.get("cases") if isinstance(data, dict) else data
    if not isinstance(rows, list):
        rows = []
    scored = [score_case(domain, r) for r in rows]
    comps = [c["composite"] for c in scored if c.get("composite") is not None]
    gate_fails = [
        c["case_id"]
        for c in scored
        if not (c.get("gates") or {}).get("all_ok", False)
    ]
    mean = round(sum(comps) / len(comps), 4) if comps else None
    notes = []
    if isinstance(data, dict):
        notes = list(data.get("notes") or [])
    return {
        "ok": bool(comps) and not gate_fails and (mean or 0) >= 0.85,
        "n_cases": len(rows),
        "n_scored": len(comps),
        "mean_composite": mean,
        "cases": scored,
        "gate_fails": gate_fails,
        "notes": notes,
        "budgets_ms": BUDGETS.get(domain, {}),
    }


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("domain", choices=sorted(BUDGETS))
    p.add_argument("--json", action="store_true")
    args = p.parse_args(argv)
    syn = ROOT / f"qa_{args.domain}" / "synthetic"
    scored = score_all(args.domain, syn / "harness_results.json")
    if args.json:
        print(json.dumps(scored, indent=2))
    else:
        print(
            f"{args.domain}: mean={scored.get('mean_composite')} "
            f"ok={scored.get('ok')} gates_fail={scored.get('gate_fails')}"
        )
    return 0 if scored.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
