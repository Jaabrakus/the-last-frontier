"""The giant's fight (a mammoth turns on the player): D minor with the phrygian E-flat, 144 BPM. Two bars of the
giant rearing (the intro, played once), then 32 bars the game loops (53 s).

	0-1     the low brass swell up out of nothing, the timpani roll, the cymbal
	2-9     A: the low strings' ostinato (3+3+2), the horns' motif in the low register
	10-17   B: the giant's theme in the trombones and tuba, the choir on each bar, high strings trembling
	18-25   C: the chords climb (D, E-flat, F minor, G minor, A), the violins race, the trumpets' fanfare
	26-31   D: the giant's theme with the whole orchestra
	32-33   the break: only the ostinato and a roll, back to A
"""
from __future__ import annotations

from _lib import Voices, bars, bass, chord, midi, near, tr
from orch import Score

CUE = dict(name="giant_battle", target=-15.0, loop=(2, 34), pre=1)

OST_A = ["D3", "D3", "D3", "F3", "D3", "D3", "Eb3", "D3"]
OST_B = ["D3", "D3", "D3", "F3", "D3", "D3", "C3", "C#3"]
ACC = (0, 3, 6)          # the 3+3+2 accents (eighths)

THEME = bars([
	[(0, "D3", 2), (2, "A3", 2)],
	[(0, "Bb3", 3), (3, "A3", 1)],
	[(0, "G3", 2), (2, "F3", 1), (3, "E3", 1)],
	[(0, "A3", 4)],
	[(0, "D3", 2), (2, "A3", 2)],
	[(0, "C4", 3), (3, "Bb3", 1)],
	[(0, "Bb3", 1), (1, "G3", 1), (2, "F3", 1), (3, "Eb3", 1)],
	[(0, "D3", 4)],
])
THEME_CHORDS = ["Dm", "Gm", "C", "A", "Dm", "Cm", "Eb", "Dm"]


def ostinato(s: Score, bar: int, n: int, vel: float, shift: int = 0, basses: bool = True) -> None:
	for b in range(bar, bar + n):
		pat = OST_A if (b - bar) % 2 == 0 else OST_B
		for i, p in enumerate(pat):
			acc = i in ACC
			v = vel * (1.0 if acc else 0.7)
			s.note("vc_spic", b, i * 0.5, midi(p) + shift, 0.5, v)
			if basses and acc:
				s.note("cb_spic", b, i * 0.5, midi(p) + shift - 12, 0.5, v * 0.95)


def timp_bar(s: Score, bar: int, vel: float, root="D2", fifth="A2", fill: bool = False) -> None:
	s.hit("timp", bar, 0, vel, root)
	s.hit("timp", bar, 1.5, vel * 0.75, root)
	s.hit("timp", bar, 3, vel * 0.82, fifth)
	if fill:
		for k, p in enumerate([fifth, fifth, root, root]):
			s.hit("timp", bar, 3.5 + k * 0.125, vel * (0.55 + 0.1 * k), p)


