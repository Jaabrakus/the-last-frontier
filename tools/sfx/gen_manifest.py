#!/usr/bin/env python3
"""Writes scripts/audio/sfx_manifest.gd from the WAVs in audio/sfx/.

The game cannot list imported WAVs at runtime (DirAccess sees no .wav files in an export),
so the sound table is generated here:

  FILES      id -> ["res://audio/sfx/<family>/<id>_NN.wav", ...]
  FILE_GAIN  id -> per-variant gain in dB (footsteps: levels.json per-file trims)
  DEFAULTS   id -> playback defaults: bus, vol (dB), rp (random pitch factor),
             rv (random volume, +-dB/2), unit (unit_size), maxd (max_distance, 0 = none),
             maxdb (max_db), cut (distance filter cutoff Hz), fdb (distance filter depth dB),
             loop, travel (delay by sound travel time to the listener, so a distant hit is
             heard after it is seen), sref/smin (impact speed scaling: gain =
             clamp(speed/sref, smin, 1))

Levels come from the family manifests where they exist (flintlock_manifest.json,
impacts_manifest.json, footsteps/levels.json, gathering_rec/gathering_rec_manifest.json) and
from the family generator docstrings otherwise; the OVERRIDES table below records every deliberate change.

It also sets every one-shot's Godot import to uncompressed PCM (compress/mode=0); the 60 s
stereo wind loop stays QOA to keep it small. Godot reimports a WAV when its .import changes.
New WAVs get an .import only after a Godot import pass, so run this again after the first
`Godot --headless --import` and import once more.

Usage (project root):  python3 tools/sfx/gen_manifest.py [--no-import]
"""
from __future__ import annotations

import argparse
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
OUT = os.path.join(ROOT, "scripts", "audio", "sfx_manifest.gd")
FAMILIES = ["flintlock", "bow", "impacts", "targets", "footsteps", "ambience", "fire", "gathering_rec", "wildlife_rec", "birds_rec",
            "bend"]
## The ring's own sounds (audio/sfx/bend: BendSounds plays them all) that Sfx plays too: the ones moves.json form_sfx names
## for the stone casts of before the elements (Stone Form, the earth wall, the pillar, Mend, a stone's hurl and strike),
## so those play our own sounds in the ring (KITS, round 2). Only these: the rest (18 MB) stay BendSounds' alone, read
## behind the ring's loading screen. Their levels are BendSounds.TABLE's (bend_table).
BEND_IDS = {"earth_rise", "earth_cast_rumble", "earth_crumble", "earth_cast_crack", "earth_grind", "earth_hit",
            "air_whoosh", "mend"}
BEND_SOUNDS = os.path.join(ROOT, "scripts", "bending", "bend_sounds.gd")
NAME_RE = re.compile(r"^(?P<id>.+)_(?P<n>\d\d)\.wav$")
KEEP_COMPRESSED = {"forest_wind_loop"}

BASE = {"bus": "SFX", "vol": 0.0, "rp": 1.0, "rv": 0.0, "unit": 3.0, "maxd": 0.0, "maxdb": 3.0,
        "cut": 5000.0, "fdb": -24.0, "loop": False, "travel": False}

# Player-owned sounds (weapons, foley, footsteps) sit a few metres from the camera. The distance
# filter only fades in beyond 8 m (Sfx.NEAR_FILTER_M), so they stay crisp up close.
FAMILY_BASE = {
    "flintlock": {"bus": "Foley", "unit": 3.0, "maxd": 40.0},
    "bow": {"bus": "Foley", "unit": 3.0, "maxd": 40.0},
    "impacts": {"bus": "World", "unit": 8.0, "maxd": 150.0, "cut": 5000.0, "travel": True},
    "targets": {"bus": "World", "unit": 8.0, "maxd": 150.0, "cut": 5000.0, "travel": True},
    "footsteps": {"bus": "Foley", "unit": 3.0, "maxd": 20.0, "rp": 1.06},
    # Bird files already carry distance colouring (lowpass + forest reverb), so the runtime
    # filter is kept gentle.
    "ambience": {"bus": "Ambience", "unit": 15.0, "maxd": 160.0, "cut": 6000.0, "fdb": -10.0, "rp": 1.04},
    # the torch (fire.py, push n01b): near the player or lying close by
    "fire": {"bus": "Foley", "unit": 3.0, "maxd": 30.0},
    # mining, chopping, felling from CC0 recordings (gathering_rec.py, push n12s; levels per id in
    # gathering_rec_manifest.json): world sounds with the outdoor reverb, heard late from afar like the impacts
    "gathering_rec": {"bus": "World", "unit": 5.0, "maxd": 200.0, "cut": 5000.0, "travel": True},
    # wildlife calls from public-domain recordings (wildlife_rec.py): out in the woods, heard late and dulled from afar
    "wildlife_rec": {"bus": "Ambience", "unit": 12.0, "maxd": 300.0, "cut": 5000.0, "fdb": -16.0, "travel": True, "rp": 1.04},
    # birds from public-domain / CC0 recordings (birds_rec.py): AmbienceBed calls them by the hour, owls from Owls
    "birds_rec": {"bus": "Ambience", "unit": 10.0, "maxd": 140.0, "cut": 6000.0, "fdb": -12.0, "rp": 1.03},
}

