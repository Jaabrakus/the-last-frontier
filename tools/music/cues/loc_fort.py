"""The fort (the Flatts' fort and its church): the Palatine settlers' hymn on the strings, a fife-and-drum tune for the
garrison, the hymn again with the woodwinds and horns as a church would sing it. G major, 80 BPM, about 1:15.

	0-7     the hymn, strings
	8-15    the fife (flute) and the drum, plucked strings under
	16-23   the hymn, woodwinds, horns and strings
"""
from __future__ import annotations

from _lib import Voices, bars, bass, chord, midi, near
from orch import Score

CUE = dict(name="loc_fort", target=-20.0)

HYMN = bars([
	[(0, "G4", 1), (1, "G4", 1), (2, "A4", 1), (3, "B4", 1)],
	[(0, "C5", 1), (1, "B4", 1), (2, "A4", 2)],
	[(0, "B4", 1), (1, "C5", 1), (2, "D5", 1), (3, "E5", 1)],
	[(0, "D5", 3.5)],
	[(0, "E5", 1), (1, "D5", 1), (2, "C5", 1), (3, "B4", 1)],
	[(0, "A4", 1), (1, "B4", 1), (2, "C5", 2)],
	[(0, "B4", 1), (1, "A4", 1), (2, "A4", 1.5), (3.5, "G4", 0.5)],
	[(0, "G4", 4)],
])
# a chord a beat (the hymn's four parts move together)
HYMN_CH = [["G", "G", "D/F#", "G"], ["C", "G/B", "D", "D"], ["G", "C", "G/D", "C"], ["D", "D", "D", "D"],
		["C", "G", "Am", "Em"], ["D", "G/B", "C", "C"], ["G/D", "D", "D7", "D7"], ["G", "G", "G", "G"]]
FIFE = bars([
	[(0, "D5", 0.5), (0.5, "G5", 0.5), (1, "G5", 0.5), (1.5, "A5", 0.5), (2, "B5", 1), (3, "G5", 1)],
	[(0, "A5", 0.5), (0.5, "B5", 0.5), (1, "C6", 0.5), (1.5, "B5", 0.5), (2, "A5", 1), (3, "D5", 1)],
	[(0, "D5", 0.5), (0.5, "G5", 0.5), (1, "G5", 0.5), (1.5, "A5", 0.5), (2, "B5", 0.5), (2.5, "C6", 0.5), (3, "D6", 1)],
	[(0, "C6", 0.5), (0.5, "B5", 0.5), (1, "A5", 0.5), (1.5, "F#5", 0.5), (2, "G5", 2)],
])
FIFE_CH = ["G", "D", "G", "D G"]


def hymn(s: Score, bar0: int, parts: dict, vel: float) -> None:
	"""The hymn in four parts from `bar0`: parts {"s"/"a"/"t"/"b": [kits]}."""
	alto = Voices(("D4", "G4"))
	tenor = Voices(("G3", "D4"))
	prev = None
	for i, row in enumerate(HYMN_CH):
		for beat, sym in enumerate(row):
			if i == 7 and beat > 0:
				break
			ln = 4 if i == 7 else 1
			a, t = alto(sym)[0], tenor(sym)[0]
			b = bass(sym, "G2", "F#3", prev)
			prev = b
			for k in parts.get("a", []):
				s.note(k, bar0 + i, beat, a, ln * 0.95, vel * 0.8)
			for k in parts.get("t", []):
				s.note(k, bar0 + i, beat, t, ln * 0.95, vel * 0.8)
			for k in parts.get("b", []):
				s.note(k, bar0 + i, beat, b, ln * 0.95, vel * (0.55 if k == "cb_nv" else 0.7))
	for k in parts.get("s", []):
		s.line(k, bar0, [(n[0], n[1], n[2] * 0.97, min(vel * 1.3, 0.8)) for n in HYMN], legato=False)


def build() -> Score:
	s = Score(80, 4, seed=131, hall=2.9)
	hymn(s, 0, {"s": ["vln"], "a": ["vla"], "t": ["vc"], "b": ["cb_nv"]}, 0.4)
	s.rit(7, 8, 72)
	s.tempo(8, 84)

	# --- 8-15: the fife and drum ---------------------------------------------------------------------------------
	for rep in (0, 1):
		b0 = 8 + rep * 4
		s.line("fl", b0, [(n[0], n[1], n[2] * 0.9, 0.55 + 0.05 * rep) for n in FIFE], legato=False)
		s.line("fl_stac", b0, [(n[0], n[1], n[2], 0.4) for n in FIFE if n[2] <= 0.5], legato=False)
		if rep == 1:
			s.line("cl", b0, [(x[0], _third_below(x[1]), x[2] * 0.9, 0.35) for x in FIFE], legato=False)
		for i, syms in enumerate(FIFE_CH):
			parts = syms.split()
			for j, sym in enumerate(parts):
				span = 4 // len(parts)
				r, pcs = chord(sym)
				for k in range(span):
					beat = j * span + k
					s.note("vc_pizz" if k % 2 == 0 else "vla_pizz", b0 + i, beat,
							near(r, "G2", "F#3") if k % 2 == 0 else near(pcs[1], "B3", "A#4"), 0.5, 0.45)
			for beat in range(4):
				s.hit("snare", b0 + i, beat, 0.42 if beat % 2 == 0 else 0.32)
				s.hit("snare", b0 + i, beat + 0.5, 0.24)
				if beat == 3:
					s.hit("snare", b0 + i, 3.75, 0.22)
			s.hit("bd", b0 + i, 0, 0.42)
	s.roll("snare_roll", 15, 2, 2, (0.15, 0.35))
	s.tempo(16, 76)

	# --- 16-23: the hymn as the church sings it --------------------------------------------------------------------
	hymn(s, 16, {"s": ["vln", "fl", "ob"], "a": ["cl", "vla"], "t": ["hn", "vc"], "b": ["bsn", "cb_nv"]}, 0.48)
	s.rit(22, 24, 62)
	return s


def _third_below(p) -> int:
	"""A diatonic third below in G major (the clarinet's second part to the fife)."""
	m = int(midi(p))
	scale = [0, 2, 4, 5, 7, 9, 11]
	pc = (m - 7) % 12
	i = scale.index(pc) if pc in scale else 0
	lower = scale[(i - 2) % 7]
	d = (pc - lower) % 12
	return m - d
