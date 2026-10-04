"""The peoples' themes (user 2026-10-03: "make music for each race when on char creation"): one short theme for each of
the character creator's 35 peoples (assets/character/body/peoples.json), heard while that people is chosen and crossed to
the next as the choice changes (MusicDirector). Each is a 16-bar loop: its eight-bar tune on one lead, then again on
another with everything fuller.

A people's theme is its mode or maqam (Middle Eastern ones with their quarter tones: a "-" after a note is a quarter
flat), its metre and tempo, a lead that suggests its own instruments with what the orchestra has (a solo violin for the
erhu, the kamancheh or a fiddle; a flute for a ney, a dizi or a shakuhachi, with their bends; the harp for a koto, a
qanun, a kora or a krar; the marimba and xylophone for a balafon or a ranat), its drums, and a drone where its music
keeps one. The Eastern Woodlands nations' themes are landscapes in the orchestra's own voice, not imitations of their
songs; like the Native dress (held for consultation), they want a word from those nations before they are final.

	notation   "D4:1 A4:1.5 ..." pitch:beats ("r" a rest, "E5-" a quarter flat), 8 bars of the people's metre
"""
from __future__ import annotations

import math
import re

from _lib import Voices, arc, bars, bass, bass_pulse, chord, frame_groove, hand_groove, heartbeat, midi, near, sub_bass
from orch import Score

