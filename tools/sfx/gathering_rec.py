#!/usr/bin/env python3
"""gathering_rec family for Frontier (push n12s): mining, chopping and tree-fall sounds built from CC0 recordings.

Usage (from the project root):
  python3 tools/sfx/gathering_rec.py                  # every sound, default seed
  python3 tools/sfx/gathering_rec.py --only gather_rec_pick_rock gather_rec_axe_chop
  python3 tools/sfx/gathering_rec.py --seed 7 --out /tmp/gathering --png /tmp/gathering_png
  python3 tools/sfx/gathering_rec.py --src ~/Downloads/Frontier_assets_staging/cc0_sfx
Then python3 tools/sfx/gen_manifest.py and a Godot import pass (see gen_all.py).

Sources: real recordings from six CC0 1.0 packs (Kenney, kheetor, rubberduck; see PACKS below and the generated
audio/sfx/gathering_rec/SOURCE.md and MANIFEST.json). The system python3 cannot decode Ogg Vorbis, so the takes are
decoded once by Blender (tools/sfx/cc0_decode.py, audaspace) into a cache (--cache, default <tmp>/frontier_cc0_decoded);
the packs stay where they were unpacked (--src). Only the finished, layered WAVs are kept in the project. Procedural
synthesis (dsp.py) only fills what the recordings lack (the mattock head's lower modes, the stone's low knock, the
trunk's ground thud, leaf contacts, the crown's air rush, low rumbles).

Output: audio/sfx/gathering_rec/<id>_<NN>.wav, 44.1 kHz 16-bit mono, plus SOURCE.md and MANIFEST.json (packs, authors,
URLs, licence, the takes each sound uses and their hashes) and gathering_rec_manifest.json (per-id loudness and
in-game levels, read by gen_manifest.py). The ids have the gather_rec_ prefix: the gathering push's own synthesized
sounds (tools/sfx/gathering.py, audio/sfx/gathering/) keep their names.
  gather_rec_pick_rock        (5) mattock / pick on rock: the steel's sharp contact click, a short bright inharmonic
                              ring of the iron head, the stone's dull knock, grit and chips scattering and settling
  gather_rec_pick_rock_hard   (4) a stronger stroke that bites deeper: more knock and chips, a shorter ring
  gather_rec_rock_split       (4) a piece breaks off: a lower crack, grit trickling, the heavier chunk dropping, rubble
  gather_rec_rock_depleted    (3) the last of the outcrop gives way: a big break, blocks dropping, a slide of rubble
  gather_rec_axe_chop         (5) felling axe into a standing trunk: the bite, the trunk's woody resonance, a chip
  gather_rec_axe_chop_big     (4) the same into a big trunk (lower, longer body)
  gather_rec_axe_chop_sapling (4) a thin sapling: a lighter, higher, springy cut with a shiver of its leaves
  gather_rec_buck             (5) bucking a fallen log: drier, shorter chops, the log damped by the ground
  gather_rec_tree_crack       (3) the hinge lets go: fibres cracking and tearing, the trunk's groan, a last tear
  gather_rec_tree_fall        (3) the crown's swish through the air and neighbouring branches, peaking at PEAK_S
                              (1.6 s; GatherSfx starts it so the peak meets the landing), 0.5 s of tail after it
  gather_rec_tree_land        (3) the trunk hits the ground: heavy thud, a bounce, branches crunching, leaves settling
Levels: every variant of an id is matched in short-term loudness (100 ms, K-weighted) and the id is scaled so its
loudest variant peaks at -1 dBFS; the SOUNDS table sets each id's in-game loudness at a typical listener distance
against the existing sounds (a musket ball into wood at 4 m, the player's steps, the musket shot).
"""
from __future__ import annotations

import argparse
import glob
import hashlib
import json
import os
import subprocess
import sys
import tempfile

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dsp  # noqa: E402

SR = dsp.SR
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "audio", "sfx", "gathering_rec")
SRC = os.path.expanduser("~/Downloads/Frontier_assets_staging/cc0_sfx")
CACHE = os.path.join(tempfile.gettempdir(), "frontier_cc0_decoded")
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"

# --------------------------------------------------------------------------- sources

PACKS = {
    "kenney_impact-sounds": {
        "title": "Impact Sounds 1.0", "author": "Kenney (Kenney Vleugels, www.kenney.nl)",
        "url": "https://kenney.nl/assets/impact-sounds", "archive": "kenney_impact-sounds.zip",
        "archive_sha256": "029d734af1582474..."},
    "kenney_rpg-audio": {
        "title": "RPG Audio", "author": "Kenney (Kenney Vleugels, www.kenney.nl)",
        "url": "https://kenney.nl/assets/rpg-audio", "archive": "kenney_rpg-audio.zip",
        "archive_sha256": "6dbeaf8544da958d..."},
    "kheetor_chop-tree-fall": {
        "title": "Tree chop, fall, thud", "author": "kheetor",
        "url": "https://opengameart.org/content/tree-chop-fall-thud", "archive": "chop-tree-fall.ogg",
        "archive_sha256": "21842dd004b46315..."},
    "sfx_breaking_and_falling": {
        "title": "75 CC0 breaking / falling / hit sfx", "author": "rubberduck",
        "url": "https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx",
        "archive": "sfx_breaking_and_falling.zip", "archive_sha256": "e6ee04d91c5f4d30..."},
    "100-CC0-wood-metal-SFX": {
        "title": "100 CC0 metal and wood SFX", "author": "rubberduck",
        "url": "https://opengameart.org/content/100-cc0-metal-and-wood-sfx",
        "archive": "100-CC0-wood-metal-SFX.zip", "archive_sha256": "be6eba63b03409ac..."},
    "sfx_100_v2": {
        "title": "100 CC0 SFX #2", "author": "rubberduck",
        "url": "https://opengameart.org/content/100-cc0-sfx-2", "archive": "sfx_100_v2.zip",
        "archive_sha256": "0fc61b4494e2e893..."},
}
LICENSE = "CC0 1.0 Universal (public domain dedication, https://creativecommons.org/publicdomain/zero/1.0/)"


def _take_path(name: str) -> str:
    """Pack-relative path of a take (by basename without .ogg)."""
    if name == "chop-tree-fall":
        return "kheetor_chop-tree-fall/chop-tree-fall.ogg"
    if name.startswith("impact") or name.startswith("footstep_"):
        return "kenney_impact-sounds/Audio/%s.ogg" % name
    if name in ("chop", "creak1", "creak2", "creak3"):
        return "kenney_rpg-audio/Audio/%s.ogg" % name
    if name.startswith("bfh1_"):
        return "sfx_breaking_and_falling/%s.ogg" % name
    if name.startswith("sfx100v2_"):
        return "sfx_100_v2/%s.ogg" % name
    return "100-CC0-wood-metal-SFX/%s.ogg" % name


