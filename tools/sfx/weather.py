#!/usr/bin/env python3
"""Weather family for Frontier (cloud engine, 2026-09-26): thunder and rain.

Usage (from the project root):
  python3 tools/sfx/weather.py                 # default seed, every sound
  python3 tools/sfx/weather.py --seed 7        # another take
  python3 tools/sfx/weather.py --out /tmp/wx   # write somewhere else
Then run a Godot import pass (Godot --headless --path . --import).

Output: audio/sfx/weather/<id>_<NN>.wav, 44.1 kHz 16-bit, synthesised with numpy (dsp.py):
  thunder_near_01..03  a close stroke: the tearing crack of the channel (broadband bursts from its nearest
                       segments), then the rolling rumble as sound from farther segments arrives (6-8 s)
  thunder_far_01..03   a distant stroke: no crack, the air has taken the highs; a low roll that swells and fades
                       (7-10 s)
  rain_loop_01         30 s stereo bed of steady rain on grass and leaves (filtered noise + thousands of drop
                       ticks), a seamless loop with a RIFF 'smpl' loop
These are not in the Sfx manifest (tools/sfx/gen_manifest.py): WeatherFx (scripts/world/env/weather_fx.gd) loads
them by path and sets their level from the distance and the rain rate.
"""
from __future__ import annotations

import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dsp  # noqa: E402
from dsp import SR, nsamp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "audio", "sfx", "weather")


def env_curve(n: int, times, values) -> np.ndarray:
    t = np.arange(n) / SR
    return np.interp(t, times, values)


def rumble(n: int, r: np.random.Generator, fc: float, rolls: int, dur: float) -> np.ndarray:
    """Low rolling noise: brown noise low-passed at fc, amplitude-modulated by `rolls` swells."""
    x = dsp.lowpass(dsp.brown(n, r), fc, 4)
    x += 0.4 * dsp.lowpass(dsp.pink(n, r), fc * 1.8, 2)
    t = np.arange(n) / SR
    am = np.zeros(n)
    for _ in range(rolls):
        c = r.uniform(0.3, dur * 0.8)
        w = r.uniform(0.3, 1.2)
        am += r.uniform(0.4, 1.0) * np.exp(-((t - c) / w) ** 2)
    am += 0.25 * (0.5 + 0.5 * dsp.smooth_noise(n, 3.0, r))
    return x * am


def thunder_near(r: np.random.Generator) -> np.ndarray:
    dur = r.uniform(6.0, 8.0)
    n = nsamp(dur)
    out = np.zeros(n)
    # the crack: a few broadband bursts in the first 150 ms (the channel's nearest segments)
    t0 = 0.05
    for _ in range(r.integers(3, 6)):
        k = nsamp(r.uniform(0.004, 0.02))
        burst = dsp.highpass(r.standard_normal(k), 400.0, 2) * np.exp(-np.arange(k) / (k * 0.4))
        dsp.place(out, burst, t0, r.uniform(0.6, 1.0))
        t0 += r.uniform(0.01, 0.05)
    # the tearing: crackle over 0.6 s
    k = nsamp(0.8)
    crackle = dsp.bandpass(r.standard_normal(k), 300.0, 6000.0, 2) * (r.random(k) < 0.02) * 3.0
    crackle = dsp.lowpass(crackle, 5000.0, 2) * env_curve(k, [0, 0.1, 0.8], [1.0, 0.6, 0.0])
    dsp.place(out, crackle, 0.08, 0.5)
    # the peal and the roll
    peal = dsp.lowpass(r.standard_normal(n), 900.0, 2) * env_curve(n, [0, 0.12, 0.3, 1.2, dur], [0, 1.0, 0.7, 0.2, 0.0])
    roll = rumble(n, r, 160.0, 6, dur) * env_curve(n, [0, 0.2, 1.0, dur * 0.7, dur], [0, 0.8, 1.0, 0.5, 0.0])
    out += 0.35 * peal / (np.max(np.abs(peal)) + 1e-9) + 0.9 * roll / (np.max(np.abs(roll)) + 1e-9)
    return dsp.finalize(out, -1.0, fade=0.5, lead_trim=False)


def thunder_far(r: np.random.Generator) -> np.ndarray:
    dur = r.uniform(7.0, 10.0)
    n = nsamp(dur)
    roll = rumble(n, r, 110.0, 8, dur)
    roll *= env_curve(n, [0, 0.6, 1.5, dur * 0.6, dur], [0, 0.6, 1.0, 0.6, 0.0])
    return dsp.finalize(roll, -3.0, fade=0.8, lead_trim=False)


def rain_loop(r: np.random.Generator) -> np.ndarray:
    dur = 32.0
    n = nsamp(dur)
    ch = []
    for c in range(2):
        hiss = dsp.bandpass(dsp.pink(n, r), 800.0, 9000.0, 2) * 0.35
        hiss += dsp.bandpass(r.standard_normal(n), 3000.0, 12000.0, 2) * 0.12
        # drops on leaves and grass: thousands of short resonant ticks
        drops = np.zeros(n)
        count = int(dur * 900)
        pos = r.integers(0, n - 800, count)
        amp = r.uniform(0.05, 1.0, count) ** 2
        for p, a in zip(pos, amp):
            k = int(r.integers(80, 500))
            f = r.uniform(1500.0, 7000.0)
            tt = np.arange(k) / SR
            drops[p:p + k] += a * np.sin(2 * np.pi * f * tt) * np.exp(-tt / r.uniform(0.001, 0.006))
        drops = dsp.highpass(drops, 600.0, 2)
        low = dsp.lowpass(dsp.brown(n, r), 300.0, 2) * 0.15
        sig = hiss + 0.25 * drops / (np.max(np.abs(drops)) + 1e-9) + low
        sig *= 0.85 + 0.15 * dsp.smooth_noise(n, 0.3, r)
        ch.append(sig)
    x = np.stack(ch, axis=-1)
    x = dsp.loop_xfade(x, 2.0)
    return dsp.peak_norm(x, dsp.db2lin(-1.0))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, default=1765)
    ap.add_argument("--out", default=OUT_DIR)
    a = ap.parse_args()
    r = dsp.rng(a.seed)
    for i in range(3):
        dsp.write_wav(os.path.join(a.out, "thunder_near_%02d.wav" % (i + 1)), thunder_near(r), seed=a.seed + i)
        dsp.write_wav(os.path.join(a.out, "thunder_far_%02d.wav" % (i + 1)), thunder_far(r), seed=a.seed + 10 + i)
    loop = rain_loop(r)
    dsp.write_wav_loop(os.path.join(a.out, "rain_loop_01.wav"), loop, seed=a.seed + 20)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
