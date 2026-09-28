#!/usr/bin/env python3
"""'bow' family: hunting longbow foley (scripts/weapons/bow.gd).

Sounds (variants), all mono, bus Foley in game:
  bow_equip (2)       ~0.43 s  cloth drag off the shoulder (carries the length), a dry limb
                               knock on the hand (250/600/900/1300/2100 Hz, tau 12-2.5 ms, ~35 %
                               of the energy), string brush buzz (KS 110 Hz, -15 dB), 3-5 arrow
                               clicks.
  bow_holster (2)     ~0.36 s  cloth rustle, dull wooden tap (220/520/1150/2000 Hz, tau
                               10-2.5 ms, ~40 % of the energy), string brush (-18 dB), rattle.
  quiver_draw (3)     ~0.31 s  4-8 shaft clicks (one mode set per variant: a 500-800 Hz body
                               mode + 3 modes in 1.2-3.5 kHz, jittered +-5 % per click, tau
                               2.5-3.5 ms), continuous shaft-on-leather slide 0.02-0.22 s (-6 dB),
                               fletching swish on leather (2-8 kHz, 150 ms). Nock timeline t=0.02.
  arrow_rest (2)      ~0.13 s  leather/skin brush (2-6 kHz, 60 ms, ~25 % of the energy), fleshy
                               wood tap (350-450 / 900 / 2100 Hz + 2 small modes), a settle tick
                               on its own modes (1.1-1.3 / 1.8-2.2 / 2.6-3.0 / 3.8-4.6 kHz) after
                               a short slide. Nock timeline t=0.35.
  nock_click (3)      ~0.08 s  3-10 ms nock-pressing micro-scrape (2-8 kHz, -14 dB), horn nock
                               click (3.5/6.2 kHz + two 8-11 kHz modes, tau 1.8-0.6 ms), on some
                               variants a second micro-click 2-5 ms later, a faint string touch
                               (~180 Hz, 45 ms, 12 dB below the click by energy), fingers closing
                               on the string. The click lands 6-11 ms into the file. Timeline 0.55.
  bow_draw (3)        0.6 s    grip 'tk', shaft friction scrape following draw speed (main
                               layer), limb creak sparse -> dense (4-5 dB below the scrape by
                               energy, ~-6 dB of the file), fletching whisper at the end.
                               Not lead-trimmed: t=0 is the start of the draw.
  bow_creak_loop (2)  2.0 s    seamless loop (smpl chunk, forward) of stick-slip creak (~60
                               slips/s, 3 % chance per slip of a 40-150 ms stick pause) through a
                               280/610/1150/2300 Hz limb resonator bank plus weaker 430/880/1650
                               Hz modes (Q 8-15, upper modes favoured), string tension hiss
                               (3-7 kHz, -24 dB). Frame 0 is a zero crossing in a quiet window.
  bow_release (4)     ~0.6 s   slap cluster (~30 % of the energy): band-passed string snap,
                               bracer slap, limb/riser body 'thock' (180-230 / 420-520 /
                               950-1250 Hz); Karplus-Strong string at 100/104/107/110 Hz with a
                               3 % pitch settle and a serving buzz, band-limited 170 Hz-6 kHz
                               (the thin string radiates little fundamental); limb thump
                               45-70 Hz (~12 %); arrow swish from 10 ms.
  arrow_whoosh (3)    ~0.49 s  bandpassed noise sweeping 800-1000 -> 1400-1800 Hz (Q 1.6-2.4),
                               fletching flutter 45-70 Hz, faint narrow-band shaft whistle
                               ~2.2 kHz on 2 of 3 variants.
  bow_let_down (2)    ~0.5 s   shaft scrape forward (250 ms, main layer), slowing creak gliding
                               down 8 % (-5 dB), muted 110 Hz string settle (-9 dB).
  quiver_empty (1)    ~0.28 s  two leather pats (120 Hz-1.2 kHz, 120 ms apart) + cloth rustle.

Conventions used for the spec numbers:
  - Click, knock and tap modes are dry: a stated "N ms decay" means the sound is gone (about
    -35 dB) after N ms, i.e. tau = N / 4. Sound lengths from the spec are carried by the
    brush, settle, slide and cloth layers, never by a ringing mode.
  - Modal hits are excited by a 1-5 ms burst of band-passed noise (plus a soft push that
    reaches the lowest mode); the burst is also radiated directly and a noise residue stands
    in for the dense upper modes, so a knock stays broadband instead of pitched (spectral
    flatness > 0.05 from 5 to 20 ms after the hit).
  - Creak resonators are defined by Q (tau = Q / (pi f)).
  - "-X dB" for a layer is relative to the sound's main layer (peak for transients, RMS for
    steady beds such as the tension hiss and the shaft whistle). Where a share of the energy
    is given ("~35 % of the energy"), the layer is scaled by energy (at_energy), because a
    dry transient's peak says little about how much of the sound it is.

Regenerate:
  python3 tools/sfx/bow.py                        # default seed, all sounds
  python3 tools/sfx/bow.py --seed 7               # a different set of variations
  python3 tools/sfx/bow.py --only bow_release,bow_draw --out /tmp/x
Output: audio/sfx/bow/<id>_<NN>.wav, 44.1 kHz 16-bit mono, peak -1 dBFS, plus a
<file>.wav.import next to each WAV (Godot: uncompressed PCM, loop mode "Detect From WAV").
"""
from __future__ import annotations

import argparse
import os
import sys
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dsp import (SR, ar_env, bandpass, convolve_same, db2lin, dc_block, fft_band,  # noqa: E402
                 finalize, highpass, karplus_strong, loop_xfade, lowpass, mallet, modal_ir,
                 nsamp, peak_norm, pink, place, rng, sine_sweep, smooth_noise, svf, taxis,
                 white, write_wav, write_wav_loop)

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_DIR = os.path.join(ROOT, "audio", "sfx", "bow")
NAME_FMT = "{id}_{n:02d}.wav"


# =========================================================================== building blocks

def band_noise(n: int, lo: float | None, hi: float | None, r: np.random.Generator,
               order: int = 2, pinkish: bool = False) -> np.ndarray:
    """Unit-RMS band-limited noise (filter first, envelope afterwards: no pre-ringing)."""
    x = pink(n, r) if pinkish else white(n, r)
    x = fft_band(x, lo, hi, order)
    return x / (np.std(x) + 1e-12)


