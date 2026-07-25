import json
from pathlib import Path

j = json.loads(
    Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-mcp-notify-fresh.json").read_text(
        encoding="utf-8"
    )
)
out = Path(r"C:\Users\Brice\Downloads\staging-tracker\.tmp-mcp-call-args.json")
out.write_text(json.dumps(j, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
print("wrote", out.stat().st_size)
ship = j["files"][1]["content"]
print(
    "fingerprint",
    ship.count('width="300"'),
    ship.count("20260722b"),
    ship.count("data-ogsc"),
    "PLACEHOLDER" in ship,
)
