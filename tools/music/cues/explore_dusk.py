"""Long shadows (heard now and then in the evening): a lone horn in B minor over the strings and the harp, the
cellos answering, the choir humming. 60 BPM, about 1:25.

	0-1     the low strings and the harp
	2-9     the horn
	10-13   the cellos, the violins high and soft, the choir
	14-17   the horn again, quieter
	18-19   B minor held, fading
"""
from __future__ import annotations

from _lib import Voices, arc, bars, chord, chord_spans, harp_arp, near, pads, roots
from orch import Score

CUE = dict(name="explore_dusk", target=-21.0)

CH = [[(0, "Bm")], [(0, "Bm")],
		[(0, "Bm")], [(0, "G")], [(0, "D")], [(0, "A")], [(0, "Bm")], [(0, "G")], [(0, "Em")], [(0, "F#")],
		[(0, "G")], [(0, "D/F#")], [(0, "Em")], [(0, "Bm")],
		[(0, "Bm")], [(0, "G")], [(0, "Em")], [(0, "F#sus4"), (2, "F#")],
		[(0, "Bmadd9")], [(0, "Bmadd9")]]
HORN = bars([
	[(0, "F#3", 2), (2, "B3", 1.5), (3.5, "A3", 0.5)],
	[(0, "G3", 2), (2, "D3", 2)],
	[(0, "F#3", 1.5), (1.5, "E3", 0.5), (2, "D3", 1), (3, "A2", 1)],
	[(0, "C#3", 4)],
	[(0, "F#3", 2), (2, "B3", 1.5), (3.5, "C#4", 0.5)],
	[(0, "D4", 2), (2, "B3", 2)],
	[(0, "G3", 1), (1, "A3", 1), (2, "B3", 1), (3, "E3", 1)],
	[(0, "F#3", 4)],
])
CELLO = bars([
	[(0, "B3", 2), (2, "A3", 1), (3, "G3", 1)],
	[(0, "F#3", 2), (2, "A3", 2)],
	[(0, "G3", 1), (1, "F#3", 1), (2, "E3", 1), (3, "G3", 1)],
	[(0, "F#3", 4)],
])
HORN2 = bars([
	[(0, "F#3", 2), (2, "B3", 2)],
	[(0, "A3", 1), (1, "G3", 1), (2, "F#3", 2)],
	[(0, "E3", 2), (2, "G3", 2)],
	[(0, "F#3", 4)],
])


def build() -> Score:
	s = Score(60, 4, seed=34, hall=3.0)
	s.mix = {"harp": -4.0, "choir": -4.0}
	sp = chord_spans(CH)
	pads(s, sp, ["vla", "vla"], lambda b: 0.24 if b < 18 else 0.2, Voices(("D4", "A4"), ("F#3", "D4")))
	roots(s, "vc", sp, 0.24, "B2", "A#3")
	roots(s, "cb_nv", sp, 0.24, "B1", "A#2")
	harp_arp(s, [x for x in sp if x[0] < 2 or x[0] >= 14], 0.3, "B2", "F#4")
	for bar, beat, sym, ln in sp:
		if 2 <= bar < 14 and beat == 0:
			root, pcs = chord(sym)
			for k, p in enumerate(sorted(near(pc, "B2", "A#3") for pc in pcs)):
				s.note("harp", bar, k * 0.15, p, 1, 0.28)
	s.line("hn_solo", 2, arc(HORN, 0.56, 0.7), send=0.6)
	s.line("vc", 10, arc(CELLO, 0.42, 0.58))
	pads(s, [x for x in sp if 10 <= x[0] < 14], ["vln", "vln"], 0.2, Voices(("D5", "A5"), ("A4", "E5")))
	for bar, beat, sym, ln in [x for x in sp if 10 <= x[0] < 20]:
		s.choir(bar, beat, Voices(("D4", "A4"), ("F#3", "D4"))(sym), ln, 0.3 if bar < 18 else [(0, 0.3), (1, 0.05)],
				vowel="u")
	s.line("hn_solo", 14, arc(HORN2, 0.48, 0.58), send=0.65)
	s.rit(17, 20, 50)
	return s
