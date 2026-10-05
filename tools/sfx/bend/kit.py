"""Building blocks for the Tidebreak ring's sounds (tools/sfx/bend/): noise bands, swept whooshes, bubbles, rock ticks,
crackles, thumps, a small room, the loudness measure and the peak limiter. numpy and tools/sfx/dsp.py only.

Every random draw takes the caller's numpy Generator (dsp.rng), so a sound is the same each run for the same seed.
Filters are FFT-based (dsp.fft_band, dsp.fft_filter, dsp.tv_filter): dsp's biquads run per sample in Python, too slow for
the crowd's many voices.
"""
from __future__ import annotations

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import dsp  # noqa: E402

SR = dsp.SR


def N(d: float) -> int:
    return dsp.nsamp(d)


def T(n: int) -> np.ndarray:
    return dsp.taxis(n)


def noise(n: int, r: np.random.Generator) -> np.ndarray:
    return r.standard_normal(n)


def band(x: np.ndarray, lo: float | None, hi: float | None, order: int = 2) -> np.ndarray:
    return dsp.fft_band(x, lo, hi, order)


def pad_to(x: np.ndarray, n: int) -> np.ndarray:
    return x[:n] if len(x) >= n else np.concatenate([x, np.zeros(n - len(x))])


def mix(n: int, *parts) -> np.ndarray:
    """Sum of (signal, start s, gain) parts into n samples (overhang dropped)."""
    y = np.zeros(n)
    for x, t, g in parts:
        dsp.place(y, x, t, g)
    return y


# ------------------------------------------------------------------------------------------------ envelopes
def hump(n: int, peak_t: float, fall_tau: float, rise_pow: float = 2.0) -> np.ndarray:
    """Rises (sin^pow) to 1 at peak_t, then falls exponentially with fall_tau."""
    t = T(n)
    up = np.sin(0.5 * np.pi * np.clip(t / max(peak_t, 1e-4), 0.0, 1.0)) ** rise_pow
    down = np.exp(-np.maximum(t - peak_t, 0.0) / fall_tau)
    return np.where(t < peak_t, up, down)


def plateau(n: int, attack: float, hold: float, release: float) -> np.ndarray:
    """Raised-cosine attack, a hold at 1, a raised-cosine release; zero after."""
    t = T(n)
    e = np.zeros(n)
    a = t < attack
    e[a] = 0.5 - 0.5 * np.cos(np.pi * t[a] / max(attack, 1e-4))
    h = (t >= attack) & (t < attack + hold)
    e[h] = 1.0
    rl = (t >= attack + hold) & (t < attack + hold + release)
    e[rl] = 0.5 + 0.5 * np.cos(np.pi * (t[rl] - attack - hold) / max(release, 1e-4))
    return e


def wobble(n: int, rate: float, depth: float, r: np.random.Generator) -> np.ndarray:
    """1 + depth * a wandering control (turbulence, flutter), never below 0."""
    return np.maximum(1.0 + depth * dsp.smooth_noise(n, rate, r), 0.0)


# ------------------------------------------------------------------------------------------------ swept noise
def sweep(r: np.random.Generator, dur: float, times, freqs, width_oct: float = 0.9, n_fft: int = 1024,
          hop: int = 128, src: np.ndarray | None = None) -> np.ndarray:
    """Noise through a band (a Gaussian in log frequency, width_oct wide at one sigma) whose centre follows
    (times, freqs): the body of every whoosh, gust and rush. Unit-ish RMS before any envelope."""
    n = N(dur)
    x = noise(n, r) if src is None else pad_to(src, n)
    tp = np.asarray(times, dtype=float)
    fp = np.log2(np.asarray(freqs, dtype=float))

    def g(t, f):
        c = np.interp(t, tp, fp)
        return np.exp(-0.5 * ((np.log2(np.maximum(f, 20.0)) - c) / width_oct) ** 2)

    y = dsp.tv_filter(x, g, n_fft, hop)
    return y / (np.std(y) + 1e-12)


def lowpass_sweep(r: np.random.Generator, dur: float, times, cutoffs, order: int = 2, src: np.ndarray | None = None,
                  n_fft: int = 1024, hop: int = 128) -> np.ndarray:
    """Noise (or src) through a lowpass whose cutoff follows (times, cutoffs): the opening and closing of a whoomph."""
    n = N(dur)
    x = noise(n, r) if src is None else pad_to(src, n)
    tp = np.asarray(times, dtype=float)
    cp = np.log2(np.asarray(cutoffs, dtype=float))

    def g(t, f):
        c = 2.0 ** np.interp(t, tp, cp)
        return 1.0 / np.sqrt(1.0 + (f / c) ** (2 * order))

    return dsp.tv_filter(x, g, n_fft, hop)


