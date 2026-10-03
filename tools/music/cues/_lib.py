"""What the cues share: chord symbols, voice leading, and the Frontier theme (the main theme's melody, which the
upper hand and the lament take up)."""
from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from orch import PCS, midi  # noqa: E402,F401

QUAL = {"": [0, 4, 7], "m": [0, 3, 7], "5": [0, 7], "sus4": [0, 5, 7], "sus2": [0, 2, 7], "7": [0, 4, 7, 10],
		"m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11], "6": [0, 4, 7, 9], "m6": [0, 3, 7, 9], "add9": [0, 4, 7, 2],
		"madd9": [0, 3, 7, 2], "dim": [0, 3, 6], "m7b5": [0, 3, 6, 10]}
_CH = re.compile(r"([A-G][b#]?)(m7b5|maj7|madd9|add9|sus4|sus2|m7|m6|dim|m|7|6|5)?(?:/([A-G][b#]?))?")


def chord(sym: str) -> tuple:
	"""A chord symbol ("Dm", "A/C#", "Gm6", "Bbmaj7") -> (bass pitch class, [pitch classes])."""
	m = _CH.fullmatch(sym)
	if not m:
		raise ValueError(f"not a chord: {sym}")
	root = PCS[m.group(1)]
	pcs = [(root + i) % 12 for i in QUAL[m.group(2) or ""]]
	bass = PCS[m.group(3)] if m.group(3) else root
	return bass, pcs


def near(pc: int, lo: float, hi: float, prev: float | None = None) -> int:
	"""The pitch of class `pc` in [lo, hi] nearest `prev` (the range's middle without one)."""
	lo, hi = int(midi(lo)), int(midi(hi))
	target = prev if prev is not None else (lo + hi) / 2.0
	cands = [p for p in range(lo, hi + 1) if p % 12 == pc]
	return min(cands, key=lambda p: (abs(p - target), p))


class Voices:
	"""Parts that move to each chord by the nearest step: ranges top first ("A4", "E5"), the pitch classes shared out
	(each one the chord has before any doubles)."""

	def __init__(self, *ranges):
		self.ranges = [(int(midi(a)), int(midi(b))) for a, b in ranges]
		self.prev = [None] * len(self.ranges)

	def __call__(self, sym: str) -> list:
		_, pcs = chord(sym)
		used: list = []
		out = []
		for i, (lo, hi) in enumerate(self.ranges):
			target = self.prev[i] if self.prev[i] is not None else (lo + hi) / 2.0
			best = None
			for p in range(lo, hi + 1):
				if p % 12 not in pcs:
					continue
				pen = 0.0 if (p % 12 not in used or len(set(used)) >= len(pcs)) else 7.0
				if out and p >= out[-1]:
					pen += 20.0     # no crossing the part above
				sc = abs(p - target) + pen
				if best is None or sc < best[0]:
					best = (sc, p)
			out.append(best[1])
			used.append(best[1] % 12)
		self.prev = out
		return out


def bass(sym: str, lo="D2", hi="D3", prev=None) -> int:
	return near(chord(sym)[0], lo, hi, prev)


def tr(notes, semis: int = 0, octave: int = 0, stretch: float = 1.0, at: float = 0.0):
	"""A phrase moved: transposed, its beats stretched (and shifted by `at`)."""
	out = []
	for n in notes:
		p = n[1]
		if p is not None:
			p = midi(p) + semis + 12 * octave
		out.append((at + n[0] * stretch, p, n[2] * stretch) + tuple(n[3:]))
	return out


def bars(phrase_by_bar, beats: int = 4):
	"""[[notes of bar 0], [bar 1], ...] -> one phrase (beats counted from bar 0)."""
	out = []
	for i, b in enumerate(phrase_by_bar):
		for n in b:
			out.append((n[0] + i * beats,) + tuple(n[1:]))
	return out


