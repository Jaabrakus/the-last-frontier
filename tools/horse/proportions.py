"""Measure the horse's conformation on the skin SDF (the shape the mesh is built from) and
compare it with typical values for a stocky 14.1-hand horse.

  python3 tools/horse/proportions.py [--json OUT]

Horse space: metres, z up, the horse faces -y, +x is its left. The reference ranges are
the usual conformation ratios (body length about equal to the height, chest depth about half
of it, head about 0.4 of it) and typical measures of small, heavy-boned horses of the
Canadian / Morgan type; they are guides, not a breed standard.
"""

import json
import math
import sys

import numpy as np

sys.dont_write_bytecode = True
import anatomy as A      # noqa: E402

NODE = A.horse_body()


def f(p):
    p = np.atleast_2d(np.asarray(p, float))
    return NODE.f(p[:, 0], p[:, 1], p[:, 2])


def extent(start, d, step=0.001, far=1.5):
    """Distance from start along d to the surface (start inside)."""
    d = np.asarray(d, float) / np.linalg.norm(d)
    ts = np.arange(0.0, far, step)
    v = f(np.asarray(start)[None, :] + ts[:, None] * d)
    out = np.nonzero(v > 0)[0]
    return float(ts[out[0]]) if len(out) else float("nan")


def top_z(x, y, z0=2.0):
    zs = np.arange(z0, 0.0, -0.001)
    v = f(np.stack([np.full_like(zs, x), np.full_like(zs, y), zs], 1))
    i = np.nonzero(v < 0)[0]
    return float(zs[i[0]]) if len(i) else float("nan")


def slice_perimeter(z, x0, y0, r=0.08, n=180):
    """Perimeter of the horizontal section round (x0, y0) at height z (limb girth)."""
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        d = np.array([math.cos(a), math.sin(a), 0.0])
        pts.append(np.array([x0, y0, z]) + d * extent([x0, y0, z], d, 0.0005, r))
    pts = np.array(pts)
    return float(np.sum(np.linalg.norm(np.roll(pts, -1, 0) - pts, axis=1))), pts


def measure():
    m = {}
    W = A.WITHERS
    m["withers_height"] = max(top_z(0.0, A.S((0, y, 0))[1]) for y in np.linspace(-0.46, -0.36, 11))
    m["croup_height"] = max(top_z(0.0, y) for y in np.linspace(0.25, 0.7, 46))
    # body length: point of shoulder (front-most point of the chest at shoulder height) to the
    # point of buttock (rear-most point at buttock height)
    zs = A.J["shoulder"][2]
    front = min(y for y in np.arange(-1.2, -0.5, 0.002) if f([A.J["shoulder"][0], y, zs])[0] < 0)
    back = max(max((y for y in np.arange(0.4, 1.2, 0.002) if f([0.10, y, zb])[0] < 0), default=0.0)
               for zb in np.arange(0.90, 1.20, 0.01))
    m["body_length"] = back - front
    m["point_of_buttock_behind_hip_joint"] = back - A.J["hip"][1]
    # chest depth at the girth and leg length (elbow height)
    under = []
    for yg in np.linspace(-0.45, -0.15, 16):
        under.append(min(z for z in np.arange(0.4, 1.2, 0.002) if f([0.0, yg, z])[0] < 0))
    zb_ = min(under)
    m["chest_depth"] = m["withers_height"] - zb_
    m["leg_length_ground_to_girth"] = zb_
    m["elbow_height"] = A.J["elbow"][2]
    ps = np.array(A.J["shoulder"])
    m["chest_width_points_of_shoulder"] = 2 * extent([0.0, ps[1] + 0.02, ps[2]], [1, 0, 0])
    ph = np.array(A.S((0.20, 0.40, 1.17)))           # point of hip landmark
    m["hip_width_points_of_hip"] = 2 * max(extent([0.0, ph[1] + dy, ph[2]], [1, 0, 0]) for dy in np.linspace(-0.05, 0.05, 11))
    m["barrel_width"] = 2 * max(extent([0.0, y, 0.95], [1, 0, 0]) for y in np.linspace(-0.1, 0.3, 21))
    # head: poll (behind the ears) to the front of the upper lip, width across the orbits,
    # depth at the jowl
    poll = np.array(A.S(A.hp(-0.02, 0.05)))
    lip = np.array(A.S(A.hp(0.60, -0.03)))
    d = lip - poll
    tip = poll + d * (extent(poll + d * 0.5, d) / np.linalg.norm(d) + 0.5)
    m["head_length"] = float(np.linalg.norm(tip - poll))
    eye = np.array(A.EYE_POS)
    m["head_width_orbits"] = 2 * extent([0.0, eye[1], eye[2] + 0.02], [1, 0, 0])
    jc = np.array(A.S(A.hp(0.15, -0.05)))
    fr = np.array(A.HEAD_FR) * A.K
    fr = fr / np.linalg.norm(fr)
    hd = A.head()
    ts = np.arange(0, 0.4, 0.001)
    down = [t for t in ts if hd.f(*(jc - fr * t)[:, None])[0] > 0]
    m["head_depth_jowl"] = extent(jc, fr) + (down[0] if down else float("nan"))
    m["muzzle_width"] = 2 * extent(np.array(A.S(A.hp(0.50, 0.0))), [1, 0, 0])
    # neck: topline from the poll to the withers
    ys = np.linspace(A.S((0, -0.40, 0))[1], A.S((0, -1.10, 0))[1], 60)
    tl = np.array([[0.0, y, top_z(0.0, y)] for y in ys])
    m["neck_topline_length"] = float(np.sum(np.linalg.norm(np.diff(tl, axis=0), axis=1)))
    mid = np.array(A.S((0.0, -0.84, 1.265)))
    m["neck_width_mid"] = 2 * extent(mid, [1, 0, 0])
    # limbs: fore cannon girth at mid cannon, forearm girth, hoof width
    c = (np.array(A.J["carpus"]) + np.array(A.J["f_fetlock"])) * 0.5
    m["fore_cannon_girth"], _ = slice_perimeter(c[2], c[0], c[1] + 0.008)
    fa = np.array(A.J["elbow"]) * 0.45 + np.array(A.J["carpus"]) * 0.55
    m["forearm_girth"], _ = slice_perimeter(fa[2], fa[0], fa[1])
    fe = np.array(A.J["elbow"]) * 0.70 + np.array(A.J["carpus"]) * 0.30       # under the elbow, below the belly
    m["forearm_girth_under_elbow"], _ = slice_perimeter(fe[2], fe[0], fe[1] + 0.02, r=0.14)
    cw = []
    for zz in np.linspace(c[2] - 0.05, c[2] + 0.05, 5):
        cw.append(extent([c[0], c[1] + 0.008, zz], [1, 0, 0], 0.0005, 0.1) + extent([c[0], c[1] + 0.008, zz], [-1, 0, 0], 0.0005, 0.1))
    m["fore_cannon_width"] = float(np.mean(cw))
    # mouth corner (bit) from the poll joint (head bone head)
    m["mouth_from_poll"] = float(np.linalg.norm(np.array([0.0, A.BIT_Y, A.BIT_Z]) - np.array(A.bone_table()["head"][0])))
    _, rt, rb = A._hoof_dims(False)
    m["fore_hoof_width"] = 2 * rb[0] * A.HOOF_RENDER_K[0]
    m["fore_hoof_length"] = 2 * rb[1] * A.HOOF_RENDER_K[1] * 0.9
    ear_b = np.array(A.S(A.EAR_BASE))
    ear_t = np.array(A.S(A.EAR_TIP))
    face = A.Scaled(A.Warped(A._face_loft()), A.K)
    e = (ear_t - ear_b) / np.linalg.norm(ear_t - ear_b)
    ts = np.arange(0, 0.25, 0.001)
    out = [t for t in ts if face.f(*(ear_b + e * t)[:, None])[0] > 0]
    m["ear_length_visible"] = float(np.linalg.norm(ear_t - ear_b)) + 0.004 - (out[0] if out else 0.0)
    return {k: round(float(v), 3) for k, v in m.items()}, W


