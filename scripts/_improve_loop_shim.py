#!/usr/bin/env python3
"""Thin wrapper — prefer scripts/improve_loop_runner.py <domain>."""
from __future__ import annotations
import runpy
import sys
from pathlib import Path

sys.argv = [sys.argv[0], Path(__file__).stem.replace("_improve_loop", ""), *sys.argv[1:]]
# Map script names: app_improve_loop → app
name = Path(__file__).name
domain = name.replace("_improve_loop.py", "")
sys.argv = [sys.argv[0], domain] + [a for a in sys.argv[1:] if a != domain]
runpy.run_path(str(Path(__file__).resolve().parent / "improve_loop_runner.py"), run_name="__main__")
