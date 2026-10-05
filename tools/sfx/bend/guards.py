"""Round 2's sounds for Tidebreak (tools/sfx/bend/bend_sfx.py writes them; scripts/bending/bend_sounds.gd plays them): each
element's guard on the beat and late, so the guarder hears which (spec §2.5: "a bright flash, a sharp crack ... the word
Clean"), and the lock's own: the grow's second click, the sputter on the hands, Carried wind's whistle. Synthesized here with
numpy like the rest (kit.py on tools/sfx/dsp.py); nothing recorded or downloaded.

  guard_earth_clean   a clean catch: the stone stopped dead with a sharp crack over the thunk, a high stony ring (the
                      late catch keeps stone_catch's dull thock)
  guard_water_clean   a Turn on the beat: a quick rising swirl of water snapping round, a bright splash-snap
  guard_water_late    a Turn late: a heavy slosh, the water half through
  guard_fire_clean    a Parry on the beat: a crisp flame snap, a hot crack and a short ring
  guard_fire_late     a Parry late: a smothered whoomph
  guard_air_clean     a Wind Guard on the beat: a taut whip of air and a clean snap back
  guard_air_late      a Wind Guard late: a soft buffet
  lock_grow           grow's second click: a deeper, rounder wood-and-stone knock than the lock's click
  lock_sputter        a held lock fizzing out on the hands: a short crackling fizz, dying
  carried_whistle     Carried wind: a rising whistle over a little rush of air
"""
from __future__ import annotations

import math

import numpy as np

from kit import N, T, band, bubbles, crack, crackles, dsp, grit, hump, lowpass_sweep, mix, noise, rock, sweep, thump, tick


def _snap(r, bright: float = 1.0) -> np.ndarray:
    """A short bright crack: a few clicks very close together through a high band."""
    m = N(0.03)
    x = np.zeros(m)
    for k in range(3):
        c = band(noise(N(0.004), r), 1800.0 * bright, 12000.0, 2) * dsp.exp_env(N(0.004), 0.0008)
        dsp.place(x, c, k * r.uniform(0.002, 0.005), 1.0 - 0.25 * k)
    return x


def guard_earth_clean(r) -> np.ndarray:
    dur = r.uniform(0.55, 0.7)
    n = N(dur)
    return mix(n, (crack(r, 1.7, r.integers(3, 5), 0.006), 0.0, 1.0),
               (rock(r, r.uniform(260.0, 340.0), 0.35, ring=2.2, contact=0.0008, rough=0.2), 0.0, 0.9),
               (thump(r.uniform(80.0, 92.0), 50.0, 0.08, 0.35, glide=0.03, attack=0.002), 0.0, 0.9),
               (_snap(r, 1.3), 0.0, 0.7), (tick(r, 3000.0, 6000.0), 0.004, 0.35),
               (grit(r, n, 14, 0.01, 0.2, decay=0.06, f_lo=2200.0), 0.0, 0.12))


def guard_water_clean(r) -> np.ndarray:
    dur = r.uniform(0.6, 0.8)
    n = N(dur)
    swirl = sweep(r, dur, [0.0, 0.12, 0.3, dur], [500.0, 1600.0, 2600.0, 900.0], 0.6) * hump(n, 0.16, 0.12, 1.4)
    snap = band(noise(N(0.012), r), 1500.0, 10000.0, 2) * dsp.exp_env(N(0.012), 0.002)
    return mix(n, (swirl, 0.0, 1.0), (snap, 0.17, 0.9), (_snap(r, 1.1), 0.17, 0.5),
               (bubbles(r, n, 22, 0.05, dur - 0.1, 800.0, 3200.0), 0.0, 0.3))


def guard_water_late(r) -> np.ndarray:
    dur = r.uniform(0.5, 0.7)
    n = N(dur)
    body = sweep(r, dur, [0.0, 0.08, dur], [260.0, 700.0, 300.0], 0.9) * hump(n, 0.08, 0.14, 1.5)
    return mix(n, (body, 0.0, 1.0), (thump(70.0, 45.0, 0.08, 0.3), 0.0, 0.5),
               (bubbles(r, n, 30, 0.02, dur, 250.0, 900.0, decay=0.2), 0.0, 0.4))


