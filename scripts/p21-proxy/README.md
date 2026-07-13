# Prophet21 → Supabase (works from anywhere)

Prophet21 Epicor is **only reachable on Swift’s private network** (office WiFi or VPN). Browsers and Supabase’s cloud cannot call it directly from home or cellular.

**Universal pattern:** one always-on Swift-network machine syncs P21 snapshots into Supabase; every user reads that cache in Order History.

## Why Swift WiFi “works” today

| Layer | On Swift WiFi | Off Swift network |
|-------|---------------|-------------------|
| P21 web UI (`…/Prophet21/#/`) | ✅ | ❌ |
| P21 REST/OData API (`…/api/security/token/v2`) | ✅ | ❌ |
| Local proxy (`127.0.0.1:8787`) | ✅ if proxy running | ❌ |
| Supabase `p21_order_cache` | ✅ | ✅ |

The web UI URL includes `/Prophet21/` for the SPA shell. **API calls use the site root**, not `/Prophet21`:

- Token: `https://swiftsupply.epicordistribution.com/api/security/token/v2`
- OData: `https://swiftsupply.epicordistribution.com/odataservice/odata/view/…`

Token requests must send `Accept: application/json` (otherwise P21 returns XML).

## Architecture

```
Swift PC (WiFi/VPN, always on)
  ├─ server.ps1 / server.mjs  → talks to P21 OData
  └─ sync-to-supabase.ps1     → pushes SO snapshots to Supabase

Supabase
  ├─ p21_order_cache          → 7-day JSON cache (all users read this)
  ├─ p21-ingest               → receives bulk sync from Swift PC
  └─ p21-order-insights       → serves cache (no live P21 from cloud)

Browser (any network)
  └─ p21.js → history.js Order History modal
```

## One-time setup

### 1. Local `.env` (`scripts/p21-proxy/.env`)

Copy `.env.example`. Required:

| Variable | Example |
|----------|---------|
| `P21_BASE_URL` | `https://swiftsupply.epicordistribution.com` |
| `P21_USERNAME` | Your P21 login |
| `P21_PASSWORD` | Your P21 password |
| `SUPABASE_URL` | Project URL |
| `SUPABASE_ANON_KEY` | Anon key |
| `P21_SYNC_KEY` | Random secret (match Supabase) |

### 2. Supabase Edge Function secrets

Dashboard → Edge Functions → Secrets:

| Secret | Value |
|--------|--------|
| `P21_SYNC_KEY` | Same as local `.env` |
| `P21_BASE_URL` | `https://swiftsupply.epicordistribution.com` (only if using cloud live fetch) |

Do **not** set `P21_ALLOW_CLOUD_LIVE=1` unless Supabase can reach P21 (it usually cannot). Default: cache-only from edge.

### 3. Swift network sync (keeps cache fresh)

On an **always-on PC at Swift**, every 5–15 minutes:

```powershell
cd scripts\p21-proxy
.\start-proxy.ps1          # window 1 — or Task Scheduler
.\sync-to-supabase.ps1     # window 2 — or schedule this
```

Optional: `.\install-p21-sync-task.ps1` registers a Windows scheduled task.

Verify: `.\test-p21.ps1` should print `TOKEN_OK=True`.

## Client flow (`p21.js`)

1. Read `p21_order_cache` in Supabase (**instant, any network**)
2. Background refresh via `p21-order-insights` if stale (returns cache; no cloud→P21 call)
3. Local proxy fallback for dev on Swift WiFi only

## Dashboard

https://supabase.com/dashboard/project/gdrpdiwykmnybmkadlrv/functions
