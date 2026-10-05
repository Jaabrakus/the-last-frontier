"""The ring's crowd for Tidebreak (tools/sfx/bend/bend_sfx.py writes them): synthesized voices, no recordings.

A voice is a buzzing source (a sawtooth at the voice's pitch, its pitch wandering a little, some breath) through the
resonances of a vowel (three formants; women's and children's a sixth higher). The crowd is many of them, grouped by
vowel and filtered together, at a distance (the top end rolled off) in the open-air stands (a short room).
  murmur   (loop) people talking: each talker a run of syllables with pauses, the vowel changing every syllable
           (a time-varying formant filter per talker), all of it soft and far
  cheer    shouts swelling up ("ah", "ay", "oh", rising pitch), clapping, a whistle or two
  roar     the cheer bigger and longer: more voices, hard clapping, stamping, whistles
  groan    "oh" and "aw" falling in pitch: the stands' disappointment
  ooh      a short gasp then an "ooh" rising and falling: a near thing
"""
from __future__ import annotations

import math

import numpy as np

from kit import N, T, band, dsp, events, mix, noise, plateau, room, wobble

VOWELS = {"a": (800, 1150, 2900), "o": (480, 820, 2830), "u": (340, 720, 2530), "e": (420, 1900, 2600),
          "ae": (680, 1700, 2450), "uh": (620, 1100, 2600), "aw": (650, 950, 2700)}
F_AMPS = (1.0, 0.55, 0.22)


def _formant_mag(f: np.ndarray, vowel: str, shift: float) -> np.ndarray:
    m = np.zeros_like(f, dtype=float)
    for fc, a in zip(VOWELS[vowel], F_AMPS):
        fc = fc * shift
        m += a * dsp.mag_resonance(f, fc, fc / (60.0 + fc * 0.06))
    return (m + 0.01) * dsp.mag_lowpass(f, 900.0 * shift, 1) * dsp.mag_highpass(f, 90.0, 2)


def _source(r, f0: np.ndarray, breath: float = 0.2) -> np.ndarray:
    """A voice's buzz: a sawtooth on the pitch track f0 (per sample) with a little breath."""
    ph = np.cumsum(f0) / dsp.SR + r.uniform(0, 1)
    saw = 2.0 * (ph % 1.0) - 1.0
    return saw + breath * noise(len(f0), r)


def _shouts(r, n: int, count: int, vowels, f_male, f_female, start_sd: float, attack, hold, release,
            bend: float = 0.15, fall: float = 0.0, bursts: float = 0.2) -> np.ndarray:
    """`count` voices shouting, each its vowel, its pitch (rising by `bend` at the onset, falling by `fall` over the
    shout), its start (reaction times), a share of them in short bursts ("hey! hey!")."""
    groups: dict = {}
    t = T(n)
    for _ in range(count):
        female = r.random() < 0.45
        v = vowels[r.integers(len(vowels))]
        base = r.uniform(*(f_female if female else f_male))
        t0 = abs(r.normal(0.0, start_sd))
        a, h, rl = r.uniform(*attack), r.uniform(*hold), r.uniform(*release)
        tt = np.maximum(t - t0, 0.0)
        f0 = base * (1.0 + bend * (1.0 - np.exp(-tt / 0.12)) - bend * 0.3) * (1.0 - fall * np.clip(tt / (a + h + rl), 0, 1))
        f0 = f0 * (1.0 + 0.012 * dsp.smooth_noise(n, 6.0, r) + 0.006 * np.sin(2 * math.pi * r.uniform(4.5, 6.5) * t))
        e = np.zeros(n)
        k = N(t0)
        if r.random() < bursts:
            for _b in range(r.integers(2, 4)):
                seg = plateau(N(0.5), 0.04, r.uniform(0.12, 0.22), 0.12)
                dsp.place(e, seg, t0, 1.0)
                t0 += r.uniform(0.35, 0.5)
        else:
            seg = plateau(n - k, a, h, rl)
            e[k:] = seg[:n - k]
        e *= wobble(n, 7.0, 0.25, r)
        x = _source(r, f0) * e * r.uniform(0.5, 1.0)
        key = (v, female)
        groups[key] = groups.get(key, 0.0) + x
    y = np.zeros(n)
    for (v, female), x in groups.items():
        y += dsp.fft_filter(x, lambda f, v=v, s=(1.17 if female else 1.0): _formant_mag(f, v, s), minphase=False)[:n]
    return y / (np.std(y) + 1e-12)