# id: name, bpm, beats, lead (first, second), mel, chords (8, one a bar) or drone (a pitch: tonic and fifth held),
#     acc (accompaniments), perc, bass, and extras (bend: a scoop on the leads' longer notes; hall; callresp: the second
#     lead answers every other two bars)
P = {
	# --- Europe -----------------------------------------------------------------------------------------------------
	"english": dict(bpm=88, beats=3, lead=("fl", "vln"),
			mel="D4:1 G4:1 A4:1 B4:2 A4:1 G4:1 B4:1 D5:1 A4:3 B4:1 C5:1 B4:1 E5:1.5 D5:.5 C5:1 B4:1 A4:1 F#4:1 G4:3",
			chords=["G", "Em", "G", "D", "Em", "C", "D", "G"], acc=["harp", "pad"], perc="frame_soft", bass="pizz"),
	"scots_irish": dict(bpm=264, beats=6, lead=("solo_vln", "fl"),
			mel="A4:1 D5:1 D5:1 F#5:1 D5:1 D5:1 A4:1 D5:1 D5:1 E5:1 F#5:1 G5:1 E5:1 C5:1 C5:1 G5:1 C5:1 C5:1 "
				"E5:1 F#5:1 G5:1 F#5:1 E5:1 D5:1 A4:1 D5:1 D5:1 F#5:1 D5:1 D5:1 A5:1 F#5:1 D5:1 E5:1 F#5:1 G5:1 "
				"E5:1 C5:1 E5:1 G5:1 F#5:1 E5:1 D5:3 D5:2 r:1",
			chords=["D", "D", "C", "D", "D", "D", "C", "D"], drone="D3", acc=["drone"], perc="jig", bass="pizz"),
	"french": dict(bpm=104, beats=3, lead=("ob", "vln"),
			mel="E5:1 A5:1 C6:1 B5:1.5 A5:.5 G#5:1 A5:2 E5:1 D5:1 G5:1 F5:1 E5:1 G5:1 C6:1 A5:1.5 G5:.5 F5:1 "
				"E5:1 D5:.5 C5:.5 B4:1 A4:3",
			chords=["Am", "E", "Am", "G", "C", "Dm", "E", "Am"], acc=["pad", "harp_beats"], perc="none", bass="pizz"),
	"palatine": dict(bpm=80, beats=3, lead=("cl", "vln"),
			mel="C5:1 A4:1 F4:1 G4:2 A4:1 Bb4:1 A4:1 G4:1 A4:3 C5:1 D5:1 C5:1 Bb4:2 G4:1 A4:1 G4:1 E4:1 F4:3",
			chords=["F", "C", "Gm", "F", "F", "Gm", "C", "F"], acc=["pad", "harp"], perc="frame_soft", bass="pizz"),
	"dutch": dict(bpm=96, beats=4, lead=("fl", "ob"),
			mel="D5:1 E5:.5 F5:.5 G5:1 A5:1 G5:1 F5:.5 E5:.5 C5:2 D5:1 F5:1 E5:1 D5:1 C#5:2 A4:2 "
				"D5:1 A5:1 G5:.5 F5:.5 E5:1 F5:1 A5:1 C6:2 B5:.5 A5:.5 G5:1 E5:1 C5:1 D5:4",
			chords=["Dm", "C", "Dm", "A", "Dm", "F", "C", "Dm"], acc=["pizz", "harp"], perc="frame44", bass="pizz"),
	"spanish": dict(bpm=132, beats=3, lead=("solo_vln", "fl"),
			mel="E5:1 F5:1 G5:1 A5:2 G5:1 F5:1.5 E5:.5 D5:1 E5:3 C5:.5 D5:.5 E5:1 F5:1 G5:1 F5:1 E5:1 "
				"D5:1 C5:1 A4:1 G#4:1 F4:1 E4:1",
			chords=["Am", "G", "F", "E", "Am", "G", "F", "E"], acc=["strum", "pizz"], perc="castanet", bass="pizz"),
	# --- Eastern Woodlands (landscapes, the orchestra's own voice) --------------------------------------------------
	"haudenosaunee": dict(bpm=72, beats=4, lead=("fl", "hn"), octave2=-1,
			mel="E4:2 G4:1 A4:1 B4:3 A4:1 G4:1 E4:1 D4:2 E4:4 B4:2 D5:1 B4:1 A4:2 G4:2 A4:1 G4:1 E4:1 D4:1 E4:4",
			chords=["Em", "Em", "G", "Em", "G", "D", "C", "Em"], acc=["pad"], perc="pulse", bass="sub"),
	"lenape": dict(bpm=66, beats=4, lead=("cl", "fl"),
			mel="D4:1 G4:1 A4:2 B4:2 A4:1 G4:1 E4:2 D4:2 G4:4 B4:1 D5:1 E5:2 D5:2 B4:1 A4:1 G4:1 E4:1 D4:1 E4:1 G4:4",
			chords=["G", "Em", "C", "G", "G", "Bm", "C", "G"], acc=["ripple", "pad"], perc="shaker", bass="sub"),
	"shawnee": dict(bpm=70, beats=4, lead=("ob", "vln"),
			mel="A4:2 C5:1 A4:1 G4:2 F4:2 D4:1 F4:1 G4:1 A4:1 D4:4 D5:2 C5:1 A4:1 G4:1 A4:1 C5:2 A4:1 G4:1 F4:1 D4:1 D4:4",
			chords=["Dm", "Gm", "Dm", "Dm", "F", "C", "Gm", "Dm"], acc=["pad", "harp_slow"], perc="pulse", bass="pizz"),
	"wabanaki": dict(bpm=64, beats=4, lead=("fl", "solo_vln"),
			mel="E4:1 A4:1 B4:2 C#5:3 B4:1 A4:2 F#4:2 E4:4 A4:1 C#5:1 E5:2 F#5:2 E5:1 C#5:1 B4:1 A4:1 F#4:1 B4:1 A4:4",
			chords=["A", "A", "F#m", "E", "A", "F#m", "D", "A"], acc=["swell", "harp_slow"], perc="sea", bass="sub"),
	# --- Africa -----------------------------------------------------------------------------------------------------
	"west_african": dict(bpm=104, beats=4, lead=("marimba", "fl"),
			mel="F4:.5 G4:.5 A4:1 C5:1 A4:1 D5:1.5 C5:.5 A4:2 C5:1 A4:.5 G4:.5 F4:1 G4:1 A4:4 "
				"C5:.5 D5:.5 C5:1 A4:1 C5:1 F5:1.5 D5:.5 C5:2 D5:.5 C5:.5 A4:1 G4:1 A4:1 F4:4",
			chords=["F", "Bb", "F", "F", "F", "Bb", "C", "F"], acc=["kora"], perc="bell12", bass="ost"),
	"central_african": dict(bpm=112, beats=4, lead=("fl", "xylo"),
			mel="G4:.5 C5:.5 E5:.5 D5:.5 C5:1 A4:1 G4:.5 A4:.5 C5:1 D5:2 E5:.5 D5:.5 C5:.5 A4:.5 G4:1 E4:1 G4:4 "
				"C5:.5 E5:.5 G5:1 E5:1 D5:1 C5:.5 D5:.5 E5:1 C5:2 A4:.5 C5:.5 D5:1 C5:1 A4:1 C5:4",
			chords=["C", "Am", "C", "G", "C", "C", "Am", "C"], acc=["hocket", "marimba"], perc="hand", bass="pizz"),
	"african_american": dict(bpm=70, beats=4, lead=("vc", "choir"), callresp=True,
			mel="Bb3:1 Eb4:1 F4:1 G4:1 Bb4:3 G4:1 G4:1 F4:1 Eb4:1 C4:1 Eb4:4 G4:1 Bb4:1 C5:1 Bb4:1 G4:2 F4:2 "
				"Eb4:1 F4:1 Gb4:.5 F4:.5 Eb4:1 Eb4:4",
			chords=["Eb", "Eb", "Ab", "Eb", "Eb", "Cm", "Ab", "Eb"], acc=["banjo"], perc="juba", bass="pizz"),
	"ethiopian": dict(bpm=200, beats=6, lead=("fl", "solo_vln"),
			mel="E5:2 D5:1 C5:2 A4:1 G4:3 A4:3 C5:2 D5:1 E5:2 G5:1 E5:6 A5:2 G5:1 E5:2 D5:1 C5:3 D5:3 "
				"E5:2 D5:1 C5:1 A4:1 G4:1 C5:6",
			chords=["C", "Am", "C", "C", "Am", "F", "G", "C"], acc=["krar"], perc="kebero", bass="pizz"),
	# --- East Asia --------------------------------------------------------------------------------------------------
	"japanese": dict(bpm=60, beats=4, lead=("fl", "solo_vln"), bend=(-70, 0.18),
			mel="E5:2 F5:1 E5:1 A4:3 r:1 B4:1 C5:1 B4:1 A4:1 E4:4 A4:2 B4:1 C5:1 F5:2 E5:2 C5:1 B4:1 A4:1 F4:1 E4:4",
			drone="E3", acc=["drone", "koto"], perc="taiko", bass="sub", scale=["E", "F", "A", "B", "C"]),
	"chinese": dict(bpm=72, beats=4, lead=("solo_vln", "fl"), bend=(-60, 0.12),
			mel="E5:1 G5:1 A5:2 G5:1 E5:1 D5:2 C5:1 D5:1 E5:1 G5:1 E5:4 A5:1 C6:1 A5:1 G5:1 E5:2 D5:2 "
				"E5:1 D5:1 C5:1 A4:1 C5:4",
			chords=["C", "Am", "C", "Em", "Am", "G", "Am", "C"], acc=["pipa", "pad"], perc="gong", bass="sub"),
	"korean": dict(bpm=66, beats=3, lead=("ob", "solo_vln"), bend=(-80, 0.15),
			mel="E5:2 D5:1 C5:1.5 D5:.5 E5:1 A4:3 G4:1 A4:1 C5:1 D5:2 E5:1 G5:1.5 E5:.5 D5:1 C5:1 A4:1 G4:1 A4:3",
			drone="A2", acc=["drone", "gayageum"], perc="janggu", bass="sub", scale=["A", "C", "D", "E", "G"]),
	# --- South Asia -------------------------------------------------------------------------------------------------
	"south_asian": dict(bpm=76, beats=4, lead=("solo_vln", "fl"), bend=(-90, 0.14),
			mel="C#5:.5 E5:.5 F#5:1 G#5:1 A5:1 G#5:.5 F#5:.5 E5:1 F#5:2 B5:1 A5:1 G#5:1 F#5:1 E5:2 D5:2 "
				"F#5:1 G#5:.5 A5:.5 B5:1 C#6:1 D6:2 C#6:1 B5:1 A5:1 G#5:1 F#5:.5 E5:.5 C#5:1 D5:4",
			drone="D3", acc=["tanpura"], perc="tabla", bass="sub_drone"),
	# --- Southeast Asia ---------------------------------------------------------------------------------------------
	"filipino": dict(bpm=76, beats=3, lead=("solo_vln", "fl"),
			mel="A4:1 D5:1 E5:1 F5:2 E5:1 D5:1 C#5:1 D5:1 A4:3 Bb4:1 D5:1 F5:1 A5:2 G5:1 F5:1 E5:1 C#5:1 D5:3",
			chords=["Dm", "Dm", "A", "Dm", "Bb", "F", "A", "Dm"], acc=["rondalla", "pad"], perc="none", bass="pizz"),
	"vietnamese": dict(bpm=66, beats=4, lead=("solo_vln", "fl"), bend=(-90, 0.2),
			mel="G4:1 A4:1 C5:2 D5:1.5 C5:.5 A4:2 G4:1 F4:1 G4:2 D4:4 F4:1 G4:1 A4:1 C5:1 D5:2 F5:2 "
				"D5:1 C5:1 A4:1 G4:1 G4:4",
			chords=["G5", "F", "G5", "Dm", "F", "Dm", "F", "G5"], acc=["tranh"], perc="woodblock", bass="sub"),
	"thai": dict(bpm=100, beats=4, lead=("xylo", "ob"),
			mel="E5:.5 G5:.5 A5:.5 G5:.5 E5:1 D5:1 C5:.5 D5:.5 E5:.5 G5:.5 A5:2 C6:.5 A5:.5 G5:.5 E5:.5 D5:1 E5:1 G5:4 "
				"A5:.5 G5:.5 E5:.5 D5:.5 C5:1 D5:1 E5:.5 G5:.5 A5:.5 C6:.5 A5:2 G5:.5 E5:.5 D5:.5 C5:.5 D5:1 E5:1 C5:4",
			chords=["C", "Am", "C", "G", "Am", "C", "G", "C"], acc=["ranat"], perc="ching", bass="sub"),
	"malay": dict(bpm=112, beats=4, lead=("solo_vln", "fl"),
			mel="A4:.5 B4:.5 D5:1 F#5:1 E5:1 D5:.5 E5:.5 F#5:.5 A5:.5 G5:1 F#5:1 E5:1 D5:1 B4:1 D5:1 A4:4 "
				"B4:.5 D5:.5 E5:1 G5:1 F#5:1 E5:.5 F#5:.5 G5:.5 B5:.5 A5:2 G5:1 F#5:1 E5:1 C#5:1 D5:4",
			chords=["D", "D", "G", "A", "G", "A", "A", "D"], acc=["harp", "pizz"], perc="rebana", bass="pizz"),
	"pacific_islander": dict(bpm=92, beats=4, lead=("choir", "fl"),
			mel="C5:1 C5:.5 D5:.5 F5:1 E5:1 D5:1 C5:1 A4:2 Bb4:1 A4:1 G4:1 A4:1 C5:4 F5:1 F5:.5 G5:.5 A5:1 G5:1 "
				"F5:1 D5:1 C5:2 D5:1 C5:1 A4:1 G4:1 F4:4",
			chords=["F", "Dm", "Gm", "C", "F", "Bb", "C", "F"], acc=["choir_pad"], perc="logdrums", bass="pizz"),
	# --- Middle East (quarter tones: "-") ---------------------------------------------------------------------------
	"levantine": dict(bpm=96, beats=4, lead=("solo_vln", "fl"),
			mel="D5:1 E5-:.5 F5:.5 G5:1 F5:1 E5-:1 D5:1 C5:2 D5:.5 E5-:.5 F5:.5 G5:.5 A5:1 Bb5:1 A5:4 "
				"G5:1 F5:1 E5-:1 F5:1 G5:.5 A5:.5 G5:.5 F5:.5 E5-:2 F5:1 E5-:1 D5:1 C5:1 D5:4",
			drone="D3", acc=["drone", "oud"], perc="maqsum", bass="ost"),
	"ottoman_turkish": dict(bpm=92, beats=4, lead=("ob", "tpt"), lead2_with_first=True,
			mel="A4:1 Bb4:1 C#5:1 D5:1 E5:2 D5:1 C#5:1 D5:1 E5:1 F5:1 E5:1 D5:.5 C#5:.5 Bb4:1 A4:2 "
				"A4:1 C#5:1 E5:1 G5:1 F5:1 E5:1 D5:2 C#5:1 D5:.5 C#5:.5 Bb4:1 C#5:1 A4:4",
			drone="A2", acc=["drone"], perc="mehter", bass="sub_drone"),
	"persian": dict(bpm=210, beats=6, lead=("solo_vln", "fl"), bend=(-60, 0.1),
			mel="D5:2 C5:1 Bb4:2 A4-:1 G4:3 A4-:3 Bb4:2 C5:1 D5:2 Eb5:1 D5:6 F5:2 Eb5:1 D5:2 C5:1 Bb4:2 C5:1 A4-:3 "
				"Bb4:1 A4-:1 G4:1 A4-:1 Bb4:1 C5:1 G4:6",
			drone="G2", acc=["drone", "santur"], perc="tombak", bass="sub_drone"),
	"arab": dict(bpm=84, beats=4, lead=("fl", "solo_vln"), bend=(-50, 0.12),
			mel="D5:1 Eb5:1 F#5:2 G5:1 F#5:.5 Eb5:.5 D5:2 A5:1 Bb5:.5 A5:.5 G5:1 F#5:1 G5:4 "
				"F#5:1 G5:1 A5:1 Bb5:1 C6:1 Bb5:1 A5:2 G5:1 F#5:1 Eb5:1 F#5:1 D5:4",
			drone="D3", acc=["drone", "qanun"], perc="wahda", bass="ost"),
	"armenian": dict(bpm=56, beats=4, lead=("cl", "vc"), bend=(-60, 0.2), octave2=-1,
			mel="E4:1 A4:1 B4:1 C5:1 B4:2 A4:2 G4:1 A4:1 B4:1 G4:1 A4:4 C5:1 D5:1 E5:1.5 D5:.5 C5:2 B4:2 "
				"B4:1 A4:1 G#4:1 B4:1 A4:4",
			drone="A2", acc=["dam"], perc="frame_soft", bass="sub_drone"),
	"kurdish": dict(bpm=116, beats=4, lead=("fl", "ob"),
			mel="D5:.5 Eb5:.5 F5:1 G5:1 F5:1 Eb5:.5 F5:.5 Eb5:.5 D5:.5 C5:2 D5:1 F5:1 A5:1 G5:1 F5:.5 Eb5:.5 D5:3 "
				"A5:.5 Bb5:.5 A5:1 G5:1 F5:1 G5:.5 A5:.5 G5:.5 F5:.5 Eb5:2 F5:1 Eb5:1 D5:1 C5:1 D5:4",
			drone="D3", acc=["drone", "tembur"], perc="daf", bass="ost"),
	# --- North Africa -----------------------------------------------------------------------------------------------
	"north_african": dict(bpm=240, beats=6, lead=("fl", "choir"), callresp=True,
			mel="A4:2 C5:1 D5:2 E5:1 D5:2 C5:1 A4:3 G4:2 A4:1 C5:2 D5:1 A4:6 E5:2 G5:1 E5:2 D5:1 C5:2 D5:1 E5:3 "
				"D5:2 C5:1 A4:1 G4:1 E4:1 A4:6",
			drone="A2", acc=["gimbri"], perc="bendir", bass="none"),
	"moorish": dict(bpm=180, beats=6, lead=("vln", "fl"),
			mel="D5:2 Eb5:1 D5:2 C5:1 B4:2 C5:1 D5:3 G5:2 F5:1 Eb5:2 D5:1 D5:6 C5:2 D5:1 Eb5:2 F5:1 Eb5:2 D5:1 C5:3 "
				"B4:2 C5:1 Ab4:2 B4:1 G4:6",
			drone="G2", acc=["drone", "oud"], perc="tar68", bass="sub_drone"),
	"egyptian": dict(bpm=104, beats=4, lead=("ob", "solo_vln"),
			mel="C5:1 D5:.5 E5-:.5 F5:1 G5:1 A5:1 G5:.5 F5:.5 E5-:2 F5:1 G5:1 A5:.5 B5-:.5 C6:1 G5:4 "
				"A5:1 G5:1 F5:1 E5-:1 F5:.5 G5:.5 F5:.5 E5-:.5 D5:2 E5-:1 D5:1 B4-:1 D5:1 C5:4",
			drone="C3", acc=["drone", "qanun"], perc="saidi", bass="ost"),
	# --- Mixed ancestry ---------------------------------------------------------------------------------------------
	"metis": dict(bpm=116, beats=4, lead=("solo_vln", "solo_vln"),
			mel="A4:.5 D5:.5 F#5:.5 D5:.5 A5:.5 F#5:.5 D5:.5 F#5:.5 G5:.5 E5:.5 C#5:.5 E5:.5 A5:1 G5:.5 E5:.5 "
				"F#5:.5 D5:.5 A4:.5 D5:.5 F#5:.5 A5:.5 B5:.5 A5:.5 G5:.5 F#5:.5 E5:.5 D5:.5 C#5:.5 A4:.5 B4:.5 C#5:.5 "
				"D5:.5 F#5:.5 A5:.5 F#5:.5 D6:1 B5:.5 A5:.5 G5:.5 B5:.5 A5:.5 G5:.5 F#5:1 E5:.5 D5:.5 "
				"E5:.5 F#5:.5 G5:.5 E5:.5 C#5:.5 A4:.5 B4:.5 C#5:.5 D5:2 D5:1 r:1",
			chords=["D", "A", "D", "A", "D", "G", "A", "D"], acc=["pizz"], perc="jigsteps", bass="pizz"),
	"afro_native": dict(bpm=88, beats=4, lead=("fl", "vc"), octave2=-1,
			mel="B4:1 D5:.5 E5:.5 G5:1 E5:1 D5:1 B4:1 A4:2 G4:.5 A4:.5 B4:1 D5:1 B4:1 E5:4 G5:1 A5:.5 G5:.5 E5:1 D5:1 "
				"E5:1 D5:1 B4:2 A4:1 B4:.5 A4:.5 G4:1 A4:1 E4:4",
			chords=["Em", "G", "Em", "Em", "C", "Em", "D", "Em"], acc=["kora", "pad"], perc="hand_pulse", bass="pizz"),
	"euro_african": dict(bpm=100, beats=4, lead=("solo_vln", "cl"),
			mel="D5:.75 B4:.25 D5:.5 G5:.5 F#5:1 E5:1 D5:.75 C5:.25 B4:.5 A4:.5 B4:2 C5:.75 E5:.25 G5:.5 E5:.5 D5:1 C5:1 "
				"B4:.5 A4:.5 G4:1 A4:2 D5:.75 B4:.25 D5:.5 G5:.5 B5:1 A5:1 G5:.75 F#5:.25 E5:.5 D5:.5 E5:2 "
				"C5:.5 E5:.5 D5:.5 B4:.5 A4:1 F#4:1 G4:4",
			chords=["G", "G", "C", "D", "G", "Em", "D", "G"], acc=["harp", "pizz"], perc="habanera", bass="tresillo"),
}
NAMES = {"english": "English", "scots_irish": "Scots-Irish", "french": "French", "palatine": "Palatine German",
		"dutch": "Dutch (Albany)", "spanish": "Spanish", "haudenosaunee": "Haudenosaunee", "lenape": "Lenape",
		"shawnee": "Shawnee", "wabanaki": "Wabanaki", "west_african": "West African", "central_african": "Central African",
		"african_american": "African American", "ethiopian": "Ethiopian", "japanese": "Japanese", "chinese": "Chinese",
		"korean": "Korean", "south_asian": "South Asian", "filipino": "Filipino", "vietnamese": "Vietnamese",
		"thai": "Thai (Siamese)", "malay": "Malay", "pacific_islander": "Pacific Islander", "levantine": "Levantine",
		"ottoman_turkish": "Ottoman Turkish", "persian": "Persian", "arab": "Arab", "armenian": "Armenian",
		"kurdish": "Kurdish", "north_african": "North African", "moorish": "Moorish (Morocco)", "egyptian": "Egyptian",
		"metis": "French and Native (Metis)", "afro_native": "African and Native", "euro_african": "European and African"}
