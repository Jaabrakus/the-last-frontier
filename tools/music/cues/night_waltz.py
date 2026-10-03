"""Hearth (night, and the homestead in the evening): the family theme as a slow waltz in E minor, the piano's
oom-pah-pah under a solo violin, then the cellos singing it with the violin above them. 76 BPM in 3/4, about 1:40.

	0-3     the piano alone
	4-19    the solo violin
	20-35   the cellos, the violin's line above them, the strings and harp; its height with the violins
	36-39   the piano alone, the theme's first bars, slowing
"""
from __future__ import annotations

from _lib import FAMILY, FAMILY_CHORDS, Voices, arc, chord_spans, harp_arp, midi, pads, roots, tr, waltz_piano
from orch import Score

CUE = dict(name="night_waltz", target=-21.0)


def build() -> Score:
	s = Score(76, 3, seed=61, hall=2.6)
	s.mix = {"harp": -5.0}
	intro = chord_spans([[(0, "Em")], [(0, "Am/E")], [(0, "Em")], [(0, "B7")]], 0, 3)
	waltz_piano(s, intro, 0.36)

	# --- 4-19: the solo violin ------------------------------------------------------------------------------
	A = chord_spans(FAMILY_CHORDS, 4, 3)
	waltz_piano(s, A, 0.34)
	s.line("solo_vln", 4, arc(FAMILY, 0.5, 0.66, 0.8), overlap=0.08)
	pads(s, [x for x in A if x[0] >= 12], ["vla", "vc"], 0.22, Voices(("E4", "B4"), ("G3", "E4")))

	# --- 20-35: the cellos, the violin above ----------------------------------------------------------------
	B = chord_spans(FAMILY_CHORDS, 20, 3)
	waltz_piano(s, B, lambda b: 0.3 + 0.08 * max(0.0, 1.0 - abs(b - 33) / 4.0))
	s.line("vc", 20, arc(tr(FAMILY, octave=-1), 0.5, 0.7, 0.8), overlap=0.1)
	descant = [(0, "G5", 3), (3, "A5", 3), (6, "E5", 3), (9, "D#5", 3), (12, "G5", 3), (15, "F#5", 3), (18, "G5", 3),
			(21, "F#5", 3), (24, "G5", 3), (27, "A5", 3), (30, "G5", 3), (33, "E5", 3), (36, "F#5", 3),
			(39, "G5", 1), (40, "A5", 1), (41, "B5", 1), (42, "A5", 2), (44, "F#5", 1), (45, "G5", 3)]
	s.line("solo_vln", 20, arc(descant, 0.38, 0.58, 0.8))
	s.line("vln", 32, arc([(n[0] - 36, n[1], n[2]) for n in FAMILY if n[0] >= 36], 0.42, 0.55))
	pads(s, B, ["vla", "vla"], lambda b: 0.24 + 0.08 * max(0.0, 1.0 - abs(b - 33) / 4.0), Voices(("E4", "B4"), ("G3", "E4")))
	roots(s, "cb_nv", B, 0.24, "E2", "D#3")
	harp_arp(s, [x for x in B if x[1] == 0], 0.26, "E3", "B4", step=1.0, low_bass=False)

	# --- 36-39: the piano alone ------------------------------------------------------------------------------
	end = chord_spans([[(0, "Em")], [(0, "Am/E")], [(0, "C")], [(0, "Em")]], 36, 3)
	waltz_piano(s, end[:3], 0.3)
	s.line("piano", 36, [(0, "E5", 1, 0.4), (1, "B5", 2, 0.42), (3, "C6", 1.5, 0.38), (4.5, "B5", 0.5, 0.34),
			(5, "A5", 1, 0.32), (6, "G5", 2, 0.32), (8, "E5", 1, 0.3)])
	for p, v in (("E2", 0.32), ("B2", 0.26), ("G3", 0.24), ("B3", 0.22), ("F#4", 0.2), ("E5", 0.26)):
		s.note("piano", 39, 0, p, 6, v)
	s.rit(37, 40, 58)
	return s
