"""The shared kit of the fighting-style generators (tools/anim_author/blender/style_<style>.py; docs/fighting_styles_design.md:
each element keeps its moves, a style re-animates how the body performs them). Taken from style_boxing.py, the first style
(which keeps its own copy, unchanged since the owner approved it on 2026-10-09):
  - bend_clips.py's solver and bake (pose(), two-bone IK on Actor_B's own rig, bake()), imported; nothing else read;
  - the owner's closed hands (2026-10-09: "make sure the hand ik is closed"): the fingers' curl table CURL and the thumb's
    fold across the fist by two-bone IK on its own joints, by the hand's grip, set on bend_clips for the bake only
    (bend_clips.py itself unchanged);
  - clip(): a clip on a style's base pose (every keyed channel starts and ends on it, the channels not keyed hold it);
  - main(): the command line and the json for tools/anim_author/install_style.gd (install_bend.gd's route).

  import style_kit as kit
  kit.hands()                                   # the closed hands, once, before baking
  clip = kit.clip_on(BASE, META)               # BASE: a full channel dict (bend_clips.STAND updated); META: the metas
  kit.main(style="capoeira", element="air", clips=CLIPS)
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bend_clips as bc  # noqa: E402  (the solver and the bake: pose(), bake(), keep_blend(); reads only the rig)
from bend_clips import FACING, FPS, STAND, SK  # noqa: E402,F401

## The fingers' close at grip 1 (deg about the knuckles' line, as bend_clips.CURL), a little past bend_clips' own; the
## thumb left to the fold below.
CURL = {"index": {"a": 86, "b": 100, "c": 66}, "middle": {"a": 88, "b": 102, "c": 66},
        "ring": {"a": 90, "b": 102, "c": 64}, "pinky": {"b": 94, "c": 100, "d": 60},
        "thumb": {"b": 0, "c": 0}}
## The thumb's last joint carried THUMB_OUT m outside the index finger's middle by the grip (0 as the rig has it, 1 a fist).
THUMB_OUT = 0.01

_bend_pose = bc.pose


def _thumb_fold(rots, root, s, g):
    if g <= 0.0:
        return
    P, _ = SK.fk(rots, root)
    _, n = bc.finger_axes(rots, s)
    across = (P[s + "_indexa"] - P[s + "_middlea"]).normalized()
    base = P[s + "_thumba"]
    closed = (P[s + "_indexb"] + P[s + "_indexc"]) * 0.5 + n * THUMB_OUT
    tgt = P[s + "_thumbc"].lerp(closed, g)
    reach = (P[s + "_thumbb"] - base).length + (P[s + "_thumbc"] - P[s + "_thumbb"]).length - 0.001
    if (tgt - base).length > reach:
        tgt = base + (tgt - base).normalized() * reach
    pole = P[s + "_thumbb"] + across * 0.05 - n * 0.02
    for _ in range(2):
        bc.rigkit.ik2(rots, root, s + "_thumba", s + "_thumbb", s + "_thumbc", tgt, pole)


def _hands_pose(clip, f):
    """bend_clips' pose, then each thumb folded across its hand by the hand's grip."""
    rots, root = _bend_pose(clip, f)
    for s in "lr":
        _thumb_fold(rots, root, s, max(0.0, min(1.0, bc.num(clip, "grip_" + s, f))))
    return rots, root


def hands():
    """The closed hands on bend_clips for this bake (its CURL table and its pose(); the file unchanged)."""
    bc.CURL.clear()
    bc.CURL.update(CURL)
    bc.pose = _hands_pose


def clip_on(base, meta_defaults):
    """clip(length, meta, **channels): a clip on `base` (each keyed channel starts on base's value at f0 and ends on it at
    the last frame unless its keys say otherwise; the channels not keyed hold base's), its metas `meta_defaults` + meta."""
    def clip(length, meta, **ch):
        c = {"length": length, "meta": dict(meta_defaults, **meta), "base": base}
        for k, keys in ch.items():
            if k in ("mirror", "spin_turns", "twin_keys", "twin_ends", "twin_start", "twin_tail", "toes", "ground",
                     "floor", "pivot_keys"):
                c[k] = keys
                continue
            keys = list(keys)
            if k not in base:                  # (a channel the stand has no value for: spin, flip, cart, pivot, ground: as keyed)
                c[k] = keys
                continue
            if keys[0][0] != 0:
                keys.insert(0, (0, base[k]))
            if keys[-1][0] != length:
                keys.append((length, base[k]))
            c[k] = keys
        return c
    return clip


def s_(a, ph=0.0):
    return math.sin(a + ph)


def c_(a, ph=0.0):
    return math.cos(a + ph)


def add(v, d):
    return tuple(round(x + y, 4) for x, y in zip(v, d))


def r_(v):
    return tuple(round(x, 4) for x in v) if isinstance(v, (tuple, list)) else round(float(v), 3)


def all_clips(clips):
    """The clips with their mirrored twins (<name>_l: bend_clips.mirror_clip, the keys mirrored left for right)."""
    out = {}
    for name, c in clips.items():
        out[name] = c
        if c.get("mirror"):
            out[name + "_l"] = bc.mirror_clip(c)
    return out


def game_name(style, key):
    st = style.replace("_", "-")     # (a two-word style, muay_thai: own-style-muay-thai-..., as BendPoses._style_library_of looks it up)
    if key.endswith("_l"):
        return "own-style-%s-%s-l" % (st, key[:-2].replace("_", "-"))
    return "own-style-%s-%s" % (st, key.replace("_", "-"))


def main(style, element, clips, generator=None):
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--blend", default=None)
    ap.add_argument("--clips", default="")
    ap.add_argument("--glb", default=None)
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--fit", action="store_true", help="list the frames where a limb is (nearly) locked straight")
    ap.add_argument("--angles", action="store_true", help="print each frame's elbow and knee bends (deg, 0 straight)")
    ap.add_argument("--points", action="store_true", help="print each frame's key joints and the lowest surface (m)")
    a = ap.parse_args(argv)
    only = [c for c in a.clips.split(",") if c]
    generator = generator or "tools/anim_author/blender/style_%s.py" % style
    library = "res://animations_extra/Frontier_Style_%s.res" % style.capitalize()
    out = {"fps": FPS, "clips": {}, "names": {}, "style": style, "element": element, "library": library,
           "generator": generator,
           "about": generator + ": our own %s clips for %s (a fighting style), key poses IK-solved on Actor_B's rig in Blender "
                    "by bend_clips.py's solver from the rig's rest pose (no library clip read)" % (style, element)}
    baked = {}
    tag = style[:3].upper()
    for name, c in all_clips(clips).items():
        if only and name not in only and name.removesuffix("_l") not in only:
            continue
        fit = [] if a.fit else None
        frames, roots, report = bc.bake(c, fit)
        meta = dict(c["meta"])
        meta["length_frames"] = c["length"]
        meta["ik_miss_m"] = round(max(r[-1] for r in report), 4)
        if c.get("loop"):
            meta["loop"] = "linear"
        out["clips"][name] = {"frames": frames, "root": roots, "meta": meta}
        out["names"][name] = game_name(style, name)
        baked[name] = (frames, roots)
        print("%s %s -> %s: %d frames, worst IK miss %.3f m" % (tag, name, game_name(style, name), len(frames), meta["ik_miss_m"]))
        for fr in fit or []:
            print("   FIT %s f%02d %s slack %.3f -> %s" % (name, fr[0], fr[1], fr[2], fr[3]))
        if a.angles:
            for fr, ang in bc.ANGLES:
                print("   ANG %s f%02d elbow r %3d l %3d  knee r %3d l %3d" % (name, fr, *ang))
        if a.points:
            for fr, pts, low, hat, far in bc.POINTS:
                print("   PTS %s f%02d low %.3f (%s) " % (name, fr, low[0], low[1]) +
                      " ".join("%s=%s" % (j, list(v)) for j, v in pts.items()) + " hat=%.3f hatz=%.3f palmhat=%.3f" % (hat, *far))
        if not a.quiet:
            for r in report:
                print("   f%02d  r_palm %s  l_palm %s  pelvis %.3f  r_ankle %s  l_ankle %s  miss %.3f" % r)
    json.dump(out, open(a.out, "w"))
    print("%s baked %d clips -> %s" % (tag, len(out["clips"]), a.out))
    if a.blend:
        bc.keep_blend(a.blend, baked)
        print("%s blend -> %s" % (tag, a.blend))
