"""The owner's listen page for the ring's sounds (bend_sfx.py --review <dir>): <dir>/r1_sounds.html with every variant
in an <audio> player, a spectrogram of each sound's first variant, the old borrowed sounds the arena played before (for
the comparison), and a short mixed fight (r1_sounds/fight_montage.wav: a countdown, the gong, a fight of all four
elements, a catch sent back, a ring-out with the stands roaring, the bell). Files are copied under <dir>/r1_sounds/ so
the page stands alone.
"""
from __future__ import annotations

import html
import json
import os
import shutil

import numpy as np

import kit
from kit import dsp

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))

FAMILIES = [
    ("Earth", ["earth_cast_rumble", "earth_cast_crack", "earth_grind", "earth_hit", "earth_rise", "earth_crumble",
               "stone_catch"]),
    ("Water and ice", ["water_cast_rush", "water_slosh", "water_hit", "ice_freeze", "ice_cast", "ice_hit"]),
    ("Fire", ["fire_whoomph", "fire_roar", "fire_crackle", "fire_hit", "fire_sizzle"]),
    ("Air", ["air_whoosh", "air_gust", "air_swirl", "air_hit"]),
    ("Lightning, steam, mending", ["lightning_crack", "lightning_charge", "steam_hiss", "mend", "heal"]),
    ("Bodies and the pool", ["knock_thud", "ringout_splash"]),
    ("The ring's moments", ["count_tick", "round_gong", "round_bell", "match_gong"]),
    ("The crowd", ["crowd_murmur", "crowd_cheer", "crowd_ooh", "crowd_roar", "crowd_groan"]),
]

# Where each sound plays in the game (scripts/bending/bend_sounds.gd).
PLAYS = {
    "earth_cast_rumble": "Stomp, Anchor, Trap, Sink, Brace, the Catch guard",
    "earth_cast_crack": "Stone disc, Rock Jab pebbles, Shove push and split, Deflect",
    "earth_grind": "Earth Skate (skate, slide, burrow), Shove pull",
    "earth_hit": "every stone that lands (bolts, the knock-up's place)",
    "earth_rise": "Column, Shell, Ramp, Kick-up",
    "earth_crumble": "a wall shot down (API: BendSounds.event)",
    "stone_catch": "a stone caught and held (Catch)",
    "water_cast_rush": "Water Whip whip, Water Jet, Wave push and surf, Flow skate, Tide, Spray",
    "water_slosh": "Lash, Grab, Draw, Cleanse, Thaw, Bubble, Redirect, Absorb",
    "water_hit": "water landing; Geyser",
    "ice_freeze": "Freeze, Ice Patch, Freeze Water, Ice Wall",
    "ice_cast": "Ice shards, Ice spear",
    "ice_hit": "ice landing",
    "fire_whoomph": "Fire Blast punch and stream, Fire Jab, Fire Jets, Footwork, the fire disc, Parry, Flare",
    "fire_roar": "Fireball, Fire Arc sweep, Breath, Fire Wall, the ring of fire, Hover, Smoke",
    "fire_crackle": "Inferno, ignite-step",
    "fire_hit": "fire landing",
    "fire_sizzle": "Heat (ice melting)",
    "air_whoosh": "Air Blast ball and slice, Air Palm, Evade steps, Air Jump, Gust-step, Updraft",
    "air_gust": "Cyclone, Cushion, Vacuum, Dust, Wind Run, Glide",
    "air_swirl": "Air Shield, Tornado, Spin, Whirl ride, Redirect",
    "air_hit": "air landing",
    "lightning_crack": "Lightning",
    "lightning_charge": "Redirect lightning (held)",
    "steam_hiss": "water meeting fire in the air",
    "mend": "Patch (earth); Mend (API: BendSounds.event)",
    "heal": "Water Shield heal",
    "knock_thud": "a fighter thrown back (API: BendSounds.event)",
    "ringout_splash": "anything falling into the pool round the deck",
    "count_tick": "the countdown (API: BendSounds.event)",
    "round_gong": "the round begins (API: BendSounds.event)",
    "round_bell": "the round ends (API: BendSounds.event)",
    "match_gong": "the match is decided (API: BendSounds.event)",
    "crowd_murmur": "always, under everything; louder with the stands' mood",
    "crowd_cheer": "a knock-back into the next zone",
    "crowd_ooh": "a knock-back (sometimes, instead of the cheer)",
    "crowd_roar": "a ring-out (one stand)",
    "crowd_groan": "a ring-out (the other stand)",
}

