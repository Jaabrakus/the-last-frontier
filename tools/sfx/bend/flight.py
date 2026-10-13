"""Shots in flight for Tidebreak (round 4, READ; tools/sfx/bend/bend_sfx.py writes them): the looping voice each shot
carries through the air, so an incoming attack is read by ear (the owner's FEEL list: "readable incoming attacks
WITHOUT any target cue"; the genre times its guards from a shot's sound). Each maker takes a numpy Generator and returns
a mono signal LOOP_RAW s long at any level; bend_sfx.py cross-fades its tail into its head (LOOPS: a seamless loop with a
RIFF smpl chunk, as the crowd's murmur) and sets the loudness. The game plays them 3D with doppler and a steep level
curve (scripts/bending/bend_sounds.gd: flight(), FLIGHTS), so these are steady beds with an identity, not events.

  stone_whirr   a low tumbling whirr: a heavy stone turning over in the air, its rotation rate rough (each turn a
                little longer or shorter), each turn a soft whump of displaced air over a low rumble
  ice_whistle   a thin glassy whistle: a narrow resonant band with a shimmer (two close partials beating, a fast
                tremolo), a faint brittle tinkle
  water_rush    a rushing hiss with a slosh: a mid-high water hiss, its top wandering, under it the mass of water
                lurching (low gurgles, a slow slosh)
  fire_flight   a roaring hiss with crackle: the flame's boiling roar, a torch-like hiss over it, sparse crackles
  air_flight    a whoosh with a pressure flutter: a band of wind, its centre swaying, beaten by a fast flutter (the
                pressure wave's tremble) with a soft whistle edge
  floor_run     the Kick's floor wave crackling along the deck: dense crackles and pops over a low flame bed and a
                rolling rumble of the boards
"""
from __future__ import annotations

import math

import numpy as np

import elements as el
from kit import N, T, band, bubbles, crackles, dsp, noise, sweep, wobble

## How long each maker renders (s); bend_sfx.py's LOOPS cross-fade of LOOP_XFADE s leaves LOOP_RAW - LOOP_XFADE.
LOOP_XFADE = 0.45
## Each variant's raw length is drawn here (s): 1.85-2.45 s looped.
RAW_S = (2.3, 2.9)


def _norm(x: np.ndarray) -> np.ndarray:
    return x / (np.std(x) + 1e-12)


def _rough_turns(r, n: int, rate: float, rough: float) -> np.ndarray:
    """A phase (in turns) running at about `rate` turns a second, each turn's length rough by +-rough of itself."""
    t = 0.0
    edges = [0.0]
    while t < n / dsp.SR + 1.0:
        t += (1.0 / rate) * (1.0 + r.uniform(-rough, rough))
        edges.append(t)
    edges = np.asarray(edges)
    tt = T(n)
    k = np.searchsorted(edges, tt, side="right") - 1
    frac = (tt - edges[k]) / (edges[k + 1] - edges[k])
    return k + frac


def stone_whirr(r) -> np.ndarray:
    dur = r.uniform(*RAW_S)
    n = N(dur)
    rate = r.uniform(5.5, 7.5)                                # turns a second
    ph = _rough_turns(r, n, rate, 0.22)
    # each turn: the stone's broad face sweeps the air (a whump twice a turn, one stronger)
    face = 0.5 + 0.5 * np.cos(2 * math.pi * ph)
    face2 = 0.5 + 0.5 * np.cos(4 * math.pi * ph + 0.6)
    am = 0.25 + 0.75 * face ** 3 + 0.35 * face2 ** 4
    tt = np.linspace(0.0, dur, 96)
    cen = 260.0 * 2.0 ** (0.35 * np.interp(tt, T(n), np.cos(2 * math.pi * ph)))
    whump = sweep(r, dur, tt, cen, 0.7) * am
    rumble = _norm(band(dsp.brown(n, r), 30.0, 140.0, 2)) * wobble(n, rate, 0.5, r)
    hiss = _norm(band(noise(n, r), 1200.0, 4200.0, 2)) * (0.3 + 0.7 * face)
    return whump + 0.55 * rumble + 0.08 * hiss


