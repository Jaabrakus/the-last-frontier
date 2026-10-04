"""The cliffs: high and open. Horn calls on open fifths and their echoes off the rock, the strings' wide fifths, then a
broad tune in the violins and violas with the choir. A mixolydian (its G natural), 60 BPM, about 1:10.

	0-3     the calls and echoes over the strings' fifths
	4-11    the tune, violins and violas in octaves; the timpani under its height
	12-15   a last call, the fifths fading
"""
from __future__ import annotations

from _lib import Voices, arc, bars, chord_spans, roots, tr
from orch import Score

CUE = dict(name="loc_cliffs", target=-20.0)

TUNE = bars([
	[(0, "A4", 2), (2, "E5", 2)],
	[(0, "D5", 1.5), (1.5, "C#5", 0.5), (2, "B4", 2)],
	[(0, "G4", 1), (1, "A4", 1), (2, "B4", 1), (3, "D5", 1)],
	[(0, "E5", 4)],
	[(0, "A5", 2), (2, "G5", 2)],
	[(0, "F#5", 1.5), (1.5, "E5", 0.5), (2, "D5", 2)],
	[(0, "E5", 1), (1, "D5", 1), (2, "B4", 1), (3, "G4", 1)],
	[(0, "A4", 4)],
])
CH = [[(0, "A")], [(0, "G/A")], [(0, "Em/G")], [(0, "A")], [(0, "D/A")], [(0, "D")], [(0, "G")], [(0, "A")]]


def call(s: Score, bar: int, vel: float) -> None:
	s.line("hn_solo", bar, [(0, "A2", 1, vel), (1, "E3", 1, vel), (2, "A3", 2, vel * 1.05)], send=0.7)
	s.line("hn_solo", bar + 1, [(0, "A2", 1, vel * 0.5), (1, "E3", 1, vel * 0.5), (2, "A3", 2, vel * 0.52)], send=0.95,
			pan=0.6)


def build() -> Score:
	s = Score(60, 4, seed=191, hall=3.6)
	s.mix = {"choir": -5.0, "hn": -3.0}
	s.chord("vln", 0, 0, ["A5", "E6"], 16, [(0, 0.05), (0.5, 0.28), (1, 0.22)])
	s.chord("vc", 0, 0, ["A2", "E3"], 16, [(0, 0.05), (0.5, 0.3), (1, 0.28)])
	s.note("cb_nv", 0, 0, "A1", 16, [(0, 0.05), (0.5, 0.3), (1, 0.28)])
	call(s, 0, 0.5)
	call(s, 2, 0.45)
	sp = chord_spans(CH, 4)
	height = lambda b: 0.45 + 0.15 * max(0.0, 1.0 - abs(b - 8) / 3.0)
	s.line("vln", 4, arc(TUNE, 0.55, 0.72, 0.55))
	s.line("vla", 4, arc(tr(TUNE, octave=-1), 0.45, 0.6, 0.55))
	s.line("vc", 4, arc([(n[0], n[1], n[2]) for n in bars([[(0, "A3", 4)], [(0, "G3", 4)], [(0, "G3", 4)],
			[(0, "A3", 4)], [(0, "A3", 4)], [(0, "D3", 4)], [(0, "G3", 4)], [(0, "A3", 4)]])], 0.45, 0.58))
	roots(s, "cb_nv", sp, height, "A1", "G#2")
	for bar, beat, sym, ln in sp:
		s.choir(bar, beat, Voices(("C#4", "A4"), ("E3", "C#4"))(sym), ln, height(bar) - 0.1, vowel="o")
		for p in Voices(("A3", "D4"), ("D3", "A3"))(sym):
			s.note("hn", bar, beat, p, ln, height(bar) - 0.05)
	s.roll("timp_roll", 7, 2, 2, (0.1, 0.5), "A2")
	s.hit("timp", 8, 0, 0.55, "A2")
	s.hit("sus_cym", 8, 0, 0.4)
	s.chord("vln", 12, 0, ["A5", "E6"], 16, [(0, 0.25), (1, 0.03)])
	s.chord("vc", 12, 0, ["A2", "E3"], 16, [(0, 0.28), (1, 0.03)])
	call(s, 12, 0.42)
	s.rit(13, 16, 50)
	drums_and_bass(s)
	return s


def drums_and_bass(s: Score) -> None:
	"""More drums and bass (user 2026-10-03: "add more drums and bass"): the giant drum and its echo off the rock, the
	low tenor drum under the tune, the sub under it all."""
	from _lib import chord_spans, sub_bass
	for b, v in ((0, 0.6), (2, 0.55), (4, 0.65), (8, 0.75), (12, 0.55)):
		s.hit("giant_drum", b, 0, v)
		s.hit("giant_drum", b, 0.75, v * 0.45)
	for b in range(4, 12):
		s.hit("tenor_lo", b, 2, 0.35)
	s.note("sub", 0, 0, "A1", 16, [(0, 0.05), (0.5, 0.4), (1, 0.35)])
	sub_bass(s, chord_spans(CH, 4), 0.45)
	s.note("sub", 12, 0, "A1", 16, [(0, 0.35), (1, 0.03)])