def env_pts(n: int, pts) -> np.ndarray:
    """Piecewise-linear envelope through (time_s, value) points."""
    ts, vs = zip(*pts)
    return np.interp(taxis(n), ts, vs)


def norm(x: np.ndarray) -> np.ndarray:
    return peak_norm(x, 1.0)


def rms(x: np.ndarray) -> float:
    return float(np.sqrt(np.mean(x ** 2)) + 1e-12)


def at_rms(x: np.ndarray, db: float, active: float = 0.1) -> np.ndarray:
    """Scale so the RMS over the loudest part (samples above `active` x peak) is `db` re 1.0."""
    a = np.abs(x) > active * np.max(np.abs(x))
    return x * db2lin(db) / (np.sqrt(np.mean(x[a] ** 2)) + 1e-12)


def soft_peaks(x: np.ndarray, pct: float = 99.7) -> np.ndarray:
    """Gently round off the rare biggest peaks (tanh above the pct-th percentile level)."""
    ref = np.percentile(np.abs(x), pct)
    return ref * np.tanh(x / ref)


def energy(x: np.ndarray) -> float:
    return float(np.sum(np.square(x)))


def at_energy(x: np.ndarray, ref: float, rel_db: float) -> np.ndarray:
    """Scale x so its energy is rel_db (dB, power) relative to the energy `ref`."""
    return x * np.sqrt(ref * 10.0 ** (rel_db / 10.0) / (energy(x) + 1e-20))


def mode_amps(r: np.random.Generator, n: int) -> np.ndarray:
    """Modal amplitudes 1, .7, .5, .4, .3, .25 (lowest mode first), each +-4 dB."""
    return np.array([1.0, 0.7, 0.5, 0.4, 0.3, 0.25][:n]) * db2lin(r.uniform(-4, 4, n))


