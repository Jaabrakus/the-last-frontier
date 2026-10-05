"""The four elements' sounds and the ring's moments for Tidebreak (tools/sfx/bend/bend_sfx.py writes them). Each maker
takes a numpy Generator and returns a mono signal at any level (bend_sfx.py trims, fades and sets the loudness).

  earth   cast_rumble (a deep rumble with a crack in front), cast_crack (a stone split off and flung), grind (stone
          dragged over stone), hit (a heavy stone landing: thump, crack, grit), rise (a wall grinding up and settling),
          crumble (a wall breaking up: crack, chunks, grit, dust), catch (a stone stopped dead in the hands: a dull thunk,
          a short scrape)
  water   cast_rush (rushing water), slosh (sloshing, gurgling), hit (a splash: slap, spray, bubbles, drops), ice_freeze
          (a freezing crackle), ice_cast (a crystal swish), ice_hit (ice shattering)
  fire    whoomph (a pressure burst), roar (a sustained roar), crackle (burning), hit (a fiery burst), sizzle
  air     whoosh, gust, swirl (wind circling), hit (a punch of air)
  others  lightning_crack (a hum swelling into the crack, an electric buzz, a short thunder roll), lightning_charge (a
          rising hum with sparks), steam_hiss, mend (stones packing tight), heal (a soft swell with a trickle),
          knock_thud (a body thrown onto the deck), ringout_splash (a body plunging into the pool), round_gong,
          match_gong, round_bell (three rings), count_tick (a wood block)
"""
from __future__ import annotations

import math

import numpy as np

from kit import (N, T, band, bubbles, crack, crackle, crackles, dsp, grit, hump, lowpass_sweep, mix, noise,
                 plateau, rock, room, sweep, thump, tick, wobble)


# ================================================================================================ earth
def _rumble(r, dur: float, lo: float = 25.0, hi: float = 170.0, rate: float = 11.0) -> np.ndarray:
    n = N(dur)
    x = band(dsp.brown(n, r), lo, hi, 2)
    return x / (np.std(x) + 1e-12) * wobble(n, rate, 0.55, r)


def _scrape(r, dur: float, rate: float = 90.0, lo: float = 180.0, hi: float = 2400.0) -> np.ndarray:
    """Stone dragged on stone: a train of slips (stick-slip), each a tiny rough knock, through a gritty band."""
    n = N(dur)
    slips = dsp.stick_slip_train(dur, lambda t: rate * (1.0 + 0.4 * math.sin(7.0 * t + r.uniform(0, 6))), r,
                                 jitter=0.45, amp_jitter=0.7)
    grain = rock(r, r.uniform(500.0, 900.0), 0.05, ring=0.25, contact=0.0004, rough=1.0)
    x = dsp.fftconvolve(slips, grain)[:n]
    bed = band(noise(n, r), lo, hi, 2) * wobble(n, 30.0, 0.8, r)
    x = x / (np.std(x) + 1e-12) + 0.6 * bed / (np.std(bed) + 1e-12)
    return band(x, lo, hi * 2.0, 1)


def earth_cast_rumble(r) -> np.ndarray:
    dur = r.uniform(1.1, 1.4)
    n = N(dur)
    rum = _rumble(r, dur, 25.0, 240.0) * hump(n, r.uniform(0.06, 0.12), r.uniform(0.35, 0.5), 1.0)
    sub = thump(r.uniform(52.0, 60.0), r.uniform(36.0, 42.0), r.uniform(0.3, 0.42), dur, glide=0.25, attack=0.02)
    scr = _scrape(r, dur, r.uniform(50.0, 80.0)) * hump(n, 0.1, 0.25)
    return mix(n, (rum, 0.0, 1.0), (sub, 0.0, 0.9), (crack(r, 0.6, 4, 0.015), 0.0, 0.45),
               (rock(r, r.uniform(120.0, 170.0), 0.4, ring=1.4), 0.0, 0.7), (scr, 0.02, 0.25),
               (grit(r, n, 40, 0.05, dur, decay=0.25), 0.0, 0.05))


def earth_cast_crack(r) -> np.ndarray:
    dur = r.uniform(0.6, 0.8)
    n = N(dur)
    fly = sweep(r, dur, [0.0, 0.08, 0.3, dur], [300.0, 700.0, 1100.0, 500.0], 0.8) * hump(n, 0.12, 0.12)
    return mix(n, (crack(r, 1.0, r.integers(4, 8), 0.02), 0.0, 1.0),
               (rock(r, r.uniform(220.0, 330.0), 0.3, ring=0.9, contact=0.0006), 0.0, 0.9),
               (thump(r.uniform(95.0, 115.0), 55.0, 0.08, 0.3), 0.0, 0.8),
               (fly, 0.03, 0.12), (grit(r, n, 30, 0.01, 0.4, decay=0.08), 0.0, 0.18))


