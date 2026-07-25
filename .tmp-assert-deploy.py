import json
from pathlib import Path

j = json.loads(
    Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-mcp-call-args.json").read_text(
        encoding="utf-8"
    )
)
assert all("PLACEHOLDER" not in f["content"] for f in j["files"])
ship = j["files"][1]["content"]
assert "20260722b" in ship
assert "storage/v1/object/public/email-assets" in ship
assert 'width="300"' in ship
assert "data-ogsc" in ship
assert "color-scheme" in ship
print("ASSERT_OK")
print(j["project_id"], j["name"], j["entrypoint_path"], j["verify_jwt"], len(j["files"]))
