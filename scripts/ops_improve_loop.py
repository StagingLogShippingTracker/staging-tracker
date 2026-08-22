#!/usr/bin/env python3
"""Ops improve loop — delegates to improve_loop_runner."""
from __future__ import annotations
import runpy
import sys
from pathlib import Path

sys.argv = [str(Path(__file__)), "ops", *sys.argv[1:]]
runpy.run_path(str(Path(__file__).resolve().parent / "improve_loop_runner.py"), run_name="__main__")