def earth_grind(r) -> np.ndarray:
    dur = r.uniform(0.8, 1.15)
    n = N(dur)
    scr = _scrape(r, dur, r.uniform(70.0, 140.0)) * plateau(n, 0.08, dur - 0.4, 0.3)
    rum = _rumble(r, dur, 30.0, 140.0) * plateau(n, 0.05, dur - 0.35, 0.3)
    return mix(n, (scr, 0.0, 0.8), (rum, 0.0, 0.7), (grit(r, n, 50, 0.0, dur), 0.0, 0.1),
               (rock(r, r.uniform(160.0, 220.0), 0.3), 0.0, 0.35))


def earth_hit(r) -> np.ndarray:
    dur = r.uniform(0.65, 0.9)
    n = N(dur)
    dust = band(noise(n, r), 1800.0, 7000.0, 2) * dsp.ar_env(n, 0.01, 0.18)
    body = band(noise(n, r), 60.0, 2400.0, 2) * dsp.ar_env(n, 0.001, 0.035)
    return mix(n, (thump(r.uniform(75.0, 90.0), r.uniform(40.0, 48.0), r.uniform(0.11, 0.15), 0.5), 0.0, 1.0),
               (rock(r, r.uniform(140.0, 230.0), 0.4, ring=1.1), 0.0, 0.9),
               (crack(r, 0.8, r.integers(3, 7), 0.012), 0.0, 0.7), (body, 0.0, 0.25),
               (grit(r, n, 70, 0.02, dur, decay=0.15, f_lo=1200.0), 0.0, 0.22), (dust, 0.0, 0.05))


def earth_rise(r) -> np.ndarray:
    dur = r.uniform(1.4, 1.8)
    n = N(dur)
    top = r.uniform(0.75, 1.0)
    swell = plateau(n, top * 0.6, top * 0.4, 0.25)
    rum = _rumble(r, dur, 25.0, 260.0, 14.0) * swell
    scr = _scrape(r, dur, r.uniform(90.0, 150.0), 220.0, 3000.0) * swell
    sub = thump(42.0, 34.0, 0.6, dur, glide=0.5, attack=0.25)
    settle = mix(N(0.6), (rock(r, r.uniform(110.0, 150.0), 0.45, ring=1.3, contact=0.002), 0.0, 1.0),
                 (thump(70.0, 42.0, 0.12, 0.4), 0.0, 0.8))
    return mix(n, (rum, 0.0, 1.0), (scr, 0.0, 0.9), (sub, 0.0, 0.6), (settle, top, 0.6),
               (crack(r, 0.5, 4, 0.03), 0.0, 0.3), (grit(r, n, 60, top, dur, decay=0.3), 0.0, 0.18),
               (grit(r, n, 30, 0.1, top), 0.0, 0.06))


def earth_crumble(r) -> np.ndarray:
    dur = r.uniform(1.5, 2.0)
    n = N(dur)
    chunks = np.zeros(n)
    for _ in range(r.integers(5, 9)):
        t = 0.06 + r.exponential(0.25)
        if t < dur - 0.3:
            ch = mix(N(0.4), (rock(r, r.uniform(160.0, 420.0), 0.3, ring=0.8), 0.0, 1.0),
                     (thump(r.uniform(70.0, 110.0), 50.0, 0.06, 0.25), 0.0, 0.6))
            dsp.place(chunks, ch, t, r.uniform(0.3, 0.8))
    rum = _rumble(r, dur, 25.0, 200.0) * hump(n, 0.08, 0.5, 1.0)
    dust = band(noise(n, r), 1500.0, 6000.0, 2) * hump(n, 0.15, 0.5)
    return mix(n, (crack(r, 0.9, 8, 0.04), 0.0, 1.0), (rock(r, r.uniform(110.0, 160.0), 0.5, ring=1.5), 0.0, 0.9),
               (rum, 0.0, 0.8), (chunks, 0.0, 0.9), (grit(r, n, 160, 0.03, dur, decay=0.4, f_lo=1200.0), 0.0, 0.2),
               (dust, 0.0, 0.05))


def stone_catch(r) -> np.ndarray:
    dur = r.uniform(0.5, 0.65)
    n = N(dur)
    stop = _scrape(r, 0.12, r.uniform(140.0, 200.0)) * np.exp(-T(N(0.12)) / 0.03)
    return mix(n, (rock(r, r.uniform(120.0, 150.0), 0.35, ring=1.6, contact=0.005, rough=0.3), 0.0, 1.0),
               (thump(r.uniform(68.0, 78.0), 46.0, 0.1, 0.4, glide=0.03, attack=0.003), 0.0, 1.0),
               (stop, 0.008, 0.25), (tick(r, 2500.0, 4000.0), 0.002, 0.15),
               (grit(r, n, 18, 0.02, 0.3, decay=0.08, f_lo=1800.0), 0.0, 0.1))


