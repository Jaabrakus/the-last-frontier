#!/usr/bin/env python3
"""How smooth a bake of tools/anim_author/blender/bend_clips.py is (its json): every bone's turn from one frame to the next, and
the frames where a bone snaps — a turn far over the frames either side (a one-frame pop) or a wrist or forearm turning faster
than a hand can (a flip of the palm's facing through its degenerate way, or an IK pole flip). Standard library and numpy.

    python3 tools/anim_author/bend_smoothness.py <bend.json> [--clips a,b] [--top 40] [--json out.json]

Per clip: its worst snap (deg in one frame at the clip's own rate, and as deg/s), the count of snaps, and its smoothness score
(the sum over bones of the largest frame-to-frame change of turn rate: low is smooth). A snap:
  pop    a bone's turn in one frame over POP_MIN_DEG and over POP_K times the larger of the turns either side of it
  flip   a wrist or forearm (or the hand's children) turning more than FLIP_DPS deg/s in a frame
"""
import argparse
import json
import math
import sys

import numpy as np

POP_MIN_DEG = 12.0
POP_K = 2.5
FLIP_DPS = 1500.0
WRISTISH = ("wrist", "forearm", "hand")


def turns(qs):
    """The angle (deg) between each frame's quaternion and the one before it."""
    q = np.asarray(qs, dtype=np.float64)
    q /= np.linalg.norm(q, axis=1, keepdims=True)
    d = np.abs(np.sum(q[1:] * q[:-1], axis=1)).clip(0.0, 1.0)
    return np.degrees(2.0 * np.arccos(d))


def qmul(a, b):
    """Quaternion products row by row ([x, y, z, w])."""
    ax, ay, az, aw = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    bx, by, bz, bw = b[..., 0], b[..., 1], b[..., 2], b[..., 3]
    return np.stack([aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
                     aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz], axis=-1)


def twist_steps(qs, axis):
    """Each frame step's twist about the bone's own axis (deg): the step in the bone's own frame (q_prev^-1 q), its part about
    `axis` (swing-twist)."""
    q = np.asarray(qs, dtype=np.float64)
    q /= np.linalg.norm(q, axis=1, keepdims=True)
    inv = q[:-1] * np.array([-1.0, -1.0, -1.0, 1.0])
    d = qmul(inv, q[1:])
    a = np.asarray(axis, dtype=np.float64)
    a /= np.linalg.norm(a)
    p = d[:, :3] @ a
    return np.degrees(2.0 * np.arctan2(np.abs(p), np.abs(d[:, 3])))


AXES = {}
TWIST_FLIP_DEG = 40.0


