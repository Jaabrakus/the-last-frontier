"""Tidebreak's stingers (round 4 SHOW; rewritten 2026-10-13 with the score, the owner: "the music is bad ... the bell thing
is bad ... make some avatar inspired music"): short cues over the ring score (MusicDirector.ring_sting ducks the loop 9 dB
under each and brings it back over a beat), every one quoting the score's Tide motif (ring_fight.MOTIF: A D F G A, D minor
pentatonic) at the score's 132 BPM in D, in the score's band: the flute and the solo violin, the harp as a zither, the
plucked and bowed strings, the drums as taiko, the gong. No bells, no brass fanfare, no choir. Each one's length (s) is
its music; its hall's tail rings a little past it.

	ring_sting_ko_dealt      2.0  a fall you dealt: the motif quick in the flute and violins, the zither's sweep up, a
	                              drum and the gong on an open D
	ring_sting_ko_taken      2.0  a fall you took: the motif's fall in the solo violin, sliding down onto a low B-flat
	ring_sting_last_life     1.5  a side starts its last life: a low swell (the basses, a timpani roll, the drums
	                              gathering), the motif's first two notes plucked at its crest
	ring_sting_sudden_death  3.0  sudden death: the small drums racing, the strings trembling a semitone apart, the
	                              motif stabbed low in the pizzicato, the gong
	ring_sting_game_won      4.0  the motif and its answer onto an open D (D, A and E: bright, no third), the zither's sweep
	ring_sting_game_lost     4.0  the motif slow in the solo violin, a plagal close in D minor, the gong low
	ring_sting_match_won     6.0  the motif in the flute, piccolo and violins, the answer broadened, the open D with the
	                              drums, the gong and the zither
	ring_sting_match_lost    5.0  the motif in minor in the cellos and the solo violin, to a quiet D minor
	ring_sting_countdown     2.5  the bed under the count: the low strings trembling on D, the drums gathering, the
	                              motif's head plucked into the go (the score's own downbeat, ring_fight)

Horns at D4 or below (ring_fight.check_horns). ring_fight's short kits (`*_st`) stop the gong, the drums and the timpani
ringing seconds past a stinger.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from orch import Score, midi  # noqa: E402
from ring_fight import BPM, MOTIF, check_horns, penta_up  # noqa: E402


LENGTHS = {"ko_dealt": 2.0, "ko_taken": 2.0, "last_life": 1.5, "sudden_death": 3.0, "game_won": 4.0, "game_lost": 4.0,
		"match_won": 6.0, "match_lost": 5.0, "countdown": 2.5}
TARGETS = {"ko_dealt": -14.0, "ko_taken": -15.0, "last_life": -17.0, "sudden_death": -15.0, "game_won": -14.5,
		"game_lost": -16.5, "match_won": -14.0, "match_lost": -16.5, "countdown": -18.0}
CUES = [dict(name="ring_sting_" + k, target=TARGETS[k], length=LENGTHS[k]) for k in LENGTHS]


def _s(hall: float = 1.5) -> Score:
	s = Score(BPM, 4, seed=31, hall=hall)
	s.mix = {"harp": 1.0, "vc_pizz": 1.5, "cb_pizz": 2.0, "gong_st": -1.0}
	return s


def _motif(semis: int = 0, stretch: float = 1.0, at: float = 0.0, octave: int = 0):
	"""The motif moved: (beat, midi, beats)."""
	return [(at + b * stretch, int(round(midi(p))) + semis + 12 * octave, d * stretch) for b, p, d in MOTIF]


def _sweep(s: Score, bar: int, beat: float, lo: str, n: int, vel: float, step: float = 0.06) -> None:
	"""The zither's sweep: `n` notes of the pentatonic up from `lo`, quick."""
	for k, p in enumerate(penta_up(int(round(midi(lo))), n)):
		s.note("harp", bar, beat + k * step, p, 0.4, vel + 0.02 * k)