# ================================================================================================ water
def water_cast_rush(r) -> np.ndarray:
    dur = r.uniform(0.6, 0.9)
    n = N(dur)
    a, b, c = r.uniform(380.0, 560.0), r.uniform(1400.0, 2100.0), r.uniform(700.0, 1000.0)
    body = sweep(r, dur, [0.0, 0.15, dur], [a, b, c], 0.65) * wobble(n, 26.0, 0.5, r)
    low = band(noise(n, r), 80.0, 350.0, 2) * wobble(n, 9.0, 0.6, r)
    e = hump(n, r.uniform(0.12, 0.2), r.uniform(0.18, 0.28), 1.5)
    return mix(n, (body * e, 0.0, 1.0), (low / (np.std(low) + 1e-12) * e, 0.0, 0.35),
               (bubbles(r, n, 26, 0.05, dur - 0.1, 500.0, 2400.0), 0.0, 0.25))


def water_slosh(r) -> np.ndarray:
    dur = r.uniform(0.75, 1.0)
    n = N(dur)
    y = np.zeros(n)
    t = 0.0
    for k in range(r.integers(2, 4)):
        d = r.uniform(0.18, 0.32)
        m = N(d)
        s = sweep(r, d, [0.0, d * 0.4, d], [r.uniform(250, 380), r.uniform(700, 1100), r.uniform(300, 450)], 1.0)
        dsp.place(y, s * hump(m, d * 0.35, d * 0.25), t, 1.0 if k == 0 else r.uniform(0.5, 0.8))
        t += d * r.uniform(0.55, 0.8)
    return mix(n, (y, 0.0, 1.0), (bubbles(r, n, 40, 0.02, dur, 250.0, 900.0, decay=0.25), 0.0, 0.5),
               (bubbles(r, n, 15, 0.05, dur, 900.0, 2400.0), 0.0, 0.2))


def water_hit(r) -> np.ndarray:
    dur = r.uniform(0.65, 0.9)
    n = N(dur)
    slap = band(noise(N(0.01), r), 500.0, 9000.0, 2) * dsp.exp_env(N(0.01), 0.0018)
    spray = sweep(r, dur, [0.0, 0.05, dur], [2500.0, 1800.0, 3500.0], 0.85) * dsp.ar_env(n, 0.004, r.uniform(0.1, 0.15))
    body = band(noise(n, r), 180.0, 1200.0, 2) * dsp.ar_env(n, 0.003, 0.06)
    return mix(n, (slap, 0.0, 0.9), (spray, 0.0, 0.25), (body / (np.std(body) + 1e-12), 0.0, 0.25),
               (thump(110.0, 70.0, 0.05, 0.2), 0.0, 0.35),
               (bubbles(r, n, 50, 0.01, 0.4, 600.0, 3000.0, decay=0.12), 0.0, 0.5),
               (bubbles(r, n, 14, 0.15, dur - 0.05, 1500.0, 4200.0), 0.0, 0.25))


def ice_freeze(r) -> np.ndarray:
    dur = r.uniform(0.9, 1.25)
    n = N(dur)
    t_end = dur * r.uniform(0.6, 0.75)
    y = np.zeros(n)
    t = 0.0
    while t < t_end:                                            # the crackle quickening as the ice spreads, then done
        rate = 30.0 + 260.0 * (t / t_end) ** 1.5
        t += r.exponential(1.0 / rate)
        m = N(r.uniform(0.0006, 0.002))
        c = noise(m, r) * dsp.exp_env(m, 0.0005)
        dsp.place(y, c, t, r.uniform(0.2, 1.0) ** 2)
    y = band(y, 2500.0, 14000.0, 2)
    fc = r.uniform(2200.0, 3200.0)
    creak = dsp.fftconvolve(dsp.stick_slip_train(t_end, lambda tt: 220.0 + 260.0 * tt, r, jitter=0.6),
                            dsp.modal_ir([fc, fc * 1.58, fc * 2.27], [0.003, 0.002, 0.0015], [1.0, 0.6, 0.4], 0.03))
    tinks = np.zeros(n)
    for _ in range(r.integers(3, 6)):
        f = r.uniform(3000.0, 7500.0)
        tk = dsp.strike([f, f * 1.52, f * 2.31], [0.15, 0.08, 0.05], [1.0, 0.5, 0.3], 0.5, contact=0.0003)
        dsp.place(tinks, tk, r.uniform(0.2, t_end + 0.1), r.uniform(0.2, 0.6))
    hiss = band(noise(n, r), 4000.0, 12000.0, 2) * plateau(n, 0.1, t_end - 0.1, 0.25)
    return mix(n, (y / (np.max(np.abs(y)) + 1e-12), 0.0, 1.0), (creak / (np.max(np.abs(creak)) + 1e-12), 0.0, 0.1),
               (tinks, 0.0, 0.35), (hiss / (np.std(hiss) + 1e-12), 0.0, 0.05), (crack(r, 1.5, 3, 0.01), 0.0, 0.4))


