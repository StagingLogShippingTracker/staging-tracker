---
name: make-mcp
description: >-
  Manage Make.com scenarios, webhooks, and automations for SLST via the official
  Make MCP server. Use when the user asks to change Make.com scenarios, email
  webhooks, PM notifications, SMS routing, or Make integrations.
---

# Make.com MCP (SLST)

## When to use

- User mentions **Make.com**, **Make scenarios**, **webhooks**, or **email notifications** from the tracker
- Changing the shipping/PM email flow triggered by `sendPmEmailWebhook` in `config.js`
- Inspecting or updating Make scenarios without manual UI work

## MCP connection

This project includes `.cursor/mcp.json` pointing at Make's official MCP server (`https://mcp.make.com`).

Before using Make MCP tools:

1. **Cursor Settings → Tools & MCP** — confirm **make** is listed
2. If status is **Needs login**, click it and complete **OAuth** (pick your Make organization + scopes)
3. Check **MCP Logs** in the Output panel if connection fails

Token alternative (no OAuth): copy `.cursor/mcp.json.example`, set `MAKE_MCP_TOKEN` in Windows env vars, use the `make-token` entry.

## SLST context

| Item | Value |
|------|--------|
| Make zone | `us2` (webhook host: `hook.us2.make.com`) |
| Email webhook (client) | `MAKE_EMAIL_WEBHOOK_URL` in `config.js` |
| Client caller | `window.sendPmEmailWebhook()` in `config.js` |
| Used from | `operations.js`, `batch.js`, ship/notify flows |

The app **POSTs JSON** to the webhook; the Make scenario handles email/SMS formatting and delivery.

## Agent workflow

1. **Discover** — Use Make MCP tools to list scenarios; find the SLST email/notification scenario
2. **Read** — Inspect scenario inputs/outputs and module chain before editing
3. **Change** — Update scenario via MCP management tools (paid plan) or guide user in Make UI
4. **Sync code** — If webhook URL or payload shape changes, update `config.js` and callers
5. **Verify** — Confirm scenario is **Active** or **On-demand** (required for MCP tools)

## Payload contract (email webhook)

`sendPmEmailWebhook` sends arbitrary JSON from callers. Common fields include PM email, SO, customer, and message body. When changing the scenario, keep backward compatibility or update all JS callers in the same change.

### PO Notification email

PO Notifications use the same Make webhook as other PM emails (`sendPmEmailWebhook`): HTML body to the PM, CC warehouse, including photo attachments when present. Email-to-SMS is not used for this flow.

## Docs

- [Make MCP Server](https://developers.make.com/mcp-server)
- [Cursor + Make OAuth](https://developers.make.com/mcp-server/connect-using-oauth/usage-with-cursor)
- Project setup: `docs/MAKE-MCP-SETUP.md`