def _hit(s: Score, bar: int, beat: float, vel: float, gong: bool = True, root: str = "D2") -> None:
	s.hit("gdrum_st", bar, beat, vel)
	s.hit("timp_st", bar, beat, vel * 0.85, root)
	if gong:
		s.hit("gong_st", bar, beat, vel * 0.8)


def _open_d(s: Score, bar: int, beat: float, beats: float, vel: float, flute: bool = True) -> None:
	"""The open D everyone lands on (D, A and E: bright without a third), held `beats`."""
	env = [(0, vel), (0.6, vel * 0.85), (1, vel * 0.45)]
	s.chord("vln", bar, beat, ["A5", "D6", "E6"], beats, env)
	s.chord("vla", bar, beat, ["D5", "A5"], beats, env)
	s.chord("vc", bar, beat, ["D3", "A3"], beats, env)
	s.note("cb", bar, beat, "D2", beats, env)
	s.note("cb_pizz", bar, beat, "D2", 0.5, vel)
	s.note("vc_pizz", bar, beat, "D3", 0.5, vel)
	s.chord("hn", bar, beat, ["D3", "A3"], beats, [(0, vel * 0.7), (0.6, vel * 0.6), (1, vel * 0.3)])
	s.note("sub", bar, beat, "D1", beats * 0.8, vel * 0.7)
	if flute:
		s.note("fl", bar, beat, "D6", beats, env)
	_sweep(s, bar, beat, "D4", 10, vel * 0.55)
	_hit(s, bar, beat, vel)


def ko_dealt(s: Score) -> None:
	# the motif quick (sixteenths and an eighth), its last note held on the open D
	m = _motif(stretch=0.5)
	s.line("fl", 0, [(b, p, d if i < 4 else 1.6, 0.8) for i, (b, p, d) in enumerate(m)])
	s.line("vln", 0, [(b, p, d if i < 4 else 1.6, 0.72) for i, (b, p, d) in enumerate(m)])
	for k in range(4):
		s.hit("tenor_hi" if k % 2 == 0 else "tenor_lo", 0, k * 0.25, 0.5 + 0.08 * k)
	_open_d(s, 0, 1.75, 1.8, 0.82, flute=False)


def ko_taken(s: Score) -> None:
	# the motif's top falling in the solo violin (A G F D), sliding down onto a low B-flat
	fall = [(0, "A5", 0.5), (0.5, "G5", 0.5), (1.0, "F5", 0.5), (1.5, "D5", 0.4), (1.9, "C5", 0.1), (2.0, "Bb4", 1.6)]
	s.line("solo_vln", 0, [(b, p, d, 0.72) for b, p, d in fall])
	s.line("vc", 0, [(1.0, "F3", 1.0, 0.6), (2.0, "Bb2", 1.6, 0.68)])
	s.note("cb", 0, 2.0, "Bb1", 1.6, [(0, 0.7), (1, 0.3)])
	s.note("sub", 0, 2.0, "Bb0", 1.2, 0.55)
	s.hit("gdrum_st", 0, 2.0, 0.72)
	s.hit("timp_st", 0, 2.0, 0.7, "A2")


def last_life(s: Score) -> None:
	swell = [(0, 0.15), (0.75, 0.8), (1, 0.6)]
	s.note("cb", 0, 0, "D2", 2.4, swell)
	s.note("vc", 0, 0, "A2", 2.4, swell)
	s.roll("timp_roll", 0, 0, 2.2, (0.15, 0.8), "D2")
	s.note("sub", 0, 0, "D1", 2.4, swell)
	for k in range(8):
		s.hit("tenor_lo" if k % 2 else "tenor_hi", 0, 0.4 + k * 0.22, 0.25 + 0.06 * k)
	# the motif's head at the crest, plucked
	s.note("vc_pizz", 0, 1.8, "A2", 0.4, 0.78)
	s.note("vc_pizz", 0, 2.2, "D3", 0.6, 0.85)
	s.note("harp", 0, 2.2, "D4", 0.6, 0.7)
	s.hit("gdrum_st", 0, 2.2, 0.72)


