"""Remove forklift/box decorations from SLST logo; export light + dark transparent PNGs."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

src = Path(
    r"C:\Users\Brice\.cursor\projects\c-Users-Brice-Downloads-staging-tracker\assets"
    r"\c__Users_Brice_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_"
    r"1783831070025-7183332a-1c64-4edc-8d05-7634bc072930.png"
)
out_dir = Path(r"C:\Users\Brice\Downloads\staging-tracker\assets")

im = Image.open(src).convert("RGBA")
w, h = im.size
arr = np.array(im).astype(np.float32)
r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]

bg = (
    (r > 220)
    & (g > 215)
    & (b > 210)
    & (np.abs(r - g) < 18)
    & (np.abs(g - b) < 18)
)
is_red = (r > 140) & (r > g + 40) & (r > b + 40)
is_dark = (r < 85) & (g < 85) & (b < 90) & ~bg

# Decoration: mid greys and tan boxes, excluding red / true charcoal letter fill
deco = (
    ~bg
    & ~is_red
    & (
        (
            (np.abs(r - g) < 22)
            & (np.abs(g - b) < 22)
            & (r > 88)
            & (r < 200)
        )
        | ((r > 170) & (g > 150) & (b < 200) & ((r - b) > 18) & (r < 240))
    )
)

# Manual wipe regions (1024x558 source) covering forklifts + boxes
mask = Image.new("L", (w, h), 0)
draw = ImageDraw.Draw(mask)
# Top forklift above S/L
draw.ellipse((480, 40, 720, 210), fill=255)
draw.rectangle((520, 60, 700, 200), fill=255)
# Boxes above T
draw.rectangle((700, 40, 960, 210), fill=255)
# Forklift in the L counter
draw.ellipse((390, 160, 560, 340), fill=255)
draw.rectangle((410, 180, 540, 320), fill=255)
wipe = np.array(mask) > 0

remove = bg | (deco & wipe) | (wipe & ~is_red & ~is_dark & (r > 70))

out = arr.copy()
out[remove | bg] = 0

# Restore letter body where wipe punched holes into dark letter shapes:
# any wiped pixel that had mostly dark neighbors in original -> charcoal
charcoal = np.array([42, 44, 48, 255], dtype=np.float32)
yy, xx = np.where(wipe & ~bg)
for y, x in zip(yy, xx):
    y0, y1 = max(0, y - 2), min(h, y + 3)
    x0, x1 = max(0, x - 2), min(w, x + 3)
    patch = arr[y0:y1, x0:x1]
    pr, pg, pb = patch[:, :, 0], patch[:, :, 1], patch[:, :, 2]
    dark_n = ((pr < 85) & (pg < 85) & (pb < 90)).mean()
    # Inside L bowl / letter mass: fill charcoal; above-cap decorations: leave transparent
    if dark_n > 0.25 and y > 150:
        out[y, x] = charcoal
    elif dark_n > 0.45:
        out[y, x] = charcoal

# Clean leftover deco greys still attached in wipe zones
r2, g2, b2, a2 = out[:, :, 0], out[:, :, 1], out[:, :, 2], out[:, :, 3]
leftover = (
    (a2 > 10)
    & wipe
    & ~is_red
    & (np.abs(r2 - g2) < 25)
    & (r2 > 90)
    & (r2 < 190)
)
out[leftover] = 0
# Re-fill if surrounded by charcoal
yy, xx = np.where(leftover)
for y, x in zip(yy, xx):
    y0, y1 = max(0, y - 3), min(h, y + 4)
    x0, x1 = max(0, x - 3), min(w, x + 4)
    patch = out[y0:y1, x0:x1]
    if ((patch[:, :, 3] > 200) & (patch[:, :, 0] < 70)).mean() > 0.3 and y > 150:
        out[y, x] = charcoal

# Slight blur on alpha edge for cleanliness
rgba = Image.fromarray(out.astype(np.uint8), "RGBA")
# Crop
alpha = np.array(rgba)[:, :, 3]
ys, xs = np.where(alpha > 8)
pad = 12
y0, y1 = max(0, ys.min() - pad), min(h, ys.max() + pad + 1)
x0, x1 = max(0, xs.min() - pad), min(w, xs.max() + pad + 1)
cropped = np.array(rgba)[y0:y1, x0:x1]
light = Image.fromarray(cropped, "RGBA")

# Dark variant: charcoal -> white; keep red
dark_arr = cropped.astype(np.float32).copy()
rr, gg, bb, aa = [dark_arr[:, :, i] for i in range(4)]
opaque = aa > 15
redish = opaque & (rr > 130) & (rr > gg + 35) & (rr > bb + 35)
darkish = opaque & ~redish & (rr < 110) & (gg < 110) & (bb < 115)
dark_arr[darkish, 0:3] = 255
mid = opaque & ~redish & ~darkish & (rr < 170) & (np.abs(rr - gg) < 30)
t = (170 - rr[mid]) / 170.0
dark_arr[mid, 0] = np.clip(rr[mid] + t * (255 - rr[mid]), 0, 255)
dark_arr[mid, 1] = np.clip(gg[mid] + t * (255 - gg[mid]), 0, 255)
dark_arr[mid, 2] = np.clip(bb[mid] + t * (255 - bb[mid]), 0, 255)
dark = Image.fromarray(dark_arr.astype(np.uint8), "RGBA")

for name, img in [
    ("slst-logo-light.png", light),
    ("slst-logo-dark.png", dark),
    ("slst-mark.png", light),
    ("slst-mark-dark.png", dark),
    ("slst-wordmark.png", light),
    ("slst-wordmark-dark.png", dark),
]:
    img.save(out_dir / name)

email = out_dir / "email"
email.mkdir(exist_ok=True)
light.save(email / "slst-logo-email.png")
dark.save(email / "slst-logo-email-dark.png")
print("OK", light.size)
