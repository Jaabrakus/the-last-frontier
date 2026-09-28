#!/usr/bin/env python3
"""Footsteps and body-movement foley for Frontier (procedural, numpy only).

Regenerate:
    python3 tools/sfx/footsteps.py                  # every sound, seed 0
    python3 tools/sfx/footsteps.py --seed 7         # a fresh set of variations
    python3 tools/sfx/footsteps.py --only step_wood_crouch land_wood
    python3 tools/sfx/footsteps.py --list
    python3 tools/sfx/footsteps.py --levels-only    # re-measure levels.json

Output: audio/sfx/footsteps/<id>_<nn>.wav (nn = 01, 02, ...), 44.1 kHz, 16-bit,
mono, trimmed, short fade-out, peak-normalized to -1 dBFS; plus
audio/sfx/footsteps/levels.json (see LOUDNESS below).

Levels inside each recipe are dB relative to the recipe's main impact
(0 dB), so relations from the spec ("cloth -14 dB") hold inside each file.
Step, landing and jump outputs get a 2nd-order 65 Hz highpass so sub-bass
cannot set the peak.

LOUDNESS: every file is peak-normalized, so loudness in game is set by
PlayerAudio. After rendering, the script measures each file's A-weighted
level in its loudest 100 ms window and writes levels.json with a trim_db
per sound id (and per file). PlayerAudio plays a sound at
    base volume_db (per gait/surface, from the spec) + trim_db
and the trims put the in-game levels in the designed order: crouch = walk
-6 dB, run = walk +5, sprint = walk +8, wood = dirt +1, grass = dirt,
landings (at base volume, before the fall-speed term) = walk +5 (+6 wood),
jump_takeoff = walk -1, cloth_move = walk -2, gear_jostle = walk -2.
step_dirt_walk is the reference (trim 0).

Per-variant parameters use stratified sampling: for a sound with V variants
each variant draws a parameter from a different 1/V slice of its range, so
the set always spans the range (for example the heel-to-toe gap).

Family-specific DSP lives in this file. Shared helpers come from dsp.py
(do not change dsp.py signatures; other family scripts import it).
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys
import zlib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dsp  # noqa: E402
from dsp import SR, db2lin, nsamp  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "audio", "sfx", "footsteps")
FAMILY = "footsteps"


# =============================================================================
# variant randomness
# =============================================================================

def _crc(*parts) -> int:
    return zlib.crc32("|".join(str(p) for p in (FAMILY,) + parts).encode("utf-8"))


class Variant:
    """Random source for one variant of one sound.

    u()      plain uniform draw.
    strat()  stratified draw: the V variants of a sound get disjoint slices of
             [lo, hi] (slice order is shuffled per key), so a set of variants
             always covers the whole range.
    """

    def __init__(self, sid: str, index: int, count: int, seed: int):
        self.sid, self.i, self.count, self.seed = sid, index, count, seed
        self.r = dsp.rng(_crc(sid, index, seed))

    def u(self, lo: float, hi: float) -> float:
        return float(self.r.uniform(lo, hi))

    def logu(self, lo: float, hi: float) -> float:
        return float(np.exp(self.r.uniform(np.log(lo), np.log(hi))))

    def strat(self, key: str, lo: float, hi: float) -> float:
        perm = dsp.rng(_crc(self.sid, key, self.seed)).permutation(self.count)
        frac = (perm[self.i] + self.r.uniform(0.15, 0.85)) / self.count
        return lo + (hi - lo) * frac

    def strat_int(self, key: str, lo: int, hi: int) -> int:
        return int(np.clip(round(self.strat(key, lo - 0.49, hi + 0.49)), lo, hi))

    def chance(self, p: float) -> bool:
        return bool(self.r.random() < p)

    def sign(self) -> float:
        return 1.0 if self.r.random() < 0.5 else -1.0


# =============================================================================
# family-local DSP helpers
# =============================================================================

def unit(x: np.ndarray) -> np.ndarray:
    """Peak-normalize to 1 (so component levels below are true peak levels)."""
    return dsp.peak_norm(np.asarray(x, float))


def noise(v: Variant, n: int) -> np.ndarray:
    return v.r.standard_normal(n)


def _rms_unit(x: np.ndarray) -> np.ndarray:
    r = float(np.sqrt(np.mean(np.square(x))))
    return x / r if r > 0 else x


def iir(x: np.ndarray, b, a, pad: float = 0.25) -> np.ndarray:
    """Causal IIR filter evaluated through its frequency response (fast).
    Exact while the impulse response decays inside `pad` seconds."""
    n = len(x)
    nf = dsp._nfft(n + nsamp(pad))
    H = np.fft.rfft(np.asarray(b, float), nf) / np.fft.rfft(np.asarray(a, float), nf)
    return np.fft.irfft(np.fft.rfft(x, nf) * H, nf)[:n]


_BUTTER4_Q = (0.5412, 1.3066)


def lp_causal(x: np.ndarray, fc: float, order: int = 4) -> np.ndarray:
    """Causal Butterworth lowpass (order 2 or 4). Used on transients."""
    for q in (_BUTTER4_Q if order >= 4 else (0.7071,)):
        x = iir(x, *dsp.biquad_coeffs("lp", fc, q))
    return x


def hp_causal(x: np.ndarray, fc: float, order: int = 2) -> np.ndarray:
    for q in (_BUTTER4_Q if order >= 4 else (0.7071,)):
        x = iir(x, *dsp.biquad_coeffs("hp", fc, q))
    return x


def bp_causal(x: np.ndarray, fc: float, q: float) -> np.ndarray:
    """Causal constant-peak-gain band-pass resonance (RBJ bp)."""
    return iir(x, *dsp.biquad_coeffs("bp", fc, q))


def ctrl(v: Variant, n: int, cutoff: float) -> np.ndarray:
    """Random control signal with ~cutoff Hz bandwidth, zero mean, unit std."""
    m = nsamp(0.04)
    y = dsp.fft_band(v.r.standard_normal(n + 2 * m), hi=cutoff, order=2)[m:m + n]
    s = np.std(y)
    return y / s if s > 0 else y


def env_pts(n: int, pts) -> np.ndarray:
    """Envelope through (time, level) points with cosine-smoothed segments."""
    t = dsp.taxis(n)
    pts = sorted(pts)
    tp = np.array([p[0] for p in pts], float)
    lv = np.array([p[1] for p in pts], float)
    idx = np.clip(np.searchsorted(tp, t, side="right") - 1, 0, len(tp) - 2)
    t0, t1 = tp[idx], tp[idx + 1]
    w = np.clip((t - t0) / np.maximum(t1 - t0, 1e-9), 0.0, 1.0)
    w = 0.5 - 0.5 * np.cos(np.pi * w)
    e = lv[idx] * (1 - w) + lv[idx + 1] * w
    e[t <= tp[0]] = lv[0]
    e[t >= tp[-1]] = lv[-1]
    return e


def tv_bandpass(x: np.ndarray, fc: np.ndarray, bw_oct: float = 1.2,
                frame: int = 512, hop: int = 128) -> np.ndarray:
    """Time-varying Gaussian band-pass (overlap-add STFT). fc: Hz per sample."""
    n = len(x)
    fc = np.broadcast_to(np.asarray(fc, float), (n,))
    win = np.hanning(frame + 1)[:-1]
    xp = np.concatenate([np.zeros(frame), x, np.zeros(frame)])
    out = np.zeros_like(xp)
    norm = np.zeros_like(xp)
    lf = np.log2(np.maximum(np.fft.rfftfreq(frame, 1.0 / SR), 1.0))
    sig = bw_oct / 2.355
    for s in range(0, len(xp) - frame + 1, hop):
        c = int(np.clip(s - frame // 2, 0, n - 1))
        H = np.exp(-0.5 * ((lf - np.log2(max(fc[c], 20.0))) / sig) ** 2)
        out[s:s + frame] += np.fft.irfft(np.fft.rfft(xp[s:s + frame] * win) * H, frame)
        norm[s:s + frame] += win
    norm[norm < 1e-6] = 1.0
    return (out / norm)[frame:frame + n]


def times_from_env(v: Variant, env: np.ndarray, count: int) -> np.ndarray:
    """Draw `count` sample indices with probability proportional to env."""
    if count <= 0 or env.sum() <= 0:
        return np.zeros(0, int)
    cdf = np.cumsum(env) / env.sum()
    return np.searchsorted(cdf, v.r.random(count)).clip(0, len(env) - 1)


def contact_pulse(width: float) -> np.ndarray:
    """Unit-area Hann contact force pulse (wider = softer strike)."""
    m = max(2, nsamp(width))
    p = np.hanning(m + 2)[1:-1]
    return p / p.sum()


def noise_click(v: Variant, width: float) -> np.ndarray:
    """Very short Hann-windowed white-noise click (a hard, pitchless contact)."""
    m = max(3, nsamp(width))
    return noise(v, m) * np.hanning(m + 2)[1:-1]


def rumble(v: Variant, n: int, fc: float, spread_oct: float = 0.45, rate: float = 25.0) -> np.ndarray:
    """Pitchless low rumble with a perfectly smooth envelope: a sinusoid
    whose frequency wanders randomly (+-spread_oct octaves around fc, about
    `rate` Hz fast). Its spectrum is a broad band (no resonance, no beating)
    and its short-term level is constant, so an applied decay stays
    monotonic (used for the soil 'give' under a landing)."""
    f = fc * 2.0 ** (spread_oct * np.tanh(1.2 * ctrl(v, n, rate)))
    return np.sin(2 * np.pi * np.cumsum(f) / SR + v.u(0.0, 2 * np.pi))


def tilt(x: np.ndarray, db_per_oct: float, pivot: float = 1500.0) -> np.ndarray:
    """Zero-phase spectral tilt (dB per octave around pivot Hz), for noise textures."""
    n = len(x)
    nf = dsp._nfft(n)
    f = np.maximum(np.fft.rfftfreq(nf, 1.0 / SR), 20.0)
    return np.fft.irfft(np.fft.rfft(x, nf) * 10 ** (db_per_oct * np.log2(f / pivot) / 20.0), nf)[:n]


def mix(dur: float, parts) -> np.ndarray:
    """parts: iterable of (start time s, signal, level dB)."""
    y = np.zeros(nsamp(dur))
    for t, sig, lev in parts:
        if sig is not None and len(sig):
            dsp.place(y, sig, t, db2lin(lev))
    return y


def _env5_db(y: np.ndarray) -> np.ndarray:
    k = nsamp(0.005)
    return 20 * np.log10(np.sqrt(np.convolve(y * y, np.ones(k) / k, mode="same")) + 1e-12)


def first_gap(y: np.ndarray, thresh_db: float = -35.0, max_len: float = 0.010):
    """First internal stretch longer than max_len whose 5 ms RMS stays below
    thresh_db re the peak and is followed by sound. Returns (start s, length s)."""
    e = _env5_db(y)
    q = e < e.max() + thresh_db
    i, n = nsamp(0.005), len(y)
    while i < n:
        if q[i]:
            j = i
            while j < n and q[j]:
                j += 1
            if j < n and (j - i) / SR > max_len:
                return i / SR, (j - i) / SR
            i = j
        else:
            i += 1
    return None


# Holes are judged against -35 dB re peak (5 ms RMS, 10 ms or longer). The
# detector here is 2 dB stricter (it also calls -33..-35 dB 'silent'), holes
# are filled 2 dB above its threshold and stray blips are ducked to -38 dB.
GAP_DB = -33.0
DUCK_DB = -38.0


def mix_gapless(dur: float, parts, max_gap: float = 0.009, keep: float = 0.005) -> np.ndarray:
    """mix(), then remove internal silent holes (5 ms RMS below GAP_DB re
    peak for more than max_gap, followed by sound) so no element plays as
    a separate, detached event: every part whose own peak lies after the
    hole is pulled earlier. A hole that no part can close (a faint click
    inside an already-decayed tail) is closed by ducking what follows it
    under the threshold."""
    parts = [list(p) for p in parts]
    for _ in range(10):
        y = mix(dur, parts)
        g = first_gap(y, GAP_DB, max_gap)
        if g is None:
            return y
        t0, length = g
        t1 = t0 + length
        movers = [p for p in parts if p[1] is not None and len(p[1])
                  and p[0] + int(np.argmax(np.abs(p[1]))) / SR >= t1 - 0.002 and p[0] > 0.0]
        if not movers:
            return _duck_after(y, DUCK_DB)
        for p in movers:
            p[0] = max(0.0, p[0] - (length - keep))
    return _duck_after(mix(dur, parts), DUCK_DB)


def _duck_after(y: np.ndarray, level_db: float) -> np.ndarray:
    """Smoothly attenuate what follows each remaining hole so its 5 ms RMS
    stays under level_db re the peak (the tail then simply fades out)."""
    g = first_gap(y, GAP_DB, 0.009)
    while g is not None:
        i1 = nsamp(g[0] + g[1])
        e = _env5_db(y)
        over = np.maximum(0.0, e[i1:] - (e.max() + level_db))
        gain = 10 ** (-np.maximum.accumulate(over[::-1])[::-1] / 20.0)
        k = nsamp(0.004)
        gain = np.convolve(np.concatenate([np.full(k, gain[0]), gain]), np.ones(k) / k, mode="same")[k:]
        y = y.copy()
        y[i1:] *= np.minimum(gain, 1.0)
        g2 = first_gap(y, GAP_DB, 0.009)
        if g2 is not None and abs(g2[0] - g[0]) < 1e-4:
            break
        g = g2
    return y


def with_tail(v: Variant, y: np.ndarray, target: float, lo: float, hi: float,
              knee_db: float = -30.0, end_db: float = -62.0) -> np.ndarray:
    """Settle tail (grit trickle, blades springing back, plank dust): from
    the last point where the 5 ms RMS envelope is above knee_db re peak, add
    smooth band noise (lo-hi Hz, order 2, light grain) that continues from
    that level and decays exponentially to end_db RMS at `target` seconds,
    so the file lasts about the spec duration and fades out in one smooth
    slope (it crosses the -35 dB line once, no detached events)."""
    n_out = max(len(y), nsamp(target + 0.03))
    y = np.concatenate([y, np.zeros(n_out - len(y))])
    e = _env5_db(y)
    pk = float(np.max(e))
    above = np.nonzero(e >= pk + knee_db)[0]
    if len(above) == 0:
        return y
    k = int(above[-1])
    t_k = k / SR
    if t_k >= target - 0.03:
        return y
    n = n_out - k
    t = dsp.taxis(n)
    tau = (target - t_k) / np.log(db2lin(knee_db - end_db))
    nz = dsp.fft_band(noise(v, n), lo, hi, 2)
    nz *= np.maximum(0.0, 1.0 + 0.3 * ctrl(v, n, 200.0))
    nz /= np.sqrt(np.mean(nz[:nsamp(0.02)] ** 2)) + 1e-12
    env = np.exp(-t / tau) * env_pts(n, [(0.0, 0.0), (0.012, 1.0), (1.0, 1.0)])
    level = db2lin(pk + knee_db - 3.0)  # RMS just under the knee, so the sum stays smooth
    y[k:] += level * nz * env
    return y


def bridge_gaps(v: Variant, y: np.ndarray, lo: float, hi: float) -> np.ndarray:
    """Last safety net against detached events: any remaining internal hole
    (5 ms RMS below GAP_DB re peak for more than 9 ms, followed by sound)
    gets a faint bed of the surface's settle texture (band noise lo-hi Hz)
    across it, 2 dB above the threshold, with 4 ms fades into its
    neighbours."""
    y = np.asarray(y, float).copy()
    for _ in range(8):
        g = first_gap(y, GAP_DB, 0.009)
        if g is None:
            break
        pk = float(np.max(_env5_db(y)))
        i0, i1 = nsamp(g[0]) - nsamp(0.004), nsamp(g[0] + g[1]) + nsamp(0.004)
        i0 = max(i0, 0)
        n = i1 - i0
        nz = dsp.fft_band(noise(v, n), lo, hi, 2)
        nz /= np.sqrt(np.mean(nz ** 2)) + 1e-12
        env = env_pts(n, [(0.0, 0.0), (0.006, 1.0), (n / SR - 0.006, 1.0), (n / SR, 0.0)])
        y[i0:i1] += db2lin(pk + GAP_DB + 2.0) * nz * env
    return y


# =============================================================================
# sound components
# =============================================================================

def thud(v: Variant, f0: float, tau: float = 0.008, dur: float = 0.07,
         noise_lp: float | None = None, noise_db: float | None = None,
         noise_tau: float | None = None, glide: float | None = None,
         attack: float | None = None, lp: float | None = None, glide_tau: float = 0.006,
         vary_tau: bool = True, flat: bool = False, second: bool = True) -> np.ndarray:
    """Heel/body impact on soft ground: a short damped sine whose pitch drops
    as the ground stiffens under load (glide, glide_tau), plus noise
    lowpassed at noise_lp. noise_db is the noise-to-sine ENERGY ratio, so
    the random part really carries that share.

    Every variant gets its own start phase, and any argument left as None is
    drawn per variant (tau x0.75-1.3, glide 1.15-1.5, attack 1-3 ms,
    noise_db -6..0, noise_lp 300-550 Hz), so the transient that sets the
    step rhythm is never identical. second=True adds the heel flattening
    after its edge lands: a second, weaker contact 2-7 ms later at a
    slightly different pitch, so the thump's waveform differs from step to
    step. flat=True replaces the noise by a random-FM rumble centred near
    0.42 x noise_lp (smooth decay, no random dips or rebounds, no
    resonance). The buffer end is faded so long tails never click."""
    n = nsamp(dur)
    t = dsp.taxis(n)
    if vary_tau:
        tau *= v.u(0.75, 1.3)
    glide = v.u(1.15, 1.5) if glide is None else glide
    attack = v.u(0.001, 0.003) if attack is None else attack
    noise_db = v.u(-6.0, 0.0) if noise_db is None else noise_db
    noise_lp = v.u(300.0, 550.0) if noise_lp is None else noise_lp
    f = f0 * (1.0 + (glide - 1.0) * np.exp(-t / glide_tau))
    ph = 2 * np.pi * np.cumsum(f) / SR + v.u(-0.8, 0.8)
    body = np.sin(ph) * dsp.ar_env(n, attack, tau)
    if second:
        d = nsamp(v.u(0.002, 0.007))
        m = n - d
        b2 = np.sin(2 * np.pi * f0 * v.u(0.8, 1.25) * dsp.taxis(m) + v.u(-0.8, 0.8))
        body[d:] += v.u(0.35, 0.8) * b2 * dsp.ar_env(m, attack, tau * v.u(0.6, 1.0))
    if flat:
        nz = rumble(v, n, noise_lp * 0.42)
    else:
        nz = dsp.fft_band(noise(v, n), hi=noise_lp, order=2)
    nz = nz * dsp.ar_env(n, attack * 0.6, noise_tau or tau * 0.8)
    y = _rms_unit(body) + db2lin(noise_db) * _rms_unit(nz)
    if lp:
        y = lp_causal(y, lp, 4)
    return unit(dsp.fade_out(y, min(0.02, dur * 0.25)))


def sole_contact(v: Variant, lo: float = 250.0, hi: float = 2000.0,
                 attack: float | None = None, tau: float | None = None) -> np.ndarray:
    """Sole/body contact noise: the broadband 250-2000 Hz 'pat' of a shoe
    meeting the ground, which fuses heel thud and high scuff into one
    footfall. Noise band-limited (order 2), fast attack (0.8-1.5 ms), 12-20
    ms decay, with a little friction grain."""
    attack = v.u(0.0008, 0.0015) if attack is None else attack
    tau = v.u(0.012, 0.020) if tau is None else tau
    n = nsamp(attack + 6.0 * tau)
    nz = dsp.fft_band(noise(v, n), lo, hi, 2)
    grain = np.maximum(0.2, 1.0 + 0.45 * ctrl(v, n, 180.0))
    return unit(dsp.fade_out(nz * grain * dsp.ar_env(n, attack, tau), 0.008))


def slap(v: Variant, lo: float = 600.0, hi: float = 3500.0, tau: float = 0.0018) -> np.ndarray:
    """Leather sole slap: a few ms of band-passed noise at heel contact."""
    n = nsamp(0.015)
    return unit(dsp.fft_band(noise(v, n), lo, hi, 2) * dsp.ar_env(n, 0.0003, tau))


def clicks(v: Variant, n: int, idx, lo: float, hi: float,
           tau=(0.0001, 0.0004), spread: float = 0.6, amp_env: np.ndarray | None = None,
           band: bool = True) -> np.ndarray:
    """Sparse grit/stem clicks: tiny damped sinusoids at random frequencies
    in [lo, hi] with lognormal amplitudes, band-limited to the same band."""
    y = np.zeros(n)
    for i in np.atleast_1d(idx):
        f = v.logu(lo, hi)
        ta = v.u(*tau)
        m = nsamp(ta * 7) + 3
        tt = dsp.taxis(m)
        c = np.exp(-tt / ta) * np.sin(2 * np.pi * f * tt + v.u(0, 0.6))
        c[:2] *= (0.35, 0.8)
        a = float(np.exp(v.r.normal(0.0, spread))) * v.r.choice((-1.0, 1.0))
        if amp_env is not None:
            a *= amp_env[int(i)]
        dsp.place(y, c, i / SR, a)
    if band and np.any(y):
        y = dsp.fft_band(y, lo * 0.75, hi * 1.25, 2)
    return y


def scuff(v: Variant, dur: float, lo: float, hi: float, attack: float,
          grit: int = 0, click_band=(1500.0, 6000.0), click_db: float = -2.0,
          am_rate: float = 80.0, am_depth: float = 0.7, sustain: float = 0.6,
          skid=None, click_tau=(0.0001, 0.0004), order: int = 3) -> np.ndarray:
    """Sole friction scuff: band noise with irregular friction AM, a soft
    attack, and `grit` sparse clicks placed where the scuff is loudest.
    skid=(f_start, f_end) blends in a band sweeping between those Hz."""
    n = nsamp(dur)
    nz = dsp.fft_band(noise(v, n), lo, hi, order)
    if skid is not None:
        sw = tv_bandpass(noise(v, n), np.geomspace(skid[0], skid[1], n), 1.4)
        nz = unit(nz) + 0.9 * unit(sw)
    am = np.maximum(0.08, 1.0 + am_depth * ctrl(v, n, am_rate))
    env = env_pts(n, [(0.0, 0.0), (attack, 1.0),
                      (attack + (dur - attack) * 0.4, sustain), (dur, 0.0)])
    y = unit(nz * am * env)
    if grit > 0:
        idx = times_from_env(v, env ** 0.8, grit)
        y = y + db2lin(click_db) * unit(clicks(v, n, idx, *click_band, tau=click_tau))
    return unit(y)


def crackle(v: Variant, dur: float, lo: float, hi: float, rate: float, pts,
            snaps: int = 0, snap_band=(1500.0, 4500.0), bed_db: float = -6.0,
            tick_tau=(0.00006, 0.00025), spread: float = 0.7,
            snap_db: float = 2.0, bed_band=(800.0, 7000.0)) -> np.ndarray:
    """Crushed grass: many tiny stem ticks (density follows the envelope),
    a few louder stem snaps, over a granular crushed-blade noise bed with its
    own, wider band (bed_band, order 2) so the crush has body below 1 kHz."""
    n = nsamp(dur)
    env = env_pts(n, pts)
    count = int(rate * dur * float(np.mean(env)))
    idx = times_from_env(v, env, count)
    y = unit(clicks(v, n, idx, lo, hi, tau=tick_tau, spread=spread,
                    amp_env=np.sqrt(env)))
    if snaps > 0:
        sidx = times_from_env(v, env ** 2, snaps)
        s = clicks(v, n, sidx, *snap_band, tau=(0.0004, 0.0011), spread=0.3)
        y = y + db2lin(snap_db) * unit(s)
    bed = dsp.fft_band(noise(v, n), bed_band[0], bed_band[1], 2)
    grain = np.maximum(0.0, 1.0 + 0.9 * ctrl(v, n, 350.0)) ** 1.5
    y = y + db2lin(bed_db) * unit(bed * grain * env)
    return unit(y)


def swish(v: Variant, dur: float, fc: float, peak_frac: float = 0.45,
          flutter: float = 0.35, tick_db: float = -3.0, tick_band=(1200.0, 8000.0)) -> np.ndarray:
    """Leg or foot brushing through grass: noise through a wide (2.5-3
    octave) band whose centre moves only x1.3-1.6 around fc with a random,
    non-monotonic wobble (no 'riser' sweep), plus a dense stream of stem
    ticks (800-1500/s) following the same bell envelope: blade texture."""
    n = nsamp(dur)
    bw = v.u(2.5, 3.0)
    sweep = v.u(1.3, 1.6) ** v.sign()
    s = np.linspace(-0.5, 0.5, n)
    traj = fc * sweep ** s * 2.0 ** (0.18 * np.tanh(ctrl(v, n, 12.0)))
    y = tv_bandpass(noise(v, n), traj, bw)
    env = env_pts(n, [(0.0, 0.0), (dur * peak_frac, 1.0), (dur, 0.0)])
    am = np.maximum(0.2, 1.0 + flutter * ctrl(v, n, 45.0))
    body = unit(y * env * am)
    rate = v.u(800.0, 1500.0)
    idx = times_from_env(v, env, int(rate * dur * float(np.mean(env))))
    ticks = clicks(v, n, idx, *tick_band, tau=(0.00006, 0.0003), spread=0.7,
                   amp_env=np.sqrt(env))
    return unit(body + db2lin(tick_db) * unit(ticks))


def grain_stream(v: Variant, env: np.ndarray, rate_lo: float, rate_hi: float) -> np.ndarray:
    """Poisson stream of micro-crinkle grains: the rate follows env between
    rate_lo and rate_hi per second; each grain is 2-8 ms of Hann-windowed
    white noise with a lognormal amplitude (sigma 0.6) scaled by sqrt(env)."""
    n = len(env)
    lam = rate_lo + (rate_hi - rate_lo) * env
    count = int(v.r.poisson(lam.sum() / SR))
    y = np.zeros(n)
    for i in times_from_env(v, lam, count):
        m = nsamp(v.u(0.002, 0.008))
        g = noise(v, m) * np.hanning(m + 2)[1:-1]
        dsp.place(y, g, i / SR, float(np.exp(v.r.normal(0.0, 0.6))) * np.sqrt(env[i]))
    return y


def cloth(v: Variant, dur: float, attack: float | None = None, env: np.ndarray | None = None,
          wool=(350.0, 2500.0), linen=(1500.0, 6000.0), band=(300.0, 7000.0),
          linen_db: float = -3.0, rate_hi: float | None = None, bed_db: float = -10.0) -> np.ndarray:
    """Wool coat + linen shirt rustle. Each layer is a Poisson stream of
    micro-crinkle grains (grainy micro-friction) over a smooth noise bed at
    bed_db, band-limited (order 2) to its own band; band edges move +-20%
    per variant. Wool (350-2500 Hz) gives the 250-1000 Hz body, linen the
    crisp top. The envelope is a soft swell (or `env`); the grains are
    micro-crinkles, never a hard transient."""
    n = nsamp(dur)
    if env is None:
        attack = attack if attack is not None else dur * 0.35
        env = env_pts(n, [(0.0, 0.0), (attack, 1.0),
                          (attack + (dur - attack) * 0.4, 0.75), (dur, 0.0)])
    rate_hi = v.u(90.0, 150.0) if rate_hi is None else rate_hi

    def layer(lo: float, hi: float) -> np.ndarray:
        lo, hi = lo * v.u(0.8, 1.2), hi * v.u(0.8, 1.2)
        g = dsp.fft_band(grain_stream(v, env, 40.0, rate_hi), lo, hi, 2)
        bed = dsp.fft_band(noise(v, n), lo, hi, 2) * env
        return unit(g) + db2lin(bed_db) * unit(bed)

    y = unit(layer(*wool)) + db2lin(linen_db) * unit(layer(*linen))
    y = dsp.fft_band(y, band[0], band[1], 2)
    return unit(dsp.fade_out(y, min(0.02, dur * 0.1)))


def knock(v: Variant, modes, amps, taus, soft: float | None = 0.0025, hard: float | None = None,
          hard_db: float = 0.0, soft_db: float = -4.0, dur: float = 0.25, detune: float = 0.08,
          rough: float = 0.25, tick_db: float | None = -8.0, tick_band=(1200.0, 5000.0),
          extra: int = 12, extra_band=(350.0, 3000.0), extra_tau=(0.004, 0.015),
          extra_db=(-16.0, -8.0), noise_db: float | None = -10.0,
          amp_spread=(0.6, 1.66), tau_spread=(0.75, 1.25), balance=None) -> np.ndarray:
    """Plank knock by modal synthesis.

    Per variant the named modes are detuned (+-detune), their amplitudes
    scaled by a strike-position factor (log-uniform amp_spread, +-4.4 dB;
    a wider spread compounds into +-12 dB brightness swings) with a
    random sign for every mode but the first (the strike point falls on
    either side of that mode's nodal lines), and their
    decays by tau_spread; `extra` weak minor modes (extra_band, decays
    extra_tau, shorter at high frequency, each measured to sit extra_db re
    the first mode) fill the spectrum so it is not a marimba.
    The board is driven by two contact pulses: a hard heel pulse (`hard`
    wide, 0.5-1 ms by default; its spectrum reaches the 500 Hz-2 kHz
    'knock') plus the soft body-weight pulse (`soft` wide) at soft_db, and
    by a short noise burst (grain). A surface tick marks the hard contact.

    balance: optional list of (lo_db, hi_db) per named mode after the first.
    Then each named mode's amplitude is set from measurement so that its
    level in the first 80 ms (Hann window, the way the step is heard and
    checked) sits a per-variant random lo..hi dB re the first mode; the
    strike-position variety is drawn inside that window instead of from
    amp_spread (which can compound to +-12 dB of brightness)."""
    freqs = [f * (1.0 + v.u(-detune, detune)) for f in modes]
    amps = [a * v.logu(*amp_spread) * (1.0 if k == 0 else v.sign()) for k, a in enumerate(amps)]
    taus = [t * v.u(*tau_spread) for t in taus]
    hard = v.u(0.0005, 0.0010) if hard is None else hard
    pulses = [(contact_pulse(hard), db2lin(hard_db))]
    if soft:
        pulses.append((contact_pulse(soft), db2lin(soft_db)))
    ex = np.zeros(max(len(p) for p, _ in pulses))
    for p, g in pulses:
        ex[:len(p)] += g * p
    ex = ex * (1.0 + rough * v.r.standard_normal(len(ex)))
    if balance is not None:
        # heard level of each unit mode through this excitation; the
        # correction is capped at +-12 dB against a flat excitation, so a
        # mode that falls near a spectral null of the contact pulse is not
        # blown up
        lv = [_mode_level(ex, f, t) for f, t in zip(freqs, taus)]
        flat = [_mode_level(_DELTA, f, t) for f, t in zip(freqs, taus)]
        amps = [amps[0] / abs(amps[0])]
        for k in range(1, len(freqs)):
            want = db2lin(v.u(*balance[k - 1])) * lv[0] / lv[k]
            ref = db2lin(v.u(*balance[k - 1])) * flat[0] / flat[k]
            amps.append(v.sign() * float(np.clip(want, ref / 4.0, ref * 4.0)))
    lv0 = _mode_level(_DELTA, freqs[0], taus[0]) * abs(amps[0])
    for _ in range(extra):
        f = v.logu(*extra_band)
        ta = max(0.0025, v.u(*extra_tau) * min(1.0, (1000.0 / f) ** 0.6))
        freqs.append(f)
        taus.append(ta)
        # extras are set against a flat excitation; the real contact pulse
        # then rolls them off naturally
        amps.append(v.sign() * db2lin(v.u(*extra_db)) * lv0 / _mode_level(_DELTA, f, ta))
    h = dsp.modal_ir(freqs, taus, amps, dur)  # zero phase: starts at rest
    n = nsamp(dur)
    y = unit(dsp.fftconvolve(ex, h)[:n])
    if noise_db is not None:
        m = nsamp(0.006)
        burst = dsp.fft_band(noise(v, m), 60.0, 3000.0, 2) * dsp.ar_env(m, 0.0004, 0.0012)
        y = y + db2lin(noise_db) * unit(dsp.fftconvolve(burst, h)[:n])
    if tick_db is not None:
        m = nsamp(0.012)
        tick = dsp.fft_band(noise(v, m), *tick_band, 2) * dsp.ar_env(m, 0.0002, 0.0012)
        dsp.place(y, unit(tick), 0.0, db2lin(tick_db))
    return unit(dsp.fade_out(y, min(0.02, dur * 0.2)))


_DELTA = np.array([1.0])


def _mode_level(ex: np.ndarray, f: float, tau: float, win: float = 0.08) -> float:
    """Level of one mode (unit amplitude) driven by `ex`, as a Hann-windowed
    `win`-second spectrum sees it at the mode frequency."""
    m = nsamp(win)
    y = dsp.fftconvolve(ex, dsp.modal_ir([f], [tau], [1.0], win))[:m]
    k = np.arange(m)
    return float(np.abs(np.sum(y * np.hanning(m) * np.exp(-2j * np.pi * f * k / SR)))) + 1e-12


def creak(v: Variant, dur: float, f_lo: float, f_hi: float, attack: float = 0.03,
          release: float = 0.05, noise_db: float = -16.0) -> np.ndarray:
    """Board creak from stick-slip friction: a slip-impulse train whose rate
    glides inside [f_lo, f_hi] Hz (the creak pitch), with grip flutter and
    per-slip jitter, convolved with a wooden body's modal response."""
    n = nsamp(dur)
    span = f_hi - f_lo
    fa = v.u(f_lo, f_lo + 0.35 * span)
    fb = v.u(f_lo + 0.55 * span, f_hi)
    fc = v.u(f_lo, 0.5 * (fa + fb))
    tmid = dur * v.u(0.35, 0.7)
    traj = env_pts(n, [(0.0, fa), (tmid, fb), (dur, fc)])
    traj *= 1.0 + 0.04 * ctrl(v, n, 18.0)
    grip = env_pts(n, [(0.0, 0.0), (attack, 1.0), (dur - release, v.u(0.6, 0.95)), (dur, 0.0)])
    grip *= np.clip(0.75 + 0.3 * ctrl(v, n, 14.0), 0.2, 1.3)

    def rate(t, _tr=traj):
        return float(_tr[min(int(t * SR), n - 1)])

    def amp(t, _g=grip):
        return float(_g[min(int(t * SR), n - 1)])

    train = dsp.stick_slip_train(dur, rate, v.r, jitter=0.05, amp=amp, amp_jitter=0.35)
    k = np.exp(-dsp.taxis(nsamp(0.001)) / 0.00015)  # slip: fast rise, quick relax
    ex = dsp.fftconvolve(train, k)[:n]
    body_f = [v.u(380, 520), v.u(700, 900), v.u(1150, 1450), v.u(1900, 2400), v.u(2900, 3500)]
    body_t = [0.012, 0.009, 0.007, 0.005, 0.004]
    body_a = [1.0, 0.8, 0.6, 0.4, 0.25]
    y = unit(dsp.fftconvolve(ex, dsp.modal_ir(body_f, body_t, body_a, 0.08))[:n])
    fric = dsp.fft_band(noise(v, n), 1200.0, 4500.0, 2) * grip
    y = hp_causal(y + db2lin(noise_db) * unit(fric), 110.0)
    return unit(y)


def rattle(v: Variant, ticks: int, first_gap: float, ratio: float = 0.7,
           f_lo: float = 600.0, f_hi: float = 1800.0, decay: float = 0.6,
           tau=(0.002, 0.004)) -> np.ndarray:
    """A loose board bouncing on its nails: ticks at shrinking intervals
    (bouncing-ball timing), each a small, well-damped modal knock (2-4 ms)
    plus a noise click for the edge clack."""
    times, t, gap = [], 0.0, first_gap
    for _ in range(ticks):
        times.append(t)
        t += gap * v.u(0.85, 1.15)
        gap *= ratio
    y = np.zeros(nsamp(t + 0.05))
    for k, tt in enumerate(times):
        f = v.u(f_lo, f_hi)
        ta = v.u(*tau)
        freqs = [f, f * v.u(1.5, 1.8), f * v.u(2.4, 2.9), v.u(180, 300)]
        tick = dsp.fftconvolve(contact_pulse(v.u(0.0003, 0.0007)),
                               dsp.modal_ir(freqs, [ta, ta * 0.7, ta * 0.5, 0.005],
                                            [1.0, 0.6, 0.35, 0.4], 0.03))
        clk = dsp.fft_band(noise_click(v, v.u(0.0003, 0.0008)), 800.0, 7000.0, 2)
        tick = unit(tick)
        dsp.place(tick, unit(clk), 0.0, db2lin(v.u(-6.0, -2.0)))
        dsp.place(y, unit(tick), tt, decay ** k * v.u(0.75, 1.0))
    return unit(y)


def horn_knock(v: Variant) -> np.ndarray:
    """Powder horn knocking against kit: a hollow, pitchless 'tok'. 5-7
    horn-wall modes spread over 700-2200 Hz with amplitudes within 6 dB of
    each other, each split into a doublet 8-14% wide (the horn is not
    round) and decaying in 3-5 ms at the lowest mode, faster up high
    (tau ~ f^-0.7), so every peak stays broad (Q about 6-8, no sine 'boop'),
    excited by a 3-5 ms noise burst;
    plus a -10 dB woody tick and the air-cavity mode at 0.55-0.7 x the
    lowest wall mode."""
    k = int(v.r.integers(5, 8))
    f_lo = v.u(700.0, 820.0)
    base = np.geomspace(f_lo, v.u(1900.0, 2200.0), k)
    freqs, taus, amps = [], [], []
    for f in base:
        f *= 1.0 + v.u(-0.05, 0.05)
        ta = v.u(0.003, 0.005) * (f_lo / f) ** 0.7
        a = db2lin(v.u(-6.0, 0.0))
        split = v.u(0.04, 0.07)
        for fs, g in ((f * (1 - split), 1.0), (f * (1 + split), v.u(0.6, 1.0))):
            freqs.append(fs)
            taus.append(ta * v.u(0.85, 1.15))
            amps.append(a * g)
    h = dsp.modal_ir(freqs, taus, amps, 0.08, r=v.r)
    m = nsamp(v.u(0.003, 0.005))
    burst = noise(v, m) * dsp.ar_env(m, 0.0003, m / SR / 3.0)
    y = unit(dsp.fftconvolve(burst, h)[:nsamp(0.08)])
    tick = dsp.fft_band(noise_click(v, v.u(0.0004, 0.0008)), 1000.0, 5000.0, 2)
    dsp.place(y, unit(tick), 0.0, db2lin(-10.0))
    cav = dsp.fftconvolve(dsp.fft_band(noise(v, nsamp(0.004)), 300, 2000, 2),
                          dsp.modal_ir([f_lo * v.u(0.55, 0.7)], [0.005], [1.0], 0.04))[:nsamp(0.08)]
    dsp.place(y, unit(cav), 0.0, db2lin(-10.0))
    return unit(dsp.fade_out(hp_causal(y, 300.0, 2), 0.01))


def leather_thump(v: Variant) -> np.ndarray:
    """Cartridge box / pouch bumping the hip: dull, lowpassed at 800 Hz."""
    n = nsamp(0.08)
    nz = dsp.fft_band(noise(v, n), 60.0, 800.0, 2) * dsp.ar_env(n, 0.002, v.u(0.010, 0.016))
    body = np.sin(2 * np.pi * v.u(140, 220) * dsp.taxis(n) + v.u(-0.8, 0.8)) * dsp.ar_env(n, 0.002, 0.012)
    return unit(lp_causal(unit(nz) + db2lin(-4.0) * unit(body), 800.0, 4))


METAL_RATIOS = (1.0, 1.5, 2.0, 2.5, 2.9, 3.6, 1.24, 1.77, 3.25, 4.1)


def metal_ticks(v: Variant, count: int) -> np.ndarray:
    """Buckle / tin-cup jingle: `count` metal ticks, each a 0.1-0.3 ms noise
    click exciting 6-10 inharmonic partials over 2.5-11 kHz (ratios near
    1, 1.5, 2, 2.5, 2.9, 3.6 ... each +-5%) with random amplitudes; higher
    partials decay faster. Buckle ticks decay in 1.5-4 ms, cup ticks in
    8-15 ms."""
    y = np.zeros(nsamp(0.2))
    t = 0.0
    for k in range(count):
        f0 = v.u(2500.0, 3100.0)
        npart = int(v.r.integers(6, 11))
        freqs = [f0 * r * (1.0 + v.u(-0.05, 0.05)) for r in METAL_RATIOS[:npart]]
        freqs = [f for f in freqs if f <= 11000.0]
        tau0 = v.u(0.008, 0.015) if v.chance(0.5) else v.u(0.0015, 0.004)
        taus = [tau0 * (f0 / f) ** 0.8 for f in freqs]
        amps = [v.logu(0.2, 1.0) for _ in freqs]
        h = dsp.modal_ir(freqs, taus, amps, 0.1, r=v.r)
        tick = dsp.fftconvolve(noise_click(v, v.u(0.0001, 0.0003)), h)
        dsp.place(y, unit(tick), t, (0.8 ** k) * v.u(0.6, 1.0))
        t += v.u(0.008, 0.035)
    return unit(dsp.fft_band(y, 2000.0, 12000.0, 2))


def settle(v: Variant, dur: float, lo: float = 1500.0, hi: float = 5000.0,
           n_clicks=(2, 5), bed_db: float = -4.0) -> np.ndarray:
    """Loose grit trickling and settling after the foot rolls off: a
    smoothly decaying grain bed (the level reference) with a few clicks
    bed_db above it that decay with the bed, so the tail fades without
    late, detached ticks."""
    n = nsamp(dur)
    t = dsp.taxis(n)
    env = np.exp(-t / (dur * 0.3)) * env_pts(n, [(0.0, 0.0), (0.008, 1.0), (dur * 0.7, 1.0), (dur, 0.0)])
    grain = np.maximum(0.0, 1.0 + 0.7 * ctrl(v, n, 250.0))
    bed = dsp.fft_band(noise(v, n), lo, hi, 2) * env * grain
    idx = times_from_env(v, env ** 2, int(v.r.integers(n_clicks[0], n_clicks[1] + 1)))
    cl = clicks(v, n, idx, lo, hi, amp_env=env)
    return unit(unit(bed) + db2lin(-bed_db) * unit(cl) if np.any(cl) else bed)


def clods(v: Variant, times, dur: float, lo: float = 300.0, hi: float = 1500.0) -> np.ndarray:
    """Dirt clods kicked up and dropping back: each a 20-40 ms noise burst
    through a low-Q (1.5-3) resonance at lo-hi Hz (a dull, pitchless
    'pock'), plus a little grit."""
    y = np.zeros(nsamp(dur))
    for tc in times:
        m = nsamp(v.u(0.02, 0.04))
        burst = noise(v, m) * dsp.ar_env(m, 0.0003, v.u(0.003, 0.007))
        body = bp_causal(burst, v.logu(lo, hi), v.u(1.5, 3.0), )
        grit = dsp.fft_band(noise(v, m), 200.0, 1500.0, 2) * dsp.ar_env(m, 0.0002, 0.002)
        c = dsp.fade_out(unit(body) + 0.5 * unit(grit), 0.005)
        dsp.place(y, unit(c), tc, v.u(0.4, 1.0))
    return unit(y)


# =============================================================================
# recipes: dirt
# =============================================================================
# sole_contact (250-2000 Hz contact noise) starts 0-3 ms after the heel. Its
# PEAK level re the heel is about 0 dB on dirt walk/run/sprint, -2..-4 on
# grass, -10 on dirt crouch and +1 on landings: a noise burst has ~12 dB more
# crest factor than the heel sine, so these peak levels put it 8-12 dB under
# the heel in RMS. That is what it takes to reach the midrange targets (at
# least 10-15 % of the energy in 500-2000 Hz, at most 50 % below 200 Hz on
# walk/run steps); the -8/-5/-12/-16 dB peak levels first tried left the
# heel with 70-85 % of the energy.

def _toe(v: Variant, f0: float, level: float, tau=(0.008, 0.014)):
    """Ball of the foot: mostly broadband mid contact noise, sometimes a
    faint low 'bump' sine 9 dB under it."""
    toe = sole_contact(v, 200.0, 2200.0, attack=v.u(0.002, 0.004), tau=v.u(*tau))
    parts = [(0.0, toe, level)]
    if v.chance(0.5):
        parts.append((0.0, thud(v, f0 * v.u(1.3, 1.6), tau=0.005, dur=0.03, noise_db=-20.0,
                                second=False), level - 9.0))
    return mix(0.12, parts)


def step_dirt_walk(v: Variant) -> np.ndarray:
    hard = v.u(0.0, 1.0)  # 0 = moccasin, 1 = hard leather heel
    f0 = 120.0 * v.strat("pitch", 0.9, 1.1)
    gap = v.strat("gap", 0.040, 0.070)
    grit = v.strat_int("grit", 3, 10)
    heel = thud(v, f0, tau=0.0075, dur=0.06, attack=0.003 - 0.002 * hard)
    sc = scuff(v, 0.060, 700.0, 5000.0, attack=0.018, grit=grit, order=2,
               click_band=(1500.0, 6000.0), click_db=-1.0)
    tail = settle(v, v.u(0.11, 0.14), 1200.0, 5000.0, n_clicks=(1, 4))
    return mix_gapless(0.26, [
        (0.002, heel, -3.0),
        (0.002 + v.u(0.0, 0.003), sole_contact(v), -3.0),
        (0.002, slap(v), -20.0 + 8.0 * hard),
        (0.002 + gap - 0.006, _toe(v, f0, 0.0), -5.0),
        (0.002 + gap, sc, -6.0),
        (0.002 + gap + 0.04, tail, -24.0),
    ])


def step_dirt_run(v: Variant) -> np.ndarray:
    f0 = 135.0 * v.strat("pitch", 0.9, 1.1)  # spec 90-180 Hz
    gap = v.strat("gap", 0.015, 0.030)
    grit = v.strat_int("grit", 10, 20)
    heel = thud(v, f0, tau=0.0085, dur=0.06)
    spray = scuff(v, 0.090, 700.0, 6000.0, attack=0.008, grit=grit, order=2,
                  click_band=(1500.0, 6000.0), click_db=0.0, am_depth=0.85, sustain=0.55)
    tail = settle(v, v.u(0.09, 0.11), 1200.0, 6000.0, n_clicks=(2, 5))
    return mix_gapless(0.23, [
        (0.002, heel, -1.0),
        (0.002 + v.u(0.0, 0.003), sole_contact(v), -2.0),
        (0.002, slap(v), -15.0),
        (0.002 + gap - 0.004, _toe(v, f0, 0.0), -3.0),
        (0.002 + gap, spray, -3.0),
        (0.002 + gap + 0.06, tail, -22.0),
    ])


def step_dirt_sprint(v: Variant) -> np.ndarray:
    f0 = 115.0 * v.strat("pitch", 0.9, 1.1)
    push = v.strat("push", 0.035, 0.055)
    n_clods = v.strat_int("clods", 2, 4)
    heel = thud(v, f0, tau=0.011, dur=0.08)
    skid = scuff(v, 0.100, 700.0, 6000.0, attack=0.012, grit=v.strat_int("grit", 8, 15), order=2,
                 click_band=(1200.0, 6000.0), click_db=-1.0, am_rate=110.0,
                 am_depth=0.8, sustain=0.7, skid=(v.u(2600, 3400), v.u(1100, 1500)))
    t_clods = [v.u(0.07, 0.11), v.u(0.17, 0.215)] + [v.u(0.09, 0.2) for _ in range(n_clods - 2)]
    cl = clods(v, sorted(t_clods), 0.26)
    tail = settle(v, 0.10, 1200.0, 5000.0, n_clicks=(2, 4))
    return mix_gapless(0.28, [
        (0.002, heel, 0.0),
        (0.002 + v.u(0.0, 0.003), sole_contact(v), -2.0),
        (0.002, slap(v), -14.0),
        (0.010, _toe(v, f0, 0.0), -4.0),
        (0.002 + push, skid, -4.0),
        (0.002, cl, -12.0),
        (0.002 + push + 0.07, tail, -21.0),
    ])


def step_dirt_crouch(v: Variant) -> np.ndarray:
    f0 = 110.0 * v.strat("pitch", 0.9, 1.1)
    roll = v.strat("roll", 0.030, 0.050)
    heel = thud(v, f0, tau=0.007, dur=0.05, attack=v.u(0.0025, 0.0035), noise_db=v.u(0.0, 4.0))
    crunch = crackle(v, 0.150, 2000.0, 7000.0, rate=v.strat("grit", 160.0, 260.0),
                     pts=[(0.0, 0.0), (0.06, 1.0), (0.09, 0.8), (0.15, 0.0)],
                     bed_db=-4.0, spread=0.45, bed_band=(700.0, 7000.0))
    knee = cloth(v, 0.30, attack=v.u(0.09, 0.13))
    return mix_gapless(0.33, [
        (0.002, heel, -10.0),
        (0.002 + v.u(0.0, 0.003), sole_contact(v, tau=v.u(0.016, 0.022)), -20.0),
        (0.002 + roll, crunch, -9.0),
        (0.0, knee, -17.0),
    ])


# =============================================================================
# recipes: grass
# =============================================================================

def step_grass_walk(v: Variant) -> np.ndarray:
    f0 = 100.0 * v.strat("pitch", 0.9, 1.1)
    heel = thud(v, f0, tau=0.009, dur=0.06, lp=250.0, noise_db=v.u(-1.0, 4.0))
    crush = crackle(v, 0.170, 1200.0, 8000.0, rate=v.strat("stems", 250.0, 450.0),
                    pts=[(0.0, 0.0), (0.03, 1.0), (0.07, 0.7), (0.17, 0.0)],
                    snaps=v.strat_int("snaps", 1, 4), bed_db=-4.0)
    lift = v.strat("lift", 0.13, 0.17)
    sw = swish(v, 0.070, v.u(2600, 3400), peak_frac=0.4)
    return mix_gapless(0.32, [
        (0.002, heel, -4.0),
        (0.002 + v.u(0.0, 0.003), sole_contact(v), -6.0),
        (v.u(0.008, 0.02), crush, -0.5),
        (lift, sw, -9.5),
    ])


def step_grass_run(v: Variant) -> np.ndarray:
    f0 = 110.0 * v.strat("pitch", 0.9, 1.1)
    heel = thud(v, f0, tau=0.009, dur=0.06, lp=300.0, noise_db=v.u(-1.0, 4.0))
    crunch = crackle(v, 0.100, 1200.0, 8000.0, rate=v.strat("stems", 450.0, 700.0),
                     pts=[(0.0, 0.0), (0.012, 1.0), (0.045, 0.75), (0.10, 0.0)],
                     snaps=v.strat_int("snaps", 2, 5), bed_db=-3.0)
    leg = v.strat("leg", 0.085, 0.125)
    sw = swish(v, 0.120, v.u(2200, 3000), peak_frac=0.5)
    return mix_gapless(0.26, [
        (0.002, heel, 0.0),
        (0.002 + v.u(0.0, 0.003), sole_contact(v), -3.0),
        (v.u(0.004, 0.012), crunch, 1.0),
        (leg, sw, -5.0),
    ])


def step_grass_sprint(v: Variant) -> np.ndarray:
    f0 = 105.0 * v.strat("pitch", 0.9, 1.1)
    heel = thud(v, f0, tau=0.011, dur=0.08, lp=300.0, noise_db=v.u(-3.0, 3.0))
    turf = scuff(v, 0.120, 1000.0, 6000.0, attack=0.010, grit=v.strat_int("roots", 6, 12),
                 click_band=(800.0, 3000.0), click_db=-3.0, am_rate=120.0, am_depth=0.85,
                 sustain=0.65, click_tau=(0.0003, 0.0009))
    blades = crackle(v, 0.110, 1200.0, 8000.0, rate=550.0,
                     pts=[(0.0, 0.0), (0.01, 1.0), (0.05, 0.7), (0.11, 0.0)],
                     snaps=v.strat_int("snaps", 2, 5), bed_db=-5.0)
    legs = v.strat("legs", 0.08, 0.11)
    sw = swish(v, 0.150, v.u(2000, 2800), peak_frac=0.45)
    return mix_gapless(0.31, [
        (0.002, heel, 0.0),
        (0.002 + v.u(0.0, 0.003), sole_contact(v), -4.0),
        (0.018, turf, -3.0),
        (0.012, blades, -3.0),
        (legs, sw, -4.0),
    ])


def step_grass_crouch(v: Variant) -> np.ndarray:
    heel = thud(v, 100.0 * v.strat("pitch", 0.9, 1.1), tau=0.007, dur=0.05,
                attack=v.u(0.0035, 0.0045), lp=250.0, noise_db=v.u(0.0, 4.0))
    crush = crackle(v, 0.200, 1200.0, 8000.0, rate=v.strat("stems", 180.0, 280.0),
                    pts=[(0.0, 0.0), (0.06, 1.0), (0.11, 0.85), (0.20, 0.0)],
                    bed_db=-3.0, spread=0.4, tick_tau=(0.00005, 0.0002))
    cl = cloth(v, 0.34, attack=v.u(0.10, 0.15))
    return mix_gapless(0.37, [
        (0.002, heel, -30.0),
        (0.002 + v.u(0.0, 0.003), sole_contact(v, attack=v.u(0.003, 0.006), tau=v.u(0.018, 0.026)), -25.0),
        (v.strat("crush", 0.008, 0.030), crush, -12.0),
        (0.0, cl, -18.0),
    ])


# =============================================================================
# recipes: wood (plank floor, firing step, ramps)
# =============================================================================
# Mode amplitudes are set (knock balance=) so the 260 and 540 Hz modes sit
# 0 to -4 dB below the 90-110 Hz mode over the first 80 ms (the hollow
# 'knock' of a plank, not a 100 Hz tom); low-mode decays are 20-25 ms.

def plank_sole(v: Variant) -> np.ndarray:
    """Leather sole pressing and sliding on the plank at contact: broadband
    friction (500-5000 Hz) decaying in 12-20 ms. It fills the high band
    between the heel's surface tick and the toe, so the step is not just
    ringing modes (a 'marimba')."""
    return sole_contact(v, 500.0, 5000.0, attack=v.u(0.0005, 0.0012), tau=v.u(0.012, 0.020))


WOOD_MODES = (110.0, 260.0, 540.0)
# per-variant level window (dB re the 90-110 Hz mode, first 80 ms) for the
# 230-260 Hz, 520-540 Hz and ~1 kHz modes
WOOD_BALANCE = [(-4.5, -1.5), (-4.5, -1.5), (-10.0, -5.0)]


def step_wood_walk(v: Variant) -> np.ndarray:
    gap = v.strat("gap", 0.045, 0.055)
    hi_mode = v.u(900, 1100)
    heel = knock(v, WOOD_MODES + (hi_mode,), [1.0, 1.0, 1.0, 1.0],
                 [0.022, 0.016, 0.012, 0.007], soft=v.u(0.0022, 0.0034), dur=0.22,
                 balance=WOOD_BALANCE)
    toe = knock(v, WOOD_MODES + (hi_mode,), [1.0, 1.0, 1.0, 1.0],
                [0.020, 0.014, 0.011, 0.006], soft=v.u(0.002, 0.003), dur=0.2, tick_db=-10.0,
                balance=WOOD_BALANCE)
    grit = scuff(v, 0.070, 1500.0, 5000.0, attack=0.012, grit=int(v.r.integers(2, 5)),
                 click_band=(2000.0, 6000.0), click_db=-3.0)
    tail = settle(v, v.u(0.16, 0.20), 1500.0, 6000.0, n_clicks=(2, 4))
    parts = [
        (0.002, heel, 0.0),
        (0.002 + v.u(0.0, 0.002), plank_sole(v), -16.0),
        (0.002 + gap, toe, -4.0),
        (0.002 + gap + v.u(0.0, 0.002), plank_sole(v), -20.0),
        (0.002 + gap + 0.004, grit, -18.0),
        (0.002 + gap + 0.03, tail, -28.0),
    ]
    if v.i == 2:  # one variant of three carries the board creak
        parts.append((0.002 + gap + v.u(0.02, 0.04),
                      creak(v, 0.150, 190.0, 320.0, attack=0.025, release=0.05), -10.0))
    return mix_gapless(0.34, parts)


def step_wood_run(v: Variant) -> np.ndarray:
    hit = knock(v, (100.0, 260.0, 540.0, v.u(950, 1150)), [1.0, 1.0, 1.0, 1.0],
                [0.024, 0.017, 0.012, 0.007], soft=v.u(0.0017, 0.0025), dur=0.25,
                balance=WOOD_BALANCE)
    toe = knock(v, WOOD_MODES, [1.0, 1.0, 1.0], [0.02, 0.014, 0.011],
                soft=v.u(0.0017, 0.0025), dur=0.12, balance=WOOD_BALANCE[:2])
    rt = rattle(v, v.strat_int("ticks", 1, 2), 0.018, f_lo=700.0, f_hi=1700.0)
    tail = settle(v, v.u(0.14, 0.17), 1500.0, 6000.0, n_clicks=(2, 4))
    body = thud(v, v.u(85.0, 100.0), tau=0.014, dur=0.08, noise_lp=300.0, noise_db=-3.0,
                glide=1.15, attack=0.002, lp=300.0, second=False)
    return mix_gapless(0.28, [
        (0.002, hit, 4.0),
        (0.002, body, -19.0),
        (0.002 + v.u(0.0, 0.002), plank_sole(v), -12.0),
        (0.002 + v.u(0.008, 0.014), toe, -3.0),
        (0.002 + v.strat("rattle", 0.035, 0.060), rt, -8.0),
        (0.04, tail, -22.0),
    ])


def step_wood_sprint(v: Variant) -> np.ndarray:
    hit = knock(v, (92.0, 240.0, 520.0, v.u(950, 1100)), [1.0, 1.0, 1.0, 1.0],
                [0.025, 0.018, 0.012, 0.007], soft=v.u(0.002, 0.003), dur=0.3,
                balance=[(-3.0, 0.0), (-3.0, 0.0), (-9.0, -4.0)])  # boom/rattle add to the low band
    boom = thud(v, v.u(80.0, 92.0), tau=0.018, dur=0.10, noise_lp=300.0, noise_db=-3.0, glide=1.15,
                attack=0.002, lp=300.0, second=False)
    scrape = scuff(v, 0.085, 1000.0, 5000.0, attack=0.012, grit=int(v.r.integers(4, 9)),
                   click_band=(1500.0, 6000.0), click_db=-2.0, am_rate=140.0, am_depth=0.9)
    rt = rattle(v, v.strat_int("ticks", 3, 4), 0.022, ratio=0.7, f_lo=600.0, f_hi=1600.0)
    tail = settle(v, v.u(0.16, 0.2), 1500.0, 6000.0, n_clicks=(2, 5))
    return mix_gapless(0.33, [
        (0.002, hit, 6.0),
        (0.002, boom, -14.0),
        (0.002 + v.u(0.0, 0.002), plank_sole(v), -10.0),
        (0.002 + v.strat("push", 0.045, 0.065), scrape, -6.0),
        (0.002 + v.u(0.03, 0.05), rt, -6.0),
        (0.06, tail, -20.0),
    ])


def step_wood_crouch(v: Variant) -> np.ndarray:
    soft = knock(v, WOOD_MODES, [1.0, 1.0, 1.0], [0.025, 0.016, 0.011],
                 soft=0.006, soft_db=0.0, hard=v.u(0.0015, 0.0025), hard_db=-8.0,
                 dur=0.2, tick_db=None, noise_db=-6.0, balance=[(-7.0, -3.0), (-9.0, -5.0)])
    ck = creak(v, v.u(0.24, 0.28), 150.0, 400.0, attack=v.u(0.04, 0.06), release=0.07)
    pad = sole_contact(v, 300.0, 3000.0, attack=v.u(0.002, 0.004), tau=v.u(0.012, 0.02))
    return mix_gapless(0.39, [
        (0.002, soft, -10.0),
        (0.002 + v.u(0.0, 0.004), pad, -10.0),
        (v.strat("creak", 0.050, 0.080), ck, -4.0),
    ])


# =============================================================================
# recipes: landings, jump, gear, cloth
# =============================================================================

def land_heel(v: Variant, f0: float, tau: float, give_db: float = 3.0, give_tau: float = 0.06,
              glide: float = 1.2, glide_tau: float = 0.008, attack: float = 0.002,
              spread_oct: float = 0.5, rise_oct: float = 0.5, rate: float = 35.0,
              dur: float = 0.3, lp: float | None = None, second=None) -> np.ndarray:
    """Landing heel on soil as ONE oscillator, so it can never beat against
    itself: it starts as a short heel thump at f0 (decay tau, set from a Q
    under 5, with a small pitch drop), and as the soil gives (15 ms) its
    frequency starts to wander randomly and fast (+-spread_oct octaves,
    about `rate` Hz, modulation index above 1) around a centre rise_oct
    above f0, clear of the 65 Hz highpass, while a slower component
    (give_tau, the spec's 60 ms) carries the envelope. The tail is a
    broadband, pitchless low rumble whose envelope is exactly the designed
    smooth, monotonic decay. give_db is the energy of the slow part
    relative to the thump.

    second=(gap, ratio, tau2, rel): the second foot's low end, merged into
    the same oscillator so the two feet cannot cancel or beat: at `gap` the
    pitch is pulled to ratio x (x1.25-1.5, clearly not unison) and relaxes
    back with tau2, and the envelope gets a bump of rel x its current level
    (kept small so the low band still falls monotonically). The second
    foot's slap is carried by its own sole-contact layer in the mids."""
    n = nsamp(dur)
    t = dsp.taxis(n)
    grow = 1.0 - np.exp(-t / 0.015)
    wander = np.tanh(0.9 * ctrl(v, n, rate))
    f = f0 * (1.0 + (glide - 1.0) * np.exp(-t / glide_tau)) * 2.0 ** (grow * (rise_oct + spread_oct * wander))
    g = np.sqrt(db2lin(give_db) ** 2 * tau / give_tau)
    env = dsp.ar_env(n, attack, tau) + g * dsp.ar_env(n, attack, give_tau)
    if second is not None:
        gap, ratio, tau2, rel = second
        k = nsamp(gap)
        bump = np.zeros(n)
        bump[k:] = dsp.ar_env(n - k, 0.0015, tau2)
        f = f * (1.0 + (ratio - 1.0) * bump)
        env = env + rel * env[k] * bump
    ph = 2 * np.pi * np.cumsum(f) / SR + v.u(-0.8, 0.8)
    y = np.sin(ph) * env
    if lp:
        y = lp_causal(y, lp, 4)
    return unit(dsp.fade_out(y, 0.03))


def _land_thuds(v: Variant, lp: float | None):
    """Low end of a two-foot landing: land_heel at f1 (Q 3.5-4.8, i.e. tau
    11-22 ms, small glide) whose soil give carries the spec's 60 ms decay,
    with the second foot 16-24 ms later merged into the same oscillator
    (pitch pulled to x1.25-1.5, tau <= 12 ms). Random overall polarity.
    Returns (low end, gap); each foot's slap is a sole_contact layer."""
    f1 = v.strat("pitch", 70.0, 105.0)  # spec 60-120 Hz
    gap = v.strat("gap", 0.016, 0.024)
    tau1 = min(0.026, v.u(3.5, 4.8) / (np.pi * f1))
    ratio = v.u(1.25, 1.5)
    tau2 = min(0.012, v.u(3.5, 4.8) / (np.pi * f1 * ratio))
    a = land_heel(v, f1, tau1, give_db=3.0, give_tau=0.06, lp=lp, dur=0.4,
                  second=(gap - 0.001, ratio, tau2, v.u(0.15, 0.3)))
    return a * v.sign(), gap


def land_dirt(v: Variant) -> np.ndarray:
    a, gap = _land_thuds(v, None)
    spray = scuff(v, 0.150, 700.0, 6000.0, attack=0.010, grit=v.strat_int("grit", 15, 28), order=2,
                  click_band=(1200.0, 6000.0), click_db=-1.0, am_depth=0.8, sustain=0.5)
    knee = cloth(v, 0.24, attack=0.05)
    tail = settle(v, v.u(0.14, 0.18), 1200.0, 5000.0, n_clicks=(3, 6))
    return mix_gapless(0.42, [
        (0.002, a, 2.0),
        (0.002 + v.u(0.0, 0.003), sole_contact(v, tau=v.u(0.016, 0.022)), 3.0),
        (0.002 + gap + v.u(0.0, 0.003), sole_contact(v), 0.0),
        (0.008, spray, 0.0),
        (0.02, knee, -8.0),
        (0.13, tail, -14.0),
    ])


def land_grass(v: Variant) -> np.ndarray:
    a, gap = _land_thuds(v, 300.0)
    crush = crackle(v, 0.180, 1200.0, 8000.0, rate=v.strat("stems", 650.0, 900.0),
                    pts=[(0.0, 0.0), (0.012, 1.0), (0.07, 0.7), (0.18, 0.0)],
                    snaps=v.strat_int("snaps", 3, 6), bed_db=-3.0)
    sw = swish(v, 0.180, v.u(3000, 4000), peak_frac=0.3)
    knee = cloth(v, 0.24, attack=0.05)
    return mix_gapless(0.42, [
        (0.002, a, 0.0),
        (0.002 + v.u(0.0, 0.003), sole_contact(v, tau=v.u(0.016, 0.022)), -1.0),
        (0.002 + gap + v.u(0.0, 0.003), sole_contact(v), -4.0),
        (0.006, crush, 0.0),
        (0.010, sw, -4.0),
        (0.02, knee, -10.0),
    ])


def land_wood(v: Variant) -> np.ndarray:
    modes = (90.0, 230.0, 520.0, v.u(950, 1100))
    amps = [1.0, 1.0, 1.0, 1.0]
    taus = [0.030, 0.020, 0.014, 0.007]
    a = knock(v, modes, amps, taus, soft=v.u(0.003, 0.0038), dur=0.35, balance=WOOD_BALANCE)
    mb = [f * v.u(1.08, 1.2) for f in modes]
    b = knock(v, mb, amps, [t * 0.9 for t in taus], soft=v.u(0.0022, 0.003),
              hard=v.u(0.0006, 0.0012), dur=0.35, balance=WOOD_BALANCE) * v.sign()
    boom = thud(v, v.u(80.0, 95.0), tau=0.025, dur=0.2, noise_lp=300.0, noise_db=0.0, glide=1.2,
                attack=0.002, lp=300.0, flat=True, second=False)
    gap = v.strat("gap", 0.015, 0.020)
    rt = rattle(v, int(v.r.integers(3, 6)), 0.026, ratio=0.72, f_lo=600.0, f_hi=1600.0)
    ck = creak(v, v.u(0.14, 0.18), 180.0, 330.0, attack=0.02, release=0.05)
    tail = settle(v, v.u(0.22, 0.26), 1500.0, 6000.0, n_clicks=(3, 6))
    return mix_gapless(0.44, [
        (0.002, a, 9.0),
        (0.002 + gap, b, 7.0),
        (0.002 + v.u(0.0, 0.002), plank_sole(v), -6.0),
        (0.002 + gap + v.u(0.0, 0.002), plank_sole(v), -8.0),
        (0.002, boom, -8.0),
        (0.002 + v.u(0.035, 0.05), rt, -6.0),
        (v.strat("creak", 0.06, 0.12), ck, -8.0),
        (0.05, tail, -16.0),
    ])


def jump_takeoff(v: Variant) -> np.ndarray:
    sc = scuff(v, 0.060, 700.0, 5000.0, attack=0.006, grit=v.strat_int("grit", 3, 6), order=2,
               click_band=(1500.0, 5500.0), click_db=-3.0)
    push = thud(v, 130.0 * v.u(0.9, 1.1), tau=0.006, dur=0.04)
    lift = cloth(v, 0.15, attack=v.u(0.04, 0.06))
    return mix_gapless(0.27, [
        (0.002, sc, 0.0),
        (0.002, push, -12.0),
        (0.002 + v.u(0.0, 0.003), sole_contact(v, 250.0, 2500.0), -6.0),
        (0.012, lift, -12.0),
        (0.012, leather_thump(v), -16.0),
        (v.strat("horn", 0.06, 0.10), horn_knock(v), -12.0),
    ])


def gear_jostle(v: Variant) -> np.ndarray:
    t = {k: v.u(0.0, 0.08) for k in ("horn", "leather", "metal")}
    lead = min(t.values())
    t = {k: tt - lead for k, tt in t.items()}  # the earliest element starts the file
    t["cloth"] = 0.0  # the coat moves through the whole jostle: a continuous bed
    return mix_gapless(0.27, [
        (t["horn"], horn_knock(v), -2.0),
        (t["leather"], leather_thump(v), 0.0),
        (t["metal"], metal_ticks(v, v.strat_int("ticks", 2, 4)), -8.0),
        (t["cloth"], cloth(v, 0.18, attack=0.02), -9.0),
    ])


def cloth_move(v: Variant) -> np.ndarray:
    """One arm/body movement of coat and shirt. The gesture shape differs
    per variant: a single swell (peak at 0.12-0.19 s), a front-loaded tug,
    a double movement with a second swell, or a long even drag; so does the
    garment, from a heavy wool coat to a linen sleeve (wool band x0.72-1.25,
    wool/linen balance -12..-2 dB and spectral tilt -3..+1 dB/oct move
    together)."""
    dur = 0.35
    n = nsamp(dur)
    kind = v.i % 4 if v.count >= 4 else int(v.r.integers(0, 4))
    pk = v.strat("swell", 0.12, 0.19)
    if kind == 3:
        a = v.u(0.03, 0.05)
        pts = [(0.0, 0.0), (a, v.u(0.7, 0.85)), (0.15, v.u(0.85, 1.0)), (0.26, v.u(0.7, 0.9)), (dur, 0.0)]
    elif kind == 0:
        pts = [(0.0, 0.0), (pk, 1.0), (pk + (dur - pk) * v.u(0.3, 0.5), v.u(0.6, 0.8)), (dur, 0.0)]
    elif kind == 1:
        a = v.u(0.04, 0.07)
        pts = [(0.0, 0.0), (a, 1.0), (a + v.u(0.05, 0.08), v.u(0.4, 0.55)), (dur, 0.0)]
    else:
        a = v.u(0.04, 0.06)
        b = v.u(0.21, 0.25)
        pts = [(0.0, 0.0), (a, v.u(0.75, 1.0)), (a + 0.06, v.u(0.25, 0.35)),
               (b, v.u(0.8, 1.0)), (dur, 0.0)]
    env = env_pts(n, pts)
    # garment, stratified: 0 = heavy wool coat (low wool band, little linen,
    # dark tilt) .. 1 = linen shirt sleeve (higher band, linen-led, crisp)
    g = v.strat("garment", 0.0, 1.0)
    ws = 0.72 + 0.53 * g
    y = cloth(v, dur, env=env, wool=(350.0 * ws, 2500.0 * ws), linen_db=-12.0 + 10.0 * g,
              bed_db=v.u(-12.0, -8.0))
    return unit(tilt(y, -3.0 + 4.0 * g))


# =============================================================================
# registry, levels and driver
# =============================================================================

# id: (variants, recipe, target duration s)
SOUNDS = {
    "step_dirt_walk": (4, step_dirt_walk, 0.22),
    "step_dirt_run": (4, step_dirt_run, 0.20),
    "step_dirt_sprint": (4, step_dirt_sprint, 0.25),
    "step_dirt_crouch": (4, step_dirt_crouch, 0.30),
    "step_grass_walk": (4, step_grass_walk, 0.30),
    "step_grass_run": (4, step_grass_run, 0.25),
    "step_grass_sprint": (4, step_grass_sprint, 0.30),
    "step_grass_crouch": (4, step_grass_crouch, 0.35),
    "step_wood_walk": (3, step_wood_walk, 0.30),
    "step_wood_run": (3, step_wood_run, 0.25),
    "step_wood_sprint": (3, step_wood_sprint, 0.30),
    "step_wood_crouch": (3, step_wood_crouch, 0.35),
    "land_dirt": (3, land_dirt, 0.35),
    "land_grass": (3, land_grass, 0.35),
    "land_wood": (2, land_wood, 0.40),
    "jump_takeoff": (3, jump_takeoff, 0.25),
    "gear_jostle": (4, gear_jostle, 0.25),
    "cloth_move": (4, cloth_move, 0.35),
}

HIGHPASS_HZ = 65.0  # 2nd order, on step_*, land_* and jump_* outputs

# Base volume_db from the playback spec (before trim_db). Landings add
# 8 * clamp(fall, 0, 1) on top of the base; gear_jostle is -18 with run
# steps and -15 with sprint steps.
BASE_VOLUME_DB = {
    "walk": -16.0, "run": -11.0, "sprint": -8.0, "crouch": -22.0, "wood": 1.0,
    "land": -12.0, "jump_takeoff": -14.0, "gear_jostle": -18.0, "cloth_move": -18.0,
}
# Designed in-game loudness relative to step_dirt_walk (dB).
TARGET_REL_WALK_DB = {
    "walk": 0.0, "run": 5.0, "sprint": 8.0, "crouch": -6.0, "land": 5.0,
    "wood": 1.0, "grass": 0.0, "dirt": 0.0,
    "jump_takeoff": -1.0, "cloth_move": -2.0, "gear_jostle": -2.0,
}
REFERENCE_ID = "step_dirt_walk"


def base_volume_db(sid: str) -> float:
    if sid in BASE_VOLUME_DB:
        return BASE_VOLUME_DB[sid]
    parts = sid.split("_")
    wood = BASE_VOLUME_DB["wood"] if "wood" in parts else 0.0
    if parts[0] == "land":
        return BASE_VOLUME_DB["land"] + wood
    return BASE_VOLUME_DB[parts[-1]] + wood


def target_rel_walk_db(sid: str) -> float:
    if sid in TARGET_REL_WALK_DB:
        return TARGET_REL_WALK_DB[sid]
    parts = sid.split("_")
    surface = parts[1] if parts[0] == "land" else parts[1]
    gait = "land" if parts[0] == "land" else parts[-1]
    return TARGET_REL_WALK_DB[gait] + TARGET_REL_WALK_DB[surface]


def a_weight(f: np.ndarray) -> np.ndarray:
    """IEC 61672 A-weighting magnitude (0 dB at 1 kHz)."""
    f2 = np.maximum(f, 1e-3) ** 2
    ra = (12194.0 ** 2 * f2 ** 2) / ((f2 + 20.6 ** 2) * np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2))
                                     * (f2 + 12194.0 ** 2))
    return ra / 0.7943