def sudden_death(s: Score) -> None:
	# the small drums racing: eighths, then sixteenths, then thirty-seconds
	t = 0.0
	for step, until in ((0.5, 1.0), (0.25, 2.0), (0.125, 2.5)):
		while t < until:
			s.hit("tenor_hi" if int(t / step) % 2 == 0 else "tenor_lo", 0, t, 0.3 + 0.2 * (t / 2.5))
			t += step
	s.roll("timp_roll", 0, 0, 2.5, (0.15, 0.9), "A2")
	s.chord("vln_trem", 0, 0, ["D5", "Eb5"], 2.5, [(0, 0.15), (1, 0.7)])
	# the motif stabbed low in the pizzicato, the gong on its last note
	m = _motif(octave=-2, stretch=0.5, at=2.5)
	for b, p, d in m[:4]:
		s.note("vc_pizz", 0, b, p, 0.5, 0.8)
		s.note("cb_pizz", 0, b, p - 12, 0.5, 0.75)
	s.chord("vc", 0, 4.0, ["D3", "A3"], 1.5, [(0, 0.85), (1, 0.4)])
	s.note("cb", 0, 4.0, "D2", 1.5, [(0, 0.85), (1, 0.4)])
	s.note("sub", 0, 4.0, "D1", 1.2, 0.65)
	_hit(s, 0, 4.0, 0.95)


def game_won(s: Score) -> None:
	m = _motif()
	s.line("fl", 0, [(b, p, d, 0.78) for b, p, d in m])
	s.line("vln", 0, [(b, p, d, 0.68) for b, p, d in m])
	for b in (0, 2):
		s.note("cb_pizz", 0, b, "D2", 0.5, 0.72)
		s.hit("gdrum_st", 0, b, 0.7)
	s.hit("gong_st", 0, 0, 0.55)
	# the answer: C A G, up to D
	ans = [(4.0, "C6", 0.75), (4.75, "A5", 0.25), (5.0, "G5", 0.75)]
	s.line("fl", 0, [(b, p, d, 0.8) for b, p, d in ans])
	s.line("vln", 0, [(b, p, d, 0.7) for b, p, d in ans])
	s.chord("vc", 0, 4.0, ["C3", "G3"], 1.75, 0.65)
	_open_d(s, 1, 2.0, 2.4, 0.84)


def game_lost(s: Score) -> None:
	m = _motif(stretch=1.25)
	s.line("solo_vln", 0, [(b, p - 12, d, 0.62) for b, p, d in m])
	s.line("vc", 0, [(0, "D3", 2.5, 0.55), (2.5, "C3", 2.5, 0.55)])
	# a plagal close: G minor to D minor
	env = [(0, 0.62), (1, 0.3)]
	s.chord("vla", 1, 1.0, ["Bb3", "D4"], 2.0, env)
	s.chord("vln", 1, 1.0, ["G4", "D5"], 2.0, env)
	s.note("cb", 1, 1.0, "G2", 2.0, env)
	s.chord("vla", 1, 3.0, ["A3", "D4"], 1.7, [(0, 0.55), (1, 0.15)])
	s.chord("vln", 1, 3.0, ["F4", "D5"], 1.7, [(0, 0.55), (1, 0.15)])
	s.note("cb", 1, 3.0, "D2", 1.7, [(0, 0.55), (1, 0.15)])
	s.hit("timp_st", 1, 3.0, 0.5, "D2")
	s.hit("gong_st", 1, 3.0, 0.4)


