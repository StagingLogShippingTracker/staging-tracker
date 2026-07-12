#!/usr/bin/env python3
"""Build SLST Brand font from logo PNG — exact S/L/T + pattern-matched alphabet."""

from __future__ import annotations

import json
import math
import os
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib.tables._g_l_y_f import Glyph
from fontTools.ttLib.tables._h_m_t_x import table__h_m_t_x

ROOT = Path(__file__).resolve().parent
DOWNLOADS = ROOT.parent.parent
LOGO = DOWNLOADS / "brand" / "source" / "1783831063527.png"
OUT_DIR = ROOT
UPM = 1000
CAP = 700
BASELINE = 0
SLANT = 0.55  # dx per dy for diagonal terminals (top-left → bottom-right)


@dataclass
class Metrics:
    stroke: float = 140.0
    cap: float = CAP
    baseline: float = BASELINE
    slant: float = SLANT
    tracking: float = 40.0


M = Metrics()


def slant_cut(x: float, y0: float, y1: float, outward: bool = True) -> list[tuple[float, float]]:
    """Diagonal terminal from y0 to y1 at x."""
    dy = y1 - y0
    dx = dy * M.slant * (1 if outward else -1)
    return [(x, y0), (x + dx, y1)]


def rect(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)]


def draw_poly(pen, pts, close=True):
    if not pts:
        return
    pen.moveTo(pts[0])
    for pt in pts[1:]:
        pen.lineTo(pt)
    if close:
        pen.closePath()


def union_rects(pen, rects):
    for r in rects:
        draw_poly(pen, rect(*r))


def glyph_S(pen, ox=0.0):
    s = M.stroke
    w = 620
    # Top bar
    union_rects(pen, [(ox, M.cap - s, ox + w, M.cap)])
    # Middle bar
    union_rects(pen, [(ox, (M.cap - s) / 2, ox + w, (M.cap - s) / 2 + s)])
    # Bottom bar
    union_rects(pen, [(ox, BASELINE, ox + w, BASELINE + s)])
    # Left top vertical
    union_rects(pen, [(ox, (M.cap - s) / 2 + s, ox + s, M.cap - s)])
    # Right bottom vertical
    union_rects(pen, [(ox + w - s, BASELINE + s, ox + w, (M.cap - s) / 2)])
    # Slanted top-right terminal
    x = ox + w - s
    y0 = M.cap - s
    y1 = M.cap
    dy = y1 - y0
    dx = dy * M.slant
    draw_poly(pen, [(x, y0), (x + dx, y1), (ox + w, y1), (ox + w, y0)])
    # Slanted bottom-left terminal
    x = ox
    y0 = BASELINE
    y1 = BASELINE + s
    dy = y1 - y0
    dx = dy * M.slant
    draw_poly(pen, [(ox, y0), (ox + s, y0), (ox + s, y1), (ox + dx, y1)])


def glyph_L(pen, ox=0.0):
    s = M.stroke
    w = 560
    foot = 520
    union_rects(pen, [(ox, BASELINE, ox + s, M.cap)])
    union_rects(pen, [(ox, BASELINE, ox + foot, BASELINE + s)])
    x = ox + foot - s
    y0 = BASELINE
    y1 = BASELINE + s
    dy = y1 - y0
    dx = dy * M.slant
    draw_poly(pen, [(x, y0), (x + dx, y1), (ox + foot, y1), (ox + foot, y0)])


def glyph_T(pen, ox=0.0):
    s = M.stroke
    w = 640
    stem_x = ox + (w - s) / 2
    union_rects(pen, [(ox, M.cap - s, ox + w, M.cap)])
    union_rects(pen, [(stem_x, BASELINE, stem_x + s, M.cap - s)])
    # Left slanted crossbar end
    x = ox
    y0 = M.cap - s
    y1 = M.cap
    dy = y1 - y0
    dx = dy * M.slant
    draw_poly(pen, [(x, y0), (x + dx, y1), (ox + s, y1), (ox + s, y0)])
    # Right slanted crossbar end
    x = ox + w - s
    draw_poly(pen, [(x, y0), (ox + w, y0), (ox + w, y1), (x + dx, y1)])