# ------------------------------------------------------------------------------------------------ events
def thump(f0: float, f1: float, tau: float, dur: float, glide: float = 0.04, attack: float = 0.002) -> np.ndarray:
    """A sine falling from f0 to f1 (glide s): the weight under a hit."""
    n = N(dur)
    t = T(n)
    f = f1 + (f0 - f1) * np.exp(-t / glide)
    return np.sin(2.0 * np.pi * np.cumsum(f) / SR) * dsp.ar_env(n, attack, tau)


def bubble(r: np.random.Generator, f0: float, rise: float | None = None) -> np.ndarray:
    """One bubble's ring (a rising chirp, Minnaert-like): the bloop of water."""
    tau = min(max(12.0 / f0, 0.004), 0.035)
    n = N(tau * 6.0)
    t = T(n)
    k = r.uniform(0.15, 0.6) if rise is None else rise
    f = f0 * (1.0 + k * t / tau)
    return np.sin(2.0 * np.pi * np.cumsum(f) / SR) * np.exp(-t / tau) * (1.0 - np.exp(-t / 0.0004))


def bubbles(r: np.random.Generator, n: int, count: int, t0: float, t1: float, f_lo: float, f_hi: float,
            decay: float | None = None, gain: float = 1.0) -> np.ndarray:
    """`count` bubbles between t0 and t1 (denser early when decay is given), log-uniform in f_lo..f_hi."""
    y = np.zeros(n)
    for _ in range(count):
        t = t0 + (r.exponential(decay) if decay else r.uniform(0.0, t1 - t0))
        if t > t1:
            continue
        f = math.exp(r.uniform(math.log(f_lo), math.log(f_hi)))
        dsp.place(y, bubble(r, f), t, gain * r.uniform(0.3, 1.0) * (600.0 / f) ** 0.3)
    return y


def tick(r: np.random.Generator, f_lo: float = 1500.0, f_hi: float = 6000.0, length: float = 0.05) -> np.ndarray:
    """A grain of grit or a pebble: a tiny struck stone (three inharmonic modes, very short)."""
    f = r.uniform(f_lo, f_hi)
    freqs = [f, f * r.uniform(1.4, 1.8), f * r.uniform(2.2, 2.9)]
    taus = [r.uniform(0.004, 0.014), r.uniform(0.003, 0.009), r.uniform(0.002, 0.006)]
    return dsp.strike(freqs, taus, [1.0, 0.6, 0.35], length, contact=0.0003, r=r, noise=0.6)


def grit(r: np.random.Generator, n: int, count: int, t0: float, t1: float, f_lo: float = 1500.0,
         f_hi: float = 6000.0, decay: float | None = None, gain: float = 1.0) -> np.ndarray:
    """A scatter of ticks (debris falling, grit settling)."""
    y = np.zeros(n)
    for _ in range(count):
        t = t0 + (r.exponential(decay) if decay else r.uniform(0.0, t1 - t0))
        if t > t1:
            continue
        dsp.place(y, tick(r, f_lo, f_hi), t, gain * r.uniform(0.2, 1.0))
    return y


def rock(r: np.random.Generator, f0: float, dur: float = 0.35, ring: float = 1.0, contact: float = 0.0012,
         rough: float = 0.6) -> np.ndarray:
    """A stone struck: six inharmonic modes from f0, short-lived (a dull knock, not a bell)."""
    ratios = np.array([1.0, 1.71, 2.43, 3.27, 4.61, 5.93]) * r.uniform(0.96, 1.04, 6)
    taus = np.array([0.07, 0.05, 0.036, 0.026, 0.018, 0.012]) * ring * r.uniform(0.8, 1.2, 6)
    amps = np.array([1.0, 0.7, 0.55, 0.4, 0.3, 0.2]) * r.uniform(0.6, 1.0, 6)
    return dsp.strike(f0 * ratios, taus, amps, dur, contact=contact, r=r, noise=rough)


def crack(r: np.random.Generator, sharp: float = 1.0, count: int = 5, spread: float = 0.02) -> np.ndarray:
    """A crack: a cluster of very short broadband bursts (a stone or ice splitting), brightest first."""
    n = N(spread + 0.03)
    y = np.zeros(n)
    for i in range(count):
        m = N(r.uniform(0.0008, 0.004))
        b = noise(m, r) * dsp.exp_env(m, r.uniform(0.0004, 0.0015))
        dsp.place(y, b, r.uniform(0.0, spread) * (i > 0), (1.0 if i == 0 else r.uniform(0.25, 0.7)))
    return band(y, 300.0 * sharp, 12000.0, 2)