def a_loud100_db(x: np.ndarray, win: float = 0.1) -> float:
    """A-weighted mean-square level (dB re full-scale square) of the loudest
    `win`-second window."""
    k = nsamp(win)
    nf = dsp._nfft(len(x) + k)
    y = np.fft.irfft(np.fft.rfft(x, nf) * a_weight(np.fft.rfftfreq(nf, 1.0 / SR)), nf)[:len(x) + k]
    e = np.convolve(y * y, np.ones(k) / k, mode="valid")
    return float(10.0 * np.log10(np.max(e) + 1e-20))


def write_levels(out_dir: str, seed: int) -> str:
    """Measure every <id>_<nn>.wav in out_dir and write levels.json."""
    per = {}
    for path in sorted(glob.glob(os.path.join(out_dir, "*.wav"))):
        sid = re.sub(r"_\d\d\.wav$", "", os.path.basename(path))
        if sid not in SOUNDS:
            continue
        x, _sr = dsp.read_wav(path)
        x = x if x.ndim == 1 else x.mean(axis=1)
        per.setdefault(sid, {})[os.path.basename(path)] = a_loud100_db(x)
    if REFERENCE_ID not in per:
        raise SystemExit(f"levels: {REFERENCE_ID} files missing in {out_dir}")
    ref = float(np.mean(list(per[REFERENCE_ID].values()))) + base_volume_db(REFERENCE_ID)
    sounds = {}
    for sid in SOUNDS:
        if sid not in per:
            continue
        lv = float(np.mean(list(per[sid].values())))
        base = base_volume_db(sid)
        target = ref + target_rel_walk_db(sid)
        trim = target - lv - base
        sounds[sid] = {
            "base_volume_db": round(base, 1),
            "target_rel_walk_db": round(target_rel_walk_db(sid), 1),
            "target_db": round(target, 2),
            "a_loud100_db": round(lv, 2),
            "trim_db": round(trim, 1),
            "files": {name: {"a_loud100_db": round(l, 2), "trim_db": round(target - l - base, 1)}
                      for name, l in per[sid].items()},
        }
    doc = {
        "family": FAMILY,
        "generator": "tools/sfx/footsteps.py",
        "seed": seed,
        "metric": "a_loud100_db: A-weighted mean-square level of the loudest 100 ms window, "
                  "dB re full-scale square (a full-scale 1 kHz sine reads -3.0)",
        "usage": "play at volume_db = base_volume_db + trim_db (per id), or + files[name].trim_db "
                 "to also even out the variants. Landings add 8 * clamp(fall, 0, 1) dB to the base; "
                 "gear_jostle base is -18 with run steps and -15 with sprint steps. If PlayerAudio uses "
                 "a different base, use trim = target_db - a_loud100_db - its base.",
        "reference": REFERENCE_ID,
        "design": "in-game level re step_dirt_walk: crouch -6, walk 0, run +5, sprint +8 dB; "
                  "wood +1, grass +0; landings +5 at base volume (+6 on wood); jump_takeoff -1; "
                  "cloth_move -2; gear_jostle -2 at its -18 base",
        "sounds": sounds,
    }
    path = os.path.join(out_dir, "levels.json")
    with open(path, "w") as fh:
        json.dump(doc, fh, indent=1)
        fh.write("\n")
    return path


