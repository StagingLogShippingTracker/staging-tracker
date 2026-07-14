# Prophet21 OData — enable API access for SLST

You can open the P21 **web UI** from any WiFi. The Order History **plugin** talks to the separate **API host**:

`https://swiftsupply-api.epicordistribution.com`

Login/token works from anywhere. Order data queries currently fail with:

> You are not authorized to access API. Please contact administrator to get access.

That means the P21 **user** needs API flags turned on (not VPN).

## Fix in Prophet21 (one-time)

Using an admin account (or your own if you have User Maintenance rights):

1. Open **User Maintenance**
2. Open user **BRICE.JOHNSON** (or a dedicated integration user)
3. Tab **Application Security**
4. Set **Allow OData API Service** = **Yes** → Save
5. Note the user’s **Role**
6. Open **Role Maintenance** → that role → **Dataservice Permission**
7. Allow at least:
   - `p21_view_oe_hdr` or `oe_hdr`
   - `p21_view_oe_line` / `oe_line` (or **Allow All** for simplicity)
8. Save

## Verify

On any PC (home WiFi is fine):

```powershell
cd scripts\p21-proxy
.\discover-p21-endpoints.ps1
```

Expect Token OK and OData OK (not 401).

## Supabase secrets (cloud plugin — no Swift PC required)

Dashboard → Project → Edge Functions → Secrets:

| Secret | Value |
|--------|--------|
| `P21_BASE_URL` | `https://swiftsupply-api.epicordistribution.com` |
| `P21_USERNAME` | `BRICE.JOHNSON` |
| `P21_PASSWORD` | *(your P21 password)* |
| `P21_SYNC_KEY` | *(optional; only for bulk sync)* |

After secrets + OData permission are set, Order History loads P21 live through Supabase for **every user on any network**.

## Hosts cheat sheet

| Purpose | URL |
|---------|-----|
| Web UI (browser) | `https://swiftsupply.epicordistribution.com/Prophet21/` |
| REST / OData (plugin) | `https://swiftsupply-api.epicordistribution.com` |
