#!/usr/bin/env python3
import json, ssl, urllib.request, urllib.error
from pathlib import Path

def load_env():
    env = {}
    for line in Path(".env").read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.strip().startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env

def call(method, url, headers, body=None):
    data = None
    h = dict(headers)
    if body is not None:
        data = json.dumps(body).encode()
        h["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, context=ssl.create_default_context(), timeout=90) as r:
            t = r.read().decode("utf-8", "replace")
            try:
                return r.status, json.loads(t) if t else None, t
            except Exception:
                return r.status, None, t
    except urllib.error.HTTPError as e:
        t = e.read().decode("utf-8", "replace")
        try:
            return e.code, json.loads(t) if t else None, t
        except Exception:
            return e.code, None, t

env = load_env()
base = env["P21_BASE_URL"].rstrip("/")
st, js, _ = call("POST", f"{base}/api/security/token/v2", {"Accept": "application/json"}, {"username": env["P21_USERNAME"], "password": env["P21_PASSWORD"]})
auth = {"Accept": "application/json", "Authorization": f"Bearer {js['AccessToken']}"}
ui = f"{base}/uiserver0"
st, _, _ = call("POST", f"{ui}/api/ui/interactive/sessions", auth, {"SessionType": "Auto", "ResponseWindowHandlingEnabled": False, "ClientPlatformApp": "SLST-SO2", "SessionTimeout": 300})
if st == 409:
    call("DELETE", f"{ui}/api/ui/interactive/sessions", auth)
    call("POST", f"{ui}/api/ui/interactive/sessions", auth, {"SessionType": "Auto", "ResponseWindowHandlingEnabled": False, "ClientPlatformApp": "SLST-SO2", "SessionTimeout": 300})

so = "1289039"
st, opened, t = call("POST", f"{ui}/api/ui/interactive/v2/window", auth, {"ServiceName": "Order"})
print("open", st, opened.get("WindowId") if opened else t[:200])
wid = opened["WindowId"]
call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid, "ToolName": "Quick.Clear"})
stc, jsc, tc = call("PUT", f"{ui}/api/ui/interactive/v2/change", auth, {"WindowId": wid, "List": [{"TabName": "Order", "FieldName": "order_no", "Value": so, "DatawindowName": "order", "Row": 1}]})
print("change", stc)
st, win, _ = call("GET", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
for b in win.get("Data") or []:
    print("dw", b.get("Name"), "cols", len(b.get("Columns") or []), "rows", len(b.get("Data") or []))
    if b.get("Name") == "order" and (b.get("Data") or []):
        cols = b.get("Columns") or []
        row = b["Data"][0]
        d = {cols[i]: row[i] for i in range(min(len(cols), len(row)))}
        print({k: d.get(k) for k in ("order_no", "customer_name", "po_no", "taker", "taker_name")})
call("POST", f"{ui}/api/ui/interactive/v2/tools", auth, {"WindowId": wid, "ToolName": "Quick.Close"})
call("DELETE", f"{ui}/api/ui/interactive/v2/window?id={wid}", auth)
call("DELETE", f"{ui}/api/ui/interactive/sessions", auth)
