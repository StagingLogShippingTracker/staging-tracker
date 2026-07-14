"""
Fetch SO via Interactive API Order window: set order_no, read full data, publish.
Saves full responses to disk (no 30KB truncate).
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


def api_save(ctx, method, path, headers, dest: Path, body=None):
    url = API + path
    kwargs = {"timeout": 180_000, "headers": headers}
    if body is not None:
        kwargs["data"] = body if isinstance(body, str) else json.dumps(body)
    fn = {"GET": ctx.get, "POST": ctx.post, "PUT": ctx.put, "DELETE": ctx.delete}[method]
    r = fn(url, **kwargs)
    text = r.text()
    dest.write_text(text, encoding="utf-8")
    try:
        parsed = json.loads(text)
    except Exception:
        parsed = None
    print(method, r.status, path, "bytes=", len(text), "->", dest.name)
    return r.status, parsed, text


def dw_rows(data):
    """Normalize Interactive data payload (list or {Data: list}) to dict rows."""
    blocks = data
    if isinstance(data, dict):
        blocks = data.get("Data") or []
    if not isinstance(blocks, list):
        return []
    rows = []
    for block in blocks:
        if not isinstance(block, dict):
            continue
        cols = block.get("Columns") or []
        for row in block.get("Data") or []:
            d = {"_dw": block.get("Name"), "_full": block.get("FullName")}
            for i, c in enumerate(cols):
                if i < len(row):
                    d[c] = row[i]
            rows.append(d)
    return rows


def publish(env, so, payload):
    url = (env.get("SUPABASE_URL") or "").rstrip("/")
    key = env.get("SUPABASE_ANON_KEY") or ""
    if not url or not key:
        print("WARN: no supabase")
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
        print("Usage: py interactive-load-so.py <SO>")
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

        st, opened, _ = api_save(
            context.request,
            "POST",
            "/api/ui/interactive/v2/window",
            h,
            OUT / f"open-{so}.json",
            {"ServiceName": "Order"},
        )
        wid = (opened or {}).get("WindowId")
        print("WID", wid)
        if not wid:
            browser.close()
            return 2

        # Set order number (known-good TabName/DatawindowName)
        api_save(
            context.request,
            "PUT",
            "/api/ui/interactive/v2/change",
            h,
            OUT / f"change-{so}.json",
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

        # Small wait for retrieve side-effects
        page.wait_for_timeout(2000)

        st_data, data, _ = api_save(
            context.request,
            "GET",
            f"/api/ui/interactive/v2/data?id={wid}",
            h,
            OUT / f"data-full-{so}.json",
        )
        api_save(
            context.request,
            "GET",
            f"/api/ui/interactive/v2/window?id={wid}",
            h,
            OUT / f"state-full-{so}.json",
        )

        # Close without saving
        api_save(
            context.request,
            "POST",
            "/api/ui/interactive/v2/tools",
            h,
            OUT / f"close-tool-{so}.json",
            {"WindowId": wid, "ToolName": "Quick.Close"},
        )
        api_save(
            context.request,
            "DELETE",
            f"/api/ui/interactive/v2/window?id={wid}",
            h,
            OUT / f"close-{so}.json",
        )
        browser.close()

    rows = dw_rows(data)
    order = next((r for r in rows if r.get("_dw") == "order"), None)
    items = [
        r
        for r in rows
        if r.get("_dw") == "items" and str(r.get("oe_order_item_id") or "").strip()
    ]
    print(
        "ORDER",
        None
        if not order
        else {
            k: order.get(k)
            for k in ("order_no", "customer_id", "customer_name", "po_no", "taker", "ship_to_name")
        },
    )
    print("ITEMS", len(items))
    if items[:3]:
        print("ITEM0", items[0].get("oe_order_item_id"), items[0].get("item_desc"))

    found = bool(
        order
        and (
            str(order.get("order_no") or "") == so
            or order.get("customer_id")
            or order.get("customer_name")
            or items
        )
    )
    payload = {
        "found": found,
        "so": so,
        "matchedBy": "interactive-order",
        "header": None
        if not order
        else {
            "orderNo": order.get("order_no") or so,
            "customerId": order.get("customer_id"),
            "customerName": order.get("customer_name"),
            "poNo": order.get("po_no"),
            "orderDate": order.get("order_date"),
            "status": order.get("validation_status") or order.get("cancel_flag"),
            "shipTo": order.get("ship_to_name"),
            "warehouse": order.get("sales_loc_id"),
            "projectId": order.get("ufc_oe_hdr_ud_project"),
            "taker": order.get("taker") or order.get("taker_name"),
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
    (OUT / f"payload-final-{so}.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print("FOUND", found, "lines", len(payload["lines"]))
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