def ice_cast(r) -> np.ndarray:
    dur = r.uniform(0.5, 0.7)
    n = N(dur)
    sw = sweep(r, dur, [0.0, 0.1, dur], [1200.0, r.uniform(2600.0, 3400.0), 1800.0], 0.7) * hump(n, 0.1, 0.12)
    f = r.uniform(2400.0, 3200.0)
    chime = dsp.strike([f, f * 1.49, f * 2.13, f * 2.87], [0.16, 0.11, 0.07, 0.05], [1.0, 0.6, 0.4, 0.25], dur,
                       contact=0.0004)
    return mix(n, (sw, 0.0, 0.5), (chime, 0.0, 0.25), (crack(r, 1.6, 4, 0.01), 0.0, 0.8),
               (grit(r, n, 12, 0.0, 0.3, 3000.0, 9000.0), 0.0, 0.25))


def ice_hit(r) -> np.ndarray:
    dur = r.uniform(0.65, 0.9)
    n = N(dur)
    shards = np.zeros(n)
    for _ in range(r.integers(22, 38)):
        f = math.exp(r.uniform(math.log(2000.0), math.log(9000.0)))
        tk = dsp.strike([f, f * r.uniform(1.4, 1.7), f * r.uniform(2.1, 2.6)],
                        [r.uniform(0.02, 0.12), 0.03, 0.015], [1.0, 0.5, 0.3], 0.3, contact=0.0002)
        dsp.place(shards, tk, 0.005 + r.exponential(0.09), r.uniform(0.1, 0.8) ** 1.5)
    burst = band(noise(N(0.08), r), 1500.0, 14000.0, 2) * dsp.exp_env(N(0.08), 0.012)
    return mix(n, (crack(r, 1.5, 6, 0.012), 0.0, 1.0), (burst, 0.0, 0.25),
               (shards / (np.max(np.abs(shards)) + 1e-12), 0.0, 0.7),
               (thump(130.0, 80.0, 0.05, 0.2), 0.0, 0.45), (rock(r, r.uniform(400.0, 600.0), 0.2, ring=0.6), 0.0, 0.35))


# ================================================================================================ fire
def _flame(r, dur: float, cut: float = 900.0, rate: float = 14.0) -> np.ndarray:
    """The body of a flame: brown and pink noise, its top end wandering, its level boiling."""
    n = N(dur)
    x = 0.7 * dsp.brown(n, r) + 0.3 * dsp.pink(n, r)
    tt = np.linspace(0.0, dur, max(int(dur / 0.07), 2))
    x = lowpass_sweep(r, dur, tt, cut * 2.0 ** r.uniform(-0.5, 0.5, len(tt)), src=x)
    x = band(x, 45.0, None, 2)
    return x / (np.std(x) + 1e-12) * wobble(n, rate, 0.6, r)


def fire_whoomph(r) -> np.ndarray:
    dur = r.uniform(0.5, 0.7)
    n = N(dur)
    top = r.uniform(2200.0, 3200.0)
    body = lowpass_sweep(r, dur, [0.0, 0.035, 0.12, dur], [250.0, top, 900.0, 300.0], 2,
                         src=0.6 * dsp.brown(n, r) + 0.4 * noise(n, r))
    body = body / (np.std(body) + 1e-12) * hump(n, 0.03, r.uniform(0.1, 0.14), 1.0) * wobble(n, 30.0, 0.4, r)
    hiss = band(noise(n, r), 2500.0, 8000.0, 2) * dsp.ar_env(n, 0.02, 0.15)
    return mix(n, (body, 0.0, 1.0), (thump(r.uniform(100.0, 120.0), 45.0, 0.1, 0.35, glide=0.05, attack=0.006), 0.0, 0.8),
               (crackles(r, n, 40.0 * np.exp(-T(n) / 0.2)), 0.0, 0.3), (hiss, 0.0, 0.05))


def fire_roar(r) -> np.ndarray:
    dur = r.uniform(1.0, 1.35)
    n = N(dur)
    e = plateau(n, r.uniform(0.08, 0.14), dur * 0.35, dur * 0.5)
    fl = _flame(r, dur, r.uniform(800.0, 1200.0), r.uniform(10.0, 16.0)) * e
    open_ = lowpass_sweep(r, 0.5, [0.0, 0.05, 0.5], [300.0, 2800.0, 600.0], 2) * dsp.ar_env(N(0.5), 0.01, 0.1)
    hiss = band(noise(n, r), 3000.0, 7000.0, 2) * e
    return mix(n, (fl, 0.0, 1.0), (open_ / (np.std(open_) + 1e-12), 0.0, 0.5),
               (thump(70.0, 50.0, 0.35, dur, glide=0.2, attack=0.04), 0.0, 0.5),
               (crackles(r, n, 18.0 * e + 2.0), 0.0, 0.3), (hiss / (np.std(hiss) + 1e-12), 0.0, 0.05))