# The Frontier theme: a folk air in D dorian, 8 bars of 4/4 (beat, pitch, beats), and its chords (bar: [(beat, sym)]).
THEME_A = bars([
	[(0, "D4", 1), (1, "A4", 1.5), (2.5, "G4", 0.5), (3, "A4", 1)],
	[(0, "C5", 1), (1, "A4", 1), (2, "G4", 1), (3, "E4", 1)],
	[(0, "F4", 1.5), (1.5, "G4", 0.5), (2, "A4", 1), (3, "D4", 1)],
	[(0, "E4", 3.5)],
	[(0, "F4", 1), (1, "A4", 1.5), (2.5, "B4", 0.5), (3, "C5", 1)],
	[(0, "D5", 2), (2, "C5", 1), (3, "A4", 1)],
	[(0, "G4", 1), (1, "A4", 0.5), (1.5, "G4", 0.5), (2, "F4", 1), (3, "E4", 1)],
	[(0, "D4", 4)],
])
THEME_A_CHORDS = [[(0, "Dm")], [(0, "C")], [(0, "Bb")], [(0, "Asus4"), (2, "A")],
		[(0, "F"), (2, "G")], [(0, "Bb"), (2, "F/A")], [(0, "Gm"), (2, "A")], [(0, "Dm")]]
# its second strain: rising to F5, back down to the dominant
THEME_B = bars([
	[(0, "F4", 1), (1, "Bb4", 1), (2, "D5", 2)],
	[(0, "E5", 1), (1, "D5", 1), (2, "C5", 1), (3, "G4", 1)],
	[(0, "A4", 1.5), (1.5, "Bb4", 0.5), (2, "A4", 1), (3, "F4", 1)],
	[(0, "E4", 2), (2, "A4", 1), (3, "C#5", 1)],
	[(0, "D5", 1.5), (1.5, "E5", 0.5), (2, "F5", 2)],
	[(0, "E5", 1), (1, "D5", 1), (2, "C5", 1), (3, "E5", 1)],
	[(0, "D5", 2), (2, "C#5", 1), (3, "E5", 1)],
	[(0, "E5", 4)],
])
THEME_B_CHORDS = [[(0, "Bb")], [(0, "C")], [(0, "Dm")], [(0, "A")], [(0, "Bb")], [(0, "C")],
		[(0, "Gm"), (2, "A")], [(0, "Asus4"), (2, "A")]]


def chord_spans(chords_by_bar, bar0: int = 0, beats: int = 4):
	"""[(bar, beat, sym, length in beats), ...] from chords by bar."""
	flat = []
	for i, cs in enumerate(chords_by_bar):
		for b, sym in cs:
			flat.append((bar0 + i, b, sym))
	out = []
	for j, (bar, b, sym) in enumerate(flat):
		if j + 1 < len(flat):
			nb, nbeat = flat[j + 1][0], flat[j + 1][1]
			ln = (nb - bar) * beats + (nbeat - b)
		else:
			ln = beats - b
		out.append((bar, b, sym, ln))
	return out


# --- arranging -----------------------------------------------------------------------------------------------------

def arc(notes, lo: float, hi: float, peak: float = 0.6):
	"""Velocities over a phrase: rising to `hi` at `peak` of the way, settling halfway back."""
	if not notes:
		return notes
	t0, t1 = notes[0][0], notes[-1][0] + 1e-6
	out = []
	for n in notes:
		x = (n[0] - t0) / (t1 - t0)
		v = lo + (hi - lo) * (x / peak) if x < peak else hi - (hi - lo) * 0.5 * (x - peak) / (1.0 - peak)
		out.append((n[0], n[1], n[2], v))
	return out


def harp_arp(s, spans, vel: float, lo="D3", hi="A4", step: float = 0.5, low_bass: bool = True) -> None:
	"""The harp's broken chords in eighths (step beats), the bass under each span's first."""
	for bar, beat, sym, ln in spans:
		b, pcs = chord(sym)
		tones = sorted(p for p in range(int(midi(lo)), int(midi(hi)) + 1) if p % 12 in pcs)
		pat = tones + tones[-2:0:-1]
		k = 0
		x = 0.0
		while x < ln - 1e-6:
			if x == 0.0 and low_bass:
				s.note("harp", bar, beat, near(b, "D2", "C#3"), 1, vel * 1.1)
			else:
				s.note("harp", bar, beat + x, pat[k % len(pat)], 1, vel * (1.0 if (x % 1.0) == 0 else 0.85))
			k += 1
			x += step