def build() -> Score:
	s = Score(144, 4, seed=5, hall=2.4)
	s.mix = {"choir": -4.0, "timp": -3.0, "bd": -4.0, "tbn": -1.5}

	# --- 0-1: the giant rears ------------------------------------------------------------------------------
	# (bar 1 is the loop's last bar, the break: render.py puts it there, this swell fading under it)
	rise = [(0, 0.15), (0.8, 0.95), (1, 0.9)]
	s.note("tuba", 0, 0, "D2", 4.5, rise)
	s.chord("tbn", 0, 0, ["D3", "A3"], 4.5, rise)
	s.chord("hn", 0, 0, ["D3", "Eb3"], 4.5, rise)
	s.chord("vln_trem", 0, 0, ["D5", "Eb5"], 4.5, [(0, 0.1), (1, 0.7)])
	s.roll("timp_roll", 0, 0, 4, (0.2, 0.9), "D2")
	s.hit("timp", 0, 0, 0.8, "D2")
	s.hit("bd", 0, 0, 0.8)
	s.choir(0, 0, ["D3", "A3", "D4", "Eb4"], 4.5, [(0, 0.1), (1, 0.7)], vowel="a")

	# --- 2-9: A, the ostinato and the horns' motif -----------------------------------------------------------
	s.hit("cym", 2, 0, 0.7)
	s.hit("bd", 2, 0, 0.85)
	ostinato(s, 2, 8, 0.7)
	for b in range(2, 10):
		timp_bar(s, b, 0.62 + 0.03 * (b - 2), fill=(b % 4 == 1))
		if b % 2 == 0:
			s.hit("bd", b, 0, 0.6)
	motif = bars([[(0, "D3", 3), (3, "Eb3", 1)], [(0, "D3", 4)], [(0, "F3", 3), (3, "Eb3", 1)],
			[(0, "D3", 2), (2, "C3", 2)], [(0, "D3", 3), (3, "Eb3", 1)], [(0, "D3", 4)],
			[(0, "G3", 2), (2, "F3", 1), (3, "Eb3", 1)], [(0, "D3", 4)]])
	s.line("hn", 2, [(n[0], n[1], n[2], 0.7 + 0.15 * n[0] / 32) for n in motif])
	s.line("tbn", 6, [(n[0] - 16, n[1], n[2], 0.5 + 0.15 * (n[0] - 16) / 16) for n in motif if n[0] >= 16])
	s.note("tuba", 2, 0, "D2", 32, [(0, 0.55), (0.5, 0.45), (1, 0.65)])
	s.chord("vla_trem", 2, 0, ["A3", "D4"], 16, [(0, 0.35), (1, 0.55)])
	s.chord("vla_trem", 6, 0, ["A3", "Eb4"], 16, [(0, 0.4), (1, 0.62)])
	s.choir(6, 0, ["D3", "A3"], 16, [(0, 0.2), (1, 0.55)], vowel="o")
	s.roll("snare_roll", 9, 2, 2, (0.2, 0.8))

	# --- 10-17: B, the giant's theme ---------------------------------------------------------------------
	theme_section(s, 10, full=False)

	# --- 18-25: C, the chords climb ---------------------------------------------------------------------------
	climb = [("Dm", 0), ("Dm", 0), ("Eb", 1), ("Eb", 1), ("Fm", 3), ("Fm", 3), ("Gm", 5), ("A", 7)]
	hi = Voices(("D5", "C6"), ("A4", "F5"), ("D4", "C5"))
	low = Voices(("C3", "Bb3"), ("F2", "D3"))
	for i, (sym, sh) in enumerate(climb):
		b = 18 + i
		g = 0.7 + 0.2 * i / 7
		ostinato(s, b, 1, g, sh)
		root, pcs = chord(sym)
		tones = [near(pcs[0], "D5", "C#6"), near(pcs[1], "D5", "E6"), near(pcs[2], "F5", "E6")]
		tones = sorted(tones)
		for q in range(16):
			p = [tones[0], tones[1], tones[2], tones[1]][q % 4]
			s.note("vln_spic", b, q * 0.25, p, 0.25, 0.5 + (0.15 if q % 4 == 0 else 0.0) + 0.1 * i / 7)
		for q in range(8):
			s.note("vla_spic", b, q * 0.5, near(pcs[2 if q % 2 == 0 else 1], "F3", "E4"), 0.5, 0.5 + 0.1 * i / 7)
		for inst, p in zip(["tbn", "tbn"], low(sym)):
			s.note(inst, b, 0, p, 4, (0.45 + 0.2 * i / 7, 0.58 + 0.2 * i / 7))
		s.note("tuba", b, 0, near(root, "D2", "C#3"), 4, 0.6 + 0.2 * i / 7)
		s.choir(b, 0, [p for p in hi(sym)][1:] + [near(pcs[0], "D3", "C#4")], 4, 0.45 + 0.3 * i / 7)
		r = near(root, "D2", "C#3")
		f5 = near(pcs[2], "F2", "E3")
		for q in range(4):
			s.hit("timp", b, q, (0.72 if q == 0 else 0.6) + 0.12 * i / 7, r if q != 2 else f5)
		s.hit("bd", b, 0, 0.7)
	fanfare = bars([
		[(0, "D4", 1.5), (1.5, "A4", 0.5), (2, "A4", 2)],
		[(0, "G4", 1), (1, "F4", 1), (2, "E4", 1), (3, "F4", 1)],
		[(0, "Eb4", 1.5), (1.5, "Bb4", 0.5), (2, "Bb4", 2)],
		[(0, "Ab4", 1), (1, "G4", 1), (2, "F4", 1), (3, "G4", 1)],
		[(0, "F4", 1.5), (1.5, "C5", 0.5), (2, "C5", 2)],
		[(0, "Bb4", 1), (1, "Ab4", 1), (2, "G4", 1), (3, "Ab4", 1)],
		[(0, "G4", 1), (1, "Bb4", 1), (2, "D5", 2)],
		[(0, "C#5", 2), (2, "E5", 2)],
	])
	s.line("tpt", 18, [(n[0], n[1], n[2], 0.68 + 0.22 * n[0] / 32) for n in fanfare])
	s.line("hn", 18, [(n[0], midi(n[1]) - 12, n[2], 0.66 + 0.22 * n[0] / 32) for n in fanfare])
	s.hit("cym", 18, 0, 0.75)
	s.hit("cym", 22, 0, 0.7)
	s.roll("snare_roll", 21, 3, 1, (0.2, 0.6))
	s.roll("snare_roll", 24, 0, 8, (0.25, 0.9))
	s.roll("timp_roll", 25, 0, 4, (0.4, 0.95), "A2")
	s.swell(26, 0, 0.85, 1)

	# --- 26-31: D, the theme with everyone; 32-33 the break --------------------------------------------------
	theme_section(s, 26, full=True)
	ostinato(s, 32, 2, 0.62)
	s.roll("timp_roll", 32, 0, 8, (0.25, 0.85), "D2")
	s.roll("snare_roll", 33, 0, 4, (0.15, 0.75))
	s.chord("hn", 32, 0, ["D3"], 8, [(0, 0.3), (1, 0.75)])
	s.chord("vln_trem", 32, 0, ["D5", "Eb5"], 8, [(0, 0.15), (1, 0.55)])
	s.choir(32, 0, ["D3", "A3"], 8, [(0, 0.15), (1, 0.5)], vowel="o")
	s.swell(34, 0, 0.8, 1)          # peaks on the loop's first beat (wrapped round)
	return s