OVERRIDES = {
    # --- flintlock. The shot reports are now the file peak, so their RMS fell 4-6 dB and the
    # tails' 5-7 dB (flintlock report, integration note 1): +3 dB on the shots, +4 on the tails.
    "musket_lock": {"bus": "Weapons", "maxd": 80.0},
    "pistol_lock": {"bus": "Weapons", "maxd": 60.0},
    "pan_flash": {"bus": "Weapons", "vol": -8.0, "maxd": 80.0},   # pistol: -2 dB, pitch 1.08 in code
    "dry_fire": {"bus": "Weapons", "maxd": 40.0},
    "musket_shot": {"vol": 3.0, "maxd": 500.0, "cut": 4000.0},
    "pistol_shot": {"vol": 1.0, "maxd": 350.0, "cut": 4000.0},
    "musket_tail": {"vol": -5.0},
    "musket_tail_fort": {"vol": -5.0},
    "pistol_tail": {"vol": -7.0},
    "pistol_tail_fort": {"vol": -7.0, "rp": 1.02},
    "ball_whizz": {"travel": False},
    # --- bow (spec trigger levels)
    "bow_equip": {"vol": -9.0, "rp": 1.05},
    "bow_holster": {"vol": -10.0, "rp": 1.04},
    "quiver_draw": {"vol": -14.0, "rp": 1.06},
    "arrow_rest": {"vol": -18.0, "rp": 1.06},
    "nock_click": {"vol": -14.0, "rp": 1.05},
    "bow_draw": {"vol": -12.0, "rp": 1.04},
    "bow_creak_loop": {"vol": 0.0, "rp": 1.0, "loop": True},        # level set per frame in code
    "bow_release": {"vol": -3.0, "rp": 1.03},
    "arrow_whoosh": {"vol": -8.0, "rp": 1.05, "maxd": 60.0},
    "bow_let_down": {"vol": -12.0, "rp": 1.04},
    "quiver_empty": {"vol": -14.0, "rp": 1.0},
    # --- targets (targets.py docstring)
    "dummy_hit": {"vol": -6.0, "rp": 1.08},
    "dummy_hit_head": {"vol": -2.0, "rp": 1.06},
    "dummy_topple": {"vol": -3.0, "rp": 1.03},
    "dummy_reset": {"vol": -8.0, "rp": 1.03},
    # --- footsteps (base volumes come from levels.json)
    "jump_takeoff": {"rp": 1.05},
    "land_dirt": {"rp": 1.04}, "land_grass": {"rp": 1.04}, "land_wood": {"rp": 1.04},
    # --- ambience (ambience.py docstring; files are loudness-matched, not peak-normalised)
    "forest_wind_loop": {"vol": -16.0, "rp": 1.0, "loop": True},
    "bird_thrush": {"vol": -1.5},
    "bird_chickadee": {"vol": -4.0},
    "bird_warbler": {"vol": -4.5},
    "crow_caw": {"vol": -1.0, "rp": 1.0},
    "woodpecker_drum": {"vol": -2.0, "rp": 1.05},
    "birds_flush": {"vol": -2.0},
    "tree_creak": {"vol": -12.0, "rp": 1.08, "unit": 10.0},
    "flag_flutter_loop": {"vol": -14.0, "rp": 1.0, "unit": 3.0, "maxd": 40.0, "loop": True},
    # the river (RiverWater): its running water at its nearest point, louder at each rapid and heard further
    "river_flow_loop": {"vol": -12.0, "rp": 1.0, "unit": 8.0, "maxd": 110.0, "loop": True},
    "river_rapids_loop": {"vol": -6.0, "rp": 1.0, "unit": 14.0, "maxd": 220.0, "loop": True},
    # --- fire (fire.py docstring): the crackle loop's level follows the fire's strength in code
    "torch_crackle_loop": {"vol": -16.0, "rp": 1.0, "unit": 2.0, "maxd": 25.0, "loop": True},
    "torch_ignite": {"vol": -10.0, "rp": 1.06},
    "torch_snuff": {"vol": -12.0, "rp": 1.06},
    "torch_toss": {"vol": -12.0, "rp": 1.08},
    # --- wildlife (wildlife_rec.py): a pack howling carries across the valley; a fox and a raven not as far
    "wild_rec_wolf_chorus": {"vol": -4.0, "unit": 60.0, "maxd": 1400.0, "cut": 3500.0, "rp": 1.03},
    "wild_rec_fox_call": {"vol": -3.0, "unit": 15.0, "maxd": 350.0},
    "wild_rec_raven_call": {"vol": -4.0, "unit": 12.0, "maxd": 300.0, "rp": 1.06},
    # --- birds (birds_rec.py): owls and the whip-poor-will carry through the night woods; songbirds closer
    "bird_rec_barred_owl": {"vol": -5.0, "unit": 25.0, "maxd": 450.0, "cut": 4500.0},
    "bird_rec_great_horned_owl": {"vol": -5.0, "unit": 25.0, "maxd": 450.0, "cut": 4000.0},
    "bird_rec_whip_poor_will": {"vol": -6.0, "unit": 18.0, "maxd": 300.0},
    "bird_rec_wood_thrush": {"vol": -6.0, "unit": 14.0, "maxd": 180.0},
    "bird_rec_veery": {"vol": -7.0, "unit": 12.0, "maxd": 160.0},
    "bird_rec_hermit_thrush": {"vol": -7.0, "unit": 12.0, "maxd": 160.0},
    "bird_rec_robin": {"vol": -7.0, "unit": 12.0, "maxd": 150.0},
    "bird_rec_red_eyed_vireo": {"vol": -8.0, "unit": 10.0, "maxd": 120.0},
    "bird_rec_chickadee": {"vol": -8.0, "unit": 8.0, "maxd": 100.0},
    "bird_rec_blue_jay": {"vol": -6.0, "unit": 14.0, "maxd": 200.0},
    "bird_rec_pileated_woodpecker": {"vol": -6.0, "unit": 16.0, "maxd": 220.0},
    "bird_rec_ruffed_grouse": {"vol": -6.0, "unit": 14.0, "maxd": 200.0, "rp": 1.0},
    "bird_rec_wild_turkey": {"vol": -6.0, "unit": 18.0, "maxd": 280.0},
    "bird_rec_crow": {"vol": -5.0, "unit": 18.0, "maxd": 300.0},
}


