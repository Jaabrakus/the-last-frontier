#!/usr/bin/env python3
"""Which 1-frame pose is an actor's true bind pose (the frames its clips are authored in)?

  python3 tools/retarget/bind_pose_probe.py <dump.json> [--out probe.json]

<dump.json> is dump_clips.gd output in sampling mode (actor=... every=6): skeleton rests,
the imported glTF rest, every 1-frame bindpose / null / retarget-pose clip, and frames at
t=0 and t=length/2 of every 6th clip. Three independent tests, as for Actor_B's null-add:

 1. Constant bone offsets: a bone's local translation is the same in every clip (rigid
    skeleton), so it must equal the bind pose's. For each bone whose clip translations
    spread < 2 mm (median of the non-additive samples), count candidates within 1 mm.
    This also tests the parent's frame orientation (the offset is expressed in it).
 2. Agreement with `null-add` (the additive identity) on the channels it keys.
 3. Hinges: knees, elbows and finger joints rotate about one local axis relative to the
    true bind pose (rel = bind^-1 * q is a pure rotation about a fixed axis). Median /
    p90 deviation of the rotation axes from their principal axis, per candidate.
Prints a table and writes the numbers as JSON.
"""
import argparse
import collections
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

HINGE_BONES = ["l_knee", "r_knee", "l_elbow", "r_elbow", "l_indexb", "l_middleb", "l_ringb", "r_indexc", "l_thumbc"]


def qmul(a, b):
    x1, y1, z1, w1 = a
    x2, y2, z2, w2 = b
    return np.array([w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2, w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
                     w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2, w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2])


def qang(a, b):
    a, b = np.asarray(a, float), np.asarray(b, float)
    d = abs(np.dot(a, b)) / np.linalg.norm(a) / np.linalg.norm(b)
    return float(np.degrees(2 * np.arccos(min(1.0, d))))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dump")
    ap.add_argument("--out")
    args = ap.parse_args()
    d = json.load(open(args.dump))
    poses = {k: v["pose"] for k, v in d["poses"].items()}
    gl = {b["name"]: {"pos": b["pos"], "rot": b["rot"]} for b in d["gltf_skeleton"]["bones"]}
    cands = dict(poses)
    cands["(imported glTF rest)"] = gl
    pos = collections.defaultdict(list)
    rot = collections.defaultdict(list)
    for c in d["clips"].values():
        if c["meta"].get("additive_source"):
            continue
        for b, ch in c["tracks"].items():
            for v in ch.get("pos", []):
                pos[b].append(v)
            for v in ch.get("rot", []):
                rot[b].append(v)
    res = {"actor": d["actor"], "clips_sampled": len(d["clips"]), "candidates": {}}
    # 1. constant offsets
    const = {}
    for b, P in pos.items():
        P = np.asarray(P)
        if len(P) < 5:
            continue
        med = np.median(P, 0)
        if np.median(np.linalg.norm(P - med, axis=1)) <= 0.002:
            const[b] = med
    for name, pose in cands.items():
        n = ok = 0
        worst = 0.0
        for b, med in const.items():
            v = pose.get(b, {}).get("pos")
            if v is None:
                continue
            e = float(np.linalg.norm(np.asarray(v) - med))
            n += 1
            ok += e < 0.001
            worst = max(worst, e)
        res["candidates"][name] = {"bones_keyed": len(pose), "offset_bones_compared": n, "offset_within_1mm": ok,
                                   "offset_max_err_m": round(worst, 4)}
    # 2. null-add agreement
    na = poses.get("null-add", {})
    for name, pose in cands.items():
        ra = [qang(v["rot"], pose[b]["rot"]) for b, v in na.items() if "rot" in v and b in pose and "rot" in pose[b]]
        pa = [float(np.linalg.norm(np.asarray(v["pos"]) - pose[b]["pos"])) for b, v in na.items()
              if "pos" in v and b in pose and "pos" in pose[b]]
        res["candidates"][name]["null_add"] = {"channels": len(ra) + len(pa),
                                               "max_rot_deg": round(max(ra), 4) if ra else None,
                                               "max_pos_m": round(max(pa), 5) if pa else None}
    # 3. hinges
    for name, pose in cands.items():
        h = {}
        for b in HINGE_BONES:
            if b not in pose or "rot" not in pose[b] or b not in rot:
                continue
            q0 = np.asarray(pose[b]["rot"], float)
            inv = np.array([-q0[0], -q0[1], -q0[2], q0[3]]) / np.dot(q0, q0)
            axes = []
            for q in rot[b]:
                r = qmul(inv, q)
                if r[3] < 0:
                    r = -r
                if 2 * np.arccos(min(1.0, r[3])) > np.radians(15):
                    axes.append(r[:3] / np.linalg.norm(r[:3]))
            if len(axes) < 5:
                continue
            A = np.asarray(axes)
            pa = np.linalg.svd(A)[2][0]
            dev = np.degrees(np.arccos(np.clip(np.abs(np.sum(A * pa, 1)), 0, 1)))
            h[b] = {"median_deg": round(float(np.median(dev)), 2), "p90_deg": round(float(np.percentile(dev, 90)), 1),
                    "axis": np.round(pa, 2).tolist(), "n": len(axes)}
        res["candidates"][name]["hinges"] = h
    # unkeyed channels of the winner
    names = [b["name"] for b in d["skeleton"]["bones"]]
    print(f"{d['actor']}: {len(d['clips'])} sampled clips, {len(const)} bones with constant offsets")
    print(f"{'candidate':24s} {'bones':>5s} {'offsets<1mm':>12s} {'max_err':>8s} {'null-add rot/pos':>18s}  hinge median deg (knee, elbow, indexb)")
    for name, c in res["candidates"].items():
        na_ = c["null_add"]
        hh = c["hinges"]
        hs = ", ".join(f"{hh[b]['median_deg']:.2f}" if b in hh else "-" for b in ("l_knee", "l_elbow", "l_indexb"))
        print(f"{name:24s} {c['bones_keyed']:5d} {c['offset_within_1mm']:5d}/{c['offset_bones_compared']:<6d} "
              f"{c['offset_max_err_m']:8.4f} {str(na_['max_rot_deg']):>9s}/{str(na_['max_pos_m']):<8s}  {hs}")
    for name in ("bindpose", "null-add"):
        if name in poses:
            miss = [b for b in names if b not in poses[name]]
            res.setdefault("unkeyed", {})[name] = miss
    if args.out:
        json.dump(res, open(args.out, "w"), indent=1)
        print("->", args.out)


if __name__ == "__main__":
    main()
