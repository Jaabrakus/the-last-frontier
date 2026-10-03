"""The orchestra's choir (VSCO 2 CE has none): each note sung by a few voices, each a band of harmonics shaped by the
vowel's formants (the singers' part by the pitch: bass, tenor, alto, soprano), its own vibrato, drift and breath.

    sing(midi, dur, vel, vowel, rng, attack=None) -> (n, 2) float32
"""
from __future__ import annotations

import math

import numpy as np

import dsp

SR = 44100
# formants per part and vowel: (Hz, dB, bandwidth Hz) x 5 (the classic tables of sung vowels)
F = {
	"bass": {
		"a": [(600, 0, 60), (1040, -7, 70), (2250, -9, 110), (2450, -9, 120), (2750, -20, 130)],
		"o": [(400, 0, 40), (750, -11, 80), (2400, -21, 100), (2600, -20, 120), (2900, -40, 120)],
		"u": [(350, 0, 40), (600, -20, 80), (2400, -32, 100), (2675, -28, 120), (2950, -36, 120)],
		"e": [(400, 0, 40), (1620, -12, 80), (2400, -9, 100), (2800, -12, 120), (3100, -18, 120)],
	},
	"tenor": {
		"a": [(650, 0, 80), (1080, -6, 90), (2650, -7, 120), (2900, -8, 130), (3250, -22, 140)],
		"o": [(400, 0, 40), (800, -10, 80), (2600, -12, 100), (2800, -12, 120), (3000, -26, 120)],
		"u": [(350, 0, 40), (600, -20, 60), (2700, -17, 100), (2900, -14, 120), (3300, -26, 120)],
		"e": [(400, 0, 70), (1700, -14, 80), (2600, -12, 100), (3200, -14, 120), (3580, -20, 120)],
	},
	"alto": {
		"a": [(800, 0, 80), (1150, -4, 90), (2800, -20, 120), (3500, -36, 130), (4950, -60, 140)],
		"o": [(450, 0, 70), (800, -9, 80), (2830, -16, 100), (3500, -28, 130), (4950, -55, 135)],
		"u": [(325, 0, 50), (700, -12, 60), (2530, -30, 170), (3500, -40, 180), (4950, -64, 200)],
		"e": [(400, 0, 60), (1600, -24, 80), (2700, -30, 120), (3300, -35, 150), (4950, -60, 200)],
	},
	"soprano": {
		"a": [(800, 0, 80), (1150, -6, 90), (2900, -32, 120), (3900, -20, 130), (4950, -50, 140)],
		"o": [(450, 0, 70), (800, -11, 80), (2830, -22, 100), (3800, -22, 130), (4950, -50, 135)],
		"u": [(325, 0, 50), (700, -16, 60), (2700, -35, 170), (3800, -40, 180), (4950, -60, 200)],
		"e": [(350, 0, 60), (2000, -20, 100), (2800, -15, 120), (3600, -40, 150), (4950, -56, 200)],
	},
}
PAN = {"bass": 0.3, "tenor": 0.12, "alto": -0.12, "soprano": -0.32}
TOP_DB = -19.0
RANGE_DB = 18.0
VOICES = 4
FMAX = 5200.0


def part_of(m: float) -> str:
	return "bass" if m < 50 else "tenor" if m < 57 else "alto" if m < 64 else "soprano"


def pan_of(m: float) -> float:
	return PAN[part_of(m)]


def _env(freqs: np.ndarray, fm) -> np.ndarray:
	e = np.full_like(freqs, 0.002)
	for f, db, bw in fm:
		e += 10.0 ** (db / 20.0) / (1.0 + ((freqs - f) / (bw * 0.5)) ** 2)
	return e


def _smooth(n: int, rate: float, rng) -> np.ndarray:
	k = max(int(n * rate / SR) + 3, 3)
	pts = rng.standard_normal(k)
	return np.interp(np.linspace(0.0, k - 1.0, n), np.arange(k), pts)


