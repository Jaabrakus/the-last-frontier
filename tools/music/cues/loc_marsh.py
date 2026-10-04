"""The marsh: still water and things moving under it. F-sharp minor leaning on its flat second (G), a bassoon's low
line, plucked low strings at odd moments, violas trembling softly, a glockenspiel's cold drops. 56 BPM, about 1:05.

	0-1     the violas' tremolo, the first plucks
	2-9     the bassoon
	10-13   the clarinet low, the bassoon under it, the drops
	14-15   the tremolo fading
"""
from __future__ import annotations

import numpy as np

from _lib import arc, bars
from orch import Score

CUE = dict(name="loc_marsh", target=-23.0)

BASSOON = bars([
	[(0, "F#3", 3), (3, "G3", 1)],
	[(0, "F#3", 4)],
	[(0, "A3", 1.5), (1.5, "G3", 0.5), (2, "F#3", 1), (3, "E3", 1)],
	[(0, "F#3", 4)],
	[(0, "C#4", 2), (2, "D4", 1), (3, "C#4", 1)],
	[(0, "B3", 2), (2, "G3", 2)],
	[(0, "A3", 1), (1, "G3", 1), (2, "E3", 1), (3, "G3", 1)],
	[(0, "F#3", 4)],
])
CLAR = bars([
	[(0, "C#4", 3), (3, "D4", 1)],
	[(0, "C#4", 2), (2, "A3", 2)],
	[(0, "B3", 1), (1, "D4", 1), (2, "G4", 2)],
	[(0, "F#4", 4)],
])


def build() -> Score:
	s = Score(56, 4, seed=211, hall=3.0)
	s.chord("vla_trem", 0, 0, ["C#4", "F#4"], 32, [(0, 0.05), (0.1, 0.22), (0.5, 0.18), (0.6, 0.24), (1, 0.18)])
	s.chord("vla_trem", 8, 0, ["G4"], 8, [(0, 0.05), (0.5, 0.18), (1, 0.05)])
	s.chord("vla_trem", 8, 0, ["C#4", "F#4"], 32, [(0, 0.18), (0.8, 0.2), (1, 0.03)])
	s.note("cb_nv", 0, 0, "F#2", 64, [(0, 0.05), (0.1, 0.2), (0.9, 0.18), (1, 0.03)])
	rng = np.random.default_rng(5)
	for bar in range(0, 15):
		for beat in sorted(rng.choice([0.0, 0.75, 1.5, 2.25, 2.5, 3.25], size=int(rng.integers(1, 3)), replace=False)):
			s.note("vc_pizz" if rng.random() < 0.6 else "cb_pizz", bar, float(beat),
					["F#2", "C#3", "G2", "F#3", "A2"][int(rng.integers(0, 5))], 0.5, 0.35 + 0.15 * rng.random())
		if bar >= 10 and rng.random() < 0.6:
			s.note("glock", bar, float(rng.choice([1.25, 2.5, 3.5])), ["F#6", "G6", "C#7", "A6"][int(rng.integers(0, 4))],
					1, 0.22)
	s.line("bsn", 2, arc(BASSOON, 0.42, 0.52))
	s.line("cl", 10, arc(CLAR, 0.36, 0.44))
	s.line("bsn", 10, [(0, "F#2", 8, 0.3), (8, "D3", 4, 0.3), (12, "C#3", 4, 0.3)])
	drums_and_bass(s)
	return s


def drums_and_bass(s: Score) -> None:
	"""More drums and bass (user 2026-10-03: "add more drums and bass"): a log drum now and then, a muted bass drum's
	thump, a sub drone."""
	rng = np.random.default_rng(9)
	for b in range(0, 15):
		if rng.random() < 0.5:
			s.hit("logdrum", b, float(rng.choice([0.5, 1.75, 2.75])), 0.22)
		if b % 2 == 0:
			s.hit("bd_muted", b, 0, 0.28)
	s.note("sub", 0, 0, "F#1", 64, [(0, 0.05), (0.1, 0.3), (0.9, 0.28), (1, 0.03)])
