#!/usr/bin/env python3
"""Regenerates every sound family, then the game's sound table (scripts/audio/sfx_manifest.gd).

Usage (project root):
  python3 tools/sfx/gen_all.py                 # shipped set (each family's default seed)
  python3 tools/sfx/gen_all.py --only bow impacts
Afterwards run a Godot import pass so new WAVs load:
  Godot --headless --path . --import
For another take of one family use its own script (e.g. python3 tools/sfx/bow.py --seed 7)
and then python3 tools/sfx/gen_manifest.py.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
# gathering_rec.py builds from the CC0 recordings (see audio/sfx/gathering_rec/SOURCE.md); without the packs it keeps
# the baked WAVs
FAMILIES = ["flintlock", "bow", "impacts", "targets", "footsteps", "ambience", "gathering_rec"]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", nargs="*", default=None, help="families to regenerate")
    a = ap.parse_args()
    for fam in a.only or FAMILIES:
        print("==", fam, flush=True)
        subprocess.run([sys.executable, os.path.join(HERE, fam + ".py")], check=True)
    subprocess.run([sys.executable, os.path.join(HERE, "gen_manifest.py")], check=True)


if __name__ == "__main__":
    main()
