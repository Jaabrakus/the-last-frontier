#!/usr/bin/env python3
"""Impacts family: arrows and lead balls striking wood, straw, dirt, grass and
stone, plus a passing-ball whizz, and the felling axe's melee (two axes clashing,
a cut crunching into a body to the spine). Everything is synthesized (noise, causal IIR
filters, modal resonators, grain clouds, varispeed); no samples.

    python3 tools/sfx/impacts.py                  # every sound, default seed
    python3 tools/sfx/impacts.py --seed 7         # a fresh set of variations
    python3 tools/sfx/impacts.py --only arrow_hit_wood,ball_hit_stone
    python3 tools/sfx/impacts.py --out /some/dir  # write elsewhere
    python3 tools/sfx/impacts.py --preview x.wav  # also write one audition file

Output: audio/sfx/impacts/<id>_<NN>.wav (44.1 kHz, 16-bit mono, -1 dBFS peak,
silence trimmed, short fade-out) and impacts_manifest.json with the playback
settings the game should use (bus, unit_size, volume, speed scaling, pitch).

Conventions used below
- "decay X ms" / tau of a mode or envelope is its exponential time constant
  (amplitude e^-t/tau).
- "N ms" for a noise layer is its whole audible length (it is tapered to zero there).
- Relative levels ("buzz at -11 dB") are layer peaks relative to the peak of the
  main impact layers of the same sound.
- Variants are seeded from (seed, id, variant), so a run is reproducible; the
  main character parameters (thud pitch, resonance centres, buzz pitch, noise
  band, ...) are spread across the variants so no two sound alike.
- Soil and straw thuds are built from resonant, band-limited noise with only a
  quiet low sine under them, so they read on small speakers (most energy sits
  between 150 Hz and 3 kHz), and every sparse grain tail rides on a quiet noise
  bed that follows the grain density, so no tail drops to digital silence.
- Ball hits are made denser than arrow hits (tanh soft saturation of the first
  30 ms before the peak normalization, SOUNDS[...]["densify"] dB of momentary
  loudness at the same peak) and the arrow volume_db values sit lower, so in
  game a ball lands ~8-10 dB louder than an arrow on the same surface.

Shared helpers come from dsp.py (never edited here); impact-specific DSP
(grain clouds, shaft buzz, wood bodies, ricochet, varispeed, densifier) lives in
this file.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys
import zlib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import dsp  # noqa: E402
from dsp import SR, db2lin, nsamp, peak_norm, place, taxis  # noqa: E402

PROJECT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(PROJECT, "audio", "sfx", "impacts")


# =========================================================================== helpers

def band(x: np.ndarray, lo: float | None = None, hi: float | None = None, order: int = 2) -> np.ndarray:
    """Causal Butterworth band limit; lo/hi may be None."""
    if lo:
        x = dsp.highpass(x, lo, order)
    if hi:
        x = dsp.lowpass(x, hi, order)
    return x


def unit(x: np.ndarray) -> np.ndarray:
    return peak_norm(np.asarray(x, dtype=float), 1.0)


def mix(*layers) -> np.ndarray:
    """Sum (signal, gain) pairs of different lengths."""
    y = np.zeros(max(len(s) for s, _ in layers))
    for s, g in layers:
        y[:len(s)] += g * s
    return y


def spread(r: np.random.Generator, slot: int, nvar: int, lo: float, hi: float) -> float:
    """A value in [lo, hi] from this variant's own slice, so variants differ."""
    return lo + (hi - lo) * (slot + r.uniform(0.15, 0.85)) / nvar


def logu(r: np.random.Generator, lo: float, hi: float, size=None):
    return np.exp(r.uniform(math.log(lo), math.log(hi), size))


def seg_env(n: int, attack: float, length: float, tau: float | None = None, taper: float = 0.35) -> np.ndarray:
    """Raised-cosine attack, exponential decay (tau, default length/4), tapered to
    exactly zero at `length` (the last `taper` fraction is a half-cosine)."""
    t = taxis(n)
    env = dsp.ar_env(n, attack, tau if tau else length / 4.0)
    t0 = attack + (length - attack) * (1.0 - taper)
    m = (t >= t0) & (t < length)
    env[m] *= 0.5 + 0.5 * np.cos(np.pi * (t[m] - t0) / max(length - t0, 1e-6))
    env[t >= length] = 0.0
    return env


def noise_layer(r, length, lo, hi, attack, tau=None, order=2, taper=0.35):
    """Band-limited noise burst lasting `length` seconds."""
    n = nsamp(length + 0.004)
    return band(dsp.white(n, r), lo, hi, order) * seg_env(n, attack, length, tau, taper)


def resonant_noise(r, length, lo, hi, centers, qs, tau, attack=0.0008, direct=0.3, order=2,
                   punch=0.0, emph=0.0, emph_tc=0.004) -> np.ndarray:
    """A noisy 'thup': an enveloped noise burst band-limited to lo..hi, then
    coloured by a few broad (Q 2-4) resonances, as a soft body (soil, a straw
    bale) gives it. `punch` boosts the first ~3 ms of the excitation and `emph`
    the first ~emph_tc of the output (the resonances lag the excitation by a
    few ms), so the thud peaks within a few ms of contact instead of wherever
    the noise happens to be largest. The resonances ring a few ms past `length`."""
    n = nsamp(length + 0.015)
    env = seg_env(n, attack, length, tau) * (1.0 + punch * np.exp(-taxis(n) / 0.003))
    x = band(dsp.white(n, r) * env, lo, hi, order)
    y = direct * unit(x)
    for fc, q in zip(centers, qs):
        y += r.uniform(0.6, 1.0) * unit(dsp.resonator(x, fc, q))
    if emph > 0:
        y *= 1.0 + emph * np.exp(-taxis(n) / emph_tc)
    return unit(dsp.fade_out(y, 0.012))


def decay_times(r, count: int, t0: float, length: float, tau: float) -> np.ndarray:
    """Event times in [t0, t0+length) whose density falls as exp(-(t-t0)/tau)."""
    u = r.uniform(0.0, 1.0, count)
    c = 1.0 - math.exp(-length / tau)
    return np.sort(t0 - tau * np.log(1.0 - u * c))


def crackle_amps(r, times, t0: float, tau: float, sigma: float = 0.55) -> np.ndarray:
    """Log-normal grain strengths (a few loud snaps among many small ones), decaying."""
    return np.exp(r.normal(0.0, sigma, len(times))) * np.exp(-(np.asarray(times) - t0) / tau)


