"""Deploy notify-pm via Supabase MCP using mcp_args_only.json."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "_mcp_deploy"))

from _mcp_deploy_two import McpClient, get_access_token  # noqa: E402

PAYLOAD_PATH = ROOT / "_mcp_deploy" / "mcp_args_only.json"


def main() -> None:
    payload = json.loads(PAYLOAD_PATH.read_text(encoding="utf-8"))
    combined = "".join(f["content"] for f in payload["files"])
    checks = {
        "four_files": len(payload["files"]) == 4,
        "no_placeholder": "PLACEHOLDER" not in combined,
        "oswald": "Oswald" in combined,
        "about_slst": "About SLST" in combined,
        "deno": "Deno.serve" in combined,
    }
    print("PRE_DEPLOY_VERIFY", "PASS" if all(checks.values()) else checks)

    mcp = McpClient(get_access_token())
    mcp.initialize()
    print("MCP_SESSION_OK", bool(mcp.session_id))

    deploy_result = mcp.call_tool("deploy_edge_function", payload)
    print("DEPLOY_RESULT", json.dumps(deploy_result))

    prev_version = 28
    get_result = mcp.call_tool(
        "get_edge_function",
        {"project_id": payload["project_id"], "function_slug": payload["name"]},
    )

    version = None
    if isinstance(deploy_result, dict):
        version = deploy_result.get("version")
    if isinstance(get_result, dict):
        version = version or get_result.get("version")

    combined_get = ""
    if isinstance(get_result, dict):
        for item in get_result.get("files") or []:
            combined_get += item.get("content") or ""

    verify = {
        "version_increased": isinstance(version, int) and version > prev_version,
        "has_oswald": "Oswald" in combined_get,
        "has_about_slst": "About SLST" in combined_get,
        "no_placeholder": "PLACEHOLDER" not in combined_get,
    }
    print("POST_DEPLOY_VERIFY", "PASS" if all(verify.values()) else verify)
    print("VERSION", version)
    print("PREV_VERSION", prev_version)


if __name__ == "__main__":
    main()
