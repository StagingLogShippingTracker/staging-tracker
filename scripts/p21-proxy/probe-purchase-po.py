#!/usr/bin/env python3
"""Probe P21 Interactive / OData for purchase-order lookup (Report Carmen path).
Usage: py probe-purchase-po.py [PO]
Reads .env in this folder. Writes scripts/p21-proxy/_ui-map/po-probe-*.json
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

import urllib.request
import urllib.error
import ssl

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


def http_json(method: str, url: str, headers: dict, body=None, timeout=60):
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers = {**headers, "Content-Type": "application/json"}
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    ctx = ssl.create_default_context()
    if os.environ.get("P21_TLS_REJECT_UNAUTHORIZED", "1") == "0":
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=timeout) as resp:
            text = resp.read().decode("utf-8", errors="replace")
            try:
                js = json.loads(text) if text else None
            except Exception:
                js = None
            return resp.status, js, text[:4000]
    except urllib.error.HTTPError as e:
        text = e.read().decode("utf-8", errors="replace")
        try:
            js = json.loads(text) if text else None
        except Exception:
            js = None
        return e.code, js, text[:4000]


def get_token(base: str, user: str, password: str) -> str:
    st, js, text = http_json(
        "POST",
        f"{base}/api/security/token/v2",
        {"Accept": "application/json"},
        {"username": user, "password": password},
    )
    if st != 200 or not isinstance(js, dict):
        raise SystemExit(f"token failed {st}: {text[:300]}")
    tok = js.get("AccessToken") or js.get("access_token") or js.get("Token")
    if not tok:
        raise SystemExit(f"no token in response: {js}")
    return str(tok)


def main():
    env = load_env(ROOT / ".env")
    base = (env.get("P21_BASE_URL") or "https://swiftsupply-api.epicordistribution.com").rstrip("/")
    user = env.get("P21_USERNAME") or ""
    password = env.get("P21_PASSWORD") or ""
    po = str(sys.argv[1] if len(sys.argv) > 1 else "4276832").strip()
    if not user or not password:
        raise SystemExit("Missing P21_USERNAME/PASSWORD in .env")

    print("TOKEN…")
    token = get_token(base, user, password)
    auth = {"Accept": "application/json", "Authorization": f"Bearer {token}"}
    ui = f"{base}/uiserver0"
    results: dict = {"po": po, "base": base, "windows": [], "odata": [], "notes": []}

    # Session
    st, js, text = http_json(
        "POST",
        f"{ui}/api/ui/interactive/sessions",
        auth,
        {
            "SessionType": "Auto",
            "ResponseWindowHandlingEnabled": False,
            "ClientPlatformApp": "SLST-POProbe",
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
                "ClientPlatformApp": "SLST-POProbe",
                "SessionTimeout": 300,
            },
        )
    print("SESSION", st)
    results["session"] = {"status": st, "preview": (text or "")[:500]}

    service_names = [
        "PurchaseOrder",
        "Purchase Order",
        "PO",
        "PoHeader",
        "PurchaseOrderEntry",
        "Purchasing",
        "POEntry",
        "po_hdr",
        "Purchase",
        "Order",  # control
    ]

    for name in service_names:
        st, js, text = http_json(
            "POST",
            f"{ui}/api/ui/interactive/v2/window",
            auth,
            {"ServiceName": name},
        )
        wid = ""
        if isinstance(js, dict):
            wid = str(js.get("WindowId") or "")
        entry = {"ServiceName": name, "status": st, "WindowId": wid, "preview": (text or "")[:400]}
        print(f"WINDOW {name!r} -> {st} wid={wid or '-'}")
        if wid:
            # Try common PO field names
            http_json(
                "POST",
                f"{ui}/api/ui/interactive/v2/tools",
                auth,
                {"WindowId": wid, "ToolName": "Quick.Clear"},
            )
            for field in ("po_no", "purchase_order_no", "purchase_order_number", "document_no", "order_no"):
                stc, jsc, textc = http_json(
                    "PUT",
                    f"{ui}/api/ui/interactive/v2/change",
                    auth,
                    {
                        "WindowId": wid,
                        "List": [
                            {
                                "TabName": "Header",
                                "FieldName": field,
                                "Value": po,
                                "DatawindowName": "header",
                                "Row": 1,
                            }
                        ],
                    },
                )
                std, jsd, textd = http_json(
                    "GET", f"{ui}/api/ui/interactive/v2/data?id={wid}", auth
                )
                # Also try TabName Purchase / PO
                if stc >= 400 or not jsd:
                    for tab, dw in (("PO", "po"), ("Purchase", "purchase"), ("Order", "order"), ("Main", "main")):
                        stc2, _, _ = http_json(
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
                        std, jsd, textd = http_json(
                            "GET", f"{ui}/api/ui/interactive/v2/data?id={wid}", auth
                        )
                        if isinstance(jsd, dict) and jsd:
                            entry.setdefault("tries", []).append(
                                {"field": field, "tab": tab, "dw": dw, "change": stc2, "data_keys": list(jsd.keys())[:40]}
                            )
                            break
                else:
                    keys = list(jsd.keys())[:40] if isinstance(jsd, dict) else []
                    entry.setdefault("tries", []).append(
                        {"field": field, "tab": "Header", "dw": "header", "change": stc, "data_keys": keys}
                    )
                    # dump snippet if any row-like data
                    blob = json.dumps(jsd)[:1500]
                    if re.search(r"supplier|vendor|sales.?order|taker|customer", blob, re.I):
                        entry["hit_snippet"] = blob
                        print(f"  HIT field={field} keys={keys}")
                        break

            # Always dump data once
            std, jsd, textd = http_json("GET", f"{ui}/api/ui/interactive/v2/data?id={wid}", auth)
            sts, jss, texts = http_json("GET", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
            entry["data_status"] = std
            entry["state_status"] = sts
            if isinstance(jsd, dict):
                entry["data_keys"] = list(jsd.keys())[:50]
                entry["data_snippet"] = json.dumps(jsd)[:2000]
            if isinstance(jss, dict):
                entry["state_snippet"] = json.dumps(jss)[:2000]

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
        results["windows"].append(entry)

    # OData view probes
    odata_paths = [
        f"/odataservice/odata/table/po_hdr?$filter=po_no eq '{po}'&$top=5",
        f"/odataservice/odata/table/p21_view_po_hdr?$filter=po_no eq '{po}'&$top=5",
        f"/odataservice/odata/view/p21_view_po_hdr?$filter=po_no eq '{po}'&$top=5",
        f"/odataservice/odata/table/purchase_order_hdr?$filter=po_no eq '{po}'&$top=5",
        f"/odataservice/odata/table/po_line?$filter=po_no eq '{po}'&$top=5",
        f"/odataservice/odata/table/oe_hdr?$filter=po_no eq '{po}'&$top=5",
        f"/api/entity/po_hdr?$filter=po_no eq '{po}'&$top=5",
    ]
    for path in odata_paths:
        st, js, text = http_json("GET", f"{base}{path}", auth)
        results["odata"].append({"path": path, "status": st, "preview": (text or "")[:500]})
        print(f"ODATA {st} {path}")

    # Cleanup session
    try:
        http_json("DELETE", f"{ui}/api/ui/interactive/sessions", auth)
    except Exception:
        pass

    out_path = OUT / f"po-probe-{po}.json"
    out_path.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print("WROTE", out_path)


if __name__ == "__main__":
    main()