def glyph_A(pen, ox=0.0):
    s = M.stroke
    w = 620
    mid = ox + w / 2
    bar_y = 280
    draw_poly(pen, [(ox + s * 0.6, BASELINE), (mid, M.cap), (mid - s / 2, M.cap), (ox, BASELINE + s), (ox + s, BASELINE + s)])
    draw_poly(pen, [(mid, M.cap), (ox + w - s * 0.6, BASELINE), (ox + w - s, BASELINE + s), (ox + w, BASELINE + s), (mid + s / 2, M.cap)])
    union_rects(pen, [(ox + s * 1.2, bar_y, ox + w - s * 1.2, bar_y + s)])


def glyph_B(pen, ox=0.0):
    s = M.stroke
    w = 580
    union_rects(pen, [(ox, BASELINE, ox + s, M.cap)])
    union_rects(pen, [(ox, M.cap - s, ox + w, M.cap)])
    union_rects(pen, [(ox, (M.cap - s) / 2, ox + w, (M.cap - s) / 2 + s)])
    union_rects(pen, [(ox, BASELINE, ox + w, BASELINE + s)])
    union_rects(pen, [(ox + w - s, (M.cap - s) / 2 + s, ox + w, M.cap - s)])
    union_rects(pen, [(ox + w - s, BASELINE + s, ox + w, (M.cap - s) / 2)])


def glyph_C(pen, ox=0.0):
    s = M.stroke
    w = 580
    union_rects(pen, [(ox + s, M.cap - s, ox + w, M.cap)])
    union_rects(pen, [(ox + s, BASELINE, ox + w, BASELINE + s)])
    union_rects(pen, [(ox, BASELINE + s, ox + s, M.cap - s)])
    x = ox + s
    y0 = M.cap - s
    y1 = M.cap
    dx = (y1 - y0) * M.slant
    draw_poly(pen, [(x, y0), (x + dx, y1), (ox + w, y1), (ox + w, y0)])
    x = ox + s
    y0 = BASELINE
    y1 = BASELINE + s
    dx = (y1 - y0) * M.slant
    draw_poly(pen, [(x, y0), (ox + w, y0), (ox + w, y1), (x + dx, y1)])


def glyph_D(pen, ox=0.0):
    s = M.stroke
    w = 600
    union_rects(pen, [(ox, BASELINE, ox + s, M.cap)])
    union_rects(pen, [(ox, M.cap - s, ox + w - s, M.cap)])
    union_rects(pen, [(ox, BASELINE, ox + w - s, BASELINE + s)])
    union_rects(pen, [(ox + w - s, BASELINE + s, ox + w, M.cap - s)])


def glyph_E(pen, ox=0.0):
    s = M.stroke
    w = 520
    union_rects(pen, [(ox, BASELINE, ox + s, M.cap)])
    union_rects(pen, [(ox, M.cap - s, ox + w, M.cap)])
    union_rects(pen, [(ox, (M.cap - s) / 2, ox + w * 0.75, (M.cap - s) / 2 + s)])
    union_rects(pen, [(ox, BASELINE, ox + w, BASELINE + s)])


def glyph_F(pen, ox=0.0):
    s = M.stroke
    w = 520
    union_rects(pen, [(ox, BASELINE, ox + s, M.cap)])
    union_rects(pen, [(ox, M.cap - s, ox + w, M.cap)])
    union_rects(pen, [(ox, (M.cap - s) / 2, ox + w * 0.75, (M.cap - s) / 2 + s)])


def glyph_G(pen, ox=0.0):
    s = M.stroke
    w = 620
    glyph_C(pen, ox)
    union_rects(pen, [(ox + w * 0.45, (M.cap - s) / 2, ox + w - s, (M.cap - s) / 2 + s)])
    union_rects(pen, [(ox + w - s, (M.cap - s) / 2, ox + w, (M.cap - s) / 2 + s * 2)])


def glyph_H(pen, ox=0.0):
    s = M.stroke
    w = 620
    union_rects(pen, [(ox, BASELINE, ox + s, M.cap)])
    union_rects(pen, [(ox + w - s, BASELINE, ox + w, M.cap)])
    union_rects(pen, [(ox, (M.cap - s) / 2, ox + w, (M.cap - s) / 2 + s)])


