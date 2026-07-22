"""Build sharp HD email logo + polished icons for Outlook-safe ship emails."""

from __future__ import annotations

import base64
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "email"
FUNC = ROOT / "supabase" / "functions" / "email-assets"
FILES = FUNC / "files"
OUT.mkdir(parents=True, exist_ok=True)
FILES.mkdir(parents=True, exist_ok=True)

# Prefer the newest HD logo attachment; fall back to prior source.
CANDIDATES = [
    Path(
        r"C:\Users\Brice\.cursor\projects\c-Users-Brice-Downloads-staging-tracker"
        r"\assets\c__Users_Brice_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_1783831070025-2452d701-d2dd-490f-b604-69f67774e191.png"
    ),
    Path(
        r"C:\Users\Brice\.cursor\projects\c-Users-Brice-Downloads-staging-tracker"
        r"\assets\c__Users_Brice_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_1783831070025-11a74eb3-f7c4-4b47-8b76-94d20bbb7ef6.png"
    ),
]

BRAND = (217, 50, 35, 255)
BRAND_DARK = (185, 40, 32, 255)
WHITE = (255, 255, 255, 255)


def pick_logo_src() -> Path:
    existing = [p for p in CANDIDATES if p.exists()]
    if not existing:
        raise FileNotFoundError("No logo source found")
    # Prefer largest file (usually highest fidelity)
    return max(existing, key=lambda p: p.stat().st_size)


