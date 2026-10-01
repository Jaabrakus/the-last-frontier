#!/usr/bin/env python3
"""The quiet score for the damage-system trailer (user 2026-09-30: "easy, not too flashy, human like"): D minor at 100 BPM like
the big trailer (a bar 2.4 s), a soft pad that changes every two bars, a dulcimer figure now and then and one slow flute line.
No drums, no hits, no risers.  python3 anatomy_score.py <out.wav> [seconds]"""
from __future__ import annotations

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trailer_score as ts  # noqa: E402
from dsp import fftconvolve  # noqa: E402

BAR = ts.BAR
# (first bar, the chord's notes as MIDI)
CHORDS = [
	(0, [50, 53, 57]),          # Dm
	(4, [46, 50, 53]),          # Bb
	(6, [43, 46, 50]),          # Gm
	(8, [43, 46, 50]),          # Gm
	(10, [45, 49, 52, 55]),     # A7 (the held breath)
	(12, [50, 53, 57]),         # Dm
	(14, [46, 50, 53]),         # Bb
	(16, [50, 53, 57]),         # Dm
]
FLUTE = [(4, 69, 2.2), (5, 65, 2.2), (6.5, 67, 1.8), (8, 65, 2.4), (10, 64, 2.4), (12, 62, 3.0), (14, 65, 2.4), (16, 62, 4.0)]


def render(total_s: float, sr: int = 48000, seed: int = 1765) -> np.ndarray:
	r = np.random.default_rng(seed)
	mx = ts.Mix(total_s, sr)
	for k, (bar, notes) in enumerate(CHORDS):
		end = CHORDS[k + 1][0] if k + 1 < len(CHORDS) else bar + 3
		dur = (end - bar) * BAR
		mx.add(bar * BAR, ts.pad(notes, dur, sr, r, bright=700.0, attack=1.8, release=2.4), 0.55, 0.0, 0.45)
	# the dulcimer: the chord's notes, a slow figure every two bars, soft
	for bar, notes in CHORDS:
		if bar < 2:
			continue
		for j, m in enumerate([notes[1] + 12, notes[2] + 12, notes[0] + 24][: 3]):
			mx.add(bar * BAR + j * ts.BEAT * 1.5, ts.dulcimer(m, sr, r, vel=0.32, dur=1.8), 0.5, -0.2 + 0.2 * j, 0.5)
	for bar, m, dur in FLUTE:
		mx.add(bar * BAR, ts.flute(m, dur, sr, r), 0.22, 0.15, 0.55)
	n_out = int(round(total_s * sr))
	ir = ts.reverb_ir(sr, r, t60=3.6)
	wet = np.stack([fftconvolve(mx.wet[:, c], ir[:, c])[:mx.n] for c in range(2)], axis=1)
	y = (mx.dry + wet * 0.6)[:n_out]
	fade = int(2.0 * sr)
	y[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
	pk = np.max(np.abs(y)) + 1e-9
	return y / pk * 10 ** (-4.0 / 20.0)


def main() -> None:
	out = sys.argv[1]
	total = float(sys.argv[2]) if len(sys.argv) > 2 else 17.5 * BAR
	y = render(total)
	ts.write_wav(out, y, 48000)
	print("SCORE %s: %.1f s" % (out, total))


if __name__ == "__main__":
	main()
