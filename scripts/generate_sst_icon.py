"""DEPRECATED — use scripts/generate_slst_icon.py with assets/slst-app-icon.png."""

from __future__ import annotations

import sys


def main() -> None:
    sys.stderr.write(
        "REFUSED: use python scripts/generate_slst_icon.py\n"
        "(Official SLST logo: assets/slst-app-icon.png)\n"
    )
    raise SystemExit(2)


if __name__ == "__main__":
    main()