def _claps(r, n: int, rate: np.ndarray) -> np.ndarray:
    """Hands clapping at `rate` claps a second (an array per sample)."""
    y = np.zeros(n)
    for t in events(r, n, rate):
        m = N(r.uniform(0.006, 0.014))
        c = noise(m, r) * dsp.exp_env(m, r.uniform(0.002, 0.005))
        fc = r.uniform(900.0, 2600.0)                      # cupped hands low, flat hands high
        c = band(c, fc / 1.7, fc * 1.7, 2) + 0.2 * c
        dsp.place(y, c, t, r.uniform(0.2, 1.0))
    return y / (np.std(y) + 1e-12)


def _whistle(r, dur: float) -> np.ndarray:
    n = N(dur)
    t = T(n)
    f_a, f_b = r.uniform(1800.0, 2400.0), r.uniform(2500.0, 3200.0)
    f = np.interp(t, [0.0, dur * 0.3, dur], [f_a, f_b, f_b * r.uniform(0.85, 1.0)]) \
        * (1.0 + 0.01 * np.sin(2 * math.pi * 6.0 * t))
    tone = np.sin(2 * math.pi * np.cumsum(f) / dsp.SR) * plateau(n, 0.05, dur - 0.15, 0.1)
    return tone + 0.08 * band(noise(n, r), 1500.0, 5000.0, 2) * plateau(n, 0.05, dur - 0.15, 0.1)


def _far(x: np.ndarray, r, wet: float = 0.3, top: float = 4500.0) -> np.ndarray:
    """At the stands' distance in the open: the top rolled off, a short room."""
    return room(dsp.fade_out(band(x, 70.0, top, 1), 0.25), r, 1.3, wet, 0.03, 3500.0)


def cheer(r) -> np.ndarray:
    dur = r.uniform(2.1, 2.6)
    n = N(dur)
    v = _shouts(r, n, 54, ["a", "ae", "e", "o", "a"], (150, 260), (260, 470), 0.12, (0.08, 0.2), (0.5, 1.3),
                (0.3, 0.6), 0.18, 0.05, 0.25)
    e = plateau(n, 0.15, dur * 0.35, dur * 0.5)
    claps = _claps(r, n, 45.0 * plateau(n, 0.35, dur * 0.4, dur * 0.4))
    wh = np.zeros(n)
    for _ in range(r.integers(1, 4)):
        dsp.place(wh, _whistle(r, r.uniform(0.4, 0.8)), r.uniform(0.15, dur * 0.5), r.uniform(0.3, 0.6))
    return _far(mix(n, (v * e, 0.0, 1.0), (claps, 0.0, 0.35), (wh, 0.0, 0.25)), r)


def roar(r) -> np.ndarray:
    dur = r.uniform(3.0, 3.6)
    n = N(dur)
    v = _shouts(r, n, 96, ["a", "ae", "e", "o", "a", "aw"], (150, 280), (270, 500), 0.15, (0.08, 0.25), (1.0, 2.2),
                (0.4, 0.9), 0.22, 0.06, 0.3)
    e = plateau(n, 0.12, dur * 0.4, dur * 0.5)
    claps = _claps(r, n, 75.0 * plateau(n, 0.3, dur * 0.45, dur * 0.45))
    stamps = np.zeros(n)
    t = 0.3
    while t < dur * 0.8:                                     # feet stamping on the boards, loosely together
        for _ in range(12):
            th = dsp.strike([r.uniform(70, 110), r.uniform(180, 260)], [0.06, 0.03], [1.0, 0.4], 0.2, contact=0.006)
            dsp.place(stamps, th, t + r.normal(0.0, 0.03), r.uniform(0.3, 1.0))
        t += r.uniform(0.38, 0.46)
    wh = np.zeros(n)
    for _ in range(r.integers(3, 6)):
        dsp.place(wh, _whistle(r, r.uniform(0.4, 0.9)), r.uniform(0.1, dur * 0.6), r.uniform(0.3, 0.6))
    rumble = band(dsp.brown(n, r), 60.0, 400.0, 2) * e
    return _far(mix(n, (v * e, 0.0, 1.0), (claps, 0.0, 0.4), (stamps / (np.max(np.abs(stamps)) + 1e-12), 0.0, 0.3),
                    (wh, 0.0, 0.25), (rumble / (np.std(rumble) + 1e-12), 0.0, 0.15)), r, 0.35)


