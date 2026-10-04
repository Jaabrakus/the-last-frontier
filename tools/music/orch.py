#!/usr/bin/env python3
"""The game's orchestra (user 2026-10-03, a soundtrack like Shadow of the Colossus's): Versilian Studios' VSCO 2
Community Edition (CC0; tools/music/SOURCE.md) played by a small sampler, a synthesized choir (choir.py) and a concert
hall (a convolution reverb). The cues (tools/music/cues/) write their notes into a Score; render() plays it.

The samples (3 GB) stay out of the repo: VSCO=<folder>, by default ~/Downloads/VSCO-2-CE (tools/music/SOURCE.md says
where to get them). Their file names carry the note (most a C3 = middle C convention: KITS' `oct`), the velocity layer
(v1 the softest, or p / mf / f) and the round robin.

    s = Score(bpm, beats=4)                    the bar grid; s.tempo(bar, bpm), s.rit(bar0, bar1, bpm) change it
    s.note(inst, bar, beat, pitch, beats, vel) a note: pitch "D4" (C4 = middle C) or midi; vel 0..1, or (v0, v1),
                                               or [(fraction, v), ...] for a swell
    s.chord(inst, bar, beat, pitches, beats, vel)
    s.line(inst, bar, [(beat, pitch, beats[, vel]), ...], vel, legato=True)   a phrase: each note after the first
                                               slurred in (its attack skipped, crossfaded from the last)
    s.hit(inst, bar, beat, vel)                unpitched percussion (and a swell placed to peak at its time)
    s.choir(bar, beat, pitches, beats, vel, vowel="a")
    render(s) -> (n, 2) float                  the mix with the hall, at SR

Levels: each sample's loudness is measured once (cached in the sample folder) so a velocity is a loudness: top_db at
1, range_db lower at 0; the layer it picks gives only the timbre.
"""
from __future__ import annotations

import atexit
import fnmatch
import json
import math
import os
import re
import sys
import wave
from dataclasses import dataclass, field

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sfx"))
import dsp  # noqa: E402

SR = 44100
VSCO = os.path.expanduser(os.environ.get("VSCO", "~/Downloads/VSCO-2-CE"))
## The tuning (user 2026-10-03: "redo the music in 432 hz"): A4 in Hz. The samples were recorded at A = 440; every pitched
## note is played this much lower (432: 31.8 cents); the unpitched percussion stays as recorded. A4=<Hz> overrides.
A4 = float(os.environ.get("A4", "432"))
TUNE = A4 / 440.0

PCS = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8,
		"Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11, "Cb": 11}
DYN = {"ppp": 0, "pp": 1, "p": 2, "mp": 3, "mf": 4, "f": 5, "ff": 6, "fff": 7}


def midi(p) -> float:
	"""A pitch: a number (midi) or a name, C4 = 60 ("Bb3", "F#5")."""
	if isinstance(p, (int, float)):
		return float(p)
	m = re.fullmatch(r"([A-G][b#]?)(-?\d)", p)
	if not m:
		raise ValueError(f"not a pitch: {p!r}")
	return float(PCS[m.group(1)] + 12 * (int(m.group(2)) + 1))


# --- the kits ------------------------------------------------------------------------------------------------------
# dir: under VSCO; match: a glob on the file name; oct: semitones from the name's note to the sounding one
# (C3 = middle C names: 12); kind: "sus" (held, looped past its end), "short" (rings out), "perc" (unpitched).
# top_db: RMS dBFS at vel 1; range_db: how much softer at vel 0; pan -1..1; width (the sample's stereo, 0 mono);
# send: to the hall; rel: release (s); slur: the attack skipped on a slurred note (s); uni: copies layered (a section
# from soloists: detune cents, spread s); max: the longest a short note rings (s).
_S = dict(kind="sus", top_db=-17.0, range_db=20.0, width=0.7, send=0.32, rel=0.45, slur=0.09, max=4.0)
_B = dict(_S, top_db=-17.0, range_db=24.0, send=0.42, rel=0.35, slur=0.07, width=0.5)
_W = dict(_S, top_db=-21.0, range_db=16.0, send=0.36, rel=0.3, slur=0.06, width=0.4)
_SH = dict(kind="short", top_db=-18.0, range_db=18.0, width=0.7, send=0.3, rel=0.12, slur=0.0, max=2.5)
_P = dict(kind="perc", top_db=-16.0, range_db=22.0, width=0.8, send=0.4, rel=0.3, slur=0.0, max=8.0)

