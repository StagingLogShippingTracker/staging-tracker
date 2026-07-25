import json
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parent.parent
payload = json.loads((ROOT / "_mcp_deploy" / "mcp_args_only.json").read_text(encoding="utf-8"))

req = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {"name": "deploy_edge_function", "arguments": payload},
}

# CallMcpTool equivalent via Cursor MCP - this script is only for local fallback.
# Primary deploy uses CallMcpTool from the agent.
print("PAYLOAD_KEYS", sorted(payload.keys()))
print("FILE_COUNT", len(payload["files"]))
