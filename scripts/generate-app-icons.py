from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "staging-shipping-logo.png"


def square_mark() -> Image.Image:
    image = Image.open(SOURCE).convert("RGBA")
    # The brand mark occupies the left side of the horizontal logo.
    mark = image.crop((0, 0, min(430, image.width), image.height))
    mark.thumbnail((900, 900), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (1024, 1024), (247, 247, 248, 255))
    x = (canvas.width - mark.width) // 2
    y = (canvas.height - mark.height) // 2
    canvas.alpha_composite(mark, (x, y))
    return canvas


def main() -> None:
    mark = square_mark()

    windows_icon = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    windows_icon.parent.mkdir(parents=True, exist_ok=True)
    mark.save(
        windows_icon,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, size in android_sizes.items():
        output = res / folder / "ic_launcher.png"
        output.parent.mkdir(parents=True, exist_ok=True)
        mark.resize((size, size), Image.Resampling.LANCZOS).save(output)


if __name__ == "__main__":
    main()
