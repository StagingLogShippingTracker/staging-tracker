"""Generate platform SLST launcher icons + Android/Wear splash from assets.

Launcher source: assets/slst-app-icon.png (stage/ship mock card on navy).
Corners are softened to a rounded square when writing platform icons.
Splash: launcher icon on navy (Android + Wear).
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "slst-app-icon.png"
WORDMARK = ROOT / "assets" / "slst-wordmark-white.png"
SPLASH_SQUARE_SRC = ROOT / "assets" / "slst-splash-wordmark.png"
BRAND_DIR = ROOT / "brand" / "slst-icon"
ICO_PATH = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"

ANDROID_MAP = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Splash wordmark bitmaps (pre-12 windowBackground + Android 12 animated icon).
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
CORNER_RADIUS_FRAC = 0.14


def resize(src: Image.Image, size: int) -> Image.Image:
    return src.resize((size, size), Image.Resampling.LANCZOS)


def apply_rounded_square_mask(im: Image.Image, radius_frac: float = CORNER_RADIUS_FRAC) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    assert w == h, "launcher icons must be square"
    radius = max(1, int(round(w * radius_frac)))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=255)
    out = im.copy()
    # Preserve existing alpha (e.g. already-rounded source) under the mask.
    existing = out.split()[3]
    out.putalpha(Image.composite(existing, Image.new("L", (w, h), 0), mask))
    return out


def ensure_icon_bg(im: Image.Image) -> Image.Image:
    """Composite onto #0A1017 so translucent corners never show checkerboard."""
    im = im.convert("RGBA")
    canvas = Image.new("RGBA", im.size, ICON_BG)
    canvas.alpha_composite(im)
    return canvas


def make_splash_from_wordmark(size: int) -> Image.Image:
    if SPLASH_SQUARE_SRC.exists():
        return resize(Image.open(SPLASH_SQUARE_SRC).convert("RGBA"), size)
    if not WORDMARK.exists():
        raise SystemExit(f"Missing splash wordmark: {WORDMARK}")
    canvas = Image.new("RGBA", (size, size), SPLASH_BG)
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
        ROOT / "apps" / "slst_wear" / "android" / "app" / "src" / "main" / "res",
    ]


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Missing SLST logo: {SRC}")
    raw = Image.open(SRC).convert("RGBA")
    src = ensure_icon_bg(raw)
    print("source", SRC, raw.size)

    BRAND_DIR.mkdir(parents=True, exist_ok=True)
    for s in BRAND_SIZES:
        path = BRAND_DIR / f"slst-{s}.png"
        resize(src, s).save(path, optimize=True)
        print("brand", path.name, path.stat().st_size)

    images = [resize(src, s) for s in ICO_SIZES]
    images[0].save(
        ICO_PATH,
        format="ICO",
        sizes=[(im.width, im.height) for im in images],
        append_images=images[1:],
    )
    print("ico", ICO_PATH, ICO_PATH.stat().st_size)

    for folder, s in ANDROID_MAP.items():
        im = resize(src, s)
        for res_root in android_res_roots():
            dest = res_root / folder / "ic_launcher.png"
            dest.parent.mkdir(parents=True, exist_ok=True)
            im.save(dest, optimize=True)
            print(dest.relative_to(ROOT), dest.stat().st_size)

    # Splash plates: centered wordmark on #091019.
    splash_master = make_splash_from_wordmark(1152)
    splash_asset = ROOT / "assets" / "slst-splash-wordmark.png"
    resize(splash_master, 1024).save(splash_asset, optimize=True)
    print("splash_asset", splash_asset)

    for folder, s in SPLASH_LAUNCH_MAP.items():
        im = resize(splash_master, s) if s != splash_master.width else splash_master
        if s != splash_master.width:
            im = make_splash_from_wordmark(s)
        for res_root in android_res_roots():
            dest = res_root / folder / "launch_image.png"
            dest.parent.mkdir(parents=True, exist_ok=True)
            im.save(dest, optimize=True)
            print(dest.relative_to(ROOT), dest.stat().st_size)

    # nodpi drawable copies for styles / layer-lists.
    for res_root in android_res_roots():
        drawable = res_root / "drawable"
        drawable.mkdir(parents=True, exist_ok=True)
        splash_dest = drawable / "splash_logo.png"
        resize(splash_master, 576).save(splash_dest, optimize=True)
        print(splash_dest.relative_to(ROOT), splash_dest.stat().st_size)


if __name__ == "__main__":
    main()
