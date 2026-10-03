"""The river (the ford, the lake shore): water in the harp's rippling triplets, a flute's line in F Lydian (its B
natural over G/F), the clarinet answering, soft strings. 66 BPM, about 1:20.

	0-1     the harp alone
	2-9     the flute
	10-17   the clarinet, the flute above it now and then
	18-21   the harp alone, fading
"""
from __future__ import annotations

from _lib import Voices, arc, bars, chord, chord_spans, midi, near, pads, roots
from orch import Score

CUE = dict(name="loc_river", target=-21.0)

FLUTE = bars([
	[(0, "C5", 2), (2, "A5", 2)],
	[(0, "G5", 1.5), (1.5, "F5", 0.5), (2, "D5", 2)],
	[(0, "E5", 2), (2, "C5", 2)],
	[(0, "D5", 3), (3, "F5", 1)],
	[(0, "A5", 2), (2, "C6", 2)],
	[(0, "B5", 1.5), (1.5, "A5", 0.5), (2, "G5", 2)],
	[(0, "F5", 1), (1, "E5", 1), (2, "D5", 1), (3, "A4", 1)],
	[(0, "C5", 4)],
])
CLAR = bars([
	[(0, "A4", 2), (2, "F4", 2)],
	[(0, "G4", 1), (1, "A4", 1), (2, "B4", 2)],
	[(0, "C5", 2), (2, "A4", 2)],
	[(0, "F4", 3), (3, "A4", 1)],
	[(0, "C5", 1.5), (1.5, "D5", 0.5), (2, "E5", 2)],
	[(0, "D5", 2), (2, "B4", 2)],
	[(0, "A4", 1), (1, "G4", 1), (2, "F4", 1), (3, "E4", 1)],
	[(0, "F4", 4)],
])
CH = [[(0, "Fmaj7")], [(0, "G/F")], [(0, "Am7")], [(0, "Bbmaj7")], [(0, "Fmaj7")], [(0, "G/F")], [(0, "Dm7")],
		[(0, "C")]]
CH2 = CH[:7] + [[(0, "Fmaj7")]]


def ripple(s: Score, spans, vel) -> None:
	"""The harp in triplet eighths, up and down the chord."""
	for bar, beat, sym, ln in spans:
		v = vel(bar) if callable(vel) else vel
		b, pcs = chord(sym)
		tones = sorted({near(pc, "F3", "E4") for pc in pcs} | {near(pc, "F4", "E5") for pc in pcs[:3]})
		pat = [near(b, "F2", "E3")] + tones + tones[-2:0:-1]
		k = 0
		while k * (1 / 3) < ln - 1e-6:
			s.note("harp", bar, beat + k / 3, pat[k % len(pat)], 1, v * (1.0 if k % 3 == 0 else 0.78))
			k += 1


def build() -> Score:
	s = Score(66, 4, seed=163, hall=2.9)
	s.mix = {"harp": -4.0}
	ripple(s, chord_spans([[(0, "Fmaj7")], [(0, "G/F")]], 0), 0.34)
	A = chord_spans(CH, 2)
	ripple(s, A, 0.3)
	s.line("fl", 2, arc(FLUTE, 0.45, 0.6))
	pads(s, A, ["vla", "vc"], 0.18, Voices(("A3", "F4"), ("F3", "C4")))
	roots(s, "cb_nv", A, 0.18, "F2", "E3")
	B = chord_spans(CH2, 10)
	ripple(s, B, 0.3)
	s.line("cl", 10, arc(CLAR, 0.45, 0.58))
	s.line("fl", 14, arc([(n[0] - 16, midi(n[1]) + 12, n[2]) for n in CLAR if n[0] >= 16], 0.32, 0.42))
	pads(s, B, ["vla", "vc", "vln"], 0.2, Voices(("C5", "A5"), ("A3", "F4"), ("F3", "C4")))
	roots(s, "cb_nv", B, 0.2, "F2", "E3")
	ripple(s, chord_spans([[(0, "Fmaj7")], [(0, "G/F")], [(0, "Fmaj7")]], 18), lambda b: 0.3 - 0.06 * (b - 18))
	for p, v in (("F2", 0.28), ("C3", 0.24), ("A3", 0.22), ("E4", 0.2), ("G4", 0.2), ("C5", 0.22)):
		s.note("harp", 21, 0, p, 4, v)
	s.rit(19, 22, 52)
	return s