# The old borrowed sounds the arena played before this round (BendLooks.SOUNDS): [label, file, pitch].
BEFORE = [
    ("stone cast (rock split)", "gathering_rec/gather_rec_rock_split_01.wav", 1.0),
    ("stone hit (pick on rock)", "gathering_rec/gather_rec_pick_rock_hard_01.wav", 0.9),
    ("water cast (an arrow)", "bow/arrow_whoosh_01.wav", 0.8),
    ("water hit (landing on dirt)", "footsteps/land_dirt_01.wav", 1.3),
    ("fire cast (torch lit)", "fire/torch_ignite_01.wav", 1.0),
    ("fire hit (torch thrown)", "fire/torch_toss_01.wav", 0.8),
    ("air cast (an arrow, low)", "bow/arrow_whoosh_01.wav", 0.6),
    ("steam (torch snuffed)", "fire/torch_snuff_01.wav", 1.0),
]


def _find(rel: str) -> str:
    """An old sound's file: audio/sfx/<rel>, or the same name anywhere under audio/sfx."""
    p = os.path.join(ROOT, "audio", "sfx", rel)
    if os.path.exists(p):
        return p
    base = os.path.basename(rel)
    for d, _s, fs in os.walk(os.path.join(ROOT, "audio", "sfx")):
        if base in fs:
            return os.path.join(d, base)
    return ""


def _pitch(x: np.ndarray, p: float) -> np.ndarray:
    if abs(p - 1.0) < 1e-6:
        return x
    n = int(len(x) / p)
    src = np.arange(n) * p
    if x.ndim == 1:
        return np.interp(src, np.arange(len(x)), x)
    return np.stack([np.interp(src, np.arange(len(x)), x[:, c]) for c in range(x.shape[1])], axis=1)


def _load(src: str, sid: str, v: int = 1) -> np.ndarray:
    x, _sr = dsp.read_wav(os.path.join(src, "%s_%02d.wav" % (sid, v)))
    return x


# The fight: (time s, id, variant, pan -1..1, distance m)
FIGHT = [
    (0.0, "crowd_murmur", 1, 0.0, 0.0),
    (0.4, "count_tick", 1, 0.0, 0.0), (1.2, "count_tick", 2, 0.0, 0.0), (2.0, "count_tick", 3, 0.0, 0.0),
    (2.8, "round_gong", 1, 0.0, 0.0),
    (4.2, "fire_whoomph", 1, 0.45, 14.0), (4.55, "fire_hit", 1, -0.2, 2.0),
    (5.3, "earth_cast_crack", 1, -0.25, 1.5), (5.75, "earth_hit", 1, 0.45, 14.0), (5.85, "crowd_ooh", 1, 0.0, 0.0),
    (6.8, "water_cast_rush", 2, 0.4, 13.0), (7.05, "fire_whoomph", 2, -0.2, 1.5), (7.25, "steam_hiss", 1, 0.1, 7.0),
    (8.4, "earth_cast_crack", 2, 0.45, 14.0), (8.85, "stone_catch", 1, -0.2, 1.5),
    (9.6, "earth_cast_crack", 3, -0.2, 1.5), (10.05, "earth_hit", 2, 0.45, 14.0), (10.1, "knock_thud", 1, 0.45, 15.0),
    (10.3, "crowd_cheer", 1, 0.0, 0.0),
    (11.6, "air_gust", 1, 0.4, 13.0), (12.0, "air_hit", 1, -0.2, 2.0),
    (12.8, "ice_cast", 1, 0.4, 13.0), (13.1, "ice_hit", 2, -0.1, 3.0),
    (13.9, "earth_rise", 1, -0.25, 3.0), (14.6, "fire_roar", 1, 0.45, 14.0), (15.2, "fire_hit", 3, -0.2, 3.5),
    (16.0, "lightning_crack", 1, 0.4, 13.0),
    (17.3, "air_swirl", 1, 0.4, 13.0),
    (18.4, "earth_cast_rumble", 1, -0.2, 1.5), (18.9, "earth_hit", 3, 0.5, 15.0), (18.95, "knock_thud", 2, 0.5, 16.0),
    (19.6, "ringout_splash", 1, 0.7, 20.0), (19.75, "crowd_roar", 1, 0.5, 0.0), (19.9, "crowd_groan", 1, -0.6, 0.0),
    (22.6, "round_bell", 1, 0.0, 0.0),
]


