# Prophet21 → Supabase (works from anywhere)

Prophet21 Epicor is **only reachable on Swift’s private network** (office WiFi or VPN). Browsers and Supabase’s cloud cannot call it directly from home or cellular.

**Universal pattern (on-demand publish):** a warehouse PC on Swift WiFi runs the local P21 proxy. When someone opens Order History for an SO, the browser loads live insights from the proxy and **publishes** that snapshot into Supabase (`p21-publish`). Every other user (any network) reads `p21_order_cache`.

Optional bulk sync remains available once OData works.

## Why Swift WiFi matters

| Layer | On Swift WiFi | Off Swift network |
|-------|---------------|-------------------|
| P21 web UI (`…/Prophet21/#/`) | ✅ | ❌ |
| P21 REST/OData API | ✅ if OData enabled | ❌ |
| Local proxy (`127.0.0.1:8787`) | ✅ if proxy running | ❌ |
| Supabase `p21_order_cache` | ✅ | ✅ |
| Order History “Open in Prophet21” | Useful | Link only works on Swift network |

The web UI URL includes `/Prophet21/` for the SPA shell. **REST/OData calls use the site root**, not `/Prophet21`:

- Token: `https://swiftsupply.epicordistribution.com/api/security/token/v2`
- OData: `https://swiftsupply.epicordistribution.com/odataservice/odata/view/…`

Token requests must send `Accept: application/json` (otherwise P21 returns XML).

## Architecture

```
Swift warehouse PC (WiFi + optional VPN)
  ├─ start-proxy.ps1          → talks to P21
  └─ Browser opens Order History
        → local proxy fetch
        → p21-publish → Supabase cache

Any user / any network
  └─ Order History → p21_order_cache (read)
```

## Warehouse PC setup (one-time)

### 1. Local `.env` (`scripts/p21-proxy/.env`)

Copy `.env.example`. Required:

| Variable | Example |
|----------|---------|
| `P21_BASE_URL` | `https://swiftsupply.epicordistribution.com` |
| `P21_USERNAME` | Your P21 login |
| `P21_PASSWORD` | Your P21 password |
| `SUPABASE_URL` | Project URL |
| `SUPABASE_ANON_KEY` | Anon key |
| `P21_SYNC_KEY` | Random secret (only for optional bulk sync) |

### 2. Start the proxy when on Swift WiFi

```powershell
cd scripts\p21-proxy
.\start-proxy.ps1
```

Verify: `.\discover-p21-endpoints.ps1` — token should be OK; OData tables/views must also be OK for order data.

If OData stays **404** on WiFi alone, connect **FortiClient VPN** and/or ask IT to:

- Enable **Allow OData API Service** for the integration user
- Grant Dataservice permissions for order header/line views
- Confirm the correct middleware base URL

### 3. Use Order History as usual

Open any SO → Order History. With the proxy running:

1. Insights load from P21 (live)
2. Payload is published to Supabase for the whole team
3. Users off-network see the same snapshot afterward

Empty state includes **Open in Prophet21** for WiFi users even when API data is missing.

## Edge functions (Supabase)

| Function | Role |
|----------|------|
| `p21-order-insights` | Serve cache (no live P21 from cloud by default) |
| `p21-publish` | Client publishes proxy payloads (JWT/anon) |
| `p21-ingest` | Bulk sync from Swift PC (`x-p21-sync-key`) |

Dashboard: https://supabase.com/dashboard/project/gdrpdiwykmnybmkadlrv/functions

## Optional bulk sync

Once OData works, schedule on an always-on Swift PC:

```powershell
.\start-proxy.ps1
.\sync-to-supabase.ps1
# or
.\install-p21-sync-task.ps1
```

## Client flow (`p21.js`)

1. Read `p21_order_cache` (any network)
2. If miss/stale → try local proxy → on success, `POST` `p21-publish`
3. Else → edge cache / empty state + Open in Prophet21
