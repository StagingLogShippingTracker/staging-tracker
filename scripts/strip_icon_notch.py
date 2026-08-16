"""Remove the orange camera pill from the source app icon."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "app-icon-source.png"
OUT = ROOT / "assets" / "swift-staging-log-app-icon.png"


def is_orange(r: int, g: int, b: int, a: int) -> bool:
    return a > 160 and r > 165 and b < 110 and r > g + 15 and g < 210


def is_camera_dot(r: int, g: int, b: int, a: int) -> bool:
    return a > 160 and r < 55 and g < 50 and b < 70


def main() -> None:
    im = Image.open(SRC).convert("RGBA")
    px = im.load()
    w, h = im.size
    white = (255, 255, 255, 255)
    navy = px[256, 40]

    for y in range(48, 97):
        for x in range(168, 342):
            r, g, b, a = px[x, y]
            pill = is_orange(r, g, b, a) or (
                is_camera_dot(r, g, b, a) and 200 <= x <= 312 and y <= 88
            )
            if not pill:
                continue
            px[x, y] = white if y >= 74 else navy

    # Soften leftover orange fringe on the white card top.
    for y in range(72, 98):
        for x in range(175, 335):
            r, g, b, a = px[x, y]
            if is_orange(r, g, b, a) and y < 97:
                neighbors = []
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        nr, ng, nb, na = px[nx, ny]
                        if not is_orange(nr, ng, nb, na):
                            neighbors.append((nr, ng, nb, na))
                if neighbors:
                    px[x, y] = neighbors[0]
                elif y >= 74:
                    px[x, y] = white

    im.save(OUT, optimize=True)
    print("wrote", OUT, im.size)


if __name__ == "__main__":
    main()
