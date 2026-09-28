#!/usr/bin/env python3
"""Fire family for Frontier (push n01b): the hand torch of fat-pine splints.

Usage (from the project root):
  python3 tools/sfx/fire.py                 # default seed, every sound
  python3 tools/sfx/fire.py --seed 3        # another take
  python3 tools/sfx/fire.py --out /tmp/fire

Output: audio/sfx/fire/<id>_<NN>.wav, 44.1 kHz 16-bit mono.
  torch_crackle_loop  8 s loop: the soft roar of a resinous flame (low, slowly breathing filtered noise) with
                      the crackle of pitch pine (short bright ticks, Poisson ~7/s, a few louder resin pops and
                      hisses); generated on a circle (events wrap, circular filtering) so it loops seamlessly;
                      RIFF 'smpl' forward loop over the whole file
  torch_ignite        (2) the splints catching: a breathy whoosh swelling over 0.5 s with the first crackles
  torch_snuff         (2) the flame beaten out / smothered: a short falling hiss and a soft thump
  torch_toss          (2) the torch swung and let go: an air swish through the flame (flutter), 0.35 s
Levels: the loop peaks at -1 dBFS (its level is set per frame in code from the fire's strength); the one-shots
are peak-normalised to -3 dBFS. Game-side defaults are in tools/sfx/gen_manifest.py (OVERRIDES).
Everything is synthesised with numpy (dsp.py); nothing is recorded or downloaded.
"""
from __future__ import annotations

import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dsp  # noqa: E402

SR = dsp.SR
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "audio", "sfx", "fire")


