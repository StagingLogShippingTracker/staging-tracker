"""
SLST Prophet21 UI Bridge — no OData / IT grant required.

Logs into the Prophet21 web UI with your normal user credentials, opens Order Entry
via the Interactive API, retrieves one sales order, and publishes it to Supabase
`p21-publish` so every SLST user can read it from `p21_order_cache`.

Setup (once):
  py -m pip install playwright
  set PLAYWRIGHT_BROWSERS_PATH=0
  py -m playwright install chromium

  Copy .env.example -> .env and set:
    P21_USERNAME / P21_PASSWORD
    SUPABASE_URL / SUPABASE_ANON_KEY

Usage:
  set PLAYWRIGHT_BROWSERS_PATH=0
  set PYTHONIOENCODING=utf-8
  py p21-ui-publisher.py 1413307
  py p21-ui-publisher.py 1413307 1413791 1413834
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path
from urllib import request as urlrequest

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
API = "https://swiftsupply-api.epicordistribution.com/uiserver0"
UI = "https://swiftsupply.epicordistribution.com/Prophet21/#/"


def load_env() -> dict[str, str]:
    env: dict[str, str] = {}
    path = HERE / ".env"
    if not path.exists():
        raise SystemExit(f"Missing {path} — copy .env.example and add credentials.")
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip() or line.strip().startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def login_token(page, user: str, password: str) -> str:
    captured: list[dict] = []

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
    raise RuntimeError("Prophet21 login did not return AccessToken.")


def call(ctx, method: str, path: str, headers: dict, body=None):
    url = API + path
    kwargs = {"timeout": 180_000, "headers": headers}
    if body is not None:
        kwargs["data"] = body if isinstance(body, str) else json.dumps(body)
    fn = {"GET": ctx.get, "POST": ctx.post, "PUT": ctx.put, "DELETE": ctx.delete}[method]
    r = fn(url, **kwargs)
    text = r.text()
    try:
        parsed = json.loads(text)
    except Exception:
        parsed = None
    return r.status, parsed, text


def dw_rows(data) -> list[dict]:
    blocks = data if isinstance(data, list) else (data or {}).get("Data") or []
    rows: list[dict] = []
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


def ensure_auto_session(ctx, headers: dict) -> None:
    st, _, text = call(
        ctx,
        "POST",
        "/api/ui/interactive/sessions",
        headers,
        {
            "SessionType": "Auto",
            "ResponseWindowHandlingEnabled": False,
            "ClientPlatformApp": "SLST-UI-Publisher",
            "SessionTimeout": 300,
        },
    )
    if st == 409:
        call(ctx, "DELETE", "/api/ui/interactive/sessions", headers)
        st, _, text = call(
            ctx,
            "POST",
            "/api/ui/interactive/sessions",
            headers,
            {
                "SessionType": "Auto",
                "ResponseWindowHandlingEnabled": False,
                "ClientPlatformApp": "SLST-UI-Publisher",
                "SessionTimeout": 300,
            },
        )
    if st not in (200, 201):
        raise RuntimeError(f"Interactive session failed ({st}): {text[:200]}")


def fetch_order(ctx, headers: dict, so: str) -> dict:
    st, opened, text = call(ctx, "POST", "/api/ui/interactive/v2/window", headers, {"ServiceName": "Order"})
    wid = (opened or {}).get("WindowId")
    if not wid:
        raise RuntimeError(f"Open Order window failed ({st}): {text[:200]}")

    try:
        call(ctx, "POST", "/api/ui/interactive/v2/tools", headers, {"WindowId": wid, "ToolName": "Quick.Clear"})

        # Row=1 triggers retrieve of existing SO (verified on Swift P21 26.1)
        st, _, ch_text = call(
            ctx,
            "PUT",
            "/api/ui/interactive/v2/change",
            headers,
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
        if st >= 400:
            # Fallback: Row=0 sometimes surfaces header on subsequent GET
            call(
                ctx,
                "PUT",
                "/api/ui/interactive/v2/change",
                headers,
                {
                    "WindowId": wid,
                    "List": [
                        {
                            "TabName": "Order",
                            "FieldName": "order_no",
                            "Value": so,
                            "DatawindowName": "order",
                            "Row": 0,
                        }
                    ],
                },
            )

        st, data, _ = call(ctx, "GET", f"/api/ui/interactive/v2/data?id={wid}", headers)
        st2, state, _ = call(ctx, "GET", f"/api/ui/interactive/v2/window?id={wid}", headers)
        rows = dw_rows(data) + dw_rows(state)

        order = next((r for r in rows if r.get("_dw") == "order" and (r.get("order_no") or r.get("customer_id"))), None)
        if not order:
            order = next((r for r in rows if r.get("_dw") == "order"), None)
        items = [
            r
            for r in rows
            if r.get("_dw") == "items" and str(r.get("oe_order_item_id") or "").strip()
        ]

        found = bool(
            order
            and (
                str(order.get("order_no") or "") == so
                or order.get("customer_id")
                or order.get("customer_name")
                or items
            )
        )
        return {
            "found": found,
            "so": so,
            "matchedBy": "interactive-api",
            "header": None
            if not found
            else {
                "orderNo": (order or {}).get("order_no") or so,
                "customerId": (order or {}).get("customer_id"),
                "customerName": (order or {}).get("customer_name"),
                "poNo": (order or {}).get("po_no"),
                "orderDate": (order or {}).get("order_date"),
                "status": (order or {}).get("validation_status") or (order or {}).get("cancel_flag"),
                "shipTo": (order or {}).get("ship_to_name"),
                "warehouse": (order or {}).get("sales_loc_id") or (order or {}).get("source_loc_id"),
                "projectId": (order or {}).get("ufc_oe_hdr_ud_project"),
                "taker": (order or {}).get("taker") or (order or {}).get("taker_name"),
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
            "_changeStatus": st,
            "_changeHint": ch_text[:120],
        }
    finally:
        try:
            call(ctx, "POST", "/api/ui/interactive/v2/tools", headers, {"WindowId": wid, "ToolName": "Quick.Close"})
        except Exception:
            pass
        try:
            call(ctx, "DELETE", f"/api/ui/interactive/v2/window?id={wid}", headers)
        except Exception:
            pass


def publish(env: dict, so: str, payload: dict) -> bool:
    url = (env.get("SUPABASE_URL") or "").rstrip("/")
    key = env.get("SUPABASE_ANON_KEY") or ""
    if not url or not key:
        print("WARN: SUPABASE_URL / SUPABASE_ANON_KEY missing — skip publish")
        return False
    body = {k: v for k, v in payload.items() if not k.startswith("_")}
    req = urlrequest.Request(
        f"{url}/functions/v1/p21-publish",
        data=json.dumps({"so": so, "payload": body}).encode("utf-8"),
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
            "apikey": key,
            "Authorization": f"Bearer {key}",
        },
        method="POST",
    )
    with urlrequest.urlopen(req, timeout=60) as resp:
        print("PUBLISH", so, resp.status, resp.read()[:240].decode("utf-8", errors="replace"))
        return 200 <= resp.status < 300


def main(argv: list[str]) -> int:
    orders = [a.strip() for a in argv if a.strip()]
    if not orders:
        print("Usage: py p21-ui-publisher.py <SO> [SO...]")
        return 1
    env = load_env()
    user = env.get("P21_USERNAME") or ""
    password = env.get("P21_PASSWORD") or ""
    if not user or not password:
        raise SystemExit("P21_USERNAME / P21_PASSWORD required in .env")

    ok = 0
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(ignore_https_errors=True)
        page = context.new_page()
        token = login_token(page, user, password)
        print("TOKEN_OK")
        headers = {
            "Accept": "application/json",
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }
        ensure_auto_session(context.request, headers)

        for so in orders:
            try:
                payload = fetch_order(context.request, headers, so)
                print(
                    "SO",
                    so,
                    "found=",
                    payload["found"],
                    "customer=",
                    (payload.get("header") or {}).get("customerName"),
                    "lines=",
                    len(payload.get("lines") or []),
                )
                if payload["found"]:
                    if publish(env, so, payload):
                        ok += 1
                else:
                    print("MISS", so)
            except Exception as e:
                print("ERROR", so, e)

        browser.close()

    print(f"DONE published={ok}/{len(orders)}")
    return 0 if ok == len(orders) else 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
