"""The lullaby (night; by the sleeping child): a music box's tune in G major, the piano taking it up, then the box again,
slowing as it winds down. 63 BPM in 3/4, about 1:25.

	0-1     the box's first notes
	2-9     the box's tune, the piano and harp under it
	10-17   the piano sings it, the box above, a solo violin far off
	18-25   the box again, winding down
"""
from __future__ import annotations

from _lib import Voices, arc, bars, chord, chord_spans, midi, near, pads, roots, tr
from orch import Score

CUE = dict(name="lullaby", target=-23.0)

TUNE = bars([
	[(0, "D6", 1), (1, "B5", 1), (2, "G5", 1)],
	[(0, "E6", 2), (2, "D6", 1)],
	[(0, "B5", 1), (1, "A5", 1), (2, "G5", 1)],
	[(0, "A5", 3)],
	[(0, "B5", 1), (1, "G5", 1), (2, "E5", 1)],
	[(0, "G5", 2), (2, "E5", 1)],
	[(0, "E5", 1), (1, "F#5", 1), (2, "A5", 1)],
	[(0, "G5", 3)],
], beats=3)
TUNE2 = TUNE[:14] + [(18, "C6", 1), (19, "B5", 1), (20, "A5", 1), (21, "G5", 3)]
CH = [[(0, "G")], [(0, "C/G")], [(0, "G")], [(0, "D")], [(0, "Em")], [(0, "C")], [(0, "Am7"), (2, "D7")], [(0, "G")]]


def box_arp(s: Score, spans, vel: float) -> None:
	"""The box's broken chords, high, an eighth apart."""
	for bar, beat, sym, ln in spans:
		_, pcs = chord(sym)
		tones = sorted(near(pc, "G5", "F#6") for pc in pcs[:3])
		for k in range(int(ln * 2)):
			s.note("musicbox", bar, beat + k * 0.5, tones[[0, 1, 2, 1][k % 4]], 0.5, vel * (1.0 if k % 2 == 0 else 0.8))


def build() -> Score:
	s = Score(63, 3, seed=73, hall=2.4)
	s.mix = {"harp": -3.0}
	s.line("musicbox", 0, [(0, "G5", 1, 0.5), (1, "B5", 1, 0.48), (2, "D6", 1, 0.5), (3, "G6", 3, 0.52)], legato=False)

	# --- 2-9: the box's tune -----------------------------------------------------------------------------------
	A = chord_spans(CH, 2, 3)
	s.line("musicbox", 2, [n + (0.6,) for n in TUNE], legato=False)
	for bar, beat, sym, ln in A:
		b, pcs = chord(sym)
		s.note("piano", bar, beat, near(b, "G2", "F#3"), ln, 0.26)
		s.note("harp", bar, beat + 1, near(pcs[1], "B3", "A#4"), 1, 0.22)
		s.note("harp", bar, beat + 2 if ln > 2 else beat + 1.5, near(pcs[2], "D4", "C#5"), 1, 0.2)

	# --- 10-17: the piano sings it -------------------------------------------------------------------------------
	B = chord_spans(CH, 10, 3)
	s.line("piano", 10, arc(tr(TUNE2, octave=-1), 0.46, 0.56), legato=False)
	for bar, beat, sym, ln in B:
		b, pcs = chord(sym)
		s.note("piano", bar, beat, near(b, "G2", "F#3"), ln, 0.26)
		for k, pc in enumerate(pcs[1:3]):
			s.note("piano", bar, beat + 1 + k * 0.5 if ln > 2 else beat + 0.5 + k * 0.5, near(pc, "B3", "A#4"), 1.5, 0.2)
	box_arp(s, B[4:], 0.32)
	pads(s, B, ["vla", "vc"], 0.11, Voices(("D4", "B4"), ("G3", "D4")))
	s.line("solo_vln", 14, [(0, "B5", 6, 0.28), (6, "C6", 3, 0.26), (9, "B5", 3, 0.26)])

	# --- 18-25: the box again, winding down -------------------------------------------------------------------------
	C = chord_spans(CH, 18, 3)
	wind = [(n[0], n[1], n[2], 0.55 - 0.18 * n[0] / 24) for n in TUNE]
	s.line("musicbox", 18, wind, legato=False)
	for bar, beat, sym, ln in C:
		b, pcs = chord(sym)
		s.note("harp", bar, beat, near(b, "G2", "F#3"), ln, 0.2)
		s.note("harp", bar, beat + 1, near(pcs[2], "D4", "C#5"), 1, 0.17)
	s.note("cb_nv", 18, 0, "G2", 24, [(0, 0.12), (1, 0.03)])
	s.rit(21, 26, 40)
	for p, v in (("G3", 0.2), ("D4", 0.18), ("B4", 0.16)):
		s.note("harp", 26, 0, p, 3, v)
	s.note("musicbox", 26, 1, "G6", 1, 0.32)
	drums_and_bass(s)
	return s


def drums_and_bass(s: Score) -> None:
	"""More drums and bass (user 2026-10-03: "add more drums and bass"): a soft plucked bass on each downbeat; the
	frame drum barely there under the piano's verse."""
	from _lib import bass_pulse, chord_spans
	bass_pulse(s, chord_spans(CH, 2, 3) + chord_spans(CH, 10, 3), "cb_pizz", 0.28, "G1", "F#2", beats=(0,))
	for b in range(10, 18):
		s.hit("frame", b, 0, 0.14)