CUES = [dict(name="people_" + k, target=-21.0, loop=(0, 16)) for k in P]


def tune(text: str) -> list:
	"""'D4:1 A4:1.5 r:1 E5-:.5' -> [(beat, pitch, beats)] ("-" a quarter flat)."""
	out, t = [], 0.0
	for tok in text.split():
		p, d = tok.split(":")
		d = float(d)
		if p != "r":
			q = p.endswith("-")
			out.append((t, midi(p.rstrip("-")) - (0.5 if q else 0.0), d))
		t += d
	return out


def build(name: str) -> Score:
	pid = name[len("people_"):]
	p = P[pid]
	beats = p["beats"]
	s = Score(p["bpm"], beats, seed=sum(map(ord, pid)), hall=p.get("hall", 2.6))
	mel = tune(p["mel"])
	total = sum(n[2] for n in mel) + sum(float(t.split(":")[1]) for t in p["mel"].split() if t.startswith("r:"))
	assert math.isclose(total, 8 * beats), f"{pid}: the tune is {total} beats, not {8 * beats}"
	drone = p.get("drone")
	chords = p.get("chords") or [_drone_chord(drone)] * 8
	sp = [(b, 0, chords[b % 8], beats) for b in range(16)]
	lead1, lead2 = p["lead"]
	kw = {"bend": p["bend"]} if p.get("bend") else {}
	# the tune: the first lead, then the second (an octave off when `octave2`), the first under it when asked
	_lead(s, lead1, 0, mel, 0.55, 0.68, kw, beats)
	mel2 = [(n[0], n[1] + 12 * p.get("octave2", 0), n[2]) for n in mel]
	if p.get("callresp"):
		# call and answer: the first lead calls two bars, the second answers two
		_lead(s, lead1, 8, [n for n in mel if (n[0] // (2 * beats)) % 2 == 0], 0.6, 0.72, kw, beats)
		_lead(s, lead2, 8, [n for n in mel2 if (n[0] // (2 * beats)) % 2 == 1], 0.6, 0.72, kw, beats)
	else:
		_lead(s, lead2, 8, mel2, 0.6, 0.74, kw, beats)
		if p.get("lead2_with_first"):
			_lead(s, lead1, 8, mel, 0.5, 0.62, kw, beats)
	for a in p["acc"]:
		ACC[a](s, sp, p)
	PERC[p["perc"]](s, p, beats)
	_bass(s, sp, p)
	# the drums forward (user: "add more drums"), the harp's accompaniment a little back under the tune
	for k in DRUMS:
		s.mix[k] = s.mix.get(k, 0.0) + 4.0
	if "harp" not in (lead1, lead2):
		s.mix["harp"] = s.mix.get("harp", 0.0) - 2.5
	return s


DRUMS = ["frame", "tamb", "shaker", "bd_muted", "bd_big", "giant_drum", "giant_hand", "tenor_lo", "tenor_hi", "conga_lo",
		"conga_hi", "bongo", "logdrum", "gong", "tri", "cym"]


def _lead(s: Score, inst: str, bar: int, notes, lo: float, hi: float, kw: dict, beats: int) -> None:
	if inst == "choir":
		for n in arc(notes, lo, hi):
			s.choir(bar, n[0], [n[1]], n[2] * 0.95, n[3] * 0.9, vowel="a", attack=0.08)
		return
	s.line(inst, bar, arc(notes, lo, hi), legato=inst not in ("marimba", "xylo"), **kw)


def _drone_chord(pitch) -> str:
	names = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
	return names[int(midi(pitch)) % 12] + "5"


def _vel(b: int, lo: float, hi: float) -> float:
	return lo if b < 8 else hi


# --- accompaniments: (score, spans, people) -------------------------------------------------------------------------

def _pad(s, sp, p):
	v = Voices(("A3", "E4"), ("D3", "A3"))
	for bar, beat, sym, ln in sp:
		for k, x in zip(["vla", "vc"], v(sym)):
			s.note(k, bar, beat, x, ln, _vel(bar, 0.18, 0.26))


def _swell(s, sp, p):
	v = Voices(("C#4", "A4"), ("E3", "C#4"))
	for bar, beat, sym, ln in sp:
		if bar % 2 == 0:
			for k, x in zip(["vla", "vc"], v(sym)):
				s.note(k, bar, beat, x, 2 * ln, [(0, 0.12), (0.6, _vel(bar, 0.28, 0.36)), (1, 0.15)])


def _drone(s, sp, p):
	t = int(midi(p["drone"]))
	for bar in range(0, 16, 4):
		v = _vel(bar, 0.2, 0.26)
		s.note("vc", bar, 0, t, 4 * p["beats"], v)
		s.note("vla", bar, 0, t + 7, 4 * p["beats"], v * 0.85)


def _dam(s, sp, p):        # a second duduk holding the tonic under the first (the dam): the bassoon
	t = int(midi(p["drone"])) + 12
	for bar in range(0, 16, 4):
		s.note("bsn", bar, 0, t, 4 * p["beats"], _vel(bar, 0.3, 0.36))


def _arp(s, sp, inst, step, vel, lo="C3", hi="C5", pat=None):
	for bar, beat, sym, ln in sp:
		b, pcs = chord(sym)
		base = int(midi(lo))
		tones = sorted({near(pc, base, base + 11) for pc in pcs} | {near(pc, base + 12, base + 23) for pc in pcs})
		tones = [x for x in tones if x <= max(int(midi(hi)), base + 12)] or tones
		seq = pat(tones) if pat else tones + tones[-2:0:-1]
		k = 0
		while k * step < ln - 1e-6:
			s.note(inst, bar, beat + k * step, seq[k % len(seq)], 1, _vel(bar, vel, vel * 1.2) * (1.0 if k % 2 == 0 else 0.8))
			k += 1


def _harp(s, sp, p):
	_arp(s, sp, "harp", 0.5, 0.26)


def _harp_beats(s, sp, p):  # a continuo's plucked chords on each beat
	for bar, beat, sym, ln in sp:
		_, pcs = chord(sym)
		for k in range(int(ln)):
			for j, pc in enumerate(pcs[:3]):
				s.note("harp", bar, beat + k + 0.02 * j, near(pc, "E3", "D#4"), 1, _vel(bar, 0.22, 0.28))


def _harp_slow(s, sp, p):
	for bar, beat, sym, ln in sp:
		_, pcs = chord(sym)
		for j, pc in enumerate(sorted(near(c, "D3", "C#4") for c in pcs)):
			s.note("harp", bar, beat + 0.1 * j, pc, 2, _vel(bar, 0.24, 0.3))


def _ripple(s, sp, p):
	_arp(s, sp, "harp", 1 / 3, 0.22, "D3", "D5")


def _kora(s, sp, p):      # a kora's interlocking runs: the harp in triplets over two octaves
	_arp(s, sp, "harp", 1 / 3, 0.25, "F3", "F5", pat=lambda t: [t[0], t[2], t[1], t[3] if len(t) > 3 else t[1], t[2], t[-1]])


def _krar(s, sp, p):
	_arp(s, sp, "harp", 1.0, 0.28, "C4", "C5", pat=lambda t: [t[0], t[2], t[1], t[2], t[-1], t[1]])


def _koto(s, sp, p):      # plucked notes of the In scale, a glide up now and then
	sc = [PCS_ONLY(n) for n in p["scale"]]
	notes = [x for x in range(int(midi("E3")), int(midi("E5")) + 1) if x % 12 in sc]
	for bar in range(16):
		v = _vel(bar, 0.26, 0.32)
		s.note("harp", bar, 0, notes[0] if bar % 2 == 0 else notes[2], 2, v)
		s.note("harp", bar, 1.5, notes[4 + bar % 3], 1, v * 0.8)
		s.note("harp", bar, 2.5, notes[3 + bar % 2], 1, v * 0.7)
		if bar % 4 == 3:
			for k, x in enumerate(notes[3:9]):
				s.note("harp", bar, 3 + k / 6, x, 1, v * 0.6)


def _gayageum(s, sp, p):
	sc = [PCS_ONLY(n) for n in p["scale"]]
	notes = [x for x in range(int(midi("A2")), int(midi("A4")) + 1) if x % 12 in sc]
	for bar in range(16):
		v = _vel(bar, 0.28, 0.34)
		s.note("harp", bar, 0, notes[0], 2, v, bend=(-80, 0.15))
		s.note("harp", bar, 1, notes[3 + bar % 3], 1, v * 0.8)
		s.note("harp", bar, 2, notes[5], 1, v * 0.75, bend=(60, 0.12))


def _pipa(s, sp, p):      # a pipa's or guzheng's tremolo on the chord's top, a glissando into each fourth bar
	for bar, beat, sym, ln in sp:
		_, pcs = chord(sym)
		top = near(pcs[1], "E4", "D#5")
		v = _vel(bar, 0.16, 0.2)
		for k in range(int(ln * 4)):
			s.note("harp", bar, beat + k * 0.25, top if k % 2 == 0 else top - 12, 0.25, v)
		if bar % 4 == 3:
			for k, x in enumerate([60, 62, 64, 67, 69, 72, 74, 76]):
				s.note("harp", bar, beat + 3 + k / 8, x, 1, v * 1.2)


def _tranh(s, sp, p):     # the dan tranh: plucks with bends, a run down at each phrase's end
	for bar, beat, sym, ln in sp:
		_, pcs = chord(sym)
		v = _vel(bar, 0.26, 0.32)
		s.note("harp", bar, beat, near(pcs[0], "G3", "F#4"), 2, v)
		s.note("harp", bar, beat + 1.5, near(pcs[-1], "C4", "B4"), 1, v * 0.8, bend=(-100, 0.2))
		if bar % 4 == 3:
			for k, x in enumerate([79, 76, 74, 72, 69, 67]):
				s.note("harp", bar, beat + 2.5 + k / 4, x, 1, v * 0.7)


def _santur(s, sp, p):    # the santur's struck tremolo on the tonic and fifth
	t = int(midi(p["drone"])) + 24
	for bar in range(16):
		v = _vel(bar, 0.16, 0.2)
		for k in range(int(p["beats"] * 2)):
			s.note("harp", bar, k * 0.5, t if k % 3 != 2 else t + 7, 0.5, v * (1.0 if k % 3 == 0 else 0.75))


def _tanpura(s, sp, p):   # the tanpura's turning drone: pa, sa, sa, low sa
	t = int(midi(p["drone"]))
	for bar in range(16):
		for k, x in enumerate([t + 19, t + 24, t + 24, t + 12]):
			s.note("harp", bar, k, x, 2, _vel(bar, 0.2, 0.24))
	s.note("vc", 0, 0, t, 16 * p["beats"], 0.2)


def _oud(s, sp, p):       # plucked, on the tonic and its neighbours, a figure a bar
	t = int(midi(p["drone"])) + 12
	for bar in range(16):
		v = _vel(bar, 0.26, 0.32)
		for x, (b, d) in zip([t, t, t + 7, t + 5 if bar % 2 else t + 3], [(0, 1), (1.5, 0.5), (2, 1), (3, 1)]):
			if b < p["beats"]:
				s.note("harp", bar, b, x, d, v)


def _qanun(s, sp, p):     # the qanun's runs up to each phrase and its plucked fifths
	t = int(midi(p["drone"])) + 12
	for bar in range(16):
		v = _vel(bar, 0.24, 0.3)
		s.note("harp", bar, 0, t, 2, v)
		s.note("harp", bar, 2, t + 7, 1, v * 0.8)
		if bar % 4 == 3:
			for k, x in enumerate([t, t + 2, t + 3, t + 5, t + 7, t + 8, t + 10, t + 12]):
				s.note("harp", bar, 3 + k / 8, x, 1, v * 0.7)


def _tembur(s, sp, p):    # strummed tonic and fifth in eighths
	t = int(midi(p["drone"])) + 12
	for bar in range(16):
		for k in range(p["beats"] * 2):
			s.note("harp", bar, k * 0.5, t if k % 2 == 0 else t + 7, 0.5, _vel(bar, 0.2, 0.26) * (1.0 if k % 4 == 0 else 0.7))


def _gimbri(s, sp, p):    # the gimbri's bass riff (on the plucked double bass), tonic and the minor third and fifth
	t = int(midi(p["drone"]))
	riff = [(0, t), (1, t), (2, t + 3), (3, t), (4, t + 7), (5, t + 5)]
	for bar in range(16):
		for b, x in riff:
			s.note("cb_pizz", bar, b, x, 1, _vel(bar, 0.45, 0.55) * (1.0 if b in (0, 3) else 0.75))


def _strum(s, sp, p):     # a guitar's rasgueado (the harp swept fast) on each beat
	for bar, beat, sym, ln in sp:
		_, pcs = chord(sym)
		tones = sorted({near(pc, "E3", "D#4") for pc in pcs} | {near(pc, "E4", "D#5") for pc in pcs if near(pc, "E4", "D#5") <= midi("B4")})
		for k in range(int(ln)):
			for j, x in enumerate(tones if k != 1 else tones[::-1]):
				s.note("harp", bar, beat + k + 0.025 * j, x, 1, _vel(bar, 0.2, 0.26) * (1.0 if k == 0 else 0.75))


def _rondalla(s, sp, p):  # bandurria tremolo and guitar chords: the harp's quick repeats over the plucked strings
	for bar, beat, sym, ln in sp:
		_, pcs = chord(sym)
		v = _vel(bar, 0.18, 0.22)
		for k in range(int(ln * 2)):
			s.note("harp", bar, beat + k * 0.5, near(pcs[k % 3], "D4", "C#5"), 0.5, v)
		s.note("vla_pizz", bar, beat + 1, near(pcs[1], "F3", "E4"), 0.5, v * 1.4)
		s.note("vla_pizz", bar, beat + 2, near(pcs[2], "F3", "E4"), 0.5, v * 1.3)


def _banjo(s, sp, p):     # a gourd banjo's frail (the harp, thumbed on the off beat) over plucked strings
	for bar, beat, sym, ln in sp:
		_, pcs = chord(sym)
		v = _vel(bar, 0.24, 0.3)
		for k, (b, pc) in enumerate([(0, 0), (1, 1), (1.5, 2), (2, 0), (3, 1), (3.5, 2)]):
			s.note("harp", bar, beat + b, near(pcs[pc], "Bb3", "A4"), 0.5, v * (1.0 if b in (0, 2) else 0.75))


def _pizz(s, sp, p):      # plucked chords on the beats after the first
	for bar, beat, sym, ln in sp:
		_, pcs = chord(sym)
		for k in range(1, int(ln)):
			for pc in pcs[1:3]:
				s.note("vla_pizz", bar, beat + k, near(pc, "D4", "C#5"), 0.5, _vel(bar, 0.3, 0.36))


def _hocket(s, sp, p):    # two plucked lines that take turns, an eighth apart (the interlocking parts)
	for bar, beat, sym, ln in sp:
		_, pcs = chord(sym)
		v = _vel(bar, 0.32, 0.4)
		for k in range(int(ln * 2)):
			inst = "vln_pizz" if k % 2 == 0 else "vla_pizz"
			s.note(inst, bar, beat + k * 0.5, near(pcs[(k * 2) % 3], "G4" if k % 2 == 0 else "C4", "F#5" if k % 2 == 0 else "B4"),
					0.5, v)


def _marimba(s, sp, p):
	_arp(s, sp, "marimba", 0.5, 0.3, "C4", "C5", pat=lambda t: [t[0], t[2], t[1], t[2]])


def _ranat(s, sp, p):     # the low ranat's slower line under the high one: the marimba
	_arp(s, sp, "marimba", 1.0, 0.32, "C3", "C4", pat=lambda t: [t[0], t[1], t[2], t[1]])
	for bar in range(0, 16):
		s.note("glock", bar, 0, near(chord(sp[bar][2])[1][0], "C6", "B6"), 1, _vel(bar, 0.18, 0.22))


def _choir_pad(s, sp, p):
	v = Voices(("F4", "C5"), ("A3", "F4"), ("C3", "A3"))
	for bar, beat, sym, ln in sp:
		s.choir(bar, beat, v(sym), ln, _vel(bar, 0.3, 0.38), vowel="o")


def PCS_ONLY(name: str) -> int:
	return int(midi(name + "4")) % 12


ACC = {"pad": _pad, "swell": _swell, "drone": _drone, "dam": _dam, "harp": _harp, "harp_beats": _harp_beats,
		"harp_slow": _harp_slow, "ripple": _ripple, "kora": _kora, "krar": _krar, "koto": _koto, "gayageum": _gayageum,
		"pipa": _pipa, "tranh": _tranh, "santur": _santur, "tanpura": _tanpura, "oud": _oud, "qanun": _qanun,
		"tembur": _tembur, "gimbri": _gimbri, "strum": _strum, "rondalla": _rondalla, "banjo": _banjo, "pizz": _pizz,
		"hocket": _hocket, "marimba": _marimba, "ranat": _ranat, "choir_pad": _choir_pad}


# --- drums: (score, people, beats) ----------------------------------------------------------------------------------

def _hits(s, pattern, vel_lo=0.5, vel_hi=0.62):
	"""pattern: [(kit, beat, weight)] a bar, for all 16 bars (softer in the first eight)."""
	for bar in range(16):
		v = _vel(bar, vel_lo, vel_hi)
		for k, b, w in pattern:
			s.hit(k, bar, b, v * w)


def _p_none(s, p, beats):
	pass


def _p_frame_soft(s, p, beats):
	_hits(s, [("frame", 0, 0.7)], 0.32, 0.4)


def _p_frame44(s, p, beats):
	frame_groove(s, 0, 8, 0.35)
	frame_groove(s, 8, 8, 0.45)


def _p_pulse(s, p, beats):  # a steady soft drum on the beat, a rattle between
	_hits(s, [("frame", b, 0.7 if b == 0 else 0.55) for b in range(beats)] + [("shaker", b + 0.5, 0.6) for b in range(beats)],
			0.3, 0.38)


def _p_shaker(s, p, beats):
	_hits(s, [("shaker", b * 0.5, 0.6 if b % 2 == 0 else 0.45) for b in range(beats * 2)], 0.35, 0.42)


def _p_sea(s, p, beats):
	for bar in range(0, 16, 4):
		s.swell(bar + 4, 0, 0.35, 1)
	_hits(s, [("frame", 0, 0.5)], 0.28, 0.34)


def _p_jig(s, p, beats):    # a bodhran's jig: the frame drum's six, accents on one and four
	_hits(s, [("frame", b, 1.0 if b in (0, 3) else 0.5) for b in range(6)] + [("bd_muted", 0, 0.6), ("bd_muted", 3, 0.45)],
			0.4, 0.5)


def _p_jigsteps(s, p, beats):  # a Red River jig's feet (the muted drum's steps) and the frame on the beats
	_hits(s, [("bd_muted", b * 0.5, 0.75 if b % 2 == 0 else 0.5) for b in range(8)] + [("frame", 0, 0.6), ("frame", 2, 0.5)],
			0.36, 0.46)


def _p_castanet(s, p, beats):  # castanets (the log drum's clicks) and a tambourine
	_hits(s, [("logdrum", 0, 0.8), ("logdrum", 1, 0.5), ("logdrum", 1.5, 0.45), ("logdrum", 2, 0.6), ("tamb", 0, 0.7)],
			0.32, 0.42)


def _p_bell12(s, p, beats):  # a bell's 12-pulse pattern (the log drum), hand drums under it
	bell = [0, 2, 4, 5, 7, 9, 11]
	pat = [("logdrum", k / 3, 0.65) for k in bell] + [("conga_lo", 0, 0.9), ("conga_lo", 2, 0.75), ("conga_hi", 4 / 3, 0.6),
			("conga_hi", 10 / 3, 0.6), ("bongo", 1, 0.45), ("bongo", 3, 0.45)]
	_hits(s, pat, 0.42, 0.52)


def _p_hand(s, p, beats):
	hand_groove(s, 0, 8, 0.36)
	hand_groove(s, 8, 8, 0.46)
	_hits(s, [("giant_hand", 0, 0.6)], 0.4, 0.5)


def _p_hand_pulse(s, p, beats):
	hand_groove(s, 0, 16, 0.32)
	_hits(s, [("frame", 0, 0.6), ("shaker", 0.5, 0.5), ("shaker", 1.5, 0.5), ("shaker", 2.5, 0.5), ("shaker", 3.5, 0.5)],
			0.32, 0.4)


def _p_juba(s, p, beats):   # patting juba: stamps (the muted bass drum) and slaps (the bongo)
	_hits(s, [("bd_muted", 0, 0.9), ("bd_muted", 2, 0.8), ("bongo", 1, 0.7), ("bongo", 1.5, 0.5), ("bongo", 3, 0.7),
			("bongo", 3.5, 0.5)], 0.4, 0.5)


def _p_kebero(s, p, beats):  # the kebero's 6: deep on one and four, light between
	_hits(s, [("conga_lo", 0, 0.9), ("conga_lo", 3, 0.75)] + [("conga_hi", b, 0.45) for b in (1, 2, 4, 5)], 0.38, 0.48)


def _p_taiko(s, p, beats):  # sparse big drums
	for bar in range(16):
		v = _vel(bar, 0.42, 0.55)
		if bar % 2 == 0:
			s.hit("giant_drum", bar, 0, v)
		else:
			s.hit("giant_drum", bar, 2.5, v * 0.6)
			s.hit("giant_drum", bar, 3, v * 0.8)
		if bar % 4 == 3:
			for k in range(4):
				s.hit("tenor_lo", bar, 3 + k * 0.25, v * (0.4 + 0.1 * k))


def _p_gong(s, p, beats):
	for bar in range(0, 16, 4):
		s.hit("gong", bar, 0, _vel(bar, 0.32, 0.4))
	_hits(s, [("tri", 2, 0.5)], 0.25, 0.3)


def _p_janggu(s, p, beats):  # the janggu's three in triplets
	_hits(s, [("conga_lo", 0, 0.9), ("conga_hi", 1, 0.6), ("bongo", 5 / 3, 0.45), ("conga_hi", 2, 0.55),
			("bongo", 8 / 3, 0.45)], 0.38, 0.48)


def _p_tabla(s, p, beats):  # the tabla's sixteenths (the bongo) over the bayan's low strokes (the low conga)
	pat = [("bongo", k * 0.25, 0.6 if k % 4 == 0 else 0.35) for k in range(16)] + [("conga_lo", 0, 0.9),
			("conga_lo", 2.5, 0.7), ("conga_lo", 3, 0.6)]
	_hits(s, pat, 0.34, 0.44)


def _p_woodblock(s, p, beats):
	_hits(s, [("logdrum", b, 0.6 if b == 0 else 0.4) for b in range(beats)], 0.28, 0.34)


def _p_ching(s, p, beats):  # the ching's open and closed strokes (the triangle), the taphon (the congas)
	_hits(s, [("tri", 0, 0.7), ("tri", 1, 0.45), ("tri", 2, 0.7), ("tri", 3, 0.45), ("conga_lo", 0, 0.8),
			("conga_hi", 1.5, 0.55), ("conga_lo", 2, 0.7)], 0.32, 0.4)


def _p_rebana(s, p, beats):
	_hits(s, [("frame", 0, 0.8), ("frame", 1.5, 0.55), ("frame", 2, 0.7), ("frame", 3, 0.6), ("tamb", 1, 0.5),
			("tamb", 3, 0.5)], 0.36, 0.46)
	for bar in range(0, 16, 2):
		s.hit("gong", bar, 0, _vel(bar, 0.26, 0.32))


def _p_logdrums(s, p, beats):
	_hits(s, [("logdrum", b * 0.5, 0.75 if b in (0, 3, 6) else 0.45) for b in range(8)] + [("giant_hand", 0, 0.7)],
			0.4, 0.5)


def _p_maqsum(s, p, beats):  # dum tek - tek dum - tek -  (the low and high congas), the riq (tambourine) in eighths
	_hits(s, [("conga_lo", 0, 0.95), ("conga_hi", 0.5, 0.6), ("conga_hi", 1.5, 0.6), ("conga_lo", 2, 0.85),
			("conga_hi", 3, 0.65)] + [("tamb", b * 0.5, 0.35) for b in range(8)], 0.4, 0.5)


def _p_saidi(s, p, beats):  # dum tek - dum dum - tek -
	_hits(s, [("conga_lo", 0, 0.95), ("conga_hi", 0.5, 0.6), ("conga_lo", 1.5, 0.85), ("conga_lo", 2, 0.85),
			("conga_hi", 3, 0.65)] + [("tamb", b * 0.5, 0.35) for b in range(8)], 0.4, 0.5)


def _p_wahda(s, p, beats):
	_hits(s, [("conga_lo", 0, 0.9), ("conga_hi", 2, 0.5), ("conga_hi", 3, 0.5)] + [("tamb", b * 0.5, 0.3) for b in range(8)],
			0.36, 0.44)


def _p_mehter(s, p, beats):  # the mehter: the davul's dum (the big bass drum) and tek, cymbals, the kos's boom
	_hits(s, [("bd_big", 0, 0.9), ("bd_big", 2, 0.75), ("tenor_hi", 1.5, 0.6), ("tenor_hi", 3.5, 0.6)], 0.6, 0.75)
	for bar in range(0, 16, 2):
		s.hit("cym", bar, 0, _vel(bar, 0.55, 0.65))
		s.hit("giant_drum", bar, 0, _vel(bar, 0.6, 0.72))


def _p_tombak(s, p, beats):  # the tombak's 6/8 and a daf's stroke
	_hits(s, [("conga_lo", 0, 0.9), ("conga_hi", 2, 0.6), ("conga_hi", 3, 0.65), ("conga_lo", 4, 0.6), ("conga_hi", 5, 0.5),
			("frame", 0, 0.6)], 0.38, 0.48)


def _p_daf(s, p, beats):    # the daf's big frame and its rings
	_hits(s, [("frame", 0, 1.0), ("frame", 0.75, 0.55), ("frame", 1.5, 0.7), ("frame", 2, 0.85), ("frame", 2.75, 0.55),
			("frame", 3.5, 0.65)] + [("tamb", b, 0.5) for b in (0, 1.5, 2, 3.5)], 0.42, 0.52)


def _p_bendir(s, p, beats):  # the bendir's 6/8, hand claps (the tambourine) on the off strokes
	_hits(s, [("frame", 0, 1.0), ("frame", 3, 0.9), ("conga_hi", 2, 0.55), ("conga_hi", 5, 0.55), ("tamb", 2, 0.6),
			("tamb", 5, 0.6)], 0.42, 0.52)


def _p_tar68(s, p, beats):
	_hits(s, [("frame", 0, 0.9), ("conga_hi", 2, 0.5), ("frame", 3, 0.7), ("conga_lo", 4, 0.55), ("tamb", 5, 0.4)],
			0.36, 0.46)


def _p_habanera(s, p, beats):  # the tresillo (3+3+2) in the low conga, the bongo and tambourine between
	_hits(s, [("conga_lo", 0, 0.9), ("conga_lo", 1.5, 0.75), ("conga_lo", 3, 0.8), ("bongo", 1, 0.45), ("bongo", 2, 0.5),
			("bongo", 2.5, 0.45), ("tamb", 0.5, 0.4), ("tamb", 2.5, 0.4)], 0.38, 0.48)


PERC = {"none": _p_none, "frame_soft": _p_frame_soft, "frame44": _p_frame44, "pulse": _p_pulse, "shaker": _p_shaker,
		"sea": _p_sea, "jig": _p_jig, "jigsteps": _p_jigsteps, "castanet": _p_castanet, "bell12": _p_bell12, "hand": _p_hand,
		"hand_pulse": _p_hand_pulse, "juba": _p_juba, "kebero": _p_kebero, "taiko": _p_taiko, "gong": _p_gong,
		"janggu": _p_janggu, "tabla": _p_tabla, "woodblock": _p_woodblock, "ching": _p_ching, "rebana": _p_rebana,
		"logdrums": _p_logdrums, "maqsum": _p_maqsum, "saidi": _p_saidi, "wahda": _p_wahda, "mehter": _p_mehter,
		"tombak": _p_tombak, "daf": _p_daf, "bendir": _p_bendir, "tar68": _p_tar68, "habanera": _p_habanera}


# --- the bass -------------------------------------------------------------------------------------------------------

def _bass(s, sp, p):
	kind = p["bass"]
	beats = p["beats"]
	if kind == "pizz":
		bass_pulse(s, sp, "cb_pizz", lambda b: _vel(b, 0.45, 0.55), "E2", "D#3",
				beats=(0, 2) if beats == 4 else (0, 3) if beats == 6 else (0,))
		sub_bass(s, sp, lambda b: _vel(b, 0.22, 0.3))
	elif kind == "sub":
		sub_bass(s, sp, lambda b: _vel(b, 0.3, 0.38))
	elif kind == "sub_drone":
		t = int(midi(p["drone"])) - 12
		while t > midi("B1"):
			t -= 12
		for bar in range(0, 16, 4):
			s.note("sub", bar, 0, t, 4 * beats, _vel(bar, 0.3, 0.36))
	elif kind == "ost" and not p.get("drone"):   # a riff on each chord: root and fifth by turns, every beat
		bass_pulse(s, sp, "cb_pizz", lambda b: _vel(b, 0.42, 0.52), "E2", "D#3", beats=tuple(range(beats)), length=0.8)
		sub_bass(s, sp, lambda b: _vel(b, 0.22, 0.3))
	elif kind == "ost":     # the oud's or bass's riff on the tonic and fifth, each beat
		t = int(midi(p["drone"])) - 12 if midi(p["drone"]) >= midi("E2") + 12 else int(midi(p["drone"]))
		for bar in range(16):
			for b in range(beats):
				s.note("cb_pizz", bar, b, t if b % 2 == 0 else t + 7, 1, _vel(bar, 0.42, 0.52) * (1.0 if b == 0 else 0.75))
		sub_bass(s, [(b, 0, _drone_chord(p["drone"]), beats) for b in range(16)], lambda b: _vel(b, 0.2, 0.28))
	elif kind == "tresillo":
		prev = None
		for bar, beat, sym, ln in sp:
			r = bass(sym, "E2", "D#3", prev)
			prev = r
			_, pcs = chord(sym)
			for b, x in ((0, r), (1.5, r), (3, near(pcs[2], "E2", "D#3", r))):
				s.note("cb_pizz", bar, beat + b, x, 0.75, _vel(bar, 0.45, 0.55))
		sub_bass(s, sp, lambda b: _vel(b, 0.22, 0.3))
