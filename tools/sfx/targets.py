#!/usr/bin/env python3
"""'targets' family: straw practice dummy (scripts/world/target_dummy.gd).

Sounds (variants):
  dummy_hit (3)       body/coat hit, ~0.4 s. Layers over the projectile's straw impact.
                      Noise-led straw thump, heavy-wool coat flap, 1-4 crossbar chatters
                      at random pitches, a ticking post creak in ~70 % of variants.
  dummy_hit_head (3)  burlap-sack head hit, ~0.3 s. Led by a hollow burlap pop and a
                      cloth thwap (400-2500 Hz); straw crackle is secondary because the
                      projectile's straw impact already supplies the crunch. Pre-compressed
                      so it plays louder than a body hit at the same peak.
  dummy_topple (2)    ~1.2 s, baked to the 0.45 s TRANS_QUAD ease-in fall tween:
                      post groan + air rush 0-0.40 s (ducked into the hit), ground whump at
                      0.44 s with a 150-600 Hz "thwump" so it survives small speakers,
                      small bounce at 0.58 s, audible straw settling to ~1.2 s.
  dummy_reset (2)     ~0.8 s, baked to the 0.6 s TRANS_BACK (ease in-out) rise tween:
                      soft unstick at 0 s, second unstick at ~0.21 s where the back-ease dip
                      passes the lying angle, lift scrape/creak ticks up to the seat knock at
                      0.42 s, higher and shorter wobble knocks 0.5-0.7 s.

Timed sounds (topple, reset) are never lead-trimmed, so t=0 in the file is t=0 of
the tween. Keep engine random_pitch small for them (1.03) so the events stay in sync.

Levels: after rendering, the variants of each sound are level-matched on K-weighted
short-term loudness (max over 50 ms), then held under a -1 dBFS peak ceiling by a
look-ahead limiter. dummy_hit_head gets an absolute target (LOUDNESS below) that sits
above dummy_hit. Suggested hook volumes (target_dummy.gd, once an Sfx player exists):
  apply_hit: Sfx.play(&"dummy_hit_head" if part == "head" else &"dummy_hit", point,
             (-2.0 if part == "head" else -6.0) + linear_to_db(clamp(damage / 100.0, 0.4, 1.2)))
  _die start: dummy_topple at global_position + UP * 0.8, -3 dB, random_pitch 1.03
  after tween_interval(respawn_time): dummy_reset at global_position + UP, -8 dB
Loaders must match "<id>_\\d\\d.wav" exactly ("dummy_hit_*" would also catch the heads).

Regenerate:
  python3 tools/sfx/targets.py                  # default seed, all sounds
  python3 tools/sfx/targets.py --seed 7         # a different set of variations
  python3 tools/sfx/targets.py --only dummy_hit,dummy_reset --out /tmp/x
Output: audio/sfx/targets/<id>_<NN>.wav, 44.1 kHz 16-bit mono, peak <= -1 dBFS.
"""
from __future__ import annotations

import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dsp import (SR, _nfft, ar_env, bandpass, convolve_same, db2lin, exp_env, fade_in, fade_out,  # noqa: E402
                 fft_band, finalize, highpass, lowpass, mallet, modal_ir, nsamp, peak_norm, place,
                 resonator, rng, sine_sweep, smooth_noise, stick_slip_train, svf, taxis, white,
                 write_wav)

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_DIR = os.path.join(ROOT, "audio", "sfx", "targets")
NAME_FMT = "{id}_{n:02d}.wav"
CEILING_DB = -1.0


# =========================================================================== family DSP

def jit(r, v: float, rel: float) -> float:
    """v scaled by a random factor in [1-rel, 1+rel]."""
    return v * (1.0 + rel * r.uniform(-1.0, 1.0))


def gain_j(r, db: float, spread: float = 1.0) -> float:
    return db2lin(db + r.uniform(-spread, spread))


def rms_norm(x: np.ndarray, rms: float, t0: float = 0.0, t1: float | None = None) -> np.ndarray:
    """Scale x so its RMS over [t0, t1] is `rms` (level sparse textures by energy, not
    by their single loudest grain)."""
    s = x[nsamp(t0):(nsamp(t1) if t1 else len(x))]
    return x * (rms / (np.sqrt(np.mean(s * s)) + 1e-12))


def crest_db(x: np.ndarray, t1: float = 0.06) -> float:
    s = x[:nsamp(t1)]
    return 20.0 * np.log10(np.max(np.abs(s)) / (np.sqrt(np.mean(s * s)) + 1e-12))


def least_peaky(cands, t1: float = 0.06) -> np.ndarray:
    """Pick the candidate with the lowest crest factor over its first t1 seconds, so a
    random noise spike cannot set the peak (and with it the variant's loudness)."""
    return min(cands, key=lambda c: crest_db(c, t1))


def wander(r, dur: float, rate_hz: float = 4.0, depth: float = 0.15):
    """Callable t -> 1 + depth * slow random wander (for slip-rate drift)."""
    n = nsamp(dur) + 2
    sn = smooth_noise(n, rate_hz, r)
    sn /= max(np.max(np.abs(sn)), 1e-9)
    return lambda t: 1.0 + depth * sn[min(max(int(t * SR), 0), n - 1)]