def scan() -> dict:
    """family -> id -> sorted list of file names."""
    out = {}
    for fam in FAMILIES:
        d = os.path.join(SFX_DIR, fam)
        if not os.path.isdir(d):
            continue
        ids: dict = {}
        for f in sorted(os.listdir(d)):
            m = NAME_RE.match(f)
            if m and (fam != "bend" or m.group("id") in BEND_IDS):
                ids.setdefault(m.group("id"), []).append(f)
        out[fam] = ids
    return out


def load_json(path: str) -> dict:
    try:
        with open(path) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def bend_table() -> dict:
    """BendSounds.TABLE (scripts/bending/bend_sounds.gd): id -> {vol, unit, maxd, bus, rp, rv}."""
    out = {}
    try:
        with open(BEND_SOUNDS) as fh:
            text = fh.read()
    except OSError:
        return out
    for m in re.finditer(r'&"(\w+)":\s*\{([^}]*)\}', text):
        e = {}
        for k, v in re.findall(r'"(\w+)":\s*("[^"]*"|-?[\d.]+)', m.group(2)):
            e[k] = v.strip('"') if v.startswith('"') else float(v)
        if "vol" in e:
            out[m.group(1)] = e
    return out


def defaults_for(fam: str, sid: str, flint: dict, impacts: dict, levels: dict, gathering: dict | None = None) -> dict:
    c = dict(BASE)
    c.update(FAMILY_BASE.get(fam, {}))
    if fam == "bend":
        # (BendSounds' own levels and ranges; its distance dulling is BendSounds.DIST_CUT_HZ / DIST_CUT_DB)
        bt = bend_table().get(sid, {})
        for k in ("vol", "unit", "maxd", "rp", "rv"):
            if k in bt:
                c[k] = float(bt[k])
        c["bus"] = str(bt.get("bus", "World"))
        c["cut"] = 6500.0
        c["fdb"] = -10.0
    elif fam == "flintlock":
        pb = flint.get("sounds", {}).get(sid, {}).get("playback", {})
        if pb:
            c["bus"] = pb.get("bus", c["bus"])
            vol = pb.get("volume_db", c["vol"])
            c["vol"] = float(vol.get("musket", 0.0) if isinstance(vol, dict) else vol)
            c["rp"] = float(pb.get("random_pitch", 1.0))
            c["rv"] = float(pb.get("random_volume_offset_db", 0.0))
            if "unit_size" in pb:
                c["unit"] = float(pb["unit_size"])
            if "max_db" in pb:
                c["maxdb"] = float(pb["max_db"])
    elif fam == "impacts":
        pb = impacts.get("sounds", {}).get(sid, {})
        for src, dst in (("volume_db", "vol"), ("random_pitch", "rp"), ("unit_size", "unit"),
                         ("max_distance", "maxd"), ("speed_ref", "sref"), ("speed_min", "smin")):
            if pb.get(src) is not None:
                c[dst] = float(pb[src])
        if "bus" in pb:
            c["bus"] = pb["bus"]
    elif fam == "gathering_rec":
        pb = (gathering or {}).get("sounds", {}).get(sid, {})
        for src, dst in (("volume_db", "vol"), ("random_pitch", "rp"), ("random_volume_db", "rv"),
                         ("unit_size", "unit"), ("max_distance", "maxd")):
            if pb.get(src) is not None:
                c[dst] = float(pb[src])
        if "bus" in pb:
            c["bus"] = pb["bus"]
    elif fam == "footsteps":
        lv = levels.get("sounds", {}).get(sid, {})
        if "base_volume_db" in lv:
            c["vol"] = float(lv["base_volume_db"])
        if sid.startswith("step_"):
            c["rv"] = 1.5
            if sid.endswith("_sprint") or sid.endswith("_crouch"):
                c["rp"] = 1.05
    c.update(OVERRIDES.get(sid, {}))
    return c