def montage(src: str, path: str) -> dict:
    dur = 26.0
    n = kit.N(dur)
    dry = np.zeros((n, 2))
    r = dsp.rng(1750)
    murmur = _load(src, "crowd_murmur")
    bed = np.tile(murmur, int(n / len(murmur)) + 1)[:n]
    for t, sid, v, p, d in FIGHT:
        if sid == "crowd_murmur":
            continue
        x = _load(src, sid, v)
        g = 1.0
        if d > 3.0:                                         # far: quieter (inverse distance from 3 m) and duller
            g = 3.0 / d
            x = kit.band(x, None, 9000.0 * (3.0 / d) ** 0.5, 1)
        if sid.startswith("crowd_"):
            g = 0.7
        elif sid in ("round_gong", "round_bell"):               # (in the game: SFX at -2 and -3 dB, a little under)
            g = 0.6
        dsp.place(dry, kit.pan(x, p), t, g)
    dry += np.stack([bed, np.roll(bed, kit.N(3.7))], axis=1) * 0.35
    wet = np.stack([kit.room(dry[:, c], r, 1.1, 1.0, 0.03, 3500.0)[:n] - dry[:, c] for c in range(2)], axis=1)
    y = dry + 0.12 * wet
    y = y * dsp.db2lin(-17.0 - kit.loudness_db(y.mean(axis=1), 0.4))
    y, cut = kit.limit(y, -1.0)
    dsp.write_wav(path, y, seed=1750)
    return {"dur_s": dur, "limit_db": round(cut, 2)}


CSS = """
:root { --bg: #f6f4ef; --card: #ffffff; --ink: #1d1c1a; --muted: #6b6760; --line: #e3dfd6; --accent: #b4572b; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #16171a; --card: #1f2125; --ink: #ecebe7; --muted: #a29e96; --line: #2f3238; --accent: #e08a5a; } }
:root[data-theme="dark"] { --bg: #16171a; --card: #1f2125; --ink: #ecebe7; --muted: #a29e96; --line: #2f3238;
  --accent: #e08a5a; }
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--ink); font: 15px/1.5 system-ui, -apple-system, sans-serif; }
main { max-width: 1100px; margin: 0 auto; padding: 24px 16px 64px; }
h1 { font-size: 26px; margin: 0 0 4px; } h2 { font-size: 19px; margin: 32px 0 10px; color: var(--accent); }
p.lead { color: var(--muted); margin: 0 0 18px; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 12px; }
.card { background: var(--card); border: 1px solid var(--line); border-radius: 10px; padding: 12px; }
.card h3 { font-size: 15px; margin: 0; font-family: ui-monospace, Menlo, monospace; }
.card .what { margin: 2px 0; } .card .plays { color: var(--muted); font-size: 13px; margin: 0 0 8px; }
.card img { width: 100%; border-radius: 6px; display: block; margin: 6px 0; }
audio { width: 100%; height: 32px; margin: 2px 0; }
.lv { color: var(--muted); font-size: 12px; font-family: ui-monospace, Menlo, monospace; }
.hero { background: var(--card); border: 1px solid var(--line); border-radius: 10px; padding: 14px; }
"""


