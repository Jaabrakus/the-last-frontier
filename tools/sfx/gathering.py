#!/usr/bin/env python3
"""Gathering family: the felling axe in a standing trunk and in a log on the ground, the mattock on stone, the
hinge wood of a tree tearing as it starts to go, and the tree coming down. Everything is synthesized (modal
bodies, filtered noise, stick-slip trains, grain clouds); no samples.

    python3 tools/sfx/gathering.py                 # every sound, default seed
    python3 tools/sfx/gathering.py --only axe_chop  # one id
    python3 tools/sfx/gathering.py --out /some/dir

Output: audio/sfx/gathering/<id>_<NN>.wav (44.1 kHz, 16-bit mono, -1 dBFS peak, trimmed, short fade-out).
GatherTools plays them itself (like WeatherFx, not through the generated Sfx manifest):
    axe_chop      the bit biting into a standing trunk: a sharp steel-on-wood crack over the trunk's hollow knock
    axe_buck      the same into a log lying on the ground: duller, damped by the ground
    mattock_stone steel on stone: a bright ring, grit and a dull knock of the rock's mass
    tree_crack    the hinge tearing: creaks speeding up into fibre snaps (about 1.6 s)
    tree_fall     the crown rushing down and the trunk hitting the ground: whoosh, boom, branches cracking

Conventions and helpers: dsp.py (only added to, never changed).
"""
from __future__ import annotations

import argparse
import os
import sys
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dsp import (SR, bandpass, db2lin, exp_env, fade_out, finalize, highpass, lowpass, modal_ir, nsamp, pink,  # noqa: E402
                 place, rng, stick_slip_train, strike, taxis, white, write_wav)

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "audio", "sfx", "gathering")


def _seed(seed: int, name: str, v: int) -> np.random.Generator:
    return rng((seed * 1000003 + zlib.crc32(("%s_%d" % (name, v)).encode())) % (2 ** 31))


def _grains(dur: float, n: int, r: np.random.Generator, lo: float, hi: float, decay: float) -> np.ndarray:
    """A cloud of tiny noise clicks (splinters, grit), denser at the start."""
    y = np.zeros(nsamp(dur))
    for _ in range(n):
        t = dur * (r.uniform(0, 1) ** 2.2)
        g = white(nsamp(0.004), r) * exp_env(nsamp(0.004), 0.0008) * np.exp(-t / decay) * r.uniform(0.3, 1.0)
        place(y, g, t)
    return bandpass(y, lo, hi)


def axe_chop(r: np.random.Generator, buck: bool = False) -> np.ndarray:
    dur = 0.45 if not buck else 0.3
    y = np.zeros(nsamp(dur))
    # the trunk's knock: a short woody body (dense, inharmonic modes that die fast; a log on the ground deader)
    base = r.uniform(170, 240) if not buck else r.uniform(130, 180)
    freqs = [base, base * 1.63, base * 2.41, base * 3.37, base * 4.9, base * 6.6]
    k = 1.0 if not buck else 0.6
    taus = [0.028 * k, 0.02 * k, 0.014 * k, 0.01 * k, 0.007 * k, 0.005 * k]
    amps = [1.0, 0.8, 0.6, 0.45, 0.3, 0.2]
    knock = strike(freqs, taus, amps, dur, contact=0.0012, r=r, noise=0.6)
    y += knock * 0.55
    body = bandpass(white(nsamp(0.09), r), 180, 1100) * exp_env(nsamp(0.09), 0.018 * k)
    place(y, body, 0.0, 0.7)
    # the bit: a hard crack of steel shearing fibre (the loudest part)
    crack = bandpass(white(nsamp(0.018), r), 1200, 8000) * exp_env(nsamp(0.018), 0.003)
    place(y, crack, 0.0, 1.6)
    # fibre tear and the chip leaving
    tear = bandpass(white(nsamp(0.1), r), 800, 5000) * exp_env(nsamp(0.1), 0.022)
    place(y, tear, 0.003, 0.5)
    y += _grains(dur, 18, r, 1800, 8000, 0.06) * 0.35
    return finalize(y, peak_db=-1.0, fade=0.05)


def mattock_stone(r: np.random.Generator) -> np.ndarray:
    dur = 0.7
    y = np.zeros(nsamp(dur))
    # the steel's ring: inharmonic partials, short
    f0 = r.uniform(1900, 2600)
    ring = modal_ir([f0, f0 * 1.52, f0 * 2.37, f0 * 3.1], [0.09, 0.06, 0.04, 0.025], [1.0, 0.6, 0.4, 0.25], dur, r)
    y += ring * 0.35
    # the blow: a hard crack
    crack = bandpass(white(nsamp(0.015), r), 1500, 9000) * exp_env(nsamp(0.015), 0.003)
    place(y, crack, 0.0, 1.0)
    # the rock's mass: a dull knock
    knock = strike([r.uniform(160, 240), 410, 780], [0.03, 0.018, 0.01], [1.0, 0.5, 0.3], dur, contact=0.001, r=r)
    y += knock * 0.7
    # grit and flakes falling
    y += _grains(dur, 30, r, 2500, 10000, 0.12) * 0.35
    return finalize(y, peak_db=-1.0, fade=0.08)