KITS = {
	# strings: sections (violins, violas, cellos) and the solo double bass (layered into a section)
	"vln": dict(_S, dir="Strings/Violin Section/susVib", oct=12, pan=-0.45),
	"vln_trem": dict(_S, dir="Strings/Violin Section/Trem", oct=12, pan=-0.45, top_db=-19.0),
	"vln_spic": dict(_SH, dir="Strings/Violin Section/Spic", oct=12, pan=-0.45, top_db=-19.0),
	"vln_pizz": dict(_SH, dir="Strings/Violin Section/Pizz", oct=12, pan=-0.45, top_db=-21.0, max=3.0),
	"vla": dict(_S, dir="Strings/Viola Section/susvib", oct=12, pan=0.12, top_db=-18.5),
	"vla_trem": dict(_S, dir="Strings/Viola Section/trem", oct=12, pan=0.12, top_db=-20.0),
	"vla_spic": dict(_SH, dir="Strings/Viola Section/spic", oct=12, pan=0.12, top_db=-20.0),
	"vla_pizz": dict(_SH, dir="Strings/Viola Section/pizz", oct=12, pan=0.12, top_db=-22.0, max=3.0),
	"vc": dict(_S, dir="Strings/Cello Section/susvib", oct=12, pan=0.38, top_db=-17.0),
	"vc_trem": dict(_S, dir="Strings/Cello Section/trem", oct=12, pan=0.38, top_db=-19.0),
	"vc_spic": dict(_SH, dir="Strings/Cello Section/spic", oct=12, pan=0.38, top_db=-17.5),
	"vc_pizz": dict(_SH, dir="Strings/Cello Section/pizzT", oct=12, pan=0.38, top_db=-20.0, max=3.5),
	"cb": dict(_S, dir="Strings/Solo Contrabass/SusVib", oct=12, pan=0.55, top_db=-18.0, uni=(3, 9.0, 0.018)),
	"cb_nv": dict(_S, dir="Strings/Solo Contrabass/SusNV", oct=12, pan=0.55, top_db=-18.0, uni=(3, 9.0, 0.018)),
	"cb_spic": dict(_SH, dir="Strings/Solo Contrabass/Spic", oct=12, pan=0.55, top_db=-18.0, uni=(2, 7.0, 0.01)),
	"cb_pizz": dict(_SH, dir="Strings/Solo Contrabass/Pizz", oct=12, pan=0.55, top_db=-19.0, max=4.0),
	"cb_trem": dict(_S, dir="Strings/Solo Contrabass/Trem", oct=12, pan=0.55, top_db=-20.0, uni=(2, 8.0, 0.015)),
	"solo_vln": dict(_S, dir="Strings/Solo Violin/Arco Vib", oct=0, pan=-0.2, top_db=-20.0, width=0.4, send=0.38),
	"harp": dict(_SH, dir="Strings/Harp", oct=0, pan=-0.6, top_db=-21.0, range_db=14.0, max=3.5, send=0.36),
	# brass
	"hn": dict(_B, dir="Brass/F Horn/sus", oct=12, pan=-0.22, top_db=-17.5, uni=(2, 7.0, 0.02), send=0.5),
	"hn_solo": dict(_B, dir="Brass/F Horn/sus", oct=12, pan=-0.22, top_db=-19.0, send=0.5),
	"hn_stac": dict(_SH, dir="Brass/F Horn/stac", oct=12, pan=-0.22, top_db=-17.5, uni=(2, 7.0, 0.012), send=0.48),
	"tpt": dict(_B, dir="Brass/Trumpet/sus", oct=12, pan=0.12, top_db=-18.5, uni=(2, 5.0, 0.015)),
	"tpt_solo": dict(_B, dir="Brass/Trumpet/susvib", oct=12, pan=0.12, top_db=-20.0),
	"tpt_stac": dict(_SH, dir="Brass/Trumpet/stac", oct=12, pan=0.12, top_db=-18.5, uni=(2, 5.0, 0.01), send=0.42),
	"tbn": dict(_B, dir="Brass/OldTrombone/Sustain", oct=12, pan=0.32, top_db=-17.0, uni=(2, 6.0, 0.02)),
	"tbn_stac": dict(_SH, dir="Brass/OldTrombone/Short", oct=12, pan=0.32, top_db=-17.0, uni=(2, 6.0, 0.01),
			send=0.42),
	"tuba": dict(_B, dir="Brass/Tuba/sus", oct=12, pan=0.45, top_db=-18.0),
	"tuba_stac": dict(_SH, dir="Brass/Tuba/stac", oct=12, pan=0.45, top_db=-18.0, send=0.4),
	# woodwinds
	"fl": dict(_W, dir="Woodwinds/Flute/susvib", oct=12, pan=-0.12),
	"fl_nv": dict(_W, dir="Woodwinds/Flute/susNV", oct=12, pan=-0.12),
	"fl_stac": dict(_SH, dir="Woodwinds/Flute/stac", oct=12, pan=-0.12, top_db=-22.0, width=0.4),
	"picc": dict(_W, dir="Woodwinds/Piccolo/Sus", oct=12, pan=-0.15, top_db=-23.0),
	"ob": dict(_W, dir="Woodwinds/Oboe/Vib", oct=12, pan=0.04),
	"cl": dict(_W, dir="Woodwinds/Clarinet/susLong", oct=12, pan=-0.18),
	"bsn": dict(_W, dir="Woodwinds/Bassoon/sus", oct=12, pan=0.18, top_db=-20.0),
	"bsn_stac": dict(_SH, dir="Woodwinds/Bassoon/stac", oct=12, pan=0.18, top_db=-20.0, width=0.4),
	# keys: Ivy Audio's upright piano (in VSCO 2 CE), its dampers down at the note's end (damp) unless pedalled longer
	"piano": dict(_SH, dir="Keys/Upright Piano", match="Player_dyn*", pan=-0.08, width=0.85, top_db=-18.0,
			range_db=24.0, max=7.0, send=0.26, rel=0.3, damp=True),
	"marimba": dict(_SH, dir="Percussion/Marimba", oct=12, pan=0.2, top_db=-20.0, range_db=14.0, max=3.0, send=0.32),
	"xylo": dict(_SH, dir="Percussion/Xylo", oct=12, pan=-0.2, top_db=-22.0, range_db=12.0, max=1.5, send=0.32),
	# pitched percussion
	"glock": dict(_SH, dir="Percussion/Glock", oct=12, pan=-0.3, top_db=-25.0, range_db=12.0, max=6.0, send=0.4),
	"timp": dict(_P, dir="Percussion/Timpani", match="Timpani*_Hit_*", kind="short", pan=-0.1, top_db=-14.0,
			range_db=24.0, max=7.0, send=0.42),
	"timp_roll": dict(_P, dir="Percussion/Timpani/Rolls", kind="sus", pan=-0.1, top_db=-16.0, range_db=26.0,
			send=0.42, rel=0.6, slur=0.0),
	# unpitched percussion
	"bd": dict(_P, dir="Percussion", match="BDrumNewhit_*", pan=0.05, top_db=-14.0, max=5.0, send=0.45),
	"snare": dict(_P, dir="Percussion", match="Snare2-HitSN_*", pan=0.2, top_db=-19.0, max=2.0, send=0.35),
	"snare_roll": dict(_P, dir="Percussion", match="Snare2-rollSN_*", kind="sus", pan=0.2, top_db=-21.0, rel=0.25),
	"cym": dict(_P, dir="Percussion", match="cymbal-crash1_*", pan=0.3, top_db=-20.0, max=7.0, send=0.35),
	"cym_swell": dict(_P, dir="Percussion", match="susCymb1-cresc-*", pan=-0.25, top_db=-22.0, range_db=10.0,
			max=12.0, send=0.35),
	"sus_cym": dict(_P, dir="Percussion", match="susCymb1-hit_*", pan=-0.25, top_db=-22.0, max=8.0, send=0.35),
	"gong": dict(_P, dir="Percussion", match="gongHit_*", pan=0.0, top_db=-17.0, max=12.0, send=0.4),
	"tri": dict(_P, dir="Percussion", match="Triangle3-Hit_*", pan=0.4, top_db=-28.0, max=4.0, send=0.35),
	# more drums (user 2026-10-03: "add more drums and bass"): VSCO 1's big drums and hand drums
	"giant_drum": dict(_P, dir="VSCO 1 Percussion/drums/other/ethnic/giant/mallet", pan=0.0, top_db=-13.0,
			max=5.0, send=0.45),
	"giant_hand": dict(_P, dir="VSCO 1 Percussion/drums/other/ethnic/giant/hand", match="*hit*", pan=-0.15,
			top_db=-16.0, max=3.0, send=0.4),
	"bd_big": dict(_P, dir="VSCO 1 Percussion/drums/bass", match="bdrum_*", exclude=["*muted*", "*roll*", "*special*"],
			pan=0.05, top_db=-14.0, max=5.0, send=0.42),
	"bd_muted": dict(_P, dir="VSCO 1 Percussion/drums/bass", match="bdrum_muted_*", pan=0.05, top_db=-16.0, max=2.0,
			send=0.35),
	"tenor_lo": dict(_P, dir="VSCO 1 Percussion/drums/tenor/tenor_lower", pan=-0.2, top_db=-16.0, max=2.5, send=0.4),
	"tenor_hi": dict(_P, dir="VSCO 1 Percussion/drums/tenor/tenor_higher", pan=0.2, top_db=-17.0, max=2.0, send=0.4),
	"frame": dict(_P, dir="Miscellania Raw/Misc 2", match="rtomtom_frame*", exclude=["*roll*"], pan=-0.1, top_db=-18.0,
			max=2.0, send=0.35),
	"conga_lo": dict(_P, dir="VSCO 1 Percussion/drums/other/ethnic/congo/open", match="ethnicLowOpen*", pan=0.25,
			top_db=-18.0, max=1.5, send=0.3),
	"conga_hi": dict(_P, dir="VSCO 1 Percussion/drums/other/ethnic/congo/open", match="ethnicHighOpen*", pan=0.3,
			top_db=-19.0, max=1.2, send=0.3),
	"bongo": dict(_P, dir="VSCO 1 Percussion/drums/other/Bongos", pan=-0.3, top_db=-20.0, max=1.0, send=0.3),
	"logdrum": dict(_P, dir="VSCO 1 Percussion/varWood/log_drum", pan=0.15, top_db=-19.0, max=1.5, send=0.35),
	"tamb": dict(_P, dir="Miscellania Raw/Misc 2", match="tamb3_?.wav", pan=0.35, top_db=-24.0, max=1.5, send=0.3),
	"shaker": dict(_P, dir="VSCO 1 Percussion/varWood", match="maraca?.wav", pan=-0.35, top_db=-26.0, max=0.8,
			send=0.25),
	"sleigh": dict(_P, dir="Miscellania Raw/Misc 2", match="sleighbell1_hit_*", pan=0.4, top_db=-26.0, max=1.5,
			send=0.3),
}
# The timpani are five drums at fixed pitches (measured: the strongest mode of each); a note takes the nearest.
TIMP_PITCH = {"Timpani1": 41.5, "Timpani2": 53.5, "Timpani3": 56.3, "Timpani4": 58.9, "Timpani5": 61.3}


