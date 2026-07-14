#!/usr/bin/env python3
"""After loading PO, activate tabs to find linked sales order fields."""
from __future__ import annotations

import json
import sys
from pathlib import Path
import ssl
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "_ui-map"


def load_env():
    env = {}
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.strip().startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def call(method, url, headers, body=None, timeout=120):
    data = None
    h = dict(headers)
    if body is not None:
        data = json.dumps(body).encode()
        h["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=timeout) as r:
            t = r.read().decode("utf-8", errors="replace")
            try:
                return r.status, json.loads(t) if t else None, t
            except Exception:
                return r.status, None, t
    except urllib.error.HTTPError as e:
        t = e.read().decode("utf-8", errors="replace")
        try:
            return e.code, json.loads(t) if t else None, t
        except Exception:
            return e.code, None, t


def all_blocks(payload):
    if isinstance(payload, dict) and isinstance(payload.get("Data"), list):
        return payload["Data"]
    return []


def main():
    env = load_env()
    base = env.get("P21_BASE_URL", "https://swiftsupply-api.epicordistribution.com").rstrip("/")
    po = sys.argv[1] if len(sys.argv) > 1 else "4276832"
    st, js, _ = call(
        "POST",
        f"{base}/api/security/token/v2",
        {"Accept": "application/json"},
        {"username": env["P21_USERNAME"], "password": env["P21_PASSWORD"]},
    )
    auth = {"Accept": "application/json", "Authorization": f"Bearer {js['AccessToken']}"}
    ui = f"{base}/uiserver0"
    st, _, _ = call(
        "POST",
        f"{ui}/api/ui/interactive/sessions",
        auth,
        {
            "SessionType": "Auto",
            "ResponseWindowHandlingEnabled": False,
            "ClientPlatformApp": "SLST-POTabsScan",
            "SessionTimeout": 300,
        },
    )
    if st == 409:
        call("DELETE", f"{ui}/api/ui/interactive/sessions", auth)
        call(
            "POST",
            f"{ui}/api/ui/interactive/sessions",
            auth,
            {
                "SessionType": "Auto",
                "ResponseWindowHandlingEnabled": False,
                "ClientPlatformApp": "SLST-POTabsScan",
                "SessionTimeout": 300,
            },
        )

    st, opened, _ = call(
        "POST", f"{ui}/api/ui/interactive/v2/window", auth, {"ServiceName": "PurchaseOrder"}
    )
    wid = opened["WindowId"]
    call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid, "ToolName": "Quick.Clear"})
    call(
        "PUT",
        f"{ui}/api/ui/interactive/v2/change",
        auth,
        {
            "WindowId": wid,
            "List": [
                {
                    "TabName": "DOCUMENT_LINK",
                    "FieldName": "po_no",
                    "Value": po,
                    "DatawindowName": "tp_1_dw_1",
                    "Row": 1,
                }
            ],
        },
    )

    tabs = [
        "TABPAGE_1",
        "TABPAGE_2",
        "TABPAGE_3",
        "TABPAGE_4",
        "TABPAGE_5",
        "TABPAGE_6",
        "TABPAGE_7",
        "TABPAGE_8",
        "TABPAGE_17",
        "TABPAGE_18",
        "TABPAGE_19",
        "TABPAGE_20",
        "DOCUMENT_LINK",
        "DOCUMENT_LINK_DETAIL",
        "PURCHASEHISTORY",
        "BACKORDERS",
        "SCHEDULE",
        "RELEASE_SCHEDULE",
        "COMMITMENT_SCHEDULE",
        "PROCESS_INFO",
        "ORDER_LINE_NOTES",
        "TABPAGE_ORDER_NOTES",
        "VENDOR_RFQ_LINE",
        "VENDOR_RFQ_HDR",
        "SHIP_TO",
        "TOTALS",
    ]

    found = []
    dw_summary = {}
    for tab in tabs:
        # Activate tab by changing focus via selecting tab — use SelectTab tool if available
        for tool in (f"SelectTab.{tab}", "SelectTab", tab):
            pass
        stc, jsc, textc = call(
            "PUT",
            f"{ui}/api/ui/interactive/v2/change",
            auth,
            {
                "WindowId": wid,
                "List": [
                    {
                        "TabName": tab,
                        "FieldName": "po_no",
                        "Value": po,
                        "DatawindowName": "tp_1_dw_1",
                        "Row": 1,
                    }
                ],
            },
        )
        stw, win, _ = call("GET", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
        blocks = all_blocks(win)
        for b in blocks:
            name = b.get("Name")
            cols = b.get("Columns") or []
            dw_summary.setdefault(name, cols)
            for row in b.get("Data") or []:
                mapped = {cols[i]: row[i] for i in range(min(len(cols), len(row)))}
                blob = json.dumps(mapped)
                if "1289039" in blob or any(
                    x in str(c).lower()
                    for c in cols
                    for x in ("sales_order", "oe_order", "order_no", "so_no", "customer_name", "taker")
                ):
                    # keep non-empty interesting
                    interesting = {
                        k: v
                        for k, v in mapped.items()
                        if v not in ("", None)
                        and (
                            any(
                                x in k.lower()
                                for x in (
                                    "order",
                                    "sales",
                                    "customer",
                                    "taker",
                                    "supplier",
                                    "vendor",
                                    "po_",
                                    "item",
                                )
                            )
                            or str(v) in ("1289039", po)
                            or "PHOENIX" in str(v).upper()
                            or "WEIR" in str(v).upper()
                        )
                    }
                    if interesting:
                        found.append({"tab": tab, "change": stc, "dw": name, "fields": interesting})
        print(f"tab={tab} change={stc} blocks={len(blocks)}", flush=True)

    # Also try tools related to links
    tool_results = []
    for tool in (
        "DocumentLinks",
        "ViewDocumentLinks",
        "Quick.Links",
        "Links",
        "RelatedDocuments",
        "PurchaseHistory",
    ):
        stt, jst, textt = call(
            "POST",
            f"{ui}/api/ui/interactive/v2/tools",
            auth,
            {"WindowId": wid, "ToolName": tool},
        )
        tool_results.append({"tool": tool, "status": stt, "preview": (textt or "")[:300]})
        if stt == 200:
            stw, win, _ = call("GET", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
            for b in all_blocks(win):
                cols = b.get("Columns") or []
                for row in b.get("Data") or []:
                    mapped = {cols[i]: row[i] for i in range(min(len(cols), len(row)))}
                    if "1289039" in json.dumps(mapped) or any("order" in c.lower() for c in cols):
                        found.append({"tool": tool, "dw": b.get("Name"), "sample": mapped})

    out = {
        "po": po,
        "dw_columns": dw_summary,
        "found": found,
        "tools": tool_results,
    }
    path = OUT / f"po-saleslink-{po}.json"
    path.write_text(json.dumps(out, indent=2, default=str), encoding="utf-8")
    print("FOUND", len(found), "WROTE", path, flush=True)
    for f in found[:20]:
        print(f, flush=True)

    try:
        call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid, "ToolName": "Quick.Close"})
    except Exception:
        pass
    call("DELETE", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
    call("DELETE", f"{ui}/api/ui/interactive/sessions", auth)


if __name__ == "__main__":
    main()