def tree_crack(r: np.random.Generator) -> np.ndarray:
    dur = 1.8
    n = nsamp(dur)
    t = taxis(n)
    # creaks: stick-slip slowing into a groan, then speeding up as the hinge goes
    rate = lambda tt: 18.0 + 60.0 * (tt / dur) ** 2
    amp = lambda tt: 0.3 + 0.7 * (tt / dur)
    slips = stick_slip_train(dur, rate, r, jitter=0.35, amp=amp)
    creak = np.zeros(n)
    for f, q in [(r.uniform(260, 340), 12.0), (r.uniform(520, 700), 9.0), (r.uniform(1100, 1400), 7.0)]:
        creak += np.convolve(slips, modal_ir([f], [q / (np.pi * f)], [1.0], 0.05, r), mode="full")[:n]
    y = creak * 0.6
    # fibre snaps, more and louder toward the end
    for k in range(int(r.integers(7, 11))):
        tk = dur * (0.25 + 0.75 * r.uniform(0, 1) ** 0.6)
        s = bandpass(white(nsamp(0.03), r), 800, 6000) * exp_env(nsamp(0.03), 0.006) * (0.4 + 0.8 * tk / dur)
        body = modal_ir([r.uniform(180, 300), r.uniform(600, 900)], [0.04, 0.02], [0.7, 0.3], 0.12, r) * 0.5
        place(y, s, tk, 1.0)
        place(y, body * (0.4 + 0.6 * tk / dur), tk, 0.6)
    y *= np.clip(t / 0.05, 0, 1)
    return finalize(y, peak_db=-1.0, fade=0.1)


def tree_fall(r: np.random.Generator) -> np.ndarray:
    dur = 3.2
    n = nsamp(dur)
    t = taxis(n)
    y = np.zeros(n)
    t_hit = 0.9
    # the crown rushing through the air: rising filtered pink noise
    whoosh = pink(n, r)
    whoosh = bandpass(whoosh, 250, 3500) * np.clip(t / t_hit, 0, 1) ** 2.2 * np.exp(-np.clip(t - t_hit, 0, None) / 0.12)
    y += whoosh * 0.5
    # the boom: the trunk into the ground
    boom = strike([r.uniform(48, 62), r.uniform(95, 120), 190, 330], [0.35, 0.2, 0.1, 0.05], [1.0, 0.6, 0.35, 0.2], 1.6,
                  contact=0.012, r=r, noise=0.5)
    place(y, boom, t_hit, 1.0)
    thud = lowpass(white(nsamp(0.25), r), 300) * exp_env(nsamp(0.25), 0.06)
    place(y, thud, t_hit, 0.8)
    # branches breaking and settling
    crackle = _grains(dur - t_hit, 90, r, 700, 7000, 0.45)
    place(y, crackle, t_hit, 0.9)
    for k in range(6):
        tk = t_hit + r.uniform(0.0, 0.6)
        s = bandpass(white(nsamp(0.05), r), 500, 4000) * exp_env(nsamp(0.05), 0.01)
        place(y, s, tk, r.uniform(0.3, 0.7))
    # a rustle of needles and leaves as it rocks and stills
    rustle = bandpass(pink(n, r), 1500, 8000) * np.exp(-np.clip(t - t_hit, 0, None) / 0.7) * (t > t_hit)
    y += rustle * 0.2
    return finalize(y, peak_db=-1.0, fade=0.3)


SOUNDS = {
    "axe_chop": (4, lambda r: axe_chop(r, False)),
    "axe_buck": (3, lambda r: axe_chop(r, True)),
    "mattock_stone": (4, mattock_stone),
    "tree_crack": (2, tree_crack),
    "tree_fall": (2, tree_fall),
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=1765)
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()
    only = set(filter(None, a.only.split(",")))
    for name, (count, fn) in SOUNDS.items():
        if only and name not in only:
            continue
        for v in range(count):
            x = fn(_seed(a.seed, name, v))
            path = write_wav(os.path.join(a.out, "%s_%02d.wav" % (name, v + 1)), x, seed=v)
            print("wrote %s (%.2f s)" % (os.path.relpath(path, ROOT), len(x) / SR))


if __name__ == "__main__":
    main()
