"""The upper hand (a knee buckles, or the player is up on the giant): the Frontier theme turned heroic, D major with
its borrowed chords (C, B-flat, F), 144 BPM like the fight so the two cross on a bar line. 32 bars, all looped (53 s).

	0-15    the theme in the horns (its beats doubled), the violins driving eighths, the low strings galloping
	16-31   again with everyone: trumpets and violins on top, the choir, the snare; a roll back to the start
"""
from __future__ import annotations

from _lib import THEME_A, Voices, bass, chord, midi, near, tr
from orch import Score

CUE = dict(name="giant_upper_hand", target=-15.0, loop=(0, 32))

# the theme's chords, two bars to each of its bars
CHORDS = ["D", "D", "C", "C", "Bb", "Bb", "A", "A", "F", "G", "D", "D", "C", "A", "D", "D"]
GALLOP = (0, 3, 6)


def drive(s: Score, bar: int, sym: str, vel: float, full: bool) -> None:
	"""One bar of the strings' drive: violins rocking in eighths, violas off the beat, cellos and basses galloping."""
	root, pcs = chord(sym)
	r5 = near(pcs[0], "C5", "B5")
	f4 = near(pcs[2], r5 - 9, r5 - 1)
	t3 = near(pcs[1], r5 + 1, r5 + 8)
	for i, p in enumerate([r5, f4, r5, f4, t3, f4, r5, f4]):
		s.note("vln_spic", bar, i * 0.5, p, 0.5, vel * (1.0 if i % 2 == 0 else 0.8))
	for i in (1, 3, 5, 7):
		s.note("vla_spic", bar, i * 0.5, near(pcs[1], "E4", "D#5"), 0.5, vel * 0.8)
	lo = near(root, "C3", "B3")
	for i, p in enumerate([lo, lo, lo, near(pcs[2], lo, lo + 11), lo, lo, lo + 12, lo]):
		acc = i in GALLOP
		s.note("vc_spic", bar, i * 0.5, p, 0.5, vel * (1.0 if acc else 0.72))
		if acc:
			s.note("cb_spic", bar, i * 0.5, lo - 12, 0.5, vel * 0.95)
	t = near(root, "D2", "C#3")
	s.hit("timp", bar, 0, vel * (0.95 if full else 0.85), t)
	s.hit("timp", bar, 1.5, vel * 0.7, t)
	s.hit("timp", bar, 3, vel * 0.78, near(pcs[2], "E2", "D#3"))


def build() -> Score:
	s = Score(144, 4, seed=8, hall=2.4)
	s.mix = {"choir": -5.0, "timp": -3.5, "bd": -4.0, "snare": -2.0, "tbn_stac": -2.5}
	theme = tr(THEME_A, stretch=2.0)

	for half in (0, 1):
		b0 = half * 16
		full = half == 1
		for i, sym in enumerate(CHORDS):
			b = b0 + i
			drive(s, b, sym, 0.62 + 0.06 * half + 0.04 * (i % 8) / 7, full)
			root, pcs = chord(sym)
			if i % 2 == 0 or CHORDS[i - 1] != sym:
				ln = 8 if i + 1 < len(CHORDS) and CHORDS[i + 1] == sym else 4
				s.note("tuba", b, 0, near(root, "D2", "C#3"), ln, 0.6 + 0.1 * half)
			if full or i >= 8:
				s.hit("bd", b, 0, 0.75)
				for beat in (1.5, 3):
					for p in Voices(("D4", "A4"), ("A3", "E4"), ("D3", "A3"))(sym):
						s.note("tbn_stac", b, beat, p, 0.5, 0.6 + 0.1 * half)
			if full:
				for beat, v in ((0, 0.75), (1.5, 0.55), (3, 0.62), (3.5, 0.45)):
					s.hit("snare", b, beat, v)
			if i >= 8 or full:
				v = Voices(("D5", "A5"), ("F#4", "D5"), ("A3", "F#4"), ("D3", "A3"))
				if i % 2 == 0 or CHORDS[i - 1] != sym:
					ln = 8 if i + 1 < len(CHORDS) and CHORDS[i + 1] == sym else 4
					s.choir(b, 0, v(sym), ln, 0.5 + 0.15 * half)
		# the theme: horns (an octave down, in their register) and violas; then trumpets, violins and flutes on top
		s.line("hn", b0, [(n[0], midi(n[1]) - 12, n[2], 0.78 + 0.08 * half) for n in theme])
		s.line("vla", b0, [(n[0], n[1], n[2], 0.62 + 0.1 * half) for n in theme])
		if full:
			s.line("tpt", b0, [(n[0], n[1], n[2], 0.82) for n in theme])
			s.line("vln", b0, [(n[0], midi(n[1]) + 12, n[2], 0.78) for n in theme])
			s.line("fl", b0, [(n[0], midi(n[1]) + 12, n[2], 0.6) for n in theme])
		# the last two bars: a trumpet call and a roll into what comes next
		call = [(0, "D5", 1), (1, "A4", 0.5), (1.5, "A4", 0.5), (2, "D5", 1), (3, "E5", 1),
				(4, "F#5", 2), (6, "E5", 1), (7, "A4", 1)]
		s.line("tpt" if not full else "tpt_solo", b0 + 14, [(n[0], n[1], n[2], 0.72 + 0.08 * half) for n in call])
		s.roll("timp_roll", b0 + 15, 0, 4, (0.3, 0.9), "A2")
		s.roll("snare_roll", b0 + 15, 2, 2, (0.2, 0.8))
		s.hit("cym", b0, 0, 0.75)
		s.hit("cym", b0 + 8, 0, 0.6)
	s.swell(32, 0, 0.8, 1)          # into the loop's first beat (wrapped round)
	s.swell(16, 0, 0.7, 1)
	drums_and_bass(s)
	return s


def drums_and_bass(s: Score) -> None:
	"""More drums and bass (user 2026-10-03: "add more drums and bass"): a march in the big drums, the sub under the
	roots, the basses and tuba up."""
	from _lib import march_drums, sub_bass
	march_drums(s, 0, 32, lambda b: 0.55 if b < 8 else 0.68 if b < 16 else 0.76)
	for b in (15, 31):
		for k in range(8):
			s.hit("tenor_hi" if k % 2 == 0 else "tenor_lo", b, 2 + k * 0.25, 0.45 + 0.05 * k)
	sub_bass(s, [(i, 0, c, 4) for i, c in enumerate(CHORDS + CHORDS)], 0.58)
	s.mix["cb_spic"] = s.mix.get("cb_spic", 0.0) + 2.5
	s.mix["tuba"] = s.mix.get("tuba", 0.0) + 1.5
