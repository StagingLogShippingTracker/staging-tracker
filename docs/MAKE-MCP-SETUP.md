# Make.com MCP setup for Cursor

Connect Cursor to your Make.com account so the agent can list, run, and (on paid plans) edit scenarios.

## 1. Project config (already added)

File: `.cursor/mcp.json`

```json
{
  "mcpServers": {
    "make": {
      "url": "https://mcp.make.com"
    }
  }
}
```

Reload Cursor or open **Settings → Tools & MCP** after pulling this file.

## 2. Sign in (one-time)

1. Open **Cursor Settings** (`Ctrl+Shift+J`)
2. Go to **Tools & MCP**
3. Under **MCP Tools**, find **make**
4. Click **Needs login** → **Open**
5. In Make OAuth: choose your **organization**, select **scopes**, click **Allow**
6. Return to Cursor — status should show connected

## 3. Scopes to enable

For SLST work, enable at least:

- **Run scenarios** — trigger/test flows
- **Read scenarios** — inspect the email webhook scenario
- **Write scenarios** (paid plan) — let the agent edit modules

## 4. Token method (optional)

If OAuth does not work:

1. Make profile → **API / MCP access** → **Add token** → type **MCP Token**
2. Set Windows env var: `MAKE_MCP_TOKEN` = your token
3. Replace `.cursor/mcp.json` with the `make-token` block from `.cursor/mcp.json.example`

Zone for Swift: **us2** (`us2.make.com`).

## 5. SLST email scenario

The site calls:

- URL: `MAKE_EMAIL_WEBHOOK_URL` in `config.js`
- Function: `sendPmEmailWebhook()` in `config.js`

Keep the webhook URL in sync if you recreate the scenario in Make.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| make not in MCP list | Restart Cursor; confirm `.cursor/mcp.json` exists |
| Needs login loops | Try `https://mcp.make.com/stateless` in mcp.json |
| No scenario tools | Scenario must be **Active** or **On-demand** |
| Timeouts | Scenario runs continue in Make; use execution ID tools |

Reference: https://developers.make.com/mcp-server