def clip_report(name, clip, fps):
    frames = clip["frames"]
    cfps = float(clip.get("fps", fps))
    loop = clip.get("meta", {}).get("loop") is not None
    out = {"clip": name, "fps": cfps, "frames": len(frames), "snaps": [], "score": 0.0, "worst": (0.0, "", 0),
           "twists": []}
    if len(frames) < 3:
        return out
    for bone in frames[0]:
        st = turns([f[bone] for f in frames])                 # st[i]: the turn from frame i to i+1
        if bone in AXES:
            # (a twist flip: the bone spun about its own length in a frame, its way hardly moving: the IK's twist jumping,
            # not a limb's swing; scaled to 30 fps so a 60 fps bake's half steps compare)
            tw = twist_steps([f[bone] for f in frames], AXES[bone]) * (cfps / 30.0)
            for i in np.nonzero(tw > TWIST_FLIP_DEG)[0]:
                # (spike: far over the twist either side, a one-frame jump; else a fast twist carried over several frames,
                # as a throw's upper arm turns)
                side = max(tw[i - 1] if i > 0 else 0.0, tw[i + 1] if i + 1 < tw.size else 0.0)
                out["twists"].append({"bone": bone, "frame": int(i) + 1, "twist_deg": round(float(tw[i]), 1),
                                      "turn_deg": round(float(st[i]), 1), "spike": bool(tw[i] > POP_K * side)})
        if st.size < 2:
            continue
        rate = st * cfps
        acc = np.abs(np.diff(rate))
        out["score"] += float(acc.max()) / cfps
        for i in range(st.size):
            before = st[i - 1] if i > 0 else (st[-1] if loop else 0.0)
            after = st[i + 1] if i + 1 < st.size else (st[0] if loop else 0.0)
            side = max(before, after)
            kind = ""
            if st[i] > POP_MIN_DEG and st[i] > POP_K * side:
                kind = "pop"
            elif any(w in bone for w in WRISTISH) and rate[i] > FLIP_DPS:
                kind = "flip"
            if kind:
                out["snaps"].append({"bone": bone, "frame": i + 1, "deg": round(float(st[i]), 1),
                                     "dps": round(float(rate[i])), "side_deg": round(float(side), 1), "kind": kind})
            if st[i] > out["worst"][0]:
                out["worst"] = (round(float(st[i]), 1), bone, i + 1)
    out["score"] = round(out["score"], 1)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("bake")
    ap.add_argument("--clips", default="")
    ap.add_argument("--top", type=int, default=40)
    ap.add_argument("--json", default="")
    ap.add_argument("--axes", default="", help="tools/anim_author/bend_axes.gd's json: count twist flips too")
    a = ap.parse_args()
    if a.axes:
        AXES.update({k: v for k, v in json.load(open(a.axes)).items() if not k.startswith("_")})
    baked = json.load(open(a.bake))
    only = [c for c in a.clips.split(",") if c]
    names = baked.get("names", {})
    reps = []
    for key, clip in baked["clips"].items():
        if only and key not in only and names.get(key, "") not in only:
            continue
        r = clip_report(names.get(key, key), clip, float(baked["fps"]))
        reps.append(r)
    reps.sort(key=lambda r: (-len(r["snaps"]), -r["worst"][0]))
    total = sum(len(r["snaps"]) for r in reps)
    print("BEND SMOOTHNESS %d clips, %d snaps (pop: > %.0f deg and %.1fx the frames either side; flip: a wrist over %.0f deg/s)"
          % (len(reps), total, POP_MIN_DEG, POP_K, FLIP_DPS))
    for r in reps[:a.top]:
        if not r["snaps"]:
            continue
        kinds = {}
        for s in r["snaps"]:
            kinds[s["kind"]] = kinds.get(s["kind"], 0) + 1
        print("%-34s snaps %3d (%s)  worst %5.1f deg %s f%d  score %.0f" % (
            r["clip"], len(r["snaps"]), ", ".join("%s %d" % kv for kv in sorted(kinds.items())), r["worst"][0], r["worst"][1],
            r["worst"][2], r["score"]))
        for s in sorted(r["snaps"], key=lambda s: -s["deg"])[:6]:
            print("      %-5s %-14s f%-3d %6.1f deg (%5d deg/s), either side %5.1f" % (
                s["kind"], s["bone"], s["frame"], s["deg"], s["dps"], s["side_deg"]))
    clean = sum(1 for r in reps if not r["snaps"])
    print("CLEAN %d of %d clips" % (clean, len(reps)))
    if AXES:
        tw = sorted(reps, key=lambda r: -len(r["twists"]))
        n = sum(len(r["twists"]) for r in reps)
        print("TWIST FLIPS %d (a bone spun over %.0f deg about its own length in a frame at 30 fps), in %d clips; %d of them "
              "spikes (%.1fx the twist either side: a one-frame jump)" % (
                  n, TWIST_FLIP_DEG, sum(1 for r in reps if r["twists"]),
                  sum(1 for r in reps for t in r["twists"] if t["spike"]), POP_K))
        sp = {}
        for r in reps:
            for t in r["twists"]:
                if t["spike"]:
                    sp[t["bone"]] = sp.get(t["bone"], 0) + 1
        print("   spikes by bone: " + ", ".join("%s %d" % kv for kv in sorted(sp.items(), key=lambda kv: -kv[1])[:12]))
        by = {}
        for r in reps:
            for t in r["twists"]:
                by[t["bone"]] = by.get(t["bone"], 0) + 1
        print("   by bone: " + ", ".join("%s %d" % kv for kv in sorted(by.items(), key=lambda kv: -kv[1])[:12]))
        for r in tw[:a.top]:
            if r["twists"]:
                worst = max(r["twists"], key=lambda t: t["twist_deg"])
                print("   %-34s %3d  worst %5.1f deg %s f%d" % (r["clip"], len(r["twists"]), worst["twist_deg"], worst["bone"],
                                                              worst["frame"]))
    if a.json:
        json.dump(reps, open(a.json, "w"), indent=1)


if __name__ == "__main__":
    sys.exit(main())