def write(review_dir: str, src: str, sounds: dict) -> None:
    out = os.path.join(review_dir, "r1_sounds")
    os.makedirs(out, exist_ok=True)
    levels = json.load(open(os.path.join(src, "levels.json")))
    for f in os.listdir(src):
        if f.endswith(".wav"):
            shutil.copy2(os.path.join(src, f), os.path.join(out, f))
    for sid in sounds:
        x = _load(src, sid)
        if sid in ("crowd_murmur",):
            x = x[:kit.N(4.0)]
        dsp.spectrogram_png(x, os.path.join(out, sid + ".png"), n_fft=1024, fmax=12000.0, width=640, height=180,
                            db_range=80.0, title=sid)
    before = []
    for label, rel, p in BEFORE:
        path = _find(rel)
        if path:
            x, _sr = dsp.read_wav(path)
            name = "before_" + os.path.basename(rel).replace(".wav", "_p%g.wav" % p)
            dsp.write_wav(os.path.join(out, name), _pitch(x, p), dither=False)
            before.append((label, name))
    m = montage(src, os.path.join(out, "fight_montage.wav"))
    e = html.escape
    parts = ["<!doctype html><html lang='en'><head><meta charset='utf-8'>",
             "<meta name='viewport' content='width=device-width, initial-scale=1'><title>Tidebreak Sounds</title>",
             "<style>%s</style></head><body><main>" % CSS,
             "<h1>Tidebreak sounds, round 1</h1>",
             "<p class='lead'>Every sound the ring now plays, made in code (tools/sfx/bend/: numpy synthesis, nothing "
             "recorded or downloaded). Each plays with a little random pitch and level, never the same variant twice "
             "in a row. Spectrograms are of the first variant (0-12 kHz).</p>",
             "<div class='hero'><h3>A fight, mixed (%.0f s)</h3><p class='plays'>countdown, gong, fire against earth, "
             "steam, a stone caught and sent back, a knock-back, air, ice, a wall, lightning, a ring-out with the "
             "stands roaring and groaning, the bell; the stands murmuring under it all</p>"
             "<audio controls preload='none' src='r1_sounds/fight_montage.wav'></audio></div>" % m["dur_s"]]
    for fam, ids in FAMILIES:
        parts.append("<h2>%s</h2><div class='grid'>" % e(fam))
        for sid in ids:
            if sid not in sounds:
                continue
            _mk, nv, target, what = sounds[sid]
            parts.append("<div class='card'><h3>%s</h3><p class='what'>%s</p><p class='plays'>Plays on: %s</p>" % (
                e(sid), e(what), e(PLAYS.get(sid, ""))))
            parts.append("<img src='r1_sounds/%s.png' alt='spectrogram of %s' loading='lazy'>" % (sid, e(sid)))
            for v in range(1, nv + 1):
                f = "%s_%02d.wav" % (sid, v)
                lv = levels.get(f, {})
                parts.append("<audio controls preload='none' src='r1_sounds/%s'></audio><div class='lv'>%s · %.2f s · "
                             "loudness %.1f dB · peak %.1f dBFS</div>" % (f, f, lv.get("dur_s", 0), lv.get("loud_db", 0),
                                                                          lv.get("peak_dbfs", 0)))
            parts.append("</div>")
        parts.append("</div>")
    if before:
        parts.append("<h2>Before: what the arena borrowed until now</h2><div class='grid'>")
        for label, name in before:
            parts.append("<div class='card'><h3>%s</h3><audio controls preload='none' src='r1_sounds/%s'></audio>"
                         "</div>" % (e(label), name))
        parts.append("</div>")
    parts.append("</main></body></html>")
    with open(os.path.join(review_dir, "r1_sounds.html"), "w") as f:
        f.write("\n".join(parts))
    print("review: %s (montage limit %.1f dB)" % (os.path.join(review_dir, "r1_sounds.html"), m["limit_db"]))


# ================================================================================================ round 4 (READ)
# The shots' flight voices (flight.py; scripts/bending/bend_sounds.gd FLIGHTS and their TABLE rows): the listen page
# r4_read_listen.html. Each id alone (its loop, three times round), a 4 s pass-by rendered offline the way the game plays
# it (Godot's inverse-distance level from `unit` m capped at max_db, silent past maxd, its doppler pitch: c / (c + v . r),
# the far top end dulled), and an incoming shot from 15 m (the element's cast there, the voice closing in, its hit at
# you), next to the element's own cast and hit.
# id -> (the bolt kind's speed m/s, the element's cast id, its hit id, what flies). Speeds from data/sway/moves.json.
FLIGHT_SHOTS = {
    "stone_whirr": (34.0, "earth_cast_crack", "earth_hit", "a Spike, a stone disc, pebbles, a caught stone sent back"),
    "ice_whistle": (42.0, "ice_cast", "ice_hit", "the ice spear, ice shards"),
    "water_rush": (34.0, "water_cast_rush", "water_hit", "the whip, the jet, a splash"),
    "fire_flight": (32.0, "fire_whoomph", "fire_hit", "the punch, the stream, the fireball, embers, the high kick"),
    "air_flight": (45.0, "air_whoosh", "air_hit", "the slice, the wind ball, Gust and Pull"),
    "floor_run": (18.0, "fire_roar", "fire_hit", "the Kick's floor wave along the deck"),
}
# The game's numbers for these (bend_sounds.gd: the flight rows of TABLE, vol dB, unit m, maxd m, and FLIGHT_MAX_DB). Kept
# in step by hand: the page is a review, the game reads its own table.
FLIGHT_LEVEL = {"vol": 0.0, "unit": 4.0, "maxd": 60.0, "max_db": 6.0}
SPEED_OF_SOUND = 343.0


