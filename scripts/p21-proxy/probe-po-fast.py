#!/usr/bin/env python3
"""Fast dump: open PurchaseOrder window, try po_no retrieve, write JSON."""
from __future__ import annotations

import json
import sys
from pathlib import Path
import ssl
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "_ui-map"
OUT.mkdir(exist_ok=True)


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


def dw_rows(data):
    blocks = data if isinstance(data, list) else (data or {}).get("Data") or []
    rows = []
    for block in blocks if isinstance(blocks, list) else []:
        if not isinstance(block, dict):
            continue
        cols = block.get("Columns") or []
        for row in block.get("Data") or []:
            d = {"_dw": block.get("Name")}
            for i, c in enumerate(cols):
                if i < len(row):
                    d[c] = row[i]
            rows.append(d)
    return rows


def main():
    env = load_env()
    base = env.get("P21_BASE_URL", "https://swiftsupply-api.epicordistribution.com").rstrip("/")
    po = sys.argv[1] if len(sys.argv) > 1 else "4276832"
    print("TOKEN", flush=True)
    st, js, text = call(
        "POST",
        f"{base}/api/security/token/v2",
        {"Accept": "application/json"},
        {"username": env["P21_USERNAME"], "password": env["P21_PASSWORD"]},
    )
    print("TOKEN_STATUS", st, flush=True)
    token = (js or {}).get("AccessToken")
    if not token:
        raise SystemExit(text[:500])
    auth = {"Accept": "application/json", "Authorization": f"Bearer {token}"}
    ui = f"{base}/uiserver0"

    print("SESSION", flush=True)
    st, _, text = call(
        "POST",
        f"{ui}/api/ui/interactive/sessions",
        auth,
        {
            "SessionType": "Auto",
            "ResponseWindowHandlingEnabled": False,
            "ClientPlatformApp": "SLST-POFast",
            "SessionTimeout": 300,
        },
    )
    if st == 409:
        call("DELETE", f"{ui}/api/ui/interactive/sessions", auth)
        st, _, text = call(
            "POST",
            f"{ui}/api/ui/interactive/sessions",
            auth,
            {
                "SessionType": "Auto",
                "ResponseWindowHandlingEnabled": False,
                "ClientPlatformApp": "SLST-POFast",
                "SessionTimeout": 300,
            },
        )
    print("SESSION_STATUS", st, flush=True)

    print("OPEN", flush=True)
    st, opened, text = call(
        "POST", f"{ui}/api/ui/interactive/v2/window", auth, {"ServiceName": "PurchaseOrder"}
    )
    wid = (opened or {}).get("WindowId")
    print("OPEN_STATUS", st, wid, flush=True)
    if not wid:
        raise SystemExit(text[:800])

    out = {"po": po, "wid": wid, "opened": opened}
    try:
        call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid, "ToolName": "Quick.Clear"})
        st, meta, _ = call("GET", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
        out["window_meta_status"] = st
        # Keep compact: names of datawindows + first columns
        meta_trim = {}
        if isinstance(meta, dict):
            meta_trim["keys"] = list(meta.keys())
            data = meta.get("Data")
            if isinstance(data, list):
                meta_trim["dw"] = [
                    {
                        "Name": b.get("Name"),
                        "Columns": (b.get("Columns") or [])[:80],
                        "row0": (b.get("Data") or [None])[0],
                    }
                    for b in data
                    if isinstance(b, dict)
                ][:40]
            elif isinstance(data, dict):
                meta_trim["Data_keys"] = list(data.keys())[:40]
        out["window_meta"] = meta_trim

        combos = [
            ("PurchaseOrder", "purchase_order", "po_no"),
            ("Purchase Order", "purchase_order", "po_no"),
            ("PO", "po", "po_no"),
            ("Header", "header", "po_no"),
            ("PurchaseOrder", "header", "po_no"),
            ("PurchaseOrder", "purchase_order", "purchase_order_no"),
            ("PurchaseOrder", "po_hdr", "po_no"),
            ("Main", "main", "po_no"),
            ("Order", "order", "po_no"),
            ("PurchaseOrder", "purchase_order", "order_no"),
        ]
        # Prefer datawindow names discovered from meta
        for b in (meta_trim.get("dw") or []):
            name = b.get("Name") or ""
            cols = b.get("Columns") or []
            for col in cols:
                cl = str(col).lower()
                if "po" in cl and ("no" in cl or "number" in cl or cl.endswith("_no")):
                    combos.insert(0, (name, name, col))
                    combos.insert(0, ("Header", name, col))
                    combos.insert(0, ("PurchaseOrder", name, col))

        # unique
        seen = set()
        uniq = []
        for c in combos:
            if c not in seen:
                seen.add(c)
                uniq.append(c)

        out["tries"] = []
        for tab, dw, field in uniq[:40]:
            print(f"TRY {tab}/{dw}/{field}", flush=True)
            stc, _, cht = call(
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
            std, data, _ = call("GET", f"{ui}/api/ui/interactive/v2/data?id={wid}", auth)
            rows = dw_rows(data)
            interesting = [
                r
                for r in rows
                if any(
                    str(r.get(k, "")).upper().find(x) >= 0
                    for k in r
                    for x in ("WEIR", "PHOENIX", "4276832", "1289039", "KARPIAK")
                )
                or any("supplier" in str(k).lower() or "vendor" in str(k).lower() or "sales" in str(k).lower() for k in r)
            ]
            try_rec = {
                "tab": tab,
                "dw": dw,
                "field": field,
                "change": stc,
                "change_preview": (cht or "")[:200],
                "data_status": std,
                "rows": len(rows),
                "sample": rows[:3],
                "interesting_n": len(interesting),
            }
            if interesting:
                try_rec["interesting"] = interesting[:5]
                print("HIT", flush=True)
                out["hit"] = try_rec
                out["all_rows"] = rows[:50]
                break
            out["tries"].append(try_rec)

        st, meta2, _ = call("GET", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
        out["final_window_dw"] = [
            {
                "Name": b.get("Name"),
                "Columns": b.get("Columns"),
                "rows": len(b.get("Data") or []),
                "row0": (b.get("Data") or [None])[0],
            }
            for b in ((meta2 or {}).get("Data") or [])
            if isinstance(b, dict)
        ][:40] if isinstance(meta2, dict) else None

    finally:
        try:
            call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid, "ToolName": "Quick.Close"})
        except Exception:
            pass
        try:
            call("DELETE", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
        except Exception:
            pass
        try:
            call("DELETE", f"{ui}/api/ui/interactive/sessions", auth)
        except Exception:
            pass

    path = OUT / f"po-fast-{po}.json"
    path.write_text(json.dumps(out, indent=2, default=str), encoding="utf-8")
    print("WROTE", path, flush=True)


if __name__ == "__main__":
    main()
