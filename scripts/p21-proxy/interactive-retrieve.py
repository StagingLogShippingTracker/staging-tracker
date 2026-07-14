"""
Open Order Entry Interactive window, set order_no, run retrieve tools, publish.
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


def api(ctx, method, path, headers, body=None):
    url = API + path
    kwargs = {"timeout": 120_000, "headers": headers}
    if body is not None:
        kwargs["data"] = body if isinstance(body, str) else json.dumps(body)
    fn = {"GET": ctx.get, "POST": ctx.post, "PUT": ctx.put, "DELETE": ctx.delete}[method]
    try:
        r = fn(url, **kwargs)
        text = r.text()
        try:
            parsed = json.loads(text)
        except Exception:
            parsed = None
        return {"status": r.status, "body": text[:30000], "json": parsed}
    except Exception as e:
        return {"status": 0, "body": str(e), "json": None}


def rows_to_dicts(data_block):
    """Convert Interactive Datawindows Data[] entries to list of dicts."""
    out = []
    if not isinstance(data_block, list):
        return out
    for block in data_block:
        cols = block.get("Columns") or []
        for row in block.get("Data") or []:
            d = {"_dw": block.get("Name"), "_full": block.get("FullName")}
            for i, c in enumerate(cols):
                if i < len(row):
                    d[c] = row[i]
            out.append(d)
    return out


def publish(env, so, payload):
    url = (env.get("SUPABASE_URL") or "").rstrip("/")
    key = env.get("SUPABASE_ANON_KEY") or ""
    if not url or not key:
        print("WARN: no supabase config")
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
        print("Usage: py interactive-retrieve.py <SO>")
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

        open_r = api(context.request, "POST", "/api/ui/interactive/v2/window", h, {"ServiceName": "Order"})
        wid = (open_r.get("json") or {}).get("WindowId")
        print("OPEN", open_r["status"], "WID", wid)
        if not wid:
            browser.close()
            return 2

        # List tools (window + order dw + order_no field)
        for q in (
            f"/api/ui/interactive/v2/tools?windowId={wid}",
            f"/api/ui/interactive/v2/tools?windowId={wid}&dwName=order",
            f"/api/ui/interactive/v2/tools?windowId={wid}&dwName=order&fieldName=order_no&row=0",
            f"/api/ui/interactive/v2/tools?windowId={wid}&dwName=order&fieldName=order_no&row=1",
        ):
            t = api(context.request, "GET", q, h)
            print("TOOLS", t["status"], q.split("?")[-1][:80], (t["body"] or "")[:300].replace("\n", " "))
            (OUT / "tools-sample.json").write_text(t["body"] or "", encoding="utf-8")

        # Set order_no
        ch = api(
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
                        "ValueType": "Data",
                    }
                ],
            },
        )
        print("CHANGE", ch["status"], (ch["body"] or "")[:250].replace("\n", " "))

        # Try pressing Enter-like tools / common retrieve names
        tool_names = [
            "cb_retrieve",
            "retrieve",
            "Retrieve",
            "open",
            "Open",
            "cb_open",
            "ue_retrieve",
            "ue_open",
            "m_fileopen",
            "m_open",
            "pb_retrieve",
            "find",
            "Find",
            "search",
            "ok",
            "OK",
        ]
        # Also parse tools list if JSON
        try:
            tools_json = json.loads((OUT / "tools-sample.json").read_text(encoding="utf-8") or "[]")
            if isinstance(tools_json, dict):
                tools_json = tools_json.get("Tools") or tools_json.get("tools") or tools_json.get("Data") or []
            if isinstance(tools_json, list):
                for item in tools_json:
                    if isinstance(item, dict):
                        n = item.get("Name") or item.get("ToolName") or item.get("Id")
                        if n:
                            tool_names.insert(0, n)
                    elif isinstance(item, str):
                        tool_names.insert(0, item)
        except Exception:
            pass

        tried = set()
        for name in tool_names:
            if name in tried:
                continue
            tried.add(name)
            payloads = [
                {"WindowId": wid, "ToolName": name},
                {"WindowId": wid, "Name": name},
                {"windowId": wid, "toolName": name, "dwName": "order"},
                {"WindowId": wid, "ToolName": name, "DatawindowName": "order"},
            ]
            for payload in payloads:
                r = api(context.request, "POST", "/api/ui/interactive/v2/tools", h, payload)
                if r["status"] == 0:
                    continue
                print("RUNTOOL", r["status"], name, str(payload)[:60], (r["body"] or "")[:180].replace("\n", " "))
                if r["status"] == 200:
                    break
            if len(tried) > 25:
                break

        data = api(context.request, "GET", f"/api/ui/interactive/v2/data?id={wid}", h)
        print("DATA", data["status"], (data["body"] or "")[:400].replace("\n", " "))
        (OUT / f"retrieve-data-{so}.json").write_text(data["body"] or "", encoding="utf-8")

        # Also re-get window state Data section
        state = api(context.request, "GET", f"/api/ui/interactive/v2/window?id={wid}", h)
        (OUT / f"retrieve-state-{so}.json").write_text(state["body"] or "", encoding="utf-8")

        api(context.request, "DELETE", f"/api/ui/interactive/v2/window?id={wid}", h)
        browser.close()

    rows = []
    for src in (data, state):
        j = src.get("json")
        if not j:
            continue
        block = j.get("Data") if isinstance(j.get("Data"), list) else None
        if block is None and isinstance(j.get("Definition"), dict):
            # state embeds Data alongside Definition in earlier capture - check top-level
            pass
        if block:
            rows.extend(rows_to_dicts(block))
        # some responses nest Data under other keys
        if isinstance(j, dict) and "Data" in j and isinstance(j["Data"], list):
            rows.extend(rows_to_dicts(j["Data"]))

    # Parse from raw files if needed
    for fname in (f"retrieve-data-{so}.json", f"retrieve-state-{so}.json"):
        pth = OUT / fname
        if not pth.exists():
            continue
        try:
            j = json.loads(pth.read_text(encoding="utf-8"))
            if isinstance(j.get("Data"), list):
                rows.extend(rows_to_dicts(j["Data"]))
        except Exception:
            pass

    order_row = next((r for r in rows if r.get("_dw") == "order" and str(r.get("order_no") or "") == so), None)
    if not order_row:
        order_row = next((r for r in rows if r.get("_dw") == "order" and r.get("customer_id")), None)
    item_rows = [r for r in rows if r.get("_dw") == "items" and r.get("oe_order_item_id")]

    print("ORDER_ROW", {k: order_row.get(k) for k in ("order_no", "customer_id", "customer_name", "po_no", "taker")} if order_row else None)
    print("ITEM_COUNT", len(item_rows))

    found = bool(order_row and (order_row.get("customer_id") or order_row.get("customer_name") or order_row.get("order_no") == so))
    payload = {
        "found": found,
        "so": so,
        "matchedBy": "interactive-retrieve",
        "header": None
        if not order_row
        else {
            "orderNo": order_row.get("order_no") or so,
            "customerId": order_row.get("customer_id"),
            "customerName": order_row.get("customer_name"),
            "poNo": order_row.get("po_no"),
            "orderDate": order_row.get("order_date"),
            "status": order_row.get("validation_status") or order_row.get("cancel_flag"),
            "shipTo": order_row.get("ship_to_name"),
            "warehouse": order_row.get("sales_loc_id"),
            "projectId": order_row.get("ufc_oe_hdr_ud_project"),
            "taker": order_row.get("taker"),
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
            for r in item_rows[:200]
        ],
        "source": "ui-bridge-interactive",
        "fetchedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    (OUT / f"payload-interactive-{so}.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print("FOUND", found)
    if found:
        publish(env, so, payload)
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
