# SLST — Staging Log & Shipping Tracker

Static HTML/JS PWA backed by Supabase. Deployed to GitHub Pages at [staginglogshippingtracker.github.io/staging-tracker](https://staginglogshippingtracker.github.io/staging-tracker/).

## Single-folder workflow

**Work only in this folder.** It is the git repo, local dev copy, and what gets pushed to GitHub.

```
C:\Users\Brice\Downloads\staging-tracker
```

Do not keep a second copy of app files in `Downloads\` — edit here, commit here, push from here.

## Daily commands

Open PowerShell in this folder:

```powershell
# Check status
.\scripts\git.ps1 status

# Commit & push
.\scripts\git.ps1 add -A
.\scripts\git.ps1 commit -m "Your message"
.\scripts\git.ps1 push
```

Or use full Git after installing [Git for Windows](https://git-scm.com/download/win) — then `git` works everywhere.

## Local preview

Open `index.html` in a browser, or use a simple static server. Hard-refresh after JS/CSS changes (cache-bust query strings on assets).

## Secrets (never commit)

- `.env` files with credentials (gitignored)

## Integrations

- **Supabase** — `plugin-supabase-supabase` MCP (database)
- **Make.com** — `.cursor/mcp.json` + OAuth sign-in (scenarios, webhooks). See [docs/MAKE-MCP-SETUP.md](docs/MAKE-MCP-SETUP.md)

## Remote

- **GitHub:** https://github.com/StagingLogShippingTracker/staging-tracker
- **Supabase project:** `gdrpdiwykmnybmkadlrv`