def crackle(r: np.random.Generator, bright: float = 1.0) -> np.ndarray:
    """A fire crackle: a few ms of band-passed noise with a very fast decay, sometimes doubled."""
    m = N(r.uniform(0.004, 0.016))
    x = noise(m, r) * dsp.exp_env(m, r.uniform(0.0008, 0.0035))
    x = band(x, r.uniform(900.0, 2400.0), r.uniform(4000.0, 9000.0) * bright, 2)
    if r.random() < 0.25:
        x = mix(len(x) + N(0.02), (x, 0.0, 1.0), (x, r.uniform(0.006, 0.018), 0.6))
    return x


def events(r: np.random.Generator, n: int, rate) -> list:
    """Times (s) of random events at `rate` per second over n samples (a number, or an array per sample): a Poisson
    process drawn at the top rate and thinned where the rate is lower, so a rate rising from nothing is followed."""
    rate_a = np.broadcast_to(np.asarray(rate, dtype=float), (n,))
    top = float(rate_a.max())
    out = []
    if top <= 0.0:
        return out
    t = r.exponential(1.0 / top)
    while t < n / SR:
        if r.random() * top < float(rate_a[min(N(t), n - 1)]):
            out.append(t)
        t += r.exponential(1.0 / top)
    return out


def crackles(r: np.random.Generator, n: int, rate, gain: float = 1.0, bright: float = 1.0) -> np.ndarray:
    """Crackles at `rate` per second (a number, or an array per sample: the envelope of the burning)."""
    y = np.zeros(n)
    for t in events(r, n, rate):
        dsp.place(y, crackle(r, bright), t, gain * r.uniform(0.15, 1.0) ** 1.5)
    return y


# ------------------------------------------------------------------------------------------------ space, level
def room(x: np.ndarray, r: np.random.Generator, rt60: float = 0.8, wet: float = 0.15, pre: float = 0.015,
         bright: float = 4000.0) -> np.ndarray:
    """A small open-air space: x plus a decaying noise tail (wet: the tail's level against the dry); longer by the tail."""
    m = N(rt60 * 1.1)
    t = T(m)
    ir = noise(m, r) * np.exp(-6.91 * t / rt60)
    ir = band(ir, 120.0, bright, 1)
    ir[:N(pre)] = 0.0
    ir /= math.sqrt(float(np.sum(ir * ir))) + 1e-12
    y = np.concatenate([x, np.zeros(m)])
    w = pad_to(dsp.fftconvolve(x, ir), len(y))
    return y + wet * w


def kweight(x: np.ndarray) -> np.ndarray:
    """A loudness weighting near K (BS.1770): a 60 Hz high-pass and a +4 dB shelf over about 1.5 kHz."""
    shelf = dsp.db2lin(4.0) - 1.0

    def mag(f):
        return dsp.mag_highpass(f, 60.0, 2) * (1.0 + shelf / (1.0 + (1500.0 / np.maximum(f, 1.0)) ** 2))

    return dsp.fft_filter(x, mag, minphase=False)[:len(x)]


def loudness_db(x: np.ndarray, win: float = 0.4) -> float:
    """Short-term loudness: the loudest `win` s of the K-weighted signal's mean square, dB (full-scale sine ~ -3)."""
    y = kweight(x)
    p = y * y
    w = N(win)
    if len(p) <= w:
        return 10.0 * math.log10(max(float(np.mean(p)), 1e-20))
    cs = np.concatenate([[0.0], np.cumsum(p)])
    m = (cs[w:] - cs[:-w]) / w
    return 10.0 * math.log10(max(float(m.max()), 1e-20))


def limit(x: np.ndarray, ceiling_db: float = -1.0, look: float = 0.003) -> tuple[np.ndarray, float]:
    """A look-ahead peak limiter to ceiling_db dBFS; returns (signal, the deepest gain cut in dB, <= 0)."""
    c = dsp.db2lin(ceiling_db)
    a = np.abs(x) if x.ndim == 1 else np.max(np.abs(x), axis=1)     # stereo: both channels cut together
    need = np.minimum(1.0, c / np.maximum(a, 1e-12))
    if need.min() >= 1.0:
        return x, 0.0
    w = max(N(look), 1)
    padded = np.concatenate([np.ones(w), need, np.ones(w)])
    g = np.lib.stride_tricks.sliding_window_view(padded, 2 * w + 1).min(axis=1)
    g = np.convolve(np.pad(g, w, mode="edge"), np.ones(w) / w, mode="same")[w:-w]
    g = np.minimum(g, need)
    return x * (g if x.ndim == 1 else g[:, None]), dsp.lin2db(float(g.min()))


def pan(x: np.ndarray, p: float) -> np.ndarray:
    """Equal-power pan of mono x: p -1 (left) .. 1 (right) -> (n, 2)."""
    a = (p + 1.0) * math.pi / 4.0
    return np.stack([x * math.cos(a), x * math.sin(a)], axis=1)