@dataclass
class Zone:
	path: str
	note: float
	layer: int        # rank among the kit's layer tokens, softest 0
	rr: int


@dataclass
class Kit:
	key: str
	spec: dict
	zones: list = field(default_factory=list)
	layers: list = field(default_factory=list)      # the layer tokens' ranks present, sorted
	_rr: int = 0

	def pick(self, note: float, li: int, other: int = 0) -> Zone:
		"""The zone for `note` at layer index `li` (into self.layers); `other` takes the next round robin."""
		want = self.layers[min(max(li, 0), len(self.layers) - 1)]
		notes = sorted({z.note for z in self.zones})
		best = min(notes, key=lambda n: (abs(n - note), n < note))
		cand = [z for z in self.zones if z.note == best]
		layers = sorted({z.layer for z in cand}, key=lambda l: (abs(l - want), -l))
		cand = [z for z in cand if z.layer == layers[0]]
		cand.sort(key=lambda z: z.rr)
		self._rr += 1
		return cand[(self._rr + other) % len(cand)]


_kits: dict = {}
_audio: dict = {}
_audio_bytes = 0
_AUDIO_CAP = 3_500_000_000
_LEVELS = os.path.join(VSCO, ".frontier_zone_levels.json")
_zdb = None
_zdb_dirty = False