def straw_body(r, dur: float, lo: float, hi: float, tau: float, attack: float = 0.003) -> np.ndarray:
    """Sack-of-straw thump: enveloped noise band-limited causally (keeps the onset clean)."""
    n = nsamp(dur)
    x = white(n, r) * ar_env(n, attack, tau)
    return fade_out(peak_norm(bandpass(x, lo, hi, order=4)), dur * 0.2)


def thud_sine(r, dur: float, f_start: float, f_end: float, glide: float, tau: float,
              attack: float = 0.002) -> np.ndarray:
    """Damped sine whose pitch drops from f_start to f_end (impact compression)."""
    n = nsamp(dur)
    t = taxis(n)
    f = f_end + (f_start - f_end) * np.exp(-t / glide)
    return fade_out(sine_sweep(n, f, phase=r.uniform(0.0, 0.3)) * ar_env(n, attack, tau), dur * 0.2)


KNOCK_EXTRA = (8.25, 12.0, 16.5)          # upper wood modes as multiples of the lowest
KNOCK_AMPS = (0.8, 1.0, 0.6, 0.35, 0.2, 0.12)


def contact_burst(r, gain: float = 1.0) -> np.ndarray:
    """6-10 ms noisy contact of wood on wood, 300-4000 Hz, tau 2 ms."""
    k = nsamp(r.uniform(0.006, 0.010))
    c = fft_band(white(k, r), 300.0, 4000.0, 2) * ar_env(k, 0.0002, 0.002)
    return gain * peak_norm(fade_out(c, 0.002))


def wood_knock(r, modes, decay: float, dur: float, contact: float = 0.0005,
               amps=KNOCK_AMPS, jitter: float = 0.08, click: float = 0.35) -> np.ndarray:
    """Six-mode wood knock. A 3-mode set gets three upper modes (x8.25, x12, x16.5 of
    the lowest). `decay` is the audible decay (~-35 dB) of the lowest mode; higher modes
    die faster. `click` is the level of a noisy 6-10 ms contact burst on the onset."""
    modes = list(modes)
    if len(modes) == 3:
        modes += [modes[0] * k for k in KNOCK_EXTRA]
    amps = list(amps) + list(KNOCK_AMPS[len(amps):len(modes)])
    freqs = [min(jit(r, f, jitter), 0.45 * SR) for f in modes]
    base_tau = decay / 4.0
    taus = [jit(r, base_tau * (modes[0] / f) ** 0.6, 0.15) for f in freqs]
    amps = [a * r.uniform(0.75, 1.25) for a in amps[:len(freqs)]]
    n = nsamp(dur)
    ex = mallet(contact)
    ex = np.concatenate([ex * (1.0 + 0.25 * r.standard_normal(len(ex))), np.zeros(n)])
    y = convolve_same(ex, modal_ir(freqs, taus, amps, dur, r))[:n]
    y = fade_out(peak_norm(y), min(0.03, dur * 0.25))
    if click > 0:
        c = contact_burst(r, click)
        y[:len(c)] += c[:n]
    return y


def rattle(r, modes, decay: float, dur: float, hits, contact: float = 0.0005,
           click: float = 0.3) -> np.ndarray:
    """A cluster of knocks: hits = [(time, gain, freq_scale), ...]."""
    y = np.zeros(nsamp(dur))
    for t0, g, fs in hits:
        k = wood_knock(r, [m * fs for m in modes], decay, max(dur - t0, 0.02), contact, click=click)
        place(y, k, t0, g)
    return y


def chatter_hits(r, count: int, t0: float, gaps=(0.030, 0.020, 0.013), drop=(-8.0, -4.0)):
    """Loose-joint chatter: `count` hits at shrinking intervals, falling level, each at
    its own contact pitch (freq_scale 0.85-1.25)."""
    hits, t, g = [], t0, 1.0
    for i in range(count):
        hits.append((t, g, r.uniform(0.85, 1.25)))
        t += jit(r, gaps[min(i, len(gaps) - 1)], 0.25)
        g *= db2lin(r.uniform(*drop))
    return hits