def fire_crackle(r) -> np.ndarray:
    dur = r.uniform(0.85, 1.2)
    n = N(dur)
    e = plateau(n, 0.06, dur * 0.4, dur * 0.5)
    bed = _flame(r, dur, 600.0, 8.0) * e
    pops = np.zeros(n)
    for _ in range(r.integers(3, 6)):
        m = N(0.03)
        p = band(noise(m, r), 500.0, 2200.0, 2) * dsp.exp_env(m, 0.006)
        dsp.place(pops, p, r.uniform(0.0, dur * 0.8), r.uniform(0.5, 1.0))
    return mix(n, (bed, 0.0, 0.35), (crackles(r, n, 32.0 * e + 1.0, bright=1.1), 0.0, 1.0), (pops, 0.0, 0.6))


def fire_hit(r) -> np.ndarray:
    dur = r.uniform(0.6, 0.8)
    n = N(dur)
    burst = lowpass_sweep(r, dur, [0.0, 0.01, 0.1, dur], [600.0, 4000.0, 1100.0, 400.0], 2,
                          src=0.5 * dsp.brown(n, r) + 0.5 * noise(n, r))
    burst = burst / (np.std(burst) + 1e-12) * hump(n, 0.008, r.uniform(0.09, 0.13), 1.0) * wobble(n, 35.0, 0.5, r)
    sizz = band(noise(n, r), 3500.0, 10000.0, 2) * dsp.ar_env(n, 0.03, 0.2) * wobble(n, 60.0, 0.9, r)
    return mix(n, (burst, 0.0, 1.0), (thump(r.uniform(85.0, 100.0), 45.0, 0.1, 0.35), 0.0, 0.9),
               (crackles(r, n, 70.0 * np.exp(-T(n) / 0.15) + 3.0), 0.0, 0.4), (sizz, 0.0, 0.05))


def fire_sizzle(r) -> np.ndarray:
    dur = r.uniform(0.7, 1.0)
    n = N(dur)
    grains = np.zeros(n)
    t = 0.0
    while t < dur:
        t += r.exponential(1.0 / 500.0)
        m = N(r.uniform(0.001, 0.006))
        dsp.place(grains, noise(m, r) * np.hanning(m), t, r.uniform(0.1, 1.0) * math.exp(-t / (dur * 0.45)))
    grains = band(grains, 3000.0, 12000.0, 4)
    return mix(n, (grains / (np.max(np.abs(grains)) + 1e-12), 0.0, 1.0),
               (crackles(r, n, 20.0 * np.exp(-T(n) / 0.3), bright=1.3), 0.0, 0.4),
               (band(noise(n, r), 200.0, 800.0, 2) * dsp.ar_env(n, 0.005, 0.05), 0.0, 0.04))


# ================================================================================================ air
def air_whoosh(r) -> np.ndarray:
    dur = r.uniform(0.4, 0.6)
    n = N(dur)
    pk = r.uniform(0.35, 0.5) * dur
    lo, top, end = r.uniform(250.0, 380.0), r.uniform(1100.0, 1700.0), r.uniform(380.0, 550.0)
    w = sweep(r, dur, [0.0, pk, dur], [lo, top, end], 0.75) * hump(n, pk, dur * 0.18, 2.0)
    whistle = dsp.sine_sweep(n, np.interp(T(n), [0.0, pk, dur], [lo * 2.0, top * 2.0, end * 2.0])) * hump(n, pk, dur * 0.12)
    return mix(n, (w, 0.0, 1.0), (whistle, 0.0, 0.03), (band(noise(n, r), 60.0, 250.0, 2) * hump(n, pk, 0.08), 0.0, 0.1))


def air_gust(r) -> np.ndarray:
    dur = r.uniform(0.9, 1.3)
    n = N(dur)
    e = hump(n, r.uniform(0.18, 0.3), r.uniform(0.25, 0.4), 1.5)
    low = sweep(r, dur, [0.0, 0.3, dur], [250.0, 520.0, 300.0], 0.8) * wobble(n, 6.0, 0.5, r)
    high = sweep(r, dur, [0.0, 0.25, dur], [900.0, 2200.0, 1100.0], 0.7) * wobble(n, r.uniform(18.0, 28.0), 0.7, r)
    return (low + 0.5 * high) * e


def air_swirl(r) -> np.ndarray:
    dur = r.uniform(1.2, 1.6)
    n = N(dur)
    t = T(n)
    spin = r.uniform(3.0, 5.0)
    ph = r.uniform(0, 2 * math.pi)
    lfo = np.sin(2 * math.pi * spin * t + ph)
    tt = np.linspace(0, dur, 64)
    lf = np.sin(2 * math.pi * spin * tt + ph)
    a = sweep(r, dur, tt, 600.0 * 2.0 ** (0.6 * lf), 0.6)
    b = sweep(r, dur, tt, 1500.0 * 2.0 ** (-0.5 * lf), 0.35)              # a thin whistling band, the other way round
    e = plateau(n, r.uniform(0.2, 0.3), dur * 0.35, dur * 0.4)
    return (a * (1.0 + 0.45 * lfo) + 0.35 * b * (1.0 - 0.4 * lfo)) * e


