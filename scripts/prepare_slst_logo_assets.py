"""Prepare SLST logo assets from the official white-on-navy source PNG.

Outputs:
  assets/slst-logo-source.png       — archived full source
  assets/slst-wordmark-white.png    — full wordmark, transparent, high-res UI
  assets/slst-mark-s.png            — S + swish only, transparent, high-res UI
  assets/slst-app-icon.png          — S + swish on #0A1017 square (launcher source)

UI wordmark/mark stay at least UI_WORDMARK_MIN_HEIGHT / UI_MARK_MIN_HEIGHT tall
so large monitors can downsample crisply. Launcher icon composition still
downscales the mark onto a 1024 canvas.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
BRAND_SOURCE = ROOT / "brand" / "source"

SRC_CANDIDATES = [
    Path(
        r"C:\Users\Brice\.cursor\projects\c-Users-Brice-Downloads-swift-staging-tracker"
        r"\assets\c__Users_Brice_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images"
        r"_1785390668198-f9fd535d-b417-48fb-a69a-8aafa0481d22.png"
    ),
    ASSETS / "slst-logo-source.png",
    BRAND_SOURCE / "slst-logo-full.png",
]

ICON_BG = (0x0A, 0x10, 0x17, 255)
# Near-bg navy of the source plate (~#080F17).
BG_REF = (8, 15, 23)


def pick_src() -> Path:
    for p in SRC_CANDIDATES:
        if p.exists():
            return p
    raise FileNotFoundError("No SLST logo source found")


def is_bg(r: int, g: int, b: int, a: int = 255) -> bool:
    if a < 8:
        return True
    return (
        abs(r - BG_REF[0]) <= 28
        and abs(g - BG_REF[1]) <= 28
        and abs(b - BG_REF[2]) <= 32
        and max(r, g, b) < 70
    )


def remove_background_keep_tread(im: Image.Image) -> Image.Image:
    """Flood-fill remove edge-connected dark bg; keep interior tire tread."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    visited = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    def try_seed(x: int, y: int) -> None:
        r, g, b, a = px[x, y]
        if is_bg(r, g, b, a) and not visited[y][x]:
            visited[y][x] = True
            q.append((x, y))

    for x in range(w):
        try_seed(x, 0)
        try_seed(x, h - 1)
    for y in range(h):
        try_seed(0, y)
        try_seed(w - 1, y)

    while q:
        x, y = q.popleft()
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                r, g, b, a = px[nx, ny]
                if is_bg(r, g, b, a):
                    visited[ny][nx] = True
                    q.append((nx, ny))

    # Soften remaining near-bg fringe on outer edges (anti-alias halos).
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if max(r, g, b) < 90 and min(r, g, b) > 0:
                # If mostly surrounded by transparent, fade halo.
                trans = 0
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if not (0 <= nx < w and 0 <= ny < h) or px[nx, ny][3] == 0:
                        trans += 1
                if trans >= 2 and is_bg(r, g, b, a):
                    px[x, y] = (0, 0, 0, 0)
                elif trans >= 3 and max(r, g, b) < 55:
                    px[x, y] = (0, 0, 0, 0)
    return im


def tight_crop(im: Image.Image, pad: int = 8) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        return im
    l, t, r, b = bbox
    return im.crop(
        (
            max(0, l - pad),
            max(0, t - pad),
            min(im.width, r + pad),
            min(im.height, b + pad),
        )
    )


def content_mask(im: Image.Image) -> list[list[bool]]:
    px = im.load()
    w, h = im.size
    return [[px[x, y][3] > 20 for x in range(w)] for y in range(h)]


def find_s_crop_right(im: Image.Image) -> int:
    """Right edge after S letter, keeping bottom swirl, excluding L mast."""
    mask = content_mask(im)
    w, h = im.size
    mid_top, mid_bot = int(h * 0.12), int(h * 0.55)
    scores = [
        sum(1 for y in range(mid_top, mid_bot) if mask[y][x]) for x in range(w)
    ]

    start_x = next((x for x, s in enumerate(scores) if s > h * 0.08), 40)
    gap_start = None
    for x in range(start_x + 20, w - 10):
        if scores[x] <= 2 and all(scores[x + k] <= 3 for k in range(min(6, w - x))):
            gap_start = x
            break
    if gap_start is None:
        gap_start = int(w * 0.32)

    # Keep ~18px of continuing bottom swirl past the S, stop before L mast.
    right = min(w - 1, gap_start + 18)
    for x in range(gap_start, min(w, gap_start + 28)):
        tall = sum(1 for y in range(int(h * 0.08), int(h * 0.7)) if mask[y][x])
        if tall > h * 0.35:
            right = max(gap_start + 10, x - 2)
            break
    return right


def _band_at(mask: list[list[bool]], x: int, h: int) -> list[tuple[int, int]]:
    runs: list[tuple[int, int]] = []
    start = None
    for y in range(h):
        if mask[y][x] and start is None:
            start = y
        elif not mask[y][x] and start is not None:
            runs.append((start, y - 1))
            start = None
    if start is not None:
        runs.append((start, h - 1))
    return [r for r in runs if r[0] >= int(h * 0.55)]


