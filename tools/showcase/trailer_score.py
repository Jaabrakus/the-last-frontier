#!/usr/bin/env python3
"""The trailer's score: synthesized, no samples (numpy and tools/sfx/dsp.py), on the edit's bar grid so every cut and
hit lands on the beat (tools/showcase/trailer_edit.py builds it; alone it writes the score for a listen).

    python3 tools/showcase/trailer_score.py <out.wav> [sample rate, default 48000]

D minor at 100 BPM (a beat 0.6 s = 18 frames at 30 fps; a bar 2.4 s). The sections by bar (SECTIONS):
    open    a low drone and a pad, a wooden flute's line over the river and the valley
    grow    the pulse: a hammered-dulcimer ostinato (paired Karplus-Strong courses), a frame drum, plucked bass
    hunt    war drums (taiko and toms), spiccato low strings, braams
    dark    half time: braams, a ticking wood block, a sub pulse; a riser and a roll into the climax
    climax  one beat of silence, then the hit (the night shot's flash)
    title   the chord rings out under the title, the flute's motif once more
    sting   near silence; a thud (the stinger) and the end card's last low boom
`accents` (seconds, kind) from the edit add hits where the picture has them: "boom" (taiko, sub), "hit" (the big
one), "thud" (low, short).
"""
from __future__ import annotations

import math
import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sfx"))
from dsp import fft_band, fftconvolve, karplus_strong  # noqa: E402

BPM = 100.0
BEAT = 60.0 / BPM
BAR = 4.0 * BEAT

## [first bar, last bar + 1] of each section.
SECTIONS = {
	"open": (0, 10),
	"grow": (10, 22),
	"hunt": (22, 30),
	"dark": (30, 38),
	"climax": (38, 39),
	"title": (39, 42),
	"sting": (42, 46),
}

# chords: [bass midi, pad voicing (midi)]
CH = {
	"Dm": [38, [50, 57, 62, 65, 69]],
	"Bb": [34, [46, 53, 58, 62, 65]],
	"F": [41, [53, 57, 60, 65, 69]],
	"C": [36, [48, 55, 60, 64, 67]],
	"Gm": [31, [43, 50, 55, 58, 62]],
	"A": [33, [45, 52, 57, 61, 64]],
}
# the chord of every bar
PROGRESSION = (["Dm"] * 4 + ["Bb"] * 2 + ["F"] * 2 + ["C"] * 2            # open 0-9
		+ ["Dm", "Dm", "Bb", "Bb", "F", "F", "C", "C", "Dm", "Dm", "Bb", "C"]      # grow 10-21
		+ ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A"]                             # hunt 22-29
		+ ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A"]                             # dark 30-37
		+ ["Dm"] * 8)                                                                  # climax, title, sting

# the flute: (bar, beat, midi, beats)
FLUTE_OPEN = [(2, 0, 69, 2), (2, 2, 74, 1.5), (2, 3.5, 72, 0.5), (3, 0, 69, 3.5),
		(4, 0, 65, 1), (4, 1, 67, 1), (4, 2, 69, 2), (5, 0, 74, 3), (5, 3, 72, 1),
		(6, 0, 72, 2), (6, 2, 69, 2), (7, 0, 65, 3.5),
		(8, 0, 67, 1), (8, 1, 69, 1), (8, 2, 72, 1), (8, 3, 76, 1), (9, 0, 74, 4)]
FLUTE_GROW = [(18, 0, 81, 2), (18, 2, 86, 1.5), (18, 3.5, 84, 0.5), (19, 0, 81, 4),
		(20, 0, 77, 1), (20, 1, 79, 1), (20, 2, 81, 2), (21, 0, 86, 2), (21, 2, 84, 2)]
FLUTE_TITLE = [(39, 2, 69, 2), (40, 0, 74, 1.5), (40, 1.5, 72, 0.5), (40, 2, 69, 4)]


def mtof(m: float) -> float:
	return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


def bt(bar: float, beat: float = 0.0) -> float:
	return bar * BAR + beat * BEAT


