---
name: make-mcp
description: >-
  Manage Make.com scenarios, webhooks, and automations for Swift Staging &
  Shipping Log via the official Make MCP server. Use when the user asks to
  change Make.com scenarios, email webhooks, PM notifications, or Make
  integrations.
---

# Make.com MCP (Swift Staging & Shipping Log)

## When to use

- User mentions **Make.com**, **Make scenarios**, **webhooks**, or **email notifications** from the tracker
- Changing the shipping/PM email flow invoked by Supabase Edge Function `notify-pm`
- Inspecting or updating Make scenarios without manual UI work

## MCP connection

This project includes `.cursor/mcp.json` pointing at Make's official MCP server (`https://mcp.make.com`).

Before using Make MCP tools:

1. **Cursor Settings → Tools & MCP** — confirm **make** is listed
2. If status is **Needs login**, click it and complete **OAuth** (pick your Make organization + scopes)
3. Check **MCP Logs** in the Output panel if connection fails

Token alternative (no OAuth): copy `.cursor/mcp.json.example`, set `MAKE_MCP_TOKEN` in Windows env vars, use the `make-token` entry.

## Product context

| Item | Value |
|------|--------|
| Make zone | `us2` (webhook host: `hook.us2.make.com`) |
| Scenario | `5572398` — Integration Webhooks, Microsoft 365 Email (Outlook) |
| Webhook storage | Edge secret `MAKE_EMAIL_WEBHOOK_URL` **or** `private.app_secrets` |
| Caller path | Flutter app (anon floor client OK) → `NotifyRepository` → Edge Function `notify-pm` |

The Flutter client never embeds the Make webhook URL. The Edge Function accepts the project **anon** key / anon JWT (warehouse floor; no user sign-in) or a signed-in user JWT, then POSTs JSON to Make. Email only — no SMS / email-to-SMS. **Do not** reintroduce client `currentSession` gates for notify.

## Agent workflow

1. **Discover** — Use Make MCP tools to list scenarios; find scenario **5572398**
2. **Read** — Inspect scenario inputs/outputs and module chain before editing
3. **Change** — Update scenario via MCP management tools (paid plan) or guide user in Make UI
4. **Sync secrets** — If the webhook URL changes, update the Edge secret and/or `private.app_secrets`
5. **Verify** — Confirm scenario is **Active** (required for delivery); keep Route WITH/WITHOUT photos mutually exclusive (`length(attachments)`)

## Payload contract

`notify-pm` forwards JSON from floor/Wear clients (anon or signed-in). Common fields: `to`, `cc`, `subject`, `body`, `attachments` (public photo URLs), `notification_type`, optional `pm_name`. Always set non-empty `cc` (default `warehouse1@swiftsupply.ca`).

## Docs

- [Make MCP Server](https://developers.make.com/mcp-server)
- [Cursor + Make OAuth](https://developers.make.com/mcp-server/connect-using-oauth/usage-with-cursor)
- Project setup: `docs/MAKE-MCP-SETUP.md`