def _loop_read(x: np.ndarray, pitch: np.ndarray, start: float = 0.0) -> np.ndarray:
    """The loop x read round and round at a pitch per output sample (linear interpolation)."""
    pos = (start + np.cumsum(pitch)) % len(x)
    i = np.floor(pos).astype(int)
    fr = pos - i
    return x[i] * (1.0 - fr) + x[(i + 1) % len(x)] * fr


def _att_db(d: np.ndarray, lv: dict) -> np.ndarray:
    a = 20.0 * np.log10(1.0 / (np.maximum(d, 1e-3) / lv["unit"] + 1e-6)) + lv["vol"]
    a = np.minimum(a, lv["max_db"])
    return np.where(d > lv["maxd"], -80.0, a)


def pass_by(x: np.ndarray, v: float, dur: float = 4.0, miss_m: float = 1.2, lv: dict | None = None) -> np.ndarray:
    """A shot flying straight past the listener `miss_m` to his right at `v` m/s, closest at dur/2: stereo, the game's
    level curve and doppler."""
    lv = lv or FLIGHT_LEVEL
    n = kit.N(dur)
    t = kit.T(n)
    z = v * (dur * 0.5 - t)                                  # ahead of him (+z), coming in, then behind
    px = np.full(n, miss_m)
    d = np.sqrt(px * px + z * z)
    approaching = -z / d                                     # its direction from him . its velocity's (-z)
    pitch = SPEED_OF_SOUND / (SPEED_OF_SOUND + v * approaching)
    y = _loop_read(x, np.clip(pitch, 1.0 / 8.0, 8.0))
    att = _att_db(d, lv)
    dull = kit.band(y, None, 6500.0, 1)
    w = np.clip(-att / 30.0, 0.0, 1.0)                       # far: toward the dulled copy (the game's distance filter)
    y = (y * (1.0 - w) + dull * w) * 10.0 ** (att / 20.0)
    p = np.clip(px / d, -1.0, 1.0) * 0.8
    a = (p + 1.0) * np.pi / 4.0
    return np.stack([y * np.cos(a), y * np.sin(a)], axis=1)


def incoming(src: str, sid: str, from_m: float = 15.0) -> np.ndarray:
    """A shot from `from_m` straight at the listener: the element's cast there, the voice closing in, its hit at him."""
    v, cast, hit, _what = FLIGHT_SHOTS[sid]
    x = _load(src, sid)
    tf = from_m / v
    pre, post = 0.35, 0.9
    n = kit.N(pre + tf + post)
    out = np.zeros(n)
    dsp.place(out, _load(src, cast), 0.0, 10.0 ** (min(20.0 * np.log10(6.0 / from_m), 3.0) / 20.0))
    m = kit.N(tf)
    t = kit.T(m)
    d = np.maximum(from_m - v * t, 0.4)
    pitch = np.full(m, SPEED_OF_SOUND / (SPEED_OF_SOUND - v))
    y = _loop_read(x, pitch) * 10.0 ** (_att_db(d, FLIGHT_LEVEL) / 20.0)
    y *= np.clip(t / 0.04, 0.0, 1.0)                         # the game's 0.04 s fade in
    tail = min(kit.N(0.08), m)
    y[-tail:] *= np.linspace(1.0, 0.0, tail)                 # and its 0.08 s fade out on the hit
    dsp.place(out, y, pre, 1.0)
    dsp.place(out, _load(src, hit), pre + tf, 10.0 ** (3.0 / 20.0))
    return out