def creak(r, dur: float, rate, amp, res_freqs, res_taus, res_amps, jitter: float = 0.3,
          friction: float = 0.2, lo_cut: float = 90.0, hi_cut: float | None = None,
          wobble: float = 0.15) -> np.ndarray:
    """Stick-slip creak: jittered slip impulses, each a tiny noisy grain, through a
    short-lived wooden resonator bank (taus of a few ms, so every slip is a separate
    tick rather than a sustained hum), plus a little friction hiss that follows the
    slips. The slip rate drifts by +-`wobble` at ~4 Hz. The output is `dur` plus the
    resonator ring-out (no truncation click)."""
    tail = max(res_taus) * 5.0
    wf = wander(r, dur, 4.0, wobble)
    rf = rate if callable(rate) else (lambda _t: rate)
    train = stick_slip_train(dur, lambda t: rf(t) * wf(t), r, jitter=jitter, amp=amp, amp_jitter=0.4)
    train = np.concatenate([train, np.zeros(nsamp(tail))])
    g = nsamp(0.0012)
    grain = np.zeros(g)
    grain[0] = 1.0
    grain += 0.35 * white(g, r) * exp_env(g, 0.0003)
    ex = convolve_same(train, grain)
    ir = modal_ir([jit(r, f, 0.03) for f in res_freqs], res_taus, res_amps, tail * 1.2, r)
    y = peak_norm(convolve_same(ex, ir))
    if friction > 0:
        n = len(y)
        # slip-density envelope (smoothed |train|) drives band-limited hiss
        w = nsamp(0.008)
        dens = np.convolve(np.abs(train), np.ones(w) / w, mode="same")
        hiss = fft_band(white(n, r), 400.0, 2500.0, 4) * dens
        y += friction * peak_norm(hiss)
    y = highpass(y, lo_cut, 2)
    if hi_cut:
        y = lowpass(y, hi_cut, 2)
    return peak_norm(fade_out(y, tail * 0.6))


def crackle(r, dur: float, density, lo: float, hi: float, grain: float = 0.0004,
            shape: float = 2.5, amp=None) -> np.ndarray:
    """Straw crackle: Poisson clicks with density(t) per second and a skewed amplitude
    law (many tiny ticks, a few loud snaps), optionally scaled by amp(t), band-limited
    causally. Every grain gets its own noise kernel (a unit impulse plus a decaying
    noise tail), so the texture has no fixed comb colouring. Longer `grain` gives
    rustle rather than crackle."""
    n = nsamp(dur)
    t = taxis(n)
    d = np.asarray(density(t), dtype=float)
    idx = np.nonzero(r.random(n) < np.clip(d / SR, 0.0, 1.0))[0]
    k = len(idx)
    a = (r.random(k) ** shape) * r.choice([-1.0, 1.0], k)
    if amp is not None:
        a *= np.asarray(amp(t), dtype=float)[idx]
    gk = max(nsamp(grain), 2)
    kern = r.standard_normal((k, gk)) * np.exp(-np.arange(gk) / SR / (grain / 3.0))[None, :]
    kern[:, 0] += 1.0
    y = np.zeros(n + gk)
    np.add.at(y, (idx[:, None] + np.arange(gk)[None, :]).ravel(), (kern * a[:, None]).ravel())
    return peak_norm(fade_out(bandpass(y, lo, hi, order=4), gk / SR))


def cloth_flap(r, dur: float = 0.06, lo: float = 600.0, hi: float = 2600.0) -> np.ndarray:
    """Heavy wool coat flapping: 2-4 fabric snaps plus a short flutter swell, all inside
    `dur`. Kept below the 1-4 kHz cloth tear of the projectile's straw impact."""
    n = nsamp(dur + 0.03)
    t = taxis(n)
    env = np.zeros(n)
    times = [0.0] + sorted(r.uniform(0.010, dur - 0.015, int(r.integers(1, 4))).tolist())
    for i, t0 in enumerate(times):
        a = 1.0 if i == 0 else r.uniform(0.3, 0.7)
        seg = ar_env(n - nsamp(t0), 0.0012, r.uniform(0.006, 0.012)) * a
        env[nsamp(t0):] += seg
    swell = np.where(t < dur, np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2, 0.0)
    env += 0.25 * swell
    env *= np.clip((dur + 0.02 - t) / 0.02, 0.0, 1.0)  # gone by dur + 20 ms
    x = fft_band(white(n, r), lo, hi, order=3) * env
    return peak_norm(x)


def cloth_thwap(r, dur: float = 0.05) -> np.ndarray:
    """Burlap slapped by the shot: noise 400-2500 Hz, 0.5 ms attack, tau 8 ms."""
    n = nsamp(dur)
    x = fft_band(white(n, r), 400.0, 2500.0, 2) * ar_env(n, 0.0005, jit(r, 0.008, 0.15))
    return peak_norm(fade_out(x, 0.012))


def burlap_pop(r, dur: float = 0.03, lo: float = 600.0, hi: float = 1200.0) -> np.ndarray:
    """Hollow burlap pop: short noise burst band-passed 600-1200 Hz plus a cavity
    resonance (700-950 Hz, Q 4) that gives the 'hollow sack' character."""
    n = nsamp(dur + 0.025)
    t = taxis(n)
    ex = white(n, r) * ar_env(n, 0.0006, dur / 3.5) * (t < dur)
    band = bandpass(ex, lo, hi, order=4)
    cav = resonator(ex, r.uniform(700.0, 950.0), 4.0)
    return peak_norm(peak_norm(band) + 0.9 * peak_norm(cav))


def dirt_scuff(r, dur: float = 0.09) -> np.ndarray:
    """Body and coat scuffing dirt: gritty mid noise with a short slide tail."""
    n = nsamp(dur + 0.06)
    env = ar_env(n, 0.002, 0.025) + 0.35 * ar_env(n, 0.012, 0.05)
    env *= np.clip((dur + 0.05 - taxis(n)) / 0.05, 0.0, 1.0)
    base = fft_band(white(n, r), 350.0, 3500.0, 2)
    grit = crackle(r, dur + 0.06, lambda t: 2500.0 + 0 * t, 1500.0, 7000.0)[:n]
    return peak_norm(peak_norm(base) * env + 0.45 * grit * env)


