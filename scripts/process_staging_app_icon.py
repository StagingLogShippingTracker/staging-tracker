"""Prepare the Staging Log launcher icon: drop the camera pill, Swift-tint chrome.

Graphics stay the attached STAGE & SHIP card. Only navy/orange chrome is
shifted toward Swift Document Generator tokens (#121417 / #CE4E30).
Greens, cyan dispatch arrow, and status-like badges keep their hues.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "app-icon-source.png"
OUT = ROOT / "assets" / "swift-staging-log-app-icon.png"

SWIFT_NAVY = (0x12, 0x14, 0x17)
SWIFT_PANEL = (0x16, 0x19, 0x1E)
SWIFT_SURFACE = (0x1C, 0x1F, 0x24)
SWIFT_ORANGE = (0xCE, 0x4E, 0x30)
SWIFT_ORANGE_SOFT = (0xF8, 0xEB, 0xE7)


def clamp(v: float) -> int:
    return max(0, min(255, int(round(v))))


def is_orange(r: int, g: int, b: int, a: int) -> bool:
    return a > 160 and r > 165 and b < 110 and r > g + 15 and g < 210


def is_camera_dot(r: int, g: int, b: int, a: int) -> bool:
    return a > 160 and r < 55 and g < 50 and b < 70


def is_green(r: int, g: int, b: int) -> bool:
    return g > r + 15 and g > b and g > 70


def is_cyan_blue(r: int, g: int, b: int) -> bool:
    return b > 90 and b > r + 10 and b >= g - 10 and r < 120


def is_navy(r: int, g: int, b: int, a: int) -> bool:
    if a < 180:
        return False
    if is_orange(r, g, b, a) or is_green(r, g, b) or is_cyan_blue(r, g, b):
        return False
    mx = max(r, g, b)
    if mx > 95 or mx < 8:
        return False
    # Cool/dark slate — old icon navy, not near-black text on the white card.
    return b >= r - 4 and g <= b + 8 and r < 80


def remap_navy(r: int, g: int, b: int) -> tuple[int, int, int]:
    lum = (r + g + b) / 3.0
    if lum < 28:
        t = SWIFT_NAVY
    elif lum < 42:
        t = SWIFT_PANEL
    else:
        t = SWIFT_SURFACE
    return t


def remap_orange(r: int, g: int, b: int) -> tuple[int, int, int]:
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    # Pale STAGED wash (high luminance, still orange-tinted).
    if lum > 185 and g > 140:
        return SWIFT_ORANGE_SOFT
    t_lum = 0.299 * SWIFT_ORANGE[0] + 0.587 * SWIFT_ORANGE[1] + 0.114 * SWIFT_ORANGE[2]
    scale = (lum / t_lum) if t_lum else 1.0
    scale = max(0.55, min(1.35, scale))
    return (
        clamp(SWIFT_ORANGE[0] * scale),
        clamp(SWIFT_ORANGE[1] * scale),
        clamp(SWIFT_ORANGE[2] * scale),
    )


def strip_pill(im: Image.Image) -> None:
    px = im.load()
    w, h = im.size
    white = (255, 255, 255, 255)
    navy = (*SWIFT_NAVY, 255)

    for y in range(48, 97):
        for x in range(168, 342):
            r, g, b, a = px[x, y]
            pill = is_orange(r, g, b, a) or (
                is_camera_dot(r, g, b, a) and 200 <= x <= 312 and y <= 88
            )
            if not pill:
                continue
            px[x, y] = white if y >= 74 else navy

    # Second pass: wipe leftover pill / camera on the card crown (not STAGE & SHIP).
    for y in range(48, 96):
        for x in range(185, 330):
            r, g, b, a = px[x, y]
            leftover = is_orange(r, g, b, a) or is_camera_dot(r, g, b, a)
            if not leftover:
                continue
            px[x, y] = white if y >= 74 else navy


def recolor(im: Image.Image) -> None:
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 16:
                continue
            if is_green(r, g, b) or is_cyan_blue(r, g, b):
                continue
            if is_navy(r, g, b, a):
                nr, ng, nb = remap_navy(r, g, b)
                px[x, y] = (nr, ng, nb, a)
                continue
            if is_orange(r, g, b, a) or (
                a > 160 and r > 150 and r > g + 10 and r > b + 20 and g < 200 and b < 140
            ):
                nr, ng, nb = remap_orange(r, g, b)
                px[x, y] = (nr, ng, nb, a)


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Missing {SRC}")
    im = Image.open(SRC).convert("RGBA")
    strip_pill(im)
    recolor(im)
    strip_pill(im)
    im.save(OUT, optimize=True)
    print("wrote", OUT, im.size)


if __name__ == "__main__":
    main()