def master(x: np.ndarray, target: float) -> np.ndarray:
    """dsp.finalize (20 Hz DC block, trim at -60 dB, 20 ms fade, -1 dBFS),
    then cap the length at 1.15 x target with a longer fade if a tail runs
    on. (render applies the 65 Hz highpass before this.)"""
    y = dsp.finalize(x, peak_db=-1.0, fade=0.02, thresh_db=-60.0)
    cap = nsamp(target * 1.15)
    if len(y) > cap:
        y = dsp.fade_out(y[:cap].copy(), 0.04)
        y = dsp.peak_norm(y, db2lin(-1.0))
    return y


# settle-tail texture band per surface (see with_tail)
TAIL_BANDS = {"dirt": (700.0, 6000.0), "grass": (1200.0, 8000.0), "wood": (500.0, 5000.0),
              "jump_takeoff": (600.0, 6000.0), "gear_jostle": (600.0, 6000.0),
              "cloth_move": (400.0, 5000.0)}


def tail_band(sid: str):
    if sid in TAIL_BANDS:
        return TAIL_BANDS[sid]
    for surface in ("dirt", "grass", "wood"):
        if surface in sid.split("_"):
            return TAIL_BANDS[surface]
    return None


def render(sid: str, index: int, seed: int = 0) -> np.ndarray:
    count, fn, target = SOUNDS[sid]
    v = Variant(sid, index, count, seed)
    y = fn(v)
    band = tail_band(sid)
    if band is not None and sid != "cloth_move":
        y = with_tail(v, y, target, *band)
    if sid.startswith(("step_", "land_", "jump_")):
        y = hp_causal(np.asarray(y, float), HIGHPASS_HZ, 2)
    if band is not None:
        y = bridge_gaps(v, y, *band)
    return master(y, target)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--seed", type=int, default=0, help="global seed (0 = shipped set)")
    ap.add_argument("--only", nargs="*", help="sound ids to render (default: all)")
    ap.add_argument("--out", default=OUT_DIR, help="output directory")
    ap.add_argument("--list", action="store_true", help="list sound ids and exit")
    ap.add_argument("--levels-only", action="store_true", help="only re-measure levels.json")
    args = ap.parse_args(argv)

    if args.list:
        for sid, (count, _fn, target) in SOUNDS.items():
            print(f"{sid:20s} {count} variants  ~{target:.2f} s")
        return 0
    ids = args.only or list(SOUNDS)
    unknown = [s for s in ids if s not in SOUNDS]
    if unknown:
        ap.error(f"unknown sound id(s): {', '.join(unknown)}")
    os.makedirs(args.out, exist_ok=True)
    if not args.levels_only:
        for sid in ids:
            count = SOUNDS[sid][0]
            for i in range(count):
                y = render(sid, i, args.seed)
                path = os.path.join(args.out, f"{sid}_{i + 1:02d}.wav")
                dsp.write_wav(path, y, seed=_crc(sid, i, args.seed, "dither"))
                print(f"{os.path.relpath(path, ROOT)}  {len(y) / SR:.3f} s  "
                      f"peak {dsp.lin2db(float(np.max(np.abs(y)))):.2f} dBFS")
    path = write_levels(args.out, args.seed)
    print(f"{os.path.relpath(path, ROOT)} written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
