"""
P21 UI bridge — uses normal Prophet21 web login (no OData grant).

Flow:
  1. Login at Prophet21 web UI
  2. From the authenticated browser context, probe sales/order APIs
     and/or open Order Entry (m_orderentry) and load an SO
  3. Publish structured payload to Supabase p21-publish

Usage:
  set PLAYWRIGHT_BROWSERS_PATH=0
  py ui-bridge.py --map
  py ui-bridge.py 1234567
  set P21_HEADED=1 && py ui-bridge.py 1234567
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import time
from pathlib import Path
from urllib import request as urlrequest

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("Install: py -m pip install playwright && py -m playwright install chromium", file=sys.stderr)
    sys.exit(1)

HERE = Path(__file__).resolve().parent
MAP_DIR = HERE / "_ui-map"
API = "https://swiftsupply-api.epicordistribution.com"


def load_env(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def normalize_so(raw: str) -> str:
    return re.sub(r"(?i)^SO[#:\s-]*", "", str(raw or "").strip())


def jwt_claims(token: str) -> dict:
    try:
        part = token.split(".")[1]
        pad = "=" * (-len(part) % 4)
        return json.loads(base64.urlsafe_b64decode(part + pad).decode("utf-8"))
    except Exception:
        return {}


def pick(row: dict, keys: list[str]):
    for k in keys:
        if row.get(k) not in (None, ""):
            return row[k]
    return None


def summarize_header(row: dict | None) -> dict | None:
    if not row:
        return None
    return {
        "orderNo": pick(row, ["order_no", "OrderNo", "order_number", "OrderNumber", "Order Number"]),
        "customerId": pick(row, ["customer_id", "CustomerId", "Customer ID"]),
        "customerName": pick(row, ["customer_name", "CustomerName", "ship_to_name", "ShipToName", "Customer Name"]),
        "poNo": pick(row, ["po_no", "PoNo", "customer_po_no", "CustomerPoNo", "PO Number"]),
        "orderDate": pick(row, ["order_date", "OrderDate", "date_created", "Order Date"]),
        "status": pick(row, ["order_status", "OrderStatus", "status", "Status"]),
        "shipTo": pick(row, ["ship_to_name", "ShipToName", "Ship To"]),
        "shipVia": pick(row, ["ship_via", "ShipVia", "carrier_id"]),
        "warehouse": pick(row, ["source_loc_id", "SourceLocId", "location_id", "Location"]),
        "projectId": pick(row, ["project_id", "ProjectId"]),
        "taker": pick(row, ["taker", "Taker"]),
    }


def summarize_line(row: dict) -> dict:
    return {
        "lineNo": pick(row, ["line_no", "LineNo", "oe_line_number", "Line"]),
        "itemId": pick(row, ["item_id", "ItemId", "inv_mast_uid", "Item ID"]),
        "description": pick(row, ["item_desc", "ItemDesc", "extended_desc", "description", "Description"]),
        "qtyOrdered": pick(row, ["qty_ordered", "QtyOrdered", "unit_quantity", "Ordered"]),
        "qtyShipped": pick(row, ["qty_shipped", "QtyShipped", "Shipped"]),
        "uom": pick(row, ["unit_of_measure", "UnitOfMeasure", "sales_uom", "UOM"]),
        "unitPrice": pick(row, ["unit_price", "UnitPrice"]),
        "extendedPrice": pick(row, ["extended_price", "ExtendedPrice"]),
        "requiredDate": pick(row, ["required_date", "RequiredDate", "promise_date"]),
    }


def first_visible(page, selectors: list[str]):
    for sel in selectors:
        loc = page.locator(sel).first
        try:
            if loc.count() and loc.is_visible():
                return loc
        except Exception:
            continue
    return None


USER_SELS = [
    'input[name="username"]',
    'input[name="Username"]',
    'input[id*="user" i]',
    'input[placeholder*="user" i]',
]
PASS_SELS = [
    'input[name="password"]',
    'input[name="Password"]',
    "#txtPassword",
    'input[type="password"]',
]


def try_login(page, user: str, password: str) -> bool:
    page.wait_for_timeout(1500)
    user_box = first_visible(page, USER_SELS)
    pass_box = first_visible(page, PASS_SELS)
    if not user_box or not pass_box:
        for frame in page.frames:
            if frame == page.main_frame:
                continue
            ub = first_visible(frame, USER_SELS)
            pb = first_visible(frame, PASS_SELS)
            if ub and pb:
                user_box, pass_box = ub, pb
                break
    if not user_box or not pass_box:
        return False
    user_box.fill(user)
    pass_box.fill(password)
    btn = page.locator("#loginButton, button[type='submit'], button:has-text('Log'), button:has-text('Sign')").first
    if btn.count():
        btn.click()
    else:
        pass_box.press("Enter")
    page.wait_for_timeout(6000)
    return True


def publish_to_supabase(env: dict, so: str, payload: dict) -> bool:
    url = (env.get("SUPABASE_URL") or "").rstrip("/")
    key = env.get("SUPABASE_ANON_KEY") or env.get("SUPABASE_SERVICE_ROLE_KEY") or ""
    if not url or not key:
        print("WARN: SUPABASE_URL / key missing - skipping publish")
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
    try:
        with urlrequest.urlopen(req, timeout=60) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            print("PUBLISH", resp.status, body[:300])
            return 200 <= resp.status < 300
    except Exception as e:
        print("PUBLISH_FAIL", e)
        return False


def auth_headers(token: str, app_key: str | None = None) -> dict[str, str]:
    h = {
        "Accept": "application/json",
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    if app_key:
        h["P21.AppKey"] = app_key
        h["AppKey"] = app_key
    return h


def probe_with_request(request_ctx, token: str, so: str, app_key: str | None) -> list[dict]:
    """CORS-free probes via Playwright request (outside page JS)."""
    headers = auth_headers(token, app_key)
    urls = [
        f"{API}/api/sales/reminders/?id=BRICE.JOHNSON",
        f"{API}/api/users/?id=BRICE.JOHNSON",
        f"{API}/uiserver0/ui/full/v1/menu/",
        f"{API}/uiserver0/ui/common/v1/sessions/",
        f"{API}/odataservice/odata/view/p21_view_oe_hdr?$top=1&$filter=order_no eq '{so}'",
        # Transaction / entity guesses (cheap 404s vs hung GET /api/sales/orders)
        f"{API}/api/entity/salesorder/{so}",
        f"{API}/api/transaction/salesorder/{so}",
        f"{API}/api/sales/v2/orders/{so}",
    ]
    out = []
    for url in urls:
        try:
            res = request_ctx.get(url, headers=headers, timeout=20_000)
            body = res.text()[:1200]
            out.append({"url": url, "status": res.status, "body": body})
        except Exception as e:
            out.append({"url": url, "status": 0, "body": str(e)})
    return out


def open_orders_with_request(request_ctx, token: str, app_key: str | None) -> list[dict]:
    """UI window open expects form field menuSearchString (not JSON)."""
    headers = auth_headers(token, app_key)
    # Drop JSON content-type for form posts
    form_headers = {k: v for k, v in headers.items() if k.lower() != "content-type"}
    form_headers["Content-Type"] = "application/x-www-form-urlencoded"
    form_headers["Accept"] = "application/json"

    attempts = [
        ("form", form_headers, "menuSearchString=m_orderentry"),
        ("form", form_headers, "menuSearchString=Orders"),
        ("form", form_headers, "menuSearchString=Order Entry"),
        ("form", form_headers, "menuSearchString=759"),
        ("json", headers, json.dumps({"menuSearchString": "m_orderentry"})),
        ("json", headers, json.dumps({"menuSearchString": "Orders"})),
    ]
    out = []
    url = f"{API}/uiserver0/ui/full/v1/window/"
    for kind, hdrs, body in attempts:
        try:
            res = request_ctx.post(url, headers=hdrs, data=body, timeout=45_000)
            out.append({"url": url, "kind": kind, "req": body, "status": res.status, "body": res.text()[:1500]})
        except Exception as e:
            out.append({"url": url, "kind": kind, "req": body, "status": 0, "body": str(e)})
    return out


def extract_token_from_captured(captured: list[dict]) -> str | None:
    for e in captured:
        data = e.get("json")
        if isinstance(data, dict) and data.get("AccessToken"):
            return data["AccessToken"]
    return None


def extract_order_from_captured(captured: list[dict], so: str):
    so_n = normalize_so(so).lower()
    header = None
    lines: list[dict] = []
    for item in captured:
        data = item.get("json")
        if data is None:
            continue
        rows = []
        if isinstance(data, list):
            rows = [r for r in data if isinstance(r, dict)]
        elif isinstance(data, dict):
            for key in ("value", "Data", "data", "Items", "items", "Orders", "orders", "Results"):
                v = data.get(key)
                if isinstance(v, list):
                    rows = [r for r in v if isinstance(r, dict)]
                    break
            if not rows and any(k in data for k in ("order_no", "OrderNo", "customer_id", "CustomerId")):
                rows = [data]
        for row in rows:
            blob = json.dumps(row).lower()
            if so_n and so_n not in blob:
                continue
            if any(k in row for k in ("item_id", "ItemId", "line_no", "LineNo", "qty_ordered", "QtyOrdered")):
                lines.append(row)
            elif header is None:
                header = row
    return header, lines


def run(so: str | None, map_only: bool) -> int:
    env = load_env(HERE / ".env")
    user = env.get("P21_USERNAME") or ""
    password = env.get("P21_PASSWORD") or ""
    ui = (env.get("P21_WEB_URL") or "https://swiftsupply.epicordistribution.com/Prophet21/#/").rstrip("/") + "/"
    headed = os.environ.get("P21_HEADED") == "1" or env.get("P21_HEADED") == "1"
    if not user or not password:
        print("Missing P21_USERNAME / P21_PASSWORD in .env", file=sys.stderr)
        return 1

    MAP_DIR.mkdir(parents=True, exist_ok=True)
    captured: list[dict] = []
    so_key = normalize_so(so or env.get("P21_TEST_SO") or "")

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=not headed)
        context = browser.new_context(viewport={"width": 1400, "height": 900}, ignore_https_errors=True)
        page = context.new_page()

        def on_response(res):
            try:
                url = res.url
                if not re.search(r"api|odata|sales|order|entity|uiserver|token|session|view|window", url, re.I):
                    return
                ct = (res.headers.get("content-type") or "").lower()
                entry: dict = {"status": res.status, "url": url[:500], "ct": ct}
                if ("json" in ct or url.endswith("/token/v2")) and res.status < 500:
                    text = res.text()[:120_000]
                    entry["preview"] = text[:200]
                    try:
                        entry["json"] = json.loads(text)
                    except Exception:
                        pass
                captured.append(entry)
            except Exception:
                pass

        page.on("response", on_response)

        print("OPEN", ui)
        page.goto(ui, wait_until="domcontentloaded", timeout=90_000)
        page.wait_for_timeout(2500)
        page.screenshot(path=str(MAP_DIR / "01-before-login.png"), full_page=True)

        logged = try_login(page, user, password)
        print("LOGIN_ATTEMPTED", logged, "URL", page.url, "TITLE", page.title())
        page.wait_for_timeout(3000)
        page.screenshot(path=str(MAP_DIR / "02-after-login.png"), full_page=True)

        token = extract_token_from_captured(captured)
        app_key = None
        if token:
            claims = jwt_claims(token)
            app_key = claims.get("P21.AppKey")
            print("TOKEN_OK AppKey=", app_key, "SessionId=", claims.get("P21.SessionId"))
        else:
            print("WARN: no AccessToken captured from login responses")

        # Skip slow/hanging sales/orders GETs for now (timeout without useful body)
        # Keep reminders/users/menu/sessions/odata + form-based window open
        if token and so_key:
            probes = probe_with_request(context.request, token, so_key, app_key)
            (MAP_DIR / "api-probes.json").write_text(json.dumps(probes, indent=2), encoding="utf-8")
            for row in probes:
                if "/api/sales/orders" in row["url"]:
                    continue  # noisy timeouts
                print(
                    "PROBE",
                    row["status"],
                    row["url"].split(".com")[-1][:90],
                    (row.get("body") or "")[:140].replace("\n", " "),
                )
            open_attempts = open_orders_with_request(context.request, token, app_key)
            (MAP_DIR / "open-orders.json").write_text(json.dumps(open_attempts, indent=2), encoding="utf-8")
            for row in open_attempts:
                print(
                    "OPEN_ORDERS",
                    row["status"],
                    row.get("kind"),
                    str(row.get("req"))[:60],
                    (row.get("body") or "")[:200].replace("\n", " "),
                )
            # If window opened, give SPA a moment then try to set order no via UI
            opened = next((r for r in open_attempts if r.get("status") == 200 and "Result" in (r.get("body") or "")), None)
            if opened:
                print("WINDOW_OPENED")
                page.wait_for_timeout(5000)
                page.screenshot(path=str(MAP_DIR / "03b-window-api.png"), full_page=True)

        # Click Orders favorite in UI if present
        try:
            fav = page.get_by_text("Orders", exact=True).first
            if fav.count() and fav.is_visible():
                fav.click()
                page.wait_for_timeout(5000)
                print("CLICKED_ORDERS_FAVORITE")
                page.screenshot(path=str(MAP_DIR / "03-orders.png"), full_page=True)
        except Exception as e:
            print("FAVORITE_CLICK_SKIP", e)

        if so_key and not map_only:
            # Type SO into any visible order field after Orders opens
            order_box = first_visible(
                page,
                [
                    'input[placeholder*="order" i]',
                    'input[aria-label*="order" i]',
                    'input[name*="order" i]',
                    'input.p21-textbox',
                    'input[type="text"]',
                ],
            )
            if order_box:
                order_box.fill(so_key)
                order_box.press("Enter")
                page.wait_for_timeout(6000)
                page.screenshot(path=str(MAP_DIR / "04-so-loaded.png"), full_page=True)
                print("TYPED_SO", so_key)

        # Persist map artifacts (strip full JWT bodies from network dump)
        safe_net = []
        for e in captured:
            safe = {k: v for k, v in e.items() if k != "json"}
            if "preview" in safe and "AccessToken" in str(safe["preview"]):
                safe["preview"] = '{"AccessToken":"[redacted]"}'
            safe_net.append(safe)
        (MAP_DIR / "network.json").write_text(json.dumps(safe_net, indent=2), encoding="utf-8")

        if map_only:
            print("MAP_DONE", MAP_DIR)
            browser.close()
            return 0

        if not so_key:
            print("Provide an SO number as argv, or set P21_TEST_SO in .env")
            browser.close()
            return 1

        header_row, line_rows = extract_order_from_captured(captured, so_key)
        # Also parse successful probe bodies
        probes_path = MAP_DIR / "api-probes.json"
        if probes_path.exists():
            for row in json.loads(probes_path.read_text(encoding="utf-8")):
                if row.get("status") != 200:
                    continue
                try:
                    data = json.loads(row["body"])
                except Exception:
                    continue
                captured.append({"status": 200, "url": row["url"], "json": data})
            header_row, line_rows = extract_order_from_captured(captured, so_key)

        body_text = ""
        try:
            body_text = page.inner_text("body")
        except Exception:
            pass

        found = header_row is not None or bool(line_rows) or (so_key in body_text and "Orders" in body_text)
        payload = {
            "found": bool(found and (header_row or line_rows or so_key in body_text)),
            "so": so_key,
            "matchedBy": "ui-bridge",
            "header": summarize_header(header_row) if header_row else ({"orderNo": so_key} if so_key in body_text else None),
            "lines": [summarize_line(r) for r in line_rows[:100]],
            "source": "ui-bridge",
            "fetchedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }
        if payload["found"] and not header_row and so_key in body_text:
            payload["note"] = "SO visible in UI DOM; refine field mapping after a successful orders window capture."

        (MAP_DIR / f"payload-{so_key}.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print("PAYLOAD_FOUND", payload["found"], "lines", len(payload["lines"]))

        if payload["found"]:
            publish_to_supabase(env, so_key, payload)
        else:
            print("No order data yet. Artifacts in", MAP_DIR)

        browser.close()
        return 0 if payload["found"] else 2


def main():
    ap = argparse.ArgumentParser(description="Prophet21 UI -> SLST cache bridge")
    ap.add_argument("so", nargs="?", help="Sales order number")
    ap.add_argument("--map", action="store_true", help="Login + capture only")
    args = ap.parse_args()
    raise SystemExit(run(args.so, args.map))


if __name__ == "__main__":
    main()
