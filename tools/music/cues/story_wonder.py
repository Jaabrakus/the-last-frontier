"""The wonder (the story: "Look up at the broken sky", the sky galleons revealed): C Lydian, the choir carrying a rising
motif over shimmering strings, the whole orchestra on its return, a B-flat and A-flat lifting into C. 72 BPM, about
1:25.

	0-3     the shimmer: high strings trembling, the harp, a low C, the choir humming in
	4-11    the motif in the choir and violins, hanging on D over C
	12-19   again with everyone: trumpets, horns, timpani; A-flat, B-flat, then C wide open
	20-23   the shimmer again, fading
"""
from __future__ import annotations

from _lib import Voices, arc, bars, chord, chord_spans, midi, near, tr
from orch import Score

CUE = dict(name="story_wonder", target=-17.0)

MOTIF = bars([
	[(0, "C5", 2), (2, "G5", 2)],
	[(0, "F#5", 1.5), (1.5, "E5", 0.5), (2, "D5", 2)],
	[(0, "E5", 2), (2, "B4", 2)],
	[(0, "C5", 1), (1, "D5", 1), (2, "E5", 2)],
	[(0, "A5", 2), (2, "G5", 1), (3, "F5", 1)],
	[(0, "E5", 2), (2, "C5", 2)],
	[(0, "D5", 2), (2, "G5", 2)],
	[(0, "F#5", 4)],
])
MOTIF_CH = [[(0, "C")], [(0, "D/C")], [(0, "Em/B")], [(0, "Am")], [(0, "F")], [(0, "C/E")], [(0, "Dm7"), (2, "G")],
		[(0, "D/C")]]
TUTTI = [n for n in MOTIF if n[0] < 16] + [(n[0] + 16,) + tuple(n[1:]) for n in bars([
		[(0, "C5", 2), (2, "Eb5", 2)], [(0, "D5", 2), (2, "F5", 2)], [(0, "E5", 1), (1, "G5", 1), (2, "C6", 2)],
		[(0, "C6", 4)]])]
TUTTI_CH = MOTIF_CH[:4] + [[(0, "Ab")], [(0, "Bb")], [(0, "C")], [(0, "C")]]


def shimmer(s: Score, bar: int, n: int, vel) -> None:
	s.chord("vln_trem", bar, 0, ["G5", "B5"], n * 4, vel)
	s.chord("vla_trem", bar, 0, ["E4", "F#4"], n * 4, vel)
	run = [p for p in range(int(midi("C3")), int(midi("B5")) + 1) if p % 12 in (0, 2, 4, 6, 7, 11)]
	for b in range(bar, bar + n):
		for k, p in enumerate(run[::2] if b % 2 == 0 else run[1::2]):
			s.note("harp", b, k * 4.0 / len(run[::2]), p, 1, 0.28)
		s.note("glock", b, 2.5, ["B6", "F#6", "E6", "G6"][b % 4], 1, 0.3)


def build() -> Score:
	s = Score(72, 4, seed=97, hall=3.2)
	s.mix = {"harp": -5.0, "choir": -3.0}
	shimmer(s, 0, 4, [(0, 0.05), (1, 0.4)])
	s.note("cb_nv", 0, 0, "C2", 16, [(0, 0.1), (1, 0.4)])
	s.note("tuba", 2, 0, "C2", 8, [(0, 0.05), (1, 0.35)])
	s.choir(1, 0, ["E4", "B4"], 12, [(0, 0.05), (1, 0.45)], vowel="u")
	s.swell(4, 0, 0.5, 1)

	# --- 4-11: the motif in the choir and violins -----------------------------------------------------------------
	A = chord_spans(MOTIF_CH, 4)
	s.line("vln", 4, arc(MOTIF, 0.5, 0.68))
	sat = Voices(("C5", "A5"), ("G4", "D5"), ("C4", "G4"), ("E3", "C4"))
	for bar, beat, sym, ln in A:
		v = sat(sym)
		s.choir(bar, beat, v[1:], ln, 0.5)
		for p in Voices(("E3", "B3"), ("C3", "G3"))(sym):
			s.note("vla", bar, beat, p, ln, 0.38)
		s.note("vc", bar, beat, near(chord(sym)[0], "C3", "B3"), ln, 0.4)
		s.note("cb_nv", bar, beat, near(chord(sym)[0], "C2", "B2"), ln, 0.38)
	for n in MOTIF:   # the sopranos on the motif with the violins
		s.choir(4, n[0], [n[1]], n[2], 0.5, vowel="a")
	shimmer(s, 10, 2, [(0, 0.25), (1, 0.5)])
	s.roll("timp_roll", 11, 0, 4, (0.1, 0.7), "C3")
	s.swell(12, 0, 0.75, 1)

	# --- 12-19: everyone ------------------------------------------------------------------------------------------
	B = chord_spans(TUTTI_CH, 12)
	s.line("tpt", 12, arc(TUTTI, 0.7, 0.88, 0.85))
	s.line("hn", 12, arc(tr(TUTTI, octave=-2), 0.7, 0.85, 0.85))
	s.line("vln", 12, arc(TUTTI, 0.72, 0.88, 0.85))
	s.line("fl", 12, arc(tr(TUTTI, octave=1), 0.55, 0.7, 0.85))
	for n in TUTTI:
		s.choir(12, n[0], [n[1]], n[2], 0.68, vowel="a")
	low = Voices(("E3", "C4"), ("G2", "E3"))
	for bar, beat, sym, ln in B:
		root, pcs = chord(sym)
		s.choir(bar, beat, sat(sym)[1:], ln, 0.66)
		for p in low(sym):
			s.note("tbn", bar, beat, p, ln, 0.6 + (0.15 if bar >= 16 else 0.0))
		s.note("tuba", bar, beat, near(root, "C2", "B2"), ln, 0.62)
		s.note("vc", bar, beat, near(root, "C3", "B3"), ln, 0.62)
		s.note("cb", bar, beat, near(root, "C2", "B2"), ln, 0.6)
		for p in Voices(("G3", "E4"), ("C3", "A3"))(sym):
			s.note("vla", bar, beat, p, ln, 0.55)
		s.hit("timp", bar, beat, 0.6 if bar < 16 else 0.75, near(root, "F2", "E3"))
	s.hit("cym", 12, 0, 0.6)
	s.roll("timp_roll", 17, 0, 4, (0.3, 0.9), "C3")
	s.swell(18, 0, 0.8, 1)
	s.hit("cym", 18, 0, 0.85)
	s.hit("gong", 18, 0, 0.6)
	s.hit("bd", 18, 0, 0.8)

	# --- 20-23: the shimmer fading -----------------------------------------------------------------------------
	shimmer(s, 20, 4, [(0, 0.45), (1, 0.05)])
	s.choir(20, 0, ["C4", "G4", "B4", "E5"], 14, [(0, 0.5), (1, 0.03)], vowel="u")
	s.note("cb_nv", 20, 0, "C2", 14, [(0, 0.4), (1, 0.02)])
	s.rit(21, 24, 60)
	return s
