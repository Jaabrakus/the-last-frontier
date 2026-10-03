"""Home (the story: the roof on the house): the family theme warm and whole, the violins singing it as a slow orchestral
waltz, the horns and flute with them, and at its end E major instead of minor. 84 BPM in 3/4, about 50 s.

	0-15    the theme (the flute joins at bar 8)
	15-17   E major, held
"""
from __future__ import annotations

from _lib import FAMILY, FAMILY_CHORDS, Voices, arc, bass, chord, chord_spans, harp_arp, near
from orch import Score

CUE = dict(name="story_home", target=-18.0)


def build() -> Score:
	s = Score(84, 3, seed=113, hall=2.8)
	s.mix = {"harp": -4.0}
	chs = [list(c) for c in FAMILY_CHORDS]
	chs[15] = [(0, "E")]
	sp = chord_spans(chs, 0, 3)
	sp[-1] = (15, 0, "E", 9)
	melody = FAMILY[:-1] + [(45, "E5", 9)]
	s.line("vln", 0, arc(melody, 0.55, 0.75, 0.8), overlap=0.08)
	s.line("fl", 8, arc([(n[0] - 24, n[1], n[2]) for n in melody if n[0] >= 24], 0.45, 0.6))
	s.line("cl", 0, arc([(n[0], n[1], n[2]) for n in melody], 0.3, 0.42, 0.8))
	horns = Voices(("B3", "D4"), ("E3", "B3"))
	prev = None
	for bar, beat, sym, ln in sp:
		b = bass(sym, "E2", "D#3", prev)
		prev = b
		v = 0.5 + 0.12 * max(0.0, 1.0 - abs(bar - 13) / 3.0)
		s.note("vc", bar, beat, b + 12 if b < 45 else b, min(ln, 3), v * 0.82)
		s.note("cb_nv", bar, beat, b, min(ln, 3), v * 0.75)
		_, pcs = chord(sym)
		for k in range(1, int(min(ln, 3))):
			for pc in pcs[:3]:
				s.note("vla", bar, beat + k, near(pc, "G3", "F#4"), 0.8, v * 0.7)
		for p in horns(sym):
			s.note("hn", bar, beat, p, ln, v * 0.85)
	harp_arp(s, [x for x in sp if x[1] == 0 and x[0] < 15], 0.28, "E3", "B4", step=1.0, low_bass=False)
	s.roll("timp_roll", 14, 1, 2, (0.1, 0.45), "B2")
	s.hit("timp", 15, 0, 0.45, "E3")
	s.hit("sus_cym", 15, 0, 0.35)
	s.chord("vla", 15, 0, ["G#3", "B3"], 9, [(0, 0.5), (1, 0.15)])
	s.chord("vc", 15, 0, ["E3"], 9, [(0, 0.5), (1, 0.15)])
	for p, d in (("E3", 0.0), ("B3", 0.12), ("E4", 0.24), ("G#4", 0.36), ("B4", 0.48), ("E5", 0.6)):
		s.note("harp", 15, d, p, 3, 0.3)
	s.rit(14, 17, 66)
	return s
