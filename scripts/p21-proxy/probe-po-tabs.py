#!/usr/bin/env python3
"""PurchaseOrder retrieve with correct TabName from Definition."""
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


def extract_tabs(definition):
    tabs = []
    blob = json.dumps(definition) if definition else ""
    # Heuristic scan for "Name" near Tab
    if isinstance(definition, dict):
        def walk(o, path=""):
            if isinstance(o, dict):
                name = o.get("Name") or o.get("DisplayText") or o.get("Text")
                t = str(o.get("Type") or o.get("ControlType") or "").lower()
                if name and ("tab" in t or "tab" in path.lower()):
                    tabs.append(str(name))
                if name and str(name).lower() in ("header", "po", "lines", "general", "main"):
                    tabs.append(str(name))
                for k, v in o.items():
                    walk(v, path + "/" + str(k))
            elif isinstance(o, list):
                for i, v in enumerate(o[:200]):
                    walk(v, path + f"[{i}]")
        walk(definition)
    return sorted(set(tabs))


def main():
    env = load_env()
    base = env.get("P21_BASE_URL", "https://swiftsupply-api.epicordistribution.com").rstrip("/")
    po = sys.argv[1] if len(sys.argv) > 1 else "4276832"
    st, js, text = call(
        "POST",
        f"{base}/api/security/token/v2",
        {"Accept": "application/json"},
        {"username": env["P21_USERNAME"], "password": env["P21_PASSWORD"]},
    )
    token = (js or {}).get("AccessToken")
    auth = {"Accept": "application/json", "Authorization": f"Bearer {token}"}
    ui = f"{base}/uiserver0"
    print("token", st, flush=True)

    st, _, text = call(
        "POST",
        f"{ui}/api/ui/interactive/sessions",
        auth,
        {
            "SessionType": "Auto",
            "ResponseWindowHandlingEnabled": False,
            "ClientPlatformApp": "SLST-POTab",
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
                "ClientPlatformApp": "SLST-POTab",
                "SessionTimeout": 300,
            },
        )
    print("session ok", flush=True)

    st, opened, text = call(
        "POST", f"{ui}/api/ui/interactive/v2/window", auth, {"ServiceName": "PurchaseOrder"}
    )
    wid = (opened or {}).get("WindowId")
    print("open", st, wid, flush=True)
    out = {"po": po, "wid": wid}

    try:
        call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid, "ToolName": "Quick.Clear"})
        st, meta, _ = call("GET", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
        definition = (meta or {}).get("Definition") if isinstance(meta, dict) else None
        tabs = extract_tabs(definition)
        dws = []
        if isinstance(meta, dict) and isinstance(meta.get("Data"), list):
            for b in meta["Data"]:
                if isinstance(b, dict):
                    dws.append({"Name": b.get("Name"), "Columns": b.get("Columns")})
        out["tabs"] = tabs
        out["dws"] = dws
        print("TABS", tabs[:40], flush=True)
        print("DWS", [d["Name"] for d in dws], flush=True)

        # Save definition excerpt
        (OUT / f"po-def-{po}.json").write_text(
            json.dumps(definition, indent=2, default=str)[:500000], encoding="utf-8"
        )

        header_dw = "tp_1_dw_1"
        tab_candidates = tabs + [
            "",
            "tp_1",
            "Header",
            "General",
            "Main",
            "PO Header",
            "Purchase Order",
            "PurchaseOrder",
        ]
        # unique
        seen = set()
        tab_candidates = [t for t in tab_candidates if not (t in seen or seen.add(t))]

        out["tries"] = []
        for tab in tab_candidates[:30]:
            body_list = {
                "WindowId": wid,
                "List": [
                    {
                        "FieldName": "po_no",
                        "Value": po,
                        "DatawindowName": header_dw,
                        "Row": 1,
                        **({"TabName": tab} if tab else {}),
                    }
                ],
            }
            # Also try without TabName key entirely when tab empty
            if not tab:
                body_list["List"][0].pop("TabName", None)

            print(f"change tab={tab!r}", flush=True)
            stc, _, cht = call("PUT", f"{ui}/api/ui/interactive/v2/change", auth, body_list)
            std, data, _ = call("GET", f"{ui}/api/ui/interactive/v2/data?id={wid}", auth)
            rows = dw_rows(data)
            header = next((r for r in rows if r.get("_dw") == header_dw), None)
            po_val = (header or {}).get("po_no")
            vendor = (header or {}).get("vendor_name") or (header or {}).get("vendor_supplier_name")
            print(f"  status={stc} po_no={po_val!r} vendor={vendor!r} rows={len(rows)}", flush=True)
            rec = {
                "tab": tab,
                "change": stc,
                "preview": (cht or "")[:250],
                "po_no": po_val,
                "vendor_name": (header or {}).get("vendor_name"),
                "vendor_supplier_name": (header or {}).get("vendor_supplier_name"),
                "supplier_id": (header or {}).get("supplier_id"),
                "row_keys": list((header or {}).keys())[:50],
            }
            out["tries"].append(rec)
            if stc == 200 and str(po_val) == po:
                out["success"] = rec
                out["rows"] = rows
                # dump ALL dw columns that mention order/sales
                salesy = []
                for r in rows:
                    for k, v in r.items():
                        if k == "_dw":
                            continue
                        kl = k.lower()
                        if any(x in kl for x in ("order", "sales", "oe_", "so_", "taker", "customer")):
                            salesy.append({"dw": r.get("_dw"), "field": k, "value": v})
                out["sales_fields"] = salesy
                break

        # If no success, try Rowless vs Row 0
        if not out.get("success"):
            for row in (0, 1):
                for tab in ("", "Header"):
                    lst = {
                        "FieldName": "po_no",
                        "Value": po,
                        "DatawindowName": header_dw,
                        "Row": row,
                    }
                    if tab:
                        lst["TabName"] = tab
                    stc, _, cht = call(
                        "PUT",
                        f"{ui}/api/ui/interactive/v2/change",
                        auth,
                        {"WindowId": wid, "List": [lst]},
                    )
                    std, data, _ = call("GET", f"{ui}/api/ui/interactive/v2/data?id={wid}", auth)
                    rows = dw_rows(data)
                    header = next((r for r in rows if r.get("_dw") == header_dw), None)
                    print("alt", tab, row, stc, (header or {}).get("po_no"), flush=True)
                    if stc == 200 and str((header or {}).get("po_no")) == po:
                        out["success"] = {"tab": tab, "row": row, "header": header}
                        out["rows"] = rows
                        break
                if out.get("success"):
                    break

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

    path = OUT / f"po-tabs-{po}.json"
    path.write_text(json.dumps(out, indent=2, default=str)[:800000], encoding="utf-8")
    print("WROTE", path, flush=True)


if __name__ == "__main__":
    main()
