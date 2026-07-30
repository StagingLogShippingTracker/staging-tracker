"""Generate platform SLST launcher icons from assets/slst-app-icon.png.

Do not procedurally paint letters — use the official two-tone SLST logo asset.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "slst-app-icon.png"
BRAND_DIR = ROOT / "brand" / "slst-icon"
ICO_PATH = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"

ANDROID_MAP = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

BRAND_SIZES = [16, 24, 32, 48, 64, 128, 256, 512, 1024]
ICO_SIZES = [256, 128, 64, 48, 32, 24, 16]


def resize(src: Image.Image, size: int) -> Image.Image:
    return src.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Missing SLST logo: {SRC}")
    src = Image.open(SRC).convert("RGBA")
    print("source", SRC, src.size)

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
        targets = [
            ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png",
            ROOT
            / "apps"
            / "slst_wear"
            / "android"
            / "app"
            / "src"
            / "main"
            / "res"
            / folder
            / "ic_launcher.png",
        ]
        for dest in targets:
            dest.parent.mkdir(parents=True, exist_ok=True)
            im.save(dest, optimize=True)
            print(dest.relative_to(ROOT), dest.stat().st_size)


if __name__ == "__main__":
    main()
