"""Brand asset pipeline for SLST.

Inputs (checked into assets/):
  assets/slst-mark.png      - forklift-in-tire brand mark (opaque cream bg)
  assets/slst-wordmark.png  - "SLST / STAGING LOG & SHIPPING TRACKER" wordmark

Outputs:
  assets/slst-mark.png / assets/slst-wordmark.png     (background made transparent, in place)
  windows/runner/resources/app_icon.ico               (tight-cropped mark, minimal padding)
  android/.../mipmap-*/ic_launcher.png                (tight-cropped mark, minimal padding)
  android/.../mipmap-*/launch_image.png               (transparent mark for the splash screen)
"""

from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

# Fraction of the icon canvas left as padding around the mark on each side.
ICON_PADDING = 0.05
TOLERANCE = 28  # per-channel distance treated as "background"


def _is_bg(px, bg, tol=TOLERANCE):
    return (
        abs(px[0] - bg[0]) <= tol
        and abs(px[1] - bg[1]) <= tol
        and abs(px[2] - bg[2]) <= tol
    )


def strip_background(image: Image.Image) -> Image.Image:
    """Flood-fill from the borders, turning the paper background transparent.

    Interior whites (e.g. highlights inside the graphic) are preserved because
    they are not reachable from the border without crossing dark pixels.
    """
    img = image.convert("RGBA")
    w, h = img.size
    px = img.load()
    bg = px[0, 0]
    if bg[3] == 0:  # already transparent (script re-run); nothing to strip
        return img

    seen = bytearray(w * h)
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            if _is_bg(px[x, y], bg):
                queue.append((x, y))
                seen[y * w + x] = 1
    for y in range(h):
        for x in (0, w - 1):
            if _is_bg(px[x, y], bg) and not seen[y * w + x]:
                queue.append((x, y))
                seen[y * w + x] = 1

    while queue:
        x, y = queue.popleft()
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                if _is_bg(px[nx, ny], bg):
                    seen[ny * w + nx] = 1
                    queue.append((nx, ny))
    return img


def tight_mark(transparent: Image.Image) -> Image.Image:
    """Crop the transparent mark to its content bounding box."""
    bbox = transparent.getbbox()
    return transparent.crop(bbox)


def fit(mark: Image.Image, inner: int) -> Image.Image:
    """Scale (up or down) so the longest edge equals `inner`."""
    ratio = inner / max(mark.width, mark.height)
    return mark.resize(
        (max(1, round(mark.width * ratio)), max(1, round(mark.height * ratio))),
        Image.Resampling.LANCZOS,
    )


def icon_canvas(mark: Image.Image, size: int = 1024) -> Image.Image:
    """Square white icon: mark fills the canvas minus a small margin."""
    scaled = fit(mark, int(size * (1 - 2 * ICON_PADDING)))
    canvas = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    canvas.alpha_composite(
        scaled,
        ((size - scaled.width) // 2, (size - scaled.height) // 2),
    )
    return canvas


def main() -> None:
    mark_path = ASSETS / "slst-mark.png"
    word_path = ASSETS / "slst-wordmark.png"

    mark_t = strip_background(Image.open(mark_path))
    mark_t.save(mark_path)
    strip_background(Image.open(word_path)).save(word_path)

    icon = icon_canvas(tight_mark(mark_t))

    windows_icon = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    windows_icon.parent.mkdir(parents=True, exist_ok=True)
    icon.save(
        windows_icon,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

    launcher_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in launcher_sizes.items():
        out = RES / folder / "ic_launcher.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        icon.resize((size, size), Image.Resampling.LANCZOS).save(out)

    # Splash logo: transparent mark, sized per density (gravity=center bitmap).
    splash_sizes = {
        "mipmap-mdpi": 140,
        "mipmap-hdpi": 210,
        "mipmap-xhdpi": 280,
        "mipmap-xxhdpi": 420,
        "mipmap-xxxhdpi": 560,
    }
    tight = tight_mark(mark_t)
    for folder, size in splash_sizes.items():
        scaled = fit(tight, size)
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        canvas.alpha_composite(
            scaled,
            ((size - scaled.width) // 2, (size - scaled.height) // 2),
        )
        canvas.save(RES / folder / "launch_image.png")


if __name__ == "__main__":
    main()