def _parse(fname: str, oct_: int):
	parts = os.path.splitext(fname)[0].replace("-", "_").split("_")
	note, layer, rr = None, 0, 0
	for p in parts:
		m = re.fullmatch(r"([A-G]#?)(-?\d)", p)
		if m:
			note = PCS[m.group(1)] + 12 * (int(m.group(2)) + 1) + oct_
			continue
		m = re.fullmatch(r"[vV](\d+)", p)
		if m:
			layer = int(m.group(1))
			continue
		if p.lower() in DYN:
			layer = DYN[p.lower()]
			continue
		m = re.fullmatch(r"(?:rr|RR)(\d+)", p)
		if m:
			rr = int(m.group(1))
			continue
		if re.fullmatch(r"\d", p):
			rr = int(p)
	return note, layer, rr


def kit(key: str) -> Kit:
	if key in _kits:
		return _kits[key]
	spec = KITS[key]
	d = os.path.join(VSCO, spec["dir"])
	if not os.path.isdir(d):
		raise SystemExit(f"no samples at {d}: get VSCO 2 CE (tools/music/SOURCE.md) or set VSCO=<folder>")
	k = Kit(key, spec)
	for f in sorted(os.listdir(d)):
		if not f.lower().endswith(".wav") or not fnmatch.fnmatch(f, spec.get("match", "*")):
			continue
		if any(fnmatch.fnmatch(f, x) for x in spec.get("exclude", [])):
			continue
		note, layer, rr = _parse(f, spec.get("oct", 0))
		if key.startswith("timp"):
			note = TIMP_PITCH[f.split("_")[0]]
		elif key == "piano":     # Player_dyn<layer>_rr1_<index>.wav: index i is key 21 + 2i (MappingChart.txt), 44 is 108
			m = re.search(r"dyn(\d+)_rr\d+_(\d{3})", f)
			idx = int(m.group(2))
			note, layer = (108 if idx >= 44 else 21 + 2 * idx), int(m.group(1))
		elif key == "cym_swell":   # Short < Median < Long: the layer is the length
			layer = {"Short": 0, "Median": 1, "Long": 2}[re.search(r"cresc-(\w+?)_", f).group(1)]
		if note is None:
			note = 60.0
		k.zones.append(Zone(os.path.join(d, f), float(note), layer, rr))
	if not k.zones:
		raise SystemExit(f"kit {key}: no files in {d} matching {spec.get('match', '*')}")
	k.layers = sorted({z.layer for z in k.zones})
	_kits[key] = k
	return k


def _read(path: str) -> np.ndarray:
	"""A sample as float32 (n, 2) (16, 24 or 32-bit PCM; mono doubled), cached."""
	global _audio_bytes
	a = _audio.get(path)
	if a is not None:
		return a
	with wave.open(path, "rb") as w:
		ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
		b = w.readframes(n)
	if sw == 2:
		x = np.frombuffer(b, "<i2").astype(np.float32) / 32768.0
	elif sw == 3:
		u = np.frombuffer(b, np.uint8).reshape(-1, 3).astype(np.int32)
		v = u[:, 0] | (u[:, 1] << 8) | (u[:, 2] << 16)
		x = (np.where(v >= 1 << 23, v - (1 << 24), v)).astype(np.float32) / float(1 << 23)
	elif sw == 4:
		x = np.frombuffer(b, "<i4").astype(np.float32) / float(1 << 31)
	else:
		x = (np.frombuffer(b, np.uint8).astype(np.float32) - 128.0) / 128.0
	x = x.reshape(-1, ch)
	if ch == 1:
		x = np.repeat(x, 2, axis=1)
	elif ch > 2:
		x = x[:, :2]
	if sr != SR:
		x = _resample(x, sr / SR, 0.0, int(len(x) * SR / sr))
	# the onset: drop the silence before it (a little kept), so a note sounds on its time
	env = np.abs(x).max(axis=1)
	thr = max(float(env.max()) * 0.02, 1e-4)
	i0 = int(np.argmax(env > thr))
	x = np.ascontiguousarray(x[max(i0 - int(0.004 * SR), 0):])
	_audio[path] = x
	_audio_bytes += x.nbytes
	if _audio_bytes > _AUDIO_CAP:
		for p in list(_audio)[: len(_audio) // 3]:
			_audio_bytes -= _audio.pop(p).nbytes
	return x


def _zone_db(k: Kit, z: Zone) -> float:
	"""A zone's own loudness (dB RMS): its loudest 1.5 s (a held kind) or 0.25 s (a short one or a hit), measured once
	and kept in the sample folder."""
	global _zdb, _zdb_dirty
	if _zdb is None:
		try:
			with open(_LEVELS) as f:
				_zdb = json.load(f)
		except (OSError, ValueError):
			_zdb = {}
		atexit.register(_save_levels)
	w_s = 1.5 if k.spec["kind"] == "sus" else 0.25
	key = f"{os.path.relpath(z.path, VSCO)}|{w_s}"
	if key not in _zdb:
		x = _read(z.path).mean(axis=1)
		w = int(w_s * SR)
		if len(x) > w:
			c = np.cumsum(np.concatenate([[0.0], x.astype(np.float64) ** 2]))
			p = (c[w:] - c[:-w]) / w
			ms = float(p.max())
		else:
			ms = float(np.mean(x.astype(np.float64) ** 2))
		_zdb[key] = 10.0 * math.log10(ms + 1e-12)
		_zdb_dirty = True
	return _zdb[key]


def _save_levels() -> None:
	if not _zdb_dirty:
		return
	try:
		with open(_LEVELS, "w") as f:
			json.dump(_zdb, f, indent=0, sort_keys=True)
	except OSError:
		pass


# --- the sampler ---------------------------------------------------------------------------------------------------

def _resample(a: np.ndarray, ratio, start: float, n: int) -> np.ndarray:
	"""`n` frames of `a` read from `start` at `ratio` frames a frame (a number, or an array a frame): cubic."""
	if np.ndim(ratio) == 0:
		pos = start + np.arange(n, dtype=np.float64) * ratio
	else:
		pos = start + np.concatenate([[0.0], np.cumsum(ratio[:-1], dtype=np.float64)])
	m = len(a)
	i = np.floor(pos).astype(np.int64)
	f = (pos - i).astype(np.float32)[:, None]
	ok = (i >= 1) & (i < m - 2)
	out = np.zeros((n, a.shape[1]), np.float32)
	ii = i[ok]
	ff = f[ok]
	p0, p1, p2, p3 = a[ii - 1], a[ii], a[ii + 1], a[ii + 2]
	out[ok] = p1 + 0.5 * ff * (p2 - p0 + ff * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3 + ff * (3.0 * (p1 - p2) + p3 - p0)))
	head = (i == 0) & (m > 1)
	out[head] = a[0] * (1.0 - f[head]) + a[1] * f[head]
	return out


