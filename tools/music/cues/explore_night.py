"""Embers (heard now and then at night): very quiet. A clarinet low in D minor, a far flute, the low strings
barely there, the harp and a glockenspiel like stars. 52 BPM, about 1:15.

	0-1     the low strings
	2-9     the clarinet
	10-13   the flute high and far
	14-15   D minor with its ninth, fading
"""
from __future__ import annotations

import numpy as np

from _lib import Voices, arc, bars, chord, chord_spans, near, pads, roots
from orch import Score

CUE = dict(name="explore_night", target=-23.0)

CH = [[(0, "Dm")], [(0, "Dm")],
		[(0, "Dm")], [(0, "Bbmaj7")], [(0, "F/A")], [(0, "Gm6")], [(0, "Dm/F")], [(0, "Em7b5")], [(0, "Asus4")],
		[(0, "A")],
		[(0, "Dm")], [(0, "Bbmaj7")], [(0, "F/A")], [(0, "Gm6")],
		[(0, "Dmadd9")], [(0, "Dmadd9")]]
CLARINET = bars([
	[(0, "A4", 3), (3, "G4", 1)],
	[(0, "F4", 2), (2, "D4", 2)],
	[(0, "C5", 2), (2, "A4", 1), (3, "G4", 1)],
	[(0, "E4", 4)],
	[(0, "A4", 1.5), (1.5, "Bb4", 0.5), (2, "A4", 1), (3, "F4", 1)],
	[(0, "G4", 2), (2, "E4", 2)],
	[(0, "D4", 2), (2, "E4", 2)],
	[(0, "C#4", 4)],
])
FLUTE = bars([
	[(0, "A5", 3), (3, "G5", 1)],
	[(0, "F5", 2), (2, "D5", 2)],
	[(0, "C6", 2), (2, "A5", 1), (3, "G5", 1)],
	[(0, "E5", 4)],
])


def build() -> Score:
	s = Score(52, 4, seed=55, hall=3.4)
	s.mix = {"harp": -4.0}
	sp = chord_spans(CH)
	pads(s, sp, ["vla", "vc"], lambda b: 0.17 if b < 14 else 0.14, Voices(("F3", "D4"), ("A2", "F3")))
	roots(s, "cb_nv", sp, 0.17, "D2", "C#3")
	s.line("cl", 2, arc(CLARINET, 0.4, 0.52))
	s.line("fl", 10, arc(FLUTE, 0.3, 0.38), send=0.6)
	for bar, beat, sym, ln in sp:
		if beat == 0 and bar % 2 == 0:
			root, pcs = chord(sym)
			s.note("harp", bar, 0, near(root, "D3", "C#4"), 1, 0.24)
			s.note("harp", bar, 2, near(pcs[-1], "D5", "C#6"), 1, 0.18)
	rng = np.random.default_rng(4)
	stars = ["D6", "F6", "G6", "A6", "C7"]
	for bar in range(2, 15):
		if rng.random() < 0.55:
			s.note("glock", bar, float(rng.choice([1.5, 2.5, 3.5])), stars[int(rng.integers(0, 5))], 1, 0.2)
	s.note("glock", 15, 1, "A6", 1, 0.2)
	s.note("vln", 14, 0, "E5", 8, [(0, 0.05), (0.5, 0.14), (1, 0.02)])
	s.rit(14, 16, 44)
	return s
