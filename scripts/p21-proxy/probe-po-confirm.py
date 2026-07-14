#!/usr/bin/env python3
"""Confirm PO retrieve via PurchaseOrder + dump ALL datawindows after load."""
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


def dw_rows(payload):
    blocks = []
    if isinstance(payload, dict):
        if isinstance(payload.get("Data"), list):
            blocks = payload["Data"]
        elif isinstance(payload.get("Data"), dict) and isinstance(payload["Data"].get("Data"), list):
            blocks = payload["Data"]["Data"]
    elif isinstance(payload, list):
        blocks = payload
    rows = []
    for block in blocks:
        if not isinstance(block, dict):
            continue
        cols = block.get("Columns") or []
        for row in block.get("Data") or []:
            d = {"_dw": block.get("Name")}
            for i, c in enumerate(cols):
                if i < len(row):
                    d[c] = row[i]
            rows.append(d)
    return rows, [
        {"Name": b.get("Name"), "Columns": b.get("Columns"), "n": len(b.get("Data") or [])}
        for b in blocks
        if isinstance(b, dict)
    ]


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
    call(
        "POST",
        f"{ui}/api/ui/interactive/sessions",
        auth,
        {
            "SessionType": "Auto",
            "ResponseWindowHandlingEnabled": False,
            "ClientPlatformApp": "SLST-POConfirm",
            "SessionTimeout": 300,
        },
    )  # ignore 409 briefly
    st, _, _ = call(
        "POST",
        f"{ui}/api/ui/interactive/sessions",
        auth,
        {
            "SessionType": "Auto",
            "ResponseWindowHandlingEnabled": False,
            "ClientPlatformApp": "SLST-POConfirm",
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
                "ClientPlatformApp": "SLST-POConfirm",
                "SessionTimeout": 300,
            },
        )

    st, opened, _ = call(
        "POST", f"{ui}/api/ui/interactive/v2/window", auth, {"ServiceName": "PurchaseOrder"}
    )
    wid = opened["WindowId"]
    call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid, "ToolName": "Quick.Clear"})

    # Try several tab names that returned 200 or likely header tabs
    for tab in ("DOCUMENT_LINK", "TABPAGE_1", "TABPAGE_CONTACT", "PROCESS_INFO", "TOTALS", "SHIP_TO"):
        stc, _, cht = call(
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
        print("try", tab, stc, (cht or "")[:120], flush=True)
        if stc == 200:
            break

    std, data, _ = call("GET", f"{ui}/api/ui/interactive/v2/data?id={wid}", auth)
    stw, win, _ = call("GET", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
    rows_d, meta_d = dw_rows(data)
    rows_w, meta_w = dw_rows(win)

    # Prefer denser payload
    rows = rows_w if len(rows_w) >= len(rows_d) else rows_d
    meta = meta_w if len(meta_w) >= len(meta_d) else meta_d

    header = next((r for r in rows if r.get("_dw") == "tp_1_dw_1"), {})
    print("HEADER po", header.get("po_no"), "vendor", header.get("vendor_name"), flush=True)

    # Search all fields
    hits = []
    for r in rows:
        for k, v in r.items():
            if k.startswith("_"):
                continue
            kl = str(k).lower()
            vs = str(v or "")
            if any(x in kl for x in ("order", "sales", "taker", "customer", "supplier", "vendor", "so_")) or vs in (
                "1289039",
                "4276832",
            ) or "WEIR" in vs.upper() or "PHOENIX" in vs.upper() or "KARPIAK" in vs.upper():
                hits.append({"dw": r.get("_dw"), "k": k, "v": v})

    out = {
        "po": po,
        "header": header,
        "dw_meta": meta,
        "hits": hits,
        "row_count": len(rows),
        "all_rows_lite": [
            {k: v for k, v in r.items() if v not in ("", None) and k != "_internalrowindex"}
            for r in rows[:30]
        ],
    }
    path = OUT / f"po-confirm-{po}.json"
    path.write_text(json.dumps(out, indent=2, default=str), encoding="utf-8")
    print("hits", len(hits), "WROTE", path, flush=True)
    for h in hits[:40]:
        print(h, flush=True)

    try:
        call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid, "ToolName": "Quick.Close"})
    except Exception:
        pass
    call("DELETE", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
    call("DELETE", f"{ui}/api/ui/interactive/sessions", auth)


if __name__ == "__main__":
    main()