class Mix:
	"""A stereo bus with a reverb send."""

	def __init__(self, secs: float, sr: int):
		self.sr = sr
		self.n = int(math.ceil(secs * sr)) + sr
		self.dry = np.zeros((self.n, 2))
		self.wet = np.zeros((self.n, 2))

	def add(self, t: float, sig: np.ndarray, gain: float = 1.0, pan: float = 0.0, send: float = 0.2) -> None:
		i = int(round(t * self.sr))
		if i >= self.n or len(sig) == 0:
			return
		if i < 0:
			sig = sig[-i:]
			i = 0
		m = min(len(sig), self.n - i)
		if sig.ndim == 1:
			a = math.pi * 0.25 * (pan + 1.0)
			st = np.stack([sig[:m] * math.cos(a), sig[:m] * math.sin(a)], axis=1) * math.sqrt(2.0)
		else:
			st = sig[:m]
		self.dry[i:i + m] += st * gain
		self.wet[i:i + m] += st * gain * send


# --- instruments ---------------------------------------------------------------------------------------------------

def saw(f: np.ndarray | float, n: int, sr: int, r: np.random.Generator) -> np.ndarray:
	"""A band-limited sawtooth (polyBLEP), f per sample or fixed."""
	f = np.broadcast_to(np.asarray(f, dtype=float), (n,))
	dt = f / sr
	ph = (np.cumsum(dt) + r.uniform(0.0, 1.0)) % 1.0
	y = 2.0 * ph - 1.0
	a = ph < dt
	x = ph[a] / dt[a]
	y[a] -= x + x - x * x - 1.0
	b = ph > 1.0 - dt
	x = (ph[b] - 1.0) / dt[b]
	y[b] -= x * x + x + x + 1.0
	return y


def env(n: int, sr: int, attack: float, hold: float, release: float, curve: float = 1.0) -> np.ndarray:
	t = np.arange(n) / sr
	e = np.clip(t / max(attack, 1e-4), 0.0, 1.0) ** curve
	rel = np.clip((t - attack - hold) / max(release, 1e-4), 0.0, 1.0)
	return e * (1.0 - rel) ** 2


def pad(notes, dur: float, sr: int, r, bright: float = 900.0, attack: float = 1.2, release: float = 1.8) -> np.ndarray:
	n = int((dur + release) * sr)
	t = np.arange(n) / sr
	y = np.zeros(n)
	for m in notes:
		f0 = mtof(m)
		for dv in (-0.0045, 0.0, 0.0052):
			vib = 1.0 + 0.0018 * np.sin(2.0 * math.pi * r.uniform(4.6, 5.6) * t + r.uniform(0, 6.3))
			y += saw(f0 * (1.0 + dv) * vib, n, sr, r)
	y = fft_band(y, 70.0, bright, order=2, sr=sr)
	return y * env(n, sr, attack, max(dur - attack, 0.0), release, 1.6) / (len(notes) * 3.0)


def flute(m: float, dur: float, sr: int, r) -> np.ndarray:
	rel = 0.35
	n = int((dur + rel) * sr)
	t = np.arange(n) / sr
	f0 = mtof(m)
	vib = 1.0 + 0.006 * np.sin(2.0 * math.pi * 5.2 * t) * np.clip((t - 0.25) / 0.4, 0.0, 1.0)
	ph = 2.0 * math.pi * np.cumsum(f0 * vib) / sr
	y = np.sin(ph) + 0.22 * np.sin(2 * ph + 0.3) + 0.08 * np.sin(3 * ph + 1.1) + 0.03 * np.sin(4 * ph)
	breath = fft_band(r.standard_normal(n), f0 * 0.8, f0 * 3.0, order=2, sr=sr)
	breath /= np.std(breath) + 1e-9
	e = env(n, sr, 0.07, max(dur - 0.07, 0.0), rel, 1.0)
	chiff = np.exp(-t / 0.04) * 0.5
	return (y * (0.9 + 0.1 * np.sin(2 * math.pi * 0.7 * t)) + breath * (0.07 + chiff)) * e


