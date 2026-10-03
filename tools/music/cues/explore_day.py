"""Open country (heard now and then while exploring by day): the harp turning over, a flute and an oboe trading the
Frontier theme's head in D major with a Lydian G-sharp, soft strings under. 80 BPM, about 1:15.

	0-3     the harp alone with the strings
	4-7     the flute
	8-11    the oboe answers (B minor, G, E minor, A)
	12-15   flute and clarinet in thirds
	16-19   the violins sing
	20-23   the flute's last words, the harp, a glockenspiel's star
"""
from __future__ import annotations

from _lib import Voices, arc, bars, chord_spans, harp_arp, pads, roots
from orch import Score

CUE = dict(name="explore_day", target=-21.0)

CH = [[(0, "D")], [(0, "E/D")], [(0, "G/D")], [(0, "D")],
		[(0, "D")], [(0, "E/D")], [(0, "G/D")], [(0, "D")],
		[(0, "Bm")], [(0, "G")], [(0, "Em")], [(0, "Asus4"), (2, "A")],
		[(0, "D")], [(0, "E/D")], [(0, "G")], [(0, "A")],
		[(0, "Bm")], [(0, "G")], [(0, "A")], [(0, "D")],
		[(0, "D")], [(0, "E/D")], [(0, "D")], [(0, "Dadd9")]]
FLUTE = bars([
	[(0, "D5", 1), (1, "A5", 1.5), (2.5, "G5", 0.5), (3, "A5", 1)],
	[(0, "B5", 1), (1, "A5", 1), (2, "G#5", 1), (3, "E5", 1)],
	[(0, "F#5", 1.5), (1.5, "G5", 0.5), (2, "A5", 1), (3, "D5", 1)],
	[(0, "E5", 3.5)],
])
OBOE = bars([
	[(0, "F#5", 2), (2, "D5", 1), (3, "B4", 1)],
	[(0, "D5", 1.5), (1.5, "E5", 0.5), (2, "B4", 2)],
	[(0, "G5", 1), (1, "F#5", 1), (2, "E5", 1), (3, "B4", 1)],
	[(0, "C#5", 4)],
])
VIOLINS = bars([
	[(0, "F#5", 1.5), (1.5, "E5", 0.5), (2, "D5", 1), (3, "B4", 1)],
	[(0, "D5", 2), (2, "B4", 1), (3, "G4", 1)],
	[(0, "A4", 1), (1, "C#5", 1), (2, "E5", 2)],
	[(0, "F#5", 4)],
])


def build() -> Score:
	s = Score(80, 4, seed=21, hall=2.8)
	s.mix = {"harp": -3.0}
	sp = chord_spans(CH)
	harp_arp(s, sp, 0.34, "D3", "A5")
	pads(s, sp, ["vla", "vla", "vc"], lambda b: 0.2 if b < 16 else 0.28, Voices(("D4", "A4"), ("A3", "E4"), ("D3", "A3")))
	roots(s, "cb_nv", [x for x in sp if x[0] >= 4], 0.2, "D2", "C#3")
	s.note("vln", 0, 0, "A5", 16, [(0, 0.05), (0.5, 0.18), (1, 0.12)])

	s.line("fl", 4, arc(FLUTE, 0.45, 0.58))
	s.line("ob", 8, arc(OBOE, 0.45, 0.58))
	s.line("fl", 12, arc(FLUTE[:9] + [(12, "F#5", 1), (13, "E5", 1), (14, "C#5", 2)], 0.45, 0.6))
	third = [(0, "B4", 1), (1, "F#5", 1.5), (2.5, "E5", 0.5), (3, "F#5", 1), (4, "G#5", 1), (5, "F#5", 1), (6, "E5", 1),
			(7, "C#5", 1), (8, "D5", 1.5)]
	s.line("cl", 12, arc(third + [(12, "D5", 1), (13, "C#5", 1), (14, "A4", 2)], 0.38, 0.5))
	s.line("vln", 16, arc(VIOLINS, 0.52, 0.66))
	pads(s, [x for x in sp if 16 <= x[0] < 20], ["hn", "hn"], 0.3, Voices(("F#3", "D4"), ("A2", "F#3")))
	s.line("fl", 20, bars([[(0, "A5", 2), (2, "F#5", 2)], [(0, "G#5", 2), (2, "E5", 2)], [(0, "F#5", 6)]]), 0.42)
	for bar, beat in ((3, 2.5), (7, 3), (15, 2.5), (23, 1)):
		s.note("glock", bar, beat, "A6" if bar != 23 else "D7", 1, 0.42)
	s.rit(21, 24, 62)
	return s