def glyph_I(pen, ox=0.0):
    s = M.stroke
    w = 260
    stem = ox + (w - s) / 2
    union_rects(pen, [(ox, M.cap - s, ox + w, M.cap)])
    union_rects(pen, [(ox, BASELINE, ox + w, BASELINE + s)])
    union_rects(pen, [(stem, BASELINE + s, stem + s, M.cap - s)])


def glyph_J(pen, ox=0.0):
    s = M.stroke
    w = 420
    stem = ox + w - s
    union_rects(pen, [(ox, M.cap - s, ox + w, M.cap)])
    union_rects(pen, [(stem, BASELINE + s * 1.5, stem + s, M.cap - s)])
    union_rects(pen, [(ox, BASELINE, ox + s * 2.5, BASELINE + s)])


def glyph_K(pen, ox=0.0):
    s = M.stroke
    w = 600
    mid = (M.cap - s) / 2
    union_rects(pen, [(ox, BASELINE, ox + s, M.cap)])
    draw_poly(pen, [(ox + s, mid), (ox + w, M.cap), (ox + w - s * 0.7, M.cap), (ox + s, mid + s * 0.6)])
    draw_poly(pen, [(ox + s, mid), (ox + w, BASELINE), (ox + w - s * 0.7, BASELINE + s), (ox + s, mid - s * 0.4)])


def glyph_M(pen, ox=0.0):
    s = M.stroke
    w = 760
    mid = ox + w / 2
    union_rects(pen, [(ox, BASELINE, ox + s, M.cap)])
    union_rects(pen, [(ox + w - s, BASELINE, ox + w, M.cap)])
    draw_poly(pen, [(ox + s, M.cap - s), (mid - s / 2, BASELINE + s * 2), (mid + s / 2, BASELINE + s * 2), (ox + w - s, M.cap - s), (ox + w - s, M.cap), (ox + s, M.cap)])


def glyph_N(pen, ox=0.0):
    s = M.stroke
    w = 640
    union_rects(pen, [(ox, BASELINE, ox + s, M.cap)])
    union_rects(pen, [(ox + w - s, BASELINE, ox + w, M.cap)])
    draw_poly(pen, [(ox + s, M.cap - s), (ox + w - s, BASELINE + s), (ox + w - s, BASELINE), (ox + w, BASELINE + s), (ox + w, M.cap - s), (ox + s, M.cap - s)])


def glyph_O(pen, ox=0.0):
    s = M.stroke
    w = 640
    union_rects(pen, [(ox, M.cap - s, ox + w, M.cap)])
    union_rects(pen, [(ox, BASELINE, ox + w, BASELINE + s)])
    union_rects(pen, [(ox, BASELINE + s, ox + s, M.cap - s)])
    union_rects(pen, [(ox + w - s, BASELINE + s, ox + w, M.cap - s)])


def glyph_P(pen, ox=0.0):
    s = M.stroke
    w = 560
    union_rects(pen, [(ox, BASELINE, ox + s, M.cap)])
    union_rects(pen, [(ox, M.cap - s, ox + w, M.cap)])
    union_rects(pen, [(ox, (M.cap - s) / 2, ox + w, (M.cap - s) / 2 + s)])
    union_rects(pen, [(ox + w - s, (M.cap - s) / 2 + s, ox + w, M.cap - s)])


def glyph_Q(pen, ox=0.0):
    s = M.stroke
    w = 640
    glyph_O(pen, ox)
    draw_poly(pen, [(ox + w * 0.55, BASELINE + s * 2), (ox + w, BASELINE - s * 0.5), (ox + w - s, BASELINE - s * 0.5), (ox + w * 0.55, BASELINE + s)])


def glyph_R(pen, ox=0.0):
    s = M.stroke
    w = 580
    glyph_P(pen, ox)
    draw_poly(pen, [(ox + w - s, (M.cap - s) / 2), (ox + w, BASELINE), (ox + w - s * 0.7, BASELINE + s), (ox + w - s, (M.cap - s) / 2 + s)])


