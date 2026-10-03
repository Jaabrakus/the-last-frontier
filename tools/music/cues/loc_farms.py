"""The farms (the Flatts' farms, the Rauch farm, the mill): a Palatine country dance, a Laendler in A major, the fiddle
(a solo violin) over plucked strings and a bassoon, the clarinet taking the tune the second time with the fiddle a
third above, a little tag to end. 104 BPM in 3/4, about 1:05.

	0-1     the oom-pah-pah
	2-17    the fiddle
	18-33   the clarinet, the fiddle above it
	34-35   the tag
"""
from __future__ import annotations

from _lib import bars, bass, chord, chord_spans, midi, near
from orch import Score

CUE = dict(name="loc_farms", target=-20.0)

TUNE = bars([
	[(0, "E5", 1), (1, "A5", 1), (2, "C#6", 1)],
	[(0, "B5", 1.5), (1.5, "A5", 0.5), (2, "E5", 1)],
	[(0, "D5", 1), (1, "G#5", 1), (2, "B5", 1)],
	[(0, "A5", 1.5), (1.5, "G#5", 0.5), (2, "E5", 1)],
	[(0, "D5", 1), (1, "E5", 1), (2, "G#5", 1)],
	[(0, "B5", 2), (2, "G#5", 1)],
	[(0, "A5", 1), (1, "C#6", 1), (2, "A5", 1)],
	[(0, "E5", 3)],
	[(0, "F#5", 1), (1, "A5", 1), (2, "D6", 1)],
	[(0, "C#6", 1.5), (1.5, "B5", 0.5), (2, "A5", 1)],
	[(0, "E5", 1), (1, "A5", 1), (2, "C#6", 1)],
	[(0, "B5", 1.5), (1.5, "A5", 0.5), (2, "F#5", 1)],
	[(0, "E5", 1), (1, "G#5", 1), (2, "B5", 1)],
	[(0, "D6", 1.5), (1.5, "C#6", 0.5), (2, "B5", 1)],
	[(0, "A5", 1), (1, "E5", 1), (2, "C#5", 1)],
	[(0, "A4", 3)],
], beats=3)
CH = [[(0, "A")], [(0, "A")], [(0, "E7")], [(0, "E7")], [(0, "E7")], [(0, "E7")], [(0, "A")], [(0, "A")],
		[(0, "D")], [(0, "D")], [(0, "A")], [(0, "A")], [(0, "E7")], [(0, "E7")], [(0, "A")], [(0, "A")]]
SCALE = [9, 11, 1, 2, 4, 6, 8]     # A major's pitch classes from A


def third_above(p) -> int:
	m = int(midi(p))
	i = SCALE.index(m % 12)
	up = SCALE[(i + 2) % 7]
	return m + (up - m % 12) % 12


def oompah(s: Score, spans, vel: float) -> None:
	"""The dance's bass on one (bassoon and plucked bass, the root and fifth by turns), the chord on two and three."""
	prev = None
	for n, (bar, beat, sym, ln) in enumerate(spans):
		r, pcs = chord(sym)
		b = bass(sym, "E2", "D#3", prev) if n % 2 == 0 else near(pcs[2], "E2", "D#3")
		prev = b
		s.note("cb_pizz", bar, 0, b, 1, vel)
		s.note("bsn_stac", bar, 0, b + 12, 0.6, vel * 0.8)
		for k in (1, 2):
			for pc in pcs[1:3]:
				s.note("vla_pizz", bar, k, near(pc, "C#4", "C5"), 0.5, vel * 0.75)
			s.note("vln_pizz", bar, k, near(pcs[0], "A4", "G#5"), 0.5, vel * 0.55)


def build() -> Score:
	s = Score(104, 3, seed=149, hall=2.2)
	s.mix = {"vla_pizz": -2.0, "vln_pizz": -4.0}
	oompah(s, chord_spans([[(0, "A")], [(0, "E7")]], 0, 3), 0.5)
	A = chord_spans(CH, 2, 3)
	oompah(s, A, 0.5)
	s.line("solo_vln", 2, [(n[0], n[1], n[2] * 0.92, 0.6 if n[2] < 2 else 0.55) for n in TUNE], legato=False)
	B = chord_spans(CH, 18, 3)
	oompah(s, B, 0.55)
	s.line("cl", 18, [(n[0], n[1], n[2] * 0.92, 0.55) for n in TUNE], legato=False)
	s.line("solo_vln", 18, [(n[0], third_above(n[1]), n[2] * 0.92, 0.48) for n in TUNE if n[0] >= 24],
			legato=False)
	s.line("solo_vln", 18, [(n[0], n[1], n[2], 0.42) for n in [(0, "C#5", 3), (3, "E5", 3), (6, "B4", 3),
			(9, "D5", 3), (12, "B4", 3), (15, "E5", 3), (18, "C#5", 3)]], legato=True)
	# the tag: a run down and two chords
	s.line("solo_vln", 34, [(0, "E6", 0.5, 0.55), (0.5, "C#6", 0.5, 0.5), (1, "A5", 0.5, 0.5), (1.5, "E5", 0.5, 0.5),
			(2, "C#5", 1, 0.55), (3, "A4", 1, 0.6)], legato=False)
	for k, p in (("cb_pizz", "A2"), ("cb_pizz", "E3"), ("vla_pizz", "C#4"), ("vla_pizz", "A4")):
		s.note(k, 34, 3, p, 1, 0.55)
	s.note("bsn_stac", 34, 3, "A2", 0.6, 0.5)
	return s
