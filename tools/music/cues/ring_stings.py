"""Tidebreak's stingers (round 4 SHOW): short cues over the ring score (MusicDirector.ring_sting ducks the loop 9 dB under
each and brings it back over a beat), every one quoting the score's Tide motif (ring_fight.MOTIF: A D E F# A) at the
score's 132 BPM in D, so a fall or an end sounds like the same band. Each one's length (s) is its music; its hall's tail
rings a little past it.

	ring_sting_ko_dealt      2.0  a fall you dealt: the motif bright and quick in the brass and strings, a cymbal on it
	ring_sting_ko_taken      2.0  a fall you took: the motif turned to D minor, falling away onto a low B-flat
	ring_sting_last_life     1.5  a side starts its last life: a low swell (the basses, trombones, a timpani roll), the
	                              motif's first two notes at its crest
	ring_sting_sudden_death  3.0  sudden death: the rolls rising, the motif stabbed in the low brass, a hit
	ring_sting_game_won      4.0  the motif and its answer to a D major cadence
	ring_sting_game_lost     4.0  the motif slow in D minor, a plagal close
	ring_sting_match_won     6.0  the motif in the trumpets and violins, the answer broadened, the choir on the last chord
	ring_sting_match_lost    5.0  the motif in minor in the cellos and choir, to a quiet D minor
	ring_sting_countdown     2.5  the bed under the count: the low strings trembling on D, a timpani roll and a snare
	                              roll rising into the go (the score's own downbeat, ring_fight)

Horns at D4 or below (ring_fight.check_horns). ring_fight's short kits (`*_st`) stop the cymbals, drums and timpani ringing
seconds past a stinger.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from orch import Score, midi  # noqa: E402
from ring_fight import BPM, MOTIF, check_horns  # noqa: E402


LENGTHS = {"ko_dealt": 2.0, "ko_taken": 2.0, "last_life": 1.5, "sudden_death": 3.0, "game_won": 4.0, "game_lost": 4.0,
		"match_won": 6.0, "match_lost": 5.0, "countdown": 2.5}
TARGETS = {"ko_dealt": -14.0, "ko_taken": -15.0, "last_life": -17.0, "sudden_death": -15.0, "game_won": -14.5,
		"game_lost": -16.5, "match_won": -14.0, "match_lost": -16.5, "countdown": -18.0}
CUES = [dict(name="ring_sting_" + k, target=TARGETS[k], length=LENGTHS[k]) for k in LENGTHS]


def _s(hall: float = 1.5) -> Score:
	s = Score(BPM, 4, seed=31, hall=hall)
	s.mix = {"choir": -5.0}
	return s


def _motif(semis: int = 0, stretch: float = 1.0, minor: bool = False, at: float = 0.0, octave: int = 0):
	"""The motif moved: (beat, midi, beats); `minor` lowers its F# to F."""
	out = []
	for b, p, d in MOTIF:
		m = midi(p) + semis + 12 * octave
		if minor and int(m) % 12 == 6:
			m -= 1
		out.append((at + b * stretch, m, d * stretch))
	return out


def _hit(s: Score, bar: int, beat: float, vel: float, root: str = "D2") -> None:
	s.hit("cym_st", bar, beat, vel * 0.9)
	s.hit("gdrum_st", bar, beat, vel)
	s.hit("timp_st", bar, beat, vel * 0.9, root)