def glyph_U(pen, ox=0.0):
    s = M.stroke
    w = 620
    union_rects(pen, [(ox, BASELINE + s * 2, ox + s, M.cap)])
    union_rects(pen, [(ox + w - s, BASELINE + s * 2, ox + w, M.cap)])
    union_rects(pen, [(ox, BASELINE, ox + w, BASELINE + s)])


def glyph_V(pen, ox=0.0):
    s = M.stroke
    w = 640
    mid = ox + w / 2
    draw_poly(pen, [(ox, M.cap), (ox + s, M.cap - s), (mid - s / 2, BASELINE + s), (mid + s / 2, BASELINE + s), (ox + w - s, M.cap - s), (ox + w, M.cap), (ox + w - s * 1.5, M.cap - s), (mid, BASELINE), (ox + s * 1.5, M.cap - s)])


def glyph_W(pen, ox=0.0):
    s = M.stroke
    w = 900
    q = w / 4
    draw_poly(pen, [(ox, M.cap), (ox + s, M.cap - s), (ox + q, BASELINE + s * 2), (ox + 2 * q - s / 2, M.cap * 0.55), (ox + 2 * q + s / 2, M.cap * 0.55), (ox + 3 * q, BASELINE + s * 2), (ox + w - s, M.cap - s), (ox + w, M.cap), (ox + w - s * 1.5, M.cap - s), (ox + 3 * q, BASELINE), (ox + 2 * q, M.cap * 0.45), (ox + q, BASELINE), (ox + s * 1.5, M.cap - s)])


def glyph_X(pen, ox=0.0):
    s = M.stroke
    w = 620
    mid = (M.cap - s) / 2
    draw_poly(pen, [(ox, M.cap), (ox + s * 1.2, M.cap - s), (ox + w / 2 - s / 2, mid + s / 2), (ox + w / 2 + s / 2, mid - s / 2), (ox + w - s * 1.2, BASELINE + s), (ox + w, BASELINE), (ox + w - s * 1.2, BASELINE + s), (ox + w / 2 + s / 2, mid + s / 2), (ox + w / 2 - s / 2, mid - s / 2), (ox + s * 1.2, M.cap - s)])
    draw_poly(pen, [(ox, BASELINE), (ox + s * 1.2, BASELINE + s), (ox + w / 2 - s / 2, mid + s / 2), (ox + w / 2 + s / 2, mid - s / 2), (ox + w - s * 1.2, M.cap - s), (ox + w, M.cap), (ox + w - s * 1.2, M.cap - s), (ox + w / 2 + s / 2, mid + s / 2), (ox + w / 2 - s / 2, mid - s / 2), (ox + s * 1.2, BASELINE + s)])


def glyph_Y(pen, ox=0.0):
    s = M.stroke
    w = 620
    mid = ox + w / 2
    split = 420
    draw_poly(pen, [(ox, M.cap), (ox + s, M.cap - s), (mid - s / 2, split), (mid + s / 2, split), (ox + w - s, M.cap - s), (ox + w, M.cap), (ox + w - s * 1.5, M.cap - s), (mid + s / 2, split + s), (mid - s / 2, split + s), (ox + s * 1.5, M.cap - s)])
    union_rects(pen, [(mid - s / 2, BASELINE, mid + s / 2, split + s)])


def glyph_Z(pen, ox=0.0):
    s = M.stroke
    w = 620
    union_rects(pen, [(ox, M.cap - s, ox + w, M.cap)])
    union_rects(pen, [(ox, BASELINE, ox + w, BASELINE + s)])
    draw_poly(pen, [(ox + w - s, M.cap - s), (ox + s, BASELINE + s), (ox + w, BASELINE + s), (ox + w, M.cap - s)])


def glyph_zero(pen, ox=0.0):
    glyph_O(pen, ox)


def glyph_one(pen, ox=0.0):
    s = M.stroke
    w = 380
    stem = ox + w * 0.55
    draw_poly(pen, [(stem - s, M.cap - s * 2), (stem, M.cap), (stem + s, M.cap - s * 0.5), (stem + s * 0.3, BASELINE), (stem - s * 0.3, BASELINE + s), (stem - s, M.cap - s * 2)])
    union_rects(pen, [(ox, BASELINE, ox + w, BASELINE + s)])


