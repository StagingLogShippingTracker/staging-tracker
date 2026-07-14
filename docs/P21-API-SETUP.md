# Prophet21 OData — enable API access for SLST

You can open the P21 **web UI** from any WiFi. The Order History **plugin** talks to the separate **API host**:

`https://swiftsupply-api.epicordistribution.com`

Login/token works from anywhere. Order data queries currently fail with:

> You are not authorized to access API. Please contact administrator to get access.

That is a **permission** issue, not a VPN issue. Warehouse logins (BRICE.JOHNSON, joe.laramee) can authenticate but cannot call OData until someone grants API rights **or** issues a Consumer Key.

## Path A — Enable OData on a user (P21 User Maintenance)

Needs User Maintenance rights (your warehouse accounts may not have this):

1. **User Maintenance** → user → **Application Security**
2. **Allow OData API Service** = **Yes** → Save
3. **Role Maintenance** → **Dataservice Permission** → allow order views (or Allow All)

## Path B — Consumer Key (recommended for integrations)

Epicor’s preferred service-account method. A **Consumer Key bypasses** Application Security / Dataservice Permission checks; access is controlled by the key’s API **scope** instead.

1. Open Middleware Admin:  
   https://swiftsupply-api.epicordistribution.com/admin/
2. Sign in with an account that has **SOA / Middleware Admin** rights (often IT/ERP admin, not a normal warehouse login).
3. Open **API Console** → **Register Consumer Key**
4. Type: **Service**, expire: **Never** (or long-lived)
5. Scope (semicolon-delimited), at least:  
   `/odataservice;/api/security`
6. Save and copy the **Client Secret** (GUID)

Then token with:

```json
{ "ClientSecret": "<consumer-key-guid>", "GrantType": "client_credentials" }
```

Put in Supabase Edge secrets:

| Secret | Value |
|--------|--------|
| `P21_BASE_URL` | `https://swiftsupply-api.epicordistribution.com` |
| `P21_CONSUMER_KEY` | *(the Client Secret GUID)* |

(Username/password not required for Consumer Key OData reads.)

## Path C — Ask IT (copy/paste email)

> Please create either (1) OData API access for an SLST service user, or (2) a Middleware Consumer Key (Service type) with scope covering `/odataservice` for the host `swiftsupply-api.epicordistribution.com`. We use it read-only for sales order header/lines in our warehouse Order History app. We do not need Interactive/Transaction write access.

## Path D — UI bridge (no IT grant)

When A–C are unavailable, run `scripts/p21-proxy/p21-ui-publisher.py` on a PC with a normal P21 web login. It authenticates like the browser, uses the Interactive Order Entry API (not OData), and publishes snapshots into `p21_order_cache` via `p21-publish`. Every SLST user then reads Order History from the cache.

See [scripts/p21-proxy/README.md](../scripts/p21-proxy/README.md).

## Purchase orders (4xxxxxx)

Site SO fields often hold a Swift **purchase order** (digits starting with `4`, e.g. `4276832`). `p21-order-insights` detects that heuristic and retrieves via Interactive **Purchase Order Entry** (`ServiceName: PurchaseOrder`, set `po_no` on `tp_1_dw_1` with TabName `DOCUMENT_LINK`):

| Display | Source |
|---------|--------|
| **PO** | PO number; when a linked SO is found on document grids: `PO (for {SO customer} SO# {n})` |
| **Customer** | Supplier (`vendor_name`) |
| **PM** | PO buyer (`buyer_name`, reformatted), or linked-SO Taker when enrich succeeds |

Manual P21 path for the same fields: **Report for Carmen** → filter PO Equal To → read Supplier + Sales Order Number → adjacent list filter Order No → read Customer Name + Taker. The edge function uses the Interactive PurchaseOrder window (same outcome for supplier/buyer). Full Carmen list/report IDs were not required once PurchaseOrder retrieve was confirmed.

Non-`4…` keys still use Order Entry Interactive → OData fallback.

## Paths that do **not** work as a bypass

| Idea | Why not |
|------|---------|
| Different warehouse password | Same 401 — OData not allowed for those users |
| VPN-only | API is already reachable from home WiFi |
| Chrome extension alone | Browser still hits the same OData 401 |
| Raw `/api/sales/orders` GETs | Hang or 401 without Dataservice rights |

## Hosts cheat sheet

| Purpose | URL |
|---------|-----|
| Web UI | `https://swiftsupply.epicordistribution.com/Prophet21/` |
| REST / OData / Interactive | `https://swiftsupply-api.epicordistribution.com` |
| Middleware Admin / API Console | `https://swiftsupply-api.epicordistribution.com/admin/` |
