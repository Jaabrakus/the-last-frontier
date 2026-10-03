"""The wreck (the pine grove where the sky ship fell): hushed and strange. The wonder's motif (story_wonder) slow on a
solo violin over the strings' high, still chords, the harp and the glockenspiel like something glinting in the
needles. C Lydian, 58 BPM, about 1:05.

	0-1     the still chords
	2-9     the motif
	10-13   the chords and the glints, fading
"""
from __future__ import annotations

from _lib import Voices, arc, bars, chord, chord_spans, midi, near
from orch import Score

CUE = dict(name="loc_wreck", target=-22.0)

MOTIF = bars([
	[(0, "C5", 2), (2, "G5", 2)],
	[(0, "F#5", 1.5), (1.5, "E5", 0.5), (2, "D5", 2)],
	[(0, "E5", 2), (2, "B4", 2)],
	[(0, "C5", 4)],
	[(0, "E5", 2), (2, "B5", 2)],
	[(0, "A5", 1.5), (1.5, "G5", 0.5), (2, "F#5", 2)],
	[(0, "G5", 2), (2, "D5", 2)],
	[(0, "E5", 4)],
])
CH = [[(0, "Cmaj7")], [(0, "D/C")], [(0, "Em/B")], [(0, "Am7")], [(0, "Cmaj7")], [(0, "D/C")], [(0, "G/B")],
		[(0, "Em")]]


def build() -> Score:
	s = Score(58, 4, seed=223, hall=3.4)
	s.mix = {"harp": -4.0}
	still = Voices(("E5", "C6"), ("G4", "E5"), ("C4", "A4"))
	intro = chord_spans([[(0, "Cmaj7")], [(0, "D/C")]], 0)
	sp = chord_spans(CH, 2)
	end = chord_spans([[(0, "Cmaj7")], [(0, "D/C")], [(0, "Cmaj7")], [(0, "Cmaj7")]], 10)
	for bar, beat, sym, ln in intro + sp + end:
		v = 0.2 if bar < 12 else 0.14
		for p in still(sym):
			s.note("vln" if midi(p) >= 67 else "vla", bar, beat, p, ln, v)
		s.note("cb_nv", bar, beat, near(chord(sym)[0], "C2", "B2"), ln, v)
		if bar % 2 == 1:
			_, pcs = chord(sym)
			s.note("harp", bar, 2.5, near(pcs[-1], "E5", "D#6"), 1, 0.22)
			s.note("glock", bar, 3.5, near(pcs[1], "E6", "D#7"), 1, 0.2)
	s.line("solo_vln", 2, arc(MOTIF, 0.42, 0.56), overlap=0.1)
	s.rit(11, 14, 46)
	return s