def dulcimer(m: float, sr: int, r, vel: float = 1.0, dur: float = 1.3) -> np.ndarray:
	"""A hammered string: two courses a little apart, a bright strike, a wooden body."""
	f0 = mtof(m)
	y = np.zeros(int(dur * sr))
	for det in (-0.0025, 0.0025):
		ex = r.uniform(-1.0, 1.0, max(int(sr / (f0 * (1 + det))), 2))
		ex = np.convolve(ex, [0.5, 0.5], mode="same")
		y += karplus_strong(f0 * (1.0 + det), dur, t60=1.1, damp=0.28, excite=ex, sr=sr)[:len(y)]
	y = fft_band(y, 120.0, 7000.0, order=2, sr=sr)
	return y * vel / (np.max(np.abs(y)) + 1e-9)


def bass_pluck(m: float, sr: int, r, dur: float = 1.6) -> np.ndarray:
	f0 = mtof(m)
	y = karplus_strong(f0, dur, t60=1.6, damp=0.6, r=r, sr=sr)
	t = np.arange(len(y)) / sr
	y = y + 0.5 * np.sin(2 * math.pi * f0 * t) * np.exp(-t / 0.5)
	y = fft_band(y, 30.0, 1200.0, order=2, sr=sr)
	return y / (np.max(np.abs(y)) + 1e-9)


def drum(sr: int, r, f_hi: float, f_lo: float, sweep: float, decay: float, noise: float, nlo: float, nhi: float,
		ndecay: float, dur: float) -> np.ndarray:
	n = int(dur * sr)
	t = np.arange(n) / sr
	f = f_lo + (f_hi - f_lo) * np.exp(-t / sweep)
	y = np.sin(2 * math.pi * np.cumsum(f) / sr) * np.exp(-t / decay)
	nz = fft_band(r.standard_normal(n), nlo, nhi, order=2, sr=sr)
	nz /= np.std(nz) + 1e-9
	y += noise * nz * np.exp(-t / ndecay)
	y *= np.clip(t / 0.0015, 0.0, 1.0)
	return y / (np.max(np.abs(y)) + 1e-9)


def frame_drum(sr, r):
	return drum(sr, r, 150.0, 62.0, 0.03, 0.28, 0.35, 80.0, 900.0, 0.03, 0.9)


def taiko(sr, r):
	return drum(sr, r, 170.0, 52.0, 0.05, 0.75, 0.5, 60.0, 700.0, 0.12, 2.2)


def tom(sr, r, f=120.0):
	return drum(sr, r, f * 1.7, f, 0.04, 0.32, 0.4, 100.0, 1800.0, 0.05, 0.9)


def snare(sr, r):
	return drum(sr, r, 330.0, 190.0, 0.02, 0.1, 1.4, 900.0, 7000.0, 0.09, 0.5)


def shaker(sr, r):
	n = int(0.12 * sr)
	t = np.arange(n) / sr
	y = fft_band(r.standard_normal(n), 4000.0, 11000.0, order=2, sr=sr)
	return y / (np.max(np.abs(y)) + 1e-9) * np.clip(t / 0.008, 0, 1) * np.exp(-t / 0.035)


def tick(sr, r):
	n = int(0.15 * sr)
	t = np.arange(n) / sr
	y = np.sin(2 * math.pi * 1250.0 * t) * np.exp(-t / 0.018) + 0.4 * np.sin(2 * math.pi * 2710.0 * t) * np.exp(-t / 0.008)
	return y


def sub(sr, f=38.0, dur=2.2, decay=0.9):
	n = int(dur * sr)
	t = np.arange(n) / sr
	fr = f * (1.0 + 0.6 * np.exp(-t / 0.08))
	return np.sin(2 * math.pi * np.cumsum(fr) / sr) * np.exp(-t / decay) * np.clip(t / 0.004, 0, 1)


