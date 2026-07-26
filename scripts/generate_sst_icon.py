from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

BG = (0x1D, 0x24, 0x33, 255)
WHITE = (255, 255, 255, 255)

root = Path(r"C:\Users\Brice\Downloads\staging-tracker")
out_dir = root / "brand" / "sst-icon"
out_dir.mkdir(parents=True, exist_ok=True)

font_candidates = [
    Path(r"C:\Windows\Fonts\segoeuib.ttf"),
    Path(r"C:\Windows\Fonts\seguisb.ttf"),
    Path(r"C:\Windows\Fonts\arialbd.ttf"),
    Path(r"C:\Windows\Fonts\arial.ttf"),
    Path(r"C:\Windows\Fonts\calibrib.ttf"),
]
font_path = next((p for p in font_candidates if p.exists()), None)
print("font", font_path)


def make_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pad = max(1, size // 32)
    radius = max(2, int(size * 0.22))
    draw.rounded_rectangle(
        (pad, pad, size - 1 - pad, size - 1 - pad),
        radius=radius,
        fill=BG,
    )
    font_size = max(8, int(size * 0.42))
    if font_path:
        font = ImageFont.truetype(str(font_path), font_size)
    else:
        font = ImageFont.load_default()
    text = "SST"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (size - tw) / 2 - bbox[0]
    y = (size - th) / 2 - bbox[1] - size * 0.02
    draw.text((x, y), text, font=font, fill=WHITE)
    return img


sizes = [16, 24, 32, 48, 64, 128, 256, 512]
for s in sizes:
    path = out_dir / f"sst-{s}.png"
    make_icon(s).save(path)
    print("wrote", path)

ico_path = root / "windows" / "runner" / "resources" / "app_icon.ico"
images = [make_icon(s) for s in [16, 24, 32, 48, 64, 128, 256]]
images[0].save(
    ico_path,
    format="ICO",
    sizes=[(im.width, im.height) for im in images],
    append_images=images[1:],
)
print("wrote", ico_path, ico_path.stat().st_size)

android_map = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
for folder, s in android_map.items():
    dest = root / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png"
    make_icon(s).save(dest)
    print("android", dest)
    wear = (
        root
        / "apps"
        / "slst_wear"
        / "android"
        / "app"
        / "src"
        / "main"
        / "res"
        / folder
        / "ic_launcher.png"
    )
    if wear.parent.exists():
        make_icon(s).save(wear)
        print("wear", wear)

assets = root / "assets"
assets.mkdir(exist_ok=True)
make_icon(512).save(assets / "sst-app-icon.png")
print("assets icon ok")