def settle_rustle(r, dur: float, density0: float, tau_fast: float, tail_density: float,
                  tau_slow: float, bed: float = 0.35, shape: float = 1.6) -> np.ndarray:
    """Straw settling: decaying rustle grains (3 ms noise ticks, not clicks) with
    amplitudes that fade as the straw comes to rest, plus a soft rustle bed. A higher
    `shape` gives sparser, bigger ticks over fainter ones."""
    cr = crackle(r, dur, lambda t: density0 * np.exp(-t / tau_fast) + tail_density * np.exp(-t / tau_slow),
                 1200.0, 7000.0, grain=0.003, shape=shape,
                 amp=lambda t: 0.35 + 0.65 * np.exp(-t / (2.0 * tau_fast)))
    n = len(cr)
    am = 0.55 + 0.45 * np.abs(smooth_noise(n, 22.0, r))
    b = fft_band(white(n, r), 1500.0, 6000.0, 3) * exp_env(n, tau_slow * 0.8) * am
    y = peak_norm(cr + bed * peak_norm(b))
    return fade_in(fade_out(y, min(0.05, dur * 0.3)), 0.015)


def straw_thump(r, dur: float, fc_start: float, fc_end: float, tau: float,
                attack: float = 0.002, hp: float = 40.0) -> np.ndarray:
    """Sack-of-straw thump: enveloped noise through a lowpass whose cutoff falls from
    fc_start to fc_end as the hit decays (a soft body darkening), rumble trimmed."""
    n = nsamp(dur)
    t = taxis(n)
    fc = fc_end + (fc_start - fc_end) * np.exp(-t / tau)
    x = white(n, r) * ar_env(n, attack, tau)
    y = highpass(svf(x, fc, 0.8, "lp"), hp, 2)
    return fade_out(peak_norm(y), dur * 0.2)


def unstick(r, dur: float, attack: float, tau: float, grit_density: float = 1800.0) -> np.ndarray:
    """Post pulling free of the dirt: gritty 300-2200 Hz burst plus crackle."""
    m = nsamp(dur)
    benv = ar_env(m, attack, tau)
    burst = fft_band(white(m, r), 300.0, 2200.0, 4) * benv
    grit = crackle(r, dur, lambda tt: grit_density * np.exp(-tt / max(0.035, attack + 0.015)),
                   1200.0, 6000.0, 0.001)[:m]
    return fade_out(peak_norm(burst) + 0.35 * grit * benv, min(0.03, dur * 0.3))


# --------------------------------------------------------------------------- level tools

def k_weight(x: np.ndarray) -> np.ndarray:
    """Approximate BS.1770 K-weighting (+4 dB shelf above ~1.7 kHz, 38 Hz highpass), by FFT."""
    nf = _nfft(2 * len(x))
    f = np.fft.rfftfreq(nf, 1.0 / SR)
    h = 1.0 + (db2lin(4.0) - 1.0) / (1.0 + (1681.0 / np.maximum(f, 1.0)) ** 2)
    h /= np.sqrt(1.0 + (38.0 / np.maximum(f, 1e-3)) ** 4)
    return np.fft.irfft(np.fft.rfft(x, nf) * h, nf)[:len(x)]


def k_loudness(x: np.ndarray, win: float = 0.05) -> float:
    """K-weighted short-term loudness: max mean square over a `win` window, in dB."""
    y = k_weight(x)
    w = nsamp(win)
    e = np.convolve(y * y, np.ones(w) / w, mode="same")
    return 10.0 * np.log10(max(float(e.max()), 1e-20))


def peak_limit(x: np.ndarray, ceiling: float, look: float = 0.002) -> np.ndarray:
    """Look-ahead peak limiter: the gain needed at each sample is spread by a min filter
    of +-`look` and a Hann-weighted average of the same width, so the gain dips smoothly
    (about 2 * look on each side) and every sample ends up <= ceiling."""
    g = np.minimum(1.0, ceiling / np.maximum(np.abs(x), 1e-12))
    if g.min() >= 1.0:
        return x
    k = max(nsamp(look), 1)
    gp = np.pad(g, (k, k), constant_values=1.0)
    gmin = np.lib.stride_tricks.sliding_window_view(gp, 2 * k + 1).min(axis=1)
    w = np.hanning(2 * k + 3)[1:-1]
    gs = np.convolve(np.pad(gmin, (k, k), constant_values=1.0), w / w.sum(), mode="valid")
    y = x * gs
    return y * min(1.0, ceiling / max(np.max(np.abs(y)), 1e-12))