def remove_background(im: Image.Image) -> Image.Image:
    """Remove cream/off-white background while preserving logo anti-alias edges."""
    im = im.convert("RGBA")
    pixels = im.load()
    w, h = im.size
    corners = [pixels[2, 2], pixels[w - 3, 2], pixels[2, h - 3], pixels[w - 3, h - 3]]
    avg = tuple(sum(c[i] for c in corners) // 4 for i in range(3))
    print("logo src", im.size, "corner_avg", avg)

    # Flood-fill style: mark near-bg, then feather edge alpha instead of hard cut
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            # Strong cream / near-white
            if r >= 228 and g >= 222 and b >= 210 and abs(r - g) < 22 and abs(g - b) < 28:
                mp[x, y] = 255
            elif (
                abs(r - avg[0]) <= 16
                and abs(g - avg[1]) <= 16
                and abs(b - avg[2]) <= 16
                and min(r, g, b) >= 210
            ):
                mp[x, y] = 255

    # Soften matte so we don't leave jagged halos
    mask = mask.filter(ImageFilter.GaussianBlur(radius=0.8))
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            m = mp[x, y]
            if m >= 250:
                pixels[x, y] = (r, g, b, 0)
            elif m > 0:
                # Keep some edge coverage for crisp letterforms
                new_a = max(0, min(255, int(a * (1 - m / 255.0))))
                pixels[x, y] = (r, g, b, new_a)
    return im


def make_logo() -> Path:
    src = pick_logo_src()
    print("using logo source", src)
    im = remove_background(Image.open(src))
    bbox = im.getbbox()
    if bbox:
        # Small pad inside crop so we don't clip shadows
        l, t, r, b = bbox
        pad = 6
        im = im.crop((max(0, l - pad), max(0, t - pad), min(im.width, r + pad), min(im.height, b + pad)))

    # Keep near-native resolution for retina email clients.
    # Display width in HTML will be ~300px; serve ~900px for sharpness.
    target_w = 900
    if im.width != target_w:
        ratio = target_w / im.width
        im = im.resize((target_w, max(1, int(im.height * ratio))), Image.Resampling.LANCZOS)

    out = OUT / "slst-logo-email.png"
    im.save(out, "PNG", optimize=True)
    print("saved", out, im.size, out.stat().st_size)
    return out


def icon_clipboard(size: int = 88) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = size / 44
    def xy(*pts):
        return [(p[0] * s, p[1] * s) for p in pts]
    d.rounded_rectangle(xy((10, 10), (34, 38))[0] + xy((10, 10), (34, 38))[1], radius=4 * s, outline=BRAND, width=max(2, int(3 * s)))
    # Fix rounded_rectangle call - need box tuple
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((10 * s, 10 * s, 34 * s, 38 * s), radius=3 * s, outline=BRAND, width=max(2, int(3 * s)))
    d.rounded_rectangle((14 * s, 6 * s, 30 * s, 14 * s), radius=2 * s, fill=BRAND)
    for y in (18, 24, 30):
        x2 = 29 * s if y < 30 else 24 * s
        d.line((15 * s, y * s, x2, y * s), fill=BRAND, width=max(2, int(2.5 * s)))
    return im


def icon_truck(size: int = 88) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = size / 44
    w = max(2, int(3 * s))
    d.rounded_rectangle((4 * s, 12 * s, 24 * s, 30 * s), radius=2 * s, outline=BRAND, width=w)
    d.line([(24 * s, 16 * s), (34 * s, 16 * s), (38 * s, 24 * s), (38 * s, 30 * s), (24 * s, 30 * s), (24 * s, 16 * s)], fill=BRAND, width=w)
    d.ellipse((8 * s, 28 * s, 16 * s, 36 * s), outline=BRAND, width=w)
    d.ellipse((28 * s, 28 * s, 36 * s, 36 * s), outline=BRAND, width=w)
    return im


def icon_cargo(size: int = 88) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = size / 44
    w = max(2, int(3 * s))
    pts = [(8 * s, 18 * s), (22 * s, 10 * s), (36 * s, 18 * s), (36 * s, 30 * s), (22 * s, 38 * s), (8 * s, 30 * s), (8 * s, 18 * s)]
    d.line(pts, fill=BRAND, width=w)
    d.line([(8 * s, 18 * s), (22 * s, 26 * s), (36 * s, 18 * s)], fill=BRAND, width=max(2, int(2.5 * s)))
    d.line([(22 * s, 26 * s), (22 * s, 38 * s)], fill=BRAND, width=max(2, int(2.5 * s)))
    return im


def icon_chat(size: int = 88) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = size / 44
    w = max(2, int(3 * s))
    d.rounded_rectangle((7 * s, 8 * s, 37 * s, 28 * s), radius=4 * s, outline=BRAND, width=w)
    d.polygon([(14 * s, 28 * s), (14 * s, 36 * s), (22 * s, 28 * s)], fill=BRAND)
    d.line((13 * s, 16 * s, 31 * s, 16 * s), fill=BRAND, width=max(2, int(2.5 * s)))
    d.line((13 * s, 21 * s, 25 * s, 21 * s), fill=BRAND, width=max(2, int(2.5 * s)))
    return im


def icon_search(size: int = 64) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = size / 32
    w = max(2, int(3 * s))
    d.ellipse((4 * s, 4 * s, 22 * s, 22 * s), outline=WHITE, width=w)
    d.line((20 * s, 20 * s, 28 * s, 28 * s), fill=WHITE, width=w)
    return im


def icon_mail(size: int = 56) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = size / 28
    w = max(2, int(2.5 * s))
    d.rounded_rectangle((2 * s, 6 * s, 26 * s, 22 * s), radius=2 * s, outline=BRAND, width=w)
    d.line([(3 * s, 7 * s), (14 * s, 15 * s), (25 * s, 7 * s)], fill=BRAND, width=w)
    return im


def icon_globe(size: int = 56) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = size / 28
    w = max(2, int(2.5 * s))
    d.ellipse((3 * s, 3 * s, 25 * s, 25 * s), outline=BRAND, width=w)
    d.ellipse((9 * s, 3 * s, 19 * s, 25 * s), outline=BRAND, width=w)
    d.line((3 * s, 14 * s, 25 * s, 14 * s), fill=BRAND, width=w)
    return im


def make_watermark() -> Path:
    """Concept-like faint gear + chevron tile for email backgrounds."""
    tile = Image.new("RGBA", (240, 240), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    stroke = (180, 180, 175, 70)

    def gear(cx: int, cy: int, r: int) -> None:
        d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=stroke, width=2)
        d.ellipse((cx - r // 3, cy - r // 3, cx + r // 3, cy + r // 3), outline=stroke, width=2)
        for ang in range(0, 360, 45):
            rad = math.radians(ang)
            x1 = cx + int((r - 2) * math.cos(rad))
            y1 = cy + int((r - 2) * math.sin(rad))
            x2 = cx + int((r + 7) * math.cos(rad))
            y2 = cy + int((r + 7) * math.sin(rad))
            d.line((x1, y1, x2, y2), fill=stroke, width=2)

    gear(48, 48, 18)
    gear(175, 70, 22)
    gear(70, 175, 14)
    # Chevrons
    for y0 in (110, 200):
        for x0 in (120, 200):
            d.line([(x0, y0), (x0 + 10, y0 + 8), (x0, y0 + 16)], fill=stroke, width=2)
            d.line([(x0 + 10, y0), (x0 + 20, y0 + 8), (x0 + 10, y0 + 16)], fill=stroke, width=2)

    out = OUT / "watermark-gears.png"
    tile.save(out, "PNG", optimize=True)
    print("saved", out, tile.size, out.stat().st_size)
    return out


def make_pixel(name: str, hexcolor: str) -> Path:
    h = hexcolor.lstrip("#")
    rgb = tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))
    im = Image.new("RGB", (1, 1), rgb)
    out = OUT / f"pixel-{name}.png"
    im.save(out, "PNG")
    (FILES / out.name).write_bytes(out.read_bytes())
    print("saved", out, hexcolor, out.stat().st_size)
    return out


def make_pixels() -> None:
    """1×1 PNG swatches — Outlook dark mode does not invert background images."""
    make_pixel("page", "#F3F1EC")
    make_pixel("shell", "#F7F5F1")
    make_pixel("white", "#FFFFFE")
    make_pixel("icon", "#FDECEA")
    make_pixel("brand", "#D93223")


def save_icon(name: str, im: Image.Image) -> Path:
    out = OUT / f"icon-{name}.png"
    im.save(out, "PNG", optimize=True)
    print("saved", out, im.size, out.stat().st_size)
    return out


def write_ts_chunks(logo_path: Path) -> None:
    """Embed assets as TS modules for the public email-assets edge function."""
    icons = {
        "icon-clipboard": OUT / "icon-clipboard.png",
        "icon-truck": OUT / "icon-truck.png",
        "icon-cargo": OUT / "icon-cargo.png",
        "icon-chat": OUT / "icon-chat.png",
        "icon-search": OUT / "icon-search.png",
        "icon-mail": OUT / "icon-mail.png",
        "icon-globe": OUT / "icon-globe.png",
        "watermark-gears": OUT / "watermark-gears.png",
    }
    lines = ["export const ICONS: Record<string, string> = {"]
    for key, path in icons.items():
        b64 = base64.b64encode(path.read_bytes()).decode("ascii")
        lines.append(f'  "{key}": "{b64}",')
        (FILES / path.name).write_bytes(path.read_bytes())
    lines.append("};")
    (FUNC / "icons-data.ts").write_text("\n".join(lines) + "\n", encoding="utf-8")

    logo_b64 = base64.b64encode(logo_path.read_bytes()).decode("ascii")
    (FILES / logo_path.name).write_bytes(logo_path.read_bytes())
    mid = len(logo_b64) // 2
    (FUNC / "logo-a.ts").write_text(
        f'export const LOGO_A = "{logo_b64[:mid]}";\n', encoding="utf-8"
    )
    (FUNC / "logo-b.ts").write_text(
        f'export const LOGO_B = "{logo_b64[mid:]}";\n', encoding="utf-8"
    )
    print("wrote TS asset modules; logo b64 chars", len(logo_b64))


def main() -> None:
    logo = make_logo()
    save_icon("clipboard", icon_clipboard())
    save_icon("truck", icon_truck())
    save_icon("cargo", icon_cargo())
    save_icon("chat", icon_chat())
    save_icon("search", icon_search())
    save_icon("mail", icon_mail())
    save_icon("globe", icon_globe())
    make_watermark()
    make_pixels()
    write_ts_chunks(logo)


if __name__ == "__main__":
    main()
