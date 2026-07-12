# SLST Brand Font

Custom geometric extended sans-serif derived from the SLST logo wordmark (`brand/source/1783831063527.png`).

## Pattern (from logo scan)

| Rule | Detail |
|------|--------|
| Weight | Extra-bold, uniform stroke (~172 upem at 1000 UPM) |
| Width | Extended — cap advance ~640 upem |
| Terminals | Open horizontal ends cut on a **diagonal slant** (top-left → bottom-right, ~55% dx/dy) |
| Corners | Sharp outer corners; minimal internal rounding |
| Construction | Rectilinear bars and stems (Eurostile / Microgramma lineage) |

## Logo-exact glyphs

These three characters are **traced directly** from the logo PNG:

- **S** — slanted top-right and bottom-left terminals
- **L** — wide foot with slanted right terminal
- **T** — crossbar with parallel slanted left/right ends

## Pattern-matched alphabet

All remaining glyphs follow the same rules:

**Uppercase:** A B C D E F G H I J K M N O P Q R U V W X Y Z  
**Digits:** 0 1 2 3 4 5 6 7 8 9  
**Punctuation:** space `-` `.` `:` `/` `#`

## Files

| File | Purpose |
|------|---------|
| `SLSTBrand-Regular.woff2` | Web font (primary) |
| `SLSTBrand-Regular.ttf` | Desktop / fallback |
| `slst-brand.css` | `@font-face` declaration |
| `build_slst_font.py` | Rebuild script (requires Python 3.12+, fonttools, pillow, scikit-image, brotli) |
| `font-metrics.json` | Measured logo letter boxes and stroke width |
| `debug/S1.png`, `L.png`, `T.png` | Cropped logo letter references |

## Rebuild

```powershell
python brand\fonts\build_slst_font.py
```