def level_match(xs, target: float | None = None, max_boost: float = 2.0,
                ceiling_db: float = CEILING_DB):
    """Match the variants' K-weighted short-term loudness, then hold the peak ceiling.

    target None: the loudest variant's loudness, but at most `max_boost` dB above the
    quietest (so no variant needs more than that much limiting)."""
    ceil = db2lin(ceiling_db)
    ls = [k_loudness(x) for x in xs]
    tgt = target if target is not None else min(max(ls), min(ls) + max_boost)
    out = []
    for x in xs:
        y = np.array(x, dtype=float)
        for _ in range(6):
            d = tgt - k_loudness(y)
            if abs(d) < 0.03:
                break
            y = peak_limit(y * db2lin(d), ceil)
        out.append(y)
    return out, tgt


# =========================================================================== sounds

def dummy_hit(r) -> np.ndarray:
    dur = r.uniform(0.38, 0.46)
    y = np.zeros(nsamp(dur))
    # Sack-of-straw body thump: noise lowpassed ~250 -> 80 Hz, tau 50 ms +-20 %, levelled
    # by its RMS over the first 60 ms (the least peaky of four draws, so a random noise
    # spike cannot set the variant's level). A quiet, roughened ~110 Hz damped sine adds
    # weight; it always dies faster than the noise so the tail of the thump is unpitched.
    tau_b = jit(r, 0.050, 0.2)
    fc0, fc1 = jit(r, 250.0, 0.06), jit(r, 80.0, 0.06)
    body = least_peaky([straw_thump(r, 0.40, fc0, fc1, tau_b, attack=0.002) for _ in range(4)])
    place(y, rms_norm(body, 0.28, 0.0, 0.06), 0.0, 1.0)
    # straw shifting inside the sack: a broad 150-600 Hz noise body under the thump
    mid = straw_body(r, 0.30, 150.0, 600.0, jit(r, 0.035, 0.2), attack=0.003)
    place(y, rms_norm(mid, 0.28, 0.0, 0.06), 0.0, gain_j(r, -9.0))
    n = nsamp(0.40)
    sine = thud_sine(r, 0.40, jit(r, 128.0, 0.05), jit(r, 110.0, 0.08), jit(r, 0.02, 0.3),
                     min(jit(r, 0.035, 0.25), 0.7 * tau_b), attack=0.0015)
    sine *= 1.0 + 0.3 * smooth_noise(n, 60.0, r)
    place(y, sine, 0.0, gain_j(r, -9.0, 1.5))
    thump_pk = 1.0
    # Coat cloth flap (heavy wool, 600-2600 Hz), reacting 2-20 ms after the impact.
    place(y, cloth_flap(r, r.uniform(0.05, 0.075)), r.uniform(0.002, 0.02),
          thump_pk * db2lin(r.uniform(-12.0, -6.0)))
    # Crossbar/post chatter: 1-4 hits at shrinking intervals, each at its own pitch.
    hits = chatter_hits(r, int(r.integers(1, 5)), r.uniform(0.008, 0.016))
    place(y, rattle(r, (200.0, 520.0, 1100.0), jit(r, 0.110, 0.2), 0.28, hits), 0.0,
          thump_pk * gain_j(r, -8.0))
    # Post rocking creak (70 % of hits): a handful of separate stick-slip ticks.
    if r.random() < 0.7:
        cdur = r.uniform(0.14, 0.20)
        c = creak(r, cdur,
                  rate=lambda t: 30.0 + 25.0 * np.sin(np.pi * min(t / cdur, 1.0)),
                  amp=lambda t: 0.3 + 0.7 * np.sin(np.pi * min(t / cdur, 1.0)) ** 1.5,
                  res_freqs=[jit(r, f, 0.08) for f in (260.0, 430.0, 720.0, 1150.0)],
                  res_taus=[0.007, 0.005, 0.004, 0.003], res_amps=[1.0, 0.9, 0.6, 0.35],
                  jitter=0.3, friction=0.2, lo_cut=110.0, hi_cut=3500.0)
        place(y, c, r.uniform(0.05, 0.14), thump_pk * gain_j(r, -13.0, 1.5))
    # Coat and straw settling as the dummy stops swinging.
    sd = r.uniform(0.22, 0.34)
    place(y, rms_norm(settle_rustle(r, sd, r.uniform(160.0, 280.0), 0.05, 50.0, 0.12, bed=0.5), 0.2),
          r.uniform(0.05, 0.10), gain_j(r, -24.0, 2.0))
    # Soft saturation (only the loud first ~50 ms reaches it) keeps the loudness steady
    # between variants and adds a little upper-harmonic weight for small speakers.
    y = 1.5 * np.tanh(y / 1.5)
    return finalize(fade_out(y, 0.05), thresh_db=-60.0)


HEAD_RMS = 0.33


