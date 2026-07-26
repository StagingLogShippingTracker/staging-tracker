import json
from pathlib import Path

ARGS_PATH = Path(__file__).with_name("mcp_args_only.json")


def main() -> None:
    data = json.loads(ARGS_PATH.read_text(encoding="utf-8"))
    assert data["name"] == "notify-pm"
    assert data["project_id"] == "gdrpdiwykmnybmkadlrv"
    assert data["entrypoint_path"] == "index.ts"
    assert data["verify_jwt"] is True
    assert len(data["files"]) == 4
    names = [f["name"] for f in data["files"]]
    assert names == [
        "index.ts",
        "email-templates/ship-confirmation.ts",
        "email-templates/email-shared.ts",
        "email-templates/notification-email.ts",
    ]
    blob = "\n".join(f["content"] for f in data["files"])
    assert "PLACEHOLDER" not in blob
    assert "www.swiftsupply.ca" in blob
    assert "Prefer explicit tracking CTA" in blob
    assert "renderNotificationEmail" in blob
    print(json.dumps(data, ensure_ascii=False))


if __name__ == "__main__":
    main()