def braam(sr, r, root: float = 38.0, dur: float = 3.2) -> np.ndarray:
	"""The trailer brass: low saw stacks, a filter that opens and closes, driven hard."""
	n = int(dur * sr)
	t = np.arange(n) / sr
	y = np.zeros(n)
	for m, g in [(root - 12, 1.0), (root, 0.9), (root + 7, 0.55), (root + 12, 0.35)]:
		for dv in (-0.006, 0.0, 0.007):
			y += g * saw(mtof(m) * (1.0 + dv) * (1.0 + 0.004 * np.sin(2 * math.pi * 3.0 * t)), n, sr, r)
	# the opening filter: a time-varying lowpass done in chunks (a swell of brightness at the attack)
	out = np.zeros(n)
	hop = int(0.05 * sr)
	win = np.hanning(2 * hop)
	for i in range(0, n - 2 * hop, hop):
		tt = i / sr
		fc = 180.0 + 1400.0 * math.exp(-tt / 0.6) * min(tt / 0.12, 1.0) + 120.0
		seg = fft_band(y[i:i + 2 * hop] * win, None, fc, order=2, sr=sr)
		out[i:i + 2 * hop] += seg
	out = np.tanh(out * 1.6 / (np.max(np.abs(out)) + 1e-9) * 2.2)
	return out * env(n, sr, 0.06, dur * 0.35, dur * 0.6, 1.0)


def crash(sr, r, dur=3.0):
	n = int(dur * sr)
	t = np.arange(n) / sr
	y = fft_band(r.standard_normal(n), 2500.0, 14000.0, order=2, sr=sr)
	return y / (np.std(y) + 1e-9) * np.exp(-t / 0.9) * 0.25


def riser(sr, r, dur: float) -> np.ndarray:
	n = int(dur * sr)
	t = np.arange(n) / sr
	k = t / dur
	nz = r.standard_normal(n)
	out = np.zeros(n)
	hop = int(0.05 * sr)
	win = np.hanning(2 * hop)
	for i in range(0, n - 2 * hop, hop):
		kk = i / n
		c = 300.0 * (40.0 ** kk)
		out[i:i + 2 * hop] += fft_band(nz[i:i + 2 * hop] * win, c * 0.5, c * 1.6, order=2, sr=sr)
	out /= np.std(out) + 1e-9
	tone = np.zeros(n)
	for base in (55.0, 110.0, 220.0):
		f = base * (2.0 ** (2.0 * k))
		tone += np.sin(2 * math.pi * np.cumsum(f) / sr)
	return (out * 0.35 + tone * 0.25) * (k ** 2.2)


def reverb_ir(sr: int, r, t60: float = 3.2, pre: float = 0.02) -> np.ndarray:
	n = int(t60 * sr)
	t = np.arange(n) / sr
	ir = np.zeros((n + int(pre * sr), 2))
	for c in range(2):
		x = r.standard_normal(n) * np.exp(-6.9 * t / t60)
		x = fft_band(x, 150.0, 5200.0, order=2, sr=sr)
		ir[int(pre * sr):, c] = x
	return ir / np.sqrt(np.sum(ir ** 2) / 2.0)


# --- the arrangement -------------------------------------------------------------------------------------------------

