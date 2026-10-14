"""The menus' sounds for Tidebreak (tools/sfx/bend/bend_sfx.py writes them; scripts/ui/ui_sounds.gd plays them): the sound
audit of 2026-10-13 found every menu silent (the lobby, the ring's Esc menu, settings, the round and match screens, the
hotbar's keys and forms). In the ring score's band (scripts/audio: a temple block and a small bronze bowl, D minor
pentatonic): synthesized here with numpy (kit.py on tools/sfx/dsp.py); nothing recorded or downloaded.

  ui_hover   a soft, short high wood tick: a button lit under the mouse or the keys
  ui_click   a temple block's knock with a small bowl's ring a fifth above: a button pressed
  ui_back    the block lower, two knocks falling: back, close, cancel
"""
from __future__ import annotations

import numpy as np

from kit import N, T, dsp, mix, thump

## D minor pentatonic's notes (Hz, A = 432 as the score): the block on A, the bowl on E a fifth above, the back on D.
A5, E6, D5, A4 = 864.0, 1294.0, 576.0, 432.0


def _block(r, f: float, dur: float = 0.12, bright: float = 1.0) -> np.ndarray:
    """A temple block: a hollow wooden knock, its body a few close modes, a quick knock of the stick in front."""
    f = f * r.uniform(0.985, 1.015)
    body = dsp.strike([f, f * 1.5, f * 2.74], [dur * 0.55, dur * 0.3, dur * 0.12], [1.0, 0.28 * bright, 0.12 * bright], dur,
                      contact=0.0007, r=r, noise=0.18)
    knock = thump(f * 0.42, f * 0.3, 0.012, 0.04)
    n = N(dur)
    return mix(n, (body, 0.0, 1.0), (knock, 0.0, 0.25))


def _bowl(r, f: float, dur: float = 0.55) -> np.ndarray:
    """A small bronze bowl tapped: a clear ring with its beating partner, dying away."""
    f = f * r.uniform(0.995, 1.005)
    ring = dsp.strike([f, f * 1.003, f * 2.71, f * 5.1], [dur * 0.6, dur * 0.55, dur * 0.2, dur * 0.07],
                      [1.0, 0.6, 0.22, 0.06], dur, contact=0.0004, r=r, noise=0.05)
    n = N(dur)
    e = np.minimum(T(n) / 0.004, 1.0)
    return ring[:n] * e if len(ring) >= n else ring


def ui_hover(r) -> np.ndarray:
    n = N(0.07)
    return mix(n, (_block(r, A5 * 2.0, 0.06, bright=0.6), 0.0, 1.0))


def ui_click(r) -> np.ndarray:
    n = N(0.6)
    return mix(n, (_block(r, A5, 0.12), 0.0, 1.0), (_bowl(r, E6, 0.55), 0.012, 0.32))


def ui_back(r) -> np.ndarray:
    n = N(0.3)
    return mix(n, (_block(r, D5, 0.12), 0.0, 1.0), (_block(r, A4, 0.14), 0.085, 0.8))
