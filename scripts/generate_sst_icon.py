"""Generate platform SST launcher icons from the HD source asset.

Source of truth: assets/sst-app-icon.png (sharp 512×512 SST mark from e44c767).
Do not procedurally rasterize text — that produced blurry mipmaps/ICO in c9bcd5c.
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "sst-app-icon.png"
BRAND_DIR = ROOT / "brand" / "sst-icon"
ICO_PATH = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"

ANDROID_MAP = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

BRAND_SIZES = [16, 24, 32, 48, 64, 128, 256, 512]
ICO_SIZES = [256, 128, 64, 48, 32, 24, 16]


def resize(src: Image.Image, size: int) -> Image.Image:
    return src.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Missing HD source icon: {SRC}")
    src = Image.open(SRC).convert("RGBA")
    print("source", SRC, src.size)

    BRAND_DIR.mkdir(parents=True, exist_ok=True)
    for s in BRAND_SIZES:
        path = BRAND_DIR / f"sst-{s}.png"
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
            if dest.parent.exists():
                im.save(dest, optimize=True)
                print(dest.relative_to(ROOT), dest.stat().st_size)


if __name__ == "__main__":
    main()