def pads(s, spans, parts, vel, voices: Voices) -> None:
	for bar, beat, sym, ln in spans:
		v = vel(bar) if callable(vel) else vel
		for inst, p in zip(parts, voices(sym)):
			s.note(inst, bar, beat, p, ln, v)


def roots(s, inst: str, spans, vel, lo="D2", hi="C#3", length=None) -> None:
	prev = None
	for bar, beat, sym, ln in spans:
		p = bass(sym, lo, hi, prev)
		prev = p
		v = vel(bar) if callable(vel) else vel
		s.note(inst, bar, beat, p, length if length else ln, v)


# The family theme (the night waltz "Hearth", the story's home): a waltz in E minor, 16 bars of 3/4, and its chords.
FAMILY = bars([
	[(0, "E4", 1), (1, "B4", 2)],
	[(0, "C5", 1.5), (1.5, "B4", 0.5), (2, "A4", 1)],
	[(0, "G4", 2), (2, "E4", 1)],
	[(0, "F#4", 3)],
	[(0, "E4", 1), (1, "B4", 2)],
	[(0, "D5", 1.5), (1.5, "C5", 0.5), (2, "B4", 1)],
	[(0, "E5", 2), (2, "D5", 1)],
	[(0, "B4", 3)],
	[(0, "E4", 1), (1, "B4", 2)],
	[(0, "C5", 1.5), (1.5, "B4", 0.5), (2, "A4", 1)],
	[(0, "G4", 2), (2, "E4", 1)],
	[(0, "A4", 1), (1, "C5", 1), (2, "E5", 1)],
	[(0, "D5", 2), (2, "B4", 1)],
	[(0, "C5", 1), (1, "E5", 1), (2, "G5", 1)],
	[(0, "F#5", 1.5), (1.5, "E5", 0.5), (2, "D#5", 1)],
	[(0, "E5", 3)],
], beats=3)
FAMILY_CHORDS = [[(0, "Em")], [(0, "Am/E")], [(0, "C")], [(0, "B7")], [(0, "Em")], [(0, "G/D")], [(0, "C")],
		[(0, "B7")], [(0, "Em")], [(0, "Am/E")], [(0, "C")], [(0, "Am")], [(0, "G/B")], [(0, "C")],
		[(0, "Am6"), (2, "B7")], [(0, "Em")]]


def waltz_piano(s, spans, vel, bass_lo="E2", bass_hi="D#3", chord_lo="G3", chord_hi="E4") -> None:
	"""The piano's waltz: the bass on one (pedalled through the bar), the chord on two and three."""
	vc = Voices(*[(chord_lo, chord_hi)] * 3)
	prev = None
	for bar, beat, sym, ln in spans:
		v = vel(bar) if callable(vel) else vel
		b = bass(sym, bass_lo, bass_hi, prev)
		prev = b
		ch = sorted(set(vc(sym)))
		for k in range(int(ln)):
			if beat + k == 0:
				s.note("piano", bar, 0, b, min(ln, 3), v * 1.05)
			else:
				for p in ch:
					s.note("piano", bar, beat + k, p, 0.85, v * 0.8)


def piano_arp(s, spans, vel, lo="B2", hi="D5", step: float = 0.5, pedal: float = 2.0) -> None:
	"""The piano's broken chords (eighths by default), the bass first, each note held `pedal` beats."""
	for bar, beat, sym, ln in spans:
		v = vel(bar) if callable(vel) else vel
		b, pcs = chord(sym)
		root = near(b, lo, int(midi(lo)) + 11)
		tones = [p for p in range(root + 7, int(midi(hi)) + 1) if p % 12 in pcs][:4]
		pat = [root] + tones + tones[-2:0:-1]
		x, k = 0.0, 0
		while x < ln - 1e-6:
			s.note("piano", bar, beat + x, pat[k % len(pat)], pedal, v * (1.0 if k == 0 else 0.82))
			x += step
			k += 1
