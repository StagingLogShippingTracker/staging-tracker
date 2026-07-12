# Prophet21 → Supabase (works from anywhere)

Prophet21 is only reachable on Swift’s network. **All site users** get insights from a **Supabase clone** (`p21_order_cache`), not from their browser connecting to P21.

## Live on Supabase (project `gdrpdiwykmnybmkadlrv`)

| Resource | Status |
|----------|--------|
| Table `p21_order_cache` | Created — 7-day cached SO snapshots, readable by the app |
| Edge Function `p21-order-insights` | Deployed — on-demand fetch + cache refresh |
| Edge Function `p21-ingest` | Deployed — receives bulk sync from Swift network |

## One manual step: Edge Function secrets

The Supabase plugin cannot set secrets. In **Dashboard → Edge Functions → Secrets**, add:

| Secret | Value |
|--------|--------|
| `P21_BASE_URL` | `https://swiftsupply.epicordistribution.com/Prophet21` |
| `P21_USERNAME` | Your P21 login |
| `P21_PASSWORD` | Your P21 password |
| `P21_SYNC_KEY` | Same as `P21_SYNC_KEY` in `scripts/p21-proxy/.env` |

## Swift network sync (keeps cache fresh)

On an **always-on PC at Swift** (WiFi or VPN), every 5–15 minutes:

```powershell
cd scripts\p21-proxy
.\start-proxy.ps1          # in one window (or Task Scheduler)
.\sync-to-supabase.ps1     # in another, or schedule this
```

`sync-to-supabase.ps1` reads all SOs from staging/shipped, fetches P21 via the local proxy, and pushes into Supabase.

## Client flow (`p21.js`)

1. Read `p21_order_cache` in Supabase (**instant, any network**)
2. Background refresh via `p21-order-insights` if stale
3. Local proxy fallback for dev only

## Dashboard link

https://supabase.com/dashboard/project/gdrpdiwykmnybmkadlrv/functions