def glyph_two(pen, ox=0.0):
    s = M.stroke
    w = 560
    union_rects(pen, [(ox + s, M.cap - s, ox + w, M.cap)])
    union_rects(pen, [(ox, BASELINE, ox + w, BASELINE + s)])
    draw_poly(pen, [(ox + w - s, M.cap - s), (ox, BASELINE + s * 2), (ox + w, BASELINE + s * 2), (ox + w, M.cap - s)])


def glyph_three(pen, ox=0.0):
    s = M.stroke
    w = 560
    union_rects(pen, [(ox, M.cap - s, ox + w, M.cap)])
    union_rects(pen, [(ox, (M.cap - s) / 2, ox + w, (M.cap - s) / 2 + s)])
    union_rects(pen, [(ox, BASELINE, ox + w, BASELINE + s)])
    union_rects(pen, [(ox + w - s, BASELINE + s, ox + w, M.cap - s)])


def glyph_four(pen, ox=0.0):
    s = M.stroke
    w = 560
    union_rects(pen, [(ox + w - s, BASELINE, ox + w, M.cap)])
    union_rects(pen, [(ox, (M.cap - s) / 2, ox + w, (M.cap - s) / 2 + s)])
    draw_poly(pen, [(ox + s * 2, M.cap), (ox, (M.cap - s) / 2 + s), (ox + s, (M.cap - s) / 2), (ox + s * 2.5, M.cap - s)])


def glyph_five(pen, ox=0.0):
    s = M.stroke
    w = 560
    union_rects(pen, [(ox, M.cap - s, ox + w, M.cap)])
    union_rects(pen, [(ox, (M.cap - s) / 2, ox + w, (M.cap - s) / 2 + s)])
    union_rects(pen, [(ox, BASELINE, ox + w, BASELINE + s)])
    union_rects(pen, [(ox, (M.cap - s) / 2, ox + s, M.cap - s)])
    union_rects(pen, [(ox + w - s, BASELINE + s, ox + w, (M.cap - s) / 2)])


def glyph_six(pen, ox=0.0):
    s = M.stroke
    w = 560
    union_rects(pen, [(ox + s, M.cap - s, ox + w, M.cap)])
    union_rects(pen, [(ox, BASELINE + s, ox + s, M.cap - s)])
    union_rects(pen, [(ox, BASELINE, ox + w, BASELINE + s)])
    union_rects(pen, [(ox + w - s, BASELINE + s, ox + w, (M.cap - s) / 2)])


def glyph_seven(pen, ox=0.0):
    s = M.stroke
    w = 560
    union_rects(pen, [(ox, M.cap - s, ox + w, M.cap)])
    draw_poly(pen, [(ox + w - s, M.cap - s), (ox + w * 0.15, BASELINE), (ox + w * 0.15 + s, BASELINE + s), (ox + w, M.cap - s)])


def glyph_eight(pen, ox=0.0):
    s = M.stroke
    w = 560
    glyph_O(pen, ox)
    union_rects(pen, [(ox, (M.cap - s) / 2, ox + w, (M.cap - s) / 2 + s)])


def glyph_nine(pen, ox=0.0):
    s = M.stroke
    w = 560
    union_rects(pen, [(ox + s, BASELINE, ox + w, BASELINE + s)])
    union_rects(pen, [(ox, (M.cap - s) / 2, ox + s, M.cap - s)])
    union_rects(pen, [(ox, M.cap - s, ox + w, M.cap)])
    union_rects(pen, [(ox + w - s, (M.cap - s) / 2, ox + w, BASELINE + s)])


def glyph_space(pen, ox=0.0):
    pass


def glyph_hyphen(pen, ox=0.0):
    s = M.stroke * 0.55
    union_rects(pen, [(ox + 80, (M.cap - s) / 2, ox + 420, (M.cap - s) / 2 + s)])


def glyph_period(pen, ox=0.0):
    s = M.stroke
    union_rects(pen, [(ox + 120, BASELINE, ox + 120 + s, BASELINE + s)])


def glyph_colon(pen, ox=0.0):
    s = M.stroke * 0.65
    union_rects(pen, [(ox + 120, 420, ox + 120 + s, 420 + s)])
    union_rects(pen, [(ox + 120, BASELINE, ox + 120 + s, BASELINE + s)])


