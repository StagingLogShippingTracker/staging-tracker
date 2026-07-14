"""
Clear Order Entry first, then set order_no and capture header+lines.
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
            d = {"_dw": block.get("Name"), "_full": block.get("FullName"), "_total": block.get("TotalRows")}
            for i, c in enumerate(cols):
                if i < len(row):
                    d[c] = row[i]
            rows.append(d)
    return rows


def publish(env, so, payload):
    url = (env.get("SUPABASE_URL") or "").rstrip("/")
    key = env.get("SUPABASE_ANON_KEY") or ""
    if not url or not key:
        print("WARN no supabase")
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
        print("Usage: py interactive-clear-load.py <SO>")
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

        # Prefer a dedicated Auto interactive session if possible
        st, j, t = call(
            context.request,
            "POST",
            "/api/ui/interactive/sessions",
            h,
            {
                "SessionType": "Auto",
                "ResponseWindowHandlingEnabled": False,
                "ClientPlatformApp": "SLST",
                "SessionTimeout": 300,
            },
        )
        print("SESS_CREATE", st, t[:200].replace("\n", " "))
        if st == 409:
            st, j, t = call(context.request, "DELETE", "/api/ui/interactive/sessions", h)
            print("SESS_DELETE", st, t[:200].replace("\n", " "))
            st, j, t = call(
                context.request,
                "POST",
                "/api/ui/interactive/sessions",
                h,
                {
                    "SessionType": "Auto",
                    "ResponseWindowHandlingEnabled": False,
                    "ClientPlatformApp": "SLST",
                },
            )
            print("SESS_CREATE2", st, t[:200].replace("\n", " "))

        st, opened, t = call(context.request, "POST", "/api/ui/interactive/v2/window", h, {"ServiceName": "Order"})
        wid = (opened or {}).get("WindowId")
        print("OPEN", st, wid)
        if not wid:
            browser.close()
            return 2

        # Snapshot immediately after open
        st, data0, t0 = call(context.request, "GET", f"/api/ui/interactive/v2/data?id={wid}", h)
        (OUT / f"data-after-open-{so}.json").write_text(t0, encoding="utf-8")
        rows0 = dw_rows(data0)
        print("AFTER_OPEN dws", sorted({r["_dw"] for r in rows0}), "items", sum(1 for r in rows0 if r["_dw"] == "items" and r.get("oe_order_item_id")))

        # Clear
        st, j, t = call(context.request, "POST", "/api/ui/interactive/v2/tools", h, {"WindowId": wid, "ToolName": "Quick.Clear"})
        print("CLEAR", st, t[:250].replace("\n", " "))
        page.wait_for_timeout(1500)

        st, data1, t1 = call(context.request, "GET", f"/api/ui/interactive/v2/data?id={wid}", h)
        (OUT / f"data-after-clear-{so}.json").write_text(t1, encoding="utf-8")
        rows1 = dw_rows(data1)
        print("AFTER_CLEAR dws", sorted({r["_dw"] for r in rows1}), "items", sum(1 for r in rows1 if r["_dw"] == "items" and r.get("oe_order_item_id")))

        # Select Order tab then set order_no
        for tab_payload in (
            {"WindowId": wid, "TabName": "TABPAGE_1"},
            {"WindowId": wid, "TabName": "Order"},
            {"WindowId": wid, "Name": "TABPAGE_1"},
        ):
            st, j, t = call(context.request, "PUT", "/api/ui/interactive/v2/tab", h, tab_payload)
            print("TAB", st, tab_payload, t[:120].replace("\n", " "))

        st, ch, t = call(
            context.request,
            "PUT",
            "/api/ui/interactive/v2/change",
            h,
            {
                "WindowId": wid,
                "List": [
                    {
                        "TabName": "Order",
                        "FieldName": "order_no",
                        "Value": so,
                        "DatawindowName": "order",
                    }
                ],
            },
        )
        print("CHANGE", st, "mentions_so", so in t, t[:300].replace("\n", " "))
        (OUT / f"change2-{so}.json").write_text(t, encoding="utf-8")
        page.wait_for_timeout(2500)

        st, data2, t2 = call(context.request, "GET", f"/api/ui/interactive/v2/data?id={wid}", h)
        (OUT / f"data-after-change-{so}.json").write_text(t2, encoding="utf-8")
        st, state, ts = call(context.request, "GET", f"/api/ui/interactive/v2/window?id={wid}", h)
        (OUT / f"state-after-change-{so}.json").write_text(ts, encoding="utf-8")

        rows = dw_rows(data2) + dw_rows(state)
        print("AFTER_CHANGE contains_so", so in t2 or so in ts)
        for name in sorted({r["_dw"] for r in rows}):
            subset = [r for r in rows if r["_dw"] == name]
            print("DW", name, "n=", len(subset), "total", subset[0].get("_total") if subset else None)

        order = next((r for r in rows if r.get("_dw") == "order"), None)
        items = [r for r in rows if r.get("_dw") == "items" and str(r.get("oe_order_item_id") or "").strip()]
        print(
            "ORDER",
            None
            if not order
            else {k: order.get(k) for k in ("order_no", "customer_id", "customer_name", "po_no", "taker")},
        )
        print("ITEMS", len(items))

        call(context.request, "POST", "/api/ui/interactive/v2/tools", h, {"WindowId": wid, "ToolName": "Quick.Close"})
        call(context.request, "DELETE", f"/api/ui/interactive/v2/window?id={wid}", h)
        browser.close()

    found = bool(order and (str(order.get("order_no")) == so or order.get("customer_id") or items and str(order.get("order_no") or "") in ("", so)))
    # Stricter: require SO match or customer
    found = bool(order and (str(order.get("order_no") or "") == so or order.get("customer_id") or order.get("customer_name")))
    if not found and items and so in (t2 or ""):
        found = True
        if not order:
            order = {"order_no": so}

    payload = {
        "found": found,
        "so": so,
        "matchedBy": "interactive-clear-load",
        "header": None
        if not order
        else {
            "orderNo": order.get("order_no") or so,
            "customerId": order.get("customer_id"),
            "customerName": order.get("customer_name"),
            "poNo": order.get("po_no"),
            "orderDate": order.get("order_date"),
            "status": order.get("validation_status"),
            "shipTo": order.get("ship_to_name"),
            "warehouse": order.get("sales_loc_id"),
            "taker": order.get("taker"),
        },
        "lines": [
            {
                "lineNo": r.get("oe_line_line_no"),
                "itemId": r.get("oe_order_item_id"),
                "description": r.get("item_desc") or r.get("extended_desc"),
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
    (OUT / f"payload-clearload-{so}.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print("FOUND", found)
    if found:
        try:
            publish(env, so, payload)
        except Exception as e:
            print("PUBLISH_FAIL", e)
            return 3
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
