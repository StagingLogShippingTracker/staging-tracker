"""Regenerate brand/staging-shipping-logo-transparent.png from main dashboard logo."""
from pathlib import Path

from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "staging-shipping-logo.png"
DST = ROOT / "brand" / "staging-shipping-logo-transparent.png"
TOLERANCE = 52


def color_dist(a, b):
    return abs(int(a[0]) - int(b[0])) + abs(int(a[1]) - int(b[1])) + abs(int(a[2]) - int(b[2]))


def main():
    if not SRC.exists():
        raise SystemExit(f"Source logo not found: {SRC}")

    DST.parent.mkdir(parents=True, exist_ok=True)
    img = Image.open(SRC).convert("RGBA")
    arr = np.array(img)
    h, w, _ = arr.shape

    corners = [
        tuple(arr[0, 0, :3]),
        tuple(arr[0, -1, :3]),
        tuple(arr[-1, 0, :3]),
        tuple(arr[-1, -1, :3]),
    ]

    for y in range(h):
        for x in range(w):
            px = tuple(arr[y, x, :3])
            if any(color_dist(px, c) <= TOLERANCE for c in corners):
                arr[y, x, 3] = 0

    # Trim fully transparent margins for a tighter asset.
    alpha = arr[:, :, 3]
    ys, xs = np.where(alpha > 12)
    if len(xs) == 0:
        raise SystemExit("No visible logo content after background removal.")
    cropped = arr[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    Image.fromarray(cropped).save(DST)
    print(f"Wrote {DST} ({DST.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
