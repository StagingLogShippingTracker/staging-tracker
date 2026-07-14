"""
Fetch one sales order via Prophet21 Transaction / Interactive APIs
using a UI-login Bearer token (no OData permission).

Usage:
  set PLAYWRIGHT_BROWSERS_PATH=0
  py fetch-order-via-ui-apis.py 1413307
"""
from __future__ import annotations

import base64
import json
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
OUT = HERE / "_ui-map"
API = "https://swiftsupply-api.epicordistribution.com"
UI = "https://swiftsupply.epicordistribution.com/Prophet21/#/"


def load_env():
    env = {}
    for line in (HERE / ".env").read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip() or line.strip().startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def jwt_claims(token: str) -> dict:
    try:
        part = token.split(".")[1]
        pad = "=" * (-len(part) % 4)
        return json.loads(base64.urlsafe_b64decode(part + pad).decode("utf-8"))
    except Exception:
        return {}


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
    page.wait_for_timeout(5000)
    for c in captured:
        if c.get("AccessToken"):
            return c["AccessToken"]
    raise RuntimeError("No AccessToken after login")


def req(ctx, method, url, headers, data=None):
    try:
        if method == "GET":
            r = ctx.get(url, headers=headers, timeout=30_000)
        elif method == "POST":
            r = ctx.post(url, headers=headers, data=data, timeout=60_000)
        elif method == "PUT":
            r = ctx.put(url, headers=headers, data=data, timeout=60_000)
        elif method == "DELETE":
            r = ctx.delete(url, headers=headers, timeout=30_000)
        else:
            raise ValueError(method)
        return {"url": url, "status": r.status, "body": r.text()[:4000]}
    except Exception as e:
        return {"url": url, "status": 0, "body": str(e)[:800]}


def main():
    so = (sys.argv[1] if len(sys.argv) > 1 else "").strip()
    if not so:
        print("Usage: py fetch-order-via-ui-apis.py <SO>")
        return 1
    env = load_env()
    OUT.mkdir(exist_ok=True)
    results = []

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(ignore_https_errors=True)
        page = context.new_page()
        token = login_token(page, env["P21_USERNAME"], env["P21_PASSWORD"])
        claims = jwt_claims(token)
        print("TOKEN_OK SessionId=", claims.get("P21.SessionId"))
        headers = {
            "Accept": "application/json",
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

        bases = [
            f"{API}/uiserver0",
            f"{API}",
        ]

        # Transaction API get Order
        for base in bases:
            body = json.dumps({
                "Name": "Order",
                "Transactions": [{
                    "Status": "New",
                    "DataElements": [{
                        "Name": "TABPAGE_1.order",
                        "Type": "Form",
                        "Keys": [],
                        "Rows": [{
                            "Edits": [{"Name": "order_no", "Value": so}]
                        }]
                    }]
                }]
            })
            for path in ("/api/v2/transaction/get", "/api/v2/definition/Order"):
                url = base + path
                method = "GET" if "definition" in path else "POST"
                row = req(context.request, method, url, headers, body if method == "POST" else None)
                results.append(row)
                print("TX", row["status"], path, (row["body"] or "")[:180].replace("\n", " "))

        # Interactive: create session + open Order window
        for base in bases:
            for sess_path in ("/api/ui/interactive/sessions", "/api/ui/interactive/v2/sessions", "/ui/interactive/v1/sessions"):
                row = req(
                    context.request,
                    "POST",
                    base + sess_path,
                    headers,
                    json.dumps({
                        "ResponseWindowHandlingEnabled": False,
                        "SessionType": "User",
                        "ClientPlatformApp": "SLST-UI-Bridge",
                    }),
                )
                results.append(row)
                print("SESS", row["status"], sess_path, (row["body"] or "")[:160].replace("\n", " "))

            for win_path, payload in (
                ("/api/ui/interactive/v2/window", {"ServiceName": "Order"}),
                ("/api/ui/interactive/v2/window", {"ServiceName": "OrderEntry"}),
                ("/api/ui/interactive/v2/window", {"Name": "w_order_entry"}),
                ("/api/ui/interactive/v2/window", {"Title": "Orders"}),
                ("/api/ui/interactive/v2/window", {"MenuId": 759}),
                ("/ui/interactive/v1/window", {"ServiceName": "Order"}),
                ("/ui/full/v1/window/", None),  # form tried separately
            ):
                data = None if payload is None else json.dumps(payload)
                row = req(context.request, "POST", base + win_path, headers, data)
                results.append(row)
                print("WIN", row["status"], win_path, str(payload)[:40], (row["body"] or "")[:160].replace("\n", " "))

            # form menuSearchString open (full UI shell)
            form_headers = dict(headers)
            form_headers["Content-Type"] = "application/x-www-form-urlencoded"
            for ms in ("m_orderentry", "Orders", "Order Entry"):
                url = base + "/ui/full/v1/window/"
                try:
                    r = context.request.post(url, headers=form_headers, data=f"menuSearchString={ms}", timeout=30_000)
                    row = {"url": url, "status": r.status, "body": r.text()[:2000], "ms": ms}
                except Exception as e:
                    row = {"url": url, "status": 0, "body": str(e), "ms": ms}
                results.append(row)
                print("FULLWIN", row["status"], ms, (row["body"] or "")[:160].replace("\n", " "))

        (OUT / f"fetch-apis-{so}.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
        browser.close()

    # Summarize any 200 that look like order data
    hits = [r for r in results if r.get("status") == 200 and ("order" in (r.get("body") or "").lower() or "WindowId" in (r.get("body") or "") or "Transactions" in (r.get("body") or ""))]
    print("HIT_COUNT", len(hits))
    for h in hits[:10]:
        print("HIT", h["url"][-80:], (h["body"] or "")[:200].replace("\n", " "))
    print("DONE", OUT / f"fetch-apis-{so}.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