REF = {  # (low, high) in metres or as ratios to the withers height (keys ending _ratio)
    "body_length_ratio": (1.00, 1.10, "body length / height: square to slightly long"),
    "chest_depth_ratio": (0.45, 0.52, "chest depth / height: about half"),
    "leg_to_chest_ratio": (0.95, 1.15, "ground-to-girth / chest depth: about equal"),
    "head_length_ratio": (0.36, 0.42, "head length / height (a short head: 0.36-0.39)"),
    "neck_to_head_ratio": (1.1, 1.6, "neck topline / head length"),
    "croup_minus_withers": (-0.03, 0.03, "croup level with the withers (m)"),
    "fore_cannon_girth": (0.18, 0.23, "fore cannon girth (m): 7-9 in of bone for a heavy-boned 14.1"),
    "forearm_girth_under_elbow": (0.40, 0.50, "forearm girth just under the elbow (m), heavy bone"),
    "point_of_buttock_behind_hip_joint": (0.25, 0.30, "point of buttock behind the hip joint (m)"),
    "mouth_from_poll": (0.44, 0.50, "mouth corner (bit) from the poll joint (m)"),
    "fore_hoof_width": (0.11, 0.14, "fore hoof width (m)"),
    "chest_width_points_of_shoulder": (0.36, 0.48, "width across the points of the shoulder (m), broad-chested type"),
    "hip_width_points_of_hip": (0.44, 0.54, "width across the points of the hip (m)"),
    "head_width_orbits": (0.19, 0.23, "head width across the orbits (m)"),
    "head_depth_jowl": (0.24, 0.30, "head depth at the jowl (m)"),
    "ear_length_visible": (0.12, 0.16, "visible ear length (m)"),
}


def compare(m, W):
    vals = {
        "body_length_ratio": m["body_length"] / W,
        "chest_depth_ratio": m["chest_depth"] / W,
        "leg_to_chest_ratio": m["leg_length_ground_to_girth"] / m["chest_depth"],
        "head_length_ratio": m["head_length"] / W,
        "neck_to_head_ratio": m["neck_topline_length"] / m["head_length"],
        "croup_minus_withers": m["croup_height"] - m["withers_height"],
    }
    for k in REF:
        if k not in vals:
            vals[k] = m[k]
    rows = []
    for k, (lo, hi, note) in REF.items():
        v = vals[k]
        rows.append({"measure": k, "value": round(v, 3), "range": [lo, hi],
                     "verdict": "in range" if lo <= v <= hi else ("low" if v < lo else "high"), "note": note})
    return rows


if __name__ == "__main__":
    m, W = measure()
    rows = compare(m, W)
    for k, v in m.items():
        print("%-28s %.3f" % (k, v))
    print()
    for r in rows:
        print("%-22s %6.3f  %-12s %s" % (r["measure"], r["value"], r["verdict"], r["note"]))
    if "--json" in sys.argv:
        json.dump({"measures": m, "comparison": rows}, open(sys.argv[sys.argv.index("--json") + 1], "w"), indent=1)