def ko_dealt(s: Score) -> None:
	# the motif quick (sixteenths and an eighth), landing on F# held, a D major chord under it
	m = _motif(stretch=0.5)
	s.line("tpt", 0, [(b, p - 12, d if i < 3 else 1.6, 0.8) for i, (b, p, d) in enumerate(m[:4])])
	s.line("vln", 0, [(b, p, d if i < 3 else 1.6, 0.78) for i, (b, p, d) in enumerate(m[:4])])
	s.chord("hn", 0, 1.0, ["D3", "F#3", "A3"], 1.6, [(0, 0.85), (1, 0.45)])
	s.chord("tbn", 0, 1.0, ["D3", "A3"], 1.6, [(0, 0.8), (1, 0.4)])
	s.note("tuba", 0, 1.0, "D2", 1.6, [(0, 0.8), (1, 0.4)])
	s.note("sub", 0, 1.0, "D1", 1.4, 0.6)
	_hit(s, 0, 1.0, 0.85)
	for k in range(4):
		s.hit("tenor_hi" if k % 2 == 0 else "tenor_lo", 0, k * 0.25, 0.5 + 0.08 * k)


def ko_taken(s: Score) -> None:
	m = _motif(stretch=0.5, minor=True)
	s.line("vln", 0, [(b, p, d if i < 3 else 0.9, 0.7) for i, (b, p, d) in enumerate(m[:4])])
	s.line("hn", 0, [(b, p - 24, d if i < 3 else 0.9, 0.7) for i, (b, p, d) in enumerate(m[:4])])
	# falling away onto a low B-flat
	s.line("vc", 0, [(1.0, "F3", 1.0, 0.65), (2.0, "D3", 0.5, 0.6), (2.5, "Bb2", 1.4, 0.7)])
	s.chord("tbn", 0, 2.5, ["Bb2", "F3"], 1.4, [(0, 0.75), (1, 0.3)])
	s.note("tuba", 0, 2.5, "Bb1", 1.4, [(0, 0.75), (1, 0.3)])
	s.note("sub", 0, 2.5, "Bb0", 1.2, 0.55)
	s.hit("timp_st", 0, 2.5, 0.8, "A2")
	s.hit("gdrum_st", 0, 2.5, 0.75)


def last_life(s: Score) -> None:
	swell = [(0, 0.15), (0.75, 0.8), (1, 0.6)]
	s.note("cb", 0, 0, "D2", 2.4, swell)
	s.note("vc", 0, 0, "A2", 2.4, swell)
	s.chord("tbn", 0, 0, ["D2", "A2"], 2.4, swell)
	s.roll("timp_roll", 0, 0, 2.2, (0.15, 0.8), "D2")
	s.note("sub", 0, 0, "D1", 2.4, swell)
	# the motif's head at the crest
	s.line("hn", 0, [(1.8, "A2", 0.4, 0.75), (2.2, "D3", 0.6, 0.8)])
	s.hit("timp_st", 0, 2.2, 0.7, "D2")


def sudden_death(s: Score) -> None:
	s.roll("snare_roll", 0, 0, 2.5, (0.1, 0.85))
	s.roll("timp_roll", 0, 0, 2.5, (0.15, 0.9), "A2")
	s.chord("vln_trem", 0, 0, ["D5", "Eb5"], 2.5, [(0, 0.15), (1, 0.7)])
	# the motif stabbed low (horns and trombones), the hit on its last note
	m = _motif(octave=-2, stretch=0.5, at=2.5)
	for i, (b, p, d) in enumerate(m[:4]):
		for inst in ("hn_stac", "tbn_stac"):
			s.note(inst, 0, b, p, 0.5, 0.7 + 0.05 * i)
		s.note("tuba_stac", 0, b, p - 12, 0.5, 0.7)
	s.chord("hn", 0, 4.0, ["D3", "F#3", "A3"], 1.5, [(0, 0.9), (1, 0.4)])
	s.chord("tbn", 0, 4.0, ["D2", "A2"], 1.5, [(0, 0.9), (1, 0.4)])
	s.note("sub", 0, 4.0, "D1", 1.2, 0.65)
	_hit(s, 0, 4.0, 0.95)


