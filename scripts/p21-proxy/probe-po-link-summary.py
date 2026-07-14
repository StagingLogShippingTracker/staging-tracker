#!/usr/bin/env python3
"""Load PO then try external_po_no as linked SO; also dump line DWs via TABPAGE_2 focus."""
from __future__ import annotations

import json
import ssl
import urllib.request
import urllib.error
from pathlib import Path

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


def ensure_session(ui, auth):
    st, _, _ = call(
        "POST",
        f"{ui}/api/ui/interactive/sessions",
        auth,
        {
            "SessionType": "Auto",
            "ResponseWindowHandlingEnabled": False,
            "ClientPlatformApp": "SLST-POLink",
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
                "ClientPlatformApp": "SLST-POLink",
                "SessionTimeout": 300,
            },
        )


def header_from_order(win):
    for b in (win or {}).get("Data") or []:
        if b.get("Name") != "order":
            continue
        cols = b.get("Columns") or []
        rows = b.get("Data") or []
        if not rows:
            return None
        row = rows[0]
        return {cols[i]: row[i] for i in range(min(len(cols), len(row)))}
    return None


def po_header(win):
    for b in (win or {}).get("Data") or []:
        if b.get("Name") != "tp_1_dw_1":
            continue
        cols = b.get("Columns") or []
        rows = b.get("Data") or []
        if not rows:
            return None
        row = rows[0]
        return {cols[i]: row[i] for i in range(min(len(cols), len(row)))}
    return None


def load_order(ui, auth, so):
    st, opened, _ = call("POST", f"{ui}/api/ui/interactive/v2/window", auth, {"ServiceName": "Order"})
    wid = opened["WindowId"]
    try:
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
        return header_from_order(win)
    finally:
        try:
            call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid, "ToolName": "Quick.Close"})
        except Exception:
            pass
        call("DELETE", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)


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
    ensure_session(ui, auth)

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
    _, win, _ = call("GET", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
    hdr = po_header(win)
    print("PO header", {k: hdr.get(k) for k in ("po_no", "vendor_name", "buyer_name", "external_po_no")} if hdr else None)

    try:
        call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid, "ToolName": "Quick.Close"})
    except Exception:
        pass
    call("DELETE", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)

    candidates = []
    if hdr and hdr.get("external_po_no"):
        candidates.append(str(hdr["external_po_no"]).strip())
    candidates.extend(["1289039"])

    results = {}
    for so in candidates:
        if not so:
            continue
        h = load_order(ui, auth, so)
        results[so] = None if not h else {k: h.get(k) for k in ("order_no", "customer_name", "po_no", "taker", "taker_name")}
        print("SO", so, results[so])

    call("DELETE", f"{ui}/api/ui/interactive/sessions", auth)
    (OUT / "po-link-summary.json").write_text(json.dumps({"po": hdr, "sos": results}, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
