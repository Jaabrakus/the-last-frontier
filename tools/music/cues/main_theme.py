"""The main theme, "Frontier" (the main menu): the Frontier theme from a distant horn call to the full orchestra and
back to a lone flute. D dorian, 66 BPM; about 2:40.

	bars 0-3    the land: a low D, the harp, a horn's call from far off
	4-11        the theme on a solo horn over the strings
	12-19       the violins take it, the horns below them
	20-27       the second strain builds: trombones, the choir, the timpani
	28-35       the whole orchestra; it closes on D major
	36-40       a flute alone over the strings
"""
from __future__ import annotations

from _lib import (THEME_A, THEME_A_CHORDS, THEME_B, THEME_B_CHORDS, Voices, arc, bars, bass, chord_spans, harp_arp,
		midi, pads, roots, tr)
from orch import Score

CUE = dict(name="main_theme", target=-18.0)


def build() -> Score:
	s = Score(66, 4, seed=3, hall=3.1)
	s.mix = {"harp": -4.0, "choir": -5.0, "tbn": -3.0}

	# --- 0-3: the land --------------------------------------------------------------------------------
	s.note("cb_nv", 0, 0, "D2", 16, [(0, 0.05), (0.4, 0.3), (1, 0.32)])
	s.note("vc", 0, 0, "D3", 16, [(0, 0.05), (0.5, 0.32), (1, 0.3)])
	s.note("vc", 0, 2, "A3", 14, [(0, 0.05), (0.5, 0.28), (1, 0.28)])
	intro = [(b, 0, "Dm", 4) for b in range(4)]
	harp_arp(s, intro[1:], 0.4, "D3", "E4")
	s.line("hn_solo", 2, [(0, "D3", 1), (1, "A3", 2.6)], 0.42, send=0.75)
	s.line("hn_solo", 3, [(2, "G3", 0.5), (2.5, "A3", 1.5)], 0.32, send=0.75)
	s.choir(2, 0, ["A3", "D4"], 8, [(0, 0.05), (0.6, 0.3), (1, 0.25)], vowel="u")

	# --- 4-11: the theme on a solo horn ----------------------------------------------------------------
	A1 = chord_spans(THEME_A_CHORDS, 4)
	s.line("hn_solo", 4, arc(tr(THEME_A, octave=-1), 0.52, 0.7), send=0.55)
	pads(s, A1, ["vla", "vla", "vc"], 0.27, Voices(("A3", "E4"), ("E3", "B3"), ("A2", "F3")))
	roots(s, "cb_nv", A1, 0.28)
	harp_arp(s, A1, 0.32, "D3", "A4")
	s.roll("timp_roll", 7, 2, 2, (0.05, 0.22), "A2")

	# --- 12-19: the violins take it, the horns below ----------------------------------------------------
	A2 = chord_spans(THEME_A_CHORDS, 12)
	s.line("vln", 12, arc(tr(THEME_A, octave=1), 0.5, 0.7))
	s.line("fl", 12, arc(tr([n for n in THEME_A if n[0] >= 16], octave=1), 0.38, 0.5))
	counter = bars([[(0, "F4", 4)], [(0, "E4", 4)], [(0, "D4", 4)], [(0, "C#4", 4)],
			[(0, "C4", 2), (2, "D4", 2)], [(0, "D4", 2), (2, "C4", 2)], [(0, "Bb3", 2), (2, "C#4", 2)], [(0, "D4", 4)]])
	s.line("hn", 12, arc(tr(counter, octave=-1), 0.42, 0.55))
	pads(s, A2, ["vla", "vla", "vc"], 0.34, Voices(("A3", "E4"), ("E3", "B3"), ("A2", "F3")))
	roots(s, "cb_nv", A2, 0.34)
	harp_arp(s, A2, 0.34, "D3", "A4")
	for bar, beat, sym, ln in A2[8:]:
		s.choir(bar, beat, Voices(("C4", "G4"), ("F3", "C4"))(sym), ln, 0.28, vowel="o")
	s.roll("timp_roll", 15, 2, 2, (0.08, 0.3), "A2")
	s.hit("timp", 19, 0, 0.35, "D2")

	# --- 20-27: the second strain builds -----------------------------------------------------------------
	B = chord_spans(THEME_B_CHORDS, 20)
	grow = lambda bar: 0.45 + 0.4 * (bar - 20) / 7.0
	s.line("vln", 20, arc(THEME_B, 0.55, 0.85, 0.75))
	s.line("cl", 20, arc(tr(THEME_B, octave=-1), 0.45, 0.7, 0.75))
	pads(s, B, ["hn", "hn"], lambda b: 0.35 + 0.35 * (b - 20) / 7.0, Voices(("F3", "D4"), ("A2", "F3")))
	s.line("vla", 20, arc(tr(THEME_B, octave=-1), 0.4, 0.6, 0.75))
	s.line("fl", 20, arc(tr([n for n in THEME_B if n[0] >= 16], octave=1), 0.5, 0.7))
	s.line("ob", 20, arc([n for n in THEME_B if n[0] >= 16], 0.45, 0.6))
	pads(s, B, ["vla_trem", "vla_trem"], lambda b: 0.3 + 0.3 * (b - 20) / 7.0, Voices(("C4", "A4"), ("F3", "D4")))
	# the low strings: a pulse on each beat
	prev = None
	for bar, beat, sym, ln in B:
		p = bass(sym, "D2", "C#3", prev)
		prev = p
		for k in range(int(ln)):
			acc = 1.0 if k % 2 == 0 else 0.82
			s.note("vc", bar, beat + k, p + 12, 0.9, grow(bar) * acc)
			s.note("cb_nv", bar, beat + k, p, 0.9, grow(bar) * acc * 0.95)
	pads(s, B[4:], ["tbn", "tbn", "tbn"], lambda b: 0.3 + 0.35 * (b - 24) / 3.0, Voices(("F3", "D4"), ("C3", "A3"), ("F2", "E3")))
	roots(s, "tuba", B[4:], lambda b: 0.35 + 0.3 * (b - 24) / 3.0, "F1", "E2")
	for bar, beat, sym, ln in B[4:]:
		s.choir(bar, beat, Voices(("C5", "G5"), ("F4", "C5"), ("C4", "G4"), ("F3", "C4"))(sym), ln,
				0.4 + 0.3 * (bar - 24) / 3.0)
	for bar, beat, sym, ln in B[4:]:
		r = bass(sym, "F2", "E3")
		for k in range(0, int(ln), 2):
			s.hit("timp", bar, beat + k, 0.5 + 0.25 * (bar - 24) / 3.0, r)
	s.roll("timp_roll", 27, 2, 2, (0.3, 0.85), "A2")
	s.swell(28, 0, 0.75, 1)
	# a harp run up into the tutti
	run = [p for p in range(int(midi("D3")), int(midi("D6")) + 1) if p % 12 in (2, 4, 5, 7, 9, 10, 1)]
	for i, p in enumerate(run[::2]):
		s.note("harp", 27, 2 + i * 2.0 / len(run[::2]), p, 1, 0.55)

	# --- 28-35: the whole orchestra ------------------------------------------------------------------------
	chords3 = [list(c) for c in THEME_A_CHORDS]
	chords3[7] = [(0, "D")]
	A3 = chord_spans(chords3, 28)
	A3[-1] = (35, 0, "D", 8)
	final = THEME_A[:-1] + [(28, "D4", 8)]
	s.line("hn", 28, arc(tr(final, octave=-1), 0.75, 0.9))
	s.line("tpt", 28, arc([n for n in final if n[0] >= 16], 0.7, 0.85))
	s.line("vln", 28, arc(tr(final, octave=1), 0.8, 0.95))
	s.line("fl", 28, arc(tr(final, octave=1), 0.55, 0.7))
	s.line("vla", 28, arc(final, 0.65, 0.8))
	cc = bars([[(0, "F3", 4)], [(0, "E3", 4)], [(0, "D3", 4)], [(0, "C#3", 4)], [(0, "C3", 2), (2, "D3", 2)],
			[(0, "D3", 2), (2, "C3", 2)], [(0, "Bb2", 2), (2, "C#3", 2)], [(0, "D3", 8)]])
	s.line("vc", 28, arc(cc, 0.7, 0.85))
	pads(s, A3, ["tbn", "tbn", "tbn"], 0.72, Voices(("F3", "D4"), ("C3", "A3"), ("F2", "E3")))
	roots(s, "tuba", A3, 0.72, "F1", "E2")
	roots(s, "cb", A3, 0.7)
	for bar, beat, sym, ln in A3:
		s.choir(bar, beat, Voices(("C5", "G5"), ("F4", "C5"), ("C4", "G4"), ("F3", "C4"))(sym), ln, 0.75)
	for bar, beat, sym, ln in A3[:-1]:
		r = bass(sym, "F2", "E3")
		for k in range(0, int(ln), 2):
			s.hit("timp", bar, beat + k, 0.8 if k == 0 else 0.65, r)
	s.hit("cym", 28, 0, 0.85)
	s.hit("bd", 28, 0, 0.8)
	s.hit("cym", 32, 0, 0.6)
	s.roll("timp_roll", 31, 2, 2, (0.3, 0.75), "A2")
	s.roll("timp_roll", 35, 0, 8, [(0, 0.8), (0.3, 0.55), (1, 0.15)], "D3")
	s.hit("cym", 35, 0, 0.7)
	s.hit("bd", 35, 0, 0.7)
	s.chord("vln", 35, 0, ["F#5"], 8, [(0, 0.8), (1, 0.4)])
	s.chord("tpt", 35, 0, ["A4"], 8, [(0, 0.8), (1, 0.35)])
	s.chord("hn", 35, 0, ["F#3", "A3"], 8, [(0, 0.75), (1, 0.3)])
	s.rit(34, 37, 56)

	# --- 37-40: a flute alone ------------------------------------------------------------------------------
	s.tempo(37, 58)
	s.rit(39, 41, 48)
	for bar, sym in [(37, "D"), (38, "G/D"), (39, "D"), (40, "Dadd9")]:
		for inst, p in zip(["vla", "vla", "vc"], Voices(("D4", "A4"), ("A3", "D4"), ("D3", "A3"))(sym)):
			s.note(inst, bar, 0, p, 4 if bar < 40 else 6, 0.22 if bar < 40 else (0.22, 0.05))
	s.note("cb_nv", 37, 0, "D2", 18, [(0, 0.25), (1, 0.05)])
	s.line("fl", 37, bars([[(0, "D5", 1), (1, "A5", 1.5), (2.5, "G5", 0.5), (3, "A5", 1)],
			[(0, "B5", 1), (1, "A5", 1), (2, "G5", 1), (3, "E5", 1)],
			[(0, "F#5", 1.5), (1.5, "E5", 0.5), (2, "D5", 2.5)]]), 0.42)
	harp_arp(s, [(37, 0, "D", 4), (38, 0, "G/D", 4), (39, 0, "D", 4)], 0.28, "D3", "D5")
	s.note("harp", 40, 0, "D3", 1, 0.3)
	s.note("harp", 40, 0.5, "A3", 1, 0.26)
	s.note("harp", 40, 1, "E4", 1, 0.24)
	s.note("harp", 40, 1.5, "A4", 1, 0.22)
	s.note("glock", 40, 2, "D6", 1, 0.3)
	return s