def _cadence(s: Score, at_bar: int, at_beat: float, beats: float, vel: float, choir: bool = False) -> None:
	"""A D major chord for everyone at (bar, beat), held `beats`."""
	env = [(0, vel), (0.6, vel * 0.85), (1, vel * 0.5)]
	s.chord("hn", at_bar, at_beat, ["D3", "F#3", "A3", "D4"], beats, env)
	s.chord("tbn", at_bar, at_beat, ["D3", "A3"], beats, env)
	s.note("tuba", at_bar, at_beat, "D2", beats, env)
	s.chord("tpt", at_bar, at_beat, ["F#4", "A4", "D5"], beats, env)
	s.chord("vln", at_bar, at_beat, ["D5", "F#5", "A5", "D6"], beats, env)
	s.chord("vla", at_bar, at_beat, ["A4", "D5"], beats, env)
	s.chord("vc", at_bar, at_beat, ["D3", "A3"], beats, env)
	s.note("cb", at_bar, at_beat, "D2", beats, env)
	s.note("sub", at_bar, at_beat, "D1", beats * 0.8, vel * 0.7)
	if choir:
		s.choir(at_bar, at_beat, ["D4", "A4", "D5", "F#5"], beats, env, vowel="a")
	_hit(s, at_bar, at_beat, vel)


def game_won(s: Score) -> None:
	m = _motif()
	s.line("tpt", 0, [(b, p - 12, d, 0.75) for b, p, d in m])
	s.line("vln", 0, [(b, p, d, 0.75) for b, p, d in m])
	s.line("hn", 0, [(b, p - 24, d, 0.7) for b, p, d in m])
	for b in (0, 2):
		s.note("tuba_stac", 0, b, "D2", 0.5, 0.7)
		s.hit("gdrum_st", 0, b, 0.7)
	s.hit("cym_st", 0, 0, 0.7)
	# the answer: G F# E, home on D
	ans = [(4.0, "G5", 0.75), (4.75, "F#5", 0.25), (5.0, "E5", 0.75)]
	s.line("vln", 0, [(b, p, d, 0.78) for b, p, d in ans])
	s.line("tpt", 0, [(b, midi(p) - 12, d, 0.75) for b, p, d in ans])
	s.chord("tbn", 0, 4.0, ["G2", "D3"], 1.75, 0.7)
	s.chord("tbn", 0, 5.75, ["A2", "E3"], 0.75, 0.75)
	_cadence(s, 1, 2.5, 2.2, 0.82)


def game_lost(s: Score) -> None:
	m = _motif(stretch=1.25, minor=True)
	s.line("vln", 0, [(b, p - 12, d, 0.6) for b, p, d in m])
	s.line("vc", 0, [(0, "D3", 2.5, 0.55), (2.5, "C3", 2.5, 0.55)])
	s.chord("hn", 0, 0, ["D3", "F3"], 2.5, [(0, 0.4), (1, 0.55)])
	s.chord("hn", 0, 2.5, ["C3", "E3"], 2.5, 0.5)
	# a plagal close: G minor to D minor
	env = [(0, 0.62), (1, 0.3)]
	s.chord("vla", 1, 1.0, ["Bb3", "D4"], 2.0, env)
	s.chord("vln", 1, 1.0, ["G4", "D5"], 2.0, env)
	s.note("cb", 1, 1.0, "G2", 2.0, env)
	s.chord("vla", 1, 3.0, ["A3", "D4"], 1.7, [(0, 0.55), (1, 0.15)])
	s.chord("vln", 1, 3.0, ["F4", "D5"], 1.7, [(0, 0.55), (1, 0.15)])
	s.note("cb", 1, 3.0, "D2", 1.7, [(0, 0.55), (1, 0.15)])
	s.note("tbn", 1, 3.0, "D3", 1.5, [(0, 0.5), (1, 0.15)])
	s.hit("timp_st", 1, 3.0, 0.55, "D2")


