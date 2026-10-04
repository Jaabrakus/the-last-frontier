"""The elegy (night): B minor, the cellos' song over the piano's broken chords, a solo violin's lift into D major, then
the song again with the violins and the choir. 60 BPM, about 1:50.

	0-1     the piano alone
	2-9     the cellos' song
	10-17   the lift: a solo violin, the cellos under it, the choir humming
	18-25   the song with the violins, the choir singing; its height at bar 23
	26-27   the piano alone
"""
from __future__ import annotations

from _lib import Voices, arc, bars, chord_spans, harp_arp, midi, pads, piano_arp, roots, tr
from orch import Score

CUE = dict(name="night_elegy", target=-21.0)

SONG = bars([
	[(0, "F#4", 1), (1, "B4", 2), (3, "C#5", 1)],
	[(0, "D5", 2), (2, "C#5", 1), (3, "B4", 1)],
	[(0, "B4", 1.5), (1.5, "A4", 0.5), (2, "G4", 2)],
	[(0, "F#4", 4)],
	[(0, "F#4", 1), (1, "B4", 2), (3, "C#5", 1)],
	[(0, "D5", 1), (1, "E5", 1), (2, "F#5", 2)],
	[(0, "E5", 2), (2, "D5", 1), (3, "C#5", 1)],
	[(0, "B4", 4)],
])
SONG_CH = [[(0, "Bm")], [(0, "G")], [(0, "Em")], [(0, "F#")], [(0, "Bm")], [(0, "G")], [(0, "Em7"), (2, "F#")],
		[(0, "Bm")]]
LIFT = bars([
	[(0, "D5", 2), (2, "B4", 2)],
	[(0, "A4", 2), (2, "F#4", 2)],
	[(0, "G4", 1), (1, "A4", 1), (2, "B4", 1), (3, "E5", 1)],
	[(0, "C#5", 3), (3, "A4", 1)],
	[(0, "B4", 1), (1, "D5", 1), (2, "G5", 2)],
	[(0, "F#5", 2), (2, "E5", 1), (3, "D5", 1)],
	[(0, "E5", 2), (2, "A#4", 2)],
	[(0, "B4", 4)],
])
LIFT_CH = [[(0, "G")], [(0, "D/F#")], [(0, "Em")], [(0, "A")], [(0, "G")], [(0, "D/F#")], [(0, "Em"), (2, "F#")],
		[(0, "Bm")]]


def build() -> Score:
	s = Score(60, 4, seed=89, hall=2.8)
	s.mix = {"choir": -5.0, "harp": -4.0}
	piano_arp(s, chord_spans([[(0, "Bm")], [(0, "Bm")]], 0), 0.32, "B1", "D5")

	A = chord_spans(SONG_CH, 2)
	piano_arp(s, A, 0.3, "B1", "D5")
	s.line("vc", 2, arc(tr(SONG, octave=-1), 0.5, 0.68), overlap=0.1)
	pads(s, A, ["vla", "vla"], 0.2, Voices(("D4", "A4"), ("F#3", "D4")))

	B = chord_spans(LIFT_CH, 10)
	piano_arp(s, B, 0.3, "B1", "D5")
	s.line("solo_vln", 10, arc(LIFT, 0.5, 0.66), overlap=0.08)
	bassline = bars([[(0, "G3", 4)], [(0, "F#3", 4)], [(0, "E3", 4)], [(0, "A3", 4)], [(0, "G3", 4)], [(0, "F#3", 4)],
			[(0, "E3", 2), (2, "F#3", 2)], [(0, "B2", 4)]])
	s.line("vc", 10, arc(bassline, 0.28, 0.38))
	pads(s, B, ["vla", "vla"], 0.24, Voices(("D4", "A4"), ("F#3", "D4")))
	for bar, beat, sym, ln in B:
		s.choir(bar, beat, Voices(("D4", "A4"), ("A3", "E4"))(sym), ln, 0.3, vowel="u")

	C = chord_spans(SONG_CH, 18)
	height = lambda b: 0.34 + 0.16 * max(0.0, 1.0 - abs(b - 23) / 3.0)
	piano_arp(s, C, 0.3, "B1", "D5")
	s.line("vln", 18, arc(SONG, 0.52, 0.72), overlap=0.1)
	s.line("vc", 18, arc(tr(SONG, octave=-1), 0.45, 0.62), overlap=0.1)
	pads(s, C, ["vla", "vla"], height, Voices(("D4", "A4"), ("F#3", "D4")))
	roots(s, "cb_nv", C, height, "B1", "A#2")
	for bar, beat, sym, ln in C:
		s.choir(bar, beat, Voices(("F#4", "D5"), ("B3", "F#4"), ("D3", "B3"))(sym), ln, height(bar) + 0.05, vowel="a")
	harp_arp(s, [x for x in C if x[1] == 0], 0.24, "B2", "F#4", step=1.0, low_bass=False)

	s.rit(25, 28, 48)
	piano_arp(s, [(26, 0, "Bm", 4)], 0.26, "B1", "D5")
	for p, v in (("B1", 0.28), ("F#2", 0.22), ("D3", 0.2), ("C#4", 0.18), ("F#4", 0.2), ("B4", 0.22)):
		s.note("piano", 27, 0, p, 8, v)
	drums_and_bass(s)
	return s


def drums_and_bass(s: Score) -> None:
	"""More drums and bass (user 2026-10-03: "add more drums and bass"): a soft heartbeat drum from the lift on, a
	plucked bass under the lift, the sub under the last verse."""
	from _lib import bass_pulse, chord_spans, heartbeat, sub_bass
	heartbeat(s, 10, 16, lambda b: 0.25 if b < 18 else 0.34)
	bass_pulse(s, chord_spans(LIFT_CH, 10), "cb_pizz", 0.32, "B1", "A#2", beats=(0, 2))
	sub_bass(s, chord_spans(LIFT_CH, 10), 0.24)
	sub_bass(s, chord_spans(SONG_CH, 18), 0.32)
