# Prophet21 → SLST Order History (internet API)

Prophet21 has two public hosts:

| Host | Role |
|------|------|
| `swiftsupply.epicordistribution.com` | Browser UI (`/Prophet21/#/`) |
| `swiftsupply-api.epicordistribution.com` | Token + OData + Entity APIs |

Both are reachable from **any WiFi** (verified from off-site). No VPN is required for network access.

## What still blocks Order Insights

Token auth succeeds, but OData returns:

`You are not authorized to access API`

Fix: enable **Allow OData API Service** + Dataservice permissions for the P21 user. See [docs/P21-API-SETUP.md](../../docs/P21-API-SETUP.md).

## Architecture (after OData is enabled)

```
Any user browser
  → p21.js → Supabase Edge p21-order-insights
      → (optional cache) p21_order_cache
      → live → swiftsupply-api.epicordistribution.com
```

Swift-PC proxy remains optional (local cache warm / bulk sync).

## Local `.env`

```
P21_BASE_URL=https://swiftsupply-api.epicordistribution.com
P21_USERNAME=...
P21_PASSWORD=...
```

## Quick test

```powershell
.\discover-p21-endpoints.ps1
.\test-p21.ps1
```

## Optional proxy

`.\start-proxy.ps1` — still useful for on-demand publish and debugging.