def glyph_slash(pen, ox=0.0):
    s = M.stroke * 0.75
    draw_poly(pen, [(ox + 80, BASELINE), (ox + 80 + s, BASELINE + s), (ox + 420, M.cap), (ox + 420 - s, M.cap - s)])


def glyph_hash(pen, ox=0.0):
    s = M.stroke * 0.55
    union_rects(pen, [(ox + 120, BASELINE + s, ox + 140 + s, M.cap - s)])
    union_rects(pen, [(ox + 320, BASELINE + s, ox + 340 + s, M.cap - s)])
    union_rects(pen, [(ox + 40, 430, ox + 460, 430 + s)])
    union_rects(pen, [(ox + 40, 250, ox + 460, 250 + s)])


GLYPH_BUILDERS = {
    "A": glyph_A, "B": glyph_B, "C": glyph_C, "D": glyph_D, "E": glyph_E,
    "F": glyph_F, "G": glyph_G, "H": glyph_H, "I": glyph_I, "J": glyph_J,
    "K": glyph_K, "L": glyph_L, "M": glyph_M, "N": glyph_N, "O": glyph_O,
    "P": glyph_P, "Q": glyph_Q, "R": glyph_R, "S": glyph_S, "T": glyph_T,
    "U": glyph_U, "V": glyph_V, "W": glyph_W, "X": glyph_X, "Y": glyph_Y,
    "Z": glyph_Z,
    "0": glyph_zero, "1": glyph_one, "2": glyph_two, "3": glyph_three,
    "4": glyph_four, "5": glyph_five, "6": glyph_six, "7": glyph_seven,
    "8": glyph_eight, "9": glyph_nine,
    " ": glyph_space, "-": glyph_hyphen, ".": glyph_period, ":": glyph_colon,
    "/": glyph_slash, "#": glyph_hash,
}


def load_logo_mask() -> tuple[np.ndarray, tuple[int, int]]:
    img = Image.open(LOGO).convert("L")
    arr = np.array(img)
    mask = arr < 128
    return mask, img.size


def find_letter_boxes(mask: np.ndarray) -> list[tuple[int, int, int, int]]:
    h, w = mask.shape
    col = mask.sum(axis=0)
    threshold = max(1, col.max() * 0.05)
    active = col > threshold
    boxes = []
    in_run = False
    start = 0
    for x in range(w):
        if active[x] and not in_run:
            start = x
            in_run = True
        elif not active[x] and in_run:
            boxes.append((start, x))
            in_run = False
    if in_run:
        boxes.append((start, w - 1))
    row_idx = np.where(mask.any(axis=1))[0]
    y0, y1 = int(row_idx.min()), int(row_idx.max())
    return [(x0, y0, x1, y1) for x0, x1 in boxes]