def match_won(s: Score) -> None:
	head = _motif()
	s.roll("timp_roll", 0, 0, 1.0, (0.3, 0.85), "A2")
	for inst, sh, v in (("fl", 0, 0.82), ("vln", 0, 0.76), ("vla", -12, 0.66), ("picc", 12, 0.5)):
		s.line(inst, 0, [(b + 1.0, p + sh, d, v) for b, p, d in head])
	s.hit("gong_st", 0, 1.0, 0.62)
	for b in (1.0, 2.0, 3.0, 4.0):
		s.hit("gdrum_st", 0, b, 0.72)
		s.note("cb_pizz", 0, b, "D2", 0.5, 0.72)
	_sweep(s, 0, 4.5, "D4", 12, 0.5)
	# the answer broadened: C D F, up to the open D
	ans = [(5.0, "C6", 1.0), (6.0, "D6", 1.0), (7.0, "F6", 1.0)]
	s.line("fl", 0, [(b, p, d, 0.84) for b, p, d in ans])
	s.line("vln", 0, [(b, p, d, 0.78) for b, p, d in ans])
	s.chord("vc", 0, 5.0, ["C3", "G3"], 1.0, 0.7)
	s.chord("vc", 0, 6.0, ["D3", "A3"], 1.0, 0.72)
	s.chord("vc", 0, 7.0, ["F3", "C4"], 1.0, 0.75)
	for k in range(8):
		s.hit("tenor_hi" if k % 2 == 0 else "tenor_lo", 1, 2.0 + k * 0.25, 0.4 + 0.06 * k)
	_open_d(s, 2, 0, 4.8, 0.9)
	s.roll("timp_roll", 2, 1.5, 3.0, (0.3, 0.7), "D2")


def match_lost(s: Score) -> None:
	m = _motif(stretch=1.5)
	s.line("vc", 0, [(b, p - 12, d, 0.62) for b, p, d in m])
	s.line("solo_vln", 0, [(b + 1.5, p - 12, d, 0.5) for b, p, d in m[:4]])
	s.note("cb", 0, 0, "D2", 6.0, [(0, 0.3), (1, 0.5)])
	s.chord("vla", 0, 3.0, ["Bb3", "F4"], 3.0, [(0, 0.35), (1, 0.55)])
	env = [(0, 0.55), (1, 0.12)]
	s.chord("vln", 1, 2.0, ["F4", "A4", "D5"], 4.5, env)
	s.chord("vla", 1, 2.0, ["A3", "D4"], 4.5, env)
	s.note("cb", 1, 2.0, "D2", 4.5, env)
	s.hit("timp_st", 1, 2.0, 0.45, "D2")
	s.hit("gong_st", 1, 2.0, 0.35)


def countdown(s: Score) -> None:
	rise = [(0, 0.1), (1, 0.8)]
	s.chord("vc_trem", 0, 0, ["D3", "A3"], 5.5, rise)
	s.note("cb_trem", 0, 0, "D2", 5.5, rise)
	s.chord("vln_trem", 0, 0, ["A4", "D5"], 5.5, [(0, 0.05), (1, 0.6)])
	s.roll("timp_roll", 0, 0, 5.5, (0.1, 0.75), "A2")
	# the drums gathering, and the motif's head plucked into the go
	for k in range(10):
		s.hit("tenor_hi" if k % 2 == 0 else "tenor_lo", 0, 2.5 + k * 0.3, 0.2 + 0.05 * k)
	for b, p, d in _motif(octave=-1, at=2.5)[:4]:
		s.note("harp", 0, b, p, d, 0.6)
		s.note("vln_pizz", 0, b, p + 12, 0.25, 0.5)


BUILD = {"ko_dealt": ko_dealt, "ko_taken": ko_taken, "last_life": last_life, "sudden_death": sudden_death,
		"game_won": game_won, "game_lost": game_lost, "match_won": match_won, "match_lost": match_lost,
		"countdown": countdown}


def build(name: str) -> Score:
	k = name.replace("ring_sting_", "")
	s = _s(1.3 if LENGTHS[k] <= 2.5 else 1.7)
	BUILD[k](s)
	check_horns(s)
	return s