def write_flight(review_dir: str, src: str, sounds: dict) -> None:
    """The flight voices' listen page: <review_dir>/r4_read_listen.html, its files under r4_read_listen/."""
    out = os.path.join(review_dir, "r4_read_listen")
    os.makedirs(out, exist_ok=True)
    levels = json.load(open(os.path.join(src, "levels.json")))
    e = html.escape
    cards = []
    for sid, (v, cast, hit, what) in FLIGHT_SHOTS.items():
        if sid not in sounds:
            continue
        nv = sounds[sid][1]
        files = []
        for k in range(1, nv + 1):
            f = "%s_%02d.wav" % (sid, k)
            dsp.write_wav(os.path.join(out, f), np.tile(_load(src, sid, k), 3), dither=False)
            files.append(f)
        x = _load(src, sid)
        dsp.spectrogram_png(np.tile(x, 2), os.path.join(out, sid + ".png"), n_fft=1024, fmax=12000.0, width=640,
                            height=170, db_range=80.0, title=sid + " (two turns of the loop)")
        pb, _cut = kit.limit(pass_by(x, v) * dsp.db2lin(-12.0), -1.0)
        dsp.write_wav(os.path.join(out, sid + "_passby.wav"), pb, dither=False)
        dsp.spectrogram_png(pb, os.path.join(out, sid + "_passby.png"), n_fft=1024, fmax=12000.0, width=640,
                            height=170, db_range=80.0, title=sid + " pass-by at %.0f m/s, 1.2 m off" % v)
        inc, _cut = kit.limit(incoming(src, sid) * dsp.db2lin(-12.0), -1.0)
        dsp.write_wav(os.path.join(out, sid + "_incoming.wav"), inc, dither=False)
        for other in (cast, hit):
            shutil.copy2(os.path.join(src, other + "_01.wav"), os.path.join(out, other + "_01.wav"))
        lv = levels.get(sid + "_01.wav", {})
        rows = ["<div class='card'><h3>%s</h3><p class='what'>%s</p><p class='plays'>Flies on: %s · %.0f m/s</p>" % (
            e(sid), e(sounds[sid][3]), e(what), v)]
        rows.append("<img src='r4_read_listen/%s.png' alt='spectrogram of %s' loading='lazy'>" % (sid, e(sid)))
        rows.append("<p class='plays'>Alone (each variant, its loop three times round)</p>")
        for f in files:
            rows.append("<audio controls preload='none' src='r4_read_listen/%s'></audio>" % f)
        rows.append("<div class='lv'>loop %.2f s · loudness %.1f dB · peak %.1f dBFS</div>" % (
            lv.get("dur_s", 0), lv.get("loud_db", 0), lv.get("peak_dbfs", 0)))
        rows.append("<p class='plays'>A pass-by (4 s, 1.2 m to your right; the game's level curve and doppler; "
                    "headphones)</p><audio controls preload='none' src='r4_read_listen/%s_passby.wav'></audio>" % sid)
        rows.append("<img src='r4_read_listen/%s_passby.png' alt='pass-by spectrogram' loading='lazy'>" % sid)
        rows.append("<p class='plays'>Incoming from 15 m: the cast there, the voice closing in, the hit at you</p>"
                    "<audio controls preload='none' src='r4_read_listen/%s_incoming.wav'></audio>" % sid)
        rows.append("<p class='plays'>Its element's cast (%s) and hit (%s), as round 1 made them</p>"
                    "<audio controls preload='none' src='r4_read_listen/%s_01.wav'></audio>"
                    "<audio controls preload='none' src='r4_read_listen/%s_01.wav'></audio></div>" % (
                        e(cast), e(hit), cast, hit))
        cards.append("\n".join(rows))
    parts = ["<!doctype html><html lang='en'><head><meta charset='utf-8'>",
             "<meta name='viewport' content='width=device-width, initial-scale=1'><title>Shots In Flight</title>",
             "<style>%s</style></head><body><main>" % CSS,
             "<h1>Shots in flight</h1>",
             "<p class='lead'>Round 4: every shot now carries its own voice through the air, louder as it nears, its "
             "pitch falling as it passes (doppler), so an attack coming at you is heard before it lands. Lightning stays "
             "instant. Your own shots play 6 dB under the ones coming at you. All made in code (tools/sfx/bend/flight.py);"
             " the pass-bys and the incoming shots are rendered offline with the game's level curve (inverse distance "
             "from %.0f m, capped at +%.0f dB, silent past %.0f m).</p>" % (
                 FLIGHT_LEVEL["unit"], FLIGHT_LEVEL["max_db"], FLIGHT_LEVEL["maxd"]),
             "<div class='grid'>"] + cards + ["</div></main></body></html>"]
    with open(os.path.join(review_dir, "r4_read_listen.html"), "w") as f:
        f.write("\n".join(parts))
    print("review: %s" % os.path.join(review_dir, "r4_read_listen.html"))
