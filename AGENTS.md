# AGENTS.md

## Cursor Cloud specific instructions

### What this is
Swift Staging Tracker — a static, dependency-free client-side PWA (plain HTML/CSS/vanilla JS, no build step, no package manager, no `node_modules`). Pages: `index.html` (dashboard), `stage.html`, `ship.html`, `reports.html`, `notifications.html`, `contacts.html`. Shared logic lives in the top-level `*.js` modules loaded directly via `<script>` tags in each HTML page.

### Services / backends
- **Static web server** (required): the only thing to run locally. There is no build step. Serve the repo root over http(s) — the app will not work from `file://` (breaks Supabase auth + PWA/service worker). Run: `python3 -m http.server 8000` from the repo root, then open `http://localhost:8000/index.html`.
- **Supabase** (required, hosted SaaS): all persistence, auth (email/password), and photo storage. The URL + public anon key are hardcoded in `config.js` (no `.env` files). Tables: `staging`, `shipped`, `changelog`; Storage bucket `freight-photos`. Anon reads are permitted, so the dashboard/logs render data without logging in; **creating/editing entries requires a logged-in user** (the entry form is hidden until sign-in).
- **`@supabase/supabase-js@2`** (required, external): loaded at runtime from the jsdelivr CDN in each HTML page — outbound internet access is required.
- **Make.com webhook** (optional): PM email/SMS notifications; failures are caught and non-blocking.

### Gotchas
- No lint / test / build tooling exists in this repo — there is nothing to install, lint, or build. "Running" the app means serving static files.
- Script tags use cache-busting query strings (e.g. `config.js?v=3.9`). After editing a JS file, bump the `?v=` in the referencing HTML (or hard-refresh) or the browser may serve a stale cached copy.
- To point at a different backend, edit `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `MAKE_EMAIL_WEBHOOK_URL` in `config.js`.
