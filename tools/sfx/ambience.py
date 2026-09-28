#!/usr/bin/env python3
"""Ambience family for Frontier: forest wind bed, songbirds, crow, woodpecker, flushed
birds, tree creaks, the fort flag, and the river (its running water and its rapids).

Usage (from the project root):
  python3 tools/sfx/ambience.py                      # default seed, every sound
  python3 tools/sfx/ambience.py --seed 7             # a different take of every sound
  python3 tools/sfx/ambience.py --only bird_thrush crow_caw
  python3 tools/sfx/ambience.py --out /tmp/amb       # write somewhere else

Output: audio/sfx/ambience/<id>_<NN>.wav, 44.1 kHz 16-bit. Everything is mono except
forest_wind_loop (stereo). One-shots are DC-blocked, trimmed and faded, then loudness-matched
rather than peak-normalised (active A-weighted RMS, see active_loudness(); peak capped at
-1 dBFS): the five bird-scheduler calls all sit at BIRD_LOUD_DB (-22), birds_flush at -26 and
tree_creak at -27, so every variant of an id plays at the same level and volume_db alone sets
the mix order. The two loops peak at -1 dBFS, are not trimmed or faded, and carry a RIFF 'smpl'
forward loop (0 .. frames-1, inclusive); game code should still set loop_mode / loop_end =
frames. The wind loop crossfades 4 s of generated overhang into its head; the flag loop is
generated exactly periodic (events on a 6 s circle, circular filters), so it needs no crossfade.

Everything is synthesised with numpy (see dsp.py): filtered noise, oscillators, modal
resonators, stick-slip excitation and convolution with synthetic forest impulse responses.

Game-side use (from the spec; implemented by the integration step). volume_db values are for
these loudness-matched files: crow, thrush and woodpecker at the top within ~1 dB, the high,
thin chickadee and warbler ~3 dB under them.
  forest_wind_loop   AmbienceBed 2D player, bus Ambience, -16 dB (-15 dB keeps the average level
                     of the previous take; its lulls are now quieter), 2 s fade-in, no pitch
                     random; start at a random offset, play(randf() * 60.0), so each level load
                     does not open on the same gust
  bird_*/crow/wood   bird scheduler every 5-16 s, 3D at 25-70 m, weights 30/25/20/15/10;
                     volume_db thrush -1.5, chickadee -4, warbler -4.5, crow -1, woodpecker -2
  birds_flush        AmbienceBed.scare() on musket/pistol shots, 60 % chance, 25-45 m away,
                     volume_db -2 (it must cut through the tail of the musket report)
  tree_creak         every 18-45 s, 3D 12-30 m away at UP*4 (files are ~2 dB quieter than the
                     previous peak-normalised take: add 2 dB to a volume tuned for those)
  flag_flutter_loop  looping 3D player at the fort flag, Vector3(-5.1, 9.3, -2)
  river_flow_loop    RiverWater: a looping 3D player kept at the river's nearest point to the listener (a line
                     source), bus Ambience; built exactly periodic (8 s circle) like the flag
  river_rapids_loop  RiverWater: a looping 3D player at each rapid, louder and further carrying (6 s circle)
The river's two (user 2026-09-27: the river "have some spots be like white water rapids"; its sound): a bed of
filtered noise swelling with a slow surge, and bubbles: each a damped sine rising in pitch as the bubble nears the
surface (the Minnaert resonance, the plink of moving water), log-uniform in pitch; the rapids denser, broader and
brighter, with splash bursts.
"""
from __future__ import annotations

import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dsp  # noqa: E402
from dsp import SR, db2lin, nsamp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "audio", "sfx", "ambience")
NAME_FMT = "{id}_{n:02d}.wav"
PEAK_DB = -1.0
TWO_PI = 2.0 * np.pi


# =========================================================================== local helpers

def bp_env(n: int, times, values) -> np.ndarray:
    """Breakpoint curve over n samples, cosine-interpolated, held flat past the ends."""
    t = np.arange(int(n)) / SR
    times = np.asarray(times, dtype=float)
    values = np.asarray(values, dtype=float)
    i = np.clip(np.searchsorted(times, t, side="right") - 1, 0, len(times) - 2)
    t0, t1 = times[i], times[i + 1]
    u = np.clip((t - t0) / np.maximum(t1 - t0, 1e-12), 0.0, 1.0)
    return values[i] + (values[i + 1] - values[i]) * (0.5 - 0.5 * np.cos(np.pi * u))


def ctrl_noise(n: int, rate: float, r: np.random.Generator, cr: float = 200.0) -> np.ndarray:
    """dsp.smooth_noise built at a control rate and interpolated (cheap for long signals)."""
    m = max(int(n / SR * cr) + 4, 8)
    c = dsp.smooth_noise(m, rate, r, sr=int(cr))
    return np.interp(np.arange(n) / SR, np.arange(m) / cr, c)


def rms(x) -> float:
    x = np.asarray(x, dtype=float)
    return float(np.sqrt(np.mean(x * x) + 1e-30))


def harmonic_osc(freq: np.ndarray, amps, fmax: float = 18000.0) -> np.ndarray:
    """Band-limited harmonic oscillator following a per-sample frequency; amps[k-1] = harmonic k."""
    ph = TWO_PI * np.cumsum(freq) / SR
    y = np.zeros_like(freq)
    for k, a in enumerate(amps, start=1):
        guard = np.clip((fmax - k * freq) / (0.15 * fmax), 0.0, 1.0)
        if not guard.any():
            break
        y += a * guard * np.sin(k * ph)
    return y


def saw_osc(freq: np.ndarray, fmax: float = 9000.0) -> np.ndarray:
    k = int(fmax / max(float(freq.min()), 50.0)) + 1
    return harmonic_osc(freq, [1.0 / i for i in range(1, k + 1)], fmax) * (2.0 / np.pi)


def lp(x, fc, order=2, tail=0.02):
    return dsp.fft_filter(x, lambda f: dsp.mag_lowpass(f, fc, order), tail=tail)