def guard_fire_clean(r) -> np.ndarray:
    dur = r.uniform(0.5, 0.65)
    n = N(dur)
    flare = lowpass_sweep(r, dur, [0.0, 0.01, 0.07, dur], [800.0, 5200.0, 1600.0, 400.0], 2,
                          src=0.5 * dsp.brown(n, r) + 0.5 * noise(n, r))
    flare = flare / (np.std(flare) + 1e-12) * hump(n, 0.01, 0.07, 1.0)
    ring = dsp.damped_sine(dur, r.uniform(1900.0, 2300.0), 0.08) * 0.4 + dsp.damped_sine(dur, r.uniform(3100.0, 3500.0), 0.05) * 0.2
    return mix(n, (flare, 0.0, 1.0), (_snap(r, 1.2), 0.0, 0.9), (ring, 0.0, 0.35),
               (crackles(r, n, 60.0 * np.exp(-T(n) / 0.1), bright=1.2), 0.0, 0.35))


def guard_fire_late(r) -> np.ndarray:
    dur = r.uniform(0.45, 0.6)
    n = N(dur)
    body = lowpass_sweep(r, dur, [0.0, 0.03, 0.12, dur], [200.0, 1100.0, 500.0, 200.0], 2,
                         src=0.7 * dsp.brown(n, r) + 0.3 * noise(n, r))
    body = body / (np.std(body) + 1e-12) * hump(n, 0.03, 0.1, 1.0)
    return mix(n, (body, 0.0, 1.0), (thump(r.uniform(90.0, 105.0), 50.0, 0.08, 0.3), 0.0, 0.6),
               (crackles(r, n, 15.0 * np.exp(-T(n) / 0.15)), 0.0, 0.2))


def guard_air_clean(r) -> np.ndarray:
    dur = r.uniform(0.45, 0.6)
    n = N(dur)
    whip = sweep(r, dur, [0.0, 0.07, 0.11, dur], [600.0, 2600.0, 3400.0, 900.0], 0.5) * hump(n, 0.09, 0.06, 2.0)
    back = sweep(r, dur, [0.0, 0.12, dur], [1800.0, 1200.0, 500.0], 0.8) * hump(n, 0.16, 0.12, 1.2)
    whistle = dsp.sine_sweep(n, np.interp(T(n), [0.0, 0.1, dur], [1200.0, 2600.0, 1500.0])) * hump(n, 0.1, 0.06)
    return mix(n, (whip, 0.0, 1.0), (_snap(r, 1.0), 0.1, 0.8), (back, 0.0, 0.6), (whistle, 0.0, 0.05))


def guard_air_late(r) -> np.ndarray:
    dur = r.uniform(0.4, 0.55)
    n = N(dur)
    puff = band(noise(n, r), 120.0, 1600.0, 2) * dsp.ar_env(n, 0.01, 0.08)
    return mix(n, (puff / (np.std(puff) + 1e-12), 0.0, 0.8), (thump(75.0, 50.0, 0.06, 0.25), 0.0, 0.5),
               (sweep(r, dur, [0.0, 0.05, dur], [900.0, 600.0, 300.0], 0.9) * hump(n, 0.04, 0.1, 1.0), 0.0, 0.5))


def lock_grow(r) -> np.ndarray:
    f = r.uniform(420.0, 470.0)
    a = dsp.strike([f, f * 2.3, f * 3.9], [0.09, 0.04, 0.02], [1.0, 0.45, 0.2], 0.35, contact=0.0009, r=r, noise=0.25)
    b = dsp.strike([f * 0.5, f * 1.15], [0.12, 0.05], [0.8, 0.3], 0.35, contact=0.0012, r=r, noise=0.2)
    n = N(0.4)
    return mix(n, (a, 0.0, 1.0), (b, 0.0, 0.8), (thump(110.0, 70.0, 0.05, 0.2), 0.0, 0.4))


def lock_sputter(r) -> np.ndarray:
    dur = r.uniform(0.45, 0.6)
    n = N(dur)
    e = np.exp(-T(n) / (dur * 0.35))
    fizz = band(noise(n, r), 2500.0, 9000.0, 2) * e * (0.6 + 0.4 * np.abs(np.sin(2 * math.pi * r.uniform(18.0, 26.0) * T(n))))
    return mix(n, (fizz / (np.std(fizz) + 1e-12), 0.0, 0.5), (crackles(r, n, 70.0 * e + 2.0, bright=1.3), 0.0, 1.0))


def carried_whistle(r) -> np.ndarray:
    dur = r.uniform(0.7, 0.9)
    n = N(dur)
    f0 = r.uniform(900.0, 1100.0)
    tone = dsp.sine_sweep(n, np.interp(T(n), [0.0, dur * 0.6, dur], [f0, f0 * 2.1, f0 * 1.8])) * hump(n, dur * 0.55, dur * 0.18, 1.5)
    rush = sweep(r, dur, [0.0, dur * 0.5, dur], [400.0, 1400.0, 800.0], 0.8) * hump(n, dur * 0.5, dur * 0.2, 1.5)
    return mix(n, (tone, 0.0, 0.5), (rush, 0.0, 1.0))