def air_hit(r) -> np.ndarray:
    dur = r.uniform(0.4, 0.6)
    n = N(dur)
    puff = band(noise(n, r), 80.0, 1300.0, 2) * dsp.ar_env(n, 0.002, 0.04)
    out = sweep(r, dur, [0.0, 0.03, dur], [2200.0, 1400.0, 450.0], 0.9) * hump(n, 0.02, 0.1, 1.0)
    flap = band(noise(N(0.05), r), 900.0, 4000.0, 2) * (np.sin(2 * math.pi * 45.0 * T(N(0.05))) ** 2)
    return mix(n, (puff / (np.std(puff) + 1e-12), 0.0, 0.6), (thump(85.0, 55.0, 0.06, 0.25), 0.0, 0.8),
               (out, 0.0, 0.6), (flap, 0.03, 0.2))


# ================================================================================================ lightning, steam
def lightning_crack(r) -> np.ndarray:
    dur = r.uniform(1.4, 1.9)
    n = N(dur)
    pre = r.uniform(0.04, 0.07)                              # the hum swelling into the strike
    m = N(pre)
    f = np.linspace(110.0, 220.0, m)
    ph = np.cumsum(f) / dsp.SR
    hum = (2.0 * (ph % 1.0) - 1.0) * np.linspace(0.0, 1.0, m) ** 2
    clicks = np.zeros(N(0.02))
    for i in range(r.integers(6, 12)):
        dsp.place(clicks, np.array([1.0, -0.8, 0.3]), r.uniform(0.0, 0.015) * (i > 0), r.uniform(0.4, 1.0))
    zaps = np.zeros(n)
    for _ in range(r.integers(30, 50)):
        k = N(r.uniform(0.001, 0.004))
        dsp.place(zaps, noise(k, r) * dsp.exp_env(k, 0.0008), pre + r.exponential(0.07), r.uniform(0.1, 0.9))
    zaps = band(zaps, 1500.0, 14000.0, 2)
    buzz_t = T(n)
    buzz = np.sign(np.sin(2 * math.pi * 120.0 * buzz_t)) * wobble(n, 80.0, 1.0, r) * np.exp(-np.maximum(buzz_t - pre, 0) / 0.18)
    buzz = band(buzz, 300.0, 6000.0, 2) * (buzz_t >= pre)
    thunder = band(dsp.brown(n, r), 30.0, 320.0, 2)
    thunder = thunder / (np.std(thunder) + 1e-12) * hump(n, pre + r.uniform(0.12, 0.22), r.uniform(0.4, 0.55), 1.2) \
        * wobble(n, 7.0, 0.7, r)
    return mix(n, (band(hum, 100.0, 5000.0, 1), 0.0, 0.25), (band(clicks, 200.0, None, 1), pre, 1.0),
               (crack(r, 1.2, 10, 0.03), pre, 0.8), (zaps / (np.max(np.abs(zaps)) + 1e-12), 0.0, 0.5),
               (buzz / (np.max(np.abs(buzz)) + 1e-12), 0.0, 0.15), (thunder, 0.0, 0.5))


def lightning_charge(r) -> np.ndarray:
    dur = r.uniform(1.0, 1.3)
    n = N(dur)
    t = T(n)
    f0 = 90.0 * (1.9 ** (t / dur)) * (1.0 + 0.01 * dsp.smooth_noise(n, 12.0, r))
    ph = np.cumsum(f0) / dsp.SR
    hum = sum(np.sin(2 * math.pi * k * ph) / k ** 0.8 for k in range(1, 12))
    hum = hum * (1.0 + 0.5 * np.sin(2 * math.pi * 31.0 * t)) * (t / dur) ** 1.2
    fizz = band(noise(n, r), 4000.0, 10000.0, 2) * wobble(n, 60.0, 1.2, r) * (t / dur) ** 2
    sparks = np.zeros(n)
    for _ in range(r.integers(12, 22)):
        k = N(r.uniform(0.001, 0.003))
        dsp.place(sparks, noise(k, r) * dsp.exp_env(k, 0.0006), dur * r.uniform(0.2, 1.0) ** 0.5, r.uniform(0.2, 1.0))
    e = plateau(n, dur * 0.85, 0.0, dur * 0.15)
    return mix(n, (band(hum, 60.0, 4000.0, 1) * e, 0.0, 1.0), (fizz * e, 0.0, 0.08),
               (band(sparks, 1500.0, None, 2), 0.0, 0.5))


