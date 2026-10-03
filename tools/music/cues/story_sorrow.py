"""The sorrow (the story: the farms across the river burned, the captives gone west): the Frontier theme slow on a
solo violin over the piano, the cellos finishing it, the choir humming. D minor, 56 BPM, about 1:20.

	0-1     the piano
	2-9     the theme on a solo violin
	10-13   its second half in the cellos, the choir under them
	14-15   the piano alone
"""
from __future__ import annotations

from _lib import THEME_A, THEME_A_CHORDS, Voices, arc, chord, chord_spans, near, pads, roots, tr
from orch import Score

CUE = dict(name="story_sorrow", target=-20.0)


def piano_chords(s: Score, spans, vel) -> None:
	"""The piano's chords on each half bar, low and close, the bass under."""
	for bar, beat, sym, ln in spans:
		b, pcs = chord(sym)
		for k in range(0, int(ln), 2):
			s.note("piano", bar, beat + k, near(b, "D2", "C#3"), 2, vel * 1.05)
			for j, pc in enumerate(sorted(pcs[:3], key=lambda c: near(c, "F3", "E4"))):
				s.note("piano", bar, beat + k + 0.04 * j, near(pc, "F3", "E4"), 2, vel * 0.75)


def build() -> Score:
	s = Score(56, 4, seed=101, hall=3.0)
	s.mix = {"choir": -5.0}
	piano_chords(s, [(0, 0, "Dm", 4), (1, 0, "Dm", 4)], 0.3)

	A = chord_spans(THEME_A_CHORDS, 2)
	piano_chords(s, A, 0.28)
	s.line("solo_vln", 2, arc(tr(THEME_A, octave=1), 0.5, 0.66), overlap=0.1)
	pads(s, [x for x in A if x[0] >= 6], ["vla", "vc"], 0.2, Voices(("D4", "A4"), ("F3", "D4")))

	half = [n for n in THEME_A if n[0] >= 16]
	B = chord_spans(THEME_A_CHORDS[4:], 10)
	piano_chords(s, B, 0.26)
	s.line("vc", 10, arc(tr([(n[0] - 16,) + tuple(n[1:]) for n in half], octave=-1), 0.5, 0.64), overlap=0.1)
	roots(s, "cb_nv", B, 0.22, "D2", "C#3")
	for bar, beat, sym, ln in B:
		s.choir(bar, beat, Voices(("D4", "A4"), ("A3", "E4"))(sym), ln, 0.3, vowel="u")
		for p in Voices(("D4", "A4"),)(sym):
			s.note("vla", bar, beat, p, ln, 0.2)

	s.rit(13, 16, 44)
	piano_chords(s, [(14, 0, "Dm", 4)], 0.22)
	s.note("piano", 15, 0, "D2", 6, 0.24)
	s.note("piano", 15, 0, "A2", 6, 0.2)
	s.note("piano", 15, 0.5, "D5", 6, 0.22)
	s.note("piano", 15, 1, "F5", 6, 0.18)
	s.note("piano", 15, 1.5, "A5", 6, 0.16)
	return s
