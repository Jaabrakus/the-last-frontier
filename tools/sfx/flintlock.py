#!/usr/bin/env python3
"""'flintlock' family: musket / pistol locks, pan flash, shots, reverb tails and
the lock, reload and equip Foley (scripts/weapons/firearm.gd, musket.gd, pistol.gd).

Everything is synthesized (numpy + stdlib only): shaped noise, oscillators,
modal banks struck by contact pulses, a frequency-domain tube comb, crackle and
granular streams, and synthetic stereo impulse responses for the tails.

Sounds (variants), mono unless noted:
  musket_lock (3)          ~60 ms  sear tick, flint scrape + sparks, frizzen, cock stop 'CLACK' + stock
  pistol_lock (3)          ~50 ms  same recipe, steel modes x1.3, decays x0.7
  pan_flash (3)            ~250 ms 'fssht': 0.3-11 kHz onset (1 ms rise), 1-7 kHz body tau 60 ms
                                   with a 9 -> 3 kHz lowpass sweep, 2-5 kHz crackle, 250 Hz puff
  musket_shot (3)          ~1.3 s  shock-front crack on a Friedlander pressure pulse, 'boom' noise
                                   70-350 Hz, 70->50 Hz sine (-13 dB), saturated blast, after-burn
  musket_tail (2)          ~4.0 s  STEREO forest: discrete slaps at 0.09/0.17/0.26/0.38 s, diffuse bed
  musket_tail_fort (2)     ~3.5 s  STEREO palisade slap + 95 ms flutter, then a quieter forest tail
  pistol_shot (3)          ~0.7 s  crack +6 dB, 2-3 ms pulse, 120-600 Hz boom, 120->80 Hz sine, bark
  pistol_tail (2)          ~2.6 s  STEREO, tau 0.55 s, slaps lowpassed 4.5 kHz, less rumble
  pistol_tail_fort (2)     ~2.2 s  STEREO, palisade slap/flutter (0.35 s), forest tail tau 0.5 s
  dry_fire (3)             ~55 ms  sear tick, 4-10 ms flint slip, steel clack (850-1600 Hz base,
                                   one slot of that range per variant) + contact + stock knock
  cock_half (3)            ~120 ms friction then half-cock click (steel from ~2.8 kHz) + 250 Hz knock
  cock_full (3)            ~140 ms light tick, full-cock click at 70-110 ms, mainspring groan
  frizzen_open (2)         ~95 ms  thumb tick, spring snap (steel from ~2.4 kHz), 300 Hz knock
  frizzen_close (3)        ~75 ms  two steel impacts 6-10 ms apart + 2-3 rattle ticks
  cartridge_draw (2)       ~0.45 s leather flap creak, flap slap, paper-on-wood slide
  cartridge_bite (4)       ~0.25 s tooth 'tk', 1-2 paper rips, 'ptt' lip spit (150-2500 Hz)
  powder_pour_pan (3)      ~0.45 s 4-9 kHz grain stream with 5-10 Hz tap wobble + pan ring
  powder_pour_barrel (3)   ~0.9 s  grains through a 6.4 ms closed-pipe comb, paper crumple
  powder_pour_barrel_pistol (2) ~0.4 s same with a 1.46 ms comb
  ball_seat (2)            ~0.15 s paper crunch, damped lead tick, short barrel 'toonk'
  musket_handle (3)        ~0.25 s palm slide, wood knock 180/420 Hz, sling swivel jingle
  ramrod_draw (2)          ~0.55 s rasping scrape speeding up, 3 thimble ticks, whip swish
  ram_stroke (4)           ~0.3 s  comb slide into a 'tunk' + thud at ~0.13 s + barrel ring;
                                   variant 04 is the harder final seat (more ring, ~0.45 s)
  ram_stroke_pistol (3)    ~0.16 s 50 ms slide (1.46 ms comb), 'tink-tunk' at ~0.06 s
  ramrod_return (2)        ~0.6 s  flip swish, rasp with closing-up ticks, seating 'tock'
  musket_equip (2)         ~0.6 s  sling creak, stock slap at 0.30 s, swivel rattle, rustle
  musket_holster (2)       ~0.4 s  rustle, sling creak, 140 Hz back bump, swivel tick
  pistol_equip (2)         ~0.25 s belt friction, hook scrape, grip slap 300/800 Hz
  pistol_holster (2)       ~0.25 s slide, 5 kHz hook tick, soft wood bump

How the spec's numbers are read:
  - A layer's "-N dB" is its peak relative to the sound's main (0 dB) layer: the scrape
    for the locks, the clack for dry_fire, the click/snap for the cock and frizzen
    sounds, the impact for the ram strokes, the knock/slap for handling sounds, the
    body for pan_flash and the (final, highpassed) pressure pulse for the shots.
    RMS ratios instead: the pan ring of powder_pour_pan, the ram strokes' thud (re the
    tunk) and the noisy part of a handling knock (re its modes).
  - "tau" is an exponential time constant and is used as given.
  - A modal "N ms decay" becomes tau = N / 3 (the mode is ~26 dB down after N), for
    every sound. Steel parts (lock frizzen and cock, cock/frizzen clicks, dry-fire
    clack, thimble / swivel / hook ticks, ramrod tock) are not 2-4 fixed partials but
    steel_modes(): 8-12 inharmonic modes from f0 to 6*f0 (<= 14 kHz), no near-integer
    ratios, amplitudes 0.3-1.0, each with a doublet partner, random phases, upper
    modes' tau scaled by (f0/f)^0.5 (+-25 %), plus a 0.5 ms contact burst. ring()
    then listens to the late ring (15 ms on, Hann-weighted) and turns down any line
    holding more than 30 % of it, so no part rings on as a single beep.
  - Handling knocks and the ram tunk: each variant draws its pitch from its own slot
    of the detune range (vslot), so variants never land on the same note.
  - ram_stroke / ram_stroke_pistol are not lead-trimmed: the impact sits at 0.13 s /
    0.06 s in every variant; the slide (90-160 / 45-55 ms) runs up to it.
  - Shots: gun_shot() checks that the report is the loudest 1 ms and the peak sample
    of the file, both within its first 3 ms; if random layers bury it, everything but
    the report is tucked under it for 3-40 ms (down to -4 dB), then the pulse's own
    tail (-3 dB), then the crack is raised. musket_shot/pistol_shot assert it.
  - Tails: reflections only (no direct path; the first 15 ms are silent pre-delay).
    Slaps and flutter reflect a 20 ms transient window of the dry shot and are
    bandpassed (slaps from 200 Hz, palisade from 120 Hz, flutter from 300 Hz), so an
    echo is a slap, not a second 'whum'; the diffuse bed gets the whole shot. Slap
    levels are relative to the direct sound; the diffuse part is set by short-term
    (50 ms) RMS relative to the dry shot, the 45-180 Hz 'thunder' relative to the
    reflections. The thunder's AM is a random 1.5-3.5 Hz wander with 1-2 slow swells;
    a draw whose low-end loudness still falls into a rhythm (lf_regularity) is redrawn.
    Bass below 150 Hz is kept mono (side channel highpassed).

Regenerate:
  python3 tools/sfx/flintlock.py                         # default seed, all sounds
  python3 tools/sfx/flintlock.py --seed 7                # a different set of variations
  python3 tools/sfx/flintlock.py --only musket_shot,musket_tail --out /tmp/x
  python3 tools/sfx/flintlock.py --list
Output: audio/sfx/flintlock/<id>_<NN>.wav, 44.1 kHz 16-bit, peak -1 dBFS, plus
flintlock_manifest.json (files, lengths, and the spec's playback settings).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dsp import (SR, ar_env, biquad_coeffs, db2lin, fade_in, fftconvolve, finalize,  # noqa: E402
                 mallet, modal_ir, nsamp, peak_norm, place, rng, smooth_noise,
                 stick_slip_train, taxis, trim, write_wav)

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_DIR = os.path.join(ROOT, "audio", "sfx", "flintlock")
NAME_FMT = "{id}_{n:02d}.wav"
MANIFEST = "flintlock_manifest.json"
DEFAULT_SEED = 1757

K_DECAY = 3.0   # modal "N ms decay" -> tau = N / K_DECAY (about -26 dB at N)
MUSKET_TUBE = 2 * 1.10 / 343.0    # 6.41 ms round trip in the 1.1 m barrel
PISTOL_TUBE = 2 * 0.25 / 343.0    # 1.46 ms in the 0.25 m barrel


def dtau(ms: float, k: float = K_DECAY) -> float:
    return ms * 1e-3 / k


def lv(x: np.ndarray, db: float = 0.0) -> np.ndarray:
    """Peak-normalize a layer and set it to `db` relative to the main layer."""
    return peak_norm(np.asarray(x, dtype=float)) * db2lin(db)


def det(r: np.random.Generator, f: float, pct: float) -> float:
    return f * r.uniform(1.0 - pct, 1.0 + pct)


# --------------------------------------------------------------------------- filters
# Causal IIR filters evaluated in the frequency domain: the cascade's exact response
# H(e^jw) multiplies a zero-padded FFT, which equals time-domain filtering once the
# padding lets the IIR tail die out. Fast, and works on (n,) and (n, 2) arrays.

def _nfft(n: int) -> int:
    return 1 << max(int(n - 1).bit_length(), 1)


def _butter(kind: str, fc: float, order: int = 2) -> list:
    secs = []
    if order % 2:
        k = np.tan(np.pi * min(fc, 0.49 * SR) / SR)
        b = [k / (1 + k), k / (1 + k), 0.0] if kind == "lp" else [1 / (1 + k), -1 / (1 + k), 0.0]
        secs.append((b, [1.0, (k - 1) / (k + 1), 0.0]))
    for i in range(1, order // 2 + 1):
        secs.append(biquad_coeffs(kind, fc, 1.0 / (2.0 * np.sin((2 * i - 1) * np.pi / (2 * order)))))
    return secs


def iir(x: np.ndarray, secs: list, pad: float = 0.3) -> np.ndarray:
    x = np.asarray(x, dtype=float)
    n = x.shape[0]
    nf = _nfft(n + nsamp(pad))
    z1 = np.exp(-2j * np.pi * np.fft.rfftfreq(nf))
    h = np.ones(len(z1), dtype=complex)
    for b, a in secs:
        h *= (b[0] + b[1] * z1 + b[2] * z1 * z1) / (a[0] + a[1] * z1 + a[2] * z1 * z1)
    y = np.fft.irfft(np.fft.rfft(x, nf, axis=0) * (h[:, None] if x.ndim == 2 else h), nf, axis=0)
    return y[:n]


def lp(x, fc, order=2):
    return iir(x, _butter("lp", fc, order))


def hp(x, fc, order=2):
    return iir(x, _butter("hp", fc, order))


def bp(x, lo, hi, order=2):
    return iir(x, _butter("hp", lo, order) + _butter("lp", hi, order))


def peq(x, f0, q, gain_db):
    return iir(x, [biquad_coeffs("peak", f0, q, gain_db)])


def reson(x, f0, q):
    return iir(x, [biquad_coeffs("bp", f0, q)], pad=0.5)


def lpg(f, fc, order=2):
    return 1.0 / np.sqrt(1.0 + (np.asarray(f) / fc) ** (2 * order))


def hpg(f, fc, order=2):
    return 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-3)) ** (2 * order))


def tv_filter(x: np.ndarray, gain_fn, frame: int = 1024, hop: int = 256) -> np.ndarray:
    """Time-varying zero-phase filter (STFT overlap-add, sqrt-Hann in and out).

    gain_fn(t, f) -> magnitude, with t (frames, 1) seconds and f (1, bins) Hz.
    Meant for noise-like material (sweeping lowpass on a tail, a swish band).
    """
    x = np.asarray(x, dtype=float)
    mono = x.ndim == 1
    xx = x[:, None] if mono else x
    n = xx.shape[0]
    win = np.sqrt(0.5 - 0.5 * np.cos(2 * np.pi * np.arange(frame) / frame))
    xp = np.pad(xx, ((frame, 2 * frame), (0, 0)))
    starts = np.arange(0, xp.shape[0] - frame + 1, hop)
    f = np.fft.rfftfreq(frame, 1.0 / SR)
    tc = (starts + frame / 2 - frame) / SR
    g = np.broadcast_to(np.asarray(gain_fn(tc[:, None], f[None, :]), dtype=float), (len(starts), len(f)))
    frames = xp[starts[:, None] + np.arange(frame)[None, :]] * win[None, :, None]
    yf = np.fft.irfft(np.fft.rfft(frames, axis=1) * g[:, :, None], frame, axis=1) * win[None, :, None]
    y = np.zeros_like(xp)
    wsum = np.zeros(xp.shape[0])
    for i, s in enumerate(starts):
        y[s:s + frame] += yf[i]
        wsum[s:s + frame] += win ** 2
    y = (y / np.maximum(wsum, 1e-9)[:, None])[frame:frame + n]
    return y[:, 0] if mono else y


def tube(x: np.ndarray, delay: float, g: float, damp: float | None = None, sign: float = -1.0,
         tail: float = 0.3) -> np.ndarray:
    """Feedback comb y = x + sign*g*L(y delayed), evaluated exactly in the frequency domain.

    A barrel is closed at the breech and open at the muzzle, so the round trip
    (delay = 2L/c) inverts the wave: sign=-1 gives the odd-harmonic resonances of a
    closed pipe (c/4L, 3c/4L, ...). L is a one-pole loop lowpass (wall losses).
    Returns len(x) + tail samples.
    """
    x = np.asarray(x, dtype=float)
    m = len(x) + nsamp(tail)
    nf = _nfft(m + nsamp(0.1))
    f = np.fft.rfftfreq(nf, 1.0 / SR)
    z1 = np.exp(-2j * np.pi * f / SR)
    loop = np.ones_like(z1)
    if damp:
        p = np.exp(-2 * np.pi * damp / SR)
        loop = (1 - p) / (1 - p * z1)
    h = 1.0 / (1.0 - sign * g * loop * np.exp(-2j * np.pi * f * delay))
    return np.fft.irfft(np.fft.rfft(x, nf) * h, nf)[:m]


# --------------------------------------------------------------------------- sources

def colored(r: np.random.Generator, dur: float, lo: float | None = None, hi: float | None = None,
            order: int = 2, extra=None) -> np.ndarray:
    """Unit-RMS noise shaped zero-phase by Butterworth magnitudes (and optional extra(f))."""
    n = nsamp(dur)
    m = nsamp(0.02)
    x = r.standard_normal(n + 2 * m)
    nf = _nfft(len(x))
    f = np.fft.rfftfreq(nf, 1.0 / SR)
    h = np.ones_like(f)
    if lo:
        h *= hpg(f, lo, order)
    if hi:
        h *= lpg(f, hi, order)
    if extra is not None:
        h *= extra(f)
    y = np.fft.irfft(np.fft.rfft(x, nf) * h, nf)[m:m + n]
    return y / (np.std(y) + 1e-12)


def hump(n: int, peak_at: float = 0.5, power: float = 1.0) -> np.ndarray:
    """Smooth 0 -> 1 -> 0 envelope over n samples with its maximum at `peak_at` (0..1)."""
    u = np.linspace(0.0, 1.0, n)
    a = max(peak_at, 1e-3)
    b = max(1.0 - peak_at, 1e-3)
    e = (u / a) ** (a * 4) * ((1 - u) / b) ** (b * 4)
    return (e / (e.max() + 1e-12)) ** power


def events(r: np.random.Generator, dur: float, rate) -> np.ndarray:
    """Poisson event times; rate is events/s, scalar or vectorized callable (thinning)."""
    if not callable(rate):
        return np.sort(r.uniform(0.0, dur, r.poisson(max(rate, 0.0) * dur)))
    rmax = float(np.max(rate(np.linspace(0.0, dur, 512)))) * 1.02 + 1e-9
    k = r.poisson(rmax * dur)
    t = np.sort(r.uniform(0.0, dur, k))
    return t[r.uniform(0.0, rmax, k) < rate(t)]


def crackle(r: np.random.Generator, dur: float, rate, click_ms=(0.1, 0.3), amp=None,
            skew: float = 2.0, rise: bool = False) -> np.ndarray:
    """Sparse clicks: each a sharp-edged decaying noise burst of click_ms length.
    rise=True gives every click a 2-3 sample linear rise instead of a one-sample step."""
    n = nsamp(dur)
    y = np.zeros(n + nsamp(max(click_ms) * 1e-3) + 4)
    for t in events(r, dur, rate):
        ln = max(int(round(r.uniform(*click_ms) * 1e-3 * SR)), 1)
        k = np.arange(ln)
        c = r.standard_normal(ln) * np.exp(-k / max(ln / 3.0, 0.5))
        c[0] = (1.0 if c[0] >= 0 else -1.0) * max(abs(c[0]), 1.5)
        if rise:
            c *= np.minimum((k + 1) / float(r.integers(2, 4)), 1.0)
        a = r.uniform(0.1, 1.0) ** skew * (float(amp(t)) if amp else 1.0)
        i = int(t * SR)
        y[i:i + ln] += a * c
    return y[:n]


def grains(r: np.random.Generator, dur: float, rate, f_range, len_ms, amp=None,
           skew: float = 1.5) -> np.ndarray:
    """Granular stream: each grain a short exponentially decaying sine at a random frequency."""
    n = nsamp(dur)
    y = np.zeros(n + nsamp(max(len_ms) * 1e-3) + 4)
    for t in events(r, dur, rate):
        ln = max(int(round(r.uniform(*len_ms) * 1e-3 * SR)), 3)
        k = np.arange(ln)
        f = r.uniform(*f_range)
        g = np.sin(2 * np.pi * f * (k + 0.5) / SR) * np.exp(-k / (ln / 3.0))
        a = r.uniform(0.2, 1.0) ** skew * (float(amp(t)) if amp else 1.0)
        i = int(t * SR)
        y[i:i + ln] += a * g
    return y[:n]


def crumple(r: np.random.Generator, dur: float, lo: float = 2000.0, hi: float = 7000.0) -> np.ndarray:
    """Paper crumple: 4-7 dense crackle clusters of 5-20 ms, bandpassed lo..hi."""
    n = nsamp(dur)
    y = np.zeros(n)
    for _ in range(int(r.integers(4, 8))):
        ln = r.uniform(0.005, 0.02)
        c = crackle(r, ln, r.uniform(4000, 10000), click_ms=(0.02, 0.15), skew=1.5)
        place(y, c * ar_env(len(c), 0.001, ln / 2.5) * r.uniform(0.35, 1.0), r.uniform(0.0, dur * 0.8))
    return bp(y, lo, hi, 4) * hump(n, 0.3, 0.5)


def hit(freqs, taus, amps, contact: float = 0.0002, dur: float | None = None,
        r: np.random.Generator | None = None) -> np.ndarray:
    """Modal body struck by a half-sine contact pulse (shorter pulse = harder, brighter).
    With r, every mode gets a random start phase (no two strikes share a waveform)."""
    keep = [i for i, f in enumerate(freqs) if f < 0.45 * SR]
    fs = [freqs[i] for i in keep]
    ts = [taus[i] for i in keep]
    am = [amps[i] for i in keep]
    dur = dur if dur is not None else min(8.0 * max(ts) + contact + 0.005, 2.0)
    ex = mallet(contact)
    return fftconvolve(ex / ex.sum(), modal_ir(fs, ts, am, dur, r))[:nsamp(dur)]


STEEL_TOP = 14000.0   # highest steel mode (Hz): keeps small parts from turning brittle


def steel_modes(r: np.random.Generator, f0: float, n: int | None = None, span: float = 6.0):
    """Inharmonic steel-part modes: f0 plus log-uniform partials up to span*f0 (capped at
    STEEL_TOP) that avoid integer ratios (+-3 %) and each other (+-4 %). Amplitudes are
    uniform 0.3-1.0 (not falling), and each mode gets a doublet partner detuned
    +0.3..1.2 % at 0.5-1.0 of its amplitude (a real part is never perfectly symmetric).
    Returns (freqs, amps, ratios), doublets included."""
    n = n or int(r.integers(8, 13))
    top = max(min(span, STEEL_TOP / f0), 1.6)
    q = [1.0]
    for _ in range(4000):
        if len(q) >= n:
            break
        x = float(np.exp(r.uniform(np.log(1.08), np.log(top))))
        if abs(x / round(x) - 1.0) < 0.03 or any(abs(x / p - 1.0) < 0.04 for p in q):
            continue
        q.append(x)
    freqs, amps, ratios = [], [], []
    for x in sorted(q):
        a = r.uniform(0.3, 1.0)
        freqs += [f0 * x, f0 * x * (1.0 + r.uniform(0.003, 0.012))]
        amps += [a, a * r.uniform(0.5, 1.0)]
        ratios += [x, x]
    return freqs, amps, ratios


def steel_taus(r: np.random.Generator, ratios, tau0: float, jit: float = 0.25) -> list:
    """tau0 for f0, upper modes scaled by (f0/f)^0.5, each jittered +-jit."""
    return [tau0 * x ** -0.5 * r.uniform(1.0 - jit, 1.0 + jit) for x in ratios]


def contact_burst(r: np.random.Generator, lo: float = 2000.0, hi: float = 12000.0,
                  length: float = 0.0005) -> np.ndarray:
    """The metal-on-metal contact itself: a 0.5 ms band of noise (lo..hi, the top edge
    4th order so it does not hiss above it) with a 2-sample rise."""
    x = colored(r, length, lo, hi, 2)
    k = np.arange(len(x))
    w = np.minimum((k + 1) / 3.0, 1.0) * np.exp(-k / max(len(x) / 3.0, 1.0))
    x = x * w
    x -= w * x.sum() / w.sum()                  # a 0.5 ms scrap of noise has a random DC: remove it
    return lp(np.concatenate([x, np.zeros(nsamp(0.001))]), hi, 2)


def balance_ring(freqs, amps, taus, contact: float, cap: float = 0.33, t0: float = 0.015) -> list:
    """Keep one mode from carrying the ring. The late ring (from t0 after the strike to
    where it has died, Hann-weighted as a listener's ear integrates it) is shared out per
    line (modes within +-1.5 %, i.e. a mode and its doublet); any line holding more than
    `cap` of it is turned down to `cap`. The contact pulse's own spectrum is included."""
    fr = np.asarray(freqs, float)
    a = np.asarray(amps, float).copy()
    ta = np.asarray(taus, float)
    ex = mallet(contact)
    mag = np.abs((np.exp(-2j * np.pi * np.outer(fr, np.arange(len(ex))) / SR) * ex[None, :]).sum(1)) / ex.sum()
    length = 6.3 * ta.max()
    tt = t0 + np.linspace(0.0, length, 400)
    w = np.sin(np.pi * (tt - t0) / length) ** 2
    e = (np.exp(-2.0 * tt[None, :] / ta[:, None]) * w[None, :]).sum(1) * mag ** 2   # per mode, per unit amp^2
    line = np.array([np.nonzero(np.abs(fr / f - 1.0) < 0.015)[0].min() for f in fr])
    for _ in range(12):
        en = a ** 2 * e
        shares = {g: en[line == g].sum() / en.sum() for g in set(line.tolist())}
        g, s = max(shares.items(), key=lambda kv: kv[1])
        if s <= cap + 1e-3:
            break
        a[line == g] *= np.sqrt(cap * (1.0 - s) / (s * (1.0 - cap)))   # its share becomes cap
    return list(a)


def steel(r: np.random.Generator, f0: float, tau0: float, contact: float, n: int | None = None,
          span: float = 6.0, burst_db: float = -4.0, burst=(2000.0, 12000.0), modes=None) -> np.ndarray:
    """A struck steel part: steel_modes (random phases; ring balanced so that no single
    mode rings on alone) + a contact burst at burst_db.
    `modes` = (freqs, amps, ratios) re-uses a mode set (the same part struck again)."""
    fr, am, q = modes if modes is not None else steel_modes(r, f0, n, span)
    keep = [i for i, f in enumerate(fr) if f < 0.45 * SR]
    fr, am, q = [fr[i] for i in keep], [am[i] for i in keep], [q[i] for i in keep]
    ta = steel_taus(r, q, tau0)
    m = ring(r, fr, ta, balance_ring(fr, am, ta, contact), contact)
    return mix(lv(m), lv(contact_burst(r, *burst), burst_db))


def ring(r: np.random.Generator, freqs, taus, amps, contact: float, cap: float = 0.3,
         t0: float = 0.015) -> np.ndarray:
    """hit() whose late ring is checked the way it is heard: the spectrum from t0 after the
    strike to where the ring has died (-55 dB), Hann-weighted. While one line (a mode and
    its doublet, +-1.5 %) holds more than `cap` of the energy above 300 Hz, that line is
    turned down and the strike re-rendered (same phases)."""
    fr = np.asarray(freqs, float)
    a = np.asarray(amps, float).copy()
    line = np.array([np.nonzero(np.abs(fr / f - 1.0) < 0.015)[0].min() for f in fr])
    state = r.bit_generator.state
    for _ in range(8):
        r.bit_generator.state = state                   # identical phases on every pass
        m = hit(list(fr), list(taus), list(a), contact=contact, r=r)
        pk = np.max(np.abs(m))
        end = int(np.nonzero(np.abs(m) > pk * db2lin(-55.0))[0][-1])
        seg = m[nsamp(t0):end]
        if len(seg) < nsamp(0.01):
            break
        S = np.abs(np.fft.rfft(seg * np.hanning(len(seg)), 1 << 15)) ** 2
        f = np.fft.rfftfreq(1 << 15, 1.0 / SR)
        tot = S[f > 300].sum()
        shares = {g: S[np.abs(f / fr[g] - 1.0) < 0.015].sum() / tot for g in set(line.tolist())}
        g, s = max(shares.items(), key=lambda kv: kv[1])
        if s <= cap:
            break
        a[line == g] *= np.sqrt(cap * (1.0 - s) / (s * (1.0 - cap))) * 0.95
    return m


def vslot(r: np.random.Generator, v: int, nv: int, pct: float) -> float:
    """Stratified per-variant factor in 1 +- pct: the range is cut into nv slots and variant
    v draws from slot v, so two variants of one sound can never land on the same pitch."""
    if nv <= 1:
        return r.uniform(1.0 - pct, 1.0 + pct)
    w = 2.0 * pct / nv
    return 1.0 - pct + w * (v % nv + r.uniform(0.25, 0.75))


def knock(r: np.random.Generator, freqs, ms, amps, contact: float, g: float = 1.0,
          pct: float = 0.05, noise_db: float = -4.0) -> np.ndarray:
    """Wood/leather knock: modal hit with every mode detuned by g * (1 +- pct), random
    phases, contact width randomized +-50 %, plus the damped, noisy part of the blow (a
    band of noise around the modes with the fundamental's decay) at noise_db RMS re the
    modes: stocks, bodies and belts are not bells."""
    c = contact * r.uniform(0.5, 1.5)
    fs = [f * g * r.uniform(1.0 - pct, 1.0 + pct) for f in freqs]
    m = hit(fs, [dtau(x) for x in ms], amps, contact=c, r=r)
    nb = colored(r, len(m) / SR, 0.7 * min(fs), 3.0 * max(fs), 2) * ar_env(len(m), c, dtau(ms[0]))
    return m + nb * db2lin(noise_db) * np.sqrt(np.mean(m ** 2) / np.mean(nb ** 2))


def nwave(length: float, pos_frac: float) -> np.ndarray:
    """Asymmetric N-wave: instant jump to +1 and linear fall over the positive phase,
    then a longer, shallower (half-sine) negative phase with equal area (no DC)."""
    ln = max(nsamp(length), 4)
    lp_ = max(int(ln * pos_frac), 2)
    ln_ = ln - lp_
    pos = 1.0 - np.arange(lp_) / lp_
    neg = -(lp_ * np.pi / (4.0 * ln_)) * np.sin(np.pi * (np.arange(ln_) + 0.5) / ln_)
    return np.concatenate([pos, neg])


def rasp(r: np.random.Generator, n: int, rate0: float, rate1: float, depth: float = 0.7,
         sharp: float = 2.0) -> np.ndarray:
    """Stick-slip amplitude modulation whose rate glides rate0 -> rate1 (Hz), jittered."""
    t = taxis(n)
    rate = rate0 * (rate1 / rate0) ** (t / max(t[-1], 1e-6)) * (1.0 + 0.15 * smooth_noise(n, 15, r))
    cyc = (0.5 + 0.5 * np.cos(2 * np.pi * np.cumsum(rate) / SR)) ** sharp
    a = 0.6 + 0.4 * np.abs(smooth_noise(n, max(rate1, 5.0), r))
    return (1.0 - depth) + depth * cyc * a


def swish(r: np.random.Generator, dur: float, f0: float, f1: float, width_oct: float = 0.6,
          peak_at: float = 0.6) -> np.ndarray:
    """Noise through a band (Gaussian in octaves) whose centre sweeps f0 -> f1."""
    x = colored(r, dur, 150, 12000)

    def g(t, f):
        fc = f0 * (f1 / f0) ** np.clip(t / dur, 0.0, 1.0)
        return np.exp(-0.5 * (np.log2(np.maximum(f, 1.0) / fc) / width_oct) ** 2)
    return tv_filter(x, g, frame=512, hop=128) * hump(len(x), peak_at)


def creak(r: np.random.Generator, dur: float, clusters: int, res, rate=(60.0, 150.0),
          continuous: bool = False) -> np.ndarray:
    """Leather stick-slip: impulse clusters through a parallel resonator bank [(f, Q, gain)]."""
    n = nsamp(dur)
    imp = np.zeros(n)
    if continuous:
        rt0 = r.uniform(*rate)
        imp += stick_slip_train(dur, lambda t: rt0 * (0.7 + 0.6 * np.sin(np.pi * t / dur)), r, jitter=0.3,
                                amp=lambda t: max(np.sin(np.pi * min(t / dur, 1.0)), 0.0) ** 0.7,
                                amp_jitter=0.5)
    for _ in range(clusters):
        ln = r.uniform(0.02, 0.05)
        rt = r.uniform(*rate)
        c = stick_slip_train(ln, rt, r, jitter=0.3, amp=lambda t, ln=ln: np.sin(np.pi * min(t / ln, 1.0)),
                             amp_jitter=0.5)
        place(imp, c * r.uniform(0.5, 1.0), r.uniform(0.0, max(dur - ln, 0.0)))
    y = sum(reson(imp, f, q) * a for f, q, a in res)
    return y + 0.08 * hp(imp, 2000, 2)


def steady(x: np.ndarray, win: float = 0.004) -> np.ndarray:
    """Divide noise by its own short-term RMS: the same band, but a flat envelope, so an
    enveloped layer never throws a random loud millisecond (peak-normalized levels of
    such a layer then mean what they say)."""
    k = max(nsamp(win), 1)
    e = np.sqrt(np.convolve(x ** 2, np.ones(k) / k, "same")) + 1e-9
    return x / e


def contact_noise(r: np.random.Generator, dur: float, lo, hi, attack: float, tau: float) -> np.ndarray:
    """A short enveloped band of noise (palm slap, thumb tick, tooth click...)."""
    x = colored(r, dur, lo, hi)
    return x * ar_env(len(x), attack, tau) * hump(len(x), 0.02, 0.25)


def pad_to(x: np.ndarray, n: int, t: float = 0.0) -> np.ndarray:
    """x placed at time t in n samples of silence."""
    y = np.zeros(n)
    place(y, x, t)
    return y


def mix(*xs) -> np.ndarray:
    """Sum mono layers of different lengths (zero-padded to the longest)."""
    y = np.zeros(max(len(x) for x in xs))
    for x in xs:
        y[:len(x)] += x
    return y


def finish(x: np.ndarray, max_s: float | None = None, fade: float = 0.01, thresh: float = -55.0,
           lead: bool = True, hp_hz: float = 20.0, pad: float = 0.002) -> np.ndarray:
    """Trim silence (thresh dB below peak, keeping `pad` s before the onset), cap the
    length, fade out, peak -1 dBFS."""
    x = trim(np.asarray(x, dtype=float), thresh, lead=lead, tail=True, pad=pad)
    if max_s is not None and len(x) > nsamp(max_s):
        x = x[:nsamp(max_s)]
    return peak_norm(dc_trim(finalize(x, -1.0, fade=fade, lead_trim=lead, thresh_db=thresh, hp=hp_hz)), db2lin(-1.0))


def dc_trim(x: np.ndarray) -> np.ndarray:
    """Remove the residual mean of a short sound (a decaying mode integrates to about
    a/omega, which a 20 Hz highpass cannot take out in 80 ms) by subtracting a scaled copy
    of the sound's own smooth envelope: no step, and nothing where the sound is silent."""
    e = np.sqrt(np.convolve(x ** 2, np.ones(nsamp(0.005)) / nsamp(0.005), "same"))
    return x - e * x.mean() / (e.mean() + 1e-12)


def st_rms_peak(x: np.ndarray, win: float = 0.05) -> float:
    """Maximum short-term RMS (win seconds), channels averaged."""
    p = x ** 2 if x.ndim == 1 else np.mean(x ** 2, axis=1)
    k = max(nsamp(win), 1)
    cs = np.concatenate([[0.0], np.cumsum(p)])
    return float(np.sqrt(np.max((cs[k:] - cs[:-k]) / k))) if len(p) > k else float(np.sqrt(np.mean(p)))


# --------------------------------------------------------------------------- locks

def lock_fall(r: np.random.Generator, pistol: bool) -> np.ndarray:
    """Sear tick, flint scrape + sparks, frizzen thrown open, cock on its stop + stock knock."""
    mf, df = (1.3, 0.7) if pistol else (1.0, 1.0)
    y = np.zeros(nsamp(0.25))
    jit = lambda: r.uniform(-0.003, 0.003)  # noqa: E731
    t_scr = max(0.004 + jit(), 0.0015)
    scr_len = r.uniform(0.010, 0.018) if pistol else r.uniform(0.012, 0.025)
    t_friz = max(0.012 + jit(), t_scr + 0.005)
    t_cock = max(0.018 + jit(), t_friz + 0.003)

    # sear release: 1 ms click, 3-6 kHz, -14 dB
    tick = colored(r, 0.001, 3000, 6000, 4) * ar_env(nsamp(0.001), 0.0001, 0.0003)
    place(y, lv(tick, -14), 0.0005)

    # flint scraping down the frizzen face (0 dB): highpassed noise peaking at 5-8 kHz,
    # sagging 30 % across the stroke, then an 8-10 ms release as the flint leaves the face
    if pistol:
        lo, pk, hi = 3000.0, r.uniform(5000, 7500), 10000.0
    else:
        lo, pk, hi = 2500.0, r.uniform(4500, 7000), 10000.0
    rel = r.uniform(0.008, 0.010)
    s = colored(r, scr_len + rel, lo, hi, 4,
                extra=lambda f: 1.0 + 2.5 * np.exp(-0.5 * (np.log2(np.maximum(f, 1.0) / pk) / 0.5) ** 2))
    t = taxis(len(s))
    env = np.minimum(t / 0.0008, 1.0) * (1.0 - 0.30 * np.minimum(t / scr_len, 1.0))
    env *= np.clip(1.0 - (t - scr_len) / rel, 0.0, 1.0) ** 1.5
    s *= env * (1.0 + 0.5 * smooth_noise(len(s), 900, r))
    place(y, lv(s, 0.0), t_scr)
    # spark crackle on top: 0.1-0.3 ms clicks at 1000-2000/s with soft 2-3 sample edges,
    # lowpassed 12 kHz, thinning out after the scrape
    rate = r.uniform(1000, 2000)
    sp = crackle(r, scr_len * 1.4,
                 lambda tt: rate * np.where(tt < scr_len, 1.0, np.exp(-(tt - scr_len) / 0.004)), rise=True)
    place(y, lv(bp(sp, 2000, 12000, 2), -2.0), t_scr + 0.0005)

    # frizzen thrown open against its spring: inharmonic steel from ~1.9 kHz, 12-25 ms decays
    fz = steel(r, det(r, 1900 * mf, 0.04), dtau(25 * df), contact=0.00012)
    place(y, lv(fz, -3.0), t_friz)

    # cock hits its stop (0 dB, the 'CLACK'): steel thunk from ~720 Hz + its contact burst,
    # then the wooden stock knock
    ck = steel(r, det(r, 720 * mf, 0.05), dtau(18 * df), contact=0.0003)
    place(y, lv(ck, 0.0), t_cock)
    place(y, lv(contact_burst(r, 2000.0, 10000.0), -3.0), t_cock)
    kf, kdb = ((320, 400, 490), -12.0) if pistol else ((185, 250, 315), -8.0)
    kn = hit([det(r, f, 0.04) for f in kf], [dtau(30 * df), dtau(24 * df), dtau(18 * df)],
             [1.0, 0.7, 0.5], contact=0.001, r=r)
    place(y, lv(kn, kdb), t_cock + 0.0004)
    return finish(y, max_s=0.09 if pistol else 0.11, fade=0.008, thresh=-50.0)


def dry_fire(r: np.random.Generator, v: int = 0, nv: int = 3) -> np.ndarray:
    y = np.zeros(nsamp(0.2))
    t_slip = max(0.004 + r.uniform(-0.002, 0.002), 0.0015)
    slip_len = r.uniform(0.004, 0.010)
    t_clack = t_slip + slip_len + r.uniform(0.002, 0.005)

    tick = colored(r, 0.001, 3000, 6000, 4) * ar_env(nsamp(0.001), 0.0001, 0.0003)
    place(y, lv(tick, -12.0), 0.0005)
    pk = r.uniform(5000, 8000)
    s = colored(r, slip_len, 2500, 11000, 4,
                extra=lambda f: 1.0 + 2.0 * np.exp(-0.5 * (np.log2(np.maximum(f, 1.0) / pk) / 0.5) ** 2))
    t = taxis(len(s))
    s *= np.minimum(t / 0.0005, 1.0) * np.clip((slip_len - t) / 0.002, 0.0, 1.0)
    place(y, lv(s, -8.0), t_slip)
    for tt in r.uniform(0.0, slip_len, int(r.integers(0, 4))):   # 0-3 stray sparks
        k = np.arange(int(r.integers(5, 14)))                     # 0.1-0.3 ms, soft 2-3 sample edge
        sp = r.standard_normal(len(k)) * np.exp(-k / (len(k) / 3.0)) * np.minimum((k + 1) / r.uniform(2, 3), 1)
        place(y, lv(bp(np.concatenate([sp, np.zeros(64)]), 2000, 12000, 2), r.uniform(-16.0, -10.0)),
              t_slip + tt)

    # the dry clack (0 dB): cock on its stop, inharmonic steel from 850-1600 Hz (the variant
    # picks its own slot of that range), 20 ms decay, contact 0.08-0.25 ms
    f0 = 850.0 * (1600.0 / 850.0) ** ((v % nv + r.uniform(0.1, 0.9)) / nv)
    ck = steel(r, f0, dtau(20), contact=r.uniform(0.00008, 0.00025))
    place(y, lv(ck, 0.0), t_clack)
    place(y, lv(contact_burst(r, 2000.0, 8000.0), -3.0), t_clack)
    # the dull body of the clack (cock and lock plate), 0.7-1.5 kHz, 4 ms: no ring, just weight
    cb = colored(r, 0.03, 700, 1500, 2) * ar_env(nsamp(0.03), 0.0002, 0.004)
    place(y, lv(cb, -6.0), t_clack)
    # hollow stock knock, 220 Hz, -8..-11 dB
    kn = hit([det(r, 220, 0.06), det(r, 470, 0.06)], [dtau(20), dtau(12)], [1.0, 0.35], contact=0.0008, r=r)
    place(y, lv(kn, r.uniform(-11.0, -8.0)), t_clack + 0.0003)
    return finish(y, max_s=0.1, fade=0.008)


# --------------------------------------------------------------------------- pan flash

def pan_flash(r: np.random.Generator) -> np.ndarray:
    dur = 0.34
    y = np.zeros(nsamp(dur + 0.02))
    # ignition attack: 300 Hz - 11 kHz noise, 1 ms rise, then 2-3 ms of decay
    a_len = r.uniform(0.002, 0.003)
    att = colored(r, a_len + 0.001, 300, 11000, 2)
    ta = taxis(len(att))
    att *= np.minimum(ta / 0.001, 1.0) * np.exp(-np.maximum(ta - 0.001, 0.0) / (a_len / 2.5))
    att = lp(np.concatenate([att, np.zeros(nsamp(0.002))]), 11000, 2)   # top edge 4th order: no tick
    place(y, lv(att, 0.0), 0.0005)
    # body: 1-7 kHz noise, tau ~60 ms, lowpass sweeping 9 -> 3 kHz across the tail
    tau = 0.060 * r.uniform(0.9, 1.1)
    body = colored(r, dur, 1000, 7000, 4) * ar_env(nsamp(dur), 0.002, tau)
    body = tv_filter(body, lambda t, f: lpg(f, 9000.0 * (3000.0 / 9000.0) ** np.clip((t - 0.01) / 0.24, 0, 1), 4))
    place(y, lv(body, -1.0), 0.0015)
    # crackle of grain pops: 400 -> 150 per second, decaying, 2-5 kHz
    cr = crackle(r, 0.27, lambda t: 150.0 + 250.0 * np.exp(-t / 0.07), click_ms=(0.1, 0.6),
                 amp=lambda t: np.exp(-t / 0.09), skew=1.5)
    place(y, lv(bp(cr, 2000, 5000, 4), -5.0), 0.003)
    # small low puff at onset: noise < 250 Hz, 40 ms, -12 dB
    pf = colored(r, 0.04, None, 250, 4)
    pf *= ar_env(len(pf), 0.003, 0.012) * hump(len(pf), 0.05, 0.3)
    place(y, lv(pf, -12.0), 0.0005)
    return finish(y, max_s=0.28, fade=0.03, thresh=-55.0)


# --------------------------------------------------------------------------- shots

def tanh_os(x: np.ndarray, os_: int = 4) -> np.ndarray:
    """tanh at os_-times oversampling (FFT zero-pad up, tanh, brickwall back down), so the
    harmonics it creates above Nyquist are removed instead of aliasing."""
    n = len(x)
    nf = _nfft(n + 64)
    up = np.fft.irfft(np.fft.rfft(x, nf), nf * os_) * os_
    Y = np.fft.rfft(np.tanh(up))[:nf // 2 + 1] / os_
    return np.fft.irfft(Y, nf)[:n]


def pressure_pulse(pos: float, neg: float, fc: float, b: float = 1.5) -> np.ndarray:
    """Muzzle pressure pulse: a Friedlander positive phase of `pos` s (0.2 ms rise, then
    (1-u)*exp(-b*u) back to zero, like a blast wave's steep front), then a negative half-sine
    lobe of `neg` s with equal area (no DC); lowpassed at fc."""
    a, m = max(nsamp(pos), 2), max(nsamp(neg), 2)
    u = (np.arange(a) + 0.5) / a
    p = (1.0 - u) * np.exp(-b * u) * np.minimum((np.arange(a) + 1) / max(nsamp(0.0002), 1), 1.0)
    q = np.sin(np.pi * (np.arange(m) + 0.5) / m)
    return lp(np.concatenate([p, -q * p.sum() / q.sum(), np.zeros(nsamp(0.02))]), fc, 2)


def loudest_ms(y: np.ndarray, pad: float = 0.0006) -> float:
    """Centre (s) of the loudest 1 ms RMS window, counted from `pad` s before the onset
    (first sample above -50 dB): where it lands in a file lead-trimmed with that pad."""
    k = nsamp(0.001)
    cs = np.concatenate([[0.0], np.cumsum(y ** 2)])
    e = (cs[k:] - cs[:-k]) / k
    on = int(np.argmax(np.abs(y) > np.max(np.abs(y)) * db2lin(-50.0)))
    return (int(np.argmax(e)) - on + k / 2) / SR + pad


def peak_at(y: np.ndarray, pad: float = 0.0006) -> float:
    """Time (s) of the peak sample, counted like loudest_ms."""
    on = int(np.argmax(np.abs(y) > np.max(np.abs(y)) * db2lin(-50.0)))
    return (int(np.argmax(np.abs(y))) - on) / SR + pad


# Shot recipes. Levels are peaks in dB re the pressure pulse as it ends up in the file
# (after the final highpass); decays are exponential time constants (s).
SHOTS = {
    "musket": dict(dur=1.6, pulse_pos=(0.004, 0.006), pulse_neg=(0.008, 0.012), pulse_fc=1200.0, pulse_b=3.0, pulse_hp=55.0,
                   crack_len=(0.002, 0.003), blast_band=(250.0, 3000.0), blast_tau=0.040, blast_fast=0.007,
                   drive=3.0, body_f=(70.0, 45.0, 0.15), body_tau=0.080, boom_band=(70.0, 350.0),
                   boom_tau=0.120, boom_att=0.0015, ab_band=(50.0, 800.0), ab_tau=0.350, hp=35.0,
                   c_db=3.0, b_db=-3.0, body_db=-13.0, boom_db=-2.0, ab_db=-9.0, sat=1.2),
    "pistol": dict(dur=1.0, pulse_pos=(0.002, 0.003), pulse_neg=(0.004, 0.006), pulse_fc=2000.0, pulse_b=3.0, pulse_hp=70.0,
                   crack_len=(0.00072, 0.00088), blast_band=(500.0, 5000.0), blast_tau=0.018, blast_fast=0.005,
                   drive=4.0, body_f=(120.0, 80.0, 0.05), body_tau=0.035, boom_band=(120.0, 600.0),
                   boom_tau=0.050, boom_att=0.001, ab_band=(60.0, 1200.0), ab_tau=0.160, hp=40.0,
                   c_db=6.0, b_db=-2.0, body_db=-10.0, boom_db=-3.0, ab_db=-10.0, sat=1.2),
}


def gun_shot(r: np.random.Generator, pistol: bool) -> np.ndarray:
    """Dry muzzle blast (before finishing), peak 1. The first pressure peak is the loudest
    1 ms of the file: if the random layers ever bury it, the crack is raised until it is."""
    P = SHOTS["pistol" if pistol else "musket"]
    dur = P["dur"]
    n = nsamp(dur)
    t = taxis(n)
    t0 = 0.001
    d = (lambda: 1.0) if pistol else (lambda: r.uniform(0.85, 1.15))  # decays +-15 % (musket)
    pf = r.uniform(0.92, 1.08)                                        # body pitch +-8 %
    fhp = (lambda x: hp(x, P["hp"], 4))                               # the final highpass

    # (b) muzzle pressure pulse, the main event (0 dB): musket 4-6 ms Friedlander positive
    # phase and an 8-12 ms negative lobe lowpassed 1.2 kHz; pistol 2-3 ms / 4-6 ms at 2 kHz
    p_pos, p_neg = r.uniform(*P["pulse_pos"]), r.uniform(*P["pulse_neg"])
    pp = hp(pressure_pulse(p_pos, p_neg, P["pulse_fc"], P["pulse_b"]), P["pulse_hp"], 2)   # no sub-40 Hz ballast

    # (a) crack: the shock front riding on that pulse, broadband to 15 kHz. An asymmetric
    # N-wave whose positive phase (0.24-0.8 ms linear fall) sits on the front of the pulse
    # and whose equal-area negative phase is stretched shallow over the whole pulse, so it
    # adds to the pulse's peak instead of cancelling it.
    c_pos = r.uniform(*P["crack_len"]) * r.uniform(0.3, 0.4)
    ln = c_pos + p_pos + p_neg
    crack = lp(np.concatenate([nwave(ln, c_pos / ln), np.zeros(nsamp(0.005))]), 15000, 4)

    # (c) blast / bark: the carrier is saturated (tanh at 4x), then enveloped with a fast
    # and a slower tau_b decay, so the bark falls away instead of sitting on a plateau
    bw = r.uniform(0.9, 1.1) if pistol else 1.0
    lo, hi = P["blast_band"][0] * bw, P["blast_band"][1] * bw
    tau_b = P["blast_tau"] * d()
    bl_len = tau_b * 9
    tb = taxis(nsamp(bl_len))
    carrier = tanh_os(P["drive"] * 0.5 * colored(r, bl_len, lo, hi, 2))
    blast = carrier * (0.65 * np.exp(-tb / P["blast_fast"]) + 0.35 * np.exp(-tb / tau_b)) * np.minimum(tb / 0.001, 1.0)

    # (d) body: falling sine (random start phase, 2 % FM, end pitch >= 50 Hz) plus a band of
    # 'boom' noise that fills the octaves above it
    fa, fb, ft = P["body_f"]
    f = np.maximum(fa * pf * (fb / fa) ** (np.minimum(t, ft) / ft), 50.0)
    fm = 1.0 + 0.02 * smooth_noise(n, 30.0, r)
    body = np.sin(r.uniform(0.0, 2 * np.pi) + 2 * np.pi * np.cumsum(f * fm) / SR) * ar_env(n, 0.002, P["body_tau"] * d())
    boom = steady(colored(r, dur, *P["boom_band"], 2)) * ar_env(n, P["boom_att"], P["boom_tau"] * d())

    # (e) powder after-burn 'whoomph'
    ab = colored(r, dur, *P["ab_band"], 2) * ar_env(n, 0.020 if not pistol else 0.010, P["ab_tau"] * d())

    # the final highpass takes some of the pulse's peak away; pre-scale it so every layer
    # sits at its stated level in the finished (highpassed) shot
    pp = pp / np.max(np.abs(fhp(pp)))
    body = body / np.max(np.abs(fhp(body[:nsamp(0.3)])))
    dly = 0.003 if pistol else r.uniform(0.004, 0.006)
    # If the random layers ever bury the report, first tuck everything but the report
    # under it for ~3-40 ms (a transient-shaper dip, down to -4 dB), then the pulse's own
    # tail (down to -3 dB), and only then raise the crack.
    tt = t - t0
    tuck = np.clip((tt - 0.0015) / 0.0015, 0.0, 1.0) * np.clip((0.040 - tt) / 0.028, 0.0, 1.0)
    tuck = 0.5 - 0.5 * np.cos(np.pi * tuck)
    rep_db, dip_db, pdip_db = 0.0, 0.0, 0.0
    for _ in range(60):
        crk = lv(crack, P["c_db"] + rep_db)
        bl = lv(blast, P["b_db"])
        rest = np.zeros(n)
        place(rest, bl, t0)
        place(rest, body * db2lin(P["body_db"]), t0)
        place(rest, lv(boom, P["boom_db"]), t0)
        place(rest, lv(ab, P["ab_db"]), t0)
        # (f) ground reflection of crack + blast: -6 dB, lowpassed 6 kHz
        place(rest, lp(mix(crk, bl), 6000, 2) * db2lin(-6.0), t0 + dly)
        y = rest * (1.0 - (1.0 - db2lin(dip_db)) * tuck)
        place(y, crk, t0)
        y += pad_to(pp, n, t0) * (1.0 - (1.0 - db2lin(pdip_db)) * tuck)
        y = peak_norm(y)
        y = tanh_os(P["sat"] * y) / np.tanh(P["sat"])
        y = peak_norm(fhp(y))
        if loudest_ms(y) <= 0.003 and peak_at(y) <= 0.003:   # report = loudest 1 ms and peak sample
            break
        if dip_db > -4.0:
            dip_db -= 0.5
        elif pdip_db > -3.0:              # then the pulse's own tail (its negative swing)
            pdip_db -= 0.5
        else:
            rep_db += 0.5
    gun_shot.dip_db, gun_shot.pdip_db = dip_db, pdip_db
    gun_shot.rep_db = rep_db
    return y


def musket_shot(r):
    x = finish(gun_shot(r, False), max_s=1.35, fade=0.15, thresh=-50.0, pad=0.0006, hp_hz=0.0)
    assert loudest_ms(x, 0.0) <= 0.003 and peak_at(x, 0.0) <= 0.003, "musket_shot: the report is not the loudest"
    return x


def pistol_shot(r):
    x = finish(gun_shot(r, True), max_s=0.85, fade=0.1, thresh=-50.0, pad=0.0006, hp_hz=0.0)
    assert loudest_ms(x, 0.0) <= 0.003 and peak_at(x, 0.0) <= 0.003, "pistol_shot: the report is not the loudest"
    return x


# --------------------------------------------------------------------------- tails

TAILS = {
    # diffuse_db / rumble_db: short-term RMS relative to the dry shot / to the wet reflections.
    # lf_cut: low shelf (dB at 150 Hz) on the diffuse IR so the rolling 'thunder' layer, not a
    # reverberated copy of the body, carries the lows. slap_db: forest slap levels re the
    # direct sound (of the dry shot's first ~20 ms, which is all a slap reflects audibly).
    "musket_tail": dict(src="musket", dur=4.0, tau=0.9, peak_t=0.20, sweep=(2500.0, 350.0), fort=False,
                        slap_lp=3000.0, slap_db=(-6.0, -8.0, -10.0, -12.0), diffuse_db=-18.0, lf_cut=6.0,
                        rumble_db=-16.0),
    "musket_tail_fort": dict(src="musket", dur=3.5, tau=0.9, peak_t=0.22, sweep=(2500.0, 350.0), fort=True,
                             er_lp=4000.0, flutter=0.5, flutter_db=-4.0, flutter_lp=0.9, diffuse_db=-27.0,
                             lf_cut=8.0, rumble_db=-26.0),
    "pistol_tail": dict(src="pistol", dur=2.6, tau=0.55, peak_t=0.18, sweep=(3200.0, 420.0), fort=False,
                        slap_lp=4500.0, slap_db=(-6.0, -8.0, -10.0, -12.0), diffuse_db=-17.0, lf_cut=10.0,
                        rumble_db=-22.0),
    "pistol_tail_fort": dict(src="pistol", dur=2.2, tau=0.5, peak_t=0.20, sweep=(3200.0, 420.0), fort=True,
                             er_lp=4500.0, flutter=0.35, flutter_db=-3.0, flutter_lp=0.9, diffuse_db=-27.0,
                             lf_cut=12.0, rumble_db=-30.0),
}
SLAP_T = (0.09, 0.17, 0.26, 0.38)       # tree line / fort slap times of the open-ground tails
TR_TAU = 0.02                           # transient window of the dry shot that feeds the slaps


def _tap(fc: float, hp_fc: float) -> np.ndarray:
    """One reflection: a unit impulse through a 2nd-order bandpass hp_fc..fc. The highpass
    keeps the body's low end out of the slaps, so an echo is a slap, not a second 'whum'."""
    k = np.zeros(nsamp(0.03))
    k[0] = 1.0
    return iir(k, _butter("hp", hp_fc, 2) + _butter("lp", fc, 2))


def _conv2(dry: np.ndarray, ir: np.ndarray, n: int) -> np.ndarray:
    return np.stack([fftconvolve(dry, ir[:, c])[:n] for c in range(2)], axis=1)


def lf_regularity(x: np.ndarray, a: float = 0.6, b: float = 3.0) -> float:
    """How periodic the low end's loudness is: the largest autocorrelation peak (lags
    0.2-1.5 s) of the detrended log 30 ms RMS envelope of the 20-150 Hz band (a..b s).
    Near 0 for a random roll, about 0.4 for the old three-sine tremolo."""
    m = x if x.ndim == 1 else x.mean(axis=1)
    nf = _nfft(len(m) + SR)
    f = np.fft.rfftfreq(nf, 1.0 / SR)
    lo = np.fft.irfft(np.fft.rfft(m, nf) * ((f >= 20) & (f < 150)), nf)[:len(m)]
    k, step = nsamp(0.03), 220
    e = np.sqrt(np.convolve(lo ** 2, np.ones(k) / k, "same"))[::step]
    t = np.arange(len(e)) * step / SR
    sel = (t > a) & (t < min(b, len(m) / SR - 0.3))
    y = np.log(e[sel] + 1e-9)
    y = y - np.polyval(np.polyfit(t[sel], y, 1), t[sel])
    ac = np.correlate(y, y, "full")[len(y) - 1:]
    ac = ac / (ac[0] + 1e-12)
    lags = np.arange(len(ac)) * step / SR
    pk = [ac[i] for i in range(1, len(ac) - 1) if ac[i] > ac[i - 1] and ac[i] > ac[i + 1] and 0.2 <= lags[i] <= 1.5]
    return max(pk, default=0.0)


def tail(r: np.random.Generator, p: dict) -> np.ndarray:
    dry = gun_shot(r, p["src"] == "pistol")
    n = nsamp(p["dur"])
    t = taxis(n)
    early = np.zeros((n, 2))                    # discrete reflections (fed the dry transient only)
    if p["fort"]:
        # dense wooden slap from the palisade: 20-110 ms, -6..-12 dB, bandpassed 120 Hz..~4 kHz
        kern = _tap(p["er_lp"], 120.0)
        for c in range(2):
            for tt in r.uniform(0.020, 0.110, int(r.integers(10, 17))):
                g = db2lin(r.uniform(-12.0, -6.0))
                place(early[:, c], kern, tt, g)
                for _ in range(2):              # log-by-log smear
                    place(early[:, c], kern, tt + r.uniform(0.0005, 0.003), g * db2lin(-r.uniform(6, 12)))
        early = peq(early, 700.0, 1.0, 3.0)     # a little woody body
        # flutter echo between opposite walls, ~95 ms apart, highpassed 300 Hz, gone after `flutter` s
        sp = 0.095 * r.uniform(0.97, 1.03)
        t_f = r.uniform(0.105, 0.12)
        loss = 24.0 * sp / p["flutter"]
        for k in range(int(p["flutter"] / sp) + 2):
            kern_k = _tap(p["er_lp"] * p.get("flutter_lp", 0.82) ** k, 300.0)
            for c in range(2):
                side = 1.5 if (k + c) % 2 == 0 else -1.5
                tt = t_f + k * sp + (0.0 if c == 0 else r.uniform(*p.get("flutter_lr", (0.0005, 0.002))))
                place(early[:, c], kern_k, tt, db2lin(p["flutter_db"] - k * loss + side + r.uniform(-1, 1)))
    else:
        # slap echoes from the tree line and the fort, bandpassed 200 Hz..slap_lp,
        # per-channel time/level for width
        kern = _tap(p["slap_lp"], 200.0)
        for c in range(2):
            for bt, bd in zip(SLAP_T, p["slap_db"]):
                tt = bt + r.uniform(-0.008, 0.008)
                g = db2lin(bd + r.uniform(-1.5, 1.5))
                place(early[:, c], kern, tt, g)
                for _ in range(2):              # scattering off trunks
                    place(early[:, c], kern, tt + r.uniform(0.001, 0.005), g * db2lin(-r.uniform(8, 14)))

    # diffuse tail: decorrelated noise, rises to peak_t, decays with tau, lowpass sweeping down
    ts, tp, te = 0.015, p["peak_t"], p["dur"] - 0.3
    env = np.where(t < tp, np.clip((t - ts) / (tp - ts), 0.0, 1.0) ** 1.5, np.exp(-(t - tp) / p["tau"]))
    dif = np.stack([colored(r, p["dur"], 30, None), colored(r, p["dur"], 30, None)], axis=1) * env[:, None]
    f0, f1 = p["sweep"]
    dif = tv_filter(dif, lambda tt, f: lpg(f, f0 * (f1 / f0) ** np.clip((tt - ts) / (te - ts), 0, 1), 2))
    if p["lf_cut"]:
        dif = iir(dif, [biquad_coeffs("lowshelf", 150.0, 0.7, -p["lf_cut"])])
    dif[t < ts] = 0.0
    wd = _conv2(dry, dif, n)
    gd = db2lin(p["diffuse_db"]) * st_rms_peak(dry) / (st_rms_peak(wd) + 1e-12)

    # reflections only (no direct path): the slaps and flutter reflect a 20 ms transient
    # window of the shot, so each is a short event; the diffuse bed gets the whole shot
    tr = dry * np.exp(-taxis(len(dry)) / TR_TAU)
    wet = _conv2(tr, early, n) + gd * wd

    # low rolling 'thunder', 45-180 Hz, 0.5 .. 3.2 s: aperiodic AM (random 1.5-3.5 Hz wander)
    # with 1-2 slow random swells, so it rolls rather than trembles
    rc = colored(r, p["dur"], 45, 180, 4)
    rum = np.stack([0.8 * rc + 0.45 * colored(r, p["dur"], 45, 180, 4),
                    0.8 * rc + 0.45 * colored(r, p["dur"], 45, 180, 4)], axis=1)
    a0, a1 = 0.5, min(3.2, p["dur"] - 0.3)
    win = np.clip((t - a0) / 0.4, 0, 1) * np.clip((a1 - t) / 0.6, 0, 1)
    win = (0.5 - 0.5 * np.cos(np.pi * win)) * np.exp(-np.maximum(t - a0, 0) / 1.6)
    best = None
    for _ in range(8):      # a random roll can still fall into a rhythm: keep the least regular draw
        am = 0.55 + 0.45 * smooth_noise(n, r.uniform(1.5, 3.5), r)
        for _ in range(int(r.integers(1, 3))):
            tc, w = r.uniform(0.6, min(2.5, p["dur"] - 0.5)), r.uniform(0.3, 0.6) / 2.355   # FWHM 0.3-0.6 s
            am *= 1.0 + (db2lin(r.uniform(4.0, 6.0)) - 1.0) * np.exp(-0.5 * ((t - tc) / w) ** 2)
        rm = rum * (am * win)[:, None]
        rm *= db2lin(p["rumble_db"]) * st_rms_peak(wet) / (st_rms_peak(rm) + 1e-12)
        out = wet + rm
        # keep the lows mono (side channel highpassed at 150 Hz) so a mono downmix cannot cancel them
        mid, side = 0.5 * (out[:, 0] + out[:, 1]), hp(0.5 * (out[:, 0] - out[:, 1]), 150.0, 2)
        out = finalize(np.stack([mid + side, mid - side], axis=1), -1.0, fade=0.3, lead_trim=False,
                       thresh_db=-80.0, hp=20.0)
        reg = lf_regularity(out)
        if best is None or reg < best[0]:
            best = (reg, out)
        if reg < 0.2:
            break
    return best[1]


# --------------------------------------------------------------------------- cock / frizzen

def cock_half(r):
    y = np.zeros(nsamp(0.32))
    fr_len = 0.060
    t_click = 0.002 + fr_len + r.uniform(0.0, 0.006)
    fr = colored(r, fr_len + 0.004, 1000, 3000, 2)
    tt = taxis(len(fr))
    fr *= np.clip(tt / fr_len, 0, 1) ** 2 * np.clip((fr_len + 0.004 - tt) / 0.004, 0, 1)
    fr *= 1.0 + 0.6 * smooth_noise(len(fr), 250, r)       # tumbler grit
    place(y, lv(fr, -18.0), 0.002)
    cl = steel(r, det(r, 2800, 0.05), dtau(20), contact=0.0001)
    place(y, lv(cl, 0.0), t_click)
    kn = hit([det(r, 250, 0.05), det(r, 575, 0.05)], [dtau(35), dtau(20)], [1.0, 0.3], contact=0.0008, r=r)
    place(y, lv(kn, -12.0), t_click + 0.0003)
    return finish(y, max_s=0.19, fade=0.015)


def cock_full(r):
    y = np.zeros(nsamp(0.32))
    g = colored(r, 0.062, 600, 1500, 2)
    g *= hump(len(g), 0.3, 0.6) * (1.0 + 0.5 * smooth_noise(len(g), 40, r))   # mainspring groan
    place(y, lv(g, -20.0), 0.0)
    tk = steel(r, det(r, 2900, 0.05), dtau(10), contact=0.00015)
    place(y, lv(tk, -10.0), 0.001)
    t_click = r.uniform(0.070, 0.110)
    cl = steel(r, det(r, 2500, 0.05), dtau(25), contact=0.00008)
    place(y, lv(cl, 0.0), t_click)
    return finish(y, max_s=0.22, fade=0.015)


def frizzen_open(r):
    y = np.zeros(nsamp(0.25))
    th = hit([det(r, 2600, 0.03), det(r, 4400, 0.03)], [dtau(8)] * 2, [1.0, 0.5], contact=0.0006, r=r)
    th = mix(lv(th), lv(contact_noise(r, 0.0015, 300, 3000, 0.0002, 0.0005), -4.0))
    place(y, lv(th, -10.0), 0.001)
    t_snap = r.uniform(0.018, 0.028)
    sn = steel(r, det(r, 2400, 0.05), dtau(35), contact=0.00008)
    place(y, lv(sn, 0.0), t_snap)
    kn = hit([det(r, 300, 0.05), det(r, 690, 0.05)], [dtau(30), dtau(18)], [1.0, 0.3], contact=0.0008, r=r)
    place(y, lv(kn, -14.0), t_snap + 0.0005)
    return finish(y, max_s=0.15, fade=0.012)


def frizzen_close(r):
    y = np.zeros(nsamp(0.28))
    f0 = det(r, 1800, 0.05)
    fr, am, q = steel_modes(r, f0)
    t1 = 0.002
    i1 = steel(r, f0, dtau(40), contact=0.00008, modes=(fr, am, q))
    place(y, lv(i1, 0.0), t1)
    # the frizzen slapping onto its spring a few ms later: the same steel, other weights
    sh = r.uniform(1.01, 1.04)
    i2 = steel(r, f0, dtau(36), contact=0.0001, modes=([f * sh for f in fr], [r.uniform(0.3, 1.0) for _ in am], q))
    t2 = t1 + r.uniform(0.006, 0.010)
    place(y, lv(i2, -2.0), t2)
    for tt in np.sort(r.uniform(0.020, 0.040, int(r.integers(2, 4)))):
        rt = steel(r, r.uniform(5000, 8000), dtau(6), contact=0.00005, n=int(r.integers(4, 7)), burst_db=-6.0)
        place(y, lv(rt, r.uniform(-16.0, -12.0)), tt)
    return finish(y, max_s=0.16, fade=0.015)


# --------------------------------------------------------------------------- cartridge

def cartridge_draw(r):
    y = np.zeros(nsamp(0.55))
    cr = creak(r, 0.15, 0, [(200.0, 4.0, 1.0), (450.0, 5.0, 0.8), (900.0, 6.0, 0.55)],
               rate=(60.0, 110.0), continuous=True)
    place(y, lv(cr, 0.0), 0.002)
    t_slap = r.uniform(0.17, 0.19)
    sl = colored(r, 0.02, 60, 1000, 2) * ar_env(nsamp(0.02), 0.0008, 0.005)
    place(y, lv(sl * hump(len(sl), 0.04, 0.3), -5.0), t_slap)
    t_slide = r.uniform(0.31, 0.34)
    ps = colored(r, 0.1, 2000, 8000, 2) * hump(nsamp(0.1), 0.35) * (1.0 + 0.4 * smooth_noise(nsamp(0.1), 120, r))
    place(y, lv(ps, -8.0), t_slide)
    return finish(y, max_s=0.46, fade=0.015)


def cartridge_bite(r, v):
    y = np.zeros(nsamp(0.45))
    tk = colored(r, 0.003, 1000, 3000, 2) * ar_env(nsamp(0.003), 0.0003, 0.0008)
    place(y, lv(tk, -6.0), 0.001)
    rips = (1, 2, 1, 2)[v % 4]
    total = r.uniform(0.08, 0.16)
    t_r = r.uniform(0.012, 0.025)
    n = nsamp(total)
    if rips == 1:
        env = ar_env(n, 0.004, total / 3.0)
    else:
        l1 = total * r.uniform(0.45, 0.6)
        gap = r.uniform(0.005, 0.015)
        tt = taxis(n)
        env = ar_env(n, 0.003, l1 / 3.0) * (tt < l1)
        e2 = ar_env(n, 0.003, (total - l1 - gap) / 3.0) * r.uniform(0.6, 0.9)
        k2 = nsamp(l1 + gap)
        env[k2:] += e2[:n - k2]
    env *= 0.65 + 0.35 * smooth_noise(n, 60, r)
    rn = smooth_noise(n, 40, r)                          # tearing speed: 2-6 kHz micro-impulses
    rate = lambda t: 4000.0 + 2000.0 * np.interp(t, taxis(n), rn)  # noqa: E731
    rip = bp(crackle(r, total, rate, click_ms=(0.02, 0.1), skew=1.5), 1500, 9000, 2) * env
    place(y, lv(rip, 0.0), t_r)
    t_spit = r.uniform(max(0.18, t_r + total + 0.015), max(0.26, t_r + total + 0.02))
    sp = colored(r, 0.02, 150, 2500, 2) * ar_env(nsamp(0.02), 0.002, 0.008)     # lip plosive 'ptt'
    place(y, lv(sp * hump(nsamp(0.02), 0.05, 0.3), -10.0), t_spit)
    return finish(y, max_s=0.35, fade=0.012)


# --------------------------------------------------------------------------- powder

def flow_env(t: np.ndarray, dur: float, fin: float, fout: float) -> np.ndarray:
    a = np.clip(t / fin, 0, 1)
    b = np.clip((dur - t) / fout, 0, 1)
    return (0.5 - 0.5 * np.cos(np.pi * a)) * (0.5 - 0.5 * np.cos(np.pi * b))


def powder_pour_pan(r):
    dur = 0.45
    fw, ph = r.uniform(5.0, 10.0), r.uniform(0, 2 * np.pi)
    base = r.uniform(1300, 1900)
    wob = lambda t: np.sin(2 * np.pi * fw * t + ph)  # noqa: E731  finger taps on the paper
    rate = lambda t: np.clip(base * (1.0 + 0.45 * wob(t)), 800, 2500) * flow_env(t, dur, 0.04, 0.08)  # noqa: E731
    amp = lambda t: 0.75 + 0.25 * wob(t)  # noqa: E731
    g = grains(r, dur, rate, (4000, 9000), (0.1, 0.3), amp=amp)
    g = hp(g, 2500, 2) * flow_env(taxis(len(g)), dur, 0.04, 0.08)
    ring_ir = modal_ir([det(r, 3200, 0.03), det(r, 5100, 0.03)], [0.045, 0.03], [1.0, 0.7], 0.3)
    ring = fftconvolve(g, ring_ir)[:len(g) + nsamp(0.05)]
    y = np.zeros(len(ring))
    y[:len(g)] += g
    ring *= db2lin(-18.0) * np.std(g) / (np.std(ring[:len(g)]) + 1e-12)
    return finish(y + ring, max_s=0.47, fade=0.015)


def barrel_pour(r, delay: float, stream: float, crumple_len: float, max_s: float):
    lr0, lr1 = r.uniform(1000, 1200), r.uniform(400, 550)        # grains/s: slowing as it settles
    rate = lambda t: (lr0 * (lr1 / lr0) ** np.clip(t / stream, 0, 1)) * flow_env(t, stream, 0.06, 0.12)  # noqa: E731
    g = grains(r, stream, rate, (2000, 6000), (0.15, 0.5), amp=lambda t: 1.0 + 0.3 * np.sin(2 * np.pi * 7 * t))
    g = tv_filter(g, lambda t, f: lpg(f, 6000.0 * (1500.0 / 6000.0) ** np.clip(t / stream, 0, 1), 4))
    g *= flow_env(taxis(len(g)), stream, 0.06, 0.12)
    wet = bp(tube(g, delay * r.uniform(0.98, 1.02), r.uniform(0.6, 0.75), damp=4500.0, tail=0.15), 300, 4000, 2)
    y = np.zeros(nsamp(max_s + 0.1))
    place(y, lv(wet, 0.0), 0.0)
    cr = crumple(r, crumple_len)
    crt = bp(tube(cr, delay, 0.6, damp=4000.0, tail=0.05), 300, 7000, 2)
    t_c = stream - r.uniform(0.02, 0.04)
    place(y, lv(cr, -3.0), t_c)
    place(y, lv(crt, -12.0), t_c)
    return finish(y, max_s=max_s, fade=0.02)


def powder_pour_barrel(r):
    return barrel_pour(r, MUSKET_TUBE, 0.75, 0.10, 0.9)


def powder_pour_barrel_pistol(r):
    return barrel_pour(r, PISTOL_TUBE, 0.34, 0.06, 0.4)


def ball_seat(r):
    y = np.zeros(nsamp(0.35))
    place(y, lv(crumple(r, 0.08), -4.0), 0.002)
    t_tick = r.uniform(0.095, 0.115)
    tk = hit([det(r, 1400, 0.04), det(r, 2600, 0.04)], [dtau(8), dtau(6.5)], [1.0, 0.6], contact=0.0005)
    place(y, lv(tk, 0.0), t_tick)
    ex = np.concatenate([mallet(0.0015), np.zeros(nsamp(0.02))])
    tn = bp(tube(ex, MUSKET_TUBE * r.uniform(0.98, 1.02), 0.65, damp=1500.0, tail=0.2), 150, 2500, 2)
    place(y, lv(tn, -18.0), t_tick)
    return finish(y, max_s=0.26, fade=0.015)


# --------------------------------------------------------------------------- ramrod

def swivel_ticks(r, y, t_lo, t_hi, count, db_range=(-14.0, -8.0), f_range=(3000, 6000), db_off: float = 0.0):
    """Sling swivel / hook ticks: small steel parts (inharmonic, 8-20 ms decays)."""
    for tt in np.sort(r.uniform(t_lo, t_hi, count)):
        k = steel(r, r.uniform(*f_range), dtau(r.uniform(8, 20)), contact=0.00006, n=int(r.integers(6, 9)))
        place(y, lv(k, r.uniform(*db_range) + db_off), tt)


def thimble_tick(r):
    """The ramrod passing a brass/iron thimble."""
    return steel(r, det(r, 2200, 0.06), dtau(15), contact=0.00012, n=int(r.integers(8, 11)))


def rod_scrape(r, dur, rate0, rate1):
    x = colored(r, dur, 800, 4000, 2) * rasp(r, nsamp(dur), rate0, rate1)
    tt = taxis(len(x))
    return x * np.clip(tt / 0.025, 0, 1) * np.clip((dur - tt) / 0.015, 0, 1) * (0.8 + 0.2 * tt / dur)


def ramrod_draw(r):
    y = np.zeros(nsamp(0.65))
    place(y, lv(rod_scrape(r, 0.45, 30.0, 60.0), -7.0), 0.002)
    for tt in (0.12, 0.26, 0.40):
        place(y, lv(thimble_tick(r), r.uniform(-2.0, 0.0)), tt + r.uniform(-0.008, 0.008))
    place(y, lv(swish(r, 0.08, 1500.0, 3000.0), -6.0), r.uniform(0.44, 0.46))
    return finish(y, max_s=0.56, fade=0.015)


def ram_stroke(r, v, pistol=False, nv=4):
    y = np.zeros(nsamp(0.6))
    if pistol:
        slide, delay, fm = r.uniform(0.045, 0.055), PISTOL_TUBE, 1.8
        tunk_d, ring_d, ring_db = r.uniform(30, 45), 100.0 * r.uniform(0.9, 1.1), -16.0
        max_s = 0.26
    else:
        hard = v == 3                               # variant 04: the harder final seat
        slide, delay, fm = r.uniform(0.09, 0.16), MUSKET_TUBE, 1.0
        tunk_d = r.uniform(30, 60)
        ring_d = 250.0 * r.uniform(1.0, 1.1) if hard else r.uniform(150, 250)
        ring_db = -11.0 if hard else -16.0
        max_s = 0.44
    contact = r.uniform(0.0006, 0.0016)
    t_imp = 0.06 if pistol else 0.13           # pinned so the reload cue times hit the impact
    # hollow rod-in-barrel slide, rising into the impact
    s = colored(r, slide, 500, 5000, 2)
    tt = taxis(len(s))
    s *= (tt / slide) ** 1.5 * rasp(r, len(s), 40.0, 70.0, depth=0.4)
    s = tube(s, delay * r.uniform(0.98, 1.02), 0.7, damp=3500.0, tail=0.03)
    place(y, lv(s, -10.0), t_imp - slide)      # a slide longer than t_imp starts before the file
    # seating 'tunk' of the iron-tipped rod on ball, paper and powder: modes detuned +-10 %
    # (the variant takes its own slot of that range), decays +-30 %, plus a dull thud
    g = vslot(r, v, nv, 0.10)
    tf, ta, tam = [], [], []
    for f, k, a in ((350, 1.0, 1.0), (900, 0.8, 0.7), (1600, 0.6, 0.45)):
        f *= fm * g * r.uniform(0.97, 1.03)
        tau = dtau(tunk_d * k * r.uniform(0.7, 1.3))
        tf += [f, f * (1.0 + r.uniform(0.003, 0.012))]      # doublets: the rod is not a perfect bar
        ta += [tau, tau * r.uniform(0.8, 1.1)]
        tam += [a, a * r.uniform(0.5, 1.0)]
    tk = ring(r, tf, ta, tam, contact, cap=0.35)
    th = colored(r, 0.1, 200 * fm ** 0.5, 900 * fm ** 0.5, 2) * ar_env(nsamp(0.1), 0.0005, 0.015)
    tk = lv(tk)
    place(y, tk, t_imp)
    place(y, th * db2lin(-2.0) * np.sqrt(np.mean(tk[:nsamp(0.1)] ** 2) / np.mean(th ** 2)), t_imp)   # RMS re tunk
    ex = np.concatenate([mallet(0.001), np.zeros(nsamp(0.02))])
    hol = bp(tube(ex, delay, 0.65, damp=2500.0, tail=0.15), 150, 2500, 2)
    place(y, lv(hol, -16.0), t_imp)
    # barrel ring: inharmonic steel tube modes, each with a doublet partner
    rf, ra, rt = [], [], []
    for f, a, k in ((1100, 1.0, 1.0), (2900, 0.9, 0.9), (5300, 0.75, 0.8), (8100, 0.6, 0.65), (11000, 0.5, 0.5)):
        fr = det(r, f * fm, 0.05)
        if fr > 16000:
            continue
        a *= r.uniform(0.6, 1.0)
        rf += [fr, fr * (1.0 + r.uniform(0.003, 0.012))]
        ra += [a, a * r.uniform(0.5, 1.0)]
        rt += [dtau(ring_d * k), dtau(ring_d * k * r.uniform(0.8, 1.1))]
    rg = ring(r, rf, rt, balance_ring(rf, ra, rt, 0.0003), 0.0003)
    place(y, lv(rg, ring_db), t_imp)
    # faint wooden rod buzz against the bore
    fb = r.uniform(140, 190) * (1.3 if pistol else 1.0)
    bz = stick_slip_train(0.07, fb, r, jitter=0.1, amp=lambda t: np.exp(-t / 0.02))
    place(y, lv(bp(bz, 300, 2000, 2), -20.0), t_imp + 0.002)
    return fade_in(finish(y, max_s=max_s, fade=0.03, lead=False), 0.004)


def ramrod_return(r):
    y = np.zeros(nsamp(0.75))
    place(y, lv(swish(r, 0.08, 1200.0, 2800.0), -6.0), 0.0)
    place(y, lv(rod_scrape(r, 0.40, 35.0, 60.0), -8.0), 0.08)
    t1 = 0.08 + r.uniform(0.08, 0.10)
    g1 = r.uniform(0.12, 0.14)
    g2 = g1 * r.uniform(0.6, 0.72)                 # ticks closing up as the rod speeds in
    for tt in (t1, t1 + g1, t1 + g1 + g2):
        place(y, lv(thimble_tick(r), -3.0), tt)
    t_k = r.uniform(0.48, 0.50)
    tock = steel(r, det(r, 1300, 0.06), dtau(45), contact=0.0005, n=int(r.integers(8, 11)), burst_db=-8.0)
    wood = hit([det(r, 250, 0.05), det(r, 560, 0.05)], [dtau(50), dtau(30)], [1.0, 0.3], contact=0.0012, r=r)
    place(y, lv(tock, 0.0), t_k)
    place(y, lv(wood, -3.0), t_k + 0.0003)
    return finish(y, max_s=0.66, fade=0.015)


# --------------------------------------------------------------------------- handling

def rustle(r, dur, lo=1000.0, hi=6000.0):
    x = colored(r, dur, lo, hi, 2)
    b = np.maximum(smooth_noise(len(x), 25, r), 0.0) ** 1.5
    return x * (0.25 + b)


# Handling knocks: each variant takes its own slot of a +-7 % size range and every mode
# is detuned a further +-5 % (+-12 % in all); contact widths vary +-50 % (knock()) and the
# knock / rustle / tick layers +-3 dB.

def jdb(r, db: float, j: float = 3.0) -> float:
    return db + r.uniform(-j, j)


def musket_handle(r, v=0, nv=3):
    y = np.zeros(nsamp(0.4))
    sl_len = r.uniform(0.16, 0.22)
    sl = colored(r, sl_len, 800, 4000, 2) * hump(nsamp(sl_len), r.uniform(0.4, 0.7))
    sl *= 1.0 + 0.5 * smooth_noise(len(sl), 45, r)
    place(y, lv(sl, jdb(r, -8.0)), 0.004)
    t_k = r.uniform(0.15, 0.20)
    kn = knock(r, (180, 420), (40, 30), [1.0, r.uniform(0.4, 0.8)], 0.0012, vslot(r, v, nv, 0.07))
    kn = mix(lv(kn), lv(contact_noise(r, 0.003, None, 2000, 0.0002, 0.0007), jdb(r, -12.0)))
    place(y, lv(kn, 0.0), t_k)
    swivel_ticks(r, y, t_k + 0.008, t_k + 0.05, int(r.integers(2, 4)), (-13.0, -11.0), db_off=r.uniform(-3, 3))
    return finish(y, max_s=0.32, fade=0.015)


def musket_equip(r, v=0, nv=2):
    y = np.zeros(nsamp(0.75))
    ln = colored(r, 0.25, 400, 2500, 2) * hump(nsamp(0.25), 0.35) * (1.0 + 0.5 * smooth_noise(nsamp(0.25), 30, r))
    place(y, lv(ln, jdb(r, -12.0)), 0.002)
    cr = creak(r, 0.25, int(r.integers(2, 4)), [(300.0, 6.0, 1.0), (550.0, 7.0, 0.8), (900.0, 8.0, 0.55)])
    place(y, lv(cr, jdb(r, -8.0)), 0.002)
    t_s = r.uniform(0.285, 0.31)
    kn = knock(r, (180, 420, 950), (60, 45, 30), [1.0, r.uniform(0.5, 0.9), r.uniform(0.3, 0.6)], 0.0012,
               vslot(r, v, nv, 0.07))
    place(y, lv(kn, 0.0), t_s)
    place(y, lv(contact_noise(r, 0.006, None, 3000, 0.0004, 0.0015), jdb(r, -6.0)), t_s)
    swivel_ticks(r, y, 0.32, 0.40, int(r.integers(3, 6)), db_off=r.uniform(-3, 3))
    ru = rustle(r, 0.32) * ar_env(nsamp(0.32), 0.02, 0.12)
    place(y, lv(ru, jdb(r, -16.0)), 0.29)
    return finish(y, max_s=0.62, fade=0.03)


def musket_holster(r, v=0, nv=2):
    y = np.zeros(nsamp(0.6))
    place(y, lv(rustle(r, 0.14) * hump(nsamp(0.14), 0.4), jdb(r, -12.0)), 0.002)
    cr = creak(r, 0.22, int(r.integers(2, 4)), [(280.0, 6.0, 1.0), (520.0, 7.0, 0.8), (850.0, 8.0, 0.55)])
    cr = mix(lv(cr), lv(colored(r, 0.22, 400, 2500, 2) * hump(nsamp(0.22), 0.5), -8.0))
    place(y, lv(cr, jdb(r, -10.0)), 0.08)
    t_b = r.uniform(0.31, 0.34)
    bm = knock(r, (140, 330), (40, 25), [1.0, r.uniform(0.25, 0.5)], 0.002, vslot(r, v, nv, 0.07), noise_db=-3.0)
    place(y, lv(bm, 0.0), t_b)
    th = colored(r, 0.015, None, 400, 4) * ar_env(nsamp(0.015), 0.001, 0.004)
    place(y, lv(th, jdb(r, -8.0)), t_b)
    swivel_ticks(r, y, t_b + 0.012, t_b + 0.03, 1, (-10.0, -10.0), (3500, 5500), db_off=r.uniform(-3, 3))
    return finish(y, max_s=0.46, fade=0.02)


def pistol_equip(r, v=0, nv=2):
    y = np.zeros(nsamp(0.4))
    sl = colored(r, 0.15, 1000, 5000, 2) * hump(nsamp(0.15), 0.72) * (1.0 + 0.4 * smooth_noise(nsamp(0.15), 60, r))
    place(y, lv(sl, jdb(r, -8.0)), 0.002)
    t_h = r.uniform(0.11, 0.135)
    hk = colored(r, 0.03, 4000, 7000, 2) * ar_env(nsamp(0.03), 0.002, 0.008) * rasp(r, nsamp(0.03), 180, 260, 0.5)
    place(y, lv(hk, jdb(r, -10.0)), t_h)
    t_g = r.uniform(0.175, 0.20)
    gs = knock(r, (300, 800), (35, 25), [1.0, r.uniform(0.4, 0.8)], 0.0009, vslot(r, v, nv, 0.07))
    place(y, lv(gs, 0.0), t_g)
    place(y, lv(contact_noise(r, 0.004, None, 2500, 0.0003, 0.001), jdb(r, -6.0)), t_g)
    return finish(y, max_s=0.31, fade=0.015)


def pistol_holster(r, v=0, nv=2):
    y = np.zeros(nsamp(0.4))
    sl = colored(r, 0.15, 800, 4500, 2) * hump(nsamp(0.15), 0.5) * (1.0 + 0.4 * smooth_noise(nsamp(0.15), 60, r))
    place(y, lv(sl, jdb(r, -8.0)), 0.002)
    t_h = r.uniform(0.15, 0.18)
    hk = steel(r, det(r, 5000, 0.08), dtau(9), contact=0.00006, n=int(r.integers(6, 9)))
    place(y, lv(hk, jdb(r, -6.0)), t_h)
    t_b = t_h + r.uniform(0.015, 0.03)
    bm = knock(r, (220, 520), (35, 20), [1.0, r.uniform(0.25, 0.5)], 0.0015, vslot(r, v, nv, 0.07))
    place(y, lv(bm, 0.0), t_b)
    return finish(y, max_s=0.31, fade=0.015)


# --------------------------------------------------------------------------- registry

SOUNDS = {  # id: (generator(r, v), variants)
    "musket_lock": (lambda r, v: lock_fall(r, False), 3),
    "pistol_lock": (lambda r, v: lock_fall(r, True), 3),
    "pan_flash": (lambda r, v: pan_flash(r), 3),
    "musket_shot": (lambda r, v: musket_shot(r), 3),
    "musket_tail": (lambda r, v: tail(r, TAILS["musket_tail"]), 2),
    "musket_tail_fort": (lambda r, v: tail(r, TAILS["musket_tail_fort"]), 2),
    "pistol_shot": (lambda r, v: pistol_shot(r), 3),
    "pistol_tail": (lambda r, v: tail(r, TAILS["pistol_tail"]), 2),
    "pistol_tail_fort": (lambda r, v: tail(r, TAILS["pistol_tail_fort"]), 2),
    "dry_fire": (lambda r, v: dry_fire(r, v, 3), 3),
    "cock_half": (lambda r, v: cock_half(r), 3),
    "cock_full": (lambda r, v: cock_full(r), 3),
    "frizzen_open": (lambda r, v: frizzen_open(r), 2),
    "frizzen_close": (lambda r, v: frizzen_close(r), 3),
    "cartridge_draw": (lambda r, v: cartridge_draw(r), 2),
    "cartridge_bite": (cartridge_bite, 4),
    "powder_pour_pan": (lambda r, v: powder_pour_pan(r), 3),
    "powder_pour_barrel": (lambda r, v: powder_pour_barrel(r), 3),
    "powder_pour_barrel_pistol": (lambda r, v: powder_pour_barrel_pistol(r), 2),
    "ball_seat": (lambda r, v: ball_seat(r), 2),
    "musket_handle": (lambda r, v: musket_handle(r, v, 3), 3),
    "ramrod_draw": (lambda r, v: ramrod_draw(r), 2),
    "ram_stroke": (lambda r, v: ram_stroke(r, v, False, 4), 4),
    "ram_stroke_pistol": (lambda r, v: ram_stroke(r, v, True, 3), 3),
    "ramrod_return": (lambda r, v: ramrod_return(r), 2),
    "musket_equip": (lambda r, v: musket_equip(r, v, 2), 2),
    "musket_holster": (lambda r, v: musket_holster(r, v, 2), 2),
    "pistol_equip": (lambda r, v: pistol_equip(r, v, 2), 2),
    "pistol_holster": (lambda r, v: pistol_holster(r, v, 2), 2),
}

# Playback settings copied from the spec, for whoever wires up PlayerAudio.
# anchor: pan = muzzle.global_position + muzzle.global_basis.z * pan_distance + UP*0.03,
# muzzle = w.muzzle.global_position, model = w.model.global_position,
# hip/chest/head = player.global_position + UP * 0.9 / 1.2 / 1.5.
PLAYBACK = {
    "musket_lock": dict(mode="3d", anchor="pan", unit_size=3, bus="Weapons", volume_db=-6, random_pitch=1.03,
                        random_volume_offset_db=1, hook="sfx(&'lock')"),
    "pistol_lock": dict(mode="3d", anchor="pan", unit_size=3, bus="Weapons", volume_db=-7, random_pitch=1.03,
                        hook="sfx(&'lock')"),
    "pan_flash": dict(mode="3d", anchor="pan", bus="Weapons", random_pitch=1.05, delay_after_lock_s=0.027,
                      volume_db={"musket": -8, "pistol": -10}, pitch_scale={"musket": 1.0, "pistol": 1.08}),
    "musket_shot": dict(mode="3d", anchor="muzzle", unit_size=3, max_db=3, bus="Weapons", volume_db=0,
                        random_pitch=1.04, hook="fired"),
    "musket_tail": dict(mode="2d", bus="Tails", volume_db=-9, random_pitch=1.02, when="outside fort"),
    "musket_tail_fort": dict(mode="2d", bus="Tails", volume_db=-9, random_pitch=1.02,
                             when="abs(x) < 16 and abs(z) < 16"),
    "pistol_shot": dict(mode="3d", anchor="muzzle", unit_size=3, max_db=3, bus="Weapons", volume_db=-2,
                        random_pitch=1.05, hook="fired"),
    "pistol_tail": dict(mode="2d", bus="Tails", volume_db=-11, random_pitch=1.02, when="outside fort"),
    "pistol_tail_fort": dict(mode="2d", bus="Tails", volume_db=-11, when="abs(x) < 16 and abs(z) < 16"),
    "dry_fire": dict(mode="3d", anchor="model", bus="Weapons", volume_db=-8, random_pitch=1.03, cooldown_s=0.35,
                     pitch_scale={"musket": 0.95, "pistol": 1.15}, hook="sfx(&'dry')"),
    "cock_half": dict(mode="3d", anchor="model", unit_size=3, bus="Foley", volume_db=-12, random_pitch=1.03),
    "cock_full": dict(mode="3d", anchor="model", bus="Foley", volume_db=-11, random_pitch=1.03),
    "frizzen_open": dict(mode="3d", anchor="model", bus="Foley", volume_db=-12, random_pitch=1.04),
    "frizzen_close": dict(mode="3d", anchor="model", bus="Foley", volume_db=-11, random_pitch=1.04),
    "cartridge_draw": dict(mode="3d", anchor="hip", bus="Foley", volume_db=-16, random_pitch=1.05),
    "cartridge_bite": dict(mode="3d", anchor="head", bus="Foley", volume_db=-14, random_pitch=1.06),
    "powder_pour_pan": dict(mode="3d", anchor="pan", bus="Foley", volume_db=-18, random_pitch=1.05),
    "powder_pour_barrel": dict(mode="3d", anchor="model", bus="Foley", volume_db=-16, random_pitch=1.04),
    "powder_pour_barrel_pistol": dict(mode="3d", anchor="model", bus="Foley", volume_db=-16, random_pitch=1.05),
    "ball_seat": dict(mode="3d", anchor="model", bus="Foley", volume_db=-16, random_pitch=1.05),
    "musket_handle": dict(mode="3d", anchor="model", bus="Foley", volume_db=-18, random_pitch=1.06),
    "ramrod_draw": dict(mode="3d", anchor="model", bus="Foley", volume_db=-14, random_pitch=1.04),
    "ram_stroke": dict(mode="3d", anchor="muzzle", bus="Foley", volume_db=-11, random_pitch=1.03, max_polyphony=1),
    "ram_stroke_pistol": dict(mode="3d", anchor="muzzle", bus="Foley", volume_db=-12, random_pitch=1.04),
    "ramrod_return": dict(mode="3d", anchor="model", bus="Foley", volume_db=-14, random_pitch=1.04),
    "musket_equip": dict(mode="3d", anchor="chest", bus="Foley", volume_db=-9, random_pitch=1.04, delay_s=0.08),
    "musket_holster": dict(mode="3d", anchor="chest", bus="Foley", volume_db=-10, random_pitch=1.04),
    "pistol_equip": dict(mode="3d", anchor="hip", bus="Foley", volume_db=-9, random_pitch=1.05, delay_s=0.08),
    "pistol_holster": dict(mode="3d", anchor="hip", bus="Foley", volume_db=-10, random_pitch=1.05),
}

# Reload timeline from the spec: weapon -> stage index -> [(sound, t, extra)]
# (extra: pitch_scale / volume offset). Stage labels: musket.gd / pistol.gd reload_stages.
RELOAD_CUES = {
    "musket": {
        "0 Biting cartridge": [["cock_half", 0.05, {}], ["frizzen_open", 0.32, {}],
                               ["cartridge_draw", 0.50, {}], ["cartridge_bite", 0.95, {}]],
        "1 Priming the pan": [["powder_pour_pan", 0.15, {}], ["frizzen_close", 0.85, {}],
                              ["musket_handle", 1.20, {}]],
        "2 Pouring powder": [["powder_pour_barrel", 0.20, {}], ["ball_seat", 1.25, {}], ["ramrod_draw", 1.41, {}]],
        "3 Ramming ball": [["ramrod_draw", 0.08, {}], ["ram_stroke", 0.80, {}], ["ram_stroke", 1.25, {}],
                           ["ram_stroke", 1.70, {"volume_db": 2, "pitch_scale": 0.97}]],
        "4 Returning ramrod": [["ramrod_return", 0.05, {}], ["musket_handle", 0.78, {}], ["cock_full", 1.05, {}]],
    },
    "pistol": {
        "0 Half-cocking": [["cock_half", 0.05, {"pitch_scale": 1.15}], ["frizzen_open", 0.40, {"pitch_scale": 1.15}]],
        "1 Powder and ball": [["cartridge_bite", 0.00, {"pitch_scale": 1.05}],
                              ["powder_pour_barrel_pistol", 0.22, {}], ["ball_seat", 0.60, {"pitch_scale": 1.1}],
                              ["ram_stroke_pistol", 0.78, {}], ["ram_stroke_pistol", 0.98, {"volume_db": 1}]],
        "2 Priming the pan": [["powder_pour_pan", 0.03, {}], ["frizzen_close", 0.52, {"pitch_scale": 1.15}],
                              ["cock_full", 0.72, {"pitch_scale": 1.15}]],
    },
}


def render(sid: str, v: int, seed: int) -> np.ndarray:
    gen, _ = SOUNDS[sid]
    return gen(rng(seed * 100003 + zlib.crc32(sid.encode()) % 100000 + 7919 * v), v)


def write_manifest(out_dir: str, done: dict) -> None:
    path = os.path.join(out_dir, MANIFEST)
    data = {}
    if os.path.exists(path):
        try:
            with open(path) as f:
                data = json.load(f)
        except (OSError, ValueError):
            data = {}
    sounds = data.get("sounds", {})
    for sid, files in done.items():
        sounds[sid] = dict(files=[os.path.basename(p) for p, _, _ in files],
                           channels=files[0][2], seconds=[round(d, 3) for _, d, _ in files],
                           playback=PLAYBACK.get(sid, {}))
    data = {"family": "flintlock", "generator": "tools/sfx/flintlock.py", "format": "44.1 kHz 16-bit PCM",
            "sounds": {k: sounds[k] for k in SOUNDS if k in sounds}, "reload_cues": RELOAD_CUES}
    with open(path, "w") as f:
        json.dump(data, f, indent=1)


def main(argv=None) -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, default=DEFAULT_SEED, help="base seed; change for new variations")
    ap.add_argument("--out", default=OUT_DIR, help="output directory")
    ap.add_argument("--only", default="", help="comma-separated sound ids")
    ap.add_argument("--list", action="store_true", help="list sound ids and variant counts")
    a = ap.parse_args(argv)
    if a.list:
        for sid, (_, nv) in SOUNDS.items():
            print(f"{sid:28s} {nv}")
        return
    ids = [s.strip() for s in a.only.split(",") if s.strip()] or list(SOUNDS)
    bad = [s for s in ids if s not in SOUNDS]
    if bad:
        raise SystemExit(f"unknown sound id(s): {', '.join(bad)}")
    done = {}
    for sid in ids:
        files = []
        for v in range(SOUNDS[sid][1]):
            x = render(sid, v, a.seed)
            path = write_wav(os.path.join(a.out, NAME_FMT.format(id=sid, n=v + 1)), x,
                             seed=a.seed + zlib.crc32(sid.encode()) % 1000 + v)
            ch = 1 if x.ndim == 1 else x.shape[1]
            files.append((path, len(x) / SR, ch))
            print(f"{os.path.relpath(path, ROOT):52s} {len(x) / SR:6.3f} s  {'stereo' if ch == 2 else 'mono'}")
        done[sid] = files
    write_manifest(a.out, done)


if __name__ == "__main__":
    main()