def dummy_hit_head(r) -> np.ndarray:
    dur = r.uniform(0.28, 0.34)
    y = np.zeros(nsamp(dur))
    t_pop = r.uniform(0.0, 0.006)
    # Main element: hollow burlap pop, 30 ms, cavity 700-950 Hz, plus the cloth thwap.
    place(y, burlap_pop(r, 0.030), t_pop, gain_j(r, 2.0))
    place(y, cloth_thwap(r), r.uniform(0.0, 0.003), gain_j(r, 0.0))
    # Straw crackle (secondary): dense burst, then a few fading snaps. Levelled by the
    # burst's RMS, then capped so single snaps cannot set the peak.
    d0 = r.uniform(3000.0, 7000.0)
    cr = crackle(r, dur, lambda t: d0 * np.exp(-t / 0.018) + 400.0 * np.exp(-t / 0.06),
                 1800.0, 9000.0, grain=0.0005, shape=2.2,
                 amp=lambda t: 0.1 + 0.9 * np.exp(-t / 0.03))
    cr *= 0.28 / (np.sqrt(np.mean(cr[:nsamp(0.05)] ** 2)) + 1e-9)
    cr /= max(1.0, np.max(np.abs(cr)) / 0.5)
    place(y, cr, 0.0005, gain_j(r, -4.0))
    # Small straw thump, noise-led (the damped sine is short and only adds a little body).
    f_end = jit(r, 200.0, 0.10)
    th = 0.4 * thud_sine(r, 0.2, f_end * jit(r, 1.17, 0.10), f_end, 0.012, 0.012, attack=0.0015)
    th += straw_body(r, 0.2, 120.0, 550.0, jit(r, 0.022, 0.25), attack=0.002)
    place(y, peak_norm(th), 0.0, gain_j(r, -8.0))
    # Burlap/straw texture right after the pop (crunch body, 2-6 kHz).
    n = nsamp(0.09)
    tex = fade_out(fft_band(white(n, r), 2000.0, 6000.0, 2) * ar_env(n, 0.003, jit(r, 0.02, 0.2)), 0.02)
    place(y, peak_norm(tex), 0.002, gain_j(r, -10.0))
    # Much less post chatter than a body hit.
    hits = chatter_hits(r, int(r.integers(1, 3)), 0.0, drop=(-10.0, -7.0))
    place(y, rattle(r, (200.0, 520.0, 1100.0), 0.07, 0.2, hits), r.uniform(0.02, 0.04), gain_j(r, -26.0))
    # Loose straw trickling out of the sack (levelled by RMS so the tails match).
    place(y, rms_norm(settle_rustle(r, r.uniform(0.2, 0.27), r.uniform(200.0, 320.0), 0.05, 50.0, 0.11,
                                    bed=0.45), 0.2, 0.0, 0.1),
          r.uniform(0.04, 0.07), gain_j(r, -20.0, 1.5))
    # Pre-compress the first 15 ms (soft clip, blended out by 22 ms) so the head hit
    # carries its level in the body of the pop rather than in one crackle spike. The mix
    # is levelled by its RMS over the first 30 ms (not its random peak) before the clip.
    y = rms_norm(y, HEAD_RMS, 0.0, 0.03)
    sc = 0.6 * np.tanh(y / 0.6)
    w = np.clip((0.022 - taxis(len(y))) / 0.007, 0.0, 1.0)
    y = w * sc + (1.0 - w) * y
    return finalize(fade_out(y, 0.04), thresh_db=-60.0)


