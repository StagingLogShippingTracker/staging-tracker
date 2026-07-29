"""DEPRECATED — do not generate SST launchers from this script.

The old SLST mark/wordmark pipeline produced soft/blurry mipmaps and ICO files.
SST icons are generated only by:

    python scripts/generate_sst_icon.py

That script paints a crisp supersampled SST master into assets/sst-app-icon.png
and refreshes Windows ICO + Android/Wear mipmaps.
"""

from __future__ import annotations

import sys


def main() -> None:
    sys.stderr.write(
        "REFUSED: scripts/generate-app-icons.py is retired.\n"
        "Run: python scripts/generate_sst_icon.py\n"
    )
    raise SystemExit(2)


if __name__ == "__main__":
    main()