def ice_whistle(r) -> np.ndarray:
    dur = r.uniform(*RAW_S)
    n = N(dur)
    t = T(n)
    f0 = r.uniform(2300.0, 3100.0)
    drift = 1.0 + 0.012 * dsp.smooth_noise(n, 1.5, r)
    beat = r.uniform(5.0, 9.0)                                # the two partials' beating: the shimmer
    a = np.sin(2 * math.pi * np.cumsum(f0 * drift) / dsp.SR)
    b = np.sin(2 * math.pi * np.cumsum((f0 + beat) * drift) / dsp.SR + 1.3)
    c = np.sin(2 * math.pi * np.cumsum(f0 * 1.51 * drift) / dsp.SR)          # a glassy upper partial
    trem = 1.0 + 0.35 * np.sin(2 * math.pi * r.uniform(11.0, 15.0) * t)
    tone = (0.5 * (a + b) + 0.18 * c) * trem
    air = sweep(r, dur, [0.0, dur], [f0 * 0.9, f0 * 0.95], 0.25) * wobble(n, 9.0, 0.4, r)
    body = _norm(band(noise(n, r), 500.0, 1800.0, 2)) * wobble(n, 4.0, 0.3, r)
    tink = np.zeros(n)
    for tk in np.arange(r.uniform(0.0, 0.2), dur, 1.0 / r.uniform(6.0, 10.0)):
        m = N(0.03)
        ping = np.sin(2 * math.pi * r.uniform(5200.0, 7800.0) * T(m)) * dsp.exp_env(m, 0.006)
        dsp.place(tink, ping, tk + r.uniform(-0.03, 0.03), r.uniform(0.2, 1.0))
    return 0.55 * tone + 0.6 * air + 0.3 * body + 0.15 * tink


def water_rush(r) -> np.ndarray:
    dur = r.uniform(*RAW_S)
    n = N(dur)
    tt = np.linspace(0.0, dur, 48)
    top = 1500.0 * 2.0 ** (0.5 * dsp.smooth_noise(48, 0.3 * 48 / dur, r))
    hiss = sweep(r, dur, tt, top, 0.8) * wobble(n, 22.0, 0.35, r)
    slosh_rate = r.uniform(1.6, 2.4)
    slosh = 0.5 + 0.5 * np.sin(2 * math.pi * slosh_rate * T(n) + r.uniform(0, 6)) * wobble(n, 2.0, 0.3, r)
    low = _norm(band(noise(n, r), 120.0, 520.0, 2)) * wobble(n, 7.0, 0.55, r) * (0.4 + 0.6 * slosh)
    gurgle = bubbles(r, n, int(dur * 22), 0.0, dur - 0.05, 300.0, 1400.0)
    return hiss + 0.55 * low + 0.35 * _norm(gurgle + 1e-9 * noise(n, r))


def fire_flight(r) -> np.ndarray:
    dur = r.uniform(*RAW_S)
    n = N(dur)
    roar = el._flame(r, dur, r.uniform(900.0, 1300.0), r.uniform(12.0, 18.0))
    hiss = _norm(band(noise(n, r), 2500.0, 7500.0, 2)) * wobble(n, 30.0, 0.5, r)
    torch = sweep(r, dur, [0.0, dur], [1100.0, 1300.0], 0.6) * wobble(n, 16.0, 0.6, r)
    return roar + 0.25 * hiss + 0.35 * torch + 0.5 * crackles(r, n, r.uniform(14.0, 22.0))


def air_flight(r) -> np.ndarray:
    dur = r.uniform(*RAW_S)
    n = N(dur)
    t = T(n)
    tt = np.linspace(0.0, dur, 64)
    sway = r.uniform(0.7, 1.3)
    cen = 700.0 * 2.0 ** (0.45 * np.sin(2 * math.pi * sway * tt + r.uniform(0, 6)))
    wind = sweep(r, dur, tt, cen, 0.75)
    flutter_hz = r.uniform(17.0, 24.0)
    flutter = 1.0 + 0.55 * np.sin(2 * math.pi * flutter_hz * t + 0.4 * np.sin(2 * math.pi * 1.7 * t))
    edge = sweep(r, dur, tt, cen * 2.6, 0.18) * wobble(n, 5.0, 0.5, r)
    low = _norm(band(noise(n, r), 70.0, 260.0, 2)) * flutter
    return wind * flutter + 0.3 * edge + 0.35 * low


def floor_run(r) -> np.ndarray:
    dur = r.uniform(*RAW_S)
    n = N(dur)
    bed = el._flame(r, dur, r.uniform(600.0, 850.0), 9.0)
    rumble = _norm(band(dsp.brown(n, r), 35.0, 160.0, 2)) * wobble(n, 12.0, 0.6, r)
    snaps = crackles(r, n, r.uniform(45.0, 60.0), bright=1.1)
    pops = np.zeros(n)
    for tk in np.arange(r.uniform(0.0, 0.1), dur, 1.0 / r.uniform(7.0, 10.0)):
        m = N(0.04)
        p = band(noise(m, r), 300.0, 1800.0, 2) * dsp.exp_env(m, 0.008)
        dsp.place(pops, p, tk + r.uniform(-0.04, 0.04), r.uniform(0.4, 1.0))
    return 0.5 * bed + 0.5 * rumble + 0.55 * snaps + 0.5 * _norm(pops + 1e-9 * noise(n, r))
