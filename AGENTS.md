# AGENTS.md

## Cursor Cloud specific instructions

### What this is
SLST — Staging Log & Shipping Tracker: a **static HTML/JS PWA** (vanilla JS, no framework, **no build step**) backed by a **hosted Supabase** project. Production is served from GitHub Pages. See `README.md` for the human workflow.

### Running the app (dev)
- Serve the repo root over HTTP (do **not** open via `file://` — `partials-loader.js` fetches `partials/*.html`, though it has inline `<script type="text/plain">` template fallbacks):
  - `python3 -m http.server 8000` from the repo root, then open `http://127.0.0.1:8000/index.html`.
- No dependencies to install: `python3` and `node` are pre-installed; the browser loads `@supabase/supabase-js@2` from the jsDelivr CDN, so **internet egress is required** at runtime.

### Live production backend — be careful
- `config.js` hardcodes the **live production** Supabase URL + anon key. Create/edit/ship/delete actions write to **real** production data, and shipping/notification flows can trigger **real PM SMS/email** via the Make.com webhook (`config.js` `MAKE_EMAIL_WEBHOOK_URL`, with real phone numbers in `PM_SMS_ROSTER`). Keep testing **read-only** unless you have explicit approval and credentials. Anonymous users are read-only; create/edit is gated behind Supabase email/password sign-in (no test credentials are provisioned in this environment).
- Console shows `502 / "Missing authorization header"` from the `removed-fn` edge function. This is the **optional**  (/Epicor ERP) enrichment and does **not** affect core staging/shipping functionality.

### Auth notes (non-obvious)
- The create/edit UI is gated **client-side** (`auth.js` `updateAuthUI` toggles `currentUser` / `#entryFormCard`). The `staging` table's RLS currently permits **anonymous** insert/delete via the anon key — so writes can hit production even without a real Supabase session. Do not write to production casually.
- Sign-in uses Supabase email/password. New accounts require **email confirmation**; unconfirmed accounts fail `signInWithPassword` with `email_not_confirmed`. To test the genuine authenticated path you need an already-confirmed account (confirm via the email link, or an admin confirms the user in the Supabase dashboard / via service-role admin API).

### Lint / test / build
- There is **no** `package.json`, bundler, formal test suite, or CI in this repo.
- Closest native check: `python3 scripts/audit-handlers.py` (verifies inline `on*=` handlers resolve to a loaded script). Note it currently reports pre-existing false positives (`MISSING: open` = the native `window.open` browser API) and exits non-zero — not caused by your changes.
- No build step — asset cache-busting is manual via `window.APP_ASSET_VERSIONS` in `config.js`.

### Optional / internal-network-only services (not needed for core testing)
- `supabase/functions/*` — Deno edge functions ( ERP), deployed via Supabase.
- `scripts/removed-proxy/-ui-publisher.py` — Playwright + Interactive UI publisher into `removed_table` (Swift/ credentials in local `.env`; see `scripts/removed-proxy/README.md`).
- PowerShell scripts under `scripts/` are Windows/Swift-network tooling.