def theme_section(s: Score, bar: int, full: bool) -> None:
	"""The giant's theme over its 8 bars from `bar` (full: the whole orchestra, its last bars the cadence only:
	6 bars)."""
	theme = THEME if not full else [n for n in THEME if n[0] < 16 or n[0] >= 24]
	chords_ = THEME_CHORDS if not full else THEME_CHORDS[:4] + THEME_CHORDS[6:]
	if full:
		theme = [(n[0] - 8 if n[0] >= 24 else n[0],) + tuple(n[1:]) for n in theme]
	n_bars = len(chords_)
	g = 0.8 if full else 0.72
	s.line("tbn", bar, [(n[0], n[1], n[2], g) for n in theme])
	s.line("tuba", bar, [(n[0], midi(n[1]) - 12, n[2], g) for n in theme])
	s.line("hn", bar, [(n[0], n[1], n[2], g) for n in theme])
	if full:
		s.line("tpt", bar, [(n[0], midi(n[1]) + 12, n[2], 0.78) for n in theme])
		s.line("vln", bar, [(n[0], midi(n[1]) + 24, n[2], 0.8) for n in theme])
		s.line("vla", bar, [(n[0], midi(n[1]) + 12, n[2], 0.72) for n in theme])
	ostinato(s, bar, n_bars, 0.78 if full else 0.72)
	hi = Voices(("A4", "F5"), ("D4", "C5"), ("A3", "F4"))
	trem = Voices(("D5", "A5"), ("A4", "F5"))
	for i, sym in enumerate(chords_):
		b = bar + i
		root, pcs = chord(sym)
		r = near(root, "D2", "C#3")
		f5 = near(pcs[2], "F2", "E3")
		timp_bar(s, b, 0.78 if full else 0.7, r, f5, fill=(i % 4 == 3))
		s.hit("bd", b, 0, 0.75 if full else 0.65)
		v = hi(sym)
		s.choir(b, 0, v + [near(pcs[0], "D3", "C#4")], 1.5 if not full else 4, 0.62 if not full else 0.66,
				attack=0.04 if not full else None)
		if not full:
			for p in trem(sym) if i >= 4 else ["D5", "Eb5"]:
				s.note("vln_trem", b, 0, p, 4, 0.35 + 0.15 * i / 7)
			if i >= 4:
				for beat in (1.5, 3):
					for p in hi(sym)[:2]:
						s.note("tpt_stac", b, beat, midi(p) + (12 if midi(p) < 65 else 0), 0.5, 0.62)
		else:
			for inst, p in zip(["vla_trem", "vla_trem"], trem(sym)):
				s.note(inst, b, 0, midi(p) - 12, 4, 0.55)
	s.hit("cym", bar, 0, 0.8)
	s.hit("cym", bar + 4, 0, 0.65)
	if full:
		s.hit("cym", bar + 2, 0, 0.55)
