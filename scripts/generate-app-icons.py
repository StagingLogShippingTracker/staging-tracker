"""DEPRECATED — use scripts/generate_slst_icon.py."""

from __future__ import annotations

import sys


def main() -> None:
    sys.stderr.write("REFUSED: use python scripts/generate_slst_icon.py\n")
    raise SystemExit(2)


if __name__ == "__main__":
    main()
