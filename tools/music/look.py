#!/usr/bin/env python3
"""A rendered cue as a picture (for checking without ears): its loudness over time with the bar lines, and a
spectrogram up to 6 kHz.

    python3 tools/music/look.py audio/music/main_theme.wav [cue name for the bar lines] [out.png]
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "cues"))
sys.path.insert(0, os.path.join(HERE, "..", "sfx"))
import dsp  # noqa: E402


def main() -> None:
	wav = sys.argv[1]
	name = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(os.path.basename(wav))[0]
	out = sys.argv[3] if len(sys.argv) > 3 else os.path.splitext(wav)[0] + ".png"
	x, sr = dsp.read_wav(wav)
	spec = out + ".spec.png"
	dsp.spectrogram_png(x, spec, sr, n_fft=2048, fmax=6000, width=1400, height=300, db_range=80, title=name)
	m = x.mean(axis=1)
	w = int(0.1 * sr)
	k = len(m) // w
	db = 10 * np.log10((m[: k * w].reshape(k, w) ** 2).mean(axis=1) + 1e-10)
	W, H = 1444, 200
	im = Image.new("RGB", (W, H), (18, 18, 22))
	dr = ImageDraw.Draw(im)
	dur = len(m) / sr
	try:
		from render import build
		s = build(name)
		b = 0
		while s.t(b) < dur:
			xpx = 40 + int(s.t(b) / dur * 1400)
			dr.line([(xpx, 0), (xpx, H)], fill=(60, 60, 70) if b % 4 else (110, 110, 130))
			if b % 4 == 0:
				dr.text((xpx + 2, 2), str(b), fill=(160, 160, 180))
			b += 1
	except (ModuleNotFoundError, KeyError):
		pass
	for lv in (-10, -20, -30, -40, -50):
		y = int((-lv) / 60 * H)
		dr.line([(40, y), (W, y)], fill=(45, 45, 50))
		dr.text((2, y - 6), str(lv), fill=(120, 120, 130))
	pts = [(40 + int(i / k * 1400), int(min(60, -v) / 60 * H)) for i, v in enumerate(db)]
	dr.line(pts, fill=(240, 180, 80), width=1)
	sp = Image.open(spec)
	full = Image.new("RGB", (max(W, sp.width), H + sp.height), (18, 18, 22))
	full.paste(im, (0, 0))
	full.paste(sp, (0, H))
	full.save(out)
	os.remove(spec)
	print(out)


if __name__ == "__main__":
	main()
