#!/usr/bin/env python3
"""Pick linked SO from commitment_schedule_detail Order transactions after PO load."""
from __future__ import annotations

import json
import ssl
import urllib.request
import urllib.error
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load_env():
    env = {}
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.strip().startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def call(method, url, headers, body=None):
    data = None
    h = dict(headers)
    if body is not None:
        data = json.dumps(body).encode()
        h["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, context=ssl.create_default_context(), timeout=90) as r:
            t = r.read().decode("utf-8", "replace")
            try:
                return r.status, json.loads(t) if t else None, t
            except Exception:
                return r.status, None, t
    except urllib.error.HTTPError as e:
        t = e.read().decode("utf-8", "replace")
        try:
            return e.code, json.loads(t) if t else None, t
        except Exception:
            return e.code, None, t


def main():
    env = load_env()
    base = env["P21_BASE_URL"].rstrip("/")
    po = "4276832"
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
            "ClientPlatformApp": "SLST-Commit",
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
                "ClientPlatformApp": "SLST-Commit",
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
    # activate commitment
    call(
        "PUT",
        f"{ui}/api/ui/interactive/v2/change",
        auth,
        {
            "WindowId": wid,
            "List": [
                {
                    "TabName": "COMMITMENT_SCHEDULE",
                    "FieldName": "po_no",
                    "Value": po,
                    "DatawindowName": "tp_1_dw_1",
                    "Row": 1,
                }
            ],
        },
    )
    _, win, _ = call("GET", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
    scores = defaultdict(float)
    for b in win.get("Data") or []:
        if b.get("Name") != "commitment_schedule_detail":
            continue
        cols = b.get("Columns") or []
        for row in b.get("Data") or []:
            d = {cols[i]: row[i] for i in range(min(len(cols), len(row)))}
            if str(d.get("trans_type") or "").lower() != "order":
                continue
            so = str(d.get("transaction_number") or "").strip()
            qty = float(d.get("allocated_qty") or 0)
            if so:
                scores[so] += qty
    print("scores", dict(scores))

    try:
        call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid, "ToolName": "Quick.Close"})
    except Exception:
        pass
    call("DELETE", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)

    ranked = sorted(scores.items(), key=lambda kv: -kv[1])
    for so, qty in ranked[:5]:
        st, opened, _ = call("POST", f"{ui}/api/ui/interactive/v2/window", auth, {"ServiceName": "Order"})
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
                        "TabName": "Order",
                        "FieldName": "order_no",
                        "Value": so,
                        "DatawindowName": "order",
                        "Row": 1,
                    }
                ],
            },
        )
        _, win, _ = call("GET", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
        hdr = None
        for b in win.get("Data") or []:
            if b.get("Name") == "order" and (b.get("Data") or []):
                cols = b.get("Columns") or []
                row = b["Data"][0]
                hdr = {cols[i]: row[i] for i in range(min(len(cols), len(row)))}
        print(
            so,
            qty,
            None
            if not hdr
            else {k: hdr.get(k) for k in ("order_no", "customer_name", "taker", "taker_name")},
        )
        try:
            call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid, "ToolName": "Quick.Close"})
        except Exception:
            pass
        call("DELETE", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)

    call("DELETE", f"{ui}/api/ui/interactive/sessions", auth)


if __name__ == "__main__":
    main()