def steam_hiss(r) -> np.ndarray:
    dur = r.uniform(1.0, 1.4)
    n = N(dur)
    h = band(noise(n, r), 1500.0, 11000.0, 2)
    h = dsp.fft_filter(h, lambda f: 0.4 + dsp.mag_resonance(f, r.uniform(4000.0, 6000.0), 1.2), minphase=False)[:n]
    h = h / (np.std(h) + 1e-12) * dsp.ar_env(n, 0.012, r.uniform(0.35, 0.5)) * wobble(n, 30.0, 0.35, r)
    puff = band(noise(n, r), 150.0, 900.0, 2) * dsp.ar_env(n, 0.003, 0.05)
    return mix(n, (h, 0.0, 1.0), (puff / (np.std(puff) + 1e-12), 0.0, 0.4),
               (crackles(r, n, 60.0 * np.exp(-T(n) / 0.3), bright=1.3), 0.0, 0.35))


# ================================================================================================ mend, heal, body
def mend(r) -> np.ndarray:
    dur = r.uniform(1.0, 1.25)
    n = N(dur)
    knocks = np.zeros(n)
    t = 0.0
    gap = r.uniform(0.15, 0.2)
    for k in range(4):                                      # stones knocking into place, quicker each time
        dsp.place(knocks, rock(r, r.uniform(500.0, 800.0) * (1.0 - 0.08 * k), 0.15, ring=0.5, contact=0.0015), t,
                  0.5 + 0.1 * k)
        t += gap
        gap *= 0.7
    seat = mix(N(0.5), (rock(r, r.uniform(150.0, 190.0), 0.4, ring=1.2, contact=0.003), 0.0, 1.0),
               (thump(75.0, 48.0, 0.1, 0.35), 0.0, 0.9))
    scr = _scrape(r, 0.5, 120.0) * hump(N(0.5), 0.1, 0.12)
    shine = np.zeros(n)
    base = r.choice([392.0, 440.0, 415.3])
    for k, ratio in enumerate([1.0, 1.25, 1.5, 2.0]):        # a soft chord rising over the packing
        f = base * ratio
        tone = (np.sin(2 * math.pi * f * T(n)) + 0.15 * np.sin(4 * math.pi * f * T(n))) * dsp.ar_env(n, 0.02, 0.35)
        dsp.place(shine, tone, t + 0.04 * k, 0.25)
    return mix(n, (knocks, 0.0, 0.8), (scr, 0.0, 0.35), (seat, t, 1.0), (shine, 0.0, 0.18),
               (grit(r, n, 25, 0.0, t + 0.2), 0.0, 0.1))


def heal(r) -> np.ndarray:
    dur = r.uniform(1.0, 1.3)
    n = N(dur)
    t = T(n)
    base = r.choice([261.6, 293.7, 329.6])
    pad = sum(np.sin(2 * math.pi * base * k * t * (1.0 + 0.003 * np.sin(2 * math.pi * 5.0 * t))) / k
              for k in [1.0, 1.5, 2.0, 3.0])
    pad = pad * hump(n, r.uniform(0.25, 0.35), 0.35, 1.5)
    air = band(noise(n, r), 1500.0, 6000.0, 2) * hump(n, 0.3, 0.3, 2.0)
    return mix(n, (pad, 0.0, 0.5), (air / (np.std(air) + 1e-12), 0.0, 0.015),
               (bubbles(r, n, 30, 0.05, dur - 0.15, 500.0, 1600.0), 0.0, 0.25))


def knock_thud(r) -> np.ndarray:
    dur = r.uniform(0.45, 0.6)
    n = N(dur)
    deck = dsp.strike([r.uniform(150.0, 180.0), r.uniform(300.0, 340.0), r.uniform(500.0, 560.0)], [0.09, 0.05, 0.03],
                      [1.0, 0.5, 0.3], 0.4, contact=0.004, r=r, noise=0.4)
    body = band(noise(n, r), 60.0, 900.0, 2) * dsp.ar_env(n, 0.002, 0.035)
    cloth = band(noise(N(0.12), r), 900.0, 4500.0, 2) * (dsp.exp_env(N(0.12), 0.015) + 0.5 * np.roll(dsp.exp_env(N(0.12), 0.012), N(0.05)))
    return mix(n, (thump(r.uniform(80.0, 95.0), 48.0, 0.09, 0.4, glide=0.03), 0.0, 1.0),
               (body / (np.std(body) + 1e-12), 0.0, 0.3), (deck, 0.004, 0.6), (cloth, 0.0, 0.12),
               (grit(r, n, 10, 0.02, 0.2, 1500.0, 4000.0), 0.0, 0.08))