def bitmap_to_glyph(mask_crop: np.ndarray, target_width: float) -> Glyph:
    """Trace bitmap silhouette contours into a TT glyph."""
    from skimage import measure

    h, w = mask_crop.shape
    scale_x = target_width / w
    scale_y = M.cap / h

    def to_font(x: float, y: float) -> tuple[float, float]:
        return (x * scale_x, M.cap - y * scale_y)

    tt_pen = TTGlyphPen(None)
    # Outer boundary first, then holes (inner contours)
    contours = measure.find_contours(mask_crop.astype(float), 0.5)
    if not contours:
        return tt_pen.glyph()

    # Sort by area descending — largest is outer shell
    def contour_area(c):
        xs, ys = c[:, 1], c[:, 0]
        return 0.5 * abs(np.dot(xs, np.roll(ys, 1)) - np.dot(ys, np.roll(xs, 1)))

    contours = sorted(contours, key=contour_area, reverse=True)

    for ci, contour in enumerate(contours):
        if len(contour) < 3:
            continue
        # Subsample very dense contours
        step = max(1, len(contour) // 120)
        pts = contour[::step]
        fx, fy = to_font(pts[0, 1], pts[0, 0])
        tt_pen.moveTo((fx, fy))
        for row, col in pts[1:]:
            fx, fy = to_font(col, row)
            tt_pen.lineTo((fx, fy))
        tt_pen.closePath()

    return tt_pen.glyph()


def calibrate_from_logo() -> dict:
    mask, size = load_logo_mask()
    boxes = find_letter_boxes(mask)
    crops = {}
    labels = ["S1", "L", "S2", "T"]
    debug_dir = OUT_DIR / "debug"
    debug_dir.mkdir(parents=True, exist_ok=True)
    for i, (label, box) in enumerate(zip(labels, boxes)):
        x0, y0, x1, y1 = box
        crop = mask[y0 : y1 + 1, x0 : x1 + 1]
        Image.fromarray((~crop).astype(np.uint8) * 255).save(debug_dir / f"{label}.png")
        crops[label] = crop
    # Measure stroke from L vertical
    l_crop = crops["L"]
    lh, lw = l_crop.shape
    col_sum = l_crop.sum(axis=0)
    stroke_px = int(np.argmax(col_sum > lh * 0.5))
    stroke_w = 0
    for x in range(lw):
        if l_crop[:, x].sum() > lh * 0.5:
            stroke_w += 1
        elif stroke_w:
            break
    M.stroke = max(100, min(180, stroke_w / lw * 620))
    meta = {
        "logo_size": size,
        "letter_boxes": boxes,
        "measured_stroke_units": M.stroke,
        "letters_found": labels[: len(boxes)],
    }
    (OUT_DIR / "font-metrics.json").write_text(json.dumps(meta, indent=2))
    return crops


def build_glyph(char: str, crops: dict) -> tuple[Glyph, float]:
    widths = {
        "I": 300, "J": 420, " ": 280, ".": 280, ":": 280, "-": 500,
        "/": 500, "#": 500,
    }
    default_w = 640
    advance = widths.get(char, default_w) + M.tracking

    if char == "S" and "S1" in crops:
        g = bitmap_to_glyph(crops["S1"], default_w)
        return g, advance
    if char == "L" and "L" in crops:
        g = bitmap_to_glyph(crops["L"], 560)
        return g, 560 + M.tracking
    if char == "T" and "T" in crops:
        g = bitmap_to_glyph(crops["T"], 640)
        return g, 640 + M.tracking

    pen = TTGlyphPen(None)
    GLYPH_BUILDERS[char](pen)
    return pen.glyph(), advance


def build_font():
    crops = calibrate_from_logo()
    M.stroke = round(M.stroke)  # use measured stroke from logo
    chars = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -.:/#")

    glyph_names = [".notdef", "space"]
    cmap = {32: "space"}
    glyphs = {}
    advances = {}

    pen = TTGlyphPen(None)
    union_rects(pen, [(100, 100, 300, 600)])
    glyphs[".notdef"] = pen.glyph()
    advances[".notdef"] = 600

    pen = TTGlyphPen(None)
    glyph_space(pen)
    glyphs["space"] = pen.glyph()
    advances["space"] = 320

    punct_names = {".": "period", "-": "hyphen", ":": "colon", "/": "slash", "#": "hash"}
    for c in chars:
        if c == " ":
            continue
        gname = c if c.isalnum() else punct_names[c]
        glyph, adv = build_glyph(c, crops)
        glyphs[gname] = glyph
        advances[gname] = adv
        glyph_names.append(gname)
        cmap[ord(c)] = gname

    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(glyph_names)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics({k: (advances[k], 0) for k in glyph_names})
    fb.setupHorizontalHeader(ascent=800, descent=-200)
    fb.setupNameTable({
        "familyName": "SLST Brand",
        "styleName": "Regular",
        "uniqueFontIdentifier": "SLSTBrand-Regular",
        "fullName": "SLST Brand Regular",
        "psName": "SLSTBrand-Regular",
        "version": "Version 1.000",
    })
    fb.setupPost()

    ttf_path = OUT_DIR / "SLSTBrand-Regular.ttf"
    woff2_path = OUT_DIR / "SLSTBrand-Regular.woff2"
    fb.save(ttf_path)
    from fontTools.ttLib import TTFont

    tt = TTFont(ttf_path)
    tt.flavor = "woff2"
    tt.save(woff2_path)
    print(f"Wrote {ttf_path}")
    print(f"Wrote {woff2_path}")


if __name__ == "__main__":
    build_font()