def dummy_topple(r) -> np.ndarray:
    dur = 1.30
    T_IMPACT, T_BOUNCE = 0.44, 0.58
    n = nsamp(dur)
    y = np.zeros(n)

    # --- 0 to 0.40 s: base groan (slowing stick-slip ticks, resonators 150-400 Hz).
    r0, r1 = jit(r, 115.0, 0.08), jit(r, 38.0, 0.1)
    groan = creak(r, 0.42,
                  rate=lambda t: r0 * (r1 / r0) ** min(t / 0.40, 1.0),
                  amp=lambda t: (0.12 + min(t / 0.40, 1.0)) ** 1.6 * min(max((0.425 - t) / 0.025, 0.0), 1.0),
                  res_freqs=[jit(r, f, 0.05) for f in (155.0, 215.0, 290.0, 395.0)],
                  res_taus=[0.012, 0.010, 0.008, 0.006], res_amps=[0.75, 0.9, 0.75, 0.55],
                  jitter=0.3, friction=0.2, lo_cut=70.0, hi_cut=2500.0)
    # duck into the hit: a 40 ms ramp down to -10 dB ending at the impact
    tg = taxis(len(groan))
    duck = db2lin(-10.0) ** np.clip((tg - (T_IMPACT - 0.04)) / 0.04, 0.0, 1.0)
    place(y, groan * duck, 0.0, gain_j(r, -12.0))

    # --- cloth and air rush: noise lowpassed rising toward 1 kHz, louder with fall speed.
    m = nsamp(T_IMPACT + 0.01)
    t = taxis(m)
    prog = np.clip(t / 0.45, 0.0, 1.0)            # TRANS_QUAD ease-in: speed ~ t
    fc = 300.0 + 700.0 * prog ** 1.3
    rush = svf(white(m, r), fc, 0.65, "lp")
    flutter = 1.0 + 0.35 * smooth_noise(m, 14.0, r)
    rush = peak_norm(rush * prog ** 2.2 * flutter)
    rush *= np.clip((T_IMPACT + 0.008 - t) / 0.012, 0.0, 1.0)
    place(y, rush, 0.0, gain_j(r, -15.0))

    # --- 0.44 s: heavy straw-and-wood whump. The noise thump carries the 90 ms decay;
    # the sine is short and low; a 150-600 Hz "thwump" keeps it on small speakers.
    whump = straw_thump(r, 0.6, 220.0, 70.0, 0.09, attack=0.004, hp=45.0)
    whump += db2lin(-8.0) * thud_sine(r, 0.6, jit(r, 120.0, 0.05), jit(r, 70.0, 0.06), 0.035, 0.045, attack=0.004)
    place(y, peak_norm(whump), T_IMPACT, 1.0)
    k = nsamp(0.25)
    mid = fade_out(fft_band(white(k, r), 150.0, 600.0, 2) * ar_env(k, 0.003, 0.030), 0.05)
    place(y, peak_norm(mid), T_IMPACT, gain_j(r, -3.0))
    place(y, dirt_scuff(r, 0.09), T_IMPACT + r.uniform(0.002, 0.006), gain_j(r, -5.0))
    post = wood_knock(r, (160.0, 380.0, 850.0), 0.18, 0.4, contact=0.0006, click=0.35)
    place(y, post, T_IMPACT + r.uniform(0.001, 0.005), gain_j(r, -1.0))
    # straw body crunching on landing
    place(y, crackle(r, 0.15, lambda tt: 3000.0 * np.exp(-tt / 0.03), 1200.0, 7000.0, 0.0008,
                     amp=lambda tt: np.exp(-tt / 0.05)),
          T_IMPACT + 0.002, gain_j(r, -13.0))

    # --- ~0.58 s: small second bounce, -10 dB.
    b = thud_sine(r, 0.35, jit(r, 115.0, 0.06), jit(r, 88.0, 0.06), 0.02, 0.03, attack=0.003)
    b += 0.7 * straw_thump(r, 0.35, 190.0, 80.0, 0.045, attack=0.003, hp=50.0)
    b = peak_norm(b)
    place(b, wood_knock(r, (160.0, 380.0, 850.0), 0.12, 0.35, contact=0.0006, click=0.3), 0.001, 0.6)
    place(b, dirt_scuff(r, 0.05), 0.002, 0.3)
    place(y, peak_norm(b), T_BOUNCE + r.uniform(-0.006, 0.006), db2lin(-10.0))

    # --- straw rustles settling until ~1.2 s: sparser, bigger ticks that survive distance.
    sd = 1.2 - 0.46
    st = rms_norm(settle_rustle(r, sd, 250.0, 0.12, 110.0, 0.5, bed=0.45, shape=2.2), 0.2, 0.0, 0.3)
    st *= np.clip((sd - taxis(len(st))) / 0.15, 0.0, 1.0)
    place(y, st, 0.46, gain_j(r, -11.0))

    # never lead-trim: t=0 is the start of the fall tween
    return fade_in(finalize(fade_out(y, 0.08), lead_trim=False, thresh_db=-72.0), 0.001)


def back_in_out(u: np.ndarray, s: float = 1.70158) -> np.ndarray:
    """Godot/Penner TRANS_BACK + EASE_IN_OUT progress (0..1 with ~10 % overshoot).
    Lowest dip at u=0.24 (0.144 s of 0.6), back through 0 at u=0.36 (0.217 s),
    upright first reached at u=0.639 (0.383 s), max overshoot at u=0.759 (0.456 s)."""
    s2 = s * 1.525
    u2 = u * 2.0
    a = 0.5 * (u2 ** 2 * ((s2 + 1) * u2 - s2))
    v = u2 - 2.0
    b = 0.5 * (v ** 2 * ((s2 + 1) * v + s2) + 2.0)
    return np.where(u2 < 1.0, a, b)


