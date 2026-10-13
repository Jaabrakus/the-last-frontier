"""Tidebreak's own score (round 4 SHOW; rewritten 2026-10-13, the owner: "the music is bad ... at least make some avatar
inspired music"): the elements' arena in the manner of an East Asian-flavoured fight score, our own tune. D minor
pentatonic (D F G A C, the E as a passing colour), 132 BPM, 4/4, 32 bars the game loops (58.2 s), in three stems of the
same length and loop that MusicDirector's ring mode lays over each other as the match rises (RingMusic: level 0 the base
alone, 1 base + drive, 2 all three):

	base    the drums as taiko: the giant drum and the bass drum as the big drum, the tenor drums as the small drums in
	        their "doko" sixteenths, the frame drum and the log drum, the low pizzicato strings on the root and fifth,
	        the sub
	drive   the harp as a zither: a rolling pentatonic ostinato in sixteenths and a sweep up into each phrase; the
	        pizzicato violins as a lute: off-beat plucks and tremolo at the top of the form; the violas' spiccato
	peak    the tune: the flute (a bamboo flute's grace notes) in A and A', the solo violin (a fiddle's slides) in B,
	        flute, piccolo and violins together in C; the strings' long counter-line; the gong on the sections, the
	        suspended cymbal swelling into them, the timpani; no bells, no choir

The Tide motif (MOTIF: A D F G A, "da-da DAA DAAA-a", a rising fourth and a climb up the pentatonic) is the score's own,
and every stinger (ring_stings.py) quotes it. Sections (bars): A 0-7 the motif and its answer over the drone; B 8-15 the
fiddle's tune over B-flat, C and D; A' 16-23 the motif again, the strings under it; C 24-31 the climb on B-flat, C and
F, the C chord (the flat seventh) turning back to the top.

The stems are one score split by instrument (STEMS), so their notes and timing are the full mix's; each stem's target
loudness (TARGETS) is the one that gives all three the same gain from the sum's MIX_TARGET (measured with
tools/music/cues/ring_fight.py --targets).

	python3 tools/music/render.py ring_fight_base ring_fight_drive ring_fight_peak ring_fight
	python3 tools/music/cues/ring_fight.py --targets      the stems' targets for a MIX_TARGET sum (renders them, slow)
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _lib import bars, chord, midi, near  # noqa: E402
import orch  # noqa: E402
from orch import Score  # noqa: E402

# short-ringing kits for the go and the stingers (a cymbal, the giant drum, the timpani and the gong stopped early, faded)
orch.KITS.setdefault("cym_st", dict(orch.KITS["cym"], max=2.4))
orch.KITS.setdefault("gdrum_st", dict(orch.KITS["giant_drum"], max=2.0))
orch.KITS.setdefault("timp_st", dict(orch.KITS["timp"], max=2.2))
orch.KITS.setdefault("gong_st", dict(orch.KITS["gong"], max=3.5))

BPM = 132
LOOP = (0, 32)
MIX_TARGET = -16.0
## The highest horn note any ring cue may write (the owner: horns at D4 or below).
HORN_MAX = midi("D4")
## Each stem's loudness for a MIX_TARGET sum at one shared gain (--targets measures them; render.py masters each stem to it).
TARGETS = {"base": -19.25, "drive": -21.32, "peak": -22.32}

STEMS = {
	"base": ["giant_drum", "bd_big", "tenor_lo", "tenor_hi", "frame", "logdrum", "vc_pizz", "cb_pizz", "sub"],
	"drive": ["harp", "vln_pizz", "vla_spic", "marimba", "hn"],
	"peak": ["fl", "picc", "solo_vln", "vln", "vla", "vc", "timp", "timp_roll", "gong", "cym_swell", "sus_cym"],
}
CUES = [dict(name="ring_fight_" + k, target=TARGETS[k], loop=LOOP, pre=0) for k in ("base", "drive", "peak")] + [
	# the go: the score's own first downbeat, struck once at the "Break!" over the stems' start
	dict(name="ring_fight", target=-14.0),
]

## The pentatonic the tune and the zither keep to (pitch classes: D F G A C).
PENTA = [2, 5, 7, 9, 0]

## The Tide motif: (beat, pitch, beats). A D F G A, the last a pickup into the next bar.
MOTIF = [(0, "A4", 0.5), (0.5, "D5", 0.5), (1, "F5", 1.0), (2, "G5", 1.5), (3.5, "A5", 0.5)]

## One chord a bar: open fifths and plain triads under a pentatonic tune (the drone's colour, not a march's cadences).
CHORDS = (
	["Dm", "Dm", "C", "Dm", "Dm", "F", "C", "Dm"]          # A 0-7
	+ ["Bb", "C", "Dm", "Dm", "Bb", "C", "Am", "Am"]        # B 8-15
	+ ["Dm", "Dm", "C", "Dm", "F", "Gm", "C", "Dm"]         # A' 16-23
	+ ["Bb", "C", "Dm", "F", "Gm", "F", "C", "C"]           # C 24-31
)

TUNE_A = bars([
	MOTIF,
	[(0, "C6", 1), (1, "A5", 0.5), (1.5, "G5", 0.5), (2, "F5", 2)],
	[(0, "G5", 1), (1, "F5", 0.5), (1.5, "D5", 0.5), (2, "C5", 1.5), (3.5, "D5", 0.5)],
	[(0, "D5", 3), (3, "D5", 0.5), (3.5, "F5", 0.5)],
	MOTIF,
	[(0, "C6", 1), (1, "D6", 0.5), (1.5, "C6", 0.5), (2, "A5", 2)],
	[(0, "G5", 1), (1, "A5", 1), (2, "C6", 1), (3, "A5", 1)],
	[(0, "D6", 3), (3, "A5", 0.5), (3.5, "C6", 0.5)],
])
TUNE_B = bars([
	[(0, "F5", 2), (2, "D5", 1), (3, "C5", 1)],
	[(0, "E5", 1.5), (1.5, "G5", 0.5), (2, "E5", 1), (3, "C5", 1)],
	[(0, "D5", 2), (2, "A4", 1), (3, "C5", 1)],
	[(0, "D5", 3), (3, "F5", 1)],
	[(0, "F5", 1), (1, "G5", 1), (2, "A5", 1), (3, "C6", 1)],
	[(0, "D6", 2), (2, "C6", 1), (3, "A5", 1)],
	[(0, "A5", 1), (1, "G5", 1), (2, "E5", 1), (3, "G5", 1)],
	[(0, "A5", 2), (2, "C6", 0.5), (2.5, "D6", 0.5), (3, "E6", 1)],
])
TUNE_C = bars([
	[(0, "D5", 0.5), (0.5, "F5", 0.5), (1, "G5", 1), (2, "A5", 1.5), (3.5, "C6", 0.5)],
	[(0, "E5", 0.5), (0.5, "G5", 0.5), (1, "A5", 1), (2, "C6", 1.5), (3.5, "D6", 0.5)],
	[(0, "D6", 2), (2, "C6", 1), (3, "A5", 1)],
	[(0, "A5", 2), (2, "C6", 1), (3, "F6", 1)],
	[(0, "G6", 1), (1, "F6", 1), (2, "D6", 1), (3, "C6", 1)],
	[(0, "A5", 1), (1, "C6", 1), (2, "F6", 1), (3, "C6", 1)],
	[(0, "C6", 4)],
	[(0, "C6", 1), (1, "D6", 0.5), (1.5, "C6", 0.5), (2, "A5", 0.5), (2.5, "G5", 0.5), (3, "F5", 0.5), (3.5, "A5", 0.5)],
])


def chord_at(bar: int) -> str:
	return CHORDS[bar % 32]


def section_gain(bar: int) -> float:
	"""The arc over the loop: A settles in, B lifts, A' fuller, C the most."""
	return [0.82, 0.9, 0.95, 1.0][(bar % 32) // 8]


def penta_up(lo: int, n: int) -> list:
	"""`n` notes of the pentatonic going up from the first at or above midi `lo`."""
	out = []
	p = lo
	while len(out) < n:
		if p % 12 in PENTA:
			out.append(p)
		p += 1
	return out


def ornamented(tune: list, inst_kind: str) -> list:
	"""The tune with its long notes ornamented: `flute` a quick grace from the pentatonic note above (the bamboo
	flute's flick), `fiddle` a slide from a step below (two quick notes rising into it). (beat, midi, beats, vel)."""
	out = []
	for x, name, d in tune:
		p = int(round(midi(name)))
		if d >= 1.0 and x % 1 == 0:
			g = 0.09 if inst_kind == "flute" else 0.07
			if inst_kind == "flute":
				up = [q for q in range(p + 1, p + 5) if q % 12 in PENTA][0]
				out.append((x, up, g, 0.42))
			else:
				out.append((x, p - 3 if (p - 3) % 12 in PENTA else p - 2, g, 0.36))
				out.append((x + g, p - 1, g, 0.42))
				g *= 2
			out.append((x + g, p, d - g, None))
		else:
			out.append((x, p, d, None))
	return out


# --- base: the drums as taiko, the low pizzicato, the sub -------------------------------------------------------------
## The low strings' figure in eighths on root (r) and fifth (f): "da-da DAA" with a push into the next bar.
OST = ["r", "r", "f", ".", "r", "f", "o", "f"]


def base(s: Score) -> None:
	prev = None
	for b in range(32):
		g = section_gain(b)
		root, pcs = chord(chord_at(b))
		r = near(root, "D2", "C#3", prev)
		prev = r
		f = r + 7
		for i, k in enumerate(OST):
			if k == ".":
				continue
			p = {"r": r, "f": f, "o": r + 12}[k]
			acc = i in (0, 2, 6)
			s.note("vc_pizz", b, i * 0.5, p, 0.5, (0.74 if acc else 0.52) * g)
			if acc:
				s.note("cb_pizz", b, i * 0.5, r - 12 if r - 12 >= midi("C2") else r, 0.5, 0.72 * g)
		s.note("sub", b, 0, near(root, "C1", "B1"), 4, 0.5 * g)
		# the big drum: one, the and of two, four; the C section doubles it
		s.hit("giant_drum", b, 0, 0.82 * g)
		s.hit("giant_drum", b, 1.5, 0.58 * g)
		s.hit("giant_drum", b, 3, 0.66 * g)
		s.hit("bd_big", b, 0, 0.68 * g)
		if b >= 24:
			s.hit("giant_drum", b, 2, 0.6 * g)
			s.hit("bd_big", b, 2, 0.55 * g)
		# the small drums: "doko-doko" sixteenths, accents on the beats
		for q in range(16):
			if q % 4 == 3 and b % 2 == 0:
				continue                              # (a breath every other bar)
			acc = q % 4 == 0
			s.hit("tenor_hi" if q % 2 == 0 else "tenor_lo", b, q * 0.25, (0.5 if acc else 0.3) * g)
		# the frame drum's backbeat and the log drum's off-beat clacks
		s.hit("frame", b, 1, 0.62 * g)
		s.hit("frame", b, 3, 0.68 * g)
		for q, w in ((0.5, 0.7), (1.75, 0.55), (2.5, 0.8), (3.5, 0.6)):
			s.hit("logdrum", b, q, 0.55 * w * g)
		# a big-drum flam into each phrase's last beat
		if b % 4 == 3:
			for k in range(6):
				s.hit("giant_drum", b, 2.5 + k * 0.25, (0.45 + 0.07 * k) * g)


# --- drive: the zither's ostinato and sweeps, the lute's plucks and tremolo, the violas ---------------------------------
def drive(s: Score) -> None:
	for b in range(32):
		g = section_gain(b)
		root, _ = chord(chord_at(b))
		lo = near(root, "D4", "C#5")
		ns = penta_up(lo, 7)
		# the zither: a rolling figure in sixteenths (the last beat of each phrase is its sweep's)
		pattern = [0, 2, 4, 2, 1, 2, 3, 4, 0, 2, 4, 5, 6, 5, 4, 2]
		end_of_phrase = b % 4 == 3
		for q, k in enumerate(pattern):
			if end_of_phrase and q >= 12:
				break
			s.note("harp", b, q * 0.25, ns[k], 0.25, (0.5 + (0.12 if q % 4 == 0 else 0.0)) * g)
		if end_of_phrase:
			sweep = penta_up(near(root, "D4", "C#5"), 12)
			for k, p in enumerate(sweep):
				s.note("harp", b, 3 + k * (1.0 / 12.0), p, 0.2, (0.42 + 0.03 * k) * g)
		# the lute: off-beat plucks on the chord's fifth and root, in B and on
		if b >= 8:
			_, pcs = chord(chord_at(b))
			for off in (0.5, 1.5, 2.5, 3.5):
				s.note("vln_pizz", b, off, near(pcs[0] if off in (0.5, 2.5) else pcs[-1], "A4", "G#5"), 0.25,
						0.5 * g)
		# its tremolo at the top of the form (C's last four bars): the pitch picked fast, a lute's sound
		if 28 <= b <= 31:
			top = near(chord(chord_at(b))[1][0], "D5", "C#6")
			for q in range(32):
				s.note("vln_pizz", b, q * 0.125, top, 0.125, (0.32 + 0.12 * (q / 31.0)) * g)
		# the violas: eighths on the root and fifth from A' on, for drive
		if b >= 16:
			for q in range(8):
				s.note("vla_spic", b, q * 0.5, near(root if q % 2 == 0 else (root + 7) % 12, "D3", "C#4"), 0.5,
						(0.48 + (0.1 if q % 4 == 0 else 0.0)) * g)
		# the marimba: a light pentatonic counter in A' (wood, under the flute)
		if 16 <= b < 24:
			cn = penta_up(near(root, "A3", "G#4"), 5)
			for q, k in enumerate((0, 2, 4, 2, 3, 1, 4, 2)):
				s.note("marimba", b, q * 0.5, cn[k], 0.5, 0.42 * g)
	# the horns (D4 at most): a low swell under C, the weight of the climb
	for b in range(24, 32):
		root, pcs = chord(chord_at(b))
		for p in (near(root, "D3", "C#4"), near(pcs[-1], "A2", "G#3")):
			s.note("hn", b, 0, p, 4, [(0, 0.35), (0.7, 0.58), (1, 0.5)])


# --- peak: the tune, the counter-line, the gong, cymbals and timpani ----------------------------------------------------
def peak(s: Score) -> None:
	fl_a = ornamented(TUNE_A, "flute")
	s.line("fl", 0, [(x, p, d, v if v is not None else 0.66) for x, p, d, v in fl_a])
	fid_b = ornamented(TUNE_B, "fiddle")
	s.line("solo_vln", 8, [(x, p, d, v if v is not None else 0.7) for x, p, d, v in fid_b])
	s.line("fl", 16, [(x, p + 12 if p < 79 else p, d, v if v is not None else 0.68) for x, p, d, v in fl_a])
	s.line("solo_vln", 16, [(x, p, d, v if v is not None else 0.52) for x, p, d, v in fl_a])
	fl_c = ornamented(TUNE_C, "flute")
	s.line("fl", 24, [(x, p, d, v if v is not None else 0.72) for x, p, d, v in fl_c])
	s.line("picc", 24, [(x, midi(n), d, 0.5) for x, n, d in TUNE_C if d >= 1])
	s.line("vln", 24, [(x, midi(n), d, 0.62) for x, n, d in TUNE_C])
	s.line("vla", 24, [(x, midi(n) - 12, d, 0.56) for x, n, d in TUNE_C])
	# the strings' long counter-line under A' (the chord's fifth and third, slow)
	for b in range(16, 24):
		_, pcs = chord(chord_at(b))
		s.note("vln", b, 0, near(pcs[1], "F4", "E5"), 4, [(0, 0.3), (0.6, 0.48), (1, 0.4)])
		s.note("vc", b, 0, near(pcs[0], "D3", "C#4"), 4, [(0, 0.32), (0.6, 0.5), (1, 0.42)])
	# the cellos under the fiddle in B
	s.line("vc", 8, [(0, "D4", 4), (4, "C4", 4), (8, "A3", 4), (12, "A3", 4), (16, "D4", 4), (20, "C4", 4),
			(24, "E4", 4), (28, "E4", 4)], 0.48)
	# the gong on each section, the cymbal swelling into it, the timpani on the roots and rolling into the next
	for b in (0, 8, 16, 24):
		root, _ = chord(chord_at(b))
		s.hit("gong", b, 0, 0.62 if b else 0.5)
		s.hit("timp", b, 0, 0.78, near(root, "D2", "C#3"))
	for b in (7, 15, 23):
		s.roll("timp_roll", b, 2, 2, (0.25, 0.82), "A2")
		s.swell(b + 1, 0, 0.55, 0)
	s.roll("timp_roll", 30, 0, 8, (0.2, 0.88), "D2")
	s.swell(32, 0, 0.7, 1)            # peaks on the loop's first beat (wrapped round)
	for b in range(24, 30):
		root, _ = chord(chord_at(b))
		s.hit("timp", b, 0, 0.64, near(root, "D2", "C#3"))
		s.hit("timp", b, 2.5, 0.48, near(root, "D2", "C#3"))
	s.hit("sus_cym", 28, 0, 0.5)


def full() -> Score:
	s = Score(BPM, 4, seed=23, hall=2.2)
	s.mix = {"timp": -2.0, "vc_pizz": 1.5, "cb_pizz": 2.5, "logdrum": -1.0, "tenor_hi": -2.0, "tenor_lo": -2.0,
			"harp": 1.0, "vln_pizz": -1.0, "vla_spic": -3.0, "picc": -4.0, "gong": -1.0, "marimba": -2.0, "hn": -3.0}
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
	"""The go: one bar, the gong and the big drums on D, the zither's sweep and the flute's flick onto the top."""
	s = Score(BPM, 4, seed=24, hall=1.8)
	s.hit("gong_st", 0, 0, 0.85)
	s.hit("gdrum_st", 0, 0, 0.9)
	s.hit("timp_st", 0, 0, 0.85, "D2")
	s.note("cb_pizz", 0, 0, "D2", 0.5, 0.85)
	s.note("vc_pizz", 0, 0, "D3", 0.5, 0.85)
	s.note("sub", 0, 0, "D1", 1.5, 0.6)
	for k, p in enumerate(penta_up(midi("D4"), 10)):
		s.note("harp", 0, k * 0.06, p, 0.3, 0.5 + 0.03 * k)
	s.note("fl", 0, 0, "G5", 0.08, 0.5)
	s.note("fl", 0, 0.08, "A5", 1.4, [(0, 0.78), (1, 0.4)])
	s.chord("vln", 0, 0, ["D5", "A5", "D6"], 1.5, [(0, 0.7), (1, 0.35)])
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
