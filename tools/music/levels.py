#!/usr/bin/env python3
"""A cue's balance without ears: each instrument rendered alone (dry), its loudness (dB RMS) every few bars.

    python3 tools/music/levels.py main_theme [bars a section, default 4]
"""
from __future__ import annotations

import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "cues"))
import orch  # noqa: E402


def main() -> None:
	name = sys.argv[1]
	step = int(sys.argv[2]) if len(sys.argv) > 2 else 4
	from render import build
	s = build(name)
	insts = sorted({e["inst"] for e in s.events})
	nb = 0
	while s.t(nb) < s.length():
		nb += 1
	secs = list(range(0, nb, step))
	print(f"{'':11s}" + "".join(f"{b:>6d}" for b in secs))
	events = s.events
	for inst in insts:
		s.events = [e for e in events if e["inst"] == inst]
		x = orch.render(s, tail=1.0, dry_only=True, verbose=False).mean(axis=1)
		row = []
		for b in secs:
			a, c = int(s.t(b) * orch.SR), int(s.t(min(b + step, nb)) * orch.SR)
			seg = x[a:c]
			r = 10 * np.log10(np.mean(seg ** 2) + 1e-12) if len(seg) else -120
			row.append(f"{r:6.0f}" if r > -70 else "     .")
		print(f"{inst:11s}" + "".join(row), flush=True)
	s.events = events


if __name__ == "__main__":
	main()