def dummy_reset(r) -> np.ndarray:
    dur = 0.80
    TWEEN = 0.60
    T_SEAT = 0.42
    n = nsamp(dur)
    y = np.zeros(n)
    t = taxis(n)
    p = back_in_out(np.clip(t / TWEEN, 0.0, 1.0))
    speed = np.abs(np.gradient(p, 1.0 / SR))
    speed /= speed.max()

    # --- t=0: the post presses further into the dirt (the back-ease dip): a soft grit.
    place(y, unstick(r, 0.16, 0.025, 0.045), 0.0, gain_j(r, -14.0))
    # --- ~0.21 s: the dip passes back through the lying angle and the post pulls free.
    place(y, unstick(r, 0.14, 0.004, 0.03, 2200.0), r.uniform(0.20, 0.23), gain_j(r, -9.0))

    # --- lift: friction scrape and creak ticks (resonators 200-500 Hz) following the
    # rise speed, running right up to the seat knock.
    lift_end = T_SEAT + 0.005
    m = nsamp(lift_end)
    tl = t[:m]
    sp = speed[:m]
    gate = np.clip((lift_end - tl) / 0.006, 0.0, 1.0)
    rough = 0.55 + 0.45 * np.abs(smooth_noise(m, 45.0, r))
    scrape = fft_band(white(m, r), 300.0, 1800.0, 4) * (0.3 + 0.7 * sp) * gate * rough
    place(y, peak_norm(scrape), 0.0, gain_j(r, -21.0))
    sp_f = lambda tt: float(np.interp(tt, tl, sp))  # noqa: E731
    cr = creak(r, lift_end,
               rate=lambda tt: 25.0 + 45.0 * sp_f(tt),
               amp=lambda tt: (0.3 + 0.7 * sp_f(tt)) * min(max((lift_end - tt) / 0.006, 0.0), 1.0),
               res_freqs=[jit(r, f, 0.05) for f in (205.0, 300.0, 390.0, 495.0)],
               res_taus=[0.010, 0.008, 0.006, 0.005], res_amps=[0.6, 0.9, 0.8, 0.65],
               jitter=0.3, friction=0.2, lo_cut=120.0, hi_cut=2500.0)
    place(y, cr, 0.0, gain_j(r, -12.0))

    # --- 0.42 s: post seats upright, 6-mode knock on 200/480/1000 Hz, 80 ms decay,
    # plus a short base thud.
    seat = wood_knock(r, (200.0, 480.0, 1000.0), 0.080, 0.35, contact=0.0005, click=0.35)
    base = thud_sine(r, 0.35, jit(r, 150.0, 0.06), jit(r, 110.0, 0.06), 0.01, 0.018, attack=0.0015)
    place(y, peak_norm(seat + 0.25 * base), T_SEAT, 1.0)
    # crossbar chatter right after the seat
    place(y, wood_knock(r, [f * r.uniform(1.05, 1.2) for f in (215.0, 530.0, 1120.0)], 0.06, 0.2,
                        contact=0.0004, click=0.3),
          T_SEAT + r.uniform(0.014, 0.022), gain_j(r, -14.0))
    # straw arms shaking on the overshoot
    place(y, settle_rustle(r, 0.25, 260.0, 0.05, 40.0, 0.1, bed=0.4), T_SEAT + 0.01, gain_j(r, -21.0))

    # --- 0.5-0.7 s: wobble settle, two softer, higher, shorter knocks and a small creak.
    k1 = r.uniform(0.515, 0.540)
    k2 = r.uniform(0.625, 0.655)
    for tk, g, dec in ((k1, gain_j(r, -8.0), 0.045), (k2, gain_j(r, -14.0), 0.035)):
        sc = r.uniform(1.08, 1.2)
        kn = wood_knock(r, [f * sc for f in (200.0, 480.0, 1000.0)], dec, 0.2, contact=0.0006, click=0.3)
        place(y, kn, tk, g)
    cd = r.uniform(0.10, 0.14)
    wc = creak(r, cd,
               rate=lambda tt: 40.0 - 15.0 * tt / cd,
               amp=lambda tt: 0.3 + 0.7 * np.sin(np.pi * min(tt / cd, 1.0)),
               res_freqs=[jit(r, f, 0.05) for f in (230.0, 350.0, 480.0)],
               res_taus=[0.007, 0.005, 0.004], res_amps=[0.7, 0.9, 0.65], jitter=0.3,
               friction=0.2, lo_cut=120.0, hi_cut=2500.0)
    place(y, wc, r.uniform(0.555, 0.585), gain_j(r, -17.0))

    return fade_in(finalize(fade_out(y, 0.06), lead_trim=False, thresh_db=-72.0), 0.001)


SOUNDS = {
    # id: (generator, variants)
    "dummy_hit": (dummy_hit, 3),
    "dummy_hit_head": (dummy_hit_head, 3),
    "dummy_topple": (dummy_topple, 2),
    "dummy_reset": (dummy_reset, 2),
}

# K-weighted short-term (50 ms) loudness targets in dB at the -1 dBFS ceiling.
# None = match the variants among themselves (see level_match).
LOUDNESS = {
    "dummy_hit": -9.25,
    "dummy_hit_head": -9.0,      # level with / slightly above dummy_hit (plus the +4 dB hook)
}


def main(argv=None) -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, default=1771, help="base seed; change for new variations")
    ap.add_argument("--out", default=OUT_DIR, help="output directory")
    ap.add_argument("--only", default="", help="comma-separated sound ids")
    ap.add_argument("--variants", type=int, default=0, help="override variant count")
    a = ap.parse_args(argv)
    only = {s.strip() for s in a.only.split(",") if s.strip()}
    for si, (sid, (gen, count)) in enumerate(SOUNDS.items()):
        if only and sid not in only:
            continue
        seeds = [a.seed * 1000 + si * 50 + v for v in range(a.variants or count)]
        raw = [gen(rng(s)) for s in seeds]
        xs, tgt = level_match(raw, LOUDNESS.get(sid))
        for v, (seed, x0, x) in enumerate(zip(seeds, raw, xs)):
            path = write_wav(os.path.join(a.out, NAME_FMT.format(id=sid, n=v + 1)), x, seed=seed)
            print(f"{path}  {len(x) / SR:.3f}s  K50 {k_loudness(x0):6.1f} -> {k_loudness(x):6.1f} dB"
                  f"  peak {20 * np.log10(np.max(np.abs(x))):6.2f} dBFS")


if __name__ == "__main__":
    main()