def render(total_s: float, sr: int = 48000, accents=(), seed: int = 1765) -> np.ndarray:
	"""The score, (n, 2) float, total_s long: SECTIONS on the bar grid, plus the edit's accents."""
	r = np.random.default_rng(seed)
	mx = Mix(total_s, sr)
	sec = SECTIONS
	s_open, s_grow, s_hunt, s_dark = sec["open"], sec["grow"], sec["hunt"], sec["dark"]
	climax = sec["climax"][0]
	title = sec["title"]
	fd, tk, bm = frame_drum(sr, r), taiko(sr, r), braam(sr, r)
	toms = [tom(sr, r, f) for f in (95.0, 120.0, 150.0)]
	sn, shk, tik = snare(sr, r), shaker(sr, r), tick(sr, r)

	# the drone: D and A under the open, swelling in
	dn = pad([26, 33, 38], bt(s_open[1]) + 1.0, sr, r, bright=260.0, attack=4.0, release=3.0)
	mx.add(bt(0), dn, 0.55, 0.0, 0.3)
	# the pad through open, grow, hunt and dark: a chord a change, brighter as it goes
	bar = 0
	while bar < climax:
		name = PROGRESSION[bar]
		span = 1
		while bar + span < climax and PROGRESSION[bar + span] == name and span < 2:
			span += 1
		if bar < s_grow[0]:
			bright, g = 700.0, 0.42
		elif bar < s_hunt[0]:
			bright, g = 1100.0, 0.34
		elif bar < s_dark[0]:
			bright, g = 1700.0, 0.36
		else:
			bright, g = 1300.0, 0.4
		mx.add(bt(bar), pad(CH[name][1], span * BAR, sr, r, bright=bright, attack=0.9, release=1.6), g, 0.0, 0.45)
		bar += span

	# the flute
	for (b, beat, m, beats) in FLUTE_OPEN + FLUTE_GROW:
		mx.add(bt(b, beat), flute(m, beats * BEAT, sr, r), 0.16, -0.15, 0.5)

	# grow: dulcimer ostinato, plucked bass, frame drum; shaker and toms join halfway
	pat = [0, 1, 2, 1, 3, 1, 2, 1]
	for b in range(s_grow[0], s_grow[1]):
		ch = CH[PROGRESSION[b]][1]
		tones = [ch[1] + 12, ch[3] + 12, ch[2] + 12, ch[4] + 12]
		for i, p in enumerate(pat):
			vel = 0.9 if i % 2 == 0 else 0.62
			mx.add(bt(b, i * 0.5), dulcimer(tones[p] - 12, sr, r, vel), 0.2, 0.25 if i % 2 else -0.1, 0.3)
		root = CH[PROGRESSION[b]][0]
		mx.add(bt(b, 0), bass_pluck(root, sr, r), 0.42, 0.0, 0.1)
		mx.add(bt(b, 2.5), bass_pluck(root, sr, r, 1.0), 0.3, 0.0, 0.1)
		mx.add(bt(b, 0), fd, 0.55, 0.0, 0.15)
		mx.add(bt(b, 2), fd, 0.42, 0.0, 0.15)
		if b >= s_grow[0] + 4:
			for i in range(8):
				mx.add(bt(b, i * 0.5), shk, 0.07 if i % 2 else 0.11, 0.35, 0.1)
			mx.add(bt(b, 3.5), toms[1], 0.3, -0.2, 0.2)
		if b >= s_grow[0] + 8:
			mx.add(bt(b, 0), tk, 0.45, 0.0, 0.25)

	# hunt: war drums, spiccato low strings, braams
	for b in range(s_hunt[0], s_hunt[1]):
		ch = PROGRESSION[b]
		root = CH[ch][0]
		mx.add(bt(b, 0), tk, 0.75, 0.0, 0.3)
		mx.add(bt(b, 2), tk, 0.55, 0.0, 0.3)
		for beat, ti, g in [(1.5, 0, 0.45), (2.5, 1, 0.35), (3.0, 2, 0.4), (3.5, 1, 0.45), (3.75, 0, 0.35)]:
			mx.add(bt(b, beat), toms[ti], g, 0.3 if ti == 2 else -0.3, 0.25)
		for i in range(8):
			m = root + 12 if i % 4 != 3 else root + 19
			n = int(0.26 * sr)
			sp = saw(mtof(m), n, sr, r) + saw(mtof(m) * 1.004, n, sr, r)
			sp = fft_band(sp, 40.0, 1400.0, order=2, sr=sr) * env(n, sr, 0.008, 0.06, 0.18)
			mx.add(bt(b, i * 0.5), sp, 0.2 if i % 2 else 0.28, 0.1, 0.2)
		mx.add(bt(b, 0), fd, 0.35, 0.0, 0.1)
		if (b - s_hunt[0]) % 4 == 0:
			mx.add(bt(b, 0), bm, 0.32, 0.0, 0.35)
		if b == s_hunt[1] - 2:           # the stampede's two bars: the toms roll in
			for i in range(16):
				mx.add(bt(b + 1, i * 0.25), toms[i % 3], 0.25 + 0.3 * i / 16, (-0.4, 0.0, 0.4)[i % 3], 0.2)

	# dark: half time, braams, ticking, the sub; a riser and a roll into the climax
	for b in range(s_dark[0], s_dark[1]):
		if (b - s_dark[0]) % 2 == 0:
			mx.add(bt(b, 0), braam(sr, r, CH[PROGRESSION[b]][0] + 0.0), 0.5, 0.0, 0.4)
			mx.add(bt(b, 0), tk, 0.8, 0.0, 0.4)
			mx.add(bt(b, 0), sub(sr), 0.55, 0.0, 0.0)
		mx.add(bt(b, 2), tk, 0.45, 0.0, 0.35)
		for i in range(8):
			mx.add(bt(b, i * 0.5), tik, 0.06 if i % 2 else 0.1, 0.5, 0.2)
	rs = riser(sr, r, 2 * BAR)
	mx.add(bt(s_dark[1] - 2), rs, 0.4, 0.0, 0.25)
	for i in range(32):            # the roll: sixteenths for a bar, then thirty-seconds, louder
		t = bt(s_dark[1] - 2) + (i * 0.25 * BEAT if i < 16 else 4.0 * BEAT + (i - 16) * 0.25 * BEAT)
		mx.add(t, sn if i % 2 else toms[i % 3], 0.18 + 0.35 * i / 32, (-0.3, 0.3)[i % 2], 0.3)

	# climax: a beat of silence at the bar (the cut to black), the hit on its third beat
	hit_t = bt(climax, 2)
	_big_hit(mx, sr, r, hit_t, bm, tk)
	# title: Dm rings out, the flute's motif once more
	mx.add(hit_t, pad(CH["Dm"][1] + [74], bt(title[1]) - hit_t, sr, r, bright=1500.0, attack=0.05, release=4.0), 0.55, 0.0, 0.6)
	mx.add(hit_t, pad([26, 38], bt(title[1]) - hit_t, sr, r, bright=300.0, attack=0.02, release=4.0), 0.6, 0.0, 0.3)
	for (b, beat, m, beats) in FLUTE_TITLE:
		mx.add(bt(b, beat), flute(m, beats * BEAT, sr, r), 0.17, -0.1, 0.6)

	for (t, kind) in accents:
		if kind == "hit":
			_big_hit(mx, sr, r, t, bm, tk)
		elif kind == "boom":
			mx.add(t, tk, 0.8, 0.0, 0.35)
			mx.add(t, sub(sr, 40.0, 1.6, 0.6), 0.5, 0.0, 0.0)
		elif kind == "thud":
			mx.add(t, taiko(sr, r), 0.6, 0.0, 0.2)
			mx.add(t, sub(sr, 34.0, 1.2, 0.35), 0.5, 0.0, 0.0)

	# the room, then the master: a gentle glue, peaks to -1 dBFS
	n_out = int(round(total_s * sr))
	ir = reverb_ir(sr, r)
	wet = np.stack([fftconvolve(mx.wet[:, c], ir[:, c])[:mx.n] for c in range(2)], axis=1)
	y = (mx.dry + wet * 0.55)[:n_out]
	pk = np.max(np.abs(y)) + 1e-9
	y = np.tanh(y / pk * 1.25) / math.tanh(1.25)
	return y * 10 ** (-1.0 / 20.0)