def _extend(a: np.ndarray, need: int) -> np.ndarray:
	"""A held sample made `need` frames long: its middle looped, each pass crossfaded (equal power) into the last."""
	n = len(a)
	if n >= need:
		return a
	A, B = int(n * 0.3), int(n * 0.82)
	xf = min(int(0.35 * SR), (B - A) // 3)
	th = np.linspace(0.0, math.pi / 2.0, xf, dtype=np.float32)[:, None]
	fi, fo = np.sin(th), np.cos(th)
	out = [a[:B - xf]]
	tail = a[B - xf:B]
	have = B - xf
	k = 0
	while have < need:
		# each pass from a slightly different place, so the loop does not drone at one rate
		s = A + (k * 7919) % max(1, (B - A) // 4)
		seg = a[s:B]
		out.append(tail * fo + seg[:xf] * fi)
		out.append(seg[xf:len(seg) - xf])
		tail = seg[len(seg) - xf:]
		have += len(seg) - xf
		k += 1
	out.append(tail)
	return np.concatenate(out)[:need]


def _curve(vel, n: int) -> np.ndarray:
	"""A velocity over n frames: a number, (v0, v1) a line, or [(fraction, v), ...] points."""
	if isinstance(vel, (int, float)):
		return np.full(n, float(vel), np.float32)
	pts = list(vel)
	if len(pts) == 2 and all(isinstance(p, (int, float)) for p in pts):
		pts = [(0.0, pts[0]), (1.0, pts[1])]
	xs = np.array([p[0] for p in pts], np.float32)
	ys = np.array([p[1] for p in pts], np.float32)
	return np.interp(np.linspace(0.0, 1.0, n, dtype=np.float32), xs, ys).astype(np.float32)


def _vmax(vel) -> float:
	if isinstance(vel, (int, float)):
		return float(vel)
	pts = list(vel)
	if len(pts) == 2 and all(isinstance(p, (int, float)) for p in pts):
		return float(max(pts))
	return float(max(p[1] for p in pts))


def _db_of(spec: dict, v: np.ndarray) -> np.ndarray:
	return spec["top_db"] - spec["range_db"] * (1.0 - np.clip(v, 0.0, 1.0)) ** 1.15


def play(key: str, pitch, dur: float, vel, slur: bool = False, cents: float = 0.0, other: int = 0,
		bend: tuple | None = None) -> np.ndarray:
	"""One note of a kit: (n, 2) float32, its release (or ring) included. `bend`: (cents at the start, seconds to
	settle) for a scoop."""
	k = kit(key)
	sp = k.spec
	note = midi(pitch) if pitch is not None else 60.0
	vm = _vmax(vel)
	li = min(int(vm * len(k.layers) * 0.999), len(k.layers) - 1)
	z = k.pick(note, li, other)
	a = _read(z.path)
	ratio = TUNE * 2.0 ** ((note - z.note + cents / 100.0) / 12.0) if sp["kind"] != "perc" else 2.0 ** (cents / 1200.0)
	if sp["kind"] == "sus":
		n = int((dur + sp["rel"]) * SR)
	else:
		n = int(min(len(a) / ratio, sp["max"] * SR))
		if sp.get("damp"):
			n = min(n, int((dur + sp["rel"]) * SR))
	skip = int(sp["slur"] * SR) if slur else 0
	need = int(skip + n * ratio) + 8
	if sp["kind"] == "sus" and need > len(a):
		a = _extend(a, need)
	if bend:
		c0, t0 = bend
		t = np.arange(n) / SR
		r = ratio * 2.0 ** ((c0 / 1200.0) * np.exp(-t / max(t0, 1e-3)))
		y = _resample(a, r, float(skip), n)
	else:
		y = _resample(a, ratio, float(skip), n)
	# the level: the velocity's loudness over the layer's own
	g_db = _db_of(sp, _curve(vel, n)) - _zone_db(k, z) + sp.get("gain_db", 0.0)
	g = (10.0 ** (g_db / 20.0)).astype(np.float32)
	if slur:
		fi = min(int(0.05 * SR), n)
		g[:fi] *= np.clip(np.sin(np.linspace(0.0, math.pi / 2.0, fi, dtype=np.float32)), 0.0, 1.0)
	if sp["kind"] == "sus":
		r0 = int(dur * SR)
		rn = n - r0
		if rn > 0:
			g[r0:] *= np.clip(np.cos(np.linspace(0.0, math.pi / 2.0, rn, dtype=np.float32)), 0.0, 1.0) ** 1.5
	elif sp.get("damp") and n < len(a) / ratio - 1:
		r0 = min(int(dur * SR), n - 1)
		g[r0:] *= np.clip(np.cos(np.linspace(0.0, math.pi / 2.0, n - r0, dtype=np.float32)), 0.0, 1.0) ** 1.2
	else:
		cut = len(a) / ratio > n + 1
		end = min(n, int(min(0.6, n / SR / 3.0) * SR) if cut else int(4.0e-3 * SR))
		g[n - end:] *= np.linspace(1.0, 0.0, end, dtype=np.float32) ** (2.0 if cut else 1.0)
	return y * g[:, None]


def place(bus: np.ndarray, sig: np.ndarray, t: float, gain: float = 1.0) -> None:
	i = int(round(t * SR))
	if i < 0:
		sig = sig[-i:]
		i = 0
	if i >= len(bus) or len(sig) == 0:
		return
	m = min(len(sig), len(bus) - i)
	bus[i:i + m] += sig[:m] * gain


def stage(sig: np.ndarray, pan: float, width: float) -> np.ndarray:
	"""A stereo signal narrowed to `width` and set at `pan` (equal power)."""
	mid = 0.5 * (sig[:, 0] + sig[:, 1])
	side = 0.5 * (sig[:, 0] - sig[:, 1]) * width
	a = math.pi * 0.25 * (max(-1.0, min(1.0, pan)) + 1.0)
	gl, gr = math.cos(a) * math.sqrt(2.0), math.sin(a) * math.sqrt(2.0)
	return np.stack([(mid + side) * gl, (mid - side) * gr], axis=1).astype(np.float32)


# --- the hall ------------------------------------------------------------------------------------------------------

def hall_ir(rt60: float = 2.6, pre: float = 0.024, seed: int = 7) -> np.ndarray:
	"""A concert hall's impulse response (stereo): early reflections, then a diffuse tail whose highs die sooner."""
	r = np.random.default_rng(seed)
	n = int((pre + rt60 * 1.25) * SR)
	t = np.arange(n) / SR
	ir = np.zeros((n, 2))
	bands = [(20.0, 300.0, 1.2), (300.0, 1200.0, 1.0), (1200.0, 4500.0, 0.72), (4500.0, 16000.0, 0.4)]
	for c in range(2):
		y = np.zeros(n)
		for lo, hi, k in bands:
			b = dsp.fft_band(r.standard_normal(n), lo, hi, order=2)
			y += b * np.exp(-6.91 * t / (rt60 * k))
		build = np.clip((t - pre) / 0.07, 0.0, 1.0) ** 1.5
		y *= build * (t >= pre)
		# early reflections: the walls and the stage, a few taps each side
		for j in range(14):
			dt = pre * 0.4 + r.uniform(0.004, 0.085)
			i = int(dt * SR)
			if i < n:
				y[i] += r.choice([-1.0, 1.0]) * 0.55 * math.exp(-dt / 0.06) * r.uniform(0.4, 1.0)
		ir[:, c] = y
	ir /= np.sqrt(np.sum(ir ** 2) / 2.0)
	return ir.astype(np.float32)


def convolve(x: np.ndarray, ir: np.ndarray, block: int = 1 << 17) -> np.ndarray:
	"""x (n, 2) through a stereo ir (each side its own, a little of the other crossed over): overlap-add FFT."""
	n, m = len(x), len(ir)
	nfft = 1 << int(math.ceil(math.log2(block + m - 1)))
	H = np.fft.rfft(ir, nfft, axis=0)
	cross = 0.25
	out = np.zeros((n + m, 2), np.float32)
	for s in range(0, n, block):
		seg = x[s:s + block]
		X = np.fft.rfft(seg, nfft, axis=0)
		yl = np.fft.irfft(X[:, 0] * H[:, 0] + cross * X[:, 1] * H[:, 1], nfft)
		yr = np.fft.irfft(X[:, 1] * H[:, 1] + cross * X[:, 0] * H[:, 0], nfft)
		k = min(nfft, len(out) - s)
		out[s:s + k, 0] += yl[:k]
		out[s:s + k, 1] += yr[:k]
	return out / (1.0 + cross)


# --- the score -----------------------------------------------------------------------------------------------------

class Score:
	def __init__(self, bpm: float, beats: int = 4, seed: int = 1, hall: float = 2.6, wet: float = 1.0):
		self.beats = beats
		self.events: list = []
		self.hall = hall
		self.wet = wet
		self.mix: dict = {}              # kit (or "choir") -> dB
		self.rng = np.random.default_rng(seed)
		self._tempo = [(0.0, float(bpm))]   # (beat position, bpm) from there on

	# time ------------------------------------------------------------------------------------------------
	def tempo(self, bar: float, bpm: float) -> None:
		pos = bar * self.beats
		self._tempo = [p for p in self._tempo if p[0] < pos] + [(pos, float(bpm))]

	def rit(self, bar0: float, bar1: float, bpm1: float) -> None:
		"""The tempo eased from what it is at bar0 to bpm1 at bar1, a step a beat."""
		b0 = self.bpm_at(bar0)
		steps = int(round((bar1 - bar0) * self.beats))
		for i in range(steps):
			self.tempo(bar0 + i / self.beats, b0 + (bpm1 - b0) * (i + 1) / steps)
		self.tempo(bar1, bpm1)

	def bpm_at(self, bar: float) -> float:
		pos = bar * self.beats
		return [b for p, b in self._tempo if p <= pos][-1]

	def t(self, bar: float, beat: float = 0.0) -> float:
		pos = bar * self.beats + beat
		s = 0.0
		for i, (p, b) in enumerate(self._tempo):
			nxt = self._tempo[i + 1][0] if i + 1 < len(self._tempo) else math.inf
			if pos <= p:
				break
			s += (min(pos, nxt) - p) * 60.0 / b
		return s

	def span(self, bar: float, beat: float, beats: float) -> float:
		return self.t(bar, beat + beats) - self.t(bar, beat)

	# notes ------------------------------------------------------------------------------------------------
	def _jit(self, tight: bool) -> float:
		return 0.0 if tight else float(self.rng.normal(0.0, 0.006))

	def note(self, inst: str, bar: float, beat: float, pitch, beats: float, vel=0.6, tight: bool = False,
			slur: bool = False, **kw) -> None:
		self.events.append(dict(kind="note", inst=inst, t=self.t(bar, beat) + self._jit(tight),
				dur=self.span(bar, beat, beats), pitch=pitch, vel=vel, slur=slur, **kw))

	def chord(self, inst: str, bar: float, beat: float, pitches, beats: float, vel=0.6, **kw) -> None:
		for p in pitches:
			self.note(inst, bar, beat, p, beats, vel, **kw)

	def line(self, inst: str, bar: float, notes, vel=0.6, legato: bool = True, overlap: float = 0.06, **kw) -> None:
		"""A phrase: notes (beat from `bar`'s start, pitch, beats[, vel]); a rest is a gap. Slurred notes overlap the
		last by `overlap` s."""
		prev_end = None
		for i, nt in enumerate(notes):
			b, p, d = nt[0], nt[1], nt[2]
			v = nt[3] if len(nt) > 3 else vel
			if p is None:
				prev_end = None
				continue
			slur = legato and prev_end is not None and abs(prev_end - b) < 1e-6
			t0 = self.t(bar, b)
			dur = self.span(bar, b, d)
			if legato and i + 1 < len(notes) and notes[i + 1][1] is not None and abs(notes[i + 1][0] - (b + d)) < 1e-6:
				dur += overlap
			self.events.append(dict(kind="note", inst=inst, t=t0 + (0.0 if slur else self._jit(False)), dur=dur,
					pitch=p, vel=v, slur=slur, **kw))
			prev_end = b + d

	def hit(self, inst: str, bar: float, beat: float = 0.0, vel=0.7, pitch=None, **kw) -> None:
		self.events.append(dict(kind="hit", inst=inst, t=self.t(bar, beat) + self._jit(True), dur=0.0,
				pitch=pitch, vel=vel, **kw))

	def roll(self, inst: str, bar: float, beat: float, beats: float, vel=(0.2, 0.9), pitch=None, **kw) -> None:
		"""A held roll (timpani, snare): a crescendo by default."""
		self.events.append(dict(kind="note", inst=inst, t=self.t(bar, beat), dur=self.span(bar, beat, beats),
				pitch=pitch, vel=vel, slur=False, tight=True, **kw))

	def swell(self, bar: float, beat: float, vel: float = 0.7, length: int = 1, **kw) -> None:
		"""A suspended cymbal's swell that peaks at bar/beat (length 0 short, 1 medium, 2 long)."""
		self.events.append(dict(kind="swell", inst="cym_swell", t=self.t(bar, beat), dur=0.0, pitch=None,
				vel=vel, layer=length, **kw))

	def choir(self, bar: float, beat: float, pitches, beats: float, vel=0.6, vowel: str = "a", **kw) -> None:
		for p in pitches:
			self.events.append(dict(kind="choir", inst="choir", t=self.t(bar, beat) + self._jit(False),
					dur=self.span(bar, beat, beats), pitch=p, vel=vel, vowel=vowel, **kw))

	def length(self) -> float:
		return max((e["t"] + e["dur"] for e in self.events), default=0.0)


def musicbox(m: float, vel: float, rng: np.random.Generator) -> np.ndarray:
	"""A music box's tine (synthesized): a steel reed's partials (a clamped bar's 1, 6.27, 17.55), the pin's click, a
	short ring that is shorter up high; a touch of the comb's wobble."""
	f = A4 * 2.0 ** ((m - 69.0) / 12.0)
	dur = float(np.clip(3.2 * (523.0 / f) ** 0.6, 0.9, 4.0))
	n = int(dur * SR)
	t = np.arange(n) / SR
	y = np.zeros(n)
	for ratio, amp, tau in ((1.0, 1.0, dur * 0.32), (2.0, 0.06, dur * 0.12), (6.27, 0.22, 0.09), (17.55, 0.05, 0.025)):
		if f * ratio < SR * 0.45:
			y += amp * np.sin(2 * math.pi * f * ratio * t + rng.uniform(0, 6.3)) * np.exp(-t / tau)
	y *= 1.0 + 0.04 * np.sin(2 * math.pi * rng.uniform(4.0, 6.0) * t)
	click = dsp.fft_band(rng.standard_normal(int(0.004 * SR)), 2500.0, 9000.0) * 0.25
	y[:len(click)] += click * np.linspace(1.0, 0.0, len(click))
	y *= np.clip(t / 0.0015, 0.0, 1.0)
	db = -24.0 - 14.0 * (1.0 - float(vel)) ** 1.15
	y *= 10.0 ** (db / 20.0) / (math.sqrt(float(np.mean(y[: int(0.3 * SR)] ** 2))) + 1e-9)
	return np.stack([y, y], axis=1).astype(np.float32)


def sub(m: float, dur: float, vel, rng: np.random.Generator) -> np.ndarray:
	"""The sub bass (synthesized): a sine with a little of its octave and fifth above (heard on small speakers too),
	gently rounded; a soft start, a release. Dry and centred."""
	f = A4 * 2.0 ** ((m - 69.0) / 12.0)
	rel = 0.35
	n = int((dur + rel) * SR)
	t = np.arange(n) / SR
	ph = 2 * math.pi * f * t
	y = np.sin(ph) + 0.28 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
	y = np.tanh(1.4 * y) / math.tanh(1.4)
	env = np.clip(t / 0.03, 0.0, 1.0) * np.where(t > dur, np.clip(1.0 - (t - dur) / rel, 0.0, 1.0) ** 2, 1.0)
	cv = _curve(vel, n)
	db = -17.0 - 20.0 * (1.0 - np.clip(cv, 0.0, 1.0)) ** 1.15
	y = y * env * 10.0 ** (db / 20.0) / 0.62
	return np.stack([y, y], axis=1).astype(np.float32)


def _voice(e: dict, rng: np.random.Generator) -> tuple:
	"""An event's signal (n, 2), its pan, width and send."""
	if e["inst"] == "sub":
		return sub(midi(e["pitch"]), e["dur"], e["vel"], rng), 0.0, 0.0, e.get("send", 0.04)
	if e["inst"] == "musicbox":
		return musicbox(midi(e["pitch"]), _vmax(e["vel"]), rng), e.get("pan", 0.1), 0.0, e.get("send", 0.35)
	if e["kind"] == "choir":
		import choir
		sig = choir.sing(midi(e["pitch"]), e["dur"], e["vel"], e.get("vowel", "a"), rng, attack=e.get("attack"))
		return sig, e.get("pan", choir.pan_of(midi(e["pitch"]))), 0.9, e.get("send", 0.5)
	sp = KITS[e["inst"]]
	if e["kind"] == "swell":
		k = kit("cym_swell")
		z = [z for z in k.zones if z.layer == e.get("layer", 1)][0]
		a = _read(z.path)
		peak = int(np.argmax(np.abs(a).max(axis=1)))
		g = 10.0 ** ((_db_of(sp, np.array(e["vel"])) - _zone_db(k, z)) / 20.0)
		sig = a * np.float32(g)
		e = dict(e, t=e["t"] - peak / SR)
		return sig, sp["pan"], sp["width"], sp["send"], e["t"]
	uni = e.get("uni", sp.get("uni"))
	if uni and uni[0] > 1:
		cnt, cents, spread = uni
		parts = []
		for j in range(cnt):
			c = (j / (cnt - 1) - 0.5) * 2.0 * cents + rng.normal(0.0, cents * 0.15)
			s = play(e["inst"], e["pitch"], e["dur"], e["vel"], e.get("slur", False), c + e.get("cents", 0.0), j,
					e.get("bend"))
			d = int(abs(rng.normal(0.0, spread)) * SR) if not e.get("slur") else 0
			if d:
				s = np.concatenate([np.zeros((d, 2), np.float32), s])
			parts.append(s)
		n = max(len(p) for p in parts)
		sig = np.zeros((n, 2), np.float32)
		for p in parts:
			sig[:len(p)] += p
		sig /= math.sqrt(cnt)
	else:
		sig = play(e["inst"], e["pitch"], e["dur"], e["vel"], e.get("slur", False), e.get("cents", 0.0), 0,
				e.get("bend"))
	return sig, e.get("pan", sp["pan"]), sp["width"], e.get("send", sp["send"])


def render(s: Score, tail: float = 5.0, dry_only: bool = False, verbose: bool = True) -> np.ndarray:
	n = int((s.length() + tail) * SR) + SR
	dry = np.zeros((n, 2), np.float32)
	wet = np.zeros((n, 2), np.float32)
	rng = np.random.default_rng(11)
	for i, e in enumerate(sorted(s.events, key=lambda e: e["t"])):
		out = _voice(e, rng)
		sig, pan, width, send = out[:4]
		t = out[4] if len(out) > 4 else e["t"]
		g = 10.0 ** (s.mix.get(e["inst"], 0.0) / 20.0) * e.get("gain", 1.0)
		st = stage(sig, pan, width)
		place(dry, st, t, g)
		place(wet, st, t, g * send)
		if verbose and i % 400 == 0:
			print(f"  {i}/{len(s.events)} notes", flush=True)
	if dry_only:
		return dry
	ir = hall_ir(s.hall)
	rev = convolve(wet, ir)[:n]
	return dry + rev * np.float32(0.55 * s.wet)


# --- the master ----------------------------------------------------------------------------------------------------

def loudness(x: np.ndarray) -> float:
	"""A short-term loudness's gated mean (dB): 400 ms windows (a K-weighting's highpass and shelf), those within
	10 dB of the loud ones."""
	y = dsp.fft_band(x.mean(axis=1).astype(np.float64), 60.0, None, order=2)
	y = y + 0.6 * dsp.fft_band(y, 2000.0, None, order=1)
	w = int(0.4 * SR)
	k = len(y) // w
	if k == 0:
		return -99.0
	p = (y[: k * w].reshape(k, w) ** 2).mean(axis=1)
	db = 10.0 * np.log10(p + 1e-12)
	db = db[db > -60.0]
	if len(db) == 0:
		return -99.0
	g = db[db > db.max() - 20.0]
	return float(10.0 * np.log10(np.mean(10.0 ** (g / 10.0))))


def limit(x: np.ndarray, ceiling_db: float = -1.0, release: float = 0.15) -> np.ndarray:
	"""A look-ahead peak limiter (5 ms) to `ceiling_db`."""
	c = 10.0 ** (ceiling_db / 20.0)
	look = int(0.005 * SR)
	pk = np.abs(x).max(axis=1)
	# the peak ahead, then held and released
	need = np.maximum(pk / c, 1.0)
	from numpy.lib.stride_tricks import sliding_window_view
	pad = np.concatenate([need, np.ones(look)])
	ahead = sliding_window_view(pad, look + 1).max(axis=1)[: len(need)]
	g = 1.0 / ahead
	a = math.exp(-1.0 / (release * SR))
	# release smoothing: the gain may fall at once, it rises back at `release`
	out = np.empty_like(g)
	cur = 1.0
	gl = g.tolist()
	for i, v in enumerate(gl):
		cur = v if v < cur else v + (cur - v) * a
		out[i] = cur
	return (x * out[:, None]).astype(np.float32)


def master(x: np.ndarray, target: float, ceiling_db: float = -1.0) -> np.ndarray:
	"""To `target` loudness (dB, see loudness()), peaks limited."""
	g = 10.0 ** ((target - loudness(x)) / 20.0)
	return limit(x * np.float32(g), ceiling_db)
