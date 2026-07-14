"""
Load one SO via Prophet21 Interactive API (ServiceName=Order) after web UI login.
No OData grant required.

Usage:
  set PLAYWRIGHT_BROWSERS_PATH=0
  set PYTHONIOENCODING=utf-8
  py interactive-order.py 1413307
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
    raise RuntimeError("No AccessToken after login")


def api(ctx, method, path, headers, body=None):
    url = API + path
    kwargs = {"timeout": 90_000, "headers": headers}
    if body is not None:
        kwargs["data"] = body if isinstance(body, (str, bytes)) else json.dumps(body)
    try:
        if method == "GET":
            r = ctx.get(url, **kwargs)
        elif method == "POST":
            r = ctx.post(url, **kwargs)
        elif method == "PUT":
            r = ctx.put(url, **kwargs)
        elif method == "DELETE":
            r = ctx.delete(url, **kwargs)
        else:
            raise ValueError(method)
        text = r.text()
        try:
            parsed = json.loads(text)
        except Exception:
            parsed = None
        return {"status": r.status, "url": url, "body": text[:25000], "json": parsed}
    except Exception as e:
        return {"status": 0, "url": url, "body": str(e), "json": None}


def pick_edits(obj, out=None):
    if out is None:
        out = {}
    if isinstance(obj, dict):
        name = obj.get("Name") or obj.get("FieldName") or obj.get("name")
        value = obj.get("Value") if "Value" in obj else obj.get("value")
        if isinstance(name, str) and value is not None and name not in ("windowid", "WindowId"):
            out[name] = value
        for v in obj.values():
            pick_edits(v, out)
    elif isinstance(obj, list):
        for v in obj:
            pick_edits(v, out)
    return out


def summarize(flat: dict, so: str) -> dict:
    def g(*keys):
        for k in keys:
            if flat.get(k) not in (None, ""):
                return flat[k]
        return None

    return {
        "orderNo": g("order_no", "OrderNo") or so,
        "customerId": g("customer_id", "CustomerId"),
        "customerName": g("customer_name", "ship_to_name", "CustomerName"),
        "poNo": g("po_no", "customer_po_no", "PoNo"),
        "orderDate": g("order_date", "OrderDate"),
        "status": g("order_status", "completed", "delete_flag", "Status"),
        "shipTo": g("ship_to_name", "ShipToName"),
        "shipVia": g("ship_via", "carrier_id"),
        "warehouse": g("location_id", "source_loc_id"),
        "projectId": g("project_id"),
        "taker": g("taker"),
    }


def publish(env, so, payload):
    url = (env.get("SUPABASE_URL") or "").rstrip("/")
    key = env.get("SUPABASE_ANON_KEY") or ""
    if not url or not key:
        print("WARN: missing SUPABASE_URL/ANON_KEY - skip publish")
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
            print("PUBLISH", resp.status, resp.read()[:300])
            return True
    except Exception as e:
        print("PUBLISH_FAIL", e)
        return False


def main():
    so = (sys.argv[1] if len(sys.argv) > 1 else "").strip()
    if not so:
        print("Usage: py interactive-order.py <SO>")
        return 1
    env = load_env()
    OUT.mkdir(exist_ok=True)
    log = []

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(ignore_https_errors=True)
        page = context.new_page()
        token = login_token(page, env["P21_USERNAME"], env["P21_PASSWORD"])
        print("TOKEN_OK")
        headers = {
            "Accept": "application/json",
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

        open_r = api(
            context.request,
            "POST",
            "/api/ui/interactive/v2/window",
            headers,
            {"ServiceName": "Order"},
        )
        log.append(("open", open_r))
        print("OPEN", open_r["status"], (open_r["body"] or "")[:220].replace("\n", " "))
        wid = (open_r.get("json") or {}).get("WindowId")
        if not wid:
            print("FAIL: no WindowId")
            (OUT / f"interactive-{so}.json").write_text(json.dumps(log, indent=2, default=str), encoding="utf-8")
            browser.close()
            return 2
        print("WINDOWID", wid)

        state = api(context.request, "GET", f"/api/ui/interactive/v2/window?id={wid}", headers)
        log.append(("state", state))
        print("STATE", state["status"], (state["body"] or "")[:300].replace("\n", " "))
        state_flat = pick_edits(state.get("json") or {})
        # Guess datawindow name from state keys if present
        dw_guesses = ["order", "FORM", "form", "TABPAGE_1.order", "d_order"]
        for k in state_flat:
            if "order" in k.lower() and k not in dw_guesses:
                dw_guesses.insert(0, k)

        change_payloads = []
        for tab in ("Order", "FORM", "TABPAGE_1", "Orders"):
            for dw in ("order", "form", "TABPAGE_1.order", "d_order"):
                change_payloads.append(
                    {
                        "WindowId": wid,
                        "List": [
                            {
                                "TabName": tab,
                                "FieldName": "order_no",
                                "Value": so,
                                "DatawindowName": dw,
                            }
                        ],
                    }
                )
        # v1 variants
        v1_payloads = []
        for dw in ("order", "d_order", "form"):
            v1_payloads.append(
                {
                    "WindowId": wid,
                    "ChangeRequests": [
                        {"DataWindowName": dw, "FieldName": "order_no", "Value": so}
                    ],
                }
            )

        change_ok = None
        for i, payload in enumerate(change_payloads):
            r = api(context.request, "PUT", "/api/ui/interactive/v2/change", headers, payload)
            log.append((f"change{i}", {"status": r["status"], "body": r["body"][:500], "url": r["url"]}))
            print("CHANGE", i, r["status"], payload["List"][0]["TabName"], payload["List"][0]["DatawindowName"], (r["body"] or "")[:160].replace("\n", " "))
            if r["status"] == 200 and "error" not in (r["body"] or "").lower():
                change_ok = r
                # Stop early on clear success with populated fields
                flat_try = pick_edits(r.get("json") or {})
                if flat_try.get("customer_id") or flat_try.get("customer_name") or flat_try.get("order_no") == so:
                    break
            # Don't hammer forever — try first 8 combos thoroughly
            if i >= 7 and change_ok:
                break
            if i >= 15:
                break

        if change_ok is None:
            for i, payload in enumerate(v1_payloads):
                r = api(context.request, "PUT", "/api/ui/interactive/v1/change", headers, payload)
                log.append((f"v1change{i}", {"status": r["status"], "body": r["body"][:500]}))
                print("V1CHANGE", i, r["status"], (r["body"] or "")[:160].replace("\n", " "))
                if r["status"] == 200:
                    change_ok = r
                    break
            # also try path under /ui/
            if change_ok is None:
                for i, payload in enumerate(v1_payloads[:2]):
                    r = api(context.request, "PUT", "/ui/interactive/v1/change", headers, payload)
                    log.append((f"uiv1change{i}", {"status": r["status"], "body": r["body"][:500]}))
                    print("UI_V1CHANGE", i, r["status"], (r["body"] or "")[:160].replace("\n", " "))

        data = api(context.request, "GET", f"/api/ui/interactive/v2/data?id={wid}", headers)
        log.append(("data", {"status": data["status"], "body": data["body"][:5000]}))
        print("DATA", data["status"], (data["body"] or "")[:400].replace("\n", " "))

        data2 = api(context.request, "GET", f"/api/ui/interactive/v1/data?id={wid}", headers)
        log.append(("data_v1", {"status": data2["status"], "body": data2["body"][:5000]}))
        print("DATA_V1", data2["status"], (data2["body"] or "")[:400].replace("\n", " "))

        api(context.request, "DELETE", f"/api/ui/interactive/v2/window?id={wid}", headers)
        browser.close()

    flat = {}
    for name, r in log:
        body = r.get("body")
        if not body:
            continue
        try:
            pick_edits(json.loads(body) if isinstance(body, str) else body, flat)
        except Exception:
            pass
    for r in (change_ok, data, data2, state):
        if r and r.get("json"):
            pick_edits(r["json"], flat)

    header = summarize(flat, so)
    found = bool(
        header.get("customerId")
        or header.get("customerName")
        or flat.get("order_no") == so
        or (change_ok and so in (change_ok.get("body") or ""))
    )
    payload = {
        "found": bool(found),
        "so": so,
        "matchedBy": "interactive-api",
        "header": header if found else None,
        "lines": [],
        "source": "ui-bridge-interactive",
        "fetchedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "flatSample": {k: flat[k] for k in list(flat)[:50]},
    }
    (OUT / f"interactive-{so}.json").write_text(
        json.dumps({"log": log, "payload": payload}, indent=2),
        encoding="utf-8",
    )
    print("FOUND", found, "FIELDS", len(flat), "header", header)
    if found:
        publish(env, so, payload)
        return 0
    print("Inspect", OUT / f"interactive-{so}.json")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
