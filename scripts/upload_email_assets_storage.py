"""Upload assets/email PNGs to Supabase Storage bucket email-assets (public read)."""
from __future__ import annotations

import json
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "email"
PROJECT_URL = "https://gdrpdiwykmnybmkadlrv.supabase.co"
ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdkcnBkaXd5a21ueWJta2FkbHJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1MjMyMTIsImV4cCI6MjA5NjA5OTIxMn0.Z7ih_vQic1GtzCyZmTEV-RWJnmuaNZQDfOV2_Fvan5g"
)
BUCKET = "email-assets"


def upload(name: str, data: bytes, content_type: str = "image/png") -> None:
    url = f"{PROJECT_URL}/storage/v1/object/{BUCKET}/{name}"
    req = urllib.request.Request(
        url,
        data=data,
        method="POST",
        headers={
            "Authorization": f"Bearer {ANON_KEY}",
            "apikey": ANON_KEY,
            "Content-Type": content_type,
            "x-upsert": "true",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            print("OK", name, resp.status, resp.read()[:120])
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print("FAIL", name, e.code, body)
        raise SystemExit(1) from e


def main() -> None:
    if not ASSETS.is_dir():
        raise SystemExit(f"Missing {ASSETS}")
    files = sorted(ASSETS.glob("*.png"))
    if not files:
        raise SystemExit("No PNG files in assets/email")
    for path in files:
        upload(path.name, path.read_bytes())
    print("uploaded", len(files), "files")


if __name__ == "__main__":
    main()