def gd(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return repr(round(v, 3))
    if isinstance(v, int):
        return repr(float(v))
    if isinstance(v, str):
        return '"%s"' % v
    raise TypeError(v)


def write_manifest(tree: dict) -> int:
    flint = load_json(os.path.join(SFX_DIR, "flintlock", "flintlock_manifest.json"))
    impacts = load_json(os.path.join(SFX_DIR, "impacts", "impacts_manifest.json"))
    levels = load_json(os.path.join(SFX_DIR, "footsteps", "levels.json"))
    gathering = load_json(os.path.join(SFX_DIR, "gathering_rec", "gathering_rec_manifest.json"))
    files_lines, gain_lines, def_lines = [], [], []
    count = 0
    for fam in FAMILIES:
        ids = tree.get(fam, {})
        if not ids:
            continue
        files_lines.append("\t# %s" % fam)
        def_lines.append("\t# %s" % fam)
        for sid in sorted(ids):
            names = ids[sid]
            count += len(names)
            paths = ", ".join('"res://audio/sfx/%s/%s"' % (fam, n) for n in names)
            files_lines.append('\t"%s": [%s],' % (sid, paths))
            lv = levels.get("sounds", {}).get(sid, {}).get("files", {}) if fam == "footsteps" else {}
            if lv:
                gains = [float(lv.get(n, {}).get("trim_db", 0.0)) for n in names]
                gain_lines.append('\t"%s": [%s],' % (sid, ", ".join(gd(g) for g in gains)))
            c = defaults_for(fam, sid, flint, impacts, levels, gathering)
            body = ", ".join('"%s": %s' % (k, gd(c[k])) for k in c)
            def_lines.append('\t"%s": {%s},' % (sid, body))
    src = [
        "extends RefCounted",
        "## GENERATED by tools/sfx/gen_manifest.py from audio/sfx/ - do not edit by hand; rerun",
        "## the script after regenerating sounds or changing levels (see its OVERRIDES table).",
        "## Read by scripts/audio/sfx.gd.",
        "",
        "## Sound id -> variant files.",
        "const FILES := {",
        *files_lines,
        "}",
        "",
        "## Per-variant gain in dB (evens out variants; footsteps levels.json trims).",
        "const FILE_GAIN := {",
        *gain_lines,
        "}",
        "",
        "## Playback defaults per id (see the generator docstring for the keys).",
        "const DEFAULTS := {",
        *def_lines,
        "}",
        "",
    ]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as fh:
        fh.write("\n".join(src))
    return count


def set_pcm_imports(tree: dict) -> int:
    changed = 0
    for fam, ids in tree.items():
        for sid, names in ids.items():
            mode = "2" if sid in KEEP_COMPRESSED else "0"
            for n in names:
                p = os.path.join(SFX_DIR, fam, n + ".import")
                if not os.path.exists(p):
                    continue
                with open(p) as fh:
                    text = fh.read()
                new = re.sub(r"(?m)^compress/mode=\d+$", "compress/mode=" + mode, text)
                if new != text:
                    with open(p, "w") as fh:
                        fh.write(new)
                    changed += 1
    return changed


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--no-import", action="store_true", help="leave the .import files alone")
    a = ap.parse_args()
    tree = scan()
    n = write_manifest(tree)
    print("wrote %s: %d ids, %d files" % (os.path.relpath(OUT, ROOT), sum(len(v) for v in tree.values()), n))
    if not a.no_import:
        print("import settings changed: %d" % set_pcm_imports(tree))


if __name__ == "__main__":
    main()