def sing(m: float, dur: float, vel, vowel: str, rng, attack: float | None = None) -> np.ndarray:
	vm = float(vel) if isinstance(vel, (int, float)) else float(max(v for v in np.atleast_1d(vel).ravel()))
	part = part_of(m)
	fm = F[part][vowel]
	rel = 0.55
	n = int((dur + rel) * SR)
	t = np.arange(n) / SR
	f0 = 440.0 * 2.0 ** ((m - 69.0) / 12.0)
	slope = 1.35 - 0.55 * vm           # louder singing is brighter
	K = max(1, int(FMAX / f0))
	kk = np.arange(1, K + 1)
	amps = kk ** -slope * _env(kk * f0, fm)
	amps /= np.sqrt(np.sum(amps ** 2))
	out = np.zeros((n, 2), np.float32)
	for v in range(VOICES):
		det = rng.normal(0.0, 7.0)
		vib_r = rng.uniform(4.7, 5.9)
		vib_d = rng.uniform(0.0035, 0.006) * np.clip((t - 0.25) / 0.6, 0.0, 1.0)
		drift = 0.0025 * _smooth(n, 0.6, rng)
		f = f0 * 2.0 ** (det / 1200.0) * (1.0 + vib_d * np.sin(2 * math.pi * vib_r * t + rng.uniform(0, 6.3)) + drift)
		ph = 2.0 * math.pi * np.cumsum(f) / SR
		y = np.zeros(n, np.float32)
		phis = rng.uniform(0.0, 2 * math.pi, K)
		for k in range(K):
			if amps[k] < 1e-4:
				continue
			y += np.float32(amps[k]) * np.sin(((k + 1) * ph + phis[k]) % (2 * math.pi)).astype(np.float32)
		shimmer = 1.0 + 0.12 * _smooth(n, 1.5, rng)
		y *= shimmer.astype(np.float32)
		a = math.pi * 0.25 * (np.clip(PAN[part] + rng.uniform(-0.25, 0.25), -1, 1) + 1.0)
		d = int(abs(rng.normal(0.0, 0.03)) * SR)
		y = np.concatenate([np.zeros(d, np.float32), y[: n - d]])
		out[:, 0] += y * math.cos(a)
		out[:, 1] += y * math.sin(a)
	# breath: noise through the same formants
	br = rng.standard_normal(n)
	spec = np.fft.rfft(br)
	fr = np.fft.rfftfreq(n, 1.0 / SR)
	br = np.fft.irfft(spec * _env(fr, fm) * (fr > 150.0), n)
	br = (br / (np.std(br) + 1e-9) * 0.05).astype(np.float32)
	out += br[:, None] * np.array([0.8, 0.8], np.float32)
	# the envelope: a swell in, held, released; the level from the velocity
	at = attack if attack is not None else 0.25 + 0.35 * (1.0 - vm)
	env = np.clip(t / max(at, 1e-3), 0.0, 1.0) ** 1.6
	r0 = dur
	env *= np.where(t > r0, np.clip(np.cos(np.clip((t - r0) / rel, 0.0, 1.0) * math.pi / 2.0), 0.0, 1.0) ** 1.5, 1.0)
	if not isinstance(vel, (int, float)):
		pts = list(vel)
		if len(pts) == 2 and all(isinstance(p, (int, float)) for p in pts):
			pts = [(0.0, pts[0]), (1.0, pts[1])]
		cv = np.interp(np.clip(t / max(dur, 1e-3), 0, 1), [p[0] for p in pts], [p[1] for p in pts])
	else:
		cv = np.full(n, vm)
	db = TOP_DB - RANGE_DB * (1.0 - np.clip(cv, 0.0, 1.0)) ** 1.15
	rms = math.sqrt(float(np.mean(out[: max(int(dur * SR), 1)] ** 2)) + 1e-12)
	g = (10.0 ** (db / 20.0) / rms * env).astype(np.float32)
	out *= g[:, None]
	if n > 64:
		for c in range(2):
			out[:, c] = dsp.fft_band(out[:, c].astype(np.float64), 90.0, None, order=2)
	return out
