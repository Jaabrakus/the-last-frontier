"""Tidebreak's own score (round 4 SHOW; the owner's FEEL list: "Tidebreak's own music"): a festival sport on the water,
bright where the giants' fight is dread. D major with the mixolydian C, 132 BPM, 4/4, 32 bars the game loops (58.2 s),
in three stems of the same length and loop that MusicDirector's ring mode lays over each other as the match rises
(RingMusic: level 0 the base alone, 1 base + drive, 2 all three):

	base    the big drums (VSCO 1's giant drum, bass drum and tenor drums), the frame drum and the log drum rowing in
	        sixteenths, the low strings' ostinato (the motif's rhythm on the root and fifth), the sub
	drive   the brass ostinato (horn and trombone stabs on the off beats, horns at D4 or under; the tuba on the roots), the
	        motif in the low brass, the spiccato strings running
	peak    the motif and its answer in the high strings and trumpets, the woodwinds' runs into each phrase, the
	        synthesized choir, timpani rolls into the sections, cymbals on them

The Tide motif (MOTIF: A D E F# A, "da-da DAA DAAA-a", a rising fourth and a climb) is the score's own, and every stinger
(ring_stings.py) quotes it. Sections (bars): A 0-7 the motif and its answer; B 8-15 a broader tune in B minor and G, the
motif in the horns below; A' 16-23 the motif up an octave, the trombones under it; C 24-31 the motif climbing on G and A,
the dominant at the end turning back to the top.

The stems are one score split by instrument (STEMS), so their notes and timing are the full mix's; each stem's target
loudness (TARGETS) is the one that gives all three the same gain from the sum's -15.0 (measured with
tools/music/cues/ring_fight.py --targets), so the layers keep the mix's balance as Godot sums them.

	python3 tools/music/render.py ring_fight_base ring_fight_drive ring_fight_peak ring_fight
	python3 tools/music/cues/ring_fight.py --targets      the stems' targets for a -15.0 sum (renders them, slow)
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _lib import Voices, bars, chord, midi, near  # noqa: E402
import orch  # noqa: E402
from orch import Score  # noqa: E402

# short-ringing kits for the go and the stingers (a cymbal, the giant drum and the timpani stopped after ~2 s, faded)
orch.KITS.setdefault("cym_st", dict(orch.KITS["cym"], max=2.4))
orch.KITS.setdefault("gdrum_st", dict(orch.KITS["giant_drum"], max=2.0))
orch.KITS.setdefault("timp_st", dict(orch.KITS["timp"], max=2.2))

BPM = 132
LOOP = (0, 32)
MIX_TARGET = -16.0
## The highest horn note any ring cue may write (the owner: horns at D4 or below).
HORN_MAX = midi("D4")
## Each stem's loudness for a -16.0 sum at one shared gain (--targets measures them; render.py masters each stem to it).
TARGETS = {"base": -19.90, "drive": -20.42, "peak": -22.42}

STEMS = {
	"base": ["giant_drum", "bd_big", "tenor_lo", "tenor_hi", "frame", "logdrum", "tamb", "vc_spic", "cb_spic", "sub"],
	"drive": ["hn", "hn_stac", "tbn", "tbn_stac", "tuba", "tuba_stac", "vln_spic", "vla_spic"],
	"peak": ["vln", "vla", "vc", "tpt", "fl", "picc", "ob", "cl", "choir", "timp", "timp_roll", "cym", "cym_swell",
			"snare_roll", "glock"],
}
CUES = [dict(name="ring_fight_" + k, target=TARGETS[k], loop=LOOP, pre=0) for k in ("base", "drive", "peak")] + [
	# the go: the score's own first downbeat, struck once at the "Break!" over the stems' start
	dict(name="ring_fight", target=-14.0),
]

## The Tide motif: (beat, pitch, beats). A D E F# A, the last a pickup into the next bar.
MOTIF = [(0, "A4", 0.5), (0.5, "D5", 0.5), (1, "E5", 1.0), (2, "F#5", 1.5), (3.5, "A5", 0.5)]

CHORDS = (
	# A 0-7
	[[(0, "D")], [(0, "C")], [(0, "G")], [(0, "D")], [(0, "D")], [(0, "C")], [(0, "G"), (2, "A")], [(0, "D")]]
	# B 8-15
	+ [[(0, "Bm")], [(0, "G")], [(0, "D")], [(0, "A")], [(0, "Bm")], [(0, "G")], [(0, "Em")], [(0, "A")]]
	# A' 16-23
	+ [[(0, "D")], [(0, "C")], [(0, "G")], [(0, "D")], [(0, "D")], [(0, "C")], [(0, "G"), (2, "A")], [(0, "D")]]
	# C 24-31
	+ [[(0, "G")], [(0, "A")], [(0, "F#m")], [(0, "Bm")], [(0, "G")], [(0, "Em")], [(0, "Asus4")], [(0, "A")]]
)

TUNE_A = bars([
	MOTIF,
	[(0, "G5", 1), (1, "F#5", 0.5), (1.5, "E5", 0.5), (2, "C5", 2)],
	[(0, "D5", 1), (1, "B4", 1), (2, "G4", 1.5), (3.5, "A4", 0.5)],
	[(0, "A4", 3), (3, "A4", 0.5), (3.5, "A4", 0.5)],
	MOTIF,
	[(0, "G5", 1), (1, "A5", 0.5), (1.5, "G5", 0.5), (2, "E5", 2)],
	[(0, "D5", 1), (1, "E5", 1), (2, "F#5", 1), (3, "E5", 1)],
	[(0, "D5", 3), (3, "A4", 0.5), (3.5, "C#5", 0.5)],
])
TUNE_B = bars([
	[(0, "F#5", 2), (2, "D5", 1), (3, "B4", 1)],
	[(0, "D5", 1.5), (1.5, "E5", 0.5), (2, "D5", 1), (3, "B4", 1)],
	[(0, "A4", 2), (2, "F#4", 1), (3, "A4", 1)],
	[(0, "E5", 3), (3, "C#5", 1)],
	[(0, "F#5", 2), (2, "G5", 1), (3, "A5", 1)],
	[(0, "B5", 2), (2, "A5", 1), (3, "G5", 1)],
	[(0, "G5", 1), (1, "F#5", 1), (2, "E5", 1), (3, "G5", 1)],
	[(0, "E5", 2), (2, "A4", 0.5), (2.5, "C#5", 0.5), (3, "E5", 1)],
])
TUNE_C = bars([
	[(0, "D5", 0.5), (0.5, "G5", 0.5), (1, "A5", 1), (2, "B5", 1.5), (3.5, "A5", 0.5)],
	[(0, "E5", 0.5), (0.5, "A5", 0.5), (1, "B5", 1), (2, "C#6", 1.5), (3.5, "B5", 0.5)],
	[(0, "A5", 2), (2, "F#5", 1), (3, "C#5", 1)],
	[(0, "D5", 2), (2, "F#5", 1), (3, "B5", 1)],
	[(0, "B5", 1), (1, "A5", 1), (2, "G5", 1), (3, "D5", 1)],
	[(0, "E5", 1), (1, "G5", 1), (2, "B5", 1), (3, "G5", 1)],
	[(0, "A5", 4)],
	[(0, "A5", 2), (2, "G5", 0.5), (2.5, "F#5", 0.5), (3, "E5", 0.5), (3.5, "C#5", 0.5)],
])


def chord_at(bar: int, beat: float = 0.0) -> str:
	sym = CHORDS[bar % 32][0][1]
	for b, s in CHORDS[bar % 32]:
		if b <= beat:
			sym = s
	return sym


def section_gain(bar: int) -> float:
	"""The arc over the loop: A settles in, B lifts, A' fuller, C the most."""
	return [0.82, 0.9, 0.95, 1.0][(bar % 32) // 8]


# --- base: the drums, the low strings' ostinato, the sub ------------------------------------------------------------
## The low strings' rowing figure in eighths: the motif's rhythm on root (r), fifth (f) and octave (o).
OST = ["r", "r", "f", "r", "o", "r", "f", "r"]
OST_ACC = (0, 3, 6)


def base(s: Score) -> None:
	prev = None
	for b in range(32):
		g = section_gain(b)
		for half in (0, 2):
			sym = chord_at(b, half)
			root, pcs = chord(sym)
			r = near(root, "D2", "C#3", prev)
			prev = r
			f = near(pcs[2], "A2", "G#3", r + 7)
			for i in range(4):
				k = OST[(half * 2 + i) % 8]
				p = {"r": r, "f": f, "o": r + 12}[k]
				acc = (half * 2 + i) in OST_ACC
				s.note("vc_spic", b, half + i * 0.5, p, 0.5, (0.72 if acc else 0.5) * g)
				if acc:
					s.note("cb_spic", b, half + i * 0.5, r - 12 if r - 12 >= midi("C2") else r, 0.5, 0.7 * g)
			s.note("sub", b, half, near(root, "C1", "B1"), 2, 0.5 * g)
		# the big drums: the giant drum on one and the and of two, the bass drum on one and three
		s.hit("giant_drum", b, 0, 0.78 * g)
		s.hit("giant_drum", b, 1.5, 0.6 * g)
		s.hit("bd_big", b, 0, 0.7 * g)
		s.hit("bd_big", b, 2, 0.55 * g)
		if b % 2 == 1:
			s.hit("giant_drum", b, 2.5, 0.5 * g)
		# the frame drum's backbeat, the tambourine with it
		s.hit("frame", b, 1, 0.66 * g)
		s.hit("frame", b, 3, 0.7 * g)
		s.hit("tamb", b, 1, 0.42 * g)
		s.hit("tamb", b, 3, 0.48 * g)
		# the log drum rowing: a sixteenth figure, the oar's catch on the accents
		for q, w in ((0, 1.0), (0.75, 0.6), (1.5, 0.8), (2, 0.55), (2.75, 0.7), (3.25, 0.5), (3.5, 0.75)):
			s.hit("logdrum", b, q, 0.58 * w * g)
		# a tenor-drum fill at each phrase's end
		if b % 4 == 3:
			for k in range(8):
				s.hit("tenor_hi" if k % 2 == 0 else "tenor_lo", b, 2 + k * 0.25, (0.42 + 0.05 * k) * g)
		else:
			s.hit("tenor_lo", b, 3.5, 0.4 * g)


# --- drive: the brass ostinato, the motif low, the spiccato strings ---------------------------------------------------
def drive(s: Score) -> None:
	hn = Voices(("A3", "D4"), ("F#3", "B3"), ("D3", "G3"))
	tb = Voices(("D3", "A3"), ("A2", "E3"))
	prev = None
	for b in range(32):
		g = section_gain(b)
		for half in (0, 2):
			sym = chord_at(b, half)
			root, pcs = chord(sym)
			t = near(root, "D2", "C#3", prev)
			prev = t
			s.note("tuba_stac", b, half, t, 0.5, 0.66 * g)
			if half == 2:
				s.note("tuba_stac", b, 3.5, near(pcs[2], "A1", "G#2", t - 5), 0.5, 0.5 * g)
			# the stabs: horns and trombones on the off beats (the and of each beat), a push on the and of four
			hv = hn(sym)
			tv = tb(sym)
			for off in (half + 0.5, half + 1.5):
				v = (0.62 if off % 2 == 1.5 else 0.54) * g
				for p in hv:
					s.note("hn_stac", b, off, p, 0.5, v)
				for p in tv:
					s.note("tbn_stac", b, off, p, 0.5, v * 0.95)
		# the violins and violas running: sixteenth arpeggios on the chord, the violas in eighths under them
		for half in (0, 2):
			sym = chord_at(b, half)
			_, pcs = chord(sym)
			tones = sorted([near(pcs[0], "D5", "C#6"), near(pcs[1], "D5", "E6"), near(pcs[2], "E5", "D#6")])
			for q in range(8):
				p = [tones[0], tones[1], tones[2], tones[1]][q % 4]
				s.note("vln_spic", b, half + q * 0.25, p, 0.25, (0.48 + (0.12 if q % 4 == 0 else 0.0)) * g)
			for q in range(4):
				s.note("vla_spic", b, half + q * 0.5, near(pcs[2 if q % 2 == 0 else 1], "F#3", "F4"), 0.5, 0.5 * g)
	# the motif low in the horns under B, and in the trombones under A'
	low = [(n[0], midi(n[1]) - 24, n[2]) for n in MOTIF]
	for b in (8, 12):
		s.line("hn", b, [(x, p, d, 0.66) for x, p, d in low])
		s.line("hn", b + 1, [(0, midi("G3"), 1, 0.6), (1, midi("F#3"), 1, 0.58), (2, midi("E3"), 2, 0.55)])
	for b in (16, 20):
		s.line("tbn", b, [(x, p, d, 0.68) for x, p, d in low])
		s.line("tbn", b + 1, [(0, midi("G3"), 1, 0.62), (1, midi("A3"), 0.5, 0.6), (1.5, midi("G3"), 0.5, 0.58),
				(2, midi("E3"), 2, 0.56)])
	# C: the horns hold the climbing chords' tops, swelling
	for b in range(24, 32):
		sym = chord_at(b)
		for p in hn(sym)[:2]:
			s.note("hn", b, 0, p, 4, [(0, 0.42), (0.7, 0.66), (1, 0.6)])


# --- peak: the tune high, the runs, the choir, the timpani and cymbals ---------------------------------------------
def peak(s: Score) -> None:
	s.line("vln", 0, [(n[0], midi(n[1]), n[2], 0.62) for n in TUNE_A])
	s.line("vln", 8, [(n[0], midi(n[1]), n[2], 0.6) for n in TUNE_B])
	s.line("vln", 16, [(n[0], midi(n[1]) + 12 if midi(n[1]) < 79 else midi(n[1]), n[2], 0.66) for n in TUNE_A])
	s.line("vla", 16, [(n[0], midi(n[1]), n[2], 0.56) for n in TUNE_A])
	s.line("vln", 24, [(n[0], midi(n[1]), n[2], 0.7) for n in TUNE_C])
	s.line("vla", 24, [(n[0], midi(n[1]) - 12, n[2], 0.6) for n in TUNE_C])
	# the trumpets on the motif's bars (A, A', C's first two)
	for b in (0, 4, 16, 20):
		s.line("tpt", b, [(n[0], midi(n[1]) - 12, n[2], 0.62) for n in MOTIF])
	s.line("tpt", 24, [(n[0], midi(n[1]) - 12, n[2], 0.66) for n in TUNE_C if n[0] < 8])
	# the cellos' counter-line under B
	s.line("vc", 8, [(0, "D4", 2, 0.5), (2, "C#4", 2), (4, "B3", 4), (8, "A3", 4), (12, "C#4", 4), (16, "D4", 4),
			(20, "B3", 4), (24, "G3", 2), (26, "B3", 2), (28, "C#4", 4)], 0.52)
	# the woodwinds' runs: a scale up into each phrase (the last beat of bars 3, 7, ...), the piccolo on top in A' and C
	scale = ["D", "E", "F#", "G", "A", "B", "C#"]
	for b in range(3, 32, 4):
		target = TUNE_A[0][1] if b % 8 == 7 else "D6"
		top = midi(target) + (12 if midi(target) < 74 else 0)
		run = []
		p = top
		for k in range(8):
			while True:
				p -= 1
				name = [n for n, v in {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8,
						"A": 9, "A#": 10, "B": 11}.items() if v == p % 12][0]
				if name in scale:
					break
			run.append(p)
		run.reverse()
		for k, rp in enumerate(run):
			s.note("fl", b, 2 + k * 0.25, rp, 0.25, 0.45 + 0.04 * k)
			if b >= 16:
				s.note("picc", b, 2 + k * 0.25, rp + 12, 0.25, 0.38 + 0.03 * k)
	# the oboe and clarinet doubling the tune's long notes in B
	s.line("ob", 8, [(n[0], midi(n[1]), n[2], 0.5) for n in TUNE_B if n[2] >= 1])
	s.line("cl", 12, [(n[0] - 16, midi(n[1]) - 12, n[2], 0.48) for n in TUNE_B if n[0] >= 16 and n[2] >= 1])
	# the choir: an open "ah" on each bar's chord from B on, fuller in C
	ch = Voices(("D5", "A5"), ("A4", "E5"), ("D4", "A4"))
	for b in range(8, 32):
		sym = chord_at(b)
		v = 0.42 if b < 16 else (0.48 if b < 24 else 0.56)
		s.choir(b, 0, ch(sym), 4, [(0, v * 0.7), (0.4, v), (1, v * 0.85)], vowel="a")
	# the timpani: the roots on each section's downbeat, rolls into the next; cymbals on the sections
	for b in (0, 8, 16, 24):
		root, _ = chord(chord_at(b))
		s.hit("timp", b, 0, 0.8, near(root, "D2", "C#3"))
		s.hit("cym", b, 0, 0.72)
	for b in (7, 15, 23):
		s.roll("timp_roll", b, 2, 2, (0.25, 0.85), "A2")
		s.swell(b + 1, 0, 0.6, 0)
	s.roll("timp_roll", 30, 0, 8, (0.2, 0.9), "A2")
	s.roll("snare_roll", 31, 0, 4, (0.15, 0.7))
	s.swell(32, 0, 0.75, 1)            # peaks on the loop's first beat (wrapped round)
	for b in range(24, 30):
		root, _ = chord(chord_at(b))
		s.hit("timp", b, 0, 0.66, near(root, "D2", "C#3"))
		s.hit("timp", b, 2.5, 0.5, near(root, "D2", "C#3"))
	s.hit("cym", 28, 0, 0.6)
	for b in range(16, 24):
		s.note("glock", b, 0, near(chord(chord_at(b))[1][0], "D6", "C#7"), 1, 0.4)


def full() -> Score:
	s = Score(BPM, 4, seed=21, hall=2.2)
	s.mix = {"choir": -5.0, "timp": -2.0, "vc_spic": 1.0, "cb_spic": 2.0, "tuba_stac": 1.0, "logdrum": -1.0,
			"tamb": -3.0, "hn_stac": -1.0, "tbn_stac": -1.5, "vln_spic": -2.5, "vla_spic": -3.0, "tpt": -2.0, "picc": -3.0}
	base(s)
	drive(s)
	peak(s)
	check_horns(s)
	return s


def check_horns(s: Score) -> int:
	"""The owner's rule, asserted: no horn above D4 (returns the highest horn note's midi)."""
	top = 0
	for e in s.events:
		if str(e["inst"]).startswith("hn") and e.get("pitch") is not None:
			m = int(round(midi(e["pitch"])))
			assert m <= HORN_MAX, f"a horn at midi {m}, over D4 (62)"
			top = max(top, m)
	return top


def stem(s: Score, name: str) -> Score:
	keep = set(STEMS[name])
	known = {i for v in STEMS.values() for i in v}
	stray = {str(e["inst"]) for e in s.events if e["inst"] not in known}
	assert not stray, f"instruments in no stem: {stray}"
	s.events = [e for e in s.events if e["inst"] in keep]
	return s


def go() -> Score:
	"""The go: one bar, the whole band on the motif's last note (D major) with the big drums and a cymbal."""
	s = Score(BPM, 4, seed=22, hall=1.8)
	s.mix = {"choir": -5.0}
	s.hit("cym_st", 0, 0, 0.8)
	s.hit("gdrum_st", 0, 0, 0.9)
	s.hit("timp_st", 0, 0, 0.85, "D2")
	s.chord("hn", 0, 0, ["D3", "F#3", "A3", "D4"], 1.5, [(0, 0.85), (1, 0.4)])
	s.chord("tbn", 0, 0, ["D3", "A3"], 1.5, [(0, 0.85), (1, 0.4)])
	s.note("tuba", 0, 0, "D2", 1.5, [(0, 0.8), (1, 0.4)])
	s.chord("tpt", 0, 0, ["A4", "D5", "F#5"], 1.5, [(0, 0.8), (1, 0.4)])
	s.chord("vln", 0, 0, ["D5", "A5", "D6"], 1.5, [(0, 0.8), (1, 0.4)])
	s.note("cb_spic", 0, 0, "D2", 0.5, 0.85)
	s.note("vc_spic", 0, 0, "D3", 0.5, 0.85)
	s.note("sub", 0, 0, "D1", 1.5, 0.6)
	check_horns(s)
	return s


def build(name: str) -> Score:
	if name == "ring_fight":
		return go()
	return stem(full(), name.replace("ring_fight_", ""))


def _targets() -> None:
	"""Renders the three stems (no master), and prints each one's target loudness for a MIX_TARGET sum at one gain."""
	import numpy as np
	import orch
	import render
	raw = {}
	for k in ("base", "drive", "peak"):
		s = build("ring_fight_" + k)
		x, _ = render.render_loop(s, LOOP, 0)
		raw[k] = x
		print(f"{k}: {orch.loudness(x):.2f} raw", flush=True)
	n = min(len(v) for v in raw.values())
	tot = sum(v[:n] for v in raw.values())
	g = MIX_TARGET - orch.loudness(tot)
	print("TARGETS = {" + ", ".join(f'"{k}": {orch.loudness(v) + g:.2f}' for k, v in raw.items()) + "}")
	np.save(os.path.join(os.environ.get("RAW_OUT", "/tmp"), "ring_fight_raw.npy"), np.stack([raw[k][:n] for k in raw]))


if __name__ == "__main__":
	if "--targets" in sys.argv:
		sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
		_targets()
