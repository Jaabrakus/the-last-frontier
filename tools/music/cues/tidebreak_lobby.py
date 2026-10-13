"""Tidebreak's lobby (2026-10-13, with the ring's new score, the owner: "make some avatar inspired music"): the arena's front
door, calm before the fight, our own tune. D minor pentatonic (its relative F major's colour in B), 84 BPM, 4/4, 24 bars
the menu loops (68.6 s):

	A  0-7    the harp as a zither rolling on D and A, the low strings' drone, the Tide motif (ring_fight.MOTIF) slow in the
	          flute with a bamboo flute's flicks, answered
	B  8-15   the solo violin's tune (a fiddle's slides) over F, C and B-flat, the strings soft under it, a marimba
	A' 16-23  the motif in the flute and the solo violin together, the frame drum's soft pulse, the gong once

	python3 tools/music/render.py tidebreak_lobby
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _lib import bars, chord, midi, near  # noqa: E402
from orch import Score  # noqa: E402
from ring_fight import MOTIF, ornamented, penta_up  # noqa: E402

BPM = 84
CUE = dict(name="tidebreak_lobby", target=-19.0, loop=(0, 24), pre=0)

CHORDS = (
	["Dm", "Dm", "C", "Dm", "Dm", "F", "C", "Dm"]          # A
	+ ["F", "C", "Bb", "F", "Dm", "C", "Bb", "C"]          # B
	+ ["Dm", "Dm", "C", "Dm", "F", "Gm", "C", "Dm"]        # A'
)

## The motif slowed to the lobby's pace (twice as long), and its answer.
SLOW = [(b * 2, n, d * 2) for b, n, d in MOTIF]
TUNE_A = bars([
	SLOW[:3], [(x - 4, n, d) for x, n, d in SLOW[3:]],
	[(0, "A5", 2), (2, "G5", 1), (3, "F5", 1)],
	[(0, "D5", 4)],
	SLOW[:3], [(0, "G5", 3), (3, "C6", 1)],
	[(0, "C6", 2), (2, "A5", 1), (3, "G5", 1)],
	[(0, "A5", 4)],
])
TUNE_B = bars([
	[(0, "A5", 2), (2, "C6", 1), (3, "A5", 1)],
	[(0, "G5", 3), (3, "E5", 1)],
	[(0, "F5", 2), (2, "D5", 1), (3, "F5", 1)],
	[(0, "C5", 4)],
	[(0, "D5", 1), (1, "F5", 1), (2, "A5", 1), (3, "C6", 1)],
	[(0, "G5", 3), (3, "A5", 1)],
	[(0, "F5", 2), (2, "D5", 2)],
	[(0, "E5", 2), (2, "G5", 1), (3, "A4", 1)],
])


def build() -> Score:
	s = Score(BPM, 4, seed=41, hall=3.0)
	s.mix = {"harp": 1.5, "vc": -1.0, "cb": -2.0, "marimba": -3.0, "frame": -3.0, "gong": -4.0}
	for b in range(24):
		root, pcs = chord(CHORDS[b])
		# the zither: eighths rolling up and back on the pentatonic from the chord's root
		ns = penta_up(near(root, "D3", "C#4"), 7)
		for q, k in enumerate((0, 2, 4, 6, 5, 4, 2, 1)):
			s.note("harp", b, q * 0.5, ns[k], 0.5, 0.42 + (0.1 if q == 0 else 0.0))
		# the drone: the cellos on the root, the basses an octave under, a swell each bar
		r = near(root, "D2", "C#3")
		s.note("vc", b, 0, r + 12 if r + 12 <= midi("A3") else r, 4, [(0, 0.22), (0.5, 0.34), (1, 0.26)])
		s.note("cb", b, 0, r, 4, [(0, 0.2), (0.5, 0.3), (1, 0.24)])
		# B: the strings soft on the chord's fifth and third
		if 8 <= b < 16:
			s.note("vla", b, 0, near(pcs[-1], "A3", "G#4"), 4, [(0, 0.2), (0.6, 0.32), (1, 0.26)])
			s.note("vln", b, 0, near(pcs[1], "D4", "C#5"), 4, [(0, 0.18), (0.6, 0.3), (1, 0.24)])
			if b % 2 == 1:
				for q, k in enumerate((4, 2, 3, 1)):
					s.note("marimba", b, q, penta_up(near(root, "D4", "C#5"), 5)[k], 1, 0.3)
		# A': the frame drum's soft pulse
		if b >= 16:
			s.hit("frame", b, 0, 0.36)
			s.hit("frame", b, 2.5, 0.26)
	s.line("fl", 0, [(x, p, d, v if v is not None else 0.5) for x, p, d, v in ornamented(TUNE_A, "flute")])
	s.line("solo_vln", 8, [(x, p, d, v if v is not None else 0.52) for x, p, d, v in ornamented(TUNE_B, "fiddle")])
	s.line("fl", 16, [(x, p, d, v if v is not None else 0.52) for x, p, d, v in ornamented(TUNE_A, "flute")])
	s.line("solo_vln", 16, [(x, p - 12, d, 0.36) for x, p, d, _v in ornamented(TUNE_A, "fiddle")])
	s.hit("gong", 16, 0, 0.32)
	return s