def forest_reverb_ir(t60: float, r: np.random.Generator, predelay: float = 0.012, build: float = 0.025,
                     hf_ratio: float = 0.4, hf_ref: float = 3500.0, lf_cut: float = 110.0,
                     n_early: int = 7, early_span=(0.005, 0.07)) -> np.ndarray:
    """Synthetic open-forest impulse response (no direct path), unit energy.

    Diffuse tail: noise with a frequency-dependent T60 (foliage soaks up the highs, the open
    sky lets little low end build up) that fades in after `predelay`. Early part: a handful of
    softened discrete reflections off nearby trunks and the ground.
    """
    L = nsamp(predelay + 1.15 * t60 + 0.03)

    def gain(t, f):
        t60f = t60 * (hf_ratio + (1.0 - hf_ratio) / (1.0 + (f / hf_ref) ** 2))
        g = np.exp(-6.9078 * np.maximum(t - predelay, 0.0) / t60f) * dsp.mag_highpass(f, lf_cut, 1)
        return g * np.clip((t - predelay) / build, 0.0, 1.0)

    h = dsp.tv_filter(r.standard_normal(L), gain, n_fft=1024, hop=128)
    h[:nsamp(predelay)] = 0.0
    h /= np.sqrt(np.sum(h * h)) + 1e-20
    er = np.zeros(L)
    for _ in range(n_early):
        d = r.uniform(*early_span)
        w = int(r.integers(8, 30))
        blip = np.hanning(w + 2)[1:-1]
        blip *= 0.35 * np.exp(-d / 0.05) * r.choice([-1.0, 1.0]) * r.uniform(0.5, 1.0) / blip.max()
        dsp.place(er, blip, d)
    h += er
    return h / (np.sqrt(np.sum(h * h)) + 1e-20)


def reverb(x: np.ndarray, t60: float, wet_db: float, r: np.random.Generator, **kw) -> np.ndarray:
    """Dry signal plus forest reverb at wet_db (relative, unit-energy IR); output grows by the tail."""
    ir = forest_reverb_ir(t60, r, **kw)
    y = db2lin(wet_db) * dsp.fftconvolve(x, ir)
    y[:len(x)] += x
    return y


def distance(x, r, lp_hz, lp_order, t60, wet_db, **kw):
    """Air/foliage absorption (lowpass) followed by the forest reverb (kw -> forest_reverb_ir)."""
    return reverb(lp(x, lp_hz, lp_order), t60, wet_db, r, **kw)


def a_weight(f):
    """IEC 61672 A-weighting magnitude (linear, 0 dB at 1 kHz)."""
    f2 = np.maximum(np.asarray(f, dtype=float), 1e-9) ** 2
    ra = (12194.0 ** 2 * f2 * f2) / ((f2 + 20.6 ** 2) * np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2))
                                     * (f2 + 12194.0 ** 2))
    return ra * db2lin(2.0)


