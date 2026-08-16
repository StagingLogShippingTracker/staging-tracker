"""Generate platform launcher icons + Android/Wear splash from a painted mark.

The mark matches Swift Document Generator: charcoal rounded-square, white
label plate, orange arrow, barcode. Outer corners are transparent so Windows
and launchers show a rounded square instead of a sharp tile.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "swift-staging-log-app-icon.png"
WORDMARK = ROOT / "assets" / "swift-staging-log-wordmark-white.png"
SPLASH_SQUARE_SRC = ROOT / "assets" / "swift-staging-log-splash-wordmark.png"
BRAND_DIR = ROOT / "brand" / "app-icon"
ICO_PATH = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"

ANDROID_MAP = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

SPLASH_LAUNCH_MAP = {
    "mipmap-mdpi": 288,
    "mipmap-hdpi": 432,
    "mipmap-xhdpi": 576,
    "mipmap-xxhdpi": 864,
    "mipmap-xxxhdpi": 1152,
}

BRAND_SIZES = [16, 24, 32, 48, 64, 128, 256, 512, 1024]
ICO_SIZES = [256, 128, 64, 48, 32, 24, 16]

ICON_BG = (0x12, 0x14, 0x17, 255)
SPLASH_BG = (0x12, 0x14, 0x17, 255)
ACCENT = (0xCE, 0x4E, 0x30, 255)
CORNER_RADIUS_FRAC = 0.22


def resize(src: Image.Image, size: int) -> Image.Image:
    return src.resize((size, size), Image.Resampling.LANCZOS)


def paint_rounded_launcher(size: int = 1024) -> Image.Image:
    """Doc Gen–shaped rounded square: charcoal plate, white label, orange arrow."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    outer_r = max(8, int(round(size * CORNER_RADIUS_FRAC)))
    d.rounded_rectangle((0, 0, size - 1, size - 1), radius=outer_r, fill=ICON_BG)

    lx0 = int(size * 0.22)
    ly0 = int(size * 0.14)
    lx1 = int(size * 0.78)
    ly1 = int(size * 0.86)
    label_r = max(6, int(size * 0.07))
    d.rounded_rectangle((lx0, ly0, lx1, ly1), radius=label_r, fill=(255, 255, 255, 255))

    line_x0 = lx0 + int(size * 0.08)
    line_x1 = lx1 - int(size * 0.08)
    y1 = ly0 + int(size * 0.10)
    y2 = y1 + int(size * 0.045)
    d.rectangle((line_x0, y1, line_x0 + int(size * 0.18), y1 + max(2, size // 80)), fill=(0x1A, 0x1A, 0x1A, 255))
    d.rectangle((line_x0, y2, line_x1, y2 + max(2, size // 110)), fill=(0xC8, 0xC8, 0xC8, 255))

    # Up arrow (stem + head).
    cx = (lx0 + lx1) // 2
    stem_w = max(8, int(size * 0.10))
    stem_top = ly0 + int(size * 0.34)
    stem_bot = ly0 + int(size * 0.58)
    d.rectangle((cx - stem_w // 2, stem_top, cx + stem_w // 2, stem_bot), fill=ACCENT)
    head_w = int(size * 0.22)
    head_h = int(size * 0.14)
    d.polygon(
        [
            (cx, stem_top - head_h + int(size * 0.02)),
            (cx - head_w, stem_top + int(size * 0.04)),
            (cx + head_w, stem_top + int(size * 0.04)),
        ],
        fill=ACCENT,
    )

    # Barcode.
    bar_top = ly1 - int(size * 0.16)
    bar_bot = ly1 - int(size * 0.07)
    x = line_x0
    widths = [3, 2, 4, 2, 3, 5, 2, 3, 2, 4, 3, 2, 5, 2, 3, 4, 2, 3]
    scale = max(1, size // 220)
    for i, w in enumerate(widths):
        bw = w * scale
        if i % 2 == 0:
            d.rectangle((x, bar_top, x + bw, bar_bot), fill=(0x12, 0x14, 0x17, 255))
        x += bw + scale

    return im


def make_splash_from_wordmark(size: int) -> Image.Image:
    if SPLASH_SQUARE_SRC.exists():
        return resize(Image.open(SPLASH_SQUARE_SRC).convert("RGBA"), size)
    canvas = Image.new("RGBA", (size, size), SPLASH_BG)
    if not WORDMARK.exists():
        mark = paint_rounded_launcher(size)
        canvas.alpha_composite(mark)
        return canvas
    wm = Image.open(WORDMARK).convert("RGBA")
    bbox = wm.getbbox()
    if bbox:
        wm = wm.crop(bbox)
    max_w = int(size * 0.78)
    max_h = int(size * 0.28)
    scale = min(max_w / wm.width, max_h / wm.height)
    nw = max(1, int(wm.width * scale))
    nh = max(1, int(wm.height * scale))
    resized = wm.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas.alpha_composite(resized, ((size - nw) // 2, (size - nh) // 2))
    return canvas


def android_res_roots() -> list[Path]:
    return [
        ROOT / "android" / "app" / "src" / "main" / "res",
        ROOT / "apps" / "wear" / "android" / "app" / "src" / "main" / "res",
    ]


def main() -> None:
    src = paint_rounded_launcher(1024)
    SRC.parent.mkdir(parents=True, exist_ok=True)
    src.save(SRC, optimize=True)
    print("source", SRC, src.size)

    BRAND_DIR.mkdir(parents=True, exist_ok=True)
    for s in BRAND_SIZES:
        path = BRAND_DIR / f"app-icon-{s}.png"
        resize(src, s).save(path, optimize=True)
        print("brand", path.name)

    images = [resize(src, s) for s in ICO_SIZES]
    ICO_PATH.parent.mkdir(parents=True, exist_ok=True)
    images[0].save(
        ICO_PATH,
        format="ICO",
        sizes=[(im.width, im.height) for im in images],
        append_images=images[1:],
    )
    print("ico", ICO_PATH)

    for folder, s in ANDROID_MAP.items():
        im = resize(src, s)
        for res_root in android_res_roots():
            dest = res_root / folder / "ic_launcher.png"
            dest.parent.mkdir(parents=True, exist_ok=True)
            im.save(dest, optimize=True)
            print(dest.relative_to(ROOT))

    splash_master = make_splash_from_wordmark(1152)
    splash_asset = ROOT / "assets" / "swift-staging-log-splash-wordmark.png"
    resize(splash_master, 1024).save(splash_asset, optimize=True)

    for folder, s in SPLASH_LAUNCH_MAP.items():
        im = make_splash_from_wordmark(s)
        for res_root in android_res_roots():
            dest = res_root / folder / "launch_image.png"
            dest.parent.mkdir(parents=True, exist_ok=True)
            im.save(dest, optimize=True)

    for res_root in android_res_roots():
        drawable = res_root / "drawable"
        drawable.mkdir(parents=True, exist_ok=True)
        resize(splash_master, 576).save(drawable / "splash_logo.png", optimize=True)


if __name__ == "__main__":
    main()
