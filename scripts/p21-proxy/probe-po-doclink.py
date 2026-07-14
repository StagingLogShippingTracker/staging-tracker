#!/usr/bin/env python3
"""Dump DOCUMENT_LINK_DETAIL / commitment DWs after PO load for linked SO."""
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


def session(ui, auth):
    st, _, _ = call(
        "POST",
        f"{ui}/api/ui/interactive/sessions",
        auth,
        {
            "SessionType": "Auto",
            "ResponseWindowHandlingEnabled": False,
            "ClientPlatformApp": "SLST-PODoc",
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
                "ClientPlatformApp": "SLST-PODoc",
                "SessionTimeout": 300,
            },
        )


def dump_blocks(payload):
    blocks = payload.get("Data") if isinstance(payload, dict) else None
    out = []
    if not isinstance(blocks, list):
        return out
    for b in blocks:
        if not isinstance(b, dict):
            continue
        cols = b.get("Columns") or []
        rows = []
        for row in b.get("Data") or []:
            rows.append({cols[i]: row[i] for i in range(min(len(cols), len(row)))})
        out.append({"Name": b.get("Name"), "Columns": cols, "rows": rows[:20], "n": len(b.get("Data") or [])})
    return out


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
    session(ui, auth)
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

    # Now specifically select DOCUMENT_LINK_DETAIL tab via change on a field there if possible
    # First dump window after load
    _, win0, _ = call("GET", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
    snaps = {"after_load": dump_blocks(win0)}

    for tab in ("DOCUMENT_LINK_DETAIL", "DOCUMENT_LINK", "COMMITMENT_SCHEDULE", "TABPAGE_2", "TABPAGE_3"):
        call(
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
        _, win, _ = call("GET", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
        snaps[tab] = dump_blocks(win)
        print(tab, [b["Name"] for b in snaps[tab]], [b["n"] for b in snaps[tab]], flush=True)

    # Try Order entry with customer po / purchase link: open second window?
    # Close PO and open Order, try po_no = 4276832
    try:
        call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid, "ToolName": "Quick.Close"})
    except Exception:
        pass
    call("DELETE", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)

    st, opened2, _ = call(
        "POST", f"{ui}/api/ui/interactive/v2/window", auth, {"ServiceName": "Order"}
    )
    wid2 = opened2["WindowId"]
    call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid2, "ToolName": "Quick.Clear"})
    for field in ("po_no", "customer_po_no", "order_no"):
        call(
            "PUT",
            f"{ui}/api/ui/interactive/v2/change",
            auth,
            {
                "WindowId": wid2,
                "List": [
                    {
                        "TabName": "Order",
                        "FieldName": field,
                        "Value": po,
                        "DatawindowName": "order",
                        "Row": 1,
                    }
                ],
            },
        )
        _, data, _ = call("GET", f"{ui}/api/ui/interactive/v2/data?id={wid2}", auth)
        blocks = dump_blocks(data if isinstance(data, dict) else {"Data": data})
        # Also from window
        _, win, _ = call("GET", f"{ui}/api/ui/interactive/v2/window?id={wid2}", auth)
        blocks2 = dump_blocks(win)
        order_rows = []
        for b in blocks2:
            for r in b["rows"]:
                if b["Name"] and "order" in str(b["Name"]).lower():
                    order_rows.append(r)
                elif r.get("order_no") or r.get("customer_name"):
                    order_rows.append(r)
        snaps[f"order_via_{field}"] = {
            "blocks": [{**b, "rows": b["rows"][:3]} for b in blocks2],
            "order_rows": order_rows[:5],
        }
        print("order via", field, "rows", len(order_rows), flush=True)
        if order_rows and (order_rows[0].get("order_no") or order_rows[0].get("customer_name")):
            break

    # Also try known linked SO directly
    call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid2, "ToolName": "Quick.Clear"})
    call(
        "PUT",
        f"{ui}/api/ui/interactive/v2/change",
        auth,
        {
            "WindowId": wid2,
            "List": [
                {
                    "TabName": "Order",
                    "FieldName": "order_no",
                    "Value": "1289039",
                    "DatawindowName": "order",
                    "Row": 1,
                }
            ],
        },
    )
    _, win, _ = call("GET", f"{ui}/api/ui/interactive/v2/window?id={wid2}", auth)
    blocks = dump_blocks(win)
    so_header = None
    for b in blocks:
        for r in b["rows"]:
            if str(r.get("order_no")) == "1289039" or r.get("customer_name"):
                so_header = r
                break
    snaps["so_1289039"] = so_header
    print("SO1289039", {k: so_header.get(k) for k in ("order_no", "customer_name", "po_no", "taker", "taker_name")} if so_header else None, flush=True)

    path = OUT / f"po-doclink-{po}.json"
    path.write_text(json.dumps(snaps, indent=2, default=str), encoding="utf-8")
    print("WROTE", path, flush=True)

    try:
        call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid2, "ToolName": "Quick.Close"})
    except Exception:
        pass
    call("DELETE", f"{ui}/api/ui/interactive/v2/window?id={wid2}", auth)
    call("DELETE", f"{ui}/api/ui/interactive/sessions", auth)


if __name__ == "__main__":
    main()