def contact_burst(r: np.random.Generator, dur: float, lo: float = 300.0, hi: float = 6000.0,
                  tau: float | None = None) -> np.ndarray:
    """A rough contact: `dur` s of band-passed noise with a 0.3 ms attack, an exponential
    decay (tau ~ 0.35 x dur) and a cosine fade over the last quarter. Unit peak."""
    n = max(nsamp(dur), 8)
    b = band_noise(n, lo, hi, r) * ar_env(n, min(0.0003, dur / 4), tau or max(0.35 * dur, 0.0004))
    k = max(n // 4, 2)
    b[-k:] *= 0.5 + 0.5 * np.cos(np.pi * (np.arange(k) + 1) / k)
    return norm(b)


def hit(freqs, taus, amps, dur: float, contact: float, r: np.random.Generator,
        noise: float = 0.6, hp: float | None = None, band=(300.0, 6000.0),
        direct: float = 0.3, residue: float = 0.6, res_band=None) -> np.ndarray:
    """Dry modal strike (unit peak before the optional causal highpass `hp`).

    The modes (sine phase: they start from rest, no step or DC thump) are excited by a
    `contact` s burst of band-passed noise; a (1 - noise) share of a half-sine push of the
    same width reaches the lowest mode. On top of the modes the burst is radiated directly
    (`direct` x peak) and a wide band-noise residue decaying like the longest mode stands in
    for the dense, rough upper modes (`residue` x peak). The residue keeps the whole decay
    broadband (spectral flatness > 0.05 from 5 to 20 ms), so a hit reads as a knock, not a
    tone."""
    n = nsamp(dur)
    burst = contact_burst(r, contact, band[0], band[1])
    push = mallet(contact)
    m = min(len(burst), len(push))
    ex = noise * burst[:m] + (1.0 - noise) * push[:m]
    y = norm(convolve_same(np.concatenate([ex, np.zeros(n)]), modal_ir(freqs, taus, amps, dur))[:n])
    y[:len(burst)] += direct * burst[:n]
    if residue > 0:
        lo, hi = res_band or (max(band[0] * 0.5, 100.0), min(band[1] * 1.25, 16000.0))
        res = band_noise(n, lo, hi, r) * ar_env(n, contact * 0.5, float(np.max(taus)))
        y += residue * norm(res)
    return highpass(y, hp, 2) if hp else y


def grains(n: int, rate, r: np.random.Generator, width: float = 0.0015) -> np.ndarray:
    """Poisson micro-contact envelope: impulses at `rate` per second (scalar or per-sample)
    with log-normal strength, each decaying with time constant `width`. Mean-normalized."""
    rate = np.broadcast_to(np.asarray(rate, dtype=float), (n,))
    hits = r.random(n) < rate / SR
    imp = np.zeros(n)
    imp[hits] = r.lognormal(0.0, 0.5, int(hits.sum()))
    k = np.exp(-taxis(max(nsamp(6 * width), 2)) / width)
    y = np.convolve(imp, k)[:n]
    return y / (np.mean(y) + 1e-9)


def rustle(n: int, lo: float, hi: float, rate, r: np.random.Generator, grain: float = 0.0015,
           smooth: float = 0.4, pinkish: bool = False, wobble: float = 0.35) -> np.ndarray:
    """Cloth / feather / leather rustle: band noise whose amplitude is a granular
    crackle (many tiny fibre contacts) plus a slow random swell."""
    base = band_noise(n, lo, hi, r, pinkish=pinkish)
    cr = grains(n, rate, r, grain)
    slow = 1.0 + wobble * smooth_noise(n, 18.0, r)
    return base * (smooth + (1.0 - smooth) * cr) * slow


def click_modes(r: np.random.Generator, fmin: float, fmax: float, count: int) -> np.ndarray:
    return np.sort(r.uniform(fmin, fmax, count))


def wood_click(r: np.random.Generator, freqs, tau: float, amps=None, jitter: float = 0.0,
               contact: float = 0.0015, band=(1000.0, 10000.0), hp: float | None = None,
               direct: float = 0.35, residue: float = 0.6) -> np.ndarray:
    """Small hard wood-on-wood click on a fixed mode set (the same arrows give the same
    modes), each mode jittered by +-`jitter`. `tau` is the decay of the lowest mode; higher
    ones die faster (wood damping rises with frequency)."""
    f = np.asarray(freqs, dtype=float) * (1 + r.uniform(-jitter, jitter, len(freqs)))
    taus = tau * (f[0] / f) ** 0.7 * r.uniform(0.85, 1.15, len(f))
    a = mode_amps(r, len(f)) if amps is None else np.asarray(amps) * db2lin(r.uniform(-2, 2, len(f)))
    return hit(f, taus, a, max(10 * tau, 0.02), contact, r, noise=0.85, band=band,
               hp=hp or f[0] * 0.6, direct=direct, residue=residue)


def friction_scrape(n: int, v: np.ndarray, r: np.random.Generator, lo: float = 600.0,
                    hi: float = 3000.0, grain_rate=(120.0, 1100.0)) -> np.ndarray:
    """Wood-on-leather friction: band noise roughened by micro stick-slip grains whose rate,
    loudness and brightness follow the sliding speed v (0..1 per sample)."""
    split = np.sqrt(lo * hi)
    low = band_noise(n, lo, split * 1.2, r)
    high = band_noise(n, split * 0.8, hi, r)
    tone = low * (1.0 - 0.55 * v) + high * (0.35 + 0.65 * v)
    cr = grains(n, grain_rate[0] + grain_rate[1] * v, r, 0.0012)
    return tone * (0.5 + 0.5 * cr) * np.power(np.clip(v, 0, 1), 1.3)


def string_brush(r: np.random.Generator, f0: float = 110.0, dur: float = 0.08,
                 t60: float = 0.08) -> np.ndarray:
    """Bow string brushing cloth: a damped Karplus-Strong string fed with cloth noise."""
    ne = nsamp(0.025)
    ex = band_noise(ne, 300, 3000, r) * ar_env(ne, 0.004, 0.008)
    y = karplus_strong(f0 * r.uniform(0.98, 1.02), dur + 0.04, t60, damp=0.55, excite=ex * 0.3)
    y = np.tanh(2.0 * norm(y)) / np.tanh(2.0)            # a little buzz against the fibres
    return y * env_pts(len(y), [(0, 1), (dur * 0.8, 1), (dur + 0.04, 0)])


def string_partials(r: np.random.Generator, f0: float, dur: float, tau: float,
                    nh: int = 10, buzz: float = 3.0) -> np.ndarray:
    """Short, damped harmonic string partials (slightly stretched), lightly buzzing."""
    n = nsamp(dur)
    t = taxis(n)
    y = np.zeros(n)
    for k in range(1, nh + 1):
        fk = f0 * k * (1 + 0.0008 * k * k)
        if fk > 12000:
            break
        y += (k ** -0.8) * db2lin(r.uniform(-3, 3)) * np.sin(2 * np.pi * fk * t + r.uniform(0, 6.28)) \
            * np.exp(-t / (tau / (1 + 0.15 * (k - 1))))
    y *= ar_env(n, 0.0015, 1e9)
    return np.tanh(buzz * norm(y)) / np.tanh(buzz)


def pluck(r: np.random.Generator, f0: float, dur: float, t60: float, damp: float,
          pos: float = 0.5, noise: float = 0.3, fmul=None) -> np.ndarray:
    """Karplus-Strong pluck from a triangular displacement (plucked at `pos`) plus noise."""
    p = max(int(SR / f0), 4)
    x = np.arange(p) / p
    tri = np.where(x < pos, x / pos, (1 - x) / (1 - pos)) * 2 - 1
    tri -= tri.mean()
    ex = tri + noise * r.uniform(-1, 1, p)
    return karplus_strong(f0, dur, t60, damp=damp, excite=ex, fmul=fmul)


# --------------------------------------------------------------------------- stick-slip creak

# Principal limb modes 280/610/1150/2300 Hz plus three weaker in-between modes (430/880/1650).
# The principal four sit close to a 1:2:4:8 series, so on their own they fuse into a pitched
# ~280 Hz drone (signal autocorrelation 0.45-0.6 at the 3.5 ms lag); the extra inharmonic
# modes break that up (0.25-0.3). Upper modes favoured: with tau = Q / (pi f) the high modes
# ring far shorter, so equal gains would leave a 280 Hz groan.
CREAK_MODES = np.array([280.0, 430.0, 610.0, 880.0, 1150.0, 1650.0, 2300.0])
CREAK_GAINS = np.array([0.5, 0.45, 0.75, 0.6, 0.85, 0.7, 1.0])


def creak_body(r: np.random.Generator):
    """Per-variant wooden resonator bank: modes near CREAK_MODES (+-4 %), Q 8-15."""
    k = len(CREAK_MODES)
    f = CREAK_MODES * (1 + r.uniform(-0.04, 0.04, k))
    q = r.uniform(8.0, 15.0, k)
    g = CREAK_GAINS * db2lin(r.uniform(-2, 2, k))
    return f, q, g


def slip_events(dur: float, r: np.random.Generator, gap_fn, lo: float = 0.006, hi: float = 0.030,
                walk: float = 0.22, cluster_p: float = 0.05, amp_fn=None, t0: float = 0.0,
                pause_p: float = 0.0, pause=(0.040, 0.150)):
    """Stick-slip timing. The gap between slips is a mean-reverting random walk (log domain)
    around gap_fn(t), clamped to [lo, hi]; now and then a cluster of 2-5 rapid slips, and
    (pause_p per slip) a stick pause during which the resonators die away. A slip after a
    longer stick releases more stored stress, so it is louder."""
    af = amp_fn or (lambda _t: 1.0)
    ev = []
    t = t0
    lg = np.log(gap_fn(t))
    boost = 1.0
    while t < dur:
        lg += 0.35 * (np.log(gap_fn(t)) - lg) + walk * r.standard_normal()
        lg = float(np.clip(lg, np.log(lo), np.log(hi)))
        gap = np.exp(lg)
        a = (gap / 0.012) ** 0.35 * r.lognormal(0.0, 0.25) * af(t) * boost
        boost = 1.0
        ev.append((t, a))
        if r.random() < cluster_p:
            tc = t
            for _ in range(int(r.integers(2, 6))):
                tc += r.uniform(0.0012, 0.004)
                ev.append((tc, a * r.uniform(0.35, 0.8)))
            t = tc
        t += gap
        if pause_p and r.random() < pause_p:
            t += r.uniform(*pause)
            boost = 1.2
    return ev


def render_creak(ev, n: int, r: np.random.Generator, body, fscale=None) -> np.ndarray:
    """Each slip rings the resonator bank (impulse response of a Q-defined 2-pole resonator:
    sin * exp(-t/tau), tau = Q/(pi f)) plus a faint 1-6 kHz grain tick. fscale(t) glides all
    mode frequencies."""
    f, q, g = body
    tau = q / (np.pi * f)
    L = nsamp(min(6 * tau.max(), 0.12))
    tt = taxis(L)
    y = np.zeros(n + L)
    tick_n = nsamp(0.0005)
    tick_env = np.exp(-taxis(tick_n) / 0.00012)
    bank = band_noise(nsamp(0.05), 1000, 6000, r)
    for t, a in ev:
        i = nsamp(t)
        if i >= n:
            continue
        s = fscale(t) if fscale else 1.0
        fk = f * s * (1 + r.uniform(-0.012, 0.012, len(f)))      # each slip excites a slightly
        gk = g * db2lin(r.uniform(-4, 4, len(f)))                 # different spot on the limb
        grain = (gk[:, None] * np.sin(2 * np.pi * fk[:, None] * tt) * np.exp(-tt / tau[:, None])).sum(0)
        j = int(r.integers(0, len(bank) - tick_n))
        grain[:tick_n] += 0.06 * bank[j:j + tick_n] * tick_env
        y[i:i + L] += a * grain
    return y[:n]


def tension_hiss(n: int, r: np.random.Generator) -> np.ndarray:
    """Thin string / serving tension hiss, 3-7 kHz, unit RMS, slowly breathing."""
    h = band_noise(n, 3000, 7000, r, order=3)
    h *= 1.0 + 0.15 * smooth_noise(n, 2.0, r)
    return h / rms(h)


# --------------------------------------------------------------------------- loop helpers

def circ_rms(x: np.ndarray, win: float) -> np.ndarray:
    """Centred moving RMS over `win` s, treating x as circular (a loop)."""
    k = max(nsamp(win), 2)
    p = np.concatenate([x[-k:], x, x[:k]]) ** 2
    return np.sqrt(np.maximum(np.convolve(p, np.ones(k) / k, mode="same")[k:-k], 0.0))


def circ_limit(x: np.ndarray, over_db: float = 4.0, win: float = 0.02, iters: int = 4) -> np.ndarray:
    """Ride down any stretch whose 20 ms RMS is more than over_db above the median (circular,
    smoothed gain), so a loop has no landmark burst that repeats every cycle."""
    k = nsamp(0.012)
    w = np.hanning(k)
    w /= w.sum()
    for _ in range(iters):
        e = circ_rms(x, win)
        g = np.minimum(1.0, np.median(e) * db2lin(over_db) / (e + 1e-12))
        if g.min() > 0.995:
            break
        gp = np.concatenate([g[-k:], g, g[:k]])
        x = x * np.convolve(gp, w, mode="same")[k:-k]
    return x


def roll_to_quiet_zero(x: np.ndarray, below_db: float = 12.0):
    """Rotate a loop so frame 0 is a zero crossing inside the quietest 10 ms window (which must
    be `below_db` under the median). Rotation is circular, so the loop stays seamless."""
    n = len(x)
    e = circ_rms(x, 0.010)
    i0 = int(np.argmin(e))
    ok = e[i0] <= np.median(e) * db2lin(-below_db)
    s = np.signbit(x)
    zc = np.nonzero(s != np.roll(s, -1))[0]
    d = np.abs(zc - i0)
    j = int(zc[np.argmin(np.minimum(d, n - d))])
    if abs(x[(j + 1) % n]) < abs(x[j]):
        j = (j + 1) % n
    return np.roll(x, -j), bool(ok)


def self_similarity(x: np.ndarray, lo: float = 0.002, hi: float = 0.030) -> float:
    """Largest circular autocorrelation of the signal for lags lo..hi s (a creak loop that
    reads as a pitched drone scores high)."""
    X = np.fft.rfft(x)
    ac = np.fft.irfft(X * np.conj(X), len(x))
    ac /= ac[0]
    return float(ac[nsamp(lo):nsamp(hi)].max())


# =========================================================================== sounds

def bow_equip(r, v):
    n = nsamp(0.47)
    y = np.zeros(n)
    # Cloth drag of the stave and string sliding off the shoulder; it carries the length.
    dl = r.uniform(0.39, 0.44)
    nd = nsamp(dl)
    drag = rustle(nd, 250, 5000, 900, r, grain=0.002, smooth=0.45, pinkish=True) \
        + 0.6 * band_noise(nd, 150, 900, r, pinkish=True)
    drag *= env_pts(nd, [(0, 0), (0.035, 0.7), (0.11, 1.0), (dl * 0.55, 0.75), (dl * 0.8, 0.35), (dl, 0)])
    place(y, at_rms(drag, -13), 0.0)
    # Wooden limb knock on the hand: soft skin contact, very dead.
    tk = r.uniform(0.13, 0.16)
    kf = np.array([250.0, 600.0, 900.0, 1300.0, 2100.0]) * (1 + r.uniform(-0.04, 0.04, 5))
    kt = np.array([0.012, 0.008, 0.004, 0.005, 0.0025]) * r.uniform(0.9, 1.1, 5)
    knock = hit(kf, kt, mode_amps(r, 5), 0.1, contact=0.004, r=r, noise=0.6)
    ns = nsamp(0.006)
    skin = band_noise(ns, None, 2500, r) * ar_env(ns, 0.0005, 0.0015)
    place(knock, skin, 0.0, 0.35 * np.max(np.abs(knock)))
    knock = norm(highpass(knock, 120.0, 2))
    # String brushing the cloth as it comes off.
    place(y, string_brush(r, 110.0, 0.08), r.uniform(0.06, 0.10), db2lin(-15))
    # Arrows rattle in the quiver (identical shafts: one mode set, jittered per click).
    am = np.concatenate([[r.uniform(600, 900)], click_modes(r, 1500, 4000, 3)])
    for _ in range(int(r.integers(3, 6))):
        c = wood_click(r, am, r.uniform(0.0015, 0.0025), jitter=0.05)
        place(y, norm(c), r.uniform(0.05, 0.30), db2lin(r.uniform(-18, -11)))
    # The knock is the accent but no longer dominates: ~35 % of the energy (was ~55 %).
    place(y, at_energy(knock, energy(y), -2.7), tk)
    return fade_tail(y, 0.04)


def bow_holster(r, v):
    n = nsamp(0.42)
    y = np.zeros(n)
    dl = r.uniform(0.34, 0.39)
    nd = nsamp(dl)
    cloth = rustle(nd, 250, 5000, 800, r, grain=0.002, smooth=0.45, pinkish=True) \
        + 0.5 * band_noise(nd, 150, 900, r, pinkish=True)
    cloth *= env_pts(nd, [(0, 0), (0.05, 0.9), (0.12, 1.0), (dl * 0.6, 0.6), (dl * 0.85, 0.3), (dl, 0)])
    place(y, at_rms(cloth, -12), 0.0)
    # One dull wooden tap: the limb settling against the back / quiver.
    tt = r.uniform(0.18, 0.22)
    tf = np.array([220.0, 520.0, 1150.0, 2000.0]) * (1 + r.uniform(-0.05, 0.05, 4))
    taus = np.array([0.010, 0.007, 0.004, 0.0025]) * r.uniform(0.9, 1.1, 4)
    tap = norm(highpass(hit(tf, taus, mode_amps(r, 4), 0.08, contact=0.005, r=r, noise=0.6), 120.0, 2))
    place(y, string_brush(r, 110.0, 0.07, 0.07), r.uniform(0.04, 0.08), db2lin(-18))
    am = np.concatenate([[r.uniform(600, 900)], click_modes(r, 1500, 4000, 3)])
    for _ in range(int(r.integers(2, 4))):
        c = wood_click(r, am, r.uniform(0.0015, 0.0025), jitter=0.05)
        place(y, norm(c), tt + r.uniform(-0.02, 0.09), db2lin(r.uniform(-17, -12)))
    # The tap holds ~40 % of the energy (was ~60 %).
    place(y, at_energy(tap, energy(y), -1.8), tt)
    return fade_tail(y, 0.04)


def quiver_draw(r, v):
    n = nsamp(0.37)
    y = np.zeros(n)
    # One mode set per variant (the arrows are identical): a body mode + 3 upper modes.
    modes = np.concatenate([[r.uniform(500, 800)], click_modes(r, 1200, 3500, 3)])
    amps = np.array([1.0, 0.75, 0.55, 0.4])
    t = r.uniform(0.004, 0.015)
    k = int(r.integers(4, 9))
    for i in range(k):
        c = wood_click(r, modes, r.uniform(0.0025, 0.0035), amps=amps, jitter=0.05)
        place(y, norm(c), t, db2lin(r.uniform(-5, 0) if i else 0.0))
        t += r.uniform(0.020, 0.060)
        if t > 0.26:
            break
    # The shaft sliding along the leather: speeds up, then eases as the arrow clears.
    ns = nsamp(0.20)
    tp = r.uniform(0.07, 0.11)
    vel = np.interp(taxis(ns), [0.0, 0.015, tp, 0.16, 0.20], [0.0, 0.35, 1.0, 0.6, 0.0])
    vel = np.clip(vel * (1 + 0.15 * smooth_noise(ns, 12.0, r)), 0, 1)
    sl = friction_scrape(ns, vel, r, lo=800.0, hi=4000.0, grain_rate=(200.0, 900.0))
    place(y, norm(sl), 0.02, db2lin(-6))
    # Fletching brushing the leather at the mouth of the quiver: rises then falls.
    ts = r.uniform(0.16, 0.20)          # overlaps the last clicks as the shaft clears
    nw = nsamp(0.15)
    sw = svf(rustle(nw, 2000, 8000, 2500, r, grain=0.0006, smooth=0.5),
             4200 * np.interp(taxis(nw), [0, 0.09, 0.15], [0.8, 1.2, 0.9]), 0.8, "bp")
    sw *= env_pts(nw, [(0, 0), (0.09, 1.0), (0.15, 0)]) ** 1.5
    place(y, norm(sw), ts, db2lin(-4))
    return fade_tail(y, 0.03)


def arrow_rest(r, v):
    n = nsamp(0.17)
    y = np.zeros(n)
    # Shaft brushing the leather rest / the knuckle.
    nb = nsamp(0.06)
    br = rustle(nb, 2000, 6000, 1500, r, grain=0.0008, smooth=0.55)
    br *= env_pts(nb, [(0, 0), (0.014, 1.0), (0.035, 0.55), (0.06, 0)])
    # Fleshy wooden tap as the shaft lands on the rest.
    tf = np.array([r.uniform(350, 450), 900.0 * r.uniform(0.97, 1.03), r.uniform(1350, 1650),
                   2100.0 * r.uniform(0.97, 1.03), r.uniform(2900, 3500)])
    ta = np.array([0.003, 0.0035, 0.0028, 0.0025, 0.0016]) * r.uniform(0.9, 1.1, 5)
    aa = np.array([0.6, 1.0, 0.4, 0.55, 0.3]) * db2lin(r.uniform(-3, 3, 5))
    tap = hit(tf, ta, aa, 0.04, contact=0.002, r=r, noise=0.7, band=(400.0, 7000.0), hp=200.0)
    t1 = r.uniform(0.022, 0.030)
    place(y, norm(tap), t1, 1.0)
    # The shaft settles a hair later: its own contact point and modes, with a short slide.
    t2 = t1 + r.uniform(0.045, 0.06)
    sf = np.array([r.uniform(1100, 1300), r.uniform(1800, 2200), r.uniform(2600, 3000), r.uniform(3800, 4600)])
    settle = hit(sf, np.array([0.0025, 0.0018, 0.0014, 0.001]), mode_amps(r, 4), 0.03, contact=0.0015,
                 r=r, noise=0.8, band=(800.0, 8000.0), hp=500.0)
    place(y, norm(settle), t2, db2lin(-12))
    nl = nsamp(0.07)
    sl = rustle(nl, 1500, 5000, 1200, r, grain=0.0008, smooth=0.5)
    sl *= env_pts(nl, [(0, 0), (0.015, 1.0), (0.03, 0.45), (0.07, 0)])
    place(y, norm(sl), t2 - 0.015, db2lin(-15))       # slides a few mm, then settles
    # The brush comes first in time but is set last: ~25 % of the energy (was 3-7 %).
    place(y, at_energy(norm(br), energy(y), -4.8), 0.0)
    return fade_tail(y, 0.03)


NOCK_SCRAPE_MS = ((3.0, 5.0), (5.5, 7.5), (8.0, 10.0))


def nock_click(r, v):
    n = nsamp(0.14)
    y = np.zeros(n)
    # Nock pushed onto the string: a 3-10 ms micro-scrape (length spread across variants).
    ls = r.uniform(*NOCK_SCRAPE_MS[v % 3]) / 1000.0
    nsc = nsamp(ls)
    sc = band_noise(nsc, 2000, 8000, r) * (0.5 + 0.5 * grains(nsc, 3000.0, r, 0.0003))
    sc *= env_pts(nsc, [(0, 0), (ls * 0.3, 0.6), (ls * 0.85, 1.0), (ls, 0.7)])
    place(y, norm(sc), 0.002, db2lin(-14))
    # The snap: horn nock over the string, very short, plus two tiny high modes.
    tc = 0.002 + ls
    cf = np.concatenate([np.array([3500.0, 6200.0]) * (1 + r.uniform(-0.03, 0.03, 2)),
                         r.uniform(8000, 11000, 2)])
    ct = np.array([0.0018, 0.0012, 0.0006, 0.0006])
    ca = np.array([1.0, 0.7 * r.uniform(0.8, 1.2), 0.45, 0.35]) * db2lin(r.uniform(-2, 2, 4))
    click = hit(cf, ct, ca, 0.02, contact=0.0015, r=r, noise=0.9, band=(2000.0, 14000.0),
                hp=1500.0, direct=0.4, residue=0.6)
    place(y, norm(click), tc, 1.0)
    e_click = energy(norm(click))
    # Sometimes the nock seats in two steps: a second micro-click 2-5 ms later.
    if (False, True, r.random() < 0.5)[v % 3]:
        c2 = hit(cf * r.uniform(0.97, 1.03, 4), ct * 0.8, ca[::-1] * 0.8 + 0.2, 0.015, contact=0.001,
                 r=r, noise=0.9, band=(2500.0, 14000.0), hp=2000.0, direct=0.5, residue=0.6)
        g2 = db2lin(r.uniform(-10, -6))
        place(y, norm(c2), tc + r.uniform(0.002, 0.005), g2)
        e_click += energy(norm(c2) * g2)
    # The string is barely disturbed: damped partials around 180 Hz, ~45 ms.
    s = string_partials(r, 180.0 * r.uniform(0.95, 1.05), 0.05, 0.02, buzz=1.5)
    s *= env_pts(len(s), [(0, 1), (0.025, 0.4), (0.045, 0)])
    place(y, at_energy(s, e_click, r.uniform(-13, -11)), tc + r.uniform(0.004, 0.012))
    # Fingers closing on the string after the nock is seated.
    nf = nsamp(r.uniform(0.03, 0.045))
    fl = rustle(nf, 1500, 6000, 1500, r, grain=0.0008, smooth=0.5)
    fl *= env_pts(nf, [(0, 0), (nf / SR * 0.3, 1.0), (nf / SR, 0)])
    place(y, norm(fl), tc + r.uniform(0.025, 0.04), db2lin(r.uniform(-24, -20)))
    return fade_tail(y, 0.02)


def bow_draw(r, v):
    dur = 0.6
    n = nsamp(dur)
    y = np.zeros(n)
    t = taxis(n)
    # Finger grip on the string: 3 ms 'tk'.
    ng = nsamp(0.003)
    tk = band_noise(ng, 900, 6000, r) * np.exp(-taxis(ng) / 0.0007)
    tk += norm(hit([2300 * r.uniform(0.9, 1.1)], [0.0012], [1.0], 0.003, contact=0.001, r=r,
                   residue=0.0))[:ng] * 0.6
    place(y, norm(tk), 0.004, db2lin(-4))
    # Draw speed: accelerates, cruises, eases in at full draw.
    ta, tb = r.uniform(0.25, 0.32), r.uniform(0.44, 0.50)
    vel = np.interp(t, [0.0, 0.02, ta, tb, 0.575, dur], [0.0, 0.0, 1.0, 0.9, 0.3, 0.0])
    vel = vel * (1 + 0.12 * smooth_noise(n, 9.0, r))
    scrape = norm(friction_scrape(n, np.clip(vel, 0, 1), r)) * db2lin(-3)
    place(y, scrape, 0.0)
    # Limb creak: sparse -> dense as the bend builds (same recipe as bow_creak_loop).
    def gap(tt):
        u = np.clip((tt - 0.05) / 0.50, 0, 1)
        return np.exp(np.log(0.045) + (np.log(0.007) - np.log(0.045)) * u)
    ev = slip_events(0.585, r, gap, lo=0.006, hi=0.06, cluster_p=0.06,
                     amp_fn=lambda tt: 0.25 + 0.75 * np.clip((tt - 0.05) / 0.5, 0, 1) ** 0.7,
                     t0=r.uniform(0.05, 0.09))
    body = creak_body(r)
    creak = render_creak(ev, n, r, body)
    place(y, at_energy(creak, energy(scrape), r.uniform(-5.0, -4.0)), 0.0)   # ~-6 dB of the file
    # Fletching whispers past the hand at the end.
    nf = nsamp(0.08)
    fl = rustle(nf, 2000, 8000, 3000, r, grain=0.0005, smooth=0.5)
    fl *= env_pts(nf, [(0, 0), (0.03, 1.0), (0.08, 0)])
    place(y, norm(fl), r.uniform(0.49, 0.51), db2lin(-9))
    return fade_tail(y, 0.03)


def bow_creak_loop(r, v):
    total, xf = 2.2, 0.2
    n = nsamp(total)
    y = None
    for _attempt in range(8):
        f1, f2, f3 = r.uniform(0.3, 0.8, 3)
        p1, p2, p3 = r.uniform(0, 2 * np.pi, 3)
        gm = r.uniform(0.015, 0.020)

        def gap(tt):   # density drifts slowly (two incommensurate LFOs in 0.3-0.8 Hz)
            return gm * np.exp(0.4 * np.sin(2 * np.pi * f1 * tt + p1) + 0.2 * np.sin(2 * np.pi * f2 * tt + p2))

        def amp(tt):
            return 1.0 + 0.2 * np.sin(2 * np.pi * f3 * tt + p3)

        ev = slip_events(total, r, gap, lo=0.006, hi=0.045, cluster_p=0.05, amp_fn=amp, pause_p=0.03)
        creak = soft_peaks(render_creak(ev, n, r, creak_body(r)), 99.5)
        x = dc_block(creak + tension_hiss(n, r) * rms(creak) * db2lin(-24))
        x = circ_limit(loop_xfade(x, xf), over_db=4.0)
        y, quiet = roll_to_quiet_zero(x, below_db=12.0)
        if quiet and self_similarity(y) < 0.33:
            break
    return y


RELEASE_F0 = (100.0, 104.0, 107.0, 110.0)
RELEASE_DAMP = (0.33, 0.29, 0.37, 0.31)
# String ring (t60 = 1.6 x ring, s), set per variant so the whole file is -30 dB (5 ms RMS,
# re its peak) at 0.22-0.28 s; the darker (higher damp) variants need a little more.
RELEASE_RING = (0.49, 0.43, 0.46, 0.42)
RELEASE_CLUSTER_DB = -2.6     # snap + bracer + body energy re the string (~30 % of the file)
RELEASE_THUMP_DB = -6.8       # 45-70 Hz thump energy re the string (~12 %)


def bow_release(r, v):
    n = nsamp(0.8)
    y = np.zeros(n)
    t = taxis(n)
    k = v % 4
    # (a) String: Karplus-Strong, pitch settling 3 % down in 40 ms, a short serving buzz
    # (+-0.5 % pitch jitter, 15-50 ms). A thin string radiates little fundamental: the
    # twang comes through the limbs, so it is high-passed at 170 Hz after the drive.
    # It is the energy reference for the other layers.
    f0 = RELEASE_F0[k] * r.uniform(0.995, 1.005)
    ring = RELEASE_RING[k] * r.uniform(0.95, 1.05)
    u = np.clip(t / 0.04, 0.0, 1.0)
    buzz = np.clip((t - 0.012) / 0.005, 0, 1) * np.clip((0.05 - t) / 0.012, 0, 1)
    fmul = 1.0 + 0.03 * (1.0 - u * u * (3.0 - 2.0 * u)) + 0.005 * buzz * smooth_noise(n, 400.0, r)
    s = pluck(r, f0, 0.8, t60=1.6 * ring, damp=RELEASE_DAMP[k] + r.uniform(-0.01, 0.01),
              pos=r.uniform(0.35, 0.45), noise=0.35, fmul=fmul)
    s = highpass(np.tanh(1.6 * norm(s)) / np.tanh(1.6), 170.0, 4)
    # The pluck's noise excitation leaves a white burst in the first periods; a gentle 6 kHz
    # lowpass keeps it from becoming a digital tick (was ~5 % of the energy above 12 kHz).
    s = lowpass(s, 6000.0, 2)
    e_str = energy(s)
    # (b) Slap cluster: a 0.4 ms band-passed snap, the string hitting the leather bracer and
    # the limb / riser body taking the shock (the dry wooden 'thock').
    ns = nsamp(0.004)
    snap = norm(bandpass(white(ns, r) * np.exp(-taxis(ns) / 0.0004), 800.0, 6000.0, 2))
    nb = nsamp(0.05)
    bracer = norm(band_noise(nb, 500, 4000, r) * ar_env(nb, 0.0005, 0.008))
    tb = r.uniform(0.002, 0.004)
    bf = np.array([205.0, 470.0, 1100.0, 2400.0]) * (1 + r.uniform(-0.06, 0.06, 4))
    bt = np.array([0.025, 0.015, 0.008, 0.004]) * r.uniform(0.9, 1.1, 4)
    body = norm(hit(bf, bt, mode_amps(r, 4), 0.2, contact=0.003, r=r, noise=0.5,
                    band=(200.0, 5000.0), hp=90.0, direct=0.2, residue=0.4)) * db2lin(-6)
    cl = np.zeros(n)
    cl[:len(snap)] += snap
    cl[nsamp(tb):nsamp(tb) + nb] += bracer
    cl[:len(body)] += body
    g = np.sqrt(e_str * 10 ** (RELEASE_CLUSTER_DB / 10) / energy(cl))   # ~30 % of the file
    place(y, snap, 0.0, g)
    place(y, bracer, tb, g)
    place(y, body, 0.0, g)
    place(y, s, 0.001)
    # (c) Limb thump / hand shock: 45-70 Hz, 60 ms, dropping slightly (weight, ~10 %).
    nt = nsamp(0.12)
    ft = r.uniform(45, 70)
    th = sine_sweep(nt, ft * (1 + 0.12 * np.exp(-taxis(nt) / 0.02))) * ar_env(nt, 0.002, 0.02)
    place(y, at_energy(th, e_str, RELEASE_THUMP_DB), 0.0)
    # (d) Arrow leaving: 1-5 kHz swish, 60 ms, from 10 ms.
    nw = nsamp(0.06)
    sw = band_noise(nw, 1000, 5000, r) * env_pts(nw, [(0, 0), (0.008, 1.0), (0.025, 0.6), (0.06, 0)])
    place(y, at_energy(sw, e_str, -11.0), 0.010)
    return fade_tail(y, 0.06)


def arrow_whoosh(r, v):
    dur = 0.5
    n = nsamp(dur)
    t = taxis(n)
    fa, fb = r.uniform(800, 1000), r.uniform(1400, 1800)
    fc = fa * (fb / fa) ** (t / dur)
    noise = svf(svf(pink(n, r), fc, r.uniform(1.6, 2.4), "bp"), fc, 1.2, "bp")
    noise /= rms(noise)
    hold = r.uniform(0.15, 0.22)
    env = ar_env(n, 0.015, 1e9)
    env *= np.where(t < hold, 1.0, np.exp(-(t - hold) / r.uniform(0.06, 0.075)))
    fm = r.uniform(45, 70) * (1 + 0.03 * smooth_noise(n, 6.0, r))
    ph = 2 * np.pi * np.cumsum(fm) / SR + r.uniform(0, 6.28)
    depth = r.uniform(0.35, 0.5)
    flutter = 1.0 + depth * (0.8 * np.sin(ph) + 0.2 * np.sin(2 * ph + 1.0))
    y = noise * flutter
    if v % 3 != 2:
        # Shaft whistle: narrow-band noise (Q 20-30), not a sine. At -23 dB re the body RMS its
        # spectral density is only ~3 dB above the body noise around 2.2 kHz: a faint colour.
        wf = r.uniform(2050, 2350) * (1 + 0.04 * t / dur)
        wh = svf(pink(n, r), wf, r.uniform(20.0, 30.0), "bp")
        wh = wh / rms(wh) * (1.0 + 0.3 * depth * np.sin(ph))
        y = y + wh * db2lin(-23)
    return fade_tail(y * env, 0.05)


def bow_let_down(r, v):
    n = nsamp(0.56)
    y = np.zeros(n)
    t0, t1 = 0.005, r.uniform(0.36, 0.40)

    def gap(tt):   # stick-slip rate falls as the bend relaxes
        u = np.clip((tt - t0) / (t1 - t0), 0, 1)
        return np.exp(np.log(0.007) + (np.log(0.040) - np.log(0.007)) * u)

    ev = slip_events(t1, r, gap, lo=0.006, hi=0.05, cluster_p=0.08,
                     amp_fn=lambda tt: 1.0 - 0.7 * np.clip((tt - t0) / (t1 - t0), 0, 1), t0=t0)
    creak = render_creak(ev, n, r, creak_body(r),
                         fscale=lambda tt: 1.0 - 0.08 * np.clip((tt - t0) / (t1 - t0), 0, 1))
    place(y, norm(creak), 0.0, db2lin(-5))
    # Shaft sliding forward over the rest: the main layer, 250 ms.
    nsc = nsamp(0.25)
    sp = np.sin(np.pi * np.clip(taxis(nsc) / 0.25, 0, 1)) ** 1.5 * 0.7
    sc = friction_scrape(nsc, sp, r, lo=500, hi=2500, grain_rate=(80.0, 500.0))
    place(y, norm(sc), r.uniform(0.05, 0.08), 1.0)
    # Muted string settle at the end.
    st = pluck(r, 110.0 * r.uniform(0.98, 1.02), 0.1, t60=0.07, damp=0.75, noise=0.2)
    st *= env_pts(len(st), [(0, 1), (0.06, 0.5), (0.1, 0)])
    place(y, norm(st), r.uniform(0.42, 0.46), db2lin(-9))
    return fade_tail(y, 0.03)


def quiver_empty(r, v):
    n = nsamp(0.31)
    y = np.zeros(n)

    def pat():
        m = nsamp(0.025)
        slap = band_noise(m, None, 3000, r, pinkish=True) * ar_env(m, 0.0008, 0.005)
        body = modal_ir([r.uniform(180, 260), r.uniform(420, 560)], [0.008, 0.005], [1.0, 0.5], 0.025)
        x = norm(slap) + 0.8 * norm(body)
        x = highpass(lowpass(x, 1200.0, 2), 120.0, 2)
        return x * env_pts(m, [(0, 1), (0.018, 0.4), (0.025, 0)])

    ta = r.uniform(0.008, 0.015)
    place(y, norm(pat()), ta, 1.0)
    place(y, norm(pat()), ta + 0.12, db2lin(-2))
    nr = nsamp(0.28)
    cl = rustle(nr, 300, 4000, 600, r, grain=0.002, smooth=0.45, pinkish=True)
    cl *= env_pts(nr, [(0, 0), (0.04, 1.0), (0.2, 0.7), (0.28, 0)])
    place(y, norm(cl), 0.0, db2lin(-16))
    return fade_tail(y, 0.03)


def fade_tail(y: np.ndarray, dur: float) -> np.ndarray:
    k = nsamp(dur)
    y[-k:] *= 0.5 + 0.5 * np.cos(np.pi * (np.arange(k) + 1) / k)
    return y


# =========================================================================== table / main

# id: (generator, variants, lead_trim, loop)
SOUNDS = {
    "bow_equip": (bow_equip, 2, True, False),
    "bow_holster": (bow_holster, 2, True, False),
    "quiver_draw": (quiver_draw, 3, True, False),
    "arrow_rest": (arrow_rest, 2, True, False),
    "nock_click": (nock_click, 3, True, False),
    "bow_draw": (bow_draw, 3, False, False),
    "bow_creak_loop": (bow_creak_loop, 2, False, True),
    "bow_release": (bow_release, 4, True, False),
    "arrow_whoosh": (arrow_whoosh, 3, True, False),
    "bow_let_down": (bow_let_down, 2, True, False),
    "quiver_empty": (quiver_empty, 1, True, False),
}

# Godot import: keep these short transients as uncompressed 16-bit PCM (Godot 4.3+ imports
# WAVs as lossy QOA by default) and let the importer take the loop from the smpl chunk.
IMPORT_PARAMS = {"compress/mode": "0", "edit/loop_mode": "0"}


def write_import_settings(wav_path: str) -> None:
    """Set IMPORT_PARAMS in <wav>.import. An existing file (written by the editor) keeps
    everything else; otherwise a minimal stub is written that the editor completes (uid,
    dest files) the next time it imports the WAV."""
    ip = wav_path + ".import"
    if not os.path.exists(ip):
        with open(ip, "w") as fh:
            fh.write('[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\n\n'
                     + "".join(f"{k}={v}\n" for k, v in IMPORT_PARAMS.items()))
        return
    with open(ip) as fh:
        lines = fh.read().splitlines()
    todo = dict(IMPORT_PARAMS)
    out, section = [], ""
    for ln in lines:
        s = ln.strip()
        if s.startswith("[") and s.endswith("]"):
            if section == "params" and todo:
                i = len(out)
                while i > 0 and not out[i - 1].strip():
                    i -= 1
                out[i:i] = [f"{key}={val}" for key, val in todo.items()]
                todo = {}
            section = s[1:-1]
        elif section == "params" and "=" in s and s.split("=", 1)[0] in todo:
            key = s.split("=", 1)[0]
            ln = f"{key}={todo.pop(key)}"
        out.append(ln)
    if todo:
        if section != "params":
            out += ["", "[params]", ""]
        out.extend(f"{k}={v}" for k, v in todo.items())
    with open(ip, "w") as fh:
        fh.write("\n".join(out) + "\n")


def render(sid: str, v: int, seed: int) -> tuple[np.ndarray, bool]:
    gen, _, lead, loop = SOUNDS[sid]
    r = rng(seed + zlib.crc32(sid.encode()) % 100000 + 7919 * v)
    x = gen(r, v)
    if loop:
        return peak_norm(x, db2lin(-1.0)), True
    return finalize(x, -1.0, fade=0.015, lead_trim=lead, thresh_db=-60.0), False


def main(argv=None) -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, default=4242, help="base seed; change for new variations")
    ap.add_argument("--out", default=OUT_DIR, help="output directory")
    ap.add_argument("--only", default="", help="comma-separated sound ids")
    ap.add_argument("--variants", type=int, default=0, help="override variant count")
    ap.add_argument("--no-import", action="store_true", help="do not write/patch .import files")
    a = ap.parse_args(argv)
    ids = [s for s in a.only.split(",") if s] or list(SOUNDS)
    os.makedirs(a.out, exist_ok=True)
    for sid in ids:
        count = a.variants or SOUNDS[sid][1]
        for v in range(count):
            x, loop = render(sid, v, a.seed)
            path = os.path.join(a.out, NAME_FMT.format(id=sid, n=v + 1))
            if loop:
                write_wav_loop(path, x, 0, len(x) - 1, seed=v)
            else:
                write_wav(path, x, seed=v)
            if not a.no_import:
                write_import_settings(path)
            print(f"{path}  {len(x) / SR:.3f} s{'  (loop)' if loop else ''}")


if __name__ == "__main__":
    main()
