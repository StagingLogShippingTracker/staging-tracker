#!/usr/bin/env python3
"""Retrieve one purchase order via Interactive ServiceName=PurchaseOrder."""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path
import ssl
import urllib.request
import urllib.error
import urllib.parse

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "_ui-map"
OUT.mkdir(exist_ok=True)


def load_env(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    if not path.exists():
        return env
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def http_json(method: str, url: str, headers: dict, body=None, timeout=90):
    data = None
    hdrs = dict(headers)
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        hdrs["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=hdrs, method=method)
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=timeout) as resp:
            text = resp.read().decode("utf-8", errors="replace")
            try:
                js = json.loads(text) if text else None
            except Exception:
                js = None
            return resp.status, js, text
    except urllib.error.HTTPError as e:
        text = e.read().decode("utf-8", errors="replace")
        try:
            js = json.loads(text) if text else None
        except Exception:
            js = None
        return e.code, js, text


def get_token(base: str, user: str, password: str) -> str:
    st, js, text = http_json(
        "POST",
        f"{base}/api/security/token/v2",
        {"Accept": "application/json"},
        {"username": user, "password": password},
    )
    if st != 200 or not isinstance(js, dict):
        raise SystemExit(f"token failed {st}: {text[:400]}")
    return str(js.get("AccessToken") or js.get("access_token") or js.get("Token"))


def parse_dws(payload):
    out = {}
    if not isinstance(payload, dict):
        return out
    # Common shapes: { Datawindows: [...] } or nested Data
    candidates = [payload]
    if isinstance(payload.get("Data"), dict):
        candidates.append(payload["Data"])
    for root in candidates:
        dws = root.get("Datawindows") or root.get("datawindows") or root.get("DataWindows")
        if isinstance(dws, list):
            for dw in dws:
                if not isinstance(dw, dict):
                    continue
                name = str(dw.get("Name") or dw.get("name") or "")
                rows = dw.get("Rows") or dw.get("rows") or dw.get("Data") or []
                if name:
                    out[name.lower()] = rows if isinstance(rows, list) else rows
        # Flat map of dw_name -> rows
        for k, v in root.items():
            if isinstance(v, list) and k.lower() not in ("datawindows",):
                out[k.lower()] = v
    return out


def main():
    env = load_env(ROOT / ".env")
    base = (env.get("P21_BASE_URL") or "https://swiftsupply-api.epicordistribution.com").rstrip("/")
    user = env["P21_USERNAME"]
    password = env["P21_PASSWORD"]
    po = str(sys.argv[1] if len(sys.argv) > 1 else "4276832").strip()
    token = get_token(base, user, password)
    auth = {"Accept": "application/json", "Authorization": f"Bearer {token}"}
    ui = f"{base}/uiserver0"
    log = {"po": po, "attempts": []}

    st, js, text = http_json(
        "POST",
        f"{ui}/api/ui/interactive/sessions",
        auth,
        {
            "SessionType": "Auto",
            "ResponseWindowHandlingEnabled": False,
            "ClientPlatformApp": "SLST-PORetrieve",
            "SessionTimeout": 300,
        },
    )
    if st == 409:
        http_json("DELETE", f"{ui}/api/ui/interactive/sessions", auth)
        st, js, text = http_json(
            "POST",
            f"{ui}/api/ui/interactive/sessions",
            auth,
            {
                "SessionType": "Auto",
                "ResponseWindowHandlingEnabled": False,
                "ClientPlatformApp": "SLST-PORetrieve",
                "SessionTimeout": 300,
            },
        )
    print("SESSION", st)

    st, js, text = http_json(
        "POST",
        f"{ui}/api/ui/interactive/v2/window",
        auth,
        {"ServiceName": "PurchaseOrder"},
    )
    wid = str((js or {}).get("WindowId") or "") if isinstance(js, dict) else ""
    print("OPEN PurchaseOrder", st, wid)
    if not wid:
        raise SystemExit(text[:800])

    try:
        http_json(
            "POST",
            f"{ui}/api/ui/interactive/v2/tools",
            auth,
            {"WindowId": wid, "ToolName": "Quick.Clear"},
        )

        # Dump initial metadata / window state for field names
        _, state0, _ = http_json("GET", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
        _, data0, _ = http_json("GET", f"{ui}/api/ui/interactive/v2/data?id={wid}", auth)
        log["initial_state"] = state0
        log["initial_data"] = data0
        log["initial_dws"] = parse_dws(data0) | parse_dws(
            state0.get("Data") if isinstance(state0, dict) else None
        )

        field_combos = []
        for dw in ("header", "po", "purchase", "purchase_order", "order", "main", "po_hdr"):
            for tab in ("Header", "PO", "Purchase", "Order", "Main", "General"):
                for field in (
                    "po_no",
                    "purchase_order_no",
                    "purchase_order_number",
                    "document_no",
                    "po_number",
                    "order_no",
                    "vendor_id",
                ):
                    field_combos.append((tab, dw, field))

        # Deduplicate preserving order
        seen = set()
        combos = []
        for c in field_combos:
            if c not in seen:
                seen.add(c)
                combos.append(c)

        best = None
        for tab, dw, field in combos:
            stc, jsc, textc = http_json(
                "PUT",
                f"{ui}/api/ui/interactive/v2/change",
                auth,
                {
                    "WindowId": wid,
                    "List": [
                        {
                            "TabName": tab,
                            "FieldName": field,
                            "Value": po,
                            "DatawindowName": dw,
                            "Row": 1,
                        }
                    ],
                },
            )
            _, data, _ = http_json("GET", f"{ui}/api/ui/interactive/v2/data?id={wid}", auth)
            _, state, _ = http_json("GET", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
            dws = parse_dws(data) | parse_dws(state.get("Data") if isinstance(state, dict) else None)
            blob = json.dumps(dws)[:5000]
            interesting = any(
                k in blob.lower()
                for k in ("supplier", "vendor", "sales_order", "order_no", "taker", "4276832", "weir", "phoenix")
            )
            rec = {
                "tab": tab,
                "dw": dw,
                "field": field,
                "change_status": stc,
                "change_preview": (textc or "")[:300],
                "dw_names": list(dws.keys())[:40],
                "interesting": interesting,
            }
            if interesting:
                rec["snippet"] = blob[:2500]
                print("HIT", tab, dw, field, "status", stc, "dws", list(dws.keys())[:20])
                best = rec
                log["hit_data"] = data
                log["hit_state"] = state
                log["hit_dws"] = {k: (v[:2] if isinstance(v, list) else v) for k, v in dws.items()}
                break
            # Still log successful 200 changes with any rows
            if stc == 200 and dws:
                rows_n = sum(len(v) if isinstance(v, list) else 0 for v in dws.values())
                if rows_n:
                    rec["rows_n"] = rows_n
                    rec["snippet"] = blob[:1200]
                    log["attempts"].append(rec)
                    print("DATA", tab, dw, field, "rows", rows_n, list(dws.keys())[:15])
            else:
                if stc not in (400, 404) and len(log["attempts"]) < 30:
                    log["attempts"].append(rec)

            if len(log["attempts"]) > 80:
                break

        if best:
            log["best"] = best

        # Also try tools Retrieve if available
        for tool in ("Retrieve", "Quick.Retrieve", "File.Retrieve", "Edit.Retrieve"):
            stt, jst, textt = http_json(
                "POST",
                f"{ui}/api/ui/interactive/v2/tools",
                auth,
                {"WindowId": wid, "ToolName": tool},
            )
            log.setdefault("tools", []).append({"tool": tool, "status": stt, "preview": (textt or "")[:200]})

    finally:
        try:
            http_json(
                "POST",
                f"{ui}/api/ui/interactive/v2/tools",
                auth,
                {"WindowId": wid, "ToolName": "Quick.Close"},
            )
        except Exception:
            pass
        try:
            http_json("DELETE", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
        except Exception:
            pass
        try:
            http_json("DELETE", f"{ui}/api/ui/interactive/sessions", auth)
        except Exception:
            pass

    out = OUT / f"po-retrieve-{po}.json"
    # avoid huge dumps
    def trim(obj, depth=0):
        if depth > 6:
            return "…"
        if isinstance(obj, dict):
            return {k: trim(v, depth + 1) for k, v in list(obj.items())[:80]}
        if isinstance(obj, list):
            return [trim(x, depth + 1) for x in obj[:5]]
        if isinstance(obj, str) and len(obj) > 2000:
            return obj[:2000] + "…"
        return obj

    out.write_text(json.dumps(trim(log), indent=2), encoding="utf-8")
    print("WROTE", out)


if __name__ == "__main__":
    main()
