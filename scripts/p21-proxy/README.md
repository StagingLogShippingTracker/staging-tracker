# Prophet21 → SLST (no IT OData grant)

IT will not enable OData/Consumer Key for warehouse users. Use the **UI bridge** instead: it logs into Prophet21 the same way you do in a browser, reads Order Entry through the Interactive API, and publishes into Supabase so every SLST user can see Order Insights.

## What works today

| Path | Status |
|------|--------|
| OData / Consumer Key | Blocked (`You are not authorized to access API`) |
| **UI bridge** (`p21-ui-publisher.py`) | **Working** — published SO `1413307` (283 lines) into `p21_order_cache` |
| Local OData proxy | Still blocked without Dataservice permission |

Prophet21 hosts (reachable from any WiFi):

| Host | Role |
|------|------|
| `swiftsupply.epicordistribution.com` | Web UI login |
| `swiftsupply-api.epicordistribution.com` | Token + Interactive UI server |

## One-time setup (any PC with your P21 login)

```powershell
cd scripts\p21-proxy
py -m pip install playwright
$env:PLAYWRIGHT_BROWSERS_PATH = '0'
py -m playwright install chromium
copy .env.example .env
# Edit .env: P21_USERNAME, P21_PASSWORD, SUPABASE_URL, SUPABASE_ANON_KEY
```

## Publish orders into the shared cache

```powershell
$env:PLAYWRIGHT_BROWSERS_PATH = '0'
$env:PYTHONIOENCODING = 'utf-8'
py p21-ui-publisher.py 1413307
py p21-ui-publisher.py 1413307 1413791 1413834
```

After a successful publish, anyone on any network opens **Order History** and sees Prophet21 insights for that SO (no VPN, no OData).

## How it works

```
Your PC (P21 web login)
  → Playwright login → Bearer token
  → Interactive Auto session on uiserver0
  → Open Order Entry (ServiceName=Order)
  → Set order_no (Row=1) to retrieve existing SO
  → Read header + lines
  → POST Supabase p21-publish → p21_order_cache
Any SLST user
  → p21.js reads cache / edge function
```

## Security notes

- Keep `.env` local (gitignored). Do not commit passwords.
- Prefer a dedicated service user if one is allowed without OData; otherwise your normal web login works.
- Rotate any password that was pasted into chat.

## Optional / older scripts

- `start-proxy.ps1` / `server.mjs` — OData proxy (only useful after Dataservice is enabled)
- `ui-bridge.py`, `interactive-*.py` — research probes; prefer `p21-ui-publisher.py`
