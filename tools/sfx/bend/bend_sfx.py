#!/usr/bin/env python3
"""Tidebreak's ring sounds (improvement round 1, 2026-10-05): every element's casts and hits, the ring's moments and the
crowd, synthesized here with numpy (kit.py, elements.py, crowd.py on tools/sfx/dsp.py). Nothing is recorded or
downloaded; the old game's borrowed sounds (a musket shot for lightning, an arrow for wind) are gone from the arena.

Usage (project root):
  python3 tools/sfx/bend/bend_sfx.py                          every sound (the shipped set: seed 0)
  python3 tools/sfx/bend/bend_sfx.py earth_hit fire_roar      only these ids
  python3 tools/sfx/bend/bend_sfx.py --seed 3 --out /tmp/x    another take, somewhere else
  python3 tools/sfx/bend/bend_sfx.py --review <dir>           and the listen page, the spectrograms and the fight
                                                              montage there (review.py)
  python3 tools/sfx/bend/bend_sfx.py --flight-review <dir>    only the flight voices' listen page (round 4, READ:
                                                              r4_read_listen.html; review.write_flight)
Afterwards a Godot import pass (`--import`) so new WAVs load (new files: run this once more after it, which sets their
imports to PCM, and import again). scripts/bending/bend_sounds.gd plays them (its TABLE: each id's level, 3D range,
pitch and level jitter, voice cap).

Output: audio/sfx/bend/<id>_<NN>.wav, 44.1 kHz 16-bit mono (the crowd's murmur a 12 s loop and the shots' flight voices
(flight.py, round 4) 1.85-2.45 s loops, each with a RIFF smpl chunk), and
audio/sfx/bend/levels.json (each file's loudness, peak, limiting and length). Deterministic: a variant's dice come from
its id, its number and --seed alone.

Levels: each variant is set to its family's loudness (SOUNDS' target: the loudest 100 ms of the K-weighted signal, dB; the murmur
the loudest 400 ms), then held under -1 dBFS by a look-ahead limiter that may cut at most 4 dB (past that the variant is
left quieter and levels.json says by how much). So variants of a family match by ear and nothing clips; the mix between
families is bend_sounds.gd's.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import zlib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import crowd  # noqa: E402
import elements as el  # noqa: E402
import flight as fl  # noqa: E402
import guards as gd  # noqa: E402
import kit  # noqa: E402
import ui  # noqa: E402
from kit import dsp  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "audio", "sfx", "bend")
CEILING_DB = -1.0
MAX_CUT_DB = 4.0

# id -> (maker, variants, target loudness dB, what it is)
SOUNDS = {
    "earth_cast_rumble": (el.earth_cast_rumble, 4, -17.0, "earth's heavy casts: a deep rumble with a crack in front"),
    "earth_cast_crack": (el.earth_cast_crack, 4, -15.0, "earth's throws: a stone split off and flung"),
    "earth_grind": (el.earth_grind, 4, -18.0, "stone dragged over stone: the skate, the slide, the pull"),
    "earth_hit": (el.earth_hit, 4, -14.0, "a stone landing: thump, crack, grit"),
    "earth_rise": (el.earth_rise, 4, -16.0, "a wall or pillar grinding up out of the deck and settling"),
    "earth_crumble": (el.earth_crumble, 4, -15.0, "a wall breaking up: crack, chunks, grit, dust"),
    "stone_catch": (el.stone_catch, 4, -13.0, "a stone stopped dead in the hands: a dull thunk, a short scrape"),
    "water_cast_rush": (el.water_cast_rush, 4, -17.0, "water rushing out: the whip, the jet, the wave"),
    "water_slosh": (el.water_slosh, 4, -18.0, "water sloshing and gurgling: the lash, the grab, the draw"),
    "water_hit": (el.water_hit, 4, -15.0, "a splash: slap, spray, bubbles, drops"),
    "ice_freeze": (el.ice_freeze, 4, -18.0, "water freezing: a quickening crackle, a glassy creak"),
    "ice_cast": (el.ice_cast, 4, -16.0, "ice formed and thrown: a crack and a crystal swish"),
    "ice_hit": (el.ice_hit, 4, -14.0, "ice shattering"),
    "fire_whoomph": (el.fire_whoomph, 4, -15.0, "a burst of flame: the punch, the jab, the jets"),
    "fire_roar": (el.fire_roar, 4, -16.0, "a sustained roar: the fireball, the breath, the wall"),
    "fire_crackle": (el.fire_crackle, 4, -19.0, "burning: crackles and pops over a low flame"),
    "fire_hit": (el.fire_hit, 4, -14.0, "a fiery burst where it strikes"),
    "fire_sizzle": (el.fire_sizzle, 4, -19.0, "a sizzle: heat on ice, a flame put out"),
    "air_whoosh": (el.air_whoosh, 4, -16.0, "a whoosh: the blast, the palm, the quick steps"),
    "air_gust": (el.air_gust, 4, -17.0, "a gust: the push, the cushion, the wind run"),
    "air_swirl": (el.air_swirl, 4, -18.0, "wind circling: the shield, the tornado, the spin"),
    "air_hit": (el.air_hit, 4, -15.0, "a punch of air landing"),
    "lightning_crack": (el.lightning_crack, 4, -14.0, "a hum swelling into the crack, a buzz, a short thunder roll"),
    "lightning_charge": (el.lightning_charge, 3, -19.0, "a rising hum with sparks: lightning held"),
    "steam_hiss": (el.steam_hiss, 4, -17.0, "water meets fire: a puff and a hiss"),
    "mend": (el.mend, 4, -18.0, "stones knocking into place and seated"),
    "heal": (el.heal, 3, -21.0, "a soft swell with a trickle: health back"),
    "knock_thud": (el.knock_thud, 4, -15.0, "a body thrown down on the deck"),
    "ringout_splash": (el.ringout_splash, 4, -13.0, "a body plunging into the pool"),
    "round_gong": (el.round_gong, 3, -15.0, "the round begins"),
    "match_gong": (el.match_gong, 3, -14.0, "the match is decided"),
    "round_bell": (el.round_bell, 3, -16.0, "the round's end: three rings"),
    "count_tick": (el.count_tick, 4, -19.0, "the countdown: a wood block"),
    "crowd_cheer": (crowd.cheer, 4, -19.0, "the stands cheer: a knock-back"),
    "crowd_roar": (crowd.roar, 3, -17.0, "the stands roar: a ring-out"),
    "crowd_groan": (crowd.groan, 3, -21.0, "the other half of the stands groans"),
    "crowd_ooh": (crowd.ooh, 3, -21.0, "a near thing: a gasp and an ooh"),
    "crowd_murmur": (crowd.murmur, 2, -25.0, "the stands talking (a 12 s loop)"),
    # round 2 (CORE): the guards on the beat and late, the lock's grow and sputter, Carried wind (guards.py)
    "guard_earth_clean": (gd.guard_earth_clean, 4, -12.0, "a clean catch: a sharp crack over the thunk, a stony ring"),
    "guard_water_clean": (gd.guard_water_clean, 4, -14.0, "a Turn on the beat: water swirled round and snapped away"),
    "guard_water_late": (gd.guard_water_late, 3, -17.0, "a Turn late: a heavy slosh"),
    "guard_fire_clean": (gd.guard_fire_clean, 4, -13.0, "a Parry on the beat: a crisp flame snap and a hot ring"),
    "guard_fire_late": (gd.guard_fire_late, 3, -17.0, "a Parry late: a smothered whoomph"),
    "guard_air_clean": (gd.guard_air_clean, 4, -14.0, "a Wind Guard on the beat: a taut whip of air, snapped back"),
    "guard_air_late": (gd.guard_air_late, 3, -18.0, "a Wind Guard late: a soft buffet"),
    "lock_grow": (gd.lock_grow, 3, -17.0, "grow's second click: a deeper, rounder knock"),
    "lock_sputter": (gd.lock_sputter, 3, -21.0, "a held lock fizzing out on the hands"),
    "carried_whistle": (gd.carried_whistle, 3, -20.0, "Carried wind: a rising whistle over a rush of air"),
    # round 4 (READ): each shot's voice in flight, a 1.85-2.45 s loop it carries (flight.py; BendSounds.flight)
    "stone_whirr": (fl.stone_whirr, 3, -18.0, "a stone in flight: a low tumbling whirr, its turns rough (a loop)"),
    "ice_whistle": (fl.ice_whistle, 3, -21.0, "ice in flight: a thin glassy whistle with a shimmer (a loop)"),
    "water_rush": (fl.water_rush, 3, -19.0, "water in flight: a rushing hiss with a slosh (a loop)"),
    "fire_flight": (fl.fire_flight, 3, -18.0, "fire in flight: a roaring hiss with crackle (a loop)"),
    "air_flight": (fl.air_flight, 3, -19.0, "air in flight: a whoosh with a pressure flutter (a loop)"),
    "floor_run": (fl.floor_run, 3, -19.0, "the Kick's floor wave crackling along the deck (a loop)"),
    # 2026-10-13 (the sound audit: every menu silent): the menus' own, a temple block and a small bowl (ui.py; UiSounds)
    "ui_hover": (ui.ui_hover, 3, -27.0, "a button lit: a soft high wood tick"),
    "ui_click": (ui.ui_click, 3, -21.0, "a button pressed: a temple block's knock and a small bowl's ring"),
    "ui_back": (ui.ui_back, 3, -22.0, "back, close, cancel: the block lower, two knocks falling"),
}
# id -> the cross-fade (s) that closes the loop
LOOPS = {"crowd_murmur": 1.5, "stone_whirr": fl.LOOP_XFADE, "ice_whistle": fl.LOOP_XFADE, "water_rush": fl.LOOP_XFADE,
         "fire_flight": fl.LOOP_XFADE, "air_flight": fl.LOOP_XFADE, "floor_run": fl.LOOP_XFADE}


def seed_of(sid: str, v: int, seed: int) -> int:
    return (zlib.crc32(sid.encode()) + 7919 * v + 104729 * seed) & 0xFFFFFFFF


def level(x: np.ndarray, target: float, win: float) -> tuple[np.ndarray, dict]:
    """x set to `target` loudness, then held under the ceiling (at most MAX_CUT_DB of limiting)."""
    ld = kit.loudness_db(x, win)
    x = x * dsp.db2lin(target - ld)
    pk = dsp.lin2db(float(np.max(np.abs(x))))
    short = 0.0
    if pk - CEILING_DB > MAX_CUT_DB:
        short = pk - CEILING_DB - MAX_CUT_DB
        x = x * dsp.db2lin(-short)
    x, cut = kit.limit(x, CEILING_DB)
    return x, {"loud_db": round(kit.loudness_db(x, win), 2), "peak_dbfs": round(dsp.lin2db(float(np.max(np.abs(x)))), 2),
                "limit_db": round(cut, 2), "short_db": round(short, 2), "dur_s": round(len(x) / dsp.SR, 3)}


def render(sid: str, v: int, seed: int) -> tuple[np.ndarray, dict]:
    maker, _n, target, _what = SOUNDS[sid]
    r = dsp.rng(seed_of(sid, v, seed))
    x = np.asarray(maker(r), dtype=float)
    if sid in LOOPS:
        x = dsp.dc_block(x, 25.0)
        x = dsp.loop_xfade(x, LOOPS[sid])
        return level(x, target, 0.4)
    x = dsp.finalize(x, peak_db=-6.0, fade=0.03, thresh_db=-62.0)
    return level(x, target, 0.1)


def pcm_imports(out: str) -> int:
    """Every WAV here imported as uncompressed PCM (compress/mode=0, as tools/sfx/gen_manifest.py does for the one-shots);
    the .import files exist only after Godot's first import of the WAVs, so import once more after this changes any."""
    changed = 0
    for f in sorted(os.listdir(out)):
        if not f.endswith(".wav.import"):
            continue
        p = os.path.join(out, f)
        text = open(p).read()
        new = re.sub(r"(?m)^compress/mode=\d+$", "compress/mode=0", text)
        if new != text:
            with open(p, "w") as fh:
                fh.write(new)
            changed += 1
    return changed


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("ids", nargs="*", help="only these ids (default: all)")
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--review", default="", help="also write the listen page, spectrograms and montage here")
    ap.add_argument("--flight-review", default="", help="only write the flight voices' listen page here (no render)")
    a = ap.parse_args()
    if a.flight_review:
        import review
        review.write_flight(a.flight_review, a.out, SOUNDS)
        return
    ids = a.ids or list(SOUNDS)
    for sid in ids:
        if sid not in SOUNDS:
            sys.exit("unknown id %s (ids: %s)" % (sid, ", ".join(SOUNDS)))
    os.makedirs(a.out, exist_ok=True)
    lv_path = os.path.join(a.out, "levels.json")
    levels = json.load(open(lv_path)) if os.path.exists(lv_path) else {}
    for sid in ids:
        t0 = time.time()
        for old in os.listdir(a.out):                       # a smaller variant count leaves no stale file behind
            if old.startswith(sid + "_") and old.endswith(".wav") and old[len(sid) + 1:-4].isdigit():
                os.remove(os.path.join(a.out, old))
        rows = []
        for v in range(SOUNDS[sid][1]):
            x, info = render(sid, v, a.seed)
            path = os.path.join(a.out, "%s_%02d.wav" % (sid, v + 1))
            if sid in LOOPS:
                dsp.write_wav_loop(path, x, seed=seed_of(sid, v, a.seed))
            else:
                dsp.write_wav(path, x, seed=seed_of(sid, v, a.seed))
            levels[os.path.basename(path)] = info
            rows.append(info)
        print("%-18s %d  loud %6.1f..%6.1f  peak <= %5.1f  limit %4.1f  short %3.1f  %.1fs  (%.1f s)" % (
            sid, len(rows), min(i["loud_db"] for i in rows), max(i["loud_db"] for i in rows),
            max(i["peak_dbfs"] for i in rows), min(i["limit_db"] for i in rows), max(i["short_db"] for i in rows),
            max(i["dur_s"] for i in rows), time.time() - t0), flush=True)
    with open(lv_path, "w") as f:
        json.dump(dict(sorted(levels.items())), f, indent=1)
        f.write("\n")
    n = pcm_imports(a.out)
    if n:
        print("%d imports set to PCM: run a Godot import pass again" % n)
    if a.review:
        import review
        review.write(a.review, a.out, SOUNDS)


if __name__ == "__main__":
    main()
