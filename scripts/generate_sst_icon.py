"""Generate sharp SST launcher icons for Windows / Android / Wear.

Source of truth: assets/sst-app-icon.png (regenerated here as a crisp 1024 master).
Each mipmap/ICO size is painted at 4× then downsampled so letter edges stay sharp.

Do NOT use scripts/generate-app-icons.py for SST — that old SLST mark pipeline
produced soft launchers and must never overwrite these assets.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "sst-app-icon.png"
BRAND_DIR = ROOT / "brand" / "sst-icon"
ICO_PATH = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"

# Dark industrial SST canvas (matches in-app shell).
BG = (18, 24, 38, 255)
FG = (255, 255, 255, 255)
CORNER = 0.22
PAD = 0.04

ANDROID_MAP = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

BRAND_SIZES = [16, 24, 32, 48, 64, 128, 256, 512, 1024]
ICO_SIZES = [256, 128, 64, 48, 32, 24, 16]


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path(r"C:\Windows\Fonts\arialbd.ttf"),
        Path(r"C:\Windows\Fonts\segoeuib.ttf"),
        Path(r"C:\Windows\Fonts\arial.ttf"),
        Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def paint_icon(size: int) -> Image.Image:
    """Paint a sharp SST squircle at [size], via 4× supersample."""
    scale = 4
    big = size * scale
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    margin = max(1, int(big * PAD))
    radius = int(big * CORNER)
    draw.rounded_rectangle(
        (margin, margin, big - 1 - margin, big - 1 - margin),
        radius=radius,
        fill=BG,
    )

    # ~32% of canvas — matches the HD mark proportions.
    font = _font(int(big * 0.34))
    text = "SST"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (big - tw) // 2 - bbox[0]
    y = (big - th) // 2 - bbox[1] - int(big * 0.01)
    draw.text((x, y), text, font=font, fill=FG)

    return img.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    master = paint_icon(1024)
    SRC.parent.mkdir(parents=True, exist_ok=True)
    master.save(SRC, optimize=True)
    print("master", SRC, master.size, SRC.stat().st_size)

    BRAND_DIR.mkdir(parents=True, exist_ok=True)
    for s in BRAND_SIZES:
        path = BRAND_DIR / f"sst-{s}.png"
        paint_icon(s).save(path, optimize=True)
        print("brand", path.name, path.stat().st_size)

    ico_images = [paint_icon(s) for s in ICO_SIZES]
    ICO_PATH.parent.mkdir(parents=True, exist_ok=True)
    ico_images[0].save(
        ICO_PATH,
        format="ICO",
        sizes=[(im.width, im.height) for im in ico_images],
        append_images=ico_images[1:],
    )
    print("ico", ICO_PATH, ICO_PATH.stat().st_size)

    for folder, s in ANDROID_MAP.items():
        im = paint_icon(s)
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
