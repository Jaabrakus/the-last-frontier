"""The lament (the giant falls): not a victory. D minor over a falling bass (D, C#, C, B, B-flat, A), 54 BPM; the
cellos sing, the violins and the choir take it up, the choir is left alone at the end. About 1:40.

	0       the low strings
	1-8     the cellos' song (the Frontier theme's opening turned downward)
	9-16    the violins an octave up, the choir and the horns under them; a warm B-flat at its height
	17-21   the choir alone, a solo violin's last line, an open fifth
"""
from __future__ import annotations

from _lib import Voices, arc, bars, bass, chord, harp_arp, midi, near
from orch import Score

CUE = dict(name="giant_lament", target=-19.0)

SONG = bars([
	[(0, "A4", 2.5), (2.5, "G4", 0.5), (3, "F4", 1)],
	[(0, "E4", 2), (2, "G4", 1), (3, "F4", 0.5), (3.5, "E4", 0.5)],
	[(0, "F4", 3), (3, "A3", 1)],
	[(0, "B3", 1.5), (1.5, "C4", 0.5), (2, "D4", 2)],
	[(0, "G4", 2), (2, "F4", 1), (3, "E4", 1)],
	[(0, "F4", 1.5), (1.5, "E4", 0.5), (2, "D4", 2)],
	[(0, "E4", 2), (2, "C#4", 1), (3, "E4", 1)],
	[(0, "D4", 4)],
])
CH1 = ["Dm", "A/C#", "Dm/C", "G/B", "Gm/Bb", "Dm/A", ("Asus4", "A"), "Dm"]
CH2 = ["Dm", "A/C#", "Dm/C", "G/B", "Bb", "Dm/A", ("Asus4", "A"), "Dm"]


def spans(chs, bar0):
	out = []
	for i, c in enumerate(chs):
		if isinstance(c, tuple):
			out += [(bar0 + i, 0, c[0], 2), (bar0 + i, 2, c[1], 2)]
		else:
			out.append((bar0 + i, 0, c, 4))
	return out


def build() -> Score:
	s = Score(54, 4, seed=13, hall=3.2)
	s.mix = {"choir": -6.0, "harp": -2.0, "hn": -2.0}
	s.note("cb_nv", 0, 0, "D2", 4, [(0, 0.05), (1, 0.3)])
	s.chord("vla", 0, 0, ["A3", "D4"], 4, [(0, 0.05), (1, 0.28)])

	# --- 1-8: the cellos' song -----------------------------------------------------------------------------
	sp1 = spans(CH1, 1)
	s.line("vc", 1, arc(SONG, 0.5, 0.68), overlap=0.1)
	pad = Voices(("D4", "A4"), ("A3", "E4"))
	prev = None
	for bar, beat, sym, ln in sp1:
		for p in pad(sym):
			s.note("vla", bar, beat, p, ln, 0.3)
		b = bass(sym, "A1", "G#2", prev)
		prev = b
		s.note("cb_nv", bar, beat, b, ln, 0.34)
	for bar, beat, sym, ln in sp1:
		if beat == 0 and bar % 2 == 1:
			root, pcs = chord(sym)
			for k, p in enumerate(sorted(near(pc, "D3", "C#4") for pc in pcs)):
				s.note("harp", bar, k * 0.12, p, 1, 0.3)

	# --- 9-16: the violins take it, the choir and horns under ---------------------------------------------------
	sp2 = spans(CH2, 9)
	s.line("vln", 9, arc([(n[0], midi(n[1]) + 12, n[2]) for n in SONG], 0.5, 0.75), overlap=0.1)
	counter = bars([[(0, "D4", 4)], [(0, "C#4", 4)], [(0, "C4", 4)], [(0, "B3", 4)], [(0, "Bb3", 4)],
			[(0, "A3", 4)], [(0, "A3", 2), (2, "G3", 2)], [(0, "F3", 4)]])
	s.line("vc", 9, arc(counter, 0.42, 0.6))
	choir = Voices(("A4", "E5"), ("D4", "A4"), ("A3", "E4"), ("D3", "A3"))
	horns = Voices(("A3", "D4"), ("D3", "A3"))
	prev = None
	for bar, beat, sym, ln in sp2:
		h = 0.36 + 0.3 * max(0.0, 1.0 - abs(bar - 13) / 4.0)
		s.choir(bar, beat, choir(sym), ln, h, vowel="o")
		for p in horns(sym):
			s.note("hn", bar, beat, p, ln, h * 0.9)
		for p in pad(sym):
			s.note("vla", bar, beat, p, ln, h * 0.85)
		b = bass(sym, "A1", "G#2", prev)
		prev = b
		s.note("cb_nv", bar, beat, b, ln, h)
	harp_arp(s, [x for x in sp2 if x[1] == 0], 0.26, "D3", "A4", step=1.0)
	s.roll("timp_roll", 12, 2, 2, (0.05, 0.35), "F2")
	s.hit("timp", 13, 0, 0.4, "Bb2")
	s.hit("sus_cym", 13, 0, 0.35)

	# --- 17-21: the choir alone ------------------------------------------------------------------------------
	s.rit(19, 22, 44)
	coda = [("Dmadd9", 17), ("Bbmaj7", 18), ("Gm6", 19), ("Asus4", 20), ("D5", 21)]
	cv = Voices(("A4", "E5"), ("D4", "A4"), ("A3", "E4"), ("D3", "A3"))
	for sym, bar in coda:
		ln = 4 if bar < 21 else 8
		vel = 0.42 if bar < 21 else [(0, 0.4), (1, 0.05)]
		s.choir(bar, 0, cv(sym), ln, vel, vowel="u" if bar >= 19 else "o")
		s.note("cb_nv", bar, 0, near(chord(sym)[0], "A1", "G#2"), ln, 0.25 if bar < 21 else [(0, 0.25), (1, 0.02)])
	s.line("solo_vln", 18, bars([[(0, "A5", 2), (2, "G5", 1), (3, "F5", 1)], [(0, "E5", 3), (3, "D5", 1)],
			[(0, "E5", 4)], [(0, "D5", 6)]]), 0.48)
	s.note("harp", 21, 0, "D3", 1, 0.25)
	s.note("harp", 21, 0.5, "A3", 1, 0.22)
	s.note("harp", 21, 1, "D4", 1, 0.2)
	drums_and_bass(s)
	return s


def drums_and_bass(s: Score) -> None:
	"""More drums and bass (user 2026-10-03: "add more drums and bass"): a slow bass drum on each bar of the second
	half, the sub with the falling bass, the basses up."""
	from _lib import sub_bass
	for b in range(9, 17):
		s.hit("bd_big", b, 0, 0.32 + 0.14 * max(0.0, 1.0 - abs(b - 13) / 4.0))
	sub_bass(s, spans(CH2, 9), 0.42, "A1", "G#2")
	s.note("sub", 17, 0, "D2", 24, [(0, 0.35), (1, 0.02)])
	s.mix["cb_nv"] = s.mix.get("cb_nv", 0.0) + 2.0