def ringout_splash(r) -> np.ndarray:
    dur = r.uniform(2.0, 2.4)
    n = N(dur)
    t = T(n)
    slap = band(noise(N(0.02), r), 300.0, 10000.0, 2) * dsp.exp_env(N(0.02), 0.004)
    plunge = np.sin(2 * math.pi * np.cumsum(np.interp(t, [0.0, 0.18, dur], [60.0, 190.0, 190.0])) / dsp.SR) \
        * hump(n, 0.05, 0.08, 1.0)
    body = sweep(r, dur, [0.0, 0.1, 0.6, dur], [700.0, 2200.0, 1600.0, 2600.0], 1.0) \
        * dsp.ar_env(n, 0.01, r.uniform(0.28, 0.38))
    sheet = np.zeros(n)                                      # the spray thrown up falling back
    for _ in range(320):
        k = N(r.uniform(0.002, 0.01))
        dsp.place(sheet, noise(k, r) * np.hanning(k), 0.25 + r.gamma(2.0, 0.22), r.uniform(0.1, 1.0))
    sheet = band(sheet, 1500.0, 9000.0, 2)
    return room(mix(n, (slap, 0.0, 0.8), (plunge, 0.03, 0.6), (thump(90.0, 50.0, 0.12, 0.5), 0.0, 0.8),
                    (body, 0.0, 0.55), (sheet / (np.max(np.abs(sheet)) + 1e-12), 0.0, 0.35),
                    (bubbles(r, n, 140, 0.03, 0.9, 250.0, 2500.0, decay=0.25), 0.0, 0.5),
                    (bubbles(r, n, 30, 0.6, dur - 0.1, 1500.0, 4500.0), 0.0, 0.25)), r, 0.6, 0.08)


# ================================================================================================ the ring's moments
def _gong(r, f0: float, dur: float, bloom: float = 0.012) -> np.ndarray:
    n = N(dur)
    t = T(n)
    ratios = np.array([1.0, 1.47, 1.98, 2.45, 2.94, 3.39, 3.98, 4.6, 5.3, 6.1, 7.0, 8.2, 9.4, 11.0])
    ratios = ratios * r.uniform(0.985, 1.015, len(ratios))
    taus = 3.4 * ratios ** -0.55 * r.uniform(0.8, 1.2, len(ratios))
    amps = ratios ** -0.7 * r.uniform(0.6, 1.2, len(ratios))
    y = np.zeros(n)
    for f, tau, a in zip(f0 * ratios, taus, amps):
        glide = 1.0 + 0.012 * (1.0 - np.exp(-t / 0.5))      # the pitch blooming up a little as it sounds
        for beat in (1.0, 1.0 + r.uniform(0.002, 0.006)):   # each mode a near pair: the gong's slow wah
            y += a * 0.5 * np.sin(2 * math.pi * np.cumsum(f * beat * glide) / dsp.SR + r.uniform(0, 6)) \
                * dsp.ar_env(n, 0.004, tau)
    shimmer = band(noise(n, r), 900.0, 4000.0, 4) * hump(n, 0.25, 1.1, 1.0) * wobble(n, 5.0, 0.5, r)
    mallet = band(noise(N(0.03), r), 80.0, 1500.0, 2) * dsp.exp_env(N(0.03), 0.006)
    y = y / (np.max(np.abs(y)) + 1e-12)
    y = mix(n, (y, 0.0, 1.0), (shimmer / (np.std(shimmer) + 1e-12), 0.0, bloom), (mallet, 0.0, 0.25))
    return room(dsp.fade_out(y, dur * 0.3), r, 1.6, 0.18)


def round_gong(r) -> np.ndarray:
    return _gong(r, r.uniform(98.0, 115.0), r.uniform(3.6, 4.2))


def match_gong(r) -> np.ndarray:
    return _gong(r, r.uniform(68.0, 78.0), r.uniform(4.8, 5.4), 0.018)


def round_bell(r) -> np.ndarray:
    f = r.uniform(950.0, 1150.0)
    ratios = np.array([0.5, 1.0, 1.19, 1.5, 2.0, 2.5, 2.66, 3.0, 4.17, 5.43]) * r.uniform(0.995, 1.005, 10)
    taus = np.array([2.0, 1.5, 1.1, 0.85, 0.65, 0.45, 0.4, 0.33, 0.2, 0.14])
    amps = np.array([0.35, 1.0, 0.55, 0.4, 0.5, 0.25, 0.2, 0.18, 0.12, 0.08])
    ir = dsp.modal_ir(f * ratios, taus, amps, 3.0, r)
    gap = r.uniform(0.26, 0.32)
    dur = 2 * gap + 3.0
    n = N(dur)
    y = np.zeros(n)
    for k, v in enumerate([1.0, 0.85, 1.0]):
        strike = dsp.convolve_same(np.concatenate([dsp.mallet(0.0008), np.zeros(len(ir))]), ir)
        dsp.place(y, strike, k * gap, v)
        dsp.place(y, band(noise(N(0.004), r), 2000.0, None, 2), k * gap, 0.15 * v)
    return room(dsp.fade_out(y, 1.0), r, 1.2, 0.12)


def count_tick(r) -> np.ndarray:
    f = r.uniform(1050.0, 1250.0)
    return dsp.strike([f, f * 2.57, f * 4.1], [0.045, 0.015, 0.008], [1.0, 0.35, 0.15], 0.25, contact=0.0006, r=r,
                      noise=0.2)