def sharpen_swirl_tip(im: Image.Image) -> Image.Image:
    """Cut the blunt thick-swirl face and redraw a centered sharp point."""
    im = im.copy().convert("RGBA")
    w, h = im.size
    mask = content_mask(im)

    # Walk left from the right edge to find the thick bottom band tip.
    best = None
    for x in range(w - 1, max(0, w // 3), -1):
        bottom = _band_at(mask, x, h)
        thick_runs = [r for r in bottom if (r[1] - r[0]) >= 10]
        if thick_runs:
            thick = max(thick_runs, key=lambda r: r[1] - r[0])
            best = (x, thick[0], thick[1])
            break
    if best is None:
        print("WARN: could not locate swirl tip; leaving unchanged")
        return im

    tip_x, y0, y1 = best
    thickness = y1 - y0 + 1
    cy0 = (y0 + y1) / 2.0

    # Gentle upward slope from samples left of the tip.
    centers: list[tuple[float, float]] = []
    for dx in range(6, 40):
        x = tip_x - dx
        if x < 0:
            break
        bands = _band_at(mask, x, h)
        thick_runs = [r for r in bands if (r[1] - r[0]) >= 8]
        if not thick_runs:
            continue
        r0, r1 = max(thick_runs, key=lambda r: r[1] - r[0])
        centers.append((float(x), (r0 + r1) / 2.0))
    slope = -0.08  # mostly horizontal sharp point
    if len(centers) >= 2:
        measured = (centers[0][1] - centers[-1][1]) / (centers[0][0] - centers[-1][0])
        slope = 0.20 * measured + 0.80 * (-0.06)
        slope = max(-0.14, min(-0.03, slope))

    # Trim modestly; taper over ~1.15× thickness so it reads as the stroke itself.
    trim = min(6, max(3, thickness // 8))
    cut_x = tip_x - trim
    extend = max(int(thickness * 1.15), thickness + 8)
    need_w = cut_x + extend + 6
    if need_w > w:
        new = Image.new("RGBA", (need_w, h), (0, 0, 0, 0))
        new.paste(im, (0, 0))
        im = new
        w = im.width
    px = im.load()

    # Remember thin parallel band before clearing.
    thin = None
    for x in range(tip_x - 1, max(0, tip_x - 30), -1):
        bands = _band_at(mask, x, h)
        below = [r for r in bands if r[0] > y1 + 2 and (r[1] - r[0]) <= max(4, thickness // 2)]
        if below:
            thin = max(below, key=lambda r: r[1] - r[0])
            break

    # Clear original blunt face / thin-line continuation past cut (any opacity).
    clear_y1 = min(h, y1 + max(18, thickness + 8))
    for x in range(cut_x, w):
        for y in range(max(0, y0 - 6), clear_y1):
            if px[x, y][3] > 0:
                px[x, y] = (0, 0, 0, 0)

    # Hard triangular taper (column fill) — reads as a true point, not a bullet.
    point_x = float(cut_x + extend)
    point_y = cy0 + slope * extend
    for i in range(extend + 1):
        t = i / max(1, extend)
        half = (thickness / 2.0) * (1.0 - t)
        x = cut_x + i
        cy = cy0 + slope * i
        if half < 0.5:
            y = int(round(cy))
            if 0 <= x < w and 0 <= y < h:
                px[x, y] = (255, 255, 255, 255)
            continue
        y0i = int(round(cy - half))
        y1i = int(round(cy + half))
        for y in range(y0i, y1i + 1):
            if 0 <= x < w and 0 <= y < h:
                px[x, y] = (255, 255, 255, 255)
    tx, ty = int(round(point_x)), int(round(point_y))
    if 0 <= tx < w and 0 <= ty < h:
        px[tx, ty] = (255, 255, 255, 255)

    if thin is not None:
        ty0, ty1 = thin
        tthick = ty1 - ty0 + 1
        t_extend = max(8, int(extend * 0.45))
        t_cy = (ty0 + ty1) / 2.0
        for i in range(t_extend + 1):
            t = i / max(1, t_extend)
            half = (tthick / 2.0) * (1.0 - t)
            x = cut_x + i
            cy = t_cy + slope * i
            if half < 0.4:
                y = int(round(cy))
                if 0 <= x < w and 0 <= y < h:
                    px[x, y] = (255, 255, 255, 255)
                continue
            y0i = int(round(cy - half))
            y1i = int(round(cy + half))
            for y in range(y0i, y1i + 1):
                if 0 <= x < w and 0 <= y < h:
                    px[x, y] = (255, 255, 255, 255)

    print(
        f"sharpened tip cut_x={cut_x} y={y0}-{y1} thick={thickness} "
        f"extend={extend} slope={slope:.3f} point=({point_x:.0f},{point_y:.0f})"
    )
    return im


# Launcher icon fill fraction (mark bbox vs canvas). Was 0.72 — too much edge padding.
ICON_MARK_FILL = 0.88
# Transparent margin kept around mark content when compositing the icon only.
ICON_MARK_CROP_PAD = 4

# UI assets stay far above on-screen height (28–120 logical px) so large monitors
# at 100% DPI can downsample crisply. Do not shrink these to display size.
UI_WORDMARK_MIN_HEIGHT = 900
UI_MARK_MIN_HEIGHT = 1000
UI_MAX_DIM = 4096


def upscale_min_height(im: Image.Image, min_h: int) -> Image.Image:
    """LANCZOS upscale so height is at least min_h (capped at UI_MAX_DIM)."""
    if im.height >= min_h and max(im.size) <= UI_MAX_DIM:
        return im
    scale = max(min_h / max(1, im.height), 1.0)
    nw = int(round(im.width * scale))
    nh = int(round(im.height * scale))
    if max(nw, nh) > UI_MAX_DIM:
        cap = UI_MAX_DIM / max(nw, nh)
        nw = max(1, int(round(nw * cap)))
        nh = max(1, int(round(nh * cap)))
    if (nw, nh) == im.size:
        return im
    return im.resize((nw, nh), Image.Resampling.LANCZOS)


def purify_white_logo(im: Image.Image) -> Image.Image:
    """Force logo ink to pure white; keep alpha for anti-aliased edges.

    Soft LANCZOS upscales leave gray fringe RGB that looks muddy/pixelated when
    ColorFiltered or shown large on low-DPR monitors. White RGB + soft alpha
    downscales cleanly under FilterQuality.high.
    """
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            px[x, y] = (255, 255, 255, a)
    return im


def make_app_icon(mark: Image.Image, size: int = 1024) -> Image.Image:
    """Place transparent S-mark on solid #0A1017 with a tight inset."""
    canvas = Image.new("RGBA", (size, size), ICON_BG)
    # Re-crop for icon only so mark-asset padding does not shrink the graphic.
    # Does not rewrite assets/slst-mark-s.png or UI wordmarks.
    mark = tight_crop(mark, pad=ICON_MARK_CROP_PAD)
    target = int(size * ICON_MARK_FILL)
    mw, mh = mark.size
    scale = min(target / mw, target / mh)
    nw, nh = max(1, int(mw * scale)), max(1, int(mh * scale))
    resized = mark.resize((nw, nh), Image.Resampling.LANCZOS)
    x = (size - nw) // 2
    y = (size - nh) // 2
    canvas.alpha_composite(resized, (x, y))
    return canvas


def main() -> None:
    src_path = pick_src()
    print("source", src_path)
    raw = Image.open(src_path).convert("RGBA")
    print("raw", raw.size)

    ASSETS.mkdir(parents=True, exist_ok=True)
    BRAND_SOURCE.mkdir(parents=True, exist_ok=True)

    # Archive source
    archived = ASSETS / "slst-logo-source.png"
    raw.save(archived, optimize=True)
    raw.save(BRAND_SOURCE / "slst-logo-full.png", optimize=True)
    print("archived", archived)

    transparent = remove_background_keep_tread(raw)
    wordmark = tight_crop(transparent, pad=10)
    # High-res UI wordmark — never bake down to sidepanel/footer display size.
    wordmark_hd = purify_white_logo(upscale_min_height(wordmark, UI_WORDMARK_MIN_HEIGHT))
    wm_path = ASSETS / "slst-wordmark-white.png"
    wordmark_hd.save(wm_path, optimize=True)
    print("wordmark", wm_path, wordmark_hd.size)

    # Also refresh legacy light wordmark path used nowhere critical.
    wordmark_hd.save(ASSETS / "slst-wordmark.png", optimize=True)

    right = find_s_crop_right(transparent)
    print("S crop right edge", right)
    s_region = transparent.crop((0, 0, right + 1, transparent.height))
    s_region = tight_crop(s_region, pad=6)
    # Upscale first, then sharpen at HD so the tip stays solid/crisp.
    mark_hd = upscale_min_height(s_region, UI_MARK_MIN_HEIGHT)
    mark_hd = sharpen_swirl_tip(mark_hd)
    mark_hd = purify_white_logo(tight_crop(mark_hd, pad=10))
    # Tip extend / crop can shrink height slightly — restore UI minimum.
    mark_hd = upscale_min_height(mark_hd, UI_MARK_MIN_HEIGHT)
    mark_path = ASSETS / "slst-mark-s.png"
    mark_hd.save(mark_path, optimize=True)
    print("mark", mark_path, mark_hd.size)

    icon = make_app_icon(mark_hd, 1024)
    icon_path = ASSETS / "slst-app-icon.png"
    icon.save(icon_path, optimize=True)
    print("icon", icon_path, icon.size)

    # Preview on transparent checker isn't needed; save debug previews.
    preview = ASSETS / "_preview_s_mark.png"
    mark_hd.save(preview, optimize=True)
    print("preview", preview)


if __name__ == "__main__":
    main()
