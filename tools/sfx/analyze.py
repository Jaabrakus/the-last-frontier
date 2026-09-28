#!/usr/bin/env python3
"""Measure SFX WAVs and optionally render spectrogram PNGs (numpy + PIL).

    python3 tools/sfx/analyze.py audio/sfx/footsteps
    python3 tools/sfx/analyze.py audio/sfx/footsteps --png /tmp/specs --sheets
    python3 tools/sfx/analyze.py a.wav b.wav --json report.json

Per file: duration, channels, peak dBFS, RMS dBFS, clipped samples,
spectral centroid, attack time (10 % -> 90 % of the 1 ms RMS envelope),
time of the envelope peak, and time from peak until the envelope stays
20 dB down. --sheets also renders one stacked PNG per sound id (files named
<id>_<nn>.wav are grouped).
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dsp  # noqa: E402

SR = dsp.SR


def measure(x: np.ndarray, sr: int = SR) -> dict:
    m = x if x.ndim == 1 else np.mean(x, axis=1)
    n = len(m)
    out = {"duration_s": n / sr, "channels": 1 if x.ndim == 1 else int(x.shape[1])}
    peak = float(np.max(np.abs(x))) if n else 0.0
    out["peak_dbfs"] = dsp.lin2db(peak)
    out["rms_dbfs"] = dsp.lin2db(float(np.sqrt(np.mean(m ** 2)))) if n else -240.0
    out["clipped"] = int(np.sum(np.abs(x) >= 32767 / 32768.0))
    nf = 1 << max(int(n - 1).bit_length(), 1)
    mag = np.abs(np.fft.rfft(m, nf))
    f = np.fft.rfftfreq(nf, 1.0 / sr)
    out["centroid_hz"] = float(np.sum(f * mag) / (np.sum(mag) + 1e-20))
    w = max(1, int(round(0.001 * sr)))
    env = np.sqrt(np.convolve(m ** 2, np.ones(w) / w, mode="same"))
    emax = float(np.max(env)) if n else 0.0
    if emax > 0:
        i10 = int(np.argmax(env >= 0.1 * emax))
        i90 = int(np.argmax(env >= 0.9 * emax))
        ipk = int(np.argmax(env))
        above = np.nonzero(env >= 0.1 * emax)[0]
        out["attack_ms"] = 1000.0 * (i90 - i10) / sr
        out["t_peak_ms"] = 1000.0 * ipk / sr
        out["decay20_ms"] = 1000.0 * (int(above[-1]) - ipk) / sr
    else:
        out["attack_ms"] = out["t_peak_ms"] = out["decay20_ms"] = 0.0
    return out


def _colormap(v: np.ndarray) -> np.ndarray:
    a = np.array([[0.00, 0, 0, 4], [0.13, 28, 16, 68], [0.25, 79, 18, 123],
                  [0.38, 129, 37, 129], [0.50, 181, 54, 122], [0.63, 229, 80, 100],
                  [0.75, 251, 135, 97], [0.88, 254, 194, 135], [1.00, 252, 253, 191]])
    return np.stack([np.interp(v, a[:, 0], a[:, c]) for c in (1, 2, 3)], -1).astype(np.uint8)


def spectrogram_image(x: np.ndarray, title: str = "", sr: int = SR, fmin: float = 40.0,
                      fmax: float = 20000.0, dyn_db: float = 80.0, width: int = 720,
                      height: int = 260, n_fft: int = 1024, hop: int = 32,
                      px_per_s: float | None = None):
    """Log-frequency spectrogram under a waveform strip, returns a PIL image.
    px_per_s fixes the time scale (so several sounds line up)."""
    from PIL import Image, ImageDraw
    m = x if x.ndim == 1 else np.mean(x, axis=1)
    dur = len(m) / sr
    if px_per_s:
        width = max(40, int(round(dur * px_per_s)))
    win = np.hanning(n_fft)
    padded = np.concatenate([np.zeros(n_fft // 2), m, np.zeros(n_fft)])
    frames = max(1, (len(padded) - n_fft) // hop)
    idx = np.arange(n_fft)[None, :] + hop * np.arange(frames)[:, None]
    S = np.abs(np.fft.rfft(padded[idx] * win, axis=1)) + 1e-12
    Sdb = 20 * np.log10(S / S.max())
    f = np.fft.rfftfreq(n_fft, 1.0 / sr)
    rows = np.geomspace(fmin, fmax, height)
    img = np.stack([np.interp(rows, f, Sdb[i]) for i in range(frames)], axis=1)[::-1]
    spec = Image.fromarray(_colormap(np.clip((img + dyn_db) / dyn_db, 0, 1)))
    spec = spec.resize((width, height), Image.BILINEAR)
    left, top, wave_h, bottom = 44, 16, 60, 18
    W = left + width + 10
    H = top + wave_h + 4 + height + bottom
    canvas = Image.new("RGB", (W, H), (18, 18, 22))
    sy = top + wave_h + 4
    canvas.paste(spec, (left, sy))
    d = ImageDraw.Draw(canvas)
    d.text((left, 2), title, fill=(235, 235, 235))
    mid = top + wave_h / 2
    cols = np.array_split(m, width)
    for i, c in enumerate(cols):
        if len(c):
            d.line([(left + i, mid - c.max() * wave_h / 2), (left + i, mid - c.min() * wave_h / 2)],
                   fill=(120, 200, 255))
    for ft in (50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000):
        y = sy + height - 1 - int(np.log(ft / fmin) / np.log(fmax / fmin) * (height - 1))
        d.line([(left - 4, y), (left, y)], fill=(200, 200, 200))
        d.text((2, y - 6), f"{ft // 1000}k" if ft >= 1000 else str(ft), fill=(200, 200, 200))
    step = 0.05 if dur <= 0.6 else (0.1 if dur <= 1.5 else 0.5)
    k = 0
    while k * step <= dur + 1e-9:
        xpx = left + int(k * step / max(dur, 1e-9) * (width - 1))
        d.line([(xpx, sy + height), (xpx, sy + height + 3)], fill=(200, 200, 200))
        d.text((xpx - 6, sy + height + 4), f"{int(round(k * step * 1000))}", fill=(200, 200, 200))
        k += 1
    return canvas


def stack_images(images, gap: int = 4):
    from PIL import Image
    W = max(im.width for im in images)
    H = sum(im.height for im in images) + gap * (len(images) - 1)
    sheet = Image.new("RGB", (W, H), (8, 8, 10))
    y = 0
    for im in images:
        sheet.paste(im, (0, y))
        y += im.height + gap
    return sheet


def collect(paths) -> list[str]:
    files = []
    for p in paths:
        if os.path.isdir(p):
            files += sorted(glob.glob(os.path.join(p, "*.wav")))
        else:
            files += sorted(glob.glob(p))
    return files


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("paths", nargs="+", help="WAV files, globs or directories")
    ap.add_argument("--png", help="directory for spectrogram PNGs (one per file)")
    ap.add_argument("--sheets", action="store_true",
                    help="also write one stacked PNG per sound id into --png")
    ap.add_argument("--json", help="write all measurements to this JSON file")
    args = ap.parse_args(argv)

    files = collect(args.paths)
    if not files:
        print("no wav files found", file=sys.stderr)
        return 1
    rows, groups = [], {}
    hdr = (f"{'file':34s} {'dur s':>6s} {'ch':>2s} {'peak':>7s} {'rms':>7s} "
           f"{'centroid':>8s} {'atk ms':>6s} {'pk ms':>6s} {'-20dB ms':>8s} {'clip':>4s}")
    print(hdr)
    print("-" * len(hdr))
    for path in files:
        x, sr = dsp.read_wav(path)
        r = measure(x, sr)
        r["file"] = os.path.basename(path)
        rows.append(r)
        print(f"{r['file']:34s} {r['duration_s']:6.3f} {r['channels']:2d} {r['peak_dbfs']:7.2f} "
              f"{r['rms_dbfs']:7.2f} {r['centroid_hz']:8.0f} {r['attack_ms']:6.1f} "
              f"{r['t_peak_ms']:6.1f} {r['decay20_ms']:8.1f} {r['clipped']:4d}")
        if args.png:
            os.makedirs(args.png, exist_ok=True)
            base = os.path.splitext(r["file"])[0]
            title = (f"{base}  {r['duration_s'] * 1000:.0f} ms  pk {r['peak_dbfs']:.1f}  "
                     f"rms {r['rms_dbfs']:.1f} dBFS  cent {r['centroid_hz']:.0f} Hz  "
                     f"atk {r['attack_ms']:.1f} ms")
            spectrogram_image(x, title, sr).save(os.path.join(args.png, base + ".png"))
            if args.sheets:
                sid = re.sub(r"_\d+$", "", base)
                groups.setdefault(sid, []).append(
                    spectrogram_image(x, title, sr, height=200, px_per_s=1800.0))
    if args.png and args.sheets:
        for sid, ims in groups.items():
            stack_images(ims).save(os.path.join(args.png, f"_sheet_{sid}.png"))
    if args.json:
        with open(args.json, "w") as fh:
            json.dump(rows, fh, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