def match_won(s: Score) -> None:
	game_won_head = _motif()
	s.roll("timp_roll", 0, 0, 1.0, (0.3, 0.85), "A2")
	for inst, sh, v in (("tpt", -12, 0.82), ("vln", 0, 0.82), ("vla", -12, 0.7), ("hn", -24, 0.75)):
		s.line(inst, 0, [(b + 1.0, p + sh, d, v) for b, p, d in game_won_head])
	s.hit("cym_st", 0, 1.0, 0.8)
	for b in (1.0, 2.0, 3.0, 4.0):
		s.hit("gdrum_st", 0, b, 0.72)
		s.note("tuba_stac", 0, b, "D2", 0.5, 0.72)
	# the answer broadened: G A B, up to D
	ans = [(5.0, "G5", 1.0), (6.0, "A5", 1.0), (7.0, "B5", 1.0)]
	s.line("vln", 0, [(b, p, d, 0.84) for b, p, d in ans])
	s.line("tpt", 0, [(b, midi(p) - 12, d, 0.8) for b, p, d in ans])
	s.chord("tbn", 0, 5.0, ["G2", "D3"], 1.0, 0.72)
	s.chord("tbn", 0, 6.0, ["A2", "E3"], 1.0, 0.75)
	s.chord("tbn", 0, 7.0, ["B2", "F#3"], 1.0, 0.78)
	s.chord("hn", 0, 5.0, ["G3", "B3", "D4"], 3.0, [(0, 0.6), (1, 0.8)])
	s.roll("snare_roll", 1, 2.0, 2.0, (0.15, 0.7))
	_cadence(s, 2, 0, 4.8, 0.9, choir=True)
	s.roll("timp_roll", 2, 1.5, 3.0, (0.3, 0.7), "D2")


def match_lost(s: Score) -> None:
	m = _motif(stretch=1.5, minor=True)
	s.line("vc", 0, [(b, p - 12, d, 0.62) for b, p, d in m])
	s.choir(0, 0, ["D4", "F4", "A4"], 6.0, [(0, 0.2), (0.6, 0.5), (1, 0.4)], vowel="o")
	s.note("cb", 0, 0, "D2", 6.0, [(0, 0.3), (1, 0.5)])
	s.chord("hn", 0, 3.0, ["Bb2", "F3"], 3.0, [(0, 0.35), (1, 0.55)])
	env = [(0, 0.55), (1, 0.12)]
	s.chord("vln", 1, 2.0, ["F4", "A4", "D5"], 4.5, env)
	s.chord("vla", 1, 2.0, ["A3", "D4"], 4.5, env)
	s.note("cb", 1, 2.0, "D2", 4.5, env)
	s.choir(1, 2.0, ["D4", "F4", "A4"], 4.0, env, vowel="o")
	s.hit("timp_st", 1, 2.0, 0.45, "D2")


def countdown(s: Score) -> None:
	rise = [(0, 0.1), (1, 0.8)]
	s.chord("vc_trem", 0, 0, ["D3", "A3"], 5.5, rise)
	s.note("cb_trem", 0, 0, "D2", 5.5, rise)
	s.chord("vln_trem", 0, 0, ["A4", "D5"], 5.5, [(0, 0.05), (1, 0.6)])
	s.roll("timp_roll", 0, 0, 5.5, (0.1, 0.75), "A2")
	s.roll("snare_roll", 0, 2.5, 3.0, (0.05, 0.55))
	# the motif's head in the low horns, its F# held into the go
	s.line("hn", 0, [(2.5, "A2", 0.5, 0.5), (3.0, "D3", 0.5, 0.55), (3.5, "E3", 0.5, 0.6), (4.0, "F#3", 1.5, 0.65)])


BUILD = {"ko_dealt": ko_dealt, "ko_taken": ko_taken, "last_life": last_life, "sudden_death": sudden_death,
		"game_won": game_won, "game_lost": game_lost, "match_won": match_won, "match_lost": match_lost,
		"countdown": countdown}


def build(name: str) -> Score:
	k = name.replace("ring_sting_", "")
	s = _s(1.3 if LENGTHS[k] <= 2.5 else 1.7)
	BUILD[k](s)
	check_horns(s)
	return s