def _big_hit(mx: Mix, sr: int, r, t: float, bm: np.ndarray, tk: np.ndarray) -> None:
	mx.add(t, tk, 1.0, -0.15, 0.5)
	mx.add(t + 0.004, taiko(sr, r), 0.9, 0.15, 0.5)
	mx.add(t, sub(sr, 36.0, 3.0, 1.2), 0.8, 0.0, 0.0)
	mx.add(t, braam(sr, r, 38.0, 4.5), 0.7, 0.0, 0.5)
	mx.add(t, crash(sr, r, 4.0), 0.5, 0.0, 0.6)


def write_wav(path: str, y: np.ndarray, sr: int) -> None:
	pcm = (np.clip(y, -1.0, 1.0) * 32767.0).astype("<i2")
	with wave.open(path, "wb") as w:
		w.setnchannels(2)
		w.setsampwidth(2)
		w.setframerate(sr)
		w.writeframes(pcm.tobytes())


def main() -> None:
	out = sys.argv[1]
	sr = int(sys.argv[2]) if len(sys.argv) > 2 else 48000
	total = bt(SECTIONS["sting"][1])
	y = render(total, sr)
	write_wav(out, y, sr)
	print("SCORE %s: %.1f s at %d Hz" % (out, total, sr))


if __name__ == "__main__":
	main()
