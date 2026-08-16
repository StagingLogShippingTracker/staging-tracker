"""Generate platform launcher icons + Android/Wear splash from Staging Log art.

Uses assets/swift-staging-log-app-icon.png (STAGE & SHIP / S-mark artwork) —
never paints Document Generator's document+arrow. Outer corners become
transparent so Windows and launchers show a rounded square like Doc Gen's
tile shape, while the graphic stays Staging Log's own.
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
# Match Document Generator's outer tile roundness (~22% of edge).
CORNER_RADIUS_FRAC = 0.22


def resize(src: Image.Image, size: int) -> Image.Image:
    return src.resize((size, size), Image.Resampling.LANCZOS)


def ensure_icon_bg(im: Image.Image) -> Image.Image:
    """Composite onto charcoal so translucent pixels never show checkerboard."""
    im = im.convert("RGBA")
    if im.width != im.height:
        side = max(im.width, im.height)
        square = Image.new("RGBA", (side, side), ICON_BG)
        square.alpha_composite(
            im, ((side - im.width) // 2, (side - im.height) // 2)
        )
        im = square
    canvas = Image.new("RGBA", im.size, ICON_BG)
    canvas.alpha_composite(im)
    return canvas


def apply_rounded_square_mask(
    im: Image.Image, radius_frac: float = CORNER_RADIUS_FRAC
) -> Image.Image:
    """Keep opaque rounded square; corners become fully transparent."""
    im = im.convert("RGBA")
    w, h = im.size
    assert w == h, "launcher icons must be square"
    radius = max(1, int(round(w * radius_frac)))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, w - 1, h - 1), radius=radius, fill=255
    )
    out = im.copy()
    existing = out.split()[3]
    out.putalpha(Image.composite(existing, Image.new("L", (w, h), 0), mask))
    return out


def make_splash_from_wordmark(size: int) -> Image.Image:
    if SPLASH_SQUARE_SRC.exists():
        return resize(Image.open(SPLASH_SQUARE_SRC).convert("RGBA"), size)
    canvas = Image.new("RGBA", (size, size), SPLASH_BG)
    if not WORDMARK.exists():
        if not SRC.exists():
            raise SystemExit(f"Missing splash wordmark and icon: {WORDMARK}")
        mark = resize(Image.open(SRC).convert("RGBA"), size)
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
    if not SRC.exists():
        raise SystemExit(f"Missing Staging Log launcher art: {SRC}")

    raw = Image.open(SRC).convert("RGBA")
    src = apply_rounded_square_mask(ensure_icon_bg(resize(raw, 1024)))
    print("source", SRC, raw.size, "rounded", src.size)

    # Keep the canonical asset as the rounded Staging Log tile (not Doc Gen art).
    src.save(SRC, optimize=True)

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