class Sources:
    """Loads takes from the decode cache (decoding missing ones with Blender) and records which sound used which."""

    def __init__(self, src: str, cache: str, blender: str):
        self.src, self.cache, self.blender = src, cache, blender
        self._mem: dict = {}
        self.used: dict = {}          # sound id -> set of take names
        self.current = ""

    def _npy(self, name: str) -> str:
        rel = _take_path(name)
        return os.path.join(self.cache, rel.split("/")[0], name + ".npy")

    def prefetch(self, names) -> None:
        missing = sorted({n for n in names if not os.path.exists(self._npy(n))})
        if not missing:
            return
        for n in missing:
            if not os.path.exists(os.path.join(self.src, _take_path(n))):
                raise SystemExit("missing CC0 take %s under %s (see SOURCE.md for the packs)" % (_take_path(n), self.src))
        print("decoding %d takes with Blender ..." % len(missing), flush=True)
        cmd = [self.blender, "--background", "--factory-startup", "--python", os.path.join(HERE, "cc0_decode.py"),
               "--", self.src, self.cache] + [_take_path(n) for n in missing]
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, timeout=600)

    def get(self, name: str) -> np.ndarray:
        """Mono float take (channels averaged), 44.1 kHz."""
        self.used.setdefault(self.current, set()).add(name)
        if name not in self._mem:
            p = self._npy(name)
            if not os.path.exists(p):
                self.prefetch([name])
            d = np.load(p).astype(float)
            self._mem[name] = d.mean(axis=1) if d.ndim == 2 else d
        return self._mem[name]

    def sha256(self, name: str) -> str:
        with open(os.path.join(self.src, _take_path(name)), "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()


S: Sources  # set in main()


# --------------------------------------------------------------------------- helpers

def cut(x: np.ndarray, t0: float, t1: float | None = None, fin: float = 0.0005, fout: float = 0.008) -> np.ndarray:
    """Excerpt [t0, t1) s with short raised-cosine fades."""
    a = max(dsp.nsamp(t0), 0)
    b = len(x) if t1 is None else min(dsp.nsamp(t1), len(x))
    y = np.array(x[a:b], dtype=float)
    if fin > 0:
        dsp.fade_in(y, fin)
    if fout > 0:
        dsp.fade_out(y, fout)
    return y


def onset(x: np.ndarray, rel_db: float = -24.0) -> float:
    """Time (s) where the 1 ms envelope first reaches rel_db below its maximum."""
    w = dsp.nsamp(0.001)
    e = np.sqrt(np.convolve(x * x, np.ones(w) / w, mode="same"))
    i = int(np.argmax(e >= e.max() * dsp.db2lin(rel_db)))
    return max(i - dsp.nsamp(0.0015), 0) / SR


def from_onset(x: np.ndarray, dur: float, rel_db: float = -24.0, fout: float = 0.01) -> np.ndarray:
    t0 = onset(x, rel_db)
    return cut(x, t0, t0 + dur, 0.0003, fout)


def repitch(x: np.ndarray, ratio: float) -> np.ndarray:
    """Band-limited resample: ratio > 1 plays higher and shorter (tape-speed pitch shift)."""
    if abs(ratio - 1.0) < 1e-4 or len(x) < 4:
        return np.array(x, dtype=float)
    n = len(x)
    pad = dsp.nsamp(0.02)
    xp = np.concatenate([x, np.zeros(pad)])
    N = len(xp)
    M = max(int(round(N / ratio)), 4)
    X = np.fft.rfft(xp)
    k = M // 2 + 1
    Y = np.zeros(k, dtype=complex)
    m = min(k, len(X))
    Y[:m] = X[:m]
    if ratio > 1.0:          # anti-alias: a gentle roll-off below the new Nyquist
        f = np.arange(k) / k
        Y *= 1.0 / np.sqrt(1.0 + (f / 0.92) ** 16)
    y = np.fft.irfft(Y, M) * (M / N)
    return y[:int(round(n / ratio))]


def decay_after(x: np.ndarray, t: float, tau: float) -> np.ndarray:
    """Extra exponential decay (time constant tau) from time t on: shortens a ring or a room tail."""
    y = np.array(x, dtype=float)
    i = dsp.nsamp(t)
    if i < len(y):
        y[i:] *= np.exp(-dsp.taxis(len(y) - i) / tau)
    return y


def band(x: np.ndarray, lo: float | None = None, hi: float | None = None, order: int = 2) -> np.ndarray:
    """Causal (minimum-phase) Butterworth band limit by FFT; lo/hi None = open."""
    def mag(f):
        h = np.ones_like(f)
        if lo:
            h = h * dsp.mag_highpass(f, lo, order)
        if hi:
            h = h * dsp.mag_lowpass(f, hi, order)
        return h
    return dsp.fft_filter(x, mag)[:len(x)]


def eq(x: np.ndarray, f0: float, gain_db: float, q: float = 0.9, kind: str = "peak") -> np.ndarray:
    return dsp.biquad(x, *dsp.biquad_coeffs(kind, f0, q, gain_db))


def norm(x: np.ndarray) -> np.ndarray:
    return dsp.peak_norm(np.asarray(x, dtype=float), 1.0)


def mix(n_s: float, *layers) -> np.ndarray:
    """Sum layers given as (signal, t_start, gain) into a buffer of n_s seconds."""
    out = np.zeros(dsp.nsamp(n_s))
    for sig, t, g in layers:
        dsp.place(out, sig, t, g)
    return out


def grains(x: np.ndarray, thresh_db: float = -34.0, rise_db: float = 8.0, max_len: float = 0.07,
           min_len: float = 0.006) -> list:
    """Split a take into its individual short events (a chip landing, a fibre snapping).

    An onset is where the 1 ms envelope sits rise_db over its level 4 ms earlier and above thresh_db (re the
    take's peak); a grain runs to the next onset or max_len, or until it falls 30 dB under its own peak."""
    w = dsp.nsamp(0.001)
    e = np.sqrt(np.convolve(x * x, np.ones(w) / w, mode="same")) + 1e-9
    edb = 20 * np.log10(e / e.max())
    lag = dsp.nsamp(0.004)
    cand = np.nonzero((edb[lag:] > thresh_db) & (edb[lag:] - edb[:-lag] > rise_db))[0] + lag
    starts = []
    for i in cand:
        if not starts or i - starts[-1] > dsp.nsamp(0.012):
            starts.append(int(i))
    out = []
    for k, s in enumerate(starts):
        a = max(s - dsp.nsamp(0.003), 0)
        b = min(len(x), a + dsp.nsamp(max_len))
        if k + 1 < len(starts):
            b = min(b, starts[k + 1] - dsp.nsamp(0.002))
        seg_e = e[a:b]
        if len(seg_e) < dsp.nsamp(min_len):
            continue
        pk = int(np.argmax(seg_e))
        below = np.nonzero(seg_e[pk:] < seg_e[pk] * dsp.db2lin(-30.0))[0]
        if len(below):
            b = min(b, a + pk + int(below[0]) + dsp.nsamp(0.002))
        g = np.array(x[a:b], dtype=float)
        if len(g) < dsp.nsamp(min_len):
            continue
        dsp.fade_in(g, 0.0008)
        dsp.fade_out(g, min(0.006, len(g) / SR * 0.4))
        out.append(norm(g))
    return out


_BANKS: dict = {}


def bank(names, **kw) -> list:
    """Grain bank from several takes (cached per argument set)."""
    key = (tuple(names), tuple(sorted(kw.items())))
    for n in names:
        S.get(n)            # record use for SOURCE.md
    if key not in _BANKS:
        g = []
        for n in names:
            g += grains(S.get(n), **kw)
        _BANKS[key] = g
    return _BANKS[key]


def scatter(r: np.random.Generator, pool: list, n: int, t0: float, mean_gap: float, dur: float,
            gain: float, tau: float, pitch=(0.9, 1.3), hi_close: float = 9000.0, darken: float = 0.0) -> np.ndarray:
    """Debris: n grains from `pool` at exponentially spread times after t0, quieter (and duller when darken > 0)
    the later they land."""
    out = np.zeros(dsp.nsamp(dur))
    t = t0
    for _ in range(n):
        g = pool[int(r.integers(len(pool)))]
        g = repitch(g, r.uniform(*pitch))
        age = t - t0
        lvl = gain * np.exp(-age / tau) * r.uniform(0.35, 1.0)
        if darken > 0:
            g = band(g, None, max(hi_close * np.exp(-age * darken), 1500.0))
        dsp.place(out, g, t, lvl)
        t += r.exponential(mean_gap)
        if t > dur - 0.05:
            break
    return out


def k_weight(x: np.ndarray) -> np.ndarray:
    """Approximate ITU-R BS.1770 K-weighting (high shelf +4 dB over ~1.7 kHz, highpass 38 Hz)."""
    y = dsp.biquad(x, *dsp.biquad_coeffs("highshelf", 1681.0, 0.707, 4.0))
    return dsp.biquad(y, *dsp.biquad_coeffs("hp", 38.0, 0.5))


def st_loudness(x: np.ndarray, win: float = 0.1) -> float:
    """Short-term loudness proxy: the loudest 100 ms window of the K-weighted signal (dB re full scale)."""
    y = k_weight(np.asarray(x, dtype=float))
    w = dsp.nsamp(win)
    if len(y) <= w:
        return dsp.lin2db(float(np.sqrt(np.mean(y * y))) + 1e-12)
    c = np.cumsum(np.concatenate([[0.0], y * y]))
    ms = (c[w:] - c[:-w]) / w
    return 10.0 * np.log10(float(ms.max()) + 1e-24)


def denoise(x: np.ndarray, over: float = 2.0, floor: float = 0.08, pct: float = 20.0) -> np.ndarray:
    """Spectral subtraction of a recording's steady hiss / room tone: each bin's noise level is its pct-th percentile
    magnitude over time; `over` times that is subtracted, never below `floor` of the original magnitude."""
    X = dsp.stft(x, 2048, 512)
    mag = np.abs(X)
    noise = np.percentile(mag, pct, axis=0)[None, :]
    gain = np.maximum(1.0 - over * noise / (mag + 1e-12), floor)
    # smooth the gain over time a little (fewer musical-noise chirps)
    k = np.ones(3) / 3.0
    gain = np.apply_along_axis(lambda g: np.convolve(g, k, mode="same"), 0, gain)
    return dsp.istft(X * gain, 2048, 512, len(x))


def finish(x: np.ndarray, fade: float = 0.03) -> np.ndarray:
    """DC-block, trim, fade; level is set later per id (loudness match)."""
    return dsp.finalize(x, peak_db=-1.0, fade=fade, thresh_db=-62.0, hp=25.0)


# --------------------------------------------------------------------------- mining

RING = ["bfh1_hit_11", "hammer_02", "hammer_03", "hammer_04", "metal_hit_05", "bfh1_hit_05"]
KNOCK = ["bfh1_rock_hit_01", "bfh1_hit_03", "sfx100v2_hit_02", "sfx100v2_hit_03"]
GRIT = ["bfh1_rock_falling_02", "bfh1_rock_falling_04", "bfh1_rock_falling_05", "bfh1_rock_falling_07",
        "bfh1_rock_falling_08", "sfx100v2_stones_01", "sfx100v2_stones_02", "sfx100v2_stones_03"]


def stone_thock(r: np.random.Generator, f0: float, tau: float) -> np.ndarray:
    """Procedural fill: the dull knock of a big stone (a few heavily damped low-mid modes over a noise burst)."""
    n = dsp.nsamp(0.1)
    ex = dsp.white(dsp.nsamp(0.005), r) * dsp.mallet(0.005)
    fr = [f0, f0 * r.uniform(1.5, 1.8), f0 * r.uniform(2.4, 3.0), f0 * r.uniform(3.8, 4.8)]
    ir = dsp.modal_ir(fr, [tau, tau * 0.8, tau * 0.6, tau * 0.45], [1.0, 0.8, 0.55, 0.35], 0.1, r)
    y = norm(dsp.convolve_same(np.concatenate([ex, np.zeros(n)]), ir)[:n])
    k = dsp.nsamp(0.06)
    burst = band(dsp.white(k, r) * dsp.exp_env(k, 0.009), 250.0, 1600.0)
    y[:k] += 0.8 * norm(burst)
    return norm(y)


def iron_head(r: np.random.Generator, f1: float, tau: float, dur: float = 0.3) -> np.ndarray:
    """Procedural fill: the mattock head's own ring. The head is a steel bar about 45 cm long, so its first
    free-free bending modes sit near 0.8, 2.1, 4.2 and 6.9 kHz (ratios 1 : 2.76 : 5.40 : 8.93, inharmonic); the
    haft, the hands and the stone the point is in damp them within a few tens of ms. The recorded rings are small hammers (partials near 6-8 kHz); this adds
    the heavier tool's lower modes under them."""
    ratios = [1.0, 2.756, 5.404, 8.933]
    freqs = [f1 * q * r.uniform(0.985, 1.015) for q in ratios]
    taus = [tau, tau, tau * 0.8, tau * 0.6]
    amps = [0.45, 1.0, 0.8, 0.35]
    y = dsp.strike(freqs, taus, amps, dur, contact=0.00025, r=r, noise=0.3)
    return norm(band(y, 500.0, None, 2))


def pick_rock(seed: int, v: int, hard: bool) -> np.ndarray:
    """Mattock / pick on rock. Layers, all from the contact:
      ring    a recorded metal strike slowed to a heavier head (0.74-0.88: its 6-8 kHz partials down to about
              4.5-6.5 kHz), highpassed and damped by the stone (tau 50-80 ms; a hard stroke bites deeper: 35-50)
      head    the procedural iron-head modes (iron_head) under it, short (tau 10-22 ms) and low in the mix
      knock   a recorded rock hit over a procedural low-mid thock: the stone's dull body
      crumble the struck face powdering (a slice of recorded rubble hiss)
      spray / settle  chips flying at the blow, then pieces landing and settling (grains of recorded gravel)"""
    r = dsp.rng(seed)
    dur = 0.8
    # the iron head: contact click and a short bright ring (handle and hand lows removed, damped by the stone)
    ring = from_onset(S.get(RING[(v + (3 if hard else 0)) % len(RING)]), 0.3)
    ring = band(ring, 900.0, None, 2)
    ring = decay_after(ring, 0.004, r.uniform(0.035, 0.05) if hard else r.uniform(0.05, 0.08))
    ring = repitch(ring, r.uniform(0.74, 0.88))
    head = iron_head(r, r.uniform(700.0, 880.0), r.uniform(0.01, 0.015) if hard else r.uniform(0.015, 0.022))
    # the stone's dull knock: a recorded rock hit over a procedural low-mid thock
    knock = from_onset(S.get(KNOCK[(v + (2 if hard else 0)) % len(KNOCK)]), 0.14)
    knock = decay_after(band(knock, 180.0, 7000.0), 0.012, 0.035)
    thock = stone_thock(r, r.uniform(240.0, 340.0) * (0.85 if hard else 1.0), r.uniform(0.006, 0.01))
    # crumble: the struck face powdering (a slice of a recorded rubble hiss)
    cr = S.get("bfh1_falling_06")
    t0 = r.uniform(0.06, 0.2)
    crumble = decay_after(band(cut(cr, t0, t0 + 0.25, 0.002, 0.03), 1500.0, 12000.0), 0.0, 0.05)
    # chips: a spray at the blow, then pieces landing and settling around the feet (small: lows removed)
    pool = bank(GRIT)
    spray = scatter(r, pool, int(r.integers(4, 7)) + (3 if hard else 0), 0.002, 0.012, dur, 1.0, 0.04,
                    pitch=(1.0, 1.35))
    settle = scatter(r, pool, int(r.integers(7, 11)) + (5 if hard else 0), r.uniform(0.09, 0.14), 0.04, dur,
                     1.0, 0.2, pitch=(1.1, 1.6), darken=1.5)
    spray = band(spray, 1000.0, None, 4)
    settle = band(settle, 900.0, None, 4)
    x = mix(dur,
            (norm(ring), 0.0, 0.6 if hard else 0.75),
            (head, 0.0, 0.15 if hard else 0.18),
            (norm(knock), 0.0005, 0.62 if hard else 0.5),
            (thock, 0.0, 0.55 if hard else 0.4),
            (norm(crumble), 0.004, 0.12 if hard else 0.08),
            (norm(spray), 0.0, 0.3 if hard else 0.22),
            (norm(settle), 0.0, 0.16 if hard else 0.12))
    x = eq(x, 9000.0, -4.0, 0.7, "highshelf")
    return finish(x, 0.05)


CRACK = ["bfh1_rock_breaking_01", "bfh1_rock_breaking_02", "bfh1_rock_breaking_03"]
CHUNK = [("bfh1_rock_falling_01", 0.205), ("bfh1_rock_falling_03", 0.27), ("bfh1_hit_08", 0.0),
         ("bfh1_rock_falling_09", 0.0)]
RUBBLE = ["bfh1_rock_falling_01", "bfh1_rock_falling_03", "bfh1_rock_falling_09", "bfh1_rock_breaking_02",
          "bfh1_rock_falling_05"]


def rumble(r: np.random.Generator, dur: float, env: np.ndarray, hi: float = 160.0) -> np.ndarray:
    """Procedural fill: the low rumble of rock moving (brown noise under `hi`, shaped by env)."""
    n = dsp.nsamp(dur)
    y = band(dsp.brown(n, r), 45.0, hi, 2)
    return norm(y * env[:n])


def rock_split(seed: int, v: int) -> np.ndarray:
    r = dsp.rng(seed)
    dur = 1.1
    # a lower crack as the piece lets go: the first crack(s) of a rock-breaking take, slowed down
    src = S.get(CRACK[v % len(CRACK)])
    t0 = onset(src)
    crack = cut(src, t0, t0 + r.uniform(0.09, 0.14), 0.0003, 0.02)
    crack = repitch(crack, r.uniform(0.72, 0.84))
    crack = decay_after(crack, 0.03, 0.05)
    # the chunk drops onto the ground: a heavy recorded hit, a little lower
    name, tc = CHUNK[v % len(CHUNK)]
    ch = S.get(name)
    t1 = tc + onset(cut(ch, tc, tc + 0.2, 0.0, 0.0))
    chunk = decay_after(cut(ch, t1, t1 + 0.3, 0.0005, 0.04), 0.05, 0.07)
    chunk = repitch(chunk, r.uniform(0.78, 0.9))
    t_drop = r.uniform(0.2, 0.3)
    # rubble: small pieces rattling after it
    pool = bank(RUBBLE)
    rub = scatter(r, pool, int(r.integers(9, 15)), t_drop + 0.02, 0.035, dur, 1.0, 0.3, pitch=(0.8, 1.15),
                  darken=1.0)
    n = dsp.nsamp(dur)
    t = dsp.taxis(n)
    env = np.clip((t - t_drop) / 0.02, 0, 1) * np.exp(-np.maximum(t - t_drop, 0) / 0.1)
    # grit trickling from the fresh fracture while the piece drops (grains and a faint hiss of powder), so the
    # crack and the landing read as one event rather than two with silence between
    trickle = scatter(r, bank(GRIT), int(r.integers(5, 9)), 0.05, 0.025, dur, 1.0, 1.0, pitch=(1.1, 1.5))
    cr = S.get("bfh1_falling_06")
    a = r.uniform(0.05, 0.2)
    hiss = band(cut(cr, a, a + t_drop, 0.03, 0.04), 1500.0, 10000.0, 2)
    x = mix(dur,
            (norm(crack), 0.0, 0.9),
            (norm(hiss), 0.06, 0.05),
            (norm(chunk), t_drop, 0.75),
            (rumble(r, dur, env), 0.0, 0.1),
            (norm(band(trickle, 900.0, None, 4)), 0.0, 0.13),
            (norm(rub), 0.0, 0.3))
    return finish(x, 0.08)


def rock_depleted(seed: int, v: int) -> np.ndarray:
    r = dsp.rng(seed)
    dur = 2.4
    n = dsp.nsamp(dur)
    t = dsp.taxis(n)
    # the big break: a whole rock-breaking take slowed right down (deeper, heavier), a second crack after it
    big = S.get("bfh1_rock_breaking_01")
    t0 = onset(big)
    brk = repitch(cut(big, t0, t0 + 0.55, 0.0003, 0.08), r.uniform(0.66, 0.74))
    src2 = S.get(CRACK[1 + v % 2])
    t2 = onset(src2)
    crack2 = repitch(decay_after(cut(src2, t2, t2 + 0.12, 0.0003, 0.02), 0.03, 0.05), r.uniform(0.75, 0.9))
    # blocks dropping: two or three heavy hits
    hits = np.zeros(n)
    th = r.uniform(0.22, 0.3)
    for k in range(int(r.integers(2, 4))):
        name, tc = CHUNK[(v + k) % len(CHUNK)]
        ch = S.get(name)
        t1 = tc + onset(cut(ch, tc, tc + 0.2, 0.0, 0.0))
        h = repitch(decay_after(cut(ch, t1, t1 + 0.35, 0.0005, 0.05), 0.05, 0.09), r.uniform(0.7, 0.85))
        dsp.place(hits, norm(h), th, r.uniform(0.55, 0.9) * (0.8 ** k))
        th += r.uniform(0.12, 0.3)
    # the rubble slide: a dense stream of grains, swelling then thinning out, over a low rumble
    pool = bank(RUBBLE)
    slide = np.zeros(n)
    ts = 0.3
    while ts < 1.9:
        dens = np.exp(-max(ts - 0.55, 0.0) / 0.45) * min((ts - 0.25) / 0.2, 1.0)
        g = repitch(pool[int(r.integers(len(pool)))], r.uniform(0.75, 1.2))
        dsp.place(slide, g, ts, r.uniform(0.3, 1.0) * dens)
        ts += r.exponential(0.012 + 0.08 * (1.0 - dens))
    slide = band(slide, None, 9000.0)
    env = np.clip((t - 0.2) / 0.1, 0, 1) * np.exp(-np.maximum(t - 0.45, 0) / 0.35)
    x = mix(dur,
            (norm(brk), 0.0, 0.85),
            (norm(crack2), r.uniform(0.12, 0.18), 0.5),
            (norm(hits), 0.0, 0.8),
            (rumble(r, dur, env, 140.0), 0.0, 0.12),
            (norm(slide), 0.0, 0.35))
    return finish(x, 0.25)


# --------------------------------------------------------------------------- chopping

BODY = ["wood_hit_08", "sfx100v2_wood_hit_02", "bfh1_wood_hit_03", "sfx100v2_wood_hit_01", "wood_hit_04",
        "bfh1_wood_hit_02"]
BITE = ["chop", "wood_hit_01", "wood_hit_06", "bfh1_wood_hit_01", "wood_hit_02"]
TICK = ["wood_cracking_01", "wood_cracking_03", "bfh1_wood_breaking_01", "bfh1_wood_breaking_02",
        "wood_cracking_04"]


def axe_real(r: np.random.Generator, tail: float) -> np.ndarray:
    """The recorded felling chop (kheetor): the strike with its own trunk ring, the room/forest tail cut short."""
    k = S.get("chop-tree-fall")
    t0 = onset(cut(k, 0.0, 0.2, 0.0, 0.0), -20.0)
    y = cut(k, t0, t0 + 0.45, 0.0003, 0.05)
    y = decay_after(y, 0.03, tail)
    return norm(repitch(y, r.uniform(0.95, 1.05)))


def body_take(name: str, lo: float, hi: float, tail: float, ratio: float) -> np.ndarray:
    y = from_onset(S.get(name), 0.35, fout=0.03)
    y = band(band(y, lo, None, 4), None, hi, 2)
    return norm(repitch(decay_after(y, 0.015, tail), ratio))


def bite_take(name: str, ratio: float, lo: float = 350.0) -> np.ndarray:
    y = from_onset(S.get(name), 0.2, fout=0.02)
    y = decay_after(band(y, lo, None, 2), 0.006, 0.03)
    return norm(repitch(y, ratio))


def chip(r: np.random.Generator, dur: float, t0: float, n: int, gain: float) -> np.ndarray:
    """A chip or two flying off: small bright wood ticks after the blow."""
    pool = bank(TICK, thresh_db=-30.0)
    y = scatter(r, pool, n, t0, 0.05, dur, 1.0, 0.15, pitch=(1.0, 1.5))
    return norm(band(y, 1500.0, 10000.0, 2)) * gain


def axe_chop(seed: int, v: int, big: bool) -> np.ndarray:
    r = dsp.rng(seed)
    dur = 0.7 if big else 0.55
    ratio = r.uniform(0.86, 0.93) if big else r.uniform(0.97, 1.06)
    tail = r.uniform(0.09, 0.13) if big else r.uniform(0.055, 0.08)
    body = body_take(BODY[(v + (3 if big else 0)) % len(BODY)], 75.0 if big else 95.0, 1100.0 if big else 1500.0, tail, ratio)
    layers = [(body, 0.0, 0.8 if big else 0.62)]
    if v % 2 == 0:
        # the recorded felling chop carries the blow; a recorded bite sharpens its edge
        layers.append((axe_real(r, tail * 0.9), 0.0, 0.95))
        layers.append((bite_take(BITE[(v // 2) % len(BITE)], ratio * r.uniform(1.0, 1.08)), 0.0, 0.3))
    else:
        layers.append((bite_take(BITE[(v // 2 + 2) % len(BITE)], ratio * r.uniform(1.0, 1.08)), 0.0, 0.85))
        layers.append((axe_real(r, tail * 0.6), 0.002, 0.35))
    layers.append((chip(r, dur, r.uniform(0.05, 0.1), int(r.integers(1, 3)), 0.12), 0.0, 1.0))
    return finish(mix(dur, *layers), 0.06)


def rustle(r: np.random.Generator, dur: float, rate, gain, lo: float = 1500.0, hi: float = 9000.0) -> np.ndarray:
    """Procedural fill: leaves brushing each other, as a stream of tiny contacts (0.4-3 ms noise ticks).

    rate(t): contacts per second, gain(t): their level; both callables of time in seconds."""
    n = dsp.nsamp(dur)
    out = np.zeros(n)
    t = 0.0
    while t < dur:
        rt = rate(t)
        if rt < 1.0:
            t += 0.005
            continue
        k = max(dsp.nsamp(r.uniform(0.0004, 0.003)), 3)
        g = dsp.white(k, r) * np.hanning(k)
        dsp.place(out, g, t, gain(t) * r.uniform(0.15, 1.0))
        t += r.exponential(1.0 / rt)
    return band(out, lo, hi, 2)


def leaf_shiver(r: np.random.Generator, dur: float, tau: float) -> np.ndarray:
    """A sapling's leaves shivering after the cut: a burst of leaf contacts that flutters and dies away."""
    f = r.uniform(9.0, 14.0)
    ph = r.uniform(0.0, 3.0)
    y = rustle(r, dur, lambda t: 1500.0 * np.exp(-t / tau) * (0.4 + 0.6 * abs(np.sin(2 * np.pi * f * t + ph))),
               lambda t: min(t / 0.02, 1.0) * np.exp(-t / (tau * 1.5)), 1800.0, 10000.0)
    return norm(y)


def axe_chop_sapling(seed: int, v: int) -> np.ndarray:
    r = dsp.rng(seed)
    dur = 0.6
    ratio = r.uniform(1.12, 1.28)
    bite = bite_take(BITE[v % len(BITE)], ratio, 500.0)
    body = body_take(BODY[(v + 1) % len(BODY)], 200.0, 2500.0, 0.03, ratio * 1.15)
    tick = norm(band(repitch(bank(TICK, thresh_db=-30.0)[(3 * v + 1) % len(bank(TICK, thresh_db=-30.0))], r.uniform(1.0, 1.3)), 1200.0, None, 2))
    x = mix(dur,
            (bite, 0.0, 0.9),
            (body, 0.0, 0.38),
            (tick, r.uniform(0.004, 0.012), 0.35),
            (leaf_shiver(r, dur, r.uniform(0.07, 0.11)), r.uniform(0.02, 0.04), 0.1))
    return finish(x, 0.08)


BUCK_BITE = ["wood_hit_01", "chop", "bfh1_wood_hit_01", "wood_hit_06", "wood_hit_03"]
BUCK_BODY = ["sfx100v2_wood_hit_03", "bfh1_wood_hit_03", "wood_hit_09", "wood_hit_04", "wood_hammer_02"]


def buck(seed: int, v: int) -> np.ndarray:
    """A chop into a log lying on the ground: drier and shorter, the ground damping the ring; a dull thump."""
    r = dsp.rng(seed)
    dur = 0.45
    ratio = r.uniform(0.92, 1.04)
    bite = bite_take(BUCK_BITE[v % len(BUCK_BITE)], ratio * r.uniform(1.0, 1.1), 400.0)
    body = body_take(BUCK_BODY[(v + 2) % len(BUCK_BODY)], 90.0, 1600.0, r.uniform(0.03, 0.045), ratio)
    n = dsp.nsamp(0.08)
    thump = norm(band(dsp.white(n, r) * dsp.exp_env(n, 0.012), 45.0, 180.0, 2))
    layers = [(bite, 0.0, 0.85), (body, 0.0, 0.6), (thump, 0.002, 0.25)]
    if v % 2 == 1:
        layers.append((chip(r, dur, r.uniform(0.04, 0.08), 1, 0.06), 0.0, 1.0))
    if v % 3 == 0:
        layers.append((axe_real(r, 0.035), 0.0, 0.4))
    return finish(mix(dur, *layers), 0.05)


# --------------------------------------------------------------------------- the tree comes down

SNAP = ["wood_cracking_01", "wood_cracking_02", "wood_cracking_03", "wood_cracking_04", "bfh1_wood_breaking_01",
        "bfh1_wood_breaking_02", "bfh1_wood_breaking_04"]
TEAR = [("wood_breaking_01", 0.0), ("bfh1_wood_breaking_03", 0.0), ("wood_breaking_02", 0.0)]
GROAN = ["creak1", "creak2", "creak3"]
BRUSH = ["sfx100v2_footstep_01", "sfx100v2_footstep_02"]
LAND_BODY = ["sfx100v2_wood_hit_01", "sfx100v2_wood_hit_02", "wood_hit_08", "bfh1_wood_hit_02"]
BRANCH = ["wood_breaking_01", "wood_breaking_02", "bfh1_wood_breaking_03", "bfh1_wood_breaking_04",
          "bfh1_wood_falling_01", "bfh1_wood_falling_02", "sfx100v2_wood_01"]


def groan(r: np.random.Generator, name: str, ratio: float, dur: float) -> np.ndarray:
    """The trunk's groan: a recorded wooden creak slowed right down, bending slowly in pitch."""
    src = from_onset(S.get(name), 0.9, -30.0, 0.05)
    y = repitch(src, ratio)
    # a slow pitch wander (variable-rate read), then a gentle band limit: wood, not a door hinge
    n = len(y)
    rate = 1.0 + 0.06 * dsp.smooth_noise(n, 3.0, r) - 0.05 * np.linspace(0.0, 1.0, n)
    pos = np.cumsum(rate)
    pos = pos[pos < n - 1]
    y = np.interp(pos, np.arange(n), y)
    y = band(band(y, 90.0, None, 4), None, 2400.0, 2)
    # stick-slip roughness: the fibres grind rather than sing
    rough = np.abs(dsp.smooth_noise(len(y), 45.0, r))
    y = y * (0.45 + 0.9 * rough / (rough.max() + 1e-9))
    y = y[:dsp.nsamp(dur)]
    dsp.fade_in(y, 0.08)
    dsp.fade_out(y, 0.15)
    return norm(y)


def tree_crack(seed: int, v: int) -> np.ndarray:
    """The last strokes are through: the hinge fibres crack one by one, faster and faster, the trunk groans as it
    leans, and a last long tear as it lets go (plays when the tree starts to fall)."""
    r = dsp.rng(seed)
    dur = 2.6
    n = dsp.nsamp(dur)
    # the recorded felling: the fibres cracking and the trunk creaking after the last chop (kheetor, 0.2-1.58 s)
    k = S.get("chop-tree-fall")
    rec = denoise(cut(k, 0.28, 1.6, 0.0, 0.0))[dsp.nsamp(0.06):]
    rec = band(rec, 70.0, None, 4)
    dsp.fade_in(rec, 0.08)
    dsp.fade_out(rec, 0.3)
    ratio = r.uniform(0.84, 0.95)
    rec = repitch(rec, ratio)
    # more fibre snaps, accelerating towards the tear, which comes as the recording's cracking runs out
    pool = bank(SNAP, thresh_db=-30.0)
    snaps = np.zeros(n)
    t = r.uniform(0.05, 0.15)
    t_tear = len(rec) / SR - r.uniform(0.06, 0.16)
    while t < t_tear:
        g = repitch(pool[int(r.integers(len(pool)))], r.uniform(0.6, 0.95))
        dsp.place(snaps, g, t, r.uniform(0.25, 1.0) * (0.4 + 0.6 * t / t_tear))
        t += r.uniform(0.05, 0.28) * (1.0 - 0.75 * t / t_tear)
    snaps = band(snaps, 250.0, 9000.0, 2)
    # the groan: two slowed creaks, the second lower
    g1 = groan(r, GROAN[v % 3], r.uniform(0.38, 0.46), 1.0)
    g2 = groan(r, GROAN[(v + 1) % 3], r.uniform(0.3, 0.36), 1.1)
    # the tear: a big wood-breaking take, slowed, as the hinge lets go
    name, t0 = TEAR[v % len(TEAR)]
    tear = from_onset(S.get(name), 0.55, fout=0.12)
    tear = repitch(decay_after(tear, 0.1, 0.25), r.uniform(0.62, 0.72))
    x = mix(dur,
            (norm(rec), 0.0, 0.6),
            (norm(snaps), 0.0, 0.5),
            (g1, r.uniform(0.25, 0.45), 0.2),
            (g2, r.uniform(0.95, 1.15), 0.24),
            (norm(tear), t_tear, 0.95))
    return finish(x, 0.3)


def air_rush(r: np.random.Generator, dur: float, peak: float) -> np.ndarray:
    """Procedural fill: the crown's rush through the air, rising with its speed (a band of pink noise opening
    upwards as the swing accelerates), cut at the ground."""
    n = dsp.nsamp(dur)
    t = dsp.taxis(n)
    speed = np.exp((t - peak) / 0.38) * (t <= peak) + (t > peak) * np.exp(-(t - peak) / 0.1)
    fc = 250.0 + 1400.0 * speed
    y = dsp.svf(dsp.pink(n, r), fc, 0.8, "bp")
    y = band(y, 120.0, 6000.0, 2)
    flutter = 1.0 + 0.35 * dsp.smooth_noise(n, 18.0, r)
    passes = 1.0 + 0.4 * dsp.smooth_noise(n, 5.5, r)          # branches sweeping past, one after another
    return norm(y * speed ** 1.4 * flutter * passes)


def tree_fall(seed: int, v: int) -> np.ndarray:
    """The crown sweeping down through the air and the neighbours' branches: a rising swish of leaves and air
    with twigs snapping, peaking at PEAK_S (play it so the peak meets the landing). After the peak the rush dies
    in about 0.1 s and the thrashing leaves over 0.3 s, so a landing a little early or late is still covered and
    the swish never stops dead."""
    r = dsp.rng(seed)
    dur = FALL_S
    peak = PEAK_S
    n = dsp.nsamp(dur)
    t = dsp.taxis(n)
    speed = lambda tt: float(np.exp((tt - peak) / 0.4)) if tt <= peak else float(np.exp(-(tt - peak) / 0.12))
    thrash = lambda tt: speed(tt) if tt <= peak else float(np.exp(-(tt - peak) / 0.3))
    # leaves thrashing: recorded brushes of foliage at growing density ...
    bed = np.zeros(n)
    tb = 0.1
    while tb < dur - 0.25:
        src = S.get(BRUSH[int(r.integers(len(BRUSH)))])
        a = r.uniform(0.02, max(len(src) / SR - 0.2, 0.03))
        sl = cut(src, a, a + r.uniform(0.08, 0.18), 0.02, 0.04)
        dsp.place(bed, repitch(sl, r.uniform(0.85, 1.25)), tb, r.uniform(0.4, 1.0) * thrash(tb))
        tb += r.uniform(0.04, 0.12) * (1.1 - 0.8 * thrash(tb))
    bed = band(band(bed, 400.0, None, 2), None, 7000.0, 2)
    # ... over a stream of leaf contacts
    leaves = rustle(r, dur, lambda tt: 300.0 + 2500.0 * thrash(tt), lambda tt: thrash(tt), 1200.0, 9000.0)
    # twigs snapping in the neighbours' crowns
    pool = bank(SNAP, thresh_db=-30.0)
    twigs = np.zeros(n)
    for _ in range(int(r.integers(3, 6))):
        tt = peak - r.uniform(0.0, 0.7)
        dsp.place(twigs, repitch(pool[int(r.integers(len(pool)))], r.uniform(1.0, 1.4)), tt,
                  r.uniform(0.3, 1.0) * speed(tt))
    x = mix(dur,
            (air_rush(r, dur, peak), 0.0, 0.8),
            (norm(bed), 0.0, 0.4),
            (norm(leaves), 0.0, 0.25),
            (norm(band(twigs, 800.0, None, 2)), 0.0, 0.3))
    y = dsp.dc_block(x, 25.0)
    dsp.fade_in(y, 0.05)
    dsp.fade_out(y, 0.12)
    return dsp.peak_norm(y, dsp.db2lin(-1.0))          # no trim: the peak must stay at PEAK_S


PEAK_S = 1.6      # tree_fall's swish peaks this long after it starts (GatherSfx.FALL_PEAK_S)
FALL_S = PEAK_S + 0.5    # its length: the tail after the peak


def thud(r: np.random.Generator, f0: float, tau: float) -> np.ndarray:
    """Procedural fill: the deep whump of the trunk's weight on the ground (a low, falling, damped swing)."""
    n = dsp.nsamp(0.5)
    t = dsp.taxis(n)
    f = f0 * (1.0 + 0.5 * np.exp(-t / 0.03))
    y = dsp.sine_sweep(n, f) * dsp.ar_env(n, 0.004, tau)
    y += 0.5 * band(dsp.white(n, r), 40.0, 250.0, 2) * dsp.ar_env(n, 0.002, tau * 0.5) / 3.0
    return norm(y)


def tree_land(seed: int, v: int) -> np.ndarray:
    """The trunk hits the ground: the recorded felled tree landing (kheetor) over a deep thud, a smaller bounce,
    branches snapping and crunching under the crown, then leaves and twigs settling."""
    r = dsp.rng(seed)
    dur = 3.0
    n = dsp.nsamp(dur)
    k = S.get("chop-tree-fall")
    a = 1.58 + onset(cut(k, 1.58, 1.75, 0.0, 0.0), -20.0)
    rec = denoise(cut(k, a - 0.05, None, 0.0, 0.0))[dsp.nsamp(0.05):]
    rec = band(rec, 40.0, None, 4)
    # the take's low end stops abruptly where the recording fades into its noise gate: let it die away first
    rec = decay_after(rec, 0.35, 0.18)
    dsp.fade_in(rec, 0.0005)
    dsp.fade_out(rec, 0.3)
    rec = repitch(rec, r.uniform(0.86, 0.96))
    boom = thud(r, r.uniform(62.0, 76.0), r.uniform(0.07, 0.1))
    # the trunk's own woody body on the ground: heavy wood hits slowed right down
    body = body_take(LAND_BODY[v % len(LAND_BODY)], 60.0, 700.0, r.uniform(0.12, 0.16), r.uniform(0.55, 0.65))
    t_b = r.uniform(0.28, 0.4)
    bounce = thud(r, r.uniform(70.0, 85.0), 0.06)
    bounce_body = body_take(LAND_BODY[(v + 1) % len(LAND_BODY)], 80.0, 900.0, 0.06, r.uniform(0.7, 0.8))
    # branches snapping and crunching under the crown
    pool = bank(BRANCH, thresh_db=-32.0, max_len=0.12)
    br = np.zeros(n)
    tt = 0.01
    for _ in range(int(r.integers(12, 18))):
        g = repitch(pool[int(r.integers(len(pool)))], r.uniform(0.7, 1.1))
        dsp.place(br, g, tt, r.uniform(0.3, 1.0) * np.exp(-tt / 0.5))
        tt += r.exponential(0.06)
        if tt > 1.4:
            break
    big = from_onset(S.get(TEAR[(v + 1) % len(TEAR)][0]), 0.5, fout=0.1)
    big = repitch(decay_after(big, 0.08, 0.2), r.uniform(0.75, 0.85))
    # leaves settling: the brushes again, sparse and fading, and a few late twigs dropping
    bed = np.zeros(n)
    tb = 0.03
    while tb < 0.6:
        src = S.get(BRUSH[int(r.integers(len(BRUSH)))])
        s0 = r.uniform(0.02, max(len(src) / SR - 0.2, 0.03))
        sl = cut(src, s0, s0 + r.uniform(0.1, 0.2), 0.03, 0.05)
        dsp.place(bed, repitch(sl, r.uniform(0.9, 1.2)), tb, r.uniform(0.4, 1.0) * np.exp(-tb / 0.35))
        tb += r.uniform(0.03, 0.08)
    bed = band(band(bed, 500.0, None, 2), None, 8000.0, 2)
    leaves = rustle(r, dur, lambda q: 3000.0 * np.exp(-q / 0.6), lambda q: min(q / 0.03, 1.0) * np.exp(-q / 0.8),
                    1500.0, 9000.0)
    late = scatter(r, bank(SNAP, thresh_db=-30.0), int(r.integers(3, 6)), 0.6, 0.35, dur, 1.0, 0.9,
                   pitch=(1.1, 1.6))
    # the ground and the trunk settling: a low rumble dying away over a second (covers the take's own end)
    t = dsp.taxis(n)
    settle = rumble(r, dur, np.clip(t / 0.03, 0, 1) * np.exp(-t / 0.45), 220.0)
    x = mix(dur,
            (norm(rec), 0.0, 0.85),
            (settle, 0.0, 0.14),
            (boom, 0.0, 0.45),
            (body, 0.0, 0.7),
            (bounce, t_b, 0.2),
            (bounce_body, t_b, 0.3),
            (norm(br), 0.0, 0.4),
            (norm(big), r.uniform(0.02, 0.08), 0.35),
            (norm(bed), 0.0, 0.22),
            (norm(leaves), 0.02, 0.22),
            (norm(band(late, 1000.0, None, 2)), 0.0, 0.12))
    # tilt: less sub rumble (the recording and the thud carry plenty), more of the thud's audible body
    x = eq(dsp.highpass(x, 60.0, 2), 180.0, 3.0, 0.8)
    return finish(x, 0.4)


# --------------------------------------------------------------------------- the family

# id: (variants, builder(seed, v), in-game loudness target (dB, st_loudness at the listener), unit_size,
#      typical listener distance (m), max_distance, random pitch, random volume (+-dB/2))
# Targets sit against the existing sounds measured the same way: a musket shot at the player ~ -7, a musket ball
# into wood at 4 m ~ -9.5, the player's walking steps ~ -34. An axe chop lands about 11 dB under the shot and
# 16 dB over the steps; the tree crashing down is the loudest thing here, still under the shot.
SOUNDS = {
    "gather_rec_pick_rock": (5, lambda s, v: pick_rock(s, v, False), -19.0, 5.0, 4.0, 150.0, 1.05, 2.0),
    "gather_rec_pick_rock_hard": (4, lambda s, v: pick_rock(s, v, True), -17.5, 5.0, 4.0, 160.0, 1.05, 2.0),
    "gather_rec_rock_split": (4, rock_split, -20.0, 5.0, 4.0, 150.0, 1.04, 1.5),
    "gather_rec_rock_depleted": (3, rock_depleted, -17.0, 6.0, 4.0, 200.0, 1.03, 1.0),
    "gather_rec_axe_chop": (5, lambda s, v: axe_chop(s, v, False), -18.5, 5.0, 4.0, 220.0, 1.05, 2.0),
    "gather_rec_axe_chop_big": (4, lambda s, v: axe_chop(s, v, True), -17.5, 5.0, 4.0, 240.0, 1.04, 2.0),
    "gather_rec_axe_chop_sapling": (4, axe_chop_sapling, -23.0, 4.0, 4.0, 80.0, 1.06, 2.0),
    "gather_rec_buck": (5, buck, -20.0, 5.0, 4.0, 180.0, 1.05, 2.0),
    "gather_rec_tree_crack": (3, tree_crack, -19.0, 10.0, 5.0, 250.0, 1.03, 1.0),
    "gather_rec_tree_fall": (3, tree_fall, -19.0, 12.0, 9.0, 200.0, 1.02, 1.0),
    "gather_rec_tree_land": (3, tree_land, -12.0, 20.0, 12.0, 400.0, 1.03, 1.0),
}
# fixed per-id seed offsets, so --only renders the same takes as a full run
SEED_OFS = {sid: 100 * i for i, sid in enumerate(SOUNDS)}


def dist_gain(unit: float, d: float) -> float:
    """Godot's inverse-distance attenuation at d metres (dB)."""
    return 20.0 * np.log10(unit / max(d, 0.1))


def band_metrics(x: np.ndarray) -> dict:
    """Numbers to judge a sound by without hearing it: attack, decay, centroid, band shares, the 2-8 kHz band's
    decay (a steel ring) and the count of separate small events after 50 ms (debris, snaps)."""
    m = dsp.analyze(x)
    X = np.abs(np.fft.rfft(x, dsp._nfft(len(x)))) ** 2
    f = np.fft.rfftfreq(dsp._nfft(len(x)), 1.0 / SR)
    tot = X.sum() + 1e-20
    edges = [(20, 150), (150, 600), (600, 2000), (2000, 8000), (8000, 20000)]
    shares = {"%d-%d" % e: round(10.0 * np.log10(X[(f >= e[0]) & (f < e[1])].sum() / tot + 1e-12), 1) for e in edges}
    w = dsp.nsamp(0.002)
    hb = dsp.fft_filter(x, lambda q: dsp.mag_bandpass(q, 2000.0, 8000.0, 4), minphase=False)[:len(x)]
    e = np.sqrt(np.convolve(hb * hb, np.ones(w) / w, mode="same"))
    i = int(np.argmax(e))
    # the ring: how long the 2-8 kHz band stays within 30 dB of its peak (the first gap of 10 ms under it ends it)
    under = e[i:] < e[i] * dsp.db2lin(-30.0)
    run = np.convolve(under.astype(float), np.ones(dsp.nsamp(0.01)), mode="valid")
    gaps = np.nonzero(run >= dsp.nsamp(0.01))[0]
    ring_ms = 1000.0 * gaps[0] / SR if len(gaps) else len(x) / SR * 1000.0
    tail = x[dsp.nsamp(0.05):]
    events = len(grains(tail, thresh_db=-40.0, rise_db=8.0)) if len(tail) > dsp.nsamp(0.02) else 0
    env = np.sqrt(np.convolve(x * x, np.ones(w) / w, mode="same"))
    ipk = int(np.argmax(env))
    b20 = np.nonzero(env[ipk:] >= env[ipk] * 0.1)[0]
    return {"dur_ms": round(len(x) / SR * 1000.0), "peak_db": round(m["peak_dbfs"], 1),
            "st_lufs": round(st_loudness(x), 1), "centroid_hz": round(m["centroid_hz"]),
            "attack_ms": round(m["attack_ms"], 1), "decay20_ms": round(1000.0 * b20[-1] / SR),
            "ring_2_8k_t30_ms": round(ring_ms), "events_after_50ms": events, "bands_db": shares}


def write_source_md(out: str, used: dict) -> None:
    takes: dict = {}
    for sid, names in used.items():
        if sid in SOUNDS:
            for nm in names:
                takes.setdefault(nm, set()).add(sid)
    lines = [
        "# Gathering sounds: sources",
        "",
        "GENERATED by `tools/sfx/gathering_rec.py` (rerun it to update). The WAVs in this folder are the project's own",
        "mixes, layered and processed from real recordings in six CC0 sound packs (downloaded with the owner's",
        "approval on 2026-09-26; staged outside the project in `~/Downloads/Frontier_assets_staging/cc0_sfx/`, whose",
        "PROVENANCE.md has the archive sizes and hashes). Only the finished mixes are kept here; the recordings",
        "themselves are not copied into the project.",
        "",
        "Licence of every source pack: " + LICENSE + ". CC0 asks for no attribution; the authors are credited",
        "anyway (here, in MANIFEST.json and in CREDITS.md). Procedural fills (dsp.py synthesis: the mattock head's",
        "lower modes, the stone's low knock, the trunk's ground thud, leaf contacts, the crown's air rush, the low",
        "rumbles of rock and ground) are the project's own. `MANIFEST.json` lists the same in machine-readable form.",
        "",
        "## Packs",
        "",
        "| Pack (staging folder) | Title | Author | Source URL | Archive (sha256 prefix) | Licence |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for key, p in PACKS.items():
        lines.append("| `%s` | %s | %s | %s | `%s` (`%s`) | CC0 1.0 |" % (
            key, p["title"], p["author"], p["url"], p["archive"], p["archive_sha256"]))
    lines += ["", "## Takes used by each sound", "", "| Sound id | Takes |", "| --- | --- |"]
    for sid in SOUNDS:
        names = sorted(used.get(sid, []))
        lines.append("| `%s` | %s |" % (sid, ", ".join("`%s`" % n for n in names)))
    lines += ["", "## Takes", "", "| Take (pack-relative path) | sha256 of the .ogg | Used by |", "| --- | --- | --- |"]
    for nm in sorted(takes):
        try:
            h = S.sha256(nm)
        except OSError:
            h = "(pack not found at generation)"
        lines.append("| `%s` | `%s` | %s |" % (_take_path(nm), h, ", ".join(sorted(takes[nm]))))
    lines.append("")
    with open(os.path.join(out, "SOURCE.md"), "w") as fh:
        fh.write("\n".join(lines))
    # the same, machine-readable (like assets/polyhaven/MANIFEST.json)
    man = {
        "source": "six CC0 sound packs (Kenney; kheetor and rubberduck on OpenGameArt.org)",
        "license": LICENSE + "; no attribution required (credited anyway)",
        "approved_by_user": "2026-09-26 (see the staging folder's PROVENANCE.md)",
        "generator": "tools/sfx/gathering_rec.py",
        "note": "The files in this folder are the project's own mixes of these takes (plus procedural fills); the "
                "recordings themselves are not copied into the project.",
        "packs": [dict(key=k, **{q: v for q, v in p.items()}) for k, p in PACKS.items()],
        "takes": [],
        "outputs": {},
    }
    for nm in sorted(takes):
        key = _take_path(nm).split("/")[0]
        try:
            h = S.sha256(nm)
        except OSError:
            h = ""
        man["takes"].append({"file": _take_path(nm), "pack": key, "author": PACKS[key]["author"],
                             "url": PACKS[key]["url"], "license": "CC0 1.0", "sha256": h,
                             "used_by": sorted(takes[nm])})
    for sid in SOUNDS:
        man["outputs"][sid] = {"files": ["%s_%02d.wav" % (sid, v + 1) for v in range(SOUNDS[sid][0])],
                               "takes": sorted(used.get(sid, []))}
    with open(os.path.join(out, "MANIFEST.json"), "w") as fh:
        json.dump(man, fh, indent=1)
        fh.write("\n")


def all_takes() -> list:
    """Every take a recipe may read (so a fresh cache is decoded in one Blender run)."""
    names = {"chop-tree-fall", "bfh1_falling_06"}
    for group in (RING, KNOCK, GRIT, CRACK, RUBBLE, BODY, BITE, TICK, BUCK_BITE, BUCK_BODY, SNAP, GROAN, BRUSH,
                  BRANCH, LAND_BODY):
        names.update(group)
    names.update(n for n, _t in CHUNK)
    names.update(n for n, _t in TEAR)
    return sorted(names)


def render(sid: str, seed: int) -> list:
    n, fn = SOUNDS[sid][0], SOUNDS[sid][1]
    S.current = sid
    return [fn(seed + SEED_OFS[sid] + 7 * v, v) for v in range(n)]


def main() -> None:
    global S
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, default=1758)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--src", default=SRC, help="folder of the unpacked CC0 packs")
    ap.add_argument("--cache", default=CACHE, help="decode cache (float .npy per take)")
    ap.add_argument("--blender", default=BLENDER)
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--png", default=None, help="write one spectrogram sheet per id here")
    a = ap.parse_args()
    S = Sources(os.path.expanduser(a.src), os.path.expanduser(a.cache), a.blender)
    if not os.path.isdir(S.src) and not glob.glob(os.path.join(S.cache, "*", "*.npy")):
        print("gathering: CC0 packs not found at %s (and no decode cache): keeping the baked WAVs" % S.src)
        return
    S.prefetch(all_takes())
    ids = a.only or list(SOUNDS)
    os.makedirs(a.out, exist_ok=True)
    man_path = os.path.join(a.out, "gathering_rec_manifest.json")
    try:
        with open(man_path) as fh:
            manifest = json.load(fh)
    except (OSError, ValueError):
        manifest = {}
    manifest.setdefault("sounds", {})
    report = {}
    for sid in ids:
        xs = render(sid, a.seed)
        # loudness match: every variant to the same short-term loudness, the loudest possible with all peaks
        # at or under -1 dBFS
        L = [st_loudness(x) for x in xs]
        pk = [dsp.lin2db(float(np.max(np.abs(x)))) for x in xs]
        l_id = min(li - pi for li, pi in zip(L, pk)) - 1.0
        for old in glob.glob(os.path.join(a.out, sid + "_[0-9][0-9].wav")):
            os.remove(old)
        rows = []
        for v, x in enumerate(xs):
            y = x * dsp.db2lin(l_id - L[v])
            path = os.path.join(a.out, "%s_%02d.wav" % (sid, v + 1))
            dsp.write_wav(path, y, seed=a.seed + v)
            y, _ = dsp.read_wav(path)
            rows.append(band_metrics(y))
            if a.png:
                os.makedirs(a.png, exist_ok=True)
        n, _fn, target, unit, dist, maxd, rp, rv = SOUNDS[sid]
        vol = target - l_id - min(dist_gain(unit, dist), 3.0)
        manifest["sounds"][sid] = {
            "variants": n, "st_loudness_db": round(l_id, 2), "target_db": target, "listener_m": dist,
            "volume_db": round(vol, 1) + 0.0, "unit_size": unit, "max_distance": maxd, "random_pitch": rp,
            "random_volume_db": rv, "bus": "World"}
        report[sid] = rows
        print("%-24s %d variants  st-loudness %.1f dB  -> volume_db %+.1f" % (sid, n, l_id, vol))
        for v, m in enumerate(rows):
            print("   %02d %5d ms pk %5.1f L %5.1f cent %5d atk %4.1f ms d20 %4d ms ring(2-8k,-30dB) %4d ms events %2d %s" % (
                v + 1, m["dur_ms"], m["peak_db"], m["st_lufs"], m["centroid_hz"], m["attack_ms"], m["decay20_ms"],
                m["ring_2_8k_t30_ms"], m["events_after_50ms"], {k: float(q) for k, q in m["bands_db"].items()}))
        if a.png:
            import analyze
            ims = []
            for v in range(n):
                y, _ = dsp.read_wav(os.path.join(a.out, "%s_%02d.wav" % (sid, v + 1)))
                m = rows[v]
                ims.append(analyze.spectrogram_image(
                    y, "%s_%02d  %d ms  L %.1f  cent %d Hz  atk %.1f ms  ring %d ms" % (
                        sid, v + 1, m["dur_ms"], m["st_lufs"], m["centroid_hz"], m["attack_ms"], m["ring_2_8k_t30_ms"]),
                    height=170, px_per_s=900.0 if SOUNDS[sid][0] and len(y) < SR else 330.0))
            analyze.stack_images(ims).save(os.path.join(a.png, "_sheet_%s.png" % sid))
    manifest["about"] = ("Written by tools/sfx/gathering_rec.py. volume_db = target_db - st_loudness_db - "
                         "min(20*log10(unit_size / listener_m), 3): the in-game loudness at the typical listener "
                         "distance, matched to the existing sounds (see the generator's SOUNDS table).")
    with open(man_path, "w") as fh:
        json.dump(manifest, fh, indent=1, sort_keys=True)
    if not a.only:
        write_source_md(a.out, S.used)
        with open(os.path.join(a.png or tempfile.gettempdir(), "gathering_report.json"), "w") as fh:
            json.dump(report, fh, indent=1)


if __name__ == "__main__":
    main()