def grain_cloud(r, length, times, amps, lo, hi, glen=(0.0002, 0.0008), order=4) -> np.ndarray:
    """Crackle: short decaying noise grains at `times` (s) with strengths `amps`,
    band-limited to lo..hi Hz as a whole (one 4th-order filter pass for the cloud).
    Each grain gets a 3-sample fade-in so it does not start on a hard step."""
    n = nsamp(length)
    y = np.zeros(n)
    for t, a in zip(times, amps):
        i = int(t * SR)
        if i < 0 or i >= n:
            continue
        L = max(int(r.uniform(*glen) * SR), 3)
        g = r.standard_normal(L) * np.exp(-np.arange(L) / (L / 3.0))
        k = min(3, L // 3)
        if k > 0:
            g[:k] *= np.arange(1, k + 1) / (k + 1.0)
        g /= np.max(np.abs(g)) + 1e-12
        k = min(L, n - i)
        y[i:i + k] += a * g[:k]
    return band(y, lo, hi, order)


def density_bed(r, n: int, times, amps, lo: float, hi: float, smooth: float | None = None) -> np.ndarray:
    """A continuous noise bed (unit peak) whose level follows the density of a grain
    cloud, so a sparse tail never falls to digital silence between its grains. The
    smoothing window follows the mean grain spacing (40-150 ms)."""
    times = np.asarray(times, dtype=float)
    hist = np.zeros(n)
    idx = (times * SR).astype(int)
    ok = (idx >= 0) & (idx < n)
    np.add.at(hist, idx[ok], np.asarray(amps, dtype=float)[ok] if np.ndim(amps) else amps)
    gaps = np.diff(np.sort(times)) if len(times) > 1 else np.array([0.05])
    if smooth is None:
        smooth = float(np.clip(2.5 * np.mean(gaps), 0.04, 0.15))
    wide = float(np.clip(2.2 * np.max(gaps), smooth, 0.3))

    def sm(width):
        w = np.hanning(max(nsamp(width), 3))
        d = np.maximum(np.convolve(hist, w / w.sum(), mode="same"), 0.0)
        return d / (d.max() + 1e-12)
    dens = np.maximum(sm(smooth), 0.35 * sm(wide))
    return unit(band(dsp.white(n, r), lo, hi, 4) * dens ** 0.6)


def rough_texture(r, n: int, rate: float, floor: float = 0.25, grain: float = 0.0015) -> np.ndarray:
    """Granular amplitude texture (fibres snapping, blades flicking): random
    pulses at about `rate` per second smeared over `grain` s, in [floor, 1+floor]."""
    imp = np.zeros(n)
    count = max(int(rate * n / SR), 1)
    imp[r.integers(0, n, count)] += r.uniform(0.2, 1.0, count)
    k = max(nsamp(grain), 2)
    win = np.exp(-np.arange(k) / (k / 3.5))
    m = np.convolve(imp, win)[:n]
    return floor + m / (m.max() + 1e-12)


def varispeed(x: np.ndarray, rate: np.ndarray) -> np.ndarray:
    """Read x with a per-output-sample playback rate (1 = normal) using cubic
    Hermite interpolation; len(output) = len(rate)."""
    pos = np.concatenate([[0.0], np.cumsum(rate[:-1])])
    pos = np.clip(pos, 0.0, len(x) - 3.0)
    i = np.floor(pos).astype(int)
    f = pos - i
    xm1 = x[np.maximum(i - 1, 0)]
    x0, x1, x2 = x[i], x[i + 1], x[i + 2]
    c1 = 0.5 * (x1 - xm1)
    c2 = xm1 - 2.5 * x0 + 2.0 * x1 - 0.5 * x2
    c3 = 0.5 * (x2 - xm1) + 1.5 * (x0 - x1)
    return ((c3 * f + c2) * f + c1) * f + x0


# --------------------------------------------------------------------------- loudness / density

def kweight(x: np.ndarray) -> np.ndarray:
    """Approximate ITU-R BS.1770 K-weighting (high shelf +4 dB near 1.7 kHz, 38 Hz highpass)."""
    y = dsp.biquad(x, *dsp.biquad_coeffs("highshelf", 1681.97, 0.7072, 4.0))
    return dsp.biquad(y, *dsp.biquad_coeffs("hp", 38.14, 0.5003))


def momentary_lufs(x: np.ndarray) -> float:
    """Max momentary loudness (400 ms window, approx. K-weighted), LUFS."""
    y = kweight(np.asarray(x, dtype=float))
    w = nsamp(0.4)
    c = np.concatenate([[0.0], np.cumsum(np.concatenate([y * y, np.zeros(w)]))])
    return -0.691 + 10.0 * math.log10(float(np.max(c[w:] - c[:-w])) / w + 1e-20)


def densify(x: np.ndarray, gain_db: float, win: float = 0.03, xfade: float = 0.01,
            max_drive: float = 3.0) -> np.ndarray:
    """Raise momentary loudness by about `gain_db` at the same peak: soft-saturate
    (tanh) the first `win` s, where the impact's peaks are, and crossfade back to
    the dry signal over `xfade` s. The tanh drive (<= max_drive) is found by
    bisection. Instantaneous saturation cuts the peaks without a gain-reduction
    release, so the body/tail balance barely moves. Returns a unit-peak signal."""
    x = unit(x)
    base = momentary_lufs(x)
    w = np.clip((win + xfade - taxis(len(x))) / xfade, 0.0, 1.0)

    def shaped(d):
        return unit(w * np.tanh(d * x) / d + (1.0 - w) * x)
    lo, hi = 0.3, max_drive
    for _ in range(14):
        mid = 0.5 * (lo + hi)
        if momentary_lufs(shaped(mid)) - base < gain_db:
            lo = mid
        else:
            hi = mid
    return shaped(hi)


# =========================================================================== building blocks

def tock(r, lo=1500.0, hi=6000.0) -> np.ndarray:
    """~1 ms hard-tip transient: a noise snap in lo..hi plus two very short tip modes."""
    n = nsamp(0.006)
    t = taxis(n)
    burst = dsp.white(n, r) * np.exp(-t / 0.00025) * (t < 0.001)
    burst[0] = 3.0 * np.sign(r.uniform(-1, 1))
    snap = band(burst, lo, hi, 2)
    tip = dsp.modal_ir(r.uniform(lo * 1.2, min(hi * 0.75, 4500.0), 2), r.uniform(0.0004, 0.0009, 2),
                       [1.0, r.uniform(0.4, 0.8)], 0.006, r)
    return unit(0.75 * unit(snap) + 0.5 * unit(tip))


def broadband_crack(r, length=0.0005, tau=0.00012, hp=150.0) -> np.ndarray:
    """Sub-millisecond broadband crack (a burst with a hard first sample)."""
    n = nsamp(0.004)
    t = taxis(n)
    b = dsp.white(n, r) * np.exp(-t / tau) * (t < length)
    b[0] = 3.5 * np.sign(r.uniform(-1, 1))
    return unit(band(b, hp, None, 2))


def wood_modes(r, count, f_lo, f_hi, tau_lo, tau_hi, detune=(0.003, 0.012)):
    """Timber resonance modes: `count` inharmonic modes in f_lo..f_hi. Higher modes
    lose energy faster (tau from tau_hi down to tau_lo); each mode is a
    near-degenerate pair detuned by `detune` (relative). Returns (freqs, taus, amps)."""
    for _ in range(40):
        f = np.sort(logu(r, f_lo, f_hi, count))
        if count < 2 or np.min(f[1:] / f[:-1]) > 1.12:
            break
    pos = (np.log(f) - math.log(f_lo)) / (math.log(f_hi) - math.log(f_lo))
    taus = np.clip((tau_hi - (tau_hi - tau_lo) * pos) * r.uniform(0.9, 1.1, count), tau_lo, tau_hi)
    amps = r.uniform(0.5, 1.0, count) * (f / f[0]) ** -0.35
    F, T, A = [], [], []
    for fi, ti, ai in zip(f, taus, amps):
        d = r.uniform(*detune)
        w = r.uniform(0.55, 0.75)
        F += [fi * (1 - d / 2), fi * (1 + d / 2)]
        T += [ti, ti * r.uniform(0.75, 1.0)]
        A += [ai * w, ai * (1 - w)]
    return F, T, A


def wood_body(r, modes, length, contact, rough=0.35) -> np.ndarray:
    """Strike the (freqs, taus, amps) modes from wood_modes with a `contact`-long,
    `rough`-noisy mallet pulse."""
    F, T, A = modes
    return unit(dsp.strike(F, T, A, length, contact=contact, r=r, noise=rough))


def thwock(r, count, f_lo=800.0, f_hi=3000.0, tau=(0.006, 0.015), noise_band=(800.0, 2500.0),
           noise_tau=0.010) -> np.ndarray:
    """The crisp mid 'thwock' of a hard point driving into timber: a few short
    modes in f_lo..f_hi plus a noise burst in noise_band (tau noise_tau)."""
    L = 0.09
    f = logu(r, f_lo, f_hi, count)
    modes = dsp.strike(f, r.uniform(*tau, count), r.uniform(0.4, 1.0, count), L, contact=0.0003, r=r, noise=0.5)
    nz = noise_layer(r, 6 * noise_tau, noise_band[0], noise_band[1], attack=0.0003, tau=noise_tau)
    return unit(mix((unit(modes), 1.0), (unit(nz), 0.8)))


def soft_ir(r, lo=400.0, hi=2500.0, tau=0.0015) -> np.ndarray:
    """Impulse response of a soft, absorbent contact (straw, soil): a tiny damped noise tap."""
    n = nsamp(8 * tau)
    return unit(band(dsp.white(n, r) * np.exp(-taxis(n) / tau), lo, hi, 2))


def shaft_buzz(r, length, f0, tau, rattle=0.3, tilt=1.1, hf_damp=0.08, rise=0.005, jitter=(0.02, 0.04),
               stretch=0.004, am_rate=(9.0, 14.0), am_depth=(0.5, 0.7), skip=(0.2, 0.3), body_ir=None,
               fmax=8000.0, radiate=None) -> np.ndarray:
    """Quivering stuck arrow ('thrrr-um').

    - A partial series on f0 stretched like a stiff shaft, f_k = k f0 (1 + stretch k^2),
      upper partials dying sooner; the fundamental amplitude decays with `tau` and the
      pitch settles a few percent as the swing shrinks.
    - Each swing's period is jittered by `jitter` (relative, 2-4 %), not a steady saw.
    - Amplitude modulation at the shaft's first bending mode (9-14 Hz, depth 0.5-0.7).
    - The shaft slapping the wound: one contact click per swing, 20-30 % of them
      skipped and the rest jittered, convolved with `body_ir` (the struck body) plus
      a little tick; `rattle` is that layer's level against the tone.
    - radiate (Hz): partials below it are weighted by f/radiate, since a thin shaft
      radiates its lowest partials poorly (keeps the sub-bass line down)."""
    n = nsamp(length)
    t = taxis(n)
    jit = r.uniform(*jitter)
    bounds = [0.0]
    while bounds[-1] < length + 0.05:
        tc = bounds[-1]
        f = f0 * (1.0 + 0.03 * math.exp(-tc / (0.5 * tau)))
        bounds.append(tc + (1.0 + jit * r.uniform(-1.0, 1.0)) / f)
    bounds = np.asarray(bounds)
    ph = 2.0 * np.pi * np.interp(t, bounds, np.arange(len(bounds), dtype=float)) + r.uniform(0, 2 * np.pi)
    y = np.zeros(n)
    k = 1
    while True:
        ratio = k * (1.0 + stretch * k * k)
        tk = tau / (1.0 + hf_damp * (ratio - 1.0))              # higher partials die sooner
        if f0 * ratio > fmax or tk < 0.003:
            break
        wk = k ** -tilt * (min(1.0, f0 * ratio / radiate) if radiate else 1.0)
        y += wk * np.sin(ratio * ph + r.uniform(0, 2 * np.pi)) * np.exp(-t / tk)
        k += 1
    y = unit(y)
    if rattle > 0:
        imp = np.zeros(n)
        sk = r.uniform(*skip)
        for i in range(len(bounds) - 1):
            if r.uniform() < sk:
                continue
            per = bounds[i + 1] - bounds[i]
            tc = bounds[i] + per * (0.5 + 0.15 * r.uniform(-1.0, 1.0))
            j = int(tc * SR)
            if j >= n:
                break
            imp[j] += math.exp(r.normal(0.0, 0.45)) * math.exp(-tc / (0.6 * tau))
        ir = body_ir if body_ir is not None else soft_ir(r)
        body = dsp.fftconvolve(imp, ir)[:n]
        tick = band(imp, 1200.0, 5000.0, 4)
        y = y + rattle * unit(mix((unit(body), 1.0), (unit(tick), 0.35)))
    fa = r.uniform(*am_rate) * (1.0 + 0.06 * dsp.smooth_noise(n, 3.0, r))
    dep = r.uniform(*am_depth)
    am = 1.0 - dep * (0.5 - 0.5 * np.cos(2.0 * np.pi * np.cumsum(fa) / SR + r.uniform(0, 2 * np.pi)))
    return unit(y * am * seg_env(n, rise, length, tau=1e9, taper=0.25))


def stone_chip(r, f_lo, f_hi, count, tau, length, crack=0.7, q=(30.0, 60.0), tau_lim=(0.002, 0.006),
               noise_band=(1500.0, 9000.0), noise_gain=0.9, low_cap=None, noise_order=4) -> np.ndarray:
    """Hard strike on rock. Many low-Q modes (Q 30-60, tau clipped to 2-6 ms) in
    f_lo..f_hi give the 'chk'; the envelope `tau` is carried by gritty noise in
    noise_band, so nothing rings like struck metal. low_cap=(f, tau) caps the decay
    of modes below f. A broadband crack sits on top."""
    f = logu(r, f_lo, f_hi, count)
    taus = np.clip(r.uniform(*q, count) / (np.pi * f), *tau_lim)
    if low_cap:
        taus = np.where(f < low_cap[0], np.minimum(taus, low_cap[1]), taus)
    amps = r.uniform(0.3, 1.0, count) * (f / f_lo) ** -0.2
    modes = dsp.strike(f, taus, amps, length, contact=0.00005, r=r, noise=0.6)
    n = nsamp(length)
    grit = band(dsp.white(n, r), noise_band[0], noise_band[1], noise_order) \
        * rough_texture(r, n, r.uniform(1500, 3000), floor=0.35, grain=0.0004) * seg_env(n, 0.0002, length, tau)
    return unit(mix((unit(modes), 1.0), (unit(grit), noise_gain), (broadband_crack(r, 0.0003, 0.0001, 700.0), crack)))


def shaft_clack(r, freqs, length=0.05, tau=(0.006, 0.010)) -> np.ndarray:
    """A wooden arrow shaft landing on rock: dowel modes (1-3 kHz, tau 6-10 ms) with
    a fresh random strength per mode on every bounce (a different subset rings each
    time), a small contact click and a short hollow thock."""
    k = len(freqs)
    modes = dsp.strike(freqs, r.uniform(*tau, k), r.uniform(0.1, 1.0, k), length, contact=0.00012, r=r, noise=0.4)
    n = nsamp(length)
    t = taxis(n)
    click = band(dsp.white(n, r) * np.exp(-t / 0.00008) * (t < 0.0003), 2000.0, 9000.0)
    thock = np.sin(2 * np.pi * r.uniform(350, 600) * t) * np.exp(-t / 0.004)
    return unit(unit(modes) + 0.4 * unit(click) + 0.25 * thock)


def tiny_tick(r, f_lo=1000.0, f_hi=3000.0, tau=(0.0004, 0.001), click=1.0, modal=0.4,
              glen=(0.0003, 0.001)) -> np.ndarray:
    """A splinter or chip landing: mostly a short noise grain in f_lo..f_hi (4th
    order), with one or two very short modes under it."""
    k = int(r.integers(1, 3))
    s = dsp.strike(r.uniform(f_lo, f_hi, k), r.uniform(*tau, k), r.uniform(0.5, 1.0, k), 0.02,
                   contact=0.00005, r=r, noise=0.5)
    g = grain_cloud(r, 0.02, [0.0], [1.0], f_lo * 0.8, f_hi * 1.25, glen=glen, order=4)
    return unit(modal * unit(s) + click * unit(g))


def ground_thud(r, f_sine, lo, hi, length, tau, res=(180.0, 450.0), sine_gain=0.25, sine_tau=None,
                crunch_db=-8.0, crunch_band=(600.0, 2500.0), attack=0.0008, punch=1.5,
                emph=0.0, emph_tc=0.003) -> np.ndarray:
    """A point or ball driving into soil: a noisy 'thup' (noise band lo..hi through
    2-3 broad resonances of Q 2-4 at random centres in `res`, tau `tau`), a quiet
    low sine (f_sine, tau 8-12 ms) for weight, and a granular soil crunch in
    crunch_band (tau 8-12 ms) at crunch_db. The sine sits at 0.25 of the noise
    thud so the band below 100 Hz stays under -8 dB of the total. `emph` (see
    resonant_noise) front-loads the thud where the peak must land at contact."""
    nres = int(r.integers(2, 4))
    body = resonant_noise(r, length, lo, hi, logu(r, res[0], res[1], nres), r.uniform(2.0, 4.0, nres),
                          tau, attack, punch=punch, emph=emph, emph_tc=emph_tc)
    st = sine_tau if sine_tau else r.uniform(0.008, 0.012)
    n = nsamp(length + 0.01)
    t = taxis(n)
    sine = dsp.sine_sweep(n, f_sine * (1.0 + 0.12 * np.exp(-t / 0.008)), r.uniform(0, 2 * np.pi)) \
        * seg_env(n, 1.5 * attack, min(length, 6 * st), st)
    ct = r.uniform(0.008, 0.012)
    cn = nsamp(6 * ct + 0.004)
    crunch = band(dsp.white(cn, r), crunch_band[0], crunch_band[1], 2) \
        * rough_texture(r, cn, r.uniform(1500, 3000), floor=0.3, grain=0.0006) * seg_env(cn, 0.0004, 6 * ct, ct)
    return unit(mix((body, 1.0), (unit(sine), sine_gain), (unit(crunch), db2lin(crunch_db))))


def ricochet_whine(r, length=0.88, glide=0.5) -> np.ndarray:
    """Deformed ball spinning away off rock: a chirp ~3.4 kHz -> ~1.2 kHz over
    `glide` s with irregular tumbling FM (a tumble whose rate wanders over 22-45 Hz
    with 2-3 abrupt jumps, plus band-limited 22-45 Hz precession noise; 8 % peak /
    ~4.5 % RMS depth), random 20-40 % amplitude
    flutter that is not locked to the FM, a breathy noise band that follows the
    tone (about 1.5-4 kHz), and a recede (1/distance, air absorption)."""
    n = nsamp(length)
    t = taxis(n)
    f1 = 3400.0 * r.uniform(0.95, 1.05)
    f2 = 1200.0 * r.uniform(0.93, 1.07)
    u = np.clip(t / glide, 0.0, 1.0) ** r.uniform(0.8, 1.15)
    f = f1 * (f2 / f1) ** u
    after = t > glide
    f[after] = f2 * (1.0 - 0.18 * (t[after] - glide) / (length - glide))
    # tumbling: the FM rate wanders over 22-45 Hz and jumps now and then
    sn = dsp.smooth_noise(n, 4.0, r)
    sn /= np.max(np.abs(sn)) + 1e-12
    rate = 33.5 + 11.5 * np.tanh(2.0 * sn) / math.tanh(2.0) + 4.0 * dsp.smooth_noise(n, 9.0, r)
    jumps = np.sort(r.uniform(0.0, 1.0, int(r.integers(2, 4))))
    for tj in 0.04 + (0.8 * glide - 0.04) * (jumps + np.arange(len(jumps))) / len(jumps):
        rate[t >= tj] += 8.0 * (1.0 if r.uniform() < 0.5 else -1.0)
    rate = np.where(rate > 45.0, 90.0 - rate, rate)          # reflect jumps back into 22-45 Hz
    rate = np.where(rate < 22.0, 44.0 - rate, rate)
    wph = 2.0 * np.pi * np.cumsum(rate) / SR + r.uniform(0, 2 * np.pi)
    wob = np.sin(wph) + 0.35 * np.sin(2.0 * wph + r.uniform(0, 2 * np.pi)) \
        + 0.3 * np.sin(1.47 * wph + r.uniform(0, 2 * np.pi))
    wob *= 0.6 + 0.4 * dsp.smooth_noise(n, 14.0, r)
    # precession: an irregular (noise) wobble spread over the same 22-45 Hz band, so
    # no single tumble rate carries most of the FM energy
    prec = dsp.fft_band(dsp.white(n, r), 22.0, 45.0, order=4)
    z = wob / (np.std(wob) + 1e-12) + 1.2 * prec / (np.std(prec) + 1e-12)
    z /= np.std(z) + 1e-12
    lo, hi = 0.05, 8.0                                        # soft-limit to RMS/peak 0.56
    for _ in range(30):
        d = 0.5 * (lo + hi)
        w = np.tanh(d * z)
        lo, hi = (d, hi) if np.std(w) / np.max(np.abs(w)) < 0.56 else (lo, d)
    wob = np.tanh(0.5 * (lo + hi) * z)
    wob /= np.max(np.abs(wob))
    fi = f * (1.0 + 0.08 * wob)
    ph = 2.0 * np.pi * np.cumsum(fi) / SR
    tone = np.sin(ph) + 0.18 * np.sin(2 * ph + r.uniform(0, 6.28)) + 0.06 * np.sin(3 * ph + r.uniform(0, 6.28))
    air = dsp.svf(dsp.white(n, r), np.clip(fi * 1.05, 1500.0, 4000.0), 1.0, "bp")
    air *= np.std(tone) / (np.std(air) + 1e-12)
    x = tone + 0.5 * air
    am = dsp.smooth_noise(n, r.uniform(9.0, 17.0), r)
    x *= 1.0 + r.uniform(0.2, 0.4) * am / (np.max(np.abs(am)) + 1e-12)
    dist = 1.0 + t / 0.07
    env = (1.0 - np.exp(-t / 0.006)) / dist * np.exp(-t / 0.5)
    x = dsp.svf(x * env, np.maximum(2500.0, 10000.0 * dist ** -0.5), 0.7071, "lp")
    return unit(dsp.fade_out(x, 0.06))


# =========================================================================== sounds
# Each returns a mono float buffer; render() trims, densifies (balls), fades and normalizes it.

def arrow_hit_wood(r, v, slot, nvar):
    L = 0.45
    main = np.zeros(nsamp(L))
    place(main, tock(r, 1500, 6000), 0.0)
    modes = wood_modes(r, int(r.integers(3, 6)), 180, 900, 0.030, 0.070)
    bg = r.uniform(0.6, 0.8)
    place(main, wood_body(r, modes, L, contact=0.00025, rough=0.35), 0.0002, bg)
    place(main, thwock(r, int(r.integers(3, 6)), tau=(0.008, 0.015), noise_tau=0.016), 0.0002, bg * db2lin(-0.5))
    k = int(r.integers(5, 13))                               # splinter micro-crackle
    times = np.sort(r.uniform(0.0006, 0.020, k))
    amps = r.uniform(0.35, 1.0, k) * np.exp(-times / 0.015)
    place(main, unit(grain_cloud(r, 0.03, times, amps, 1500, 8000, glen=(0.00005, 0.00025))), 0.0,
          r.uniform(0.3, 0.45))
    pk = np.max(np.abs(main))
    n = nsamp(0.08)                                          # the struck body, damped, rings each shaft slap
    ir = dsp.modal_ir(*modes, 0.08, r) * np.exp(-taxis(n) / 0.008)
    buzz = shaft_buzz(r, L - 0.003, spread(r, slot, nvar, 45, 65), 0.120, rattle=0.45, body_ir=ir, radiate=180.0)
    place(main, buzz, 0.003, pk * db2lin(-11))
    return main


def arrow_hit_straw(r, v, slot, nvar):
    L = 0.35
    main = np.zeros(nsamp(L))
    lp = noise_layer(r, 0.030, None, spread(r, slot, nvar, 150, 600), attack=0.0015, tau=0.009)
    res = resonant_noise(r, 0.045, 150, 1200, [r.uniform(200, 600)], [2.0], r.uniform(0.010, 0.015),
                         attack=0.001, direct=0.15)
    place(main, unit(mix((res, 1.0), (unit(lp), 0.7))), 0.0)
    cd = r.uniform(0.05, 0.09)                               # straw crunch
    times = decay_times(r, int(cd * r.uniform(2500, 3800)), 0.0005, cd, cd / 3)
    crunch = grain_cloud(r, cd + 0.01, times, crackle_amps(r, times, 0.0, cd / 2.5), 1100, 3500,
                         glen=(0.0001, 0.0004), order=4)
    crunch *= seg_env(len(crunch), 0.0, cd, tau=1e9, taper=0.3)
    place(main, unit(crunch), 0.0005, r.uniform(0.45, 0.55))
    pk = np.max(np.abs(main))
    n = nsamp(0.045)                                         # cloth tear of the coat
    tear = band(dsp.white(n, r), 800, 3500) * rough_texture(r, n, r.uniform(600, 1000)) \
        * seg_env(n, 0.002, 0.040, 0.015)
    place(main, unit(tear), 0.0003, pk * db2lin(-12))
    buzz = shaft_buzz(r, 0.18, r.uniform(45, 65), 0.035, rattle=0.1, tilt=1.35, hf_damp=0.15,
                      body_ir=soft_ir(r, 300, 1500, 0.002), radiate=150.0)
    place(main, buzz, 0.004, pk * db2lin(-20))
    k = int(r.integers(18, 32))                              # fibres springing back
    times = decay_times(r, k, cd * r.uniform(0.5, 0.8), r.uniform(0.18, 0.25), r.uniform(0.07, 0.12))
    amps = r.uniform(0.3, 1.0, k) * np.exp(-(times - times[0]) / 0.15)
    place(main, unit(grain_cloud(r, L, times, amps, 700, 3000, glen=(0.0003, 0.0012))), 0.0, pk * db2lin(-22))
    place(main, density_bed(r, nsamp(L), times, amps, 600, 2500), 0.0, pk * db2lin(-34))
    return main


def arrow_hit_dirt(r, v, slot, nvar):
    L = 0.30
    main = np.zeros(nsamp(L))
    thud = ground_thud(r, spread(r, slot, nvar, 70, 115), 150, 900,
                       length=spread(r, (slot + 1) % nvar, nvar, 0.030, 0.060), tau=r.uniform(0.012, 0.020))
    place(main, thud, 0.0)
    count = int(r.integers(16, 34))                          # grit spray
    t0 = r.uniform(0.001, 0.006)
    times = decay_times(r, count, t0, r.uniform(0.2, 0.26), r.uniform(0.07, 0.11))
    amps = r.uniform(0.25, 1.0, count) * np.exp(-(times - t0) / r.uniform(0.08, 0.12))
    place(main, unit(grain_cloud(r, L, times, amps, 1800, 5500, glen=(0.0002, 0.0006))), 0.0,
          r.uniform(0.2, 0.3))
    pk = np.max(np.abs(main))
    place(main, density_bed(r, nsamp(L), times, amps, 1500, 5000), 0.0, pk * db2lin(-33))
    buzz = shaft_buzz(r, 0.2, r.uniform(45, 65), 0.045, rattle=0.2, tilt=1.25, hf_damp=0.12,
                      body_ir=soft_ir(r, 400, 2500, 0.0015), radiate=150.0)
    place(main, buzz, 0.004, pk * db2lin(-18))
    return main


def arrow_hit_grass(r, v, slot, nvar):
    L = 0.35
    main = np.zeros(nsamp(L))
    th = r.uniform(0.0025, 0.0045)                           # the tip crosses 10-20 cm of grass, reaches soil
    tail = r.uniform(0.040, 0.060)                           # blades whipping back after the thud
    n = nsamp(th + tail + 0.005)
    t = taxis(n)
    env = dsp.ar_env(n, r.uniform(0.0015, 0.003), 1e9) * np.where(t < th, 1.0, np.exp(-(t - th) / 0.020))
    env *= seg_env(n, 0.0, th + tail, tau=1e9, taper=0.3)
    swish = band(dsp.white(n, r), 1800, 6000) * rough_texture(r, n, r.uniform(150, 300), floor=0.6, grain=0.004) * env
    thud = ground_thud(r, spread(r, slot, nvar, 60, 100), 120, 600,
                       length=spread(r, (slot + 1) % nvar, nvar, 0.030, 0.060), tau=r.uniform(0.012, 0.020),
                       emph=3.0)                             # contact first: peaks within ~3 ms of th
    place(main, thud, th)
    place(main, unit(swish), 0.0, db2lin(r.uniform(-10, -8)))
    k = int(r.integers(4, 9))                                # a little grit
    times = th + np.sort(r.uniform(0.001, 0.06, k))
    place(main, unit(grain_cloud(r, L, times, r.uniform(0.3, 1.0, k), 1800, 5500)), 0.0, 0.1)
    pk = np.max(np.abs(main))
    k = int(r.integers(20, 36))                              # stems settling
    times = decay_times(r, k, th + r.uniform(0.02, 0.04), r.uniform(0.15, 0.2), r.uniform(0.1, 0.18))
    amps = r.uniform(0.3, 1.0, k) * np.exp(-(times - th) / 0.2)
    rust = grain_cloud(r, L, times, amps, 1500, 5000, glen=(0.0002, 0.0008))
    place(main, unit(rust), 0.0, pk * db2lin(-12))
    place(main, density_bed(r, nsamp(L), times, amps, 1200, 4500), 0.0, pk * db2lin(-32))
    return main


def arrow_hit_stone(r, v, slot, nvar):
    L = 0.5
    main = np.zeros(nsamp(L))
    place(main, stone_chip(r, 2500, 7000, int(r.integers(20, 31)), 0.020, 0.15,
                           noise_band=(spread(r, slot, nvar, 1300, 2300), r.uniform(7000, 10000))), 0.0)
    pk = np.max(np.abs(main))
    nb = int(r.integers(3, 6))                               # the shaft skitters away
    ratio = r.uniform(0.55, 0.75)
    span = r.uniform(0.30, 0.35)
    gap = span * (1 - ratio) / (1 - ratio ** nb)
    shaft = logu(r, 1000, 3000, int(r.integers(4, 6)))
    t, amp = 0.0, r.uniform(0.35, 0.5)
    bt, ba = [0.0], [1.0]
    for i in range(nb):
        t += gap * ratio ** i
        bt.append(t)
        ba.append(amp)
        place(main, shaft_clack(r, shaft * r.uniform(0.94, 1.06, len(shaft))), t, amp * r.uniform(0.95, 1.05))
        if r.uniform() < 0.5:                                # tip and nock land a moment apart
            place(main, shaft_clack(r, shaft * r.uniform(0.94, 1.06, len(shaft))), t + r.uniform(0.004, 0.012),
                  amp * r.uniform(0.25, 0.4))
        if i == 0:                                           # it slides a little before the next bounce
            sl = min(r.uniform(0.02, 0.06), 0.8 * gap * ratio)
            n = nsamp(sl + 0.004)
            scrape = band(dsp.white(n, r), 1000, 4000) * rough_texture(r, n, r.uniform(300, 700), 0.3, 0.002) \
                * seg_env(n, 0.003, sl, sl / 2.5)
            place(main, unit(scrape), t + 0.004, pk * db2lin(-18))
        amp *= r.uniform(0.55, 0.75)
    place(main, density_bed(r, nsamp(L), bt, ba, 1000, 5000), 0.0, pk * db2lin(-38))   # sliding, rolling
    return main


def ball_hit_wood(r, v, slot, nvar):
    L = 0.5
    main = np.zeros(nsamp(L))
    place(main, broadband_crack(r, 0.0005, 0.00012, 150.0), 0.0)
    count = int(r.integers(260, 380))                        # splintering
    times = decay_times(r, count, 0.0003, 0.3, 0.045)
    cr = grain_cloud(r, 0.32, times, crackle_amps(r, times, 0.0, 0.04, 0.6), 1000, 8000,
                     glen=(0.00005, 0.0003), order=4)
    place(main, unit(cr), 0.0, r.uniform(0.55, 0.7))
    modes = wood_modes(r, int(r.integers(4, 7)), 150, 550, 0.030, 0.050, detune=(0.001, 0.003))
    knock = wood_body(r, modes, L, contact=spread(r, slot, nvar, 0.002, 0.004), rough=1.0)
    place(main, knock, 0.0003, r.uniform(0.45, 0.55))
    n = nsamp(0.13)                                          # fibres tearing: crunchy mid-band
    fib = band(dsp.white(n, r), 600, 2500) * rough_texture(r, n, r.uniform(800, 1500), floor=0.25, grain=0.0008) \
        * seg_env(n, 0.0008, 0.125, 0.025)
    place(main, unit(fib), 0.0003, db2lin(r.uniform(-5, -4)))
    pk = np.max(np.abs(main))
    tt = np.sort(r.uniform(0.08, 0.40, int(r.integers(4, 8))))   # falling splinters
    ta = db2lin(r.uniform(-30, -21, len(tt)))
    for ti, ai in zip(tt, ta):
        place(main, tiny_tick(r, 1000, 3000), ti, pk * ai)
    place(main, density_bed(r, nsamp(L), np.concatenate([times[times > 0.05], tt]),
                            np.concatenate([np.full(np.sum(times > 0.05), 0.3), ta / ta.max()]), 1000, 4000),
          0.0, pk * db2lin(-33))
    return main


def ball_hit_dirt(r, v, slot, nvar):
    L = 0.45
    main = np.zeros(nsamp(L))
    thud = ground_thud(r, spread(r, slot, nvar, 50, 90), 150, 900,
                       length=spread(r, (slot + 1) % nvar, nvar, 0.035, 0.060), tau=r.uniform(0.014, 0.020),
                       crunch_db=-7.0)
    place(main, thud, 0.0)
    n = nsamp(0.16)                                          # soil thrown up
    spray = band(dsp.white(n, r), 600, 3000, 4) * rough_texture(r, n, r.uniform(700, 1400), floor=0.3, grain=0.001) \
        * seg_env(n, 0.003, 0.15, r.uniform(0.025, 0.04))
    place(main, unit(spray), 0.001, db2lin(r.uniform(-15, -12)))
    pk = np.max(np.abs(main))
    count = int(r.integers(28, 50))                          # grit falling back, thinning
    gt = decay_times(r, count, r.uniform(0.04, 0.08), 0.34, r.uniform(0.09, 0.15))
    ga = r.uniform(0.2, 1.0, count) * np.exp(-(gt - 0.06) / 0.2)
    place(main, unit(grain_cloud(r, L, gt, ga, 1500, 4500, glen=(0.0002, 0.0006))), 0.0, pk * db2lin(-16))
    count = int(r.integers(5, 11))                           # clods
    ct = decay_times(r, count, r.uniform(0.05, 0.09), 0.28, r.uniform(0.07, 0.12))
    place(main, unit(grain_cloud(r, L, ct, r.uniform(0.5, 1.0, count), 1000, 2500, glen=(0.0008, 0.0025))),
          0.0, pk * db2lin(-13))
    place(main, density_bed(r, nsamp(L), np.concatenate([gt, ct]), 1.0, 800, 4000, smooth=0.04),
          0.0, pk * db2lin(-26))
    return main


def ball_hit_grass(r, v, slot, nvar):
    L = 0.45
    main = np.zeros(nsamp(L))
    thud = ground_thud(r, spread(r, slot, nvar, 50, 85), 120, 600,
                       length=spread(r, (slot + 1) % nvar, nvar, 0.035, 0.060), tau=r.uniform(0.014, 0.020),
                       attack=0.0015)
    place(main, thud, 0.0)
    n = nsamp(0.125)                                         # turf tearing
    tear_n = band(dsp.white(n, r), 1200, 5000) * rough_texture(r, n, r.uniform(500, 900)) \
        * seg_env(n, 0.003, 0.12, 0.035)
    k = int(r.integers(50, 90))
    times = decay_times(r, k, 0.002, 0.11, 0.04)
    tear_c = grain_cloud(r, 0.125, times, crackle_amps(r, times, 0.0, 0.05), 1200, 5000, glen=(0.0001, 0.0004))
    place(main, unit(mix((unit(tear_n), 0.7), (unit(tear_c), 1.0))), 0.001, r.uniform(0.35, 0.45))
    pk = np.max(np.abs(main))
    k = int(r.integers(6, 15))                               # clod patter
    times = decay_times(r, k, r.uniform(0.06, 0.1), 0.32, r.uniform(0.09, 0.15))
    amps = r.uniform(0.3, 1.0, k) * np.exp(-(times - 0.08) / 0.2)
    place(main, unit(grain_cloud(r, L, times, amps, 800, 3000, glen=(0.0003, 0.0012))), 0.0, pk * db2lin(-10))
    place(main, density_bed(r, nsamp(L), times, amps, 800, 3500), 0.0, pk * db2lin(-32))
    return main


def ball_hit_straw(r, v, slot, nvar):
    L = 0.35
    main = np.zeros(nsamp(L))
    n = nsamp(0.044)
    t = taxis(n)
    fw_n = noise_layer(r, 0.040, 100, 250, attack=0.003, tau=0.011)
    fw_s = dsp.sine_sweep(n, spread(r, slot, nvar, 140, 190) * (1.0 + 0.05 * np.exp(-t / 0.01))) \
        * seg_env(n, 0.003, 0.040, 0.012)
    thw = noise_layer(r, 0.06, 300, 900, attack=0.0015, tau=0.012)
    place(main, unit(mix((unit(fw_n), 1.0), (unit(fw_s), 0.4), (unit(thw), 1.0))), 0.0)
    count = int(r.integers(250, 350))                        # straw crunch burst
    times = decay_times(r, count, 0.0005, 0.08, 0.03)
    crunch = grain_cloud(r, 0.09, times, crackle_amps(r, times, 0.0, 0.03), 900, 3000,
                         glen=(0.0001, 0.0004), order=4)
    crunch *= seg_env(len(crunch), 0.0, 0.08, tau=1e9, taper=0.3)
    place(main, unit(crunch), 0.0005, r.uniform(0.45, 0.55))
    pk = np.max(np.abs(main))
    n = nsamp(0.24)                                          # fibres settling, grown out of the crunch
    k = int(r.integers(45, 75))
    times = decay_times(r, k, 0.0, 0.22, 0.15)
    fib = grain_cloud(r, 0.24, times, r.uniform(0.2, 1.0, k) * np.exp(-times / 0.2), 700, 3000,
                      glen=(0.0003, 0.0015), order=4)
    hiss = band(dsp.white(n, r), 900, 3500, 4) * (0.6 + 0.4 * dsp.smooth_noise(n, 30.0, r)) \
        * seg_env(n, 0.0, 0.22, 0.09)
    rustle = unit(mix((unit(fib), 1.0), (unit(hiss), 0.12))) * seg_env(n, 0.025, 0.22, tau=1e9, taper=0.35)
    place(main, unit(rustle), r.uniform(0.015, 0.03), pk * db2lin(-13))
    return main


def ball_hit_stone(r, v, slot, nvar):
    whine = v < 2                                            # variants 01 and 02 ricochet
    L = 0.9 if whine else 0.4
    main = np.zeros(nsamp(L))
    place(main, stone_chip(r, 1800, 8000, int(r.integers(20, 31)), 0.015, 0.15, low_cap=(2000.0, 0.005),
                           noise_band=(spread(r, slot, nvar, 1300, 2000), r.uniform(6000, 8000)), noise_gain=0.45),
          0.0)
    n = nsamp(0.03)                                          # lead splat
    t = taxis(n)
    thud = dsp.sine_sweep(n, 400.0 * r.uniform(0.93, 1.07) * (1.0 + 0.1 * np.exp(-t / 0.003))) \
        * seg_env(n, 0.0004, 0.028, r.uniform(0.008, 0.012))
    lead = noise_layer(r, 0.02, None, 1200, attack=0.0003, tau=0.005)
    place(main, unit(mix((unit(thud), 1.0), (unit(lead), 0.7))), 0.0002, r.uniform(0.9, 1.0))
    pk = np.max(np.abs(main))
    k = int(r.integers(6, 13))                               # chips and grit pattering down
    tt = np.append(decay_times(r, k - 1, 0.04, 0.26, r.uniform(0.2, 0.35)), r.uniform(0.29, 0.35))
    ta = db2lin(r.uniform(-6.0, 0.0, k))
    place(main, unit(grain_cloud(r, L, tt, ta, 2000, 5500, glen=(0.0003, 0.001))), 0.0, pk * db2lin(-20))
    place(main, density_bed(r, nsamp(L), tt, ta, 1200, 4500), 0.0, pk * db2lin(-34))
    if whine:
        place(main, ricochet_whine(r, 0.88, 0.5), r.uniform(0.006, 0.012),
              pk * db2lin(-7.0 if v == 0 else -9.0))
    return main


def ball_whizz(r, v, slot, nvar):
    """A ball passing within a few metres: a short 'vwip' peaking ~30 ms in (the
    game triggers at closest approach), rising from 30+ dB down, then a receding
    tail (~1/d) through a lowpass closing from 4 kHz to 1 kHz. Doppler 1.35x -> 0.75x
    over ~10 ms; a resonant hum (Q 6-10) makes the pitch drop audible."""
    tp = 0.03
    tail = spread(r, slot, nvar, 0.25, 0.35)
    L = tp + tail
    ns = nsamp(1.4 * L + 0.05)                               # source, read up to 1.35x real time
    lo = 400.0 * spread(r, slot, nvar, 0.75, 1.25)
    hi = max(1500.0 * spread(r, (slot + 2) % nvar, nvar, 0.75, 1.25), 2.4 * lo)
    bright = spread(r, nvar - 1 - slot, nvar, 0.7, 1.4)         # a closer pass is brighter
    nz = unit(band(dsp.white(ns, r), lo, hi, order=4))
    fc = spread(r, (slot + 1) % nvar, nvar, 600, 1100)
    hum = dsp.resonator(dsp.white(ns, r), fc, r.uniform(6.0, 10.0))
    src = nz + db2lin(-6.0) * hum * (np.std(nz) / (np.std(hum) + 1e-12))
    ff = spread(r, (slot + 2) % nvar, nvar, 60, 120)          # tumble flutter rate
    fm = ff * (1.0 + 0.12 * dsp.smooth_noise(ns, 15.0, r))
    ph = 2.0 * np.pi * np.cumsum(fm) / SR
    cyc = ph / (2.0 * np.pi)
    strength = np.interp(cyc, np.arange(int(cyc[-1]) + 2), r.uniform(0.45, 1.0, int(cyc[-1]) + 2))
    flutter = (0.5 + 0.5 * np.sin(ph)) ** 3 * strength
    x = src * (0.4 + 0.6 * flutter)
    t = taxis(nsamp(L))
    w = r.uniform(0.008, 0.015)
    rate = 1.05 - 0.30 * (t - tp) / np.sqrt((t - tp) ** 2 + w ** 2)   # Doppler 1.35x -> 0.75x
    y = varispeed(x, rate)
    wd = r.uniform(0.008, 0.011)                              # closest distance / speed
    d = np.sqrt(1.0 + ((t - tp) / wd) ** 2)
    y *= np.where(t < tp, d ** -3.0, 1.0 / d)                 # quiet ahead of the ball, 1/d behind it
    fcut = 4000.0 * bright * 0.25 ** np.clip((t - tp) / (0.8 * tail), 0.0, 1.0)
    y = dsp.svf(y, fcut, 0.7071, "lp")
    return dsp.fade_out(dsp.fade_in(y, 0.022), 0.04)


# =========================================================================== registry

# =========================================================================== melee (AxeMelee, MeleeSweep)

def iron_modes(r, f1, count, tau1, detune=(0.002, 0.006)):
    """A forged iron axe head's ring: `count` inharmonic modes from f1 up (a thick wedge struck side-on:
    ratios about 1, 1.6, 2.3, 2.9, 3.8, 4.6, 5.9, 7.2, 8.6, each jittered 3 %), each a near-degenerate
    pair that beats; the higher modes die faster (tau1 * (f1 / f) ** 0.8). Returns (freqs, taus, amps)."""
    base = np.array([1.0, 1.61, 2.27, 2.93, 3.81, 4.62, 5.94, 7.2, 8.55])[:count]
    f = f1 * base * r.uniform(0.97, 1.03, count)
    taus = tau1 * (f1 / f) ** 0.8 * r.uniform(0.8, 1.15, count)
    amps = r.uniform(0.55, 1.0, count) * (f / f1) ** -0.45
    F, T, A = [], [], []
    for fi, ti, ai in zip(f, taus, amps):
        d = r.uniform(*detune)
        w = r.uniform(0.5, 0.7)
        F += [fi * (1 - d / 2), fi * (1 + d / 2)]
        T += [ti, ti * r.uniform(0.7, 1.0)]
        A += [ai * w, ai * (1 - w)]
    return F, T, A


def axe_clash(r, v, slot, nvar):
    """Two felling axes meeting (MeleeSweep.sound "weapon"): a hard crack, the two iron heads ringing
    at different pitches (bright and short: struck side-on, damped by the hafts in the hands, not free
    bells), a knock of the ash hafts under them, and the edges grinding past each other for a few
    tens of ms (-14 dB)."""
    L = 0.9
    main = np.zeros(nsamp(L))
    place(main, broadband_crack(r, 0.0006, 0.00015, 400.0), 0.0)
    f1 = spread(r, slot, nvar, 1500.0, 2300.0)
    ring_a = dsp.strike(*iron_modes(r, f1, 8, r.uniform(0.16, 0.24)), L, contact=0.0003, r=r, noise=0.4)
    ring_b = dsp.strike(*iron_modes(r, f1 * r.uniform(1.18, 1.42), 7, r.uniform(0.10, 0.16)), L, contact=0.0004,
                        r=r, noise=0.4)
    place(main, unit(ring_a), 0.0002, 0.75)
    place(main, unit(ring_b), r.uniform(0.0005, 0.002), 0.5)
    knock = wood_body(r, wood_modes(r, 5, 180.0, 700.0, 0.02, 0.04, detune=(0.002, 0.006)), 0.2, contact=0.0015,
                      rough=0.8)
    place(main, knock, 0.0005, 0.45)
    sl = r.uniform(0.04, 0.09)
    n = nsamp(sl + 0.004)
    scrape = band(dsp.white(n, r), 2500.0, 9000.0) * rough_texture(r, n, r.uniform(900, 1600), 0.25, 0.0008) \
        * seg_env(n, 0.002, sl, sl / 2.0)
    place(main, unit(scrape), r.uniform(0.003, 0.008), db2lin(-14))
    return main


def axe_crunch_flesh(r, v, slot, nvar):
    """An axe driven into a body to the spine (MeleeSweep.crunch "flesh": the cut reaching the core): the
    heavy wet thud of the blow (a resonant low body with a falling 70-110 Hz sine under it), a slap of
    the skin, the bone giving way 8-20 ms in as a close run of cracks (a grain cloud, 700 Hz-4.5 kHz,
    with two or three loud snaps in it), and a wet squelch as the blade settles (-8 dB)."""
    L = 0.5
    main = np.zeros(nsamp(L))
    f = spread(r, slot, nvar, 70.0, 110.0)
    thud = ground_thud(r, f, 80.0, 700.0, 0.18, 0.05, res=(120.0, 320.0), sine_gain=0.7, sine_tau=0.045,
                       crunch_db=-12.0, crunch_band=(500.0, 1800.0), punch=2.0, emph=1.0)
    place(main, thud, 0.0, 1.0)
    place(main, unit(noise_layer(r, 0.03, 300.0, 2200.0, 0.0005, 0.007)), 0.0, 0.4)
    t0 = r.uniform(0.008, 0.02)
    count = int(r.integers(40, 80))
    times = decay_times(r, count, t0, 0.07, 0.022)
    cr = grain_cloud(r, 0.12, times, crackle_amps(r, times, t0, 0.03, 0.7), 700.0, 4500.0,
                     glen=(0.0004, 0.0015), order=4)
    place(main, unit(cr), 0.0, 0.42)
    for _ in range(int(r.integers(2, 4))):
        place(main, broadband_crack(r, 0.0006, 0.0002, 500.0), t0 + r.uniform(0.0, 0.035), r.uniform(0.2, 0.35))
    sq = r.uniform(0.14, 0.22)
    n = nsamp(sq + 0.004)
    wet = band(dsp.white(n, r), 150.0, 1400.0) * rough_texture(r, n, r.uniform(40, 90), floor=0.2, grain=0.004) \
        * seg_env(n, 0.004, sq, sq / 2.5)
    place(main, unit(wet), r.uniform(0.02, 0.04), db2lin(-8))
    return main


ARROW = {"speed_ref": 62.0, "speed_min": 0.25, "random_pitch": 1.06}
BALL = {"speed_ref": 180.0, "speed_min": 0.30}
HIT = {"unit_size": 8.0, "max_distance": 150.0, "bus": "World"}
BALL_DENSIFY = 4.0                # dB of momentary loudness gained at the same peak (render())

SOUNDS = {
    "arrow_hit_wood": dict(fn=arrow_hit_wood, variants=4, length=0.45,
                           play=dict(HIT, volume_db=-6.0, **ARROW, travel_delay=True)),
    "arrow_hit_straw": dict(fn=arrow_hit_straw, variants=4, length=0.35,
                            play=dict(HIT, volume_db=-5.0, **ARROW, travel_delay=True)),
    "arrow_hit_dirt": dict(fn=arrow_hit_dirt, variants=4, length=0.30,
                           play=dict(HIT, volume_db=-6.5, **ARROW, travel_delay=True)),
    "arrow_hit_grass": dict(fn=arrow_hit_grass, variants=3, length=0.35,
                            play=dict(HIT, volume_db=-7.5, **ARROW, travel_delay=True)),
    "arrow_hit_stone": dict(fn=arrow_hit_stone, variants=3, length=0.50,
                            play=dict(HIT, volume_db=-5.0, **ARROW, travel_delay=True)),
    "ball_hit_wood": dict(fn=ball_hit_wood, densify=BALL_DENSIFY, variants=4, length=0.50,
                          play=dict(HIT, volume_db=0.0, **BALL, random_pitch=1.05, travel_delay=True)),
    "ball_hit_dirt": dict(fn=ball_hit_dirt, densify=BALL_DENSIFY, variants=4, length=0.45,
                          play=dict(HIT, volume_db=-1.0, **BALL, random_pitch=1.06, travel_delay=True)),
    "ball_hit_grass": dict(fn=ball_hit_grass, densify=BALL_DENSIFY, variants=3, length=0.45,
                           play=dict(HIT, volume_db=-2.0, **BALL, random_pitch=1.06, travel_delay=True)),
    "ball_hit_straw": dict(fn=ball_hit_straw, densify=BALL_DENSIFY, variants=3, length=0.35,
                           play=dict(HIT, volume_db=-1.0, **BALL, random_pitch=1.06, travel_delay=True)),
    "ball_hit_stone": dict(fn=ball_hit_stone, densify=BALL_DENSIFY, variants=3, length=0.90,
                           play=dict(HIT, volume_db=0.0, **BALL, random_pitch=1.05, travel_delay=True)),
    "ball_whizz": dict(fn=ball_whizz, variants=3, length=0.50,
                       play=dict(unit_size=8.0, max_distance=60.0, bus="World", volume_db=-6.0,
                                 speed_ref=None, speed_min=None, random_pitch=1.06, travel_delay=False)),
    "axe_clash": dict(fn=axe_clash, variants=4, length=0.90,
                      play=dict(HIT, volume_db=-2.0, speed_ref=None, speed_min=None, random_pitch=1.05,
                                travel_delay=True)),
    "axe_crunch_flesh": dict(fn=axe_crunch_flesh, variants=4, length=0.50,
                             play=dict(HIT, volume_db=-1.0, speed_ref=None, speed_min=None, random_pitch=1.05,
                                       travel_delay=True)),
}

MANIFEST_NOTES = {
    "volume": "volume_db = volume_db + linear_to_db(clamp(speed / speed_ref, speed_min, 1)) when speed_ref is set",
    "travel_delay": "optional: delay playback by distance_to_camera / 343 s, capped at 0.4 s",
    "hook": "projectile.gd _on_impact, after `var speed := velocity.length()`: "
            "Sfx.impact(kind, collider, point, normal, speed) -> id ('arrow_hit_' or 'ball_hit_') + "
            "Sfx.surface_of(collider, point, normal), played 3D at point under current_scene",
    "surface_of": [
        "meta 'surface' if set",
        "meta hit_part 'post' -> wood, 'head' -> straw",
        "an ancestor that is a TargetDummy (torso AnimatableBody3D) -> straw",
        "normal.y > 0.7 and point.y < 0.05 is ground: dirt if abs(x)<16 and abs(z)<16 (fort floor) "
        "or abs(x)<5 and -160<z<-20 (range lane), otherwise grass",
        "CollisionShape3D SphereShape3D (rocks) or BoxShape3D ~(0.9,1.6,0.9) (chimney) -> stone; "
        "BoxShape3D ~(1.6,0.9,0.9) +-0.05 (hay bales) -> straw",
        "everything else -> wood",
    ],
    "layering": "on dummies (straw surface) dummy_hit is layered on top of arrow/ball_hit_straw",
    "levels": "ball_hit_* files are densified (tanh soft saturation of the first 30 ms, +4 dB momentary "
              "loudness at the same -1 dBFS peak) and arrow_hit_* volume_db sit 2-4 dB lower than in the first set, "
              "so with these volume_db values a ball lands ~9 dB louder than an arrow on the same surface "
              "(approx. K-weighted momentary loudness; ball stone ~7 dB without the ricochet, ~11-13 dB with it)",
    "ball_whizz": "optional: BALL only, once per projectile, when the step segment's closest approach to "
                  "the camera is < 3 m and _life > 0.08 s; play 3D at the closest point. "
                  "max_distance for it is not in the spec (60 m chosen here).",
    "melee": "axe_clash: two weapons meeting (MeleeSweep.sound 'weapon'); axe_crunch_flesh: an axe cut reaching "
             "a body's core, the spine (MeleeSweep.crunch 'flesh'). Synthesized like the rest (no samples).",
}


# =========================================================================== build

def _seed(base: int, sid: str, v: int) -> int:
    return zlib.crc32(f"impacts:{sid}:{v}:{base}".encode())


def render(sid: str, v: int, seed: int) -> np.ndarray:
    spec = SOUNDS[sid]
    nvar = spec["variants"]
    slot = int(dsp.rng(zlib.crc32(f"perm:{sid}:{seed}".encode())).permutation(nvar)[v])
    x = spec["fn"](dsp.rng(_seed(seed, sid, v)), v, slot, nvar)
    x = dsp.fade_out(x[:nsamp(spec["length"])].copy(), 0.05)
    lead = np.nonzero(np.abs(x) > np.max(np.abs(x)) * db2lin(-60.0))[0]
    x = x[max(lead[0] - 1, 0):]                      # onset stays sample-sharp
    if spec.get("densify"):
        x = densify(x, spec["densify"])
    return dsp.finalize(x, peak_db=-1.0, fade=0.012, lead_trim=False, thresh_db=-60.0, hp=20.0)


def build(ids, seed: int, out_dir: str, manifest: bool = True, preview: str | None = None):
    written = []
    audition = []
    for sid in ids:
        for v in range(SOUNDS[sid]["variants"]):
            x = render(sid, v, seed)
            path = os.path.join(out_dir, f"{sid}_{v + 1:02d}.wav")
            dsp.write_wav(path, x, seed=_seed(seed, sid, v) & 0xFFFF)
            written.append(path)
            audition += [x, np.zeros(nsamp(0.35))]
            print(f"{os.path.relpath(path, PROJECT)}  {len(x) / SR:.3f} s")
    if manifest:
        man_path = os.path.join(out_dir, "impacts_manifest.json")
        old = {}
        if os.path.exists(man_path):
            with open(man_path) as fh:
                old = json.load(fh).get("sounds", {})
        for sid in ids:
            old[sid] = dict(SOUNDS[sid]["play"],
                            files=[f"res://audio/sfx/impacts/{sid}_{v + 1:02d}.wav"
                                   for v in range(SOUNDS[sid]["variants"])])
        with open(man_path, "w") as fh:
            # (entries this script does not make, e.g. flesh_rec.py's *_hit_flesh, are kept after its own)
            keep = {k: old[k] for k in SOUNDS if k in old}
            keep.update({k: v for k, v in old.items() if k not in SOUNDS})
            json.dump({"family": "impacts", "generator": "tools/sfx/impacts.py", "seed": seed,
                       "notes": MANIFEST_NOTES, "sounds": keep},
                      fh, indent=1)
            fh.write("\n")
    if preview:
        dsp.write_wav(preview, np.concatenate(audition), seed=1)
    return written


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--seed", type=int, default=1, help="variation seed (default 1)")
    ap.add_argument("--only", default="", help="comma-separated sound ids")
    ap.add_argument("--out", default=OUT_DIR, help="output directory")
    ap.add_argument("--no-manifest", action="store_true")
    ap.add_argument("--preview", default=None, help="also write every variant into one audition WAV")
    ap.add_argument("--list", action="store_true", help="list sound ids and exit")
    a = ap.parse_args(argv)
    if a.list:
        for k, s in SOUNDS.items():
            print(f"{k:18s} x{s['variants']}  ~{s['length']:.2f} s")
        return
    ids = [s.strip() for s in a.only.split(",") if s.strip()] or list(SOUNDS)
    bad = [s for s in ids if s not in SOUNDS]
    if bad:
        ap.error(f"unknown id(s): {', '.join(bad)}")
    build(ids, a.seed, a.out, manifest=not a.no_manifest and os.path.abspath(a.out) == os.path.abspath(OUT_DIR),
          preview=a.preview)


if __name__ == "__main__":
    main()