def groan(r) -> np.ndarray:
    dur = r.uniform(1.7, 2.2)
    n = N(dur)
    v = _shouts(r, n, 48, ["o", "aw", "u", "uh", "o"], (110, 190), (210, 340), 0.08, (0.1, 0.2), (0.4, 0.9),
                (0.4, 0.7), 0.1, 0.3, 0.0)
    e = plateau(n, 0.12, dur * 0.3, dur * 0.55)
    return _far(v * e, r, 0.3, 3500.0)


def ooh(r) -> np.ndarray:
    dur = r.uniform(1.1, 1.4)
    n = N(dur)
    gasp = band(noise(N(0.12), r), 700.0, 4000.0, 2) * plateau(N(0.12), 0.03, 0.03, 0.06)
    v = _shouts(r, n, 44, ["u", "o", "u"], (140, 230), (250, 400), 0.06, (0.1, 0.18), (0.25, 0.5), (0.35, 0.55),
                0.35, 0.25, 0.0)
    e = plateau(n, 0.14, dur * 0.25, dur * 0.55)
    return _far(mix(n, (gasp, 0.0, 0.25), (v * e, 0.08, 1.0)), r, 0.3, 3800.0)


def murmur(r, dur: float = 13.5, talkers: int = 30) -> np.ndarray:
    """People talking in the stands, `dur` s (bend_sfx.py cross-fades it into a loop)."""
    n = N(dur)
    n_fft, hop = 1024, 256
    f = np.fft.rfftfreq(n_fft, 1.0 / dsp.SR)
    vkeys = list(VOWELS)
    y = np.zeros(n)
    for _ in range(talkers):
        female = r.random() < 0.45
        s = 1.17 if female else 1.0
        table = np.stack([_formant_mag(f, v, s) for v in vkeys])
        base = r.uniform(*((190, 290) if female else (100, 160)))
        # syllables: (start, length, vowel, accent), with pauses between phrases
        sylls = []
        t = r.uniform(0.0, 1.0)
        while t < dur:
            for _w in range(r.integers(3, 12)):
                d = r.uniform(0.11, 0.26)
                sylls.append((t, d, r.integers(len(vkeys)), r.uniform(0.5, 1.0)))
                t += d + r.uniform(0.0, 0.05)
            t += r.uniform(0.25, 1.4)
        e = np.zeros(n)
        f0 = np.full(n, base)
        frame_v = np.zeros(int(np.ceil(n / hop)) + 1, dtype=int)
        for st, d, vi, acc in sylls:
            m = N(d)
            dsp.place(e, np.hanning(m) ** 0.7 * acc, st, 1.0)
            a, b = N(st), min(N(st + d), n)
            if a < n:
                f0[a:b] = base * (1.0 + 0.12 * (acc - 0.75) + 0.05 * np.linspace(0.5, -0.5, b - a))
                frame_v[a // hop:b // hop + 1] = vi
        f0 = np.convolve(f0, np.ones(N(0.02)) / N(0.02), mode="same")
        x = _source(r, f0, 0.25) * e
        X = dsp.stft(x, n_fft, hop)
        g = table[frame_v[:X.shape[0]]]
        y += dsp.istft(X * g, n_fft, hop, n) * r.uniform(0.4, 1.0)
    y = y / (np.std(y) + 1e-12)
    return band(_far(y, r, 0.45, 3000.0)[:n], 80.0, None, 2)