def active_loudness(x: np.ndarray, win: float = 0.05, hop: float = 0.01, gate_db: float = 20.0) -> float:
    """Active A-weighted RMS (dBFS): mean power of the 50 ms windows within gate_db of the loudest.

    Used to loudness-match one-shots so every variant of an id, and every bird call at the
    same volume_db, plays at the same perceived level (a peak-normalised pure 4 kHz whistle
    is otherwise ~12 dB louder than a peak-normalised woodpecker roll).
    """
    x = np.asarray(x, dtype=float)
    y = dsp.fft_filter(x if x.ndim == 1 else x.mean(axis=1), a_weight, minphase=False)
    w, h = nsamp(win), nsamp(hop)
    k = max((len(y) - w) // h + 1, 1)
    p = np.array([np.mean(y[i * h:i * h + w] ** 2) for i in range(k)])
    return float(10.0 * np.log10(np.mean(p[p >= p.max() * 10.0 ** (-gate_db / 10.0)]) + 1e-30))


# Loudness references (active A-weighted RMS, dBFS). Every bird-scheduler one-shot (thrush,
# chickadee, warbler, crow, woodpecker) sits at BIRD_LOUD_DB, so volume_db alone sets the mix
# order. Flush and creaks have their own references (each variant of an id matches).
BIRD_LOUD_DB = -22.0
FLUSH_LOUD_DB = -26.0
CREAK_LOUD_DB = -27.0


def finish(x: np.ndarray, thresh_db: float = -60.0, fade_out: float = 0.04, max_len: float | None = None,
           hp: float = 20.0, loud_db: float | None = None) -> np.ndarray:
    """One-shot finishing: DC/subsonic highpass, trim silence, optional cap, fades, level.

    Level: peak-normalised to -1 dBFS, or, with loud_db, scaled to that active A-weighted RMS
    with the peak capped at -1 dBFS (a warning is printed if the cap stops it short).
    """
    x = dsp.fft_filter(np.asarray(x, dtype=float), lambda f: dsp.mag_highpass(f, hp, 2))
    x = dsp.trim(x, thresh_db, pad=0.002)
    if max_len is not None and len(x) > nsamp(max_len):
        x = x[:nsamp(max_len)]
    x = dsp.fade_out(x.copy(), fade_out)
    x = dsp.fade_in(x, 0.001)
    if loud_db is None:
        return dsp.peak_norm(x, db2lin(PEAK_DB))
    x = x * db2lin(loud_db - active_loudness(x))
    pk = float(np.max(np.abs(x)))
    if pk > db2lin(PEAK_DB):
        x = x * (db2lin(PEAK_DB) / pk)
        print("  warning: peak cap leaves this one-shot %.1f dB under its loudness target %.1f"
              % (dsp.lin2db(pk) - PEAK_DB, loud_db), file=sys.stderr)
    return x


def finish_loop(x: np.ndarray, xfade: float = 0.0) -> np.ndarray:
    """Equal-power crossfade of the last `xfade` s into the head (skipped for 0, i.e. a signal
    that is already periodic), then -1 dBFS peak. No trim/fades."""
    x = np.asarray(x, dtype=float)
    if xfade > 0:
        x = dsp.loop_xfade(x, xfade)
    return dsp.peak_norm(x, db2lin(PEAK_DB))


def tone_tracks(notes, n: int, glide: float = 0.012, bridge: float = 0.15):
    """Per-sample (freq, amp) for a slurred sequence of whistled notes.

    notes: list of (t0, dur, f_start, f_end, amp, attack, release). Frequency glides (cosine
    portamento) from each note's end pitch to the next note's start pitch across the gap plus
    `glide`; amplitude dips to `bridge` * the quieter neighbour in the gaps so the slide is heard.
    """
    ft, fv, at, av = [], [], [], []
    prev_b = 0.0
    for i, (t0, d, f0, f1, a, att, rel) in enumerate(notes):
        nxt = notes[i + 1] if i + 1 < len(notes) else None
        b = bridge * min(a, nxt[4]) if nxt else 0.0
        if i == 0:
            ft.append(t0)
            fv.append(f0)
        at.append(t0)
        av.append(prev_b)
        ft += [t0 + glide, t0 + d]
        fv += [f0, f1]
        at += [t0 + att, t0 + d - rel, t0 + d]
        av += [a, 0.85 * a, b]
        prev_b = b
    return bp_env(n, ft, fv), bp_env(n, at, av)


def whistle(freq: np.ndarray, amp: np.ndarray, h2_db: float = -12.0) -> np.ndarray:
    """Sine plus 2nd harmonic following freq/amp tracks."""
    ph = TWO_PI * np.cumsum(freq) / SR
    return amp * (np.sin(ph) + db2lin(h2_db) * np.sin(2.0 * ph + 0.4))


# =========================================================================== forest_wind_loop

def _corr_pair(n: int, r: np.random.Generator, rho: float, lag: int, gen):
    """Two noise channels sharing a common part (correlation ~rho); R lags L by `lag` samples."""
    c = gen(n + lag, r)
    a, b = gen(n, r), gen(n, r)
    return np.stack([np.sqrt(rho) * c[lag:lag + n] + np.sqrt(1 - rho) * a,
                     np.sqrt(rho) * c[:n] + np.sqrt(1 - rho) * b], axis=1)


def _wind_tick(r: np.random.Generator) -> np.ndarray:
    """One soft leaf rustle-tick or twig click, energy in 1-4 kHz."""
    if r.random() < 0.55:                                   # leaf: tiny resonant noise tick
        m = nsamp(r.uniform(0.003, 0.008))
        burst = r.standard_normal(m) * dsp.ar_env(m, 0.0002, r.uniform(0.001, 0.0025))
        fc, q = r.uniform(1000, 4000), r.uniform(2.0, 5.0)
        y = dsp.fft_filter(burst, lambda f: dsp.mag_resonance(f, fc, q), tail=0.01)
    else:                                                   # twig: small damped modes + contact
        m = nsamp(0.03)
        f1 = r.uniform(1200, 4000)
        y = dsp.damped_sine(0.03, f1, r.uniform(0.003, 0.009), attack=0.0003)
        y += 0.5 * dsp.damped_sine(0.03, f1 * r.uniform(1.5, 2.3), r.uniform(0.002, 0.005), attack=0.0003)
        y[:nsamp(0.0006)] += 0.6 * r.standard_normal(nsamp(0.0006))
    return y / (np.max(np.abs(y)) + 1e-12)


TICK_GAIN = 1.5     # leaf/twig ticks relative to the wind RMS (median tick ~8 dB under the local
                    # 1-4 kHz wind, the loudest ~30 % poke through)


def forest_wind_loop(r: np.random.Generator, v: int, debug: dict | None = None):
    total, xfade = 64.0, 4.0
    n = nsamp(total)
    cr = 200.0
    m = int(total * cr) + 2
    tc = np.arange(m) / cr

    # gust envelope: smoothed sum of 3 slow random LFOs (0.03-0.15 Hz), phases wander slightly
    g = np.zeros(m)
    for (lo, hi), w in zip([(0.03, 0.06), (0.06, 0.10), (0.10, 0.15)], [1.0, 0.75, 0.55]):
        f = r.uniform(lo, hi)
        wander = 0.8 * dsp.smooth_noise(m, f * 0.5, r, sr=int(cr))
        g += w * np.sin(TWO_PI * f * tc + r.uniform(0, TWO_PI) + wander)
    g = dsp.fft_filter(g, lambda f: dsp.mag_lowpass(f, 0.2, 2), sr=int(cr), minphase=False, circular=True)
    gust_c = (g - g.min()) / (g.max() - g.min())
    # the gust front reaches one side a little before the other; the signed lag wanders slowly
    # (+ = right later, - = left later, up to ~0.4 s) so gusts come from either side
    lag_c = dsp.smooth_noise(m, 0.05, r, sr=int(cr))
    lag_c = 0.4 * (lag_c - lag_c.mean()) / (np.max(np.abs(lag_c - lag_c.mean())) + 1e-12)
    gust_lr_c = np.stack([np.interp(tc + np.minimum(lag_c, 0.0), tc, gust_c),
                          np.interp(tc - np.maximum(lag_c, 0.0), tc, gust_c)], axis=1)
    ta = np.arange(n) / SR
    gust = np.stack([np.interp(ta, tc, gust_lr_c[:, 0]), np.interp(ta, tc, gust_lr_c[:, 1])], axis=1)

    lag = nsamp(0.00025)                            # small inter-channel lag of the shared noise

    # (a) low air bed: pink noise 70-500 Hz, level follows the gusts (deep swing, no sub rumble)
    bed = _corr_pair(n, r, 0.7, lag, dsp.pink)
    bed = dsp.fft_filter(bed, lambda f: dsp.mag_lowpass(f, 500, 2) * dsp.mag_highpass(f, 70, 2))
    bed *= 0.22 + 0.78 * gust
    bed *= 1.0 / rms(bed)

    # (b) pine-needle hiss from 2 kHz (gentle skirt, meets the whoosh) to 7 kHz, exaggerated
    # gust depth; a faint needle whisper (-29 dB) stays in the lulls so they are not bare rumble
    hiss = _corr_pair(n, r, 0.5, lag, dsp.white)
    hiss = dsp.fft_filter(hiss, lambda f: dsp.mag_highpass(f, 2000, 2) * dsp.mag_lowpass(f, 7000, 4))
    hdepth = np.clip((gust - 0.3) / 0.7, 0.0, 1.0) ** 2.2 + 0.035
    flutter = 1.0 + 0.22 * np.stack([ctrl_noise(n, 2.5, r), ctrl_noise(n, 2.5, r)], axis=1)
    hiss *= hdepth * flutter
    hiss *= 0.42 / rms(hiss)

    # (c) mid whoosh from 400 Hz up to a 2.2 kHz skirt, a band that sweeps up with each gust
    # (480 -> 1700 Hz) and swells in level
    wh = _corr_pair(n, r, 0.6, lag, dsp.pink)
    chans = []
    for c in range(2):
        def gain(t, f, c=c):
            gt = np.interp(t, tc, gust_lr_c[:, c])
            fc = 480.0 * (1700.0 / 480.0) ** (gt ** 1.3)
            return dsp.mag_resonance(f, fc, 1.1) * dsp.mag_highpass(f, 400, 2) * dsp.mag_lowpass(f, 2200, 2)
        chans.append(dsp.tv_filter(wh[:, c], gain, n_fft=2048, hop=512))
    wh = np.stack(chans, axis=1) * (0.08 + 0.92 * gust ** 1.6)
    wh *= 0.5 / rms(wh)

    # (d) sparse leaf/twig ticks, 0.5-3 per second, only while a gust is up
    ticks = np.zeros((n + nsamp(0.05), 2))
    dt, g0, t = 0.01, 0.45, 0.0
    n_ticks, gust_time, tick_times = 0, 0.0, []
    while t < total:
        gl = float(np.interp(t, tc, gust_c))
        lam = 0.0 if gl < g0 else 0.5 + 2.5 * (gl - g0) / (1.0 - g0)
        gust_time += dt if gl >= g0 else 0.0
        if r.random() < lam * dt:
            th = r.uniform(0.12, np.pi / 2 - 0.12)
            a = r.uniform(0.35, 1.0)
            for k in range(1 + int(r.random() < 0.3) * int(r.integers(1, 3))):
                y = _wind_tick(r) * a * (0.55 if k else 1.0)
                tt = t + r.uniform(0, dt) + (k * r.uniform(0.02, 0.08) if k else 0.0)
                dsp.place(ticks, np.stack([np.cos(th) * y, np.sin(th) * y], axis=1), tt)
                tick_times.append(tt)
                n_ticks += 1
        t += dt
    ticks = ticks[:n] * TICK_GAIN * rms(bed + hiss + wh)

    if debug is not None:
        debug.update(bed=bed, hiss=hiss, wh=wh, ticks=ticks, tick_times=np.array(tick_times),
                     gust=gust, lag_c=lag_c, tc=tc)
    x = bed + hiss + wh + ticks
    return finish_loop(x, xfade), {"ticks": n_ticks, "ticks_per_s_in_gusts": round(n_ticks / max(gust_time, 1e-9), 2),
                                   "gust_time_s": round(gust_time, 1)}



# =========================================================================== birds

# Each wood-thrush phrase: intro notes (f_start, f_end, amp, dur), gaps between notes,
# gap before the trill, trill (tone_a, tone_b, alternation Hz, dur, level), vibrato (Hz, depth).
THRUSH_PHRASES = [
    dict(notes=[(1850, 1920, 0.55, 0.080), (2650, 2500, 1.00, 0.135), (2150, 2260, 0.80, 0.105),
                (3200, 3050, 0.90, 0.145)],
         gaps=[0.030, 0.022, 0.030], pre=0.050, trill=(4600, 5500, 42.0, 0.42, 0.70), vib=(24.0, 0.016)),
    dict(notes=[(2400, 2300, 0.85, 0.150), (1700, 1760, 0.60, 0.130), (2950, 3150, 1.00, 0.150)],
         gaps=[0.036, 0.030], pre=0.065, trill=(5200, 4300, 34.0, 0.44, 0.65), vib=(21.0, 0.018)),
    dict(notes=[(1600, 1660, 0.45, 0.070), (2000, 1950, 0.60, 0.085), (2800, 2700, 1.00, 0.125),
                (2300, 2400, 0.75, 0.095), (3400, 3280, 0.85, 0.115)],
         gaps=[0.020, 0.025, 0.020, 0.028], pre=0.045, trill=(4800, 5800, 55.0, 0.40, 0.70), vib=(28.0, 0.012)),
]


def bird_thrush(r: np.random.Generator, v: int):
    P = THRUSH_PHRASES[v % len(THRUSH_PHRASES)]
    fj = lambda: r.uniform(0.97, 1.03)  # noqa: E731
    notes, t = [], 0.01
    for i, (f0, f1, a, d) in enumerate(P["notes"]):
        d *= r.uniform(0.92, 1.08)
        s = fj()
        notes.append((t, d, f0 * s, f1 * s, a * r.uniform(0.9, 1.0), 0.010, 0.022))
        t += d + (P["gaps"][i] if i < len(P["gaps"]) else 0.0)
    t_tr = t + P["pre"]
    fa, fb, alt, dtr, lvl = P["trill"]
    fa, fb, dtr = fa * fj(), fb * fj(), dtr * r.uniform(0.92, 1.08)
    n = nsamp(t_tr + dtr + 0.02)
    ta = np.arange(n) / SR

    freq, amp = tone_tracks(notes, n, glide=0.012, bridge=0.15)
    vr, vd = P["vib"]
    freq = freq * (1.0 + vd * np.sin(TWO_PI * vr * ta + r.uniform(0, TWO_PI)))
    intro = whistle(freq, amp, -12.0)

    # trill: a rapid series of short slurred elements alternating between a high and a low
    # tone (`alt` full cycles per second, i.e. 2*alt elements/s). Soft tanh switching, each
    # element glides down ~5 % and carries its own +-2 % pitch, the element rate wanders +-3 %,
    # and the level dips smoothly between elements.
    m = nsamp(dtr)
    rate = alt * (1.0 + 0.03 * dsp.smooth_noise(m, 12.0, r))
    ph_c = np.cumsum(rate) / SR
    s = np.sin(TWO_PI * ph_c)
    cyc = np.floor(2.0 * ph_c).astype(int)                    # element index
    frac = 2.0 * ph_c - cyc                                   # position inside the element
    jit = 1.0 + 0.02 * r.uniform(-1.0, 1.0, int(cyc.max()) + 2)
    ftr = 0.5 * (fa + fb) + 0.5 * (fb - fa) * np.tanh(2.0 * s) / np.tanh(2.0)
    ftr = ftr * jit[cyc] * (1.0 + 0.05 * (0.5 - frac))
    k = nsamp(0.0015)                                         # soften the element-boundary pitch steps
    ftr = np.convolve(np.pad(ftr, k, mode="edge"), np.hanning(2 * k + 1) / np.hanning(2 * k + 1).sum(),
                      mode="same")[k:-k]
    am = 0.3 + 0.7 * (1.0 - np.exp(-5.0 * s * s))
    env = bp_env(m, [0, 0.015, 0.45 * dtr, dtr - 0.04, dtr], [0, 0.85, 1.0, 0.8, 0]) * lvl
    trill = whistle(ftr, am * env, -12.0)
    x = intro
    dsp.place(x, trill, t_tr)

    x = distance(x, r, 6000.0, 4, 0.6, -12.0)
    return finish(x, -60.0, 0.05, loud_db=BIRD_LOUD_DB), {"notes": len(notes), "trill_hz": alt}


def bird_chickadee(r: np.random.Generator, v: int):
    if v % 2 == 0:
        # "fee-bee": 4.0 kHz for 250 ms, 60 ms gap, 3.6 kHz for 300 ms bending slightly down
        s = r.uniform(0.985, 1.015)
        d1, gap, d2 = 0.25, 0.06, 0.30
        n = nsamp(0.01 + d1 + gap + d2 + 0.02)
        freq, amp = tone_tracks([(0.01, d1, 4000 * s, 3975 * s, 1.0, 0.025, 0.03),
                                 (0.01 + d1 + gap, d2, 3600 * s, 3440 * s, 0.82, 0.02, 0.05)],
                                n, glide=0.004, bridge=0.0)
        # a little life in the whistle: an irregular +-0.5 % pitch wobble centred on 6-8 Hz, a
        # +-1 dB level waver and a 2nd harmonic at -24 dB, so it reads as a bird, not a test tone
        # (band-limited noise: ctrl_noise's smoothing flattens a 6-8 Hz rate over a 0.6 s call)
        def wobble(lo, hi):
            w = dsp.fft_filter(r.standard_normal(n), lambda f: dsp.mag_bandpass(f, lo, hi, 2), minphase=False)
            return w / (np.percentile(np.abs(w), 95) + 1e-12)
        fw = r.uniform(6.0, 8.0)
        freq = freq * (1.0 + 0.005 * wobble(fw / 1.3, fw * 1.3))
        amp = amp * (1.0 + 0.12 * wobble(6.0, 14.0))
        x = whistle(freq, amp, -24.0)
        info = {"call": "fee-bee"}
    else:
        # "chick-a-dee-dee": 2 short 7 kHz chips, then 3 buzzy 4 kHz notes (noise AM near 150 Hz)
        n = nsamp(0.80)
        x = np.zeros(n)
        for tc_, a in [(0.01, 0.75), (0.085, 0.65)]:
            m = nsamp(0.032)
            u = np.arange(m) / m
            f = 7000.0 * r.uniform(0.98, 1.02) * (1.08 - 0.16 * u ** 0.7)
            e = dsp.ar_env(m, 0.002, 0.012) * dsp.fade_out(np.ones(m), 0.008)
            dsp.place(x, a * whistle(f, e, -20.0), tc_)
        t = 0.17
        for k in range(3):
            d = r.uniform(0.12, 0.14)
            m = nsamp(d)
            u = np.arange(m) / m
            f = 4000.0 * r.uniform(0.985, 1.015) * (1.02 - 0.04 * u)
            mod = dsp.fft_filter(r.standard_normal(m), lambda ff: dsp.mag_bandpass(ff, 100.0, 210.0, 4),
                                 minphase=False)                      # noise band around 150 Hz
            am = 0.5 + 0.5 * np.tanh(1.6 * mod / rms(mod))            # deep, smooth (band-limited) AM
            e = bp_env(m, [0, 0.012, d * 0.6, d - 0.025, d], [0, 1.0, 0.9, 0.75, 0])
            carrier = harmonic_osc(f, [1.0, db2lin(-10), db2lin(-18)])
            dsp.place(x, (0.95 - 0.07 * k) * carrier * am * e, t)
            t += d + r.uniform(0.045, 0.06)
        info = {"call": "chick-a-dee-dee"}
    x = distance(x, r, 9000.0, 2, 0.6, -14.0)
    return finish(x, -60.0, 0.08, max_len=0.85, loud_db=BIRD_LOUD_DB), info


def bird_warbler(r: np.random.Generator, v: int):
    rate = (14.0 if v % 2 == 0 else 17.0) * r.uniform(0.97, 1.03)
    count = int(round(rate * 1.07))
    T = (count - 1) / rate + 0.025
    n = nsamp(T + 0.05)
    x = np.zeros(n)
    peak_u, end_lvl = (0.72, 0.25) if v % 2 == 0 else (0.66, 0.3)
    expo = 0.8 if v % 2 == 0 else 1.4                      # sweep curvature per variant
    for k in range(count):
        tk = 0.01 + k / rate * (1.0 + 0.03 * r.uniform(-1, 1))
        u = tk / T
        rise = 1.0 + 0.10 * np.clip((u - 0.3) / 0.7, 0.0, 1.0) ** 2        # ~10 % higher at the end
        lvl = float(np.interp(u, [0.0, peak_u, 1.0], [0.35, 1.0, end_lvl]))   # crescendo, drop-off
        d = 0.025 * r.uniform(0.95, 1.05)
        m = nsamp(d)
        w = np.arange(m) / m
        f = rise * (5000.0 + 2000.0 * w ** expo) * r.uniform(0.99, 1.01)
        e = np.sin(np.pi * w ** 0.75) ** 1.2
        dsp.place(x, lvl * r.uniform(0.9, 1.0) * whistle(f, e, -18.0), tk)
    x = distance(x, r, 9000.0, 2, 0.6, -15.0)
    return finish(x, -55.0, 0.04, loud_db=BIRD_LOUD_DB), {"chirps": count, "rate": round(rate, 2)}


# =========================================================================== crow

def _caw(r: np.random.Generator, dur: float, f_start: float, f_peak: float, f_end: float,
         fry_depth: float = 0.6) -> np.ndarray:
    n = nsamp(dur)
    f = bp_env(n, [0, 0.12 * dur, 0.35 * dur, dur], [f_start, f_start * 1.04, f_peak, f_end])
    f = f * (1.0 + 0.03 * dsp.smooth_noise(n, 35.0, r) + 0.01 * dsp.smooth_noise(n, 120.0, r))
    src = np.tanh(2.0 * saw_osc(f, 9000.0))                 # harsh, harmonic
    fry = 80.0 * (1.0 + 0.1 * dsp.smooth_noise(n, 15.0, r))  # vocal-fry AM near 80 Hz
    pulse = (0.5 + 0.5 * np.cos(TWO_PI * np.cumsum(fry) / SR)) ** 3
    am = (1.0 - fry_depth) + fry_depth * pulse
    noise = r.standard_normal(n) * am
    src = src * am
    src = src + noise * 0.2 * rms(src) / rms(noise)          # 20 % noise
    env = bp_env(n, [0, 0.025, 0.6 * dur, dur - 0.06, dur], [0, 1.0, 0.85, 0.7, 0])
    return src * env


def crow_caw(r: np.random.Generator, v: int):
    if v % 2 == 0:
        caws = [(0.26, 520, 640, 540, 1.0), (0.25, 510, 625, 530, 0.9), (0.23, 500, 605, 515, 0.8)]
        spacing, fry = 0.35, 0.6
    else:
        caws = [(0.27, 500, 585, 505, 1.0), (0.25, 495, 570, 500, 0.85)]
        spacing, fry = 0.37, 0.72
    total = spacing * (len(caws) - 1) + 0.3 + 0.02
    x = np.zeros(nsamp(total))
    for i, (d, fs, fp, fe, a) in enumerate(caws):
        s = r.uniform(0.98, 1.02)
        c = _caw(r, d * r.uniform(0.95, 1.05), fs * s, fp * s, fe * s, fry)
        dsp.place(x, a * c, 0.01 + i * spacing + r.uniform(-0.02, 0.02))
    formants = lambda f: (0.06 + dsp.mag_resonance(f, 1100, 5.0) + 0.7 * dsp.mag_resonance(f, 1900, 6.0)  # noqa: E731
                          + 0.5 * dsp.mag_resonance(f, 2800, 7.0))
    x = dsp.fft_filter(x, formants, tail=0.03)
    x = distance(x, r, 3500.0, 4, 1.0, -10.0, predelay=0.025)
    return finish(x, -50.0, 0.15, max_len=1.35, loud_db=BIRD_LOUD_DB), {"caws": len(caws)}


# =========================================================================== woodpecker

def woodpecker_drum(r: np.random.Generator, v: int):
    count, (r0, r1) = [(17, (16.3, 18.8)), (21, (17.2, 20.0))][v % 2]
    times, t = [], 0.01
    for k in range(count):
        times.append(t)
        rate = r0 + (r1 - r0) * (k / (count - 1)) ** 1.3        # speeding up slightly
        t += (1.0 / rate) * (1.0 + 0.02 * r.uniform(-1, 1))
    x = np.zeros(nsamp(t + 0.1))
    ex = dsp.mallet(0.0005)
    for k, tk in enumerate(times):
        u = k / (count - 1)
        a = (1.0 - 0.65 * u ** 1.4) * (0.85 if k == 0 else 1.0) * r.uniform(0.9, 1.1)   # fading
        s = r.uniform(0.99, 1.01)
        h = dsp.modal_ir([600 * s, 1350 * s * r.uniform(0.99, 1.01), 2400 * s * r.uniform(0.99, 1.01)],
                         [0.012, 0.012, 0.012], [1.0, 0.5 * r.uniform(0.85, 1.15), 0.28 * r.uniform(0.85, 1.15)],
                         0.08)
        knock = dsp.fftconvolve(ex, h)
        click = r.standard_normal(nsamp(0.0008)) * np.hanning(nsamp(0.0008))
        knock[:len(click)] += 0.12 * np.max(np.abs(knock)) * click
        dsp.place(x, a * knock, tk)
    # tight early field: the reverb must not put a second arrival 12-40 ms after a knock (the knock
    # period is ~55 ms), or every knock flams and the roll reads as a double-rate rattle. The few
    # early taps sit within 9 ms, where they fuse with the 12 ms knock ring; with taps spread to
    # 20 ms some seeds put a -5 dB copy ~18 ms after every knock.
    x = distance(x, r, 6000.0, 2, 0.8, -10.0, predelay=0.006, build=0.010, n_early=4,
                 early_span=(0.0015, 0.009))
    # end 0.3 s after the last knock; the 0.2 s fade covers only the reverb tail
    return (finish(x, -50.0, 0.2, max_len=times[-1] + 0.3, loud_db=BIRD_LOUD_DB),
            {"knocks": count, "rate": "%.1f->%.1f Hz" % (r0, r1)})


# =========================================================================== birds_flush

def birds_flush(r: np.random.Generator, v: int):
    birds = [4, 6][v % 2]
    T = 1.65
    n = nsamp(T)
    ex = np.zeros(n + nsamp(0.05))
    for _ in range(birds):
        # the flock leaves in a cascade over ~0.45 s and each bird keeps flapping as it climbs away
        s, rate0 = r.uniform(0.0, 0.45), r.uniform(12.0, 18.0)
        level, tau = r.uniform(0.55, 1.0), r.uniform(1.3, 2.2)
        t, k = s + r.uniform(0, 1.0 / rate0), 0
        while t < T:
            el = t - s
            rate = rate0 * (1.0 - 0.12 * min(1.0, el / 1.2))
            d = r.uniform(0.015, 0.030)
            m = nsamp(d)
            e = dsp.ar_env(m, r.uniform(0.002, 0.004), d / 3.5) * dsp.fade_out(np.ones(m), 0.003)
            a = level * np.exp(-el / tau) * r.uniform(0.75, 1.0) * (1.35 if k < 3 else 1.0)
            dsp.place(ex, a * r.standard_normal(m) * e, t)
            t += (1.0 / rate) * (1.0 + 0.06 * r.uniform(-1, 1))
            k += 1
    flaps = dsp.fft_filter(ex, lambda f: dsp.mag_lowpass(f, 2000, 4) * dsp.mag_highpass(f, 90, 2))
    flaps /= np.max(np.abs(flaps))

    chips = np.zeros_like(flaps)
    n_chips = [4, 5][v % 2]
    for tc_ in np.sort(r.uniform(0.06, 0.85, n_chips)):
        d = r.uniform(0.02, 0.04)
        m = nsamp(d)
        w = np.arange(m) / m
        f0 = r.uniform(4300, 5000)
        f = f0 + (max(3050.0, f0 * r.uniform(0.68, 0.8)) - f0) * w ** 0.6
        e = dsp.ar_env(m, 0.0015, d / 3.0) * dsp.fade_out(np.ones(m), 0.004)
        dsp.place(chips, r.uniform(0.3, 0.5) * np.exp(-tc_ / 0.9) * whistle(f, e, -14.0), tc_)

    x = flaps + chips
    # closing lowpass (9 kHz -> 800 Hz) and falling level as the flock flies off
    x = dsp.tv_filter(x, lambda t, f: dsp.mag_lowpass(f, 9000.0 * (800.0 / 9000.0) ** np.clip(t / 1.5, 0, 1), 2),
                      n_fft=1024, hop=256)
    ta = np.arange(len(x)) / SR
    x *= np.where(ta < 0.45, 1.0, np.exp(-(ta - 0.45) / 0.45))
    return finish(x, -60.0, 0.15, max_len=1.6, loud_db=FLUSH_LOUD_DB), {"birds": birds, "chips": n_chips}


# =========================================================================== tree_creak

# (slip-excitation span s (the file ends ~0.05 s after it), rate breakpoints as fractions of the duration, slips/s, swell breakpoints, swell)
CREAKS = [
    (1.62, [0, 0.35, 0.7, 1], [16, 30, 36, 20], [0, 0.15, 0.5, 0.8, 1], [0, 0.45, 1.0, 0.7, 0]),
    (1.95, [0, 0.3, 0.55, 0.8, 1], [22, 38, 26, 33, 18], [0, 0.2, 0.4, 0.75, 1], [0, 0.6, 1.0, 0.8, 0]),
    (2.3, [0, 0.5, 1], [15, 27, 17], [0, 0.25, 0.55, 0.85, 1], [0, 0.5, 1.0, 0.55, 0]),
]


def tree_creak(r: np.random.Generator, v: int):
    T, rt, rv, st, sv = CREAKS[v % len(CREAKS)]
    T *= r.uniform(0.95, 1.05)
    rv = np.clip(np.asarray(rv, float) * r.uniform(0.9, 1.1), 15.0, 40.0)
    rate_fn = lambda t: float(np.interp(t / T, rt, rv))  # noqa: E731
    swell_c = bp_env(nsamp(T) + 1, np.asarray(st) * T, sv)
    amp_fn = lambda t: float(swell_c[min(int(t * SR), len(swell_c) - 1)])  # noqa: E731
    imp = dsp.stick_slip_train(T, rate_fn, r, jitter=0.12, amp=amp_fn, amp_jitter=0.35)
    k = np.arange(nsamp(0.003)) / SR
    slip = np.exp(-k / 0.0005) * (1.0 - np.exp(-k / 0.0001))  # sharp release pulse
    slip /= slip.max()
    ex = dsp.fftconvolve(imp, slip)[:len(imp)]

    # trunk modes, scaled and detuned per variant (a different tree each time), which rise 2-3 % with the
    # bending load: each slip rings the modes as tuned at the moment it happens
    size = [1.0, 0.93, 1.07][v % 3] * r.uniform(0.98, 1.02)          # trunk size per variant
    freqs = np.array([120.0, 260.0, 430.0]) * size * r.uniform(0.97, 1.03, 3)
    q = 20.0
    taus = q / (np.pi * freqs)
    gains = np.array([1.0, 0.7, 0.45]) * r.uniform(0.8, 1.2, 3) * 2.0 / (taus * SR)  # unity peak gain
    drift = r.uniform(0.02, 0.03)
    y = np.zeros(len(imp) + nsamp(0.4) + len(slip))
    for i in np.flatnonzero(imp):
        sc = 1.0 + drift * (2.0 * swell_c[min(i, len(swell_c) - 1)] - 1.0)
        dsp.place(y, imp[i] * np.convolve(slip, dsp.modal_ir(freqs * sc, taus, gains, 0.4)), i / SR)

    # faint friction grit riding on the slips (wood fibre texture)
    grit_env = np.zeros(len(y))
    dsp.place(grit_env, dsp.fftconvolve(np.abs(ex), np.hanning(nsamp(0.003))), 0.0)
    grit = dsp.fft_filter(r.standard_normal(len(y)), lambda f: dsp.mag_bandpass(f, 700, 2600, 2)) * grit_env
    y = y + grit * 0.06 * rms(y) / (rms(grit) + 1e-20)
    y = dsp.fft_filter(y, lambda f: dsp.mag_highpass(f, 50, 2))
    return (finish(y, -55.0, 0.1, max_len=2.5, loud_db=CREAK_LOUD_DB),
            {"dur": round(T, 2), "rate": "%d-%d/s" % (rv.min(), rv.max()),
             "modes_hz": [int(round(f)) for f in freqs], "drift": "+-%.1f%%" % (100 * drift)})


# =========================================================================== flag_flutter_loop

def _wrap_add(buf: np.ndarray, n: int) -> np.ndarray:
    """Fold everything past sample n back onto the head (circular buffer of period n)."""
    y = np.array(buf[:n], copy=True)
    over = buf[n:]
    y[:len(over)] += over
    return y


def flag_flutter_loop(r: np.random.Generator, v: int, debug: dict | None = None):
    """Wool flag on the fort pole. Built exactly periodic (no crossfade): events are laid on a
    6 s circle, overhang wraps onto the head, the wind control is a sum of harmonics of 1/6 Hz
    and every filter runs circularly, so the wrap is just another moment of the same flutter."""
    L = 6.0
    n = nsamp(L)
    tt = np.arange(n) / SR

    # periodic wind control in [0, 1]: harmonics 1-3 of 1/6 Hz plus low-depth wander up to 2 Hz
    w = np.zeros(n)
    for k in range(1, 13):
        a = [1.0, 0.8, 0.5][k - 1] if k <= 3 else 0.3 * r.uniform(0.5, 1.0) / np.sqrt(k)
        w += a * np.sin(TWO_PI * k * tt / L + r.uniform(0.0, TWO_PI))
    w = (w - w.min()) / (w.max() - w.min())

    # flap times: gamma(4.5)-spaced at 5-8 per second (45 ms .. 1.8x the mean apart), generated over
    # one turn of the circle starting at s0 and stretched (by ~1-3 %) so that the interval across
    # the wrap is an ordinary draw too
    s0 = r.uniform(0.0, 0.2)
    times, t = [], s0
    while True:
        times.append(t)
        rate = 5.0 + 3.0 * float(w[int(t * SR) % n])
        t += float(np.clip(r.gamma(4.5, 1.0 / (4.5 * rate)), 0.045, 1.8 / rate))
        if t >= s0 + L:
            break
    times = s0 + (np.array(times) - s0) * L / (t - s0)

    flaps = np.zeros(n + nsamp(0.1))
    env = np.zeros(n + nsamp(0.5))
    env_k = dsp.ar_env(nsamp(0.45), 0.005, 0.08)             # flap envelope: 5 ms attack, 80 ms release
    for te in times:
        te %= L
        ww = float(w[int(te * SR) % n])
        d = r.uniform(0.010, 0.025)
        m = nsamp(d)
        u = r.random()
        a = (0.45 + 0.55 * u) * (0.6 + 0.4 * ww)
        fc = 300.0 * (2000.0 / 300.0) ** (0.3 * r.random() + 0.7 * u)   # stronger snaps are brighter
        e = dsp.ar_env(m, r.uniform(0.0008, 0.002), d / 3.0) * dsp.fade_out(np.ones(m), 0.003)
        burst = dsp.fft_filter(r.standard_normal(m) * e, lambda f: dsp.mag_lowpass(f, fc, 2), tail=0.012)
        burst /= np.max(np.abs(burst)) + 1e-12
        for _ in range(int(r.integers(1, 4))):              # wool fibre crackle: tiny 2-5 kHz noise grains
            g = nsamp(r.uniform(0.0003, 0.0008))
            grain = dsp.fft_filter(r.standard_normal(g) * np.hanning(g),
                                   lambda f: dsp.mag_highpass(f, 2000.0, 2) * dsp.mag_lowpass(f, 5000.0, 2),
                                   tail=0.001)
            grain *= r.choice([-1.0, 1.0]) * r.uniform(0.08, 0.2) / (np.max(np.abs(grain)) + 1e-12)
            dsp.place(burst, grain, r.uniform(0.0, d))
        dsp.place(flaps, a * burst, te)
        dsp.place(env, a * env_k, te)
    flaps = _wrap_add(flaps, n)
    env = _wrap_add(env, n)
    env = np.clip(env / np.percentile(env, 98), 0.0, 1.0)

    # dull wool rustle, 800 Hz - 4 kHz, riding on the flaps rather than hissing on its own
    rustle = dsp.fft_filter(r.standard_normal(n), lambda f: dsp.mag_highpass(f, 800, 2) * dsp.mag_lowpass(f, 4000, 4),
                            circular=True)
    rustle *= (0.35 + 0.65 * env) * (0.85 + 0.15 * w)
    rustle *= rms(flaps) * db2lin(-12.0) / rms(rustle)      # rustle 12 dB under the flaps
    if debug is not None:
        debug.update(flaps=flaps, rustle=rustle, env=env, w=w, times=np.sort(times % L))
    x = dsp.fft_filter(flaps + rustle, lambda f: dsp.mag_highpass(f, 40, 2), circular=True)
    return finish_loop(x), {"flaps": len(times), "flaps_per_s": round(len(times) / L, 2)}


# =========================================================================== river loops

def _bubbles(n: int, L: float, rate: float, f_lo: float, f_hi: float, r: np.random.Generator,
             tau=(0.004, 0.02), rise=(0.1, 0.35)):
    """Bubble plinks on a circle of L s (Poisson at `rate` a second): each a damped sine rising 10-35 % in pitch as
    it goes (the bubble nearing the surface), pitch log-uniform in f_lo..f_hi, the bigger (lower) ones louder."""
    buf = np.zeros(n + nsamp(0.15))
    t = r.uniform(0.0, 1.0 / rate)
    count = 0
    while t < L:
        f0 = f_lo * (f_hi / f_lo) ** r.random()
        d = r.uniform(*tau)
        m = nsamp(d * 5.0)
        tt = np.arange(m) / SR
        f = f0 * (1.0 + r.uniform(*rise) * np.minimum(tt / (3.0 * d), 1.0))
        b = np.sin(TWO_PI * np.cumsum(f) / SR) * np.exp(-tt / d) * (1.0 - np.exp(-tt / 0.0006))
        dsp.place(buf, b * float(np.exp(r.normal(0.0, 0.6))) * (800.0 / f0) ** 0.3, t)
        count += 1
        t += r.exponential(1.0 / rate)
    return _wrap_add(buf, n), count


def _surge(n: int, L: float, r: np.random.Generator, harmonics: int = 8) -> np.ndarray:
    """A slow periodic swell in [0, 1] (harmonics of 1/L)."""
    tt = np.arange(n) / SR
    w = np.zeros(n)
    for k in range(1, harmonics + 1):
        w += np.sin(TWO_PI * k * tt / L + r.uniform(0.0, TWO_PI)) / k
    return (w - w.min()) / (w.max() - w.min())


def _band_noise(n: int, lo: float, hi: float, r: np.random.Generator, tilt: float = 0.5) -> np.ndarray:
    """Circularly filtered noise lo..hi Hz, tilted down `tilt` (0 white, 0.5 pink-ish)."""
    return dsp.fft_filter(r.standard_normal(n), lambda f: dsp.mag_highpass(f, lo, 2) * dsp.mag_lowpass(f, hi, 2)
                          * (np.maximum(f, 20.0) / 200.0) ** (-tilt), circular=True)


def river_flow_loop(r: np.random.Generator, v: int, debug: dict | None = None):
    """The river running: a bed of water noise (120 Hz - 2.5 kHz) swelling a little, bubbles 4 dB under it (45 a
    second, 350 Hz - 2.2 kHz), a thin hiss of spray 18 dB under. Exactly periodic (8 s)."""
    L = 8.0
    n = nsamp(L)
    w = _surge(n, L, r)
    bed = _band_noise(n, 120.0, 2500.0, r) * (0.75 + 0.25 * w)
    hiss = _band_noise(n, 3000.0, 9000.0, r, tilt=0.0)
    bub, count = _bubbles(n, L, 45.0, 350.0, 2200.0, r)
    bub = dsp.fft_filter(bub, lambda f: dsp.mag_highpass(f, 200.0, 2), circular=True)
    bub *= rms(bed) * db2lin(-4.0) / rms(bub)
    hiss *= rms(bed) * db2lin(-18.0) / rms(hiss)
    x = dsp.fft_filter(bed + bub + hiss, lambda f: dsp.mag_highpass(f, 40.0, 2), circular=True)
    return finish_loop(x), {"bubbles": count, "per_s": round(count / L, 1)}


def river_rapids_loop(r: np.random.Generator, v: int, debug: dict | None = None):
    """White water: a broad roar (80 Hz - 6 kHz) surging deeper, bright hiss 8 dB under, dense bubbles (260 a second,
    250 Hz - 3 kHz) 6 dB under, splash bursts (6 a second, 600 Hz - 6 kHz) 6 dB under. Exactly periodic (6 s)."""
    L = 6.0
    n = nsamp(L)
    w = _surge(n, L, r, harmonics=12)
    roar = _band_noise(n, 80.0, 6000.0, r, tilt=0.35) * (0.6 + 0.4 * w)
    hiss = _band_noise(n, 2500.0, 10000.0, r, tilt=0.0) * (0.7 + 0.3 * w)
    bub, count = _bubbles(n, L, 260.0, 250.0, 3000.0, r, tau=(0.003, 0.012))
    spl = np.zeros(n + nsamp(0.2))
    t = r.uniform(0.0, 0.2)
    splashes = 0
    while t < L:
        m = nsamp(r.uniform(0.02, 0.06))
        burst = dsp.fft_filter(r.standard_normal(m) * dsp.ar_env(m, 0.002, m / SR / 3.0),
                               lambda f: dsp.mag_highpass(f, 600.0, 2) * dsp.mag_lowpass(f, 6000.0, 2), tail=0.01)
        dsp.place(spl, burst * r.uniform(0.4, 1.0), t)
        splashes += 1
        t += r.exponential(1.0 / 6.0)
    spl = _wrap_add(spl, n)
    for part, db in ((hiss, -8.0), (bub, -6.0), (spl, -6.0)):
        part *= rms(roar) * db2lin(db) / (rms(part) + 1e-12)
    x = dsp.fft_filter(roar + hiss + bub + spl, lambda f: dsp.mag_highpass(f, 40.0, 2), circular=True)
    return finish_loop(x), {"bubbles": count, "splashes": splashes}


# =========================================================================== registry / CLI

# id, variants, generator, is_loop
SOUNDS = [
    ("forest_wind_loop", 1, forest_wind_loop, True),
    ("bird_thrush", 3, bird_thrush, False),
    ("bird_chickadee", 2, bird_chickadee, False),
    ("bird_warbler", 2, bird_warbler, False),
    ("crow_caw", 2, crow_caw, False),
    ("woodpecker_drum", 2, woodpecker_drum, False),
    ("birds_flush", 2, birds_flush, False),
    ("tree_creak", 3, tree_creak, False),
    ("flag_flutter_loop", 1, flag_flutter_loop, True),
    ("river_flow_loop", 1, river_flow_loop, True),
    ("river_rapids_loop", 1, river_rapids_loop, True),
]


def main(argv=None) -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, default=1754, help="base seed; change for new variations")
    ap.add_argument("--out", default=OUT_DIR, help="output directory")
    ap.add_argument("--only", nargs="*", default=None, help="sound ids to (re)generate")
    a = ap.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)
    for si, (sid, variants, gen, is_loop) in enumerate(SOUNDS):
        if a.only and sid not in a.only:
            continue
        for v in range(variants):
            seed = a.seed * 1000 + si * 50 + v
            x, info = gen(dsp.rng(seed), v)
            path = os.path.join(a.out, NAME_FMT.format(id=sid, n=v + 1))
            if is_loop:
                dsp.write_wav_loop(path, x, 0, len(x) - 1, seed=seed)
            else:
                dsp.write_wav(path, x, seed=seed)
            pk = dsp.lin2db(float(np.max(np.abs(x))))
            print("%-28s %6.2f s  %s  peak %5.1f dBFS  %s" % (
                os.path.basename(path), len(x) / SR, "stereo" if x.ndim == 2 else "mono  ", pk, info))


if __name__ == "__main__":
    main()