def circ_lowpass(x: np.ndarray, fc: float) -> np.ndarray:
    """Zero-phase circular low-pass (FFT brick with a soft edge): the signal stays periodic."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    h = 1.0 / np.sqrt(1.0 + (f / fc) ** 4)
    return np.fft.irfft(np.fft.rfft(x) * h, n)


def circ_band(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    h = (1.0 / np.sqrt(1.0 + (lo / np.maximum(f, 1.0)) ** 4)) / np.sqrt(1.0 + (f / hi) ** 4)
    return np.fft.irfft(np.fft.rfft(x) * h, n)


def crackle(r: np.random.Generator, bright: float = 1.0) -> np.ndarray:
    """One crackle: a few ms of band-passed noise with a very fast decay, sometimes a double tick."""
    n = dsp.nsamp(r.uniform(0.004, 0.018))
    x = dsp.white(n, r) * dsp.exp_env(n, r.uniform(0.0008, 0.004))
    x = dsp.bandpass(x, r.uniform(900, 2500), r.uniform(4000, 9000) * bright)
    if r.random() < 0.25:
        m = dsp.nsamp(r.uniform(0.006, 0.02))
        y = np.zeros(n + m)
        y[:n] += x
        y[m:m + n] += x * r.uniform(0.3, 0.7)
        x = y
    return x


def resin_pop(r: np.random.Generator) -> np.ndarray:
    """A louder pop of a resin pocket, with a short hiss of escaping gas after it."""
    n = dsp.nsamp(0.35)
    x = np.zeros(n)
    k = dsp.nsamp(0.012)
    x[:k] += dsp.bandpass(dsp.white(k, r), 300, 5000) * dsp.exp_env(k, 0.002) * 2.0
    h = dsp.white(n, r) * dsp.ar_env(n, 0.01, r.uniform(0.05, 0.12))
    x += dsp.bandpass(h, 2500, 9000) * 0.25
    return x


def crackle_loop(seed: int, dur: float = 8.0) -> np.ndarray:
    r = dsp.rng(seed)
    n = dsp.nsamp(dur)
    t = dsp.taxis(n)
    # the roar: low noise, breathing slowly (periodic modulation on the loop's circle)
    roar = circ_lowpass(dsp.white(n, r), 380.0)
    roar = circ_band(roar, 60.0, 380.0)
    breath = 0.75 + 0.15 * np.sin(2 * np.pi * t / dur * 3 + 0.7) + 0.1 * np.sin(2 * np.pi * t / dur * 7 + 2.1)
    roar *= breath / (np.std(roar) + 1e-9) * 0.09
    # flutter: mid noise gated fast (the flame's tongues)
    flut = circ_band(dsp.white(n, r), 400.0, 1800.0)
    gate = circ_lowpass(np.abs(dsp.white(n, r)), 14.0)
    flut *= gate / (np.std(flut * gate) + 1e-9) * 0.02
    x = roar + flut
    # crackles on the circle
    rate = 7.0
    k = r.poisson(rate * dur)
    for _ in range(k):
        c = crackle(r)
        i = int(r.uniform(0, n))
        g = r.uniform(0.05, 0.35) * (1.6 if r.random() < 0.08 else 1.0)
        idx = (i + np.arange(len(c))) % n
        np.add.at(x, idx, c * g)
    for _ in range(r.poisson(0.5 * dur)):
        p = resin_pop(r)
        i = int(r.uniform(0, n))
        idx = (i + np.arange(len(p))) % n
        np.add.at(x, idx, p * r.uniform(0.2, 0.45))
    x = x - np.mean(x)
    return dsp.peak_norm(x, dsp.db2lin(-1.0))


def ignite(seed: int) -> np.ndarray:
    r = dsp.rng(seed)
    n = dsp.nsamp(1.1)
    t = dsp.taxis(n)
    w = dsp.pink(n, r)
    env = np.clip(t / 0.45, 0, 1) ** 1.5 * np.exp(-np.maximum(t - 0.55, 0) / 0.25)
    whoosh = dsp.svf(w, 250 + 2200 * np.clip(t / 0.5, 0, 1), 0.9, "lp") * env
    x = whoosh / (np.max(np.abs(whoosh)) + 1e-9) * 0.8
    for _ in range(r.integers(5, 10)):
        c = crackle(r)
        dsp.place(x, c, r.uniform(0.25, 0.95), r.uniform(0.1, 0.35))
    x = dsp.fade_out(dsp.dc_block(x), 0.1)
    return dsp.peak_norm(x, dsp.db2lin(-3.0))


def snuff(seed: int) -> np.ndarray:
    r = dsp.rng(seed)
    n = dsp.nsamp(0.7)
    t = dsp.taxis(n)
    h = dsp.white(n, r) * dsp.ar_env(n, 0.005, 0.16)
    hiss = dsp.svf(h, 5000 - 3500 * np.clip(t / 0.5, 0, 1), 0.8, "lp")
    hiss = dsp.highpass(hiss, 700)
    k = dsp.nsamp(0.09)
    thump = dsp.lowpass(dsp.white(k, r), 220) * dsp.exp_env(k, 0.02) * 3.0
    x = hiss * 0.6
    dsp.place(x, thump, 0.0, 1.0)
    x = dsp.fade_out(dsp.dc_block(x), 0.08)
    return dsp.peak_norm(x, dsp.db2lin(-3.0))


def toss(seed: int) -> np.ndarray:
    r = dsp.rng(seed)
    n = dsp.nsamp(0.45)
    t = dsp.taxis(n)
    env = np.sin(np.pi * np.clip(t / 0.32, 0, 1)) ** 2
    sw = dsp.svf(dsp.pink(n, r), 600 + 1600 * env, 1.2, "bp") * env
    flutter = 1.0 + 0.5 * np.sin(2 * np.pi * r.uniform(24, 34) * t)
    x = sw * flutter
    for _ in range(r.integers(2, 5)):
        dsp.place(x, crackle(r), r.uniform(0.05, 0.35), r.uniform(0.05, 0.15))
    x = dsp.fade_out(dsp.dc_block(x), 0.06)
    return dsp.peak_norm(x, dsp.db2lin(-3.0))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=1758)
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    loop = crackle_loop(a.seed)
    dsp.write_wav_loop(os.path.join(a.out, "torch_crackle_loop_01.wav"), loop, seed=a.seed)
    for i in range(2):
        dsp.write_wav(os.path.join(a.out, "torch_ignite_%02d.wav" % (i + 1)), ignite(a.seed + 10 + i), seed=i)
        dsp.write_wav(os.path.join(a.out, "torch_snuff_%02d.wav" % (i + 1)), snuff(a.seed + 20 + i), seed=i)
        dsp.write_wav(os.path.join(a.out, "torch_toss_%02d.wav" % (i + 1)), toss(a.seed + 30 + i), seed=i)
    print("wrote", sorted(os.listdir(a.out)))


if __name__ == "__main__":
    main()
