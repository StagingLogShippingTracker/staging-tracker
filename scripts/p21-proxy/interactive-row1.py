"""
Try Row=1 change + inquiry.transaction to load an SO.
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path
from urllib import request as urlrequest

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
OUT = HERE / "_ui-map"
API = "https://swiftsupply-api.epicordistribution.com/uiserver0"
UI = "https://swiftsupply.epicordistribution.com/Prophet21/#/"


def load_env():
    env = {}
    for line in (HERE / ".env").read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip() or line.strip().startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def login_token(page, user, password):
    captured = []

    def on_resp(res):
        if "token/v2" in res.url and res.status == 200:
            try:
                captured.append(res.json())
            except Exception:
                pass

    page.on("response", on_resp)
    page.goto(UI, wait_until="domcontentloaded", timeout=90_000)
    page.wait_for_timeout(2000)
    page.locator('input[name="username"]').first.fill(user)
    page.locator("#txtPassword, input[type='password']").first.fill(password)
    page.locator("#loginButton").first.click()
    page.wait_for_timeout(6000)
    for c in captured:
        if c.get("AccessToken"):
            return c["AccessToken"]
    raise RuntimeError("No AccessToken")


def call(ctx, method, path, headers, body=None):
    url = API + path
    kwargs = {"timeout": 180_000, "headers": headers}
    if body is not None:
        kwargs["data"] = body if isinstance(body, str) else json.dumps(body)
    fn = {"GET": ctx.get, "POST": ctx.post, "PUT": ctx.put, "DELETE": ctx.delete}[method]
    r = fn(url, **kwargs)
    text = r.text()
    try:
        j = json.loads(text)
    except Exception:
        j = None
    return r.status, j, text


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


def order_summary(rows):
    order = next((r for r in rows if r.get("_dw") == "order"), None)
    items = [r for r in rows if r.get("_dw") == "items" and str(r.get("oe_order_item_id") or "").strip()]
    return order, items


def publish(env, so, payload):
    url = (env.get("SUPABASE_URL") or "").rstrip("/")
    key = env.get("SUPABASE_ANON_KEY") or ""
    if not url or not key:
        return False
    req = urlrequest.Request(
        f"{url}/functions/v1/p21-publish",
        data=json.dumps({"so": so, "payload": payload}).encode("utf-8"),
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
            "apikey": key,
            "Authorization": f"Bearer {key}",
        },
        method="POST",
    )
    with urlrequest.urlopen(req, timeout=60) as resp:
        print("PUBLISH", resp.status, resp.read()[:300])
        return True


def main():
    so = (sys.argv[1] if len(sys.argv) > 1 else "").strip()
    if not so:
        print("Usage: py interactive-row1.py <SO>")
        return 1
    env = load_env()
    OUT.mkdir(exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(ignore_https_errors=True)
        page = context.new_page()
        token = login_token(page, env["P21_USERNAME"], env["P21_PASSWORD"])
        print("TOKEN_OK")
        h = {
            "Accept": "application/json",
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

        st, j, t = call(context.request, "POST", "/api/ui/interactive/sessions", h, {"SessionType": "Auto", "ResponseWindowHandlingEnabled": False, "ClientPlatformApp": "SLST"})
        if st == 409:
            call(context.request, "DELETE", "/api/ui/interactive/sessions", h)
            st, j, t = call(context.request, "POST", "/api/ui/interactive/sessions", h, {"SessionType": "Auto", "ResponseWindowHandlingEnabled": False, "ClientPlatformApp": "SLST"})
        print("SESS", st)

        st, opened, _ = call(context.request, "POST", "/api/ui/interactive/v2/window", h, {"ServiceName": "Order"})
        wid = (opened or {}).get("WindowId")
        print("OPEN", st, wid)
        if not wid:
            browser.close()
            return 2

        call(context.request, "POST", "/api/ui/interactive/v2/tools", h, {"WindowId": wid, "ToolName": "Quick.Clear"})

        # Try several change shapes including Row 1
        payloads = [
            {"WindowId": wid, "List": [{"TabName": "Order", "FieldName": "order_no", "Value": so, "DatawindowName": "order", "Row": 1}]},
            {"WindowId": wid, "List": [{"TabName": "Order", "FieldName": "order_no", "Value": so, "DatawindowName": "order", "Row": 0}]},
            {"WindowId": wid, "List": [{"TabName": "Order", "FieldName": "order_no", "Value": so, "DatawindowName": "order", "ValueType": "Display", "Row": 1}]},
        ]
        for i, payload in enumerate(payloads):
            st, j, t = call(context.request, "PUT", "/api/ui/interactive/v2/change", h, payload)
            print("CHANGE", i, st, "so_in_body", so in t)
            st, data, text = call(context.request, "GET", f"/api/ui/interactive/v2/data?id={wid}", h)
            (OUT / f"row1-data-{i}-{so}.json").write_text(text, encoding="utf-8")
            order, items = order_summary(dw_rows(data))
            print("  ORDER", None if not order else {k: order.get(k) for k in ("order_no", "customer_id", "customer_name")})
            print("  ITEMS", len(items))
            if order and (str(order.get("order_no") or "") == so or order.get("customer_id")):
                break

        # inquiry.transaction may open a finder window
        st, j, t = call(context.request, "POST", "/api/ui/interactive/v2/tools", h, {"WindowId": wid, "ToolName": "inquiry.transaction"})
        print("INQUIRY", st, t[:400].replace("\n", " "))
        (OUT / f"inquiry-{so}.json").write_text(t, encoding="utf-8")
        # If a new window opened, capture its id and data
        new_wid = None
        if j:
            for ev in j.get("Events") or []:
                if ev.get("Name") == "windowopened":
                    for d in ev.get("Data") or []:
                        if d.get("Key") == "windowid":
                            new_wid = d.get("Value")
        # Sometimes WindowId is top-level on response windows
        if not new_wid and isinstance(j, dict):
            new_wid = j.get("WindowId")
        print("INQUIRY_WID", new_wid)
        if new_wid and new_wid != wid:
            st, data, text = call(context.request, "GET", f"/api/ui/interactive/v2/data?id={new_wid}", h)
            (OUT / f"inquiry-data-{so}.json").write_text(text, encoding="utf-8")
            st, tools, tt = call(context.request, "GET", f"/api/ui/interactive/v2/tools?windowId={new_wid}", h)
            (OUT / f"inquiry-tools-{so}.json").write_text(tt, encoding="utf-8")
            print("INQUIRY_TOOLS", st, tt[:300].replace("\n", " "))
            # try set search field named transaction / order
            for field in ("order_no", "transaction_no", "document_no", "search", "criteria"):
                for dw in ("form", "criteria", "list", "search"):
                    st, j, t = call(
                        context.request,
                        "PUT",
                        "/api/ui/interactive/v2/change",
                        h,
                        {"WindowId": new_wid, "List": [{"TabName": "FORM", "FieldName": field, "Value": so, "DatawindowName": dw, "Row": 1}]},
                    )
                    if st == 200:
                        print("INQ_CHANGE", field, dw, st, t[:120].replace("\n", " "))

        st, data, text = call(context.request, "GET", f"/api/ui/interactive/v2/data?id={wid}", h)
        (OUT / f"final-data-{so}.json").write_text(text, encoding="utf-8")
        order, items = order_summary(dw_rows(data))
        print("FINAL_ORDER", None if not order else {k: order.get(k) for k in ("order_no", "customer_id", "customer_name", "po_no")})
        print("FINAL_ITEMS", len(items))

        call(context.request, "POST", "/api/ui/interactive/v2/tools", h, {"WindowId": wid, "ToolName": "Quick.Close"})
        call(context.request, "DELETE", f"/api/ui/interactive/v2/window?id={wid}", h)
        browser.close()

    found = bool(order and (str(order.get("order_no") or "") == so or order.get("customer_id") or order.get("customer_name")))
    payload = {
        "found": found,
        "so": so,
        "matchedBy": "interactive-row1",
        "header": None
        if not order
        else {
            "orderNo": order.get("order_no") or so,
            "customerId": order.get("customer_id"),
            "customerName": order.get("customer_name"),
            "poNo": order.get("po_no"),
            "orderDate": order.get("order_date"),
            "shipTo": order.get("ship_to_name"),
            "taker": order.get("taker"),
            "warehouse": order.get("sales_loc_id"),
        },
        "lines": [
            {
                "lineNo": r.get("oe_line_line_no"),
                "itemId": r.get("oe_order_item_id"),
                "description": r.get("item_desc"),
                "qtyOrdered": r.get("unit_quantity"),
                "uom": r.get("unit_of_measure"),
                "unitPrice": r.get("unit_price"),
                "extendedPrice": r.get("extended_price"),
            }
            for r in items[:500]
        ],
        "source": "ui-bridge-interactive",
        "fetchedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    (OUT / f"payload-row1-{so}.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print("FOUND", found)
    if found:
        publish(env, so, payload)
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
