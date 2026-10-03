"""The deep woods (deep woods, old-growth woods, the wooded ridge): old and still, as the land in Shadow of the Colossus
is. E dorian over a low drone, a clarinet's slow line, a horn calling from far off and its echo, the harp's single notes,
the choir under everything. 50 BPM, about 1:20.

	0-1     the drone
	2-7     the clarinet
	8-9     the horn's call and its echo
	10-13   the clarinet again, lower, the choir rising and falling
	14-15   the drone alone
"""
from __future__ import annotations

from _lib import Voices, arc, bars, chord, chord_spans, near
from orch import Score

CUE = dict(name="loc_woods", target=-22.0)

CH = [[(0, "Em")], [(0, "Em")], [(0, "D/E")], [(0, "Em")], [(0, "C/E")], [(0, "D/E")], [(0, "Em")], [(0, "Em")],
		[(0, "Em")], [(0, "Em")], [(0, "C/E")], [(0, "D/E")], [(0, "Bm/E")], [(0, "Em")], [(0, "Em")], [(0, "Em")]]
CLAR = bars([
	[(0, "E4", 2), (2, "B4", 2)],
	[(0, "A4", 1.5), (1.5, "G4", 0.5), (2, "F#4", 2)],
	[(0, "G4", 1), (1, "A4", 1), (2, "B4", 2)],
	[(0, "C#5", 2), (2, "B4", 2)],
	[(0, "A4", 3), (3, "F#4", 1)],
	[(0, "E4", 4)],
])
CLAR2 = bars([
	[(0, "B3", 2), (2, "E4", 2)],
	[(0, "D4", 1.5), (1.5, "C4", 0.5), (2, "B3", 2)],
	[(0, "A3", 1), (1, "B3", 1), (2, "D4", 1), (3, "F#4", 1)],
	[(0, "E4", 4)],
])


def build() -> Score:
	s = Score(50, 4, seed=179, hall=3.4)
	s.mix = {"choir": -6.0, "harp": -5.0}
	sp = chord_spans(CH)
	s.note("cb_nv", 0, 0, "E2", 64, [(0, 0.05), (0.1, 0.24), (0.9, 0.22), (1, 0.03)])
	s.note("vc", 0, 0, "B2", 64, [(0, 0.05), (0.1, 0.2), (0.9, 0.18), (1, 0.03)])
	upper = Voices(("D4", "B4"), ("G3", "E4"))
	for bar, beat, sym, ln in sp:
		for p in upper(sym):
			s.note("vla", bar, beat, p, ln, 0.15 if 2 <= bar < 14 else 0.1)
		if bar % 2 == 0 and 1 <= bar < 15:
			_, pcs = chord(sym)
			s.note("harp", bar, 1.5, near(pcs[1], "E5", "D#6"), 1, 0.24)
			s.note("harp", bar + 1, 0.5, near(pcs[2], "B4", "A#5"), 1, 0.2)
	s.line("cl", 2, arc(CLAR, 0.4, 0.5))
	s.line("hn_solo", 8, [(0, "E3", 1, 0.42), (1, "B3", 2.5, 0.45), (4, "A3", 1, 0.4), (5, "B3", 3, 0.42)], send=0.8)
	s.line("hn_solo", 9, [(1, "E3", 1, 0.22), (2, "B3", 2, 0.24)], send=0.95, pan=0.5)
	s.line("cl", 10, arc(CLAR2, 0.38, 0.48))
	s.choir(9, 0, ["E3", "B3"], 20, [(0, 0.05), (0.5, 0.32), (1, 0.05)], vowel="u")
	s.note("glock", 13, 3, "B6", 1, 0.2)
	return s
