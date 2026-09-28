#!/usr/bin/env python3
"""Candidate stow points for the loadout survey (writes tools/loadout/candidates.json).

    python3 tools/loadout/make_candidates.py <raw_fit.json> [out=tools/loadout/candidates.json]

Reads the bind-pose surface map and item sizes that tools/loadout/measure_body_fit.gd
measured (section bind.outer_fine_nogear, items, draws) and places every candidate item as
one or two capsules just outside the outer surface of the legacy outfit (the old powder
horn and the shot pouch are left out of the map, so candidates may occupy the horn's place;
the pouch still counts in the Godot clearance check). The Godot script then carries each
capsule with its bone over the clips and reports surface clearance, limb sweeps, pairwise
gaps and right-hand reach.

Rig space: +Y up, character faces +Z, character right = -X. Angles around the torso axis:
0 front, 90 character right, 180 back, 270 left.

Every capsule: origin (bind skeleton space), axis (unit), length, radius, bone ("skin" =
the skin weights of the nearest outer-surface vertex; for belt items that is the belt band).
Items made of two capsules share an "item" id (their mutual gap is not a conflict).
"""

import json
import math
import sys

import numpy as np

GAP = 0.006          # clearance kept between an item and the outer surface at bind (m)
BELT_Y = 0.942       # centre of the baked belt band (0.922..0.962)
GRIP_Y = 0.914       # source pistol grip height at the grab frame (no-pack draw)


def load(path):
    with open(path) as f:
        return json.load(f)


class Surface:
    """Outer radius R(y, angle) of the legacy outfit without the old horn and pouch."""

    def __init__(self, fine):
        self.rows = {float(k): {int(a): float(r) for a, r in v.items()} for k, v in fine["rows"].items()}
        self.axis = {float(k): (float(v[0]), float(v[1])) for k, v in fine["axis"].items()}
        self.ys = sorted(self.rows)

    def ax(self, y):
        ys = sorted(self.axis)
        y = min(max(y, ys[0]), ys[-1])
        for i in range(len(ys) - 1):
            if ys[i] <= y <= ys[i + 1]:
                t = (y - ys[i]) / (ys[i + 1] - ys[i])
                a, b = self.axis[ys[i]], self.axis[ys[i + 1]]
                return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
        return self.axis[ys[-1]]

    def _row_r(self, row, a):
        a = a % 360.0
        keys = sorted(row)
        if not keys:
            return 0.0
        # nearest two bins (wrap)
        lo = max([k for k in keys if k <= a], default=keys[-1] - 360)
        hi = min([k for k in keys if k >= a], default=keys[0] + 360)
        rl = row[lo % 360] if lo % 360 in row else row[keys[-1]]
        rh = row[hi % 360] if hi % 360 in row else row[keys[0]]
        if hi == lo:
            return rl
        t = (a - lo) / (hi - lo)
        return rl + (rh - rl) * t

    def R(self, y, a, spread=10.0):
        """Max outer radius around (y, a) within +-spread deg and +-1.25 cm."""
        best = 0.0
        for yy in self.ys:
            if abs(yy - y) <= 0.0126:
                row = self.rows[yy]
                for da in np.arange(-spread, spread + 0.1, 5.0):
                    best = max(best, self._row_r(row, a + da))
        return best

    def point(self, y, a, r):
        cx, cz = self.ax(y)
        ar = math.radians(a)
        return np.array([cx - math.sin(ar) * r, y, cz + math.cos(ar) * r])

    def polar(self, p):
        cx, cz = self.ax(p[1])
        dx, dz = p[0] - cx, p[2] - cz
        return math.degrees(math.atan2(-dx, dz)) % 360.0, math.hypot(dx, dz)


def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def clear_line(S, p0, p1, rad, push, n=24, lo=0.45, hi=1.55):
    """Moves the segment p0-p1 along `push` (unit, horizontal outward) until every sample
    inside the mapped height range is at least R + rad + GAP from the torso axis."""
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    push = unit(push)
    for _ in range(400):
        worst = 0.0
        for t in np.linspace(0, 1, n):
            p = p0 + (p1 - p0) * t
            if not (lo <= p[1] <= hi):
                continue
            a, r = S.polar(p)
            need = S.R(p[1], a) + rad + GAP
            worst = max(worst, need - r)
        if worst <= 1e-4:
            break
        step = max(worst * 0.5, 0.001)
        p0 = p0 + push * step
        p1 = p1 + push * step
    return p0, p1


def clear_line2(S, p0, p1, rad, push, n=40, lo=0.45, hi=1.55):
    """Like clear_line, but the two ends move independently (the item tilts to lie on the
    body): each violation pushes the ends in proportion to how close they are to it."""
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    push = unit(push)
    for _ in range(600):
        worst, wt = 0.0, 0.5
        for t in np.linspace(0, 1, n):
            p = p0 + (p1 - p0) * t
            if not (lo <= p[1] <= hi):
                continue
            a, r = S.polar(p)
            need = S.R(p[1], a) + rad + GAP
            if need - r > worst:
                worst, wt = need - r, t
        if worst <= 1e-4:
            break
        step = max(worst, 0.001)
        p0 = p0 + push * step * (1 - wt) * 1.05
        p1 = p1 + push * step * wt * 1.05
    return p0, p1


def outward(S, y, a):
    return S.point(y, a, 1.0) - S.point(y, a, 0.0)


def hang(S, a, y_top, y_bot, rad, a_bot=None):
    """Item hanging along the body at angle a (optionally drifting to a_bot at the bottom):
    top and bottom points just outside the outer surface, the straight line between them
    clear of the surface everywhere in between."""
    a_bot = a if a_bot is None else a_bot
    rt = S.R(y_top, a) + rad + GAP
    rb = S.R(y_bot, a_bot) + rad + GAP
    for _ in range(200):
        worst, wt = 0.0, 0.5
        for t in np.linspace(0, 1, 21):
            y = y_top + (y_bot - y_top) * t
            aa = a + (a_bot - a) * t
            p = S.point(y_top, a, rt) + (S.point(y_bot, a_bot, rb) - S.point(y_top, a, rt)) * t
            ang, r = S.polar(p)
            need = S.R(y, ang) + rad + GAP
            if need - r > worst:
                worst, wt = need - r, t
        if worst <= 1e-4:
            break
        rt += worst * (1 - wt) + 0.0005
        rb += worst * wt + 0.0005
    return S.point(y_top, a, rt), S.point(y_bot, a_bot, rb)


def cap(cid, item, bone, p0, p1, rad, kind, gear, note="", grip=0.0, skip=("horn", "wood", "horn_tip")):
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    d = p1 - p0
    L = float(np.linalg.norm(d))
    return {"id": cid, "item": item, "kind": kind, "gear": gear, "bone": bone,
            "origin": [round(float(x), 4) for x in p0], "axis": [round(float(x), 5) for x in d / L],
            "length": round(L, 4), "radius": rad, "grip_at": grip, "skip_labels": list(skip), "note": note}


def pistol_hook(S, cid, a, bone, gear, note, grip_y=GRIP_Y, butt="rear"):
    """Belt-hook / holster pistol hanging muzzle down at angle a (source no-pack stow:
    barrel straight down, top of the lock forward-inward, butt to the rear)."""
    out = []
    # barrel: from the breech (grip height) to the muzzle 0.31 m lower
    top, bot = hang(S, a, grip_y + 0.02, grip_y - 0.31, 0.018)
    out.append(cap(cid + ":barrel", cid, bone, top, bot, 0.018, "pistol", gear, note, grip=0.06))
    # stock: from the grip up and back (butt 0.08 up, 0.09 behind along the tangent)
    toward_rear = 1.0 if (a % 360.0) < 180.0 else -1.0
    sgn = toward_rear if butt == "rear" else -toward_rear
    a_b = a + sgn * math.degrees(0.09 / max(S.R(grip_y + 0.08, a), 0.1))
    s0, s1 = hang(S, a, grip_y, grip_y + 0.08, 0.026, a_bot=a_b)
    out.append(cap(cid + ":stock", cid, bone, s0, s1, 0.026, "pistol", gear, note))
    return out


def pistol_tuck(S, cid, a, bone, gear, note, lean_deg, y0=None):
    """Pistol pushed through the belt / sash at the front: barrel down behind the band,
    leaning lean_deg from vertical in the frontal plane (+ = toward the character's left),
    butt and lock above the band leaning the other way."""
    out = []
    y0 = BELT_Y + 0.035 if y0 is None else y0
    top = S.point(y0, a, S.R(y0, a) + 0.016 + GAP)
    lr = math.radians(lean_deg)
    bot = top + np.array([math.sin(lr) * 0.30, -math.cos(lr) * 0.30, 0.0])
    top, bot = clear_line2(S, top, bot, 0.016, outward(S, y0, a))
    out.append(cap(cid + ":barrel", cid, bone, top, bot, 0.016, "pistol", gear, note, grip=0.0))
    s1 = top + np.array([-math.sin(lr) * 0.10, 0.07, 0.0])
    s0, s1 = clear_line2(S, top, s1, 0.026, outward(S, y0, a))
    out.append(cap(cid + ":stock", cid, bone, s0, s1, 0.026, "pistol", gear, note))
    return out


def tomahawk(S, cid, a, bone, gear, note):
    """Tomahawk hung through the belt (or a frog): haft down along the body, head resting on
    top of the band with the edge along the belt."""
    out = []
    top, bot = hang(S, a, BELT_Y + 0.05, BELT_Y + 0.05 - 0.46, 0.017)
    out.append(cap(cid + ":haft", cid, bone, top, bot, 0.017, "tomahawk", gear, note, grip=0.2))
    # head: 0.18 m along the belt tangent, centred on the haft top
    r = S.R(BELT_Y + 0.06, a) + 0.03 + GAP
    da = math.degrees(0.09 / r)
    h0, h1 = S.point(BELT_Y + 0.06, a - da, r), S.point(BELT_Y + 0.06, a + da, r)
    h0, h1 = clear_line(S, h0, h1, 0.03, S.point(BELT_Y + 0.06, a, 1.0) - S.point(BELT_Y + 0.06, a, 0.0))
    out.append(cap(cid + ":head", cid, bone, h0, h1, 0.03, "tomahawk", gear, note))
    return out


def tomahawk_edge(S, cid, a, bone, gear, note, edge_sign):
    """Tomahawk through the belt with the head off-centre along the belt: the edge (0.124 m)
    toward increasing angle (edge_sign +1) or decreasing angle (-1), the poll 0.05 m the
    other way."""
    out = []
    top, bot = hang(S, a, BELT_Y + 0.05, BELT_Y + 0.05 - 0.46, 0.017)
    out.append(cap(cid + ":haft", cid, bone, top, bot, 0.017, "tomahawk", gear, note, grip=0.2))
    r = S.R(BELT_Y + 0.06, a) + 0.03 + GAP
    de, dp = math.degrees(0.124 / r), math.degrees(0.05 / r)
    h0 = S.point(BELT_Y + 0.06, a - edge_sign * dp, r)
    h1 = S.point(BELT_Y + 0.06, a + edge_sign * de, r)
    h0, h1 = clear_line(S, h0, h1, 0.03, outward(S, BELT_Y + 0.06, a))
    out.append(cap(cid + ":head", cid, bone, h0, h1, 0.03, "tomahawk", gear, note))
    return out


def knife(S, cid, a, bone, gear, note):
    top, bot = hang(S, a, BELT_Y + 0.06, BELT_Y - 0.25, 0.022)
    return [cap(cid, cid, bone, top, bot, 0.022, "knife", gear, note, grip=0.1)]


def atlatl(S, cid, a, bone, gear, note, lean_deg=0.0):
    """Board tucked through the belt at the back, top 8 cm above the band, leaning lean_deg
    from vertical in the back plane (+ = bottom toward the character's left)."""
    y0 = BELT_Y + 0.08
    top = S.point(y0, a, S.R(y0, a) + 0.03 + GAP)
    lr = math.radians(lean_deg)
    bot = top + np.array([math.sin(lr) * 0.52, -math.cos(lr) * 0.52, 0.0])
    top, bot = clear_line2(S, top, bot, 0.03, outward(S, y0, a))
    return [cap(cid, cid, bone, top, bot, 0.03, "atlatl", gear, note, grip=0.0)]


def saber(S, cid, a_hilt, a_tip, bone, gear, note):
    """Hanger / cutlass in a scabbard from a frog: hilt forward and up at a_hilt, scabbard
    running down and back to the tip at a_tip."""
    hilt_top, hilt_bot = hang(S, a_hilt - 8, BELT_Y + 0.10, BELT_Y - 0.02, 0.03, a_bot=a_hilt)
    s0, s1 = hang(S, a_hilt, BELT_Y - 0.02, 0.38, 0.022, a_bot=a_tip)
    return [cap(cid + ":hilt", cid, bone, hilt_top, hilt_bot, 0.03, "saber", gear, note, grip=0.5),
            cap(cid + ":scabbard", cid, bone, s0, s1, 0.022, "saber", gear, note)]


def horn(S, cid, a_base, y_base, a_spout, y_spout, bone, note, strap):
    """Powder horn, 0.30 m along the curve, base plug diameter ~0.07, spout ~0.02: two
    capsules (base half r 0.032, spout half r 0.018)."""
    rmid = 0.028
    b, s = hang(S, a_base, y_base, y_spout, rmid, a_bot=a_spout) if y_base >= y_spout else \
        tuple(reversed(hang(S, a_spout, y_spout, y_base, rmid, a_bot=a_base)))
    # stretch / shrink to 0.30 m along the chord (a curved 0.30 m horn has a ~0.27 m chord)
    d = unit(s - b)
    mid = (b + s) / 2
    b, s = mid - d * 0.135, mid + d * 0.135
    m = (b + s) / 2
    b, m1 = clear_line(S, b, m, 0.032, S.point(m[1], S.polar(m)[0], 1.0) - S.point(m[1], S.polar(m)[0], 0.0))
    m2, s = clear_line(S, m1, s, 0.018, S.point(m[1], S.polar(m)[0], 1.0) - S.point(m[1], S.polar(m)[0], 0.0))
    return [cap(cid + ":base", cid, bone, b, m1, 0.032, "horn", "horn_strap", note + " " + strap),
            cap(cid + ":spout", cid, bone, m2, s, 0.018, "horn", "horn_strap", note + " " + strap)]


GRAB_Y = {"musket": 1.40, "bow": 1.17, "spear_pair": 1.45, "dart_bundle": 1.45, "quiver": None}


def back_line(S, cid, item, kind, top_xy, bot_xy, length, rad, bone, up_end_len, note, gear="back", z_extra=0.0):
    """Long item on the back along the line through top_xy -> bot_xy (x, y in the back plane),
    `up_end_len` of its length above top_xy's height; pushed back until it clears the back."""
    t = np.array([top_xy[0], top_xy[1], -0.05])
    b = np.array([bot_xy[0], bot_xy[1], -0.05])
    d = unit(t - b)
    p_top = t + d * up_end_len          # up_end_len of the item reaches above the top anchor
    p_bot = p_top - d * length
    p_top, p_bot = clear_line2(S, p_top, p_bot, rad, np.array([0.0, 0.0, -1.0]))
    if z_extra:
        p_top = p_top + np.array([0, 0, -z_extra])
        p_bot = p_bot + np.array([0, 0, -z_extra])
    # grab point: where the drawing hand takes it (musket: fore-end at the shoulder; bow: the
    # grip at mid length; spears / darts: the shaft behind the right shoulder; quiver: the nocks)
    gy = GRAB_Y.get(kind)
    if kind == "quiver":
        grip = 1.0
    elif gy is not None:
        grip = float(min(max((gy - p_bot[1]) / (p_top[1] - p_bot[1]), 0.0), 1.0))
    else:
        grip = 0.0
    return [cap(cid, item, bone, p_bot, p_top, rad, kind, gear, note, grip=round(grip, 3))]


def main():
    raw = load(sys.argv[1])
    out_path = "tools/loadout/candidates.json"
    for a in sys.argv[2:]:
        if a.startswith("out="):
            out_path = a[4:]
    S = Surface(raw["bind"]["outer_fine_nogear"])
    C = []
    # ---- pistols on a waist belt (hook / holster, source no-pack stow = barrel down, butt rear)
    for a in (95, 110, 125, 140):
        C += pistol_hook(S, "pistol_hook_R%d" % a, a, "skin", "waist_belt",
                         "belt hook, butt to the rear" + (" (source no-pack grab angle)" if a == 110 else ""))
    C += pistol_hook(S, "pistol_hook_R110_pelvis", 110, "pelvis", "waist_belt", "as R110, rigid on pelvis")
    C += pistol_hook(S, "pistol_hook_R110_spinea", 110, "spinea", "waist_belt", "as R110, rigid on spinea")
    C += pistol_hook(S, "pistol_hook_R110_root", 110, "root", "waist_belt", "as R110, rigid on root (like holster_pistol)")
    for a in (250, 265, 280):
        C += pistol_hook(S, "pistol_hook_L%d" % a, a, "skin", "waist_belt", "belt hook left side, cross draw, butt forward", butt="front")
    C += pistol_tuck(S, "pistol_tuck_F335", 335, "skin", "belt_or_sash", "tucked at the front left, cross draw: butt up-right, barrel down-left", 35)
    C += pistol_tuck(S, "pistol_tuck_F25", 25, "skin", "belt_or_sash", "tucked at the front right: butt up-right, barrel down-left across the belly", 35)
    C += pistol_tuck(S, "pistol_tuck_F350", 350, "skin", "belt_or_sash", "tucked left of the buckle, near vertical", 15)
    # ---- tomahawks, knife, atlatl, saber on the belt
    for a in (135, 150, 165, 180, 195, 210, 225):
        C += tomahawk(S, "tomahawk_%d" % a, a, "skin", "waist_belt", "through the belt, head on the band")
    for a in (285, 300, 315):
        C += knife(S, "knife_L%d" % a, a, "skin", "waist_belt", "sheath knife hung from the belt, handle up")
    for a, lean in ((180, 0), (195, 0), (210, 0), (165, 0), (200, 20)):
        C += atlatl(S, "atlatl_%d%s" % (a, "" if not lean else "_lean%d" % lean), a, "skin", "waist_belt",
                    "board tucked through the belt", lean)
    C += saber(S, "saber_L", 285, 225, "skin", "waist_belt_frog_or_baldric", "hanger in a frog, hilt forward")
    C += saber(S, "saber_L_steep", 275, 245, "skin", "waist_belt_frog_or_baldric", "hanger, steeper scabbard")
    # ---- more knife and tomahawk options
    for a in (230, 240):
        C += knife(S, "knife_L%d" % a, a, "skin", "waist_belt", "sheath knife behind the left hip (behind the shot pouch)")
    C += tomahawk_edge(S, "tomahawk_185_edgeL", 185, "skin", "waist_belt", "through the belt right of the spine, edge to the left, poll to the right", +1)
    C += tomahawk_edge(S, "tomahawk_200_edgeL", 200, "skin", "waist_belt", "through the belt left of the spine, edge to the left", +1)
    C += tomahawk_edge(S, "tomahawk_170_edgeR", 170, "skin", "waist_belt", "through the belt right of the spine, edge to the right", -1)
    # ---- sash (wider band 0.92..1.06): pistols tucked higher and more upright
    C += pistol_tuck(S, "sash_tuck_F340", 340, "skin", "sash", "tucked in a sash left of centre, cross draw, upright", 20, y0=1.07)
    C += pistol_tuck(S, "sash_tuck_F20", 20, "skin", "sash", "tucked in a sash right of centre, upright", 20, y0=1.07)
    C += pistol_tuck(S, "sash_tuck_L300", 300, "skin", "sash", "tucked in a sash at the left front hip, cross draw", 15, y0=1.07)
    # ---- sash: pistols pushed through at a steep diagonal (barrel along the band, muzzle
    # above the thigh crease), the classic brace-in-the-sash look
    C += pistol_tuck(S, "sash_diag_F345", 345, "skin", "sash", "through the sash left of centre, barrel 60 deg toward the left hip, butt up-right (cross draw)", 60, y0=1.05)
    C += pistol_tuck(S, "sash_diag_F15", 15, "skin", "sash", "through the sash right of centre, barrel 60 deg toward the left, butt up-right", 60, y0=1.05)
    C += pistol_tuck(S, "sash_diag_F330", 330, "skin", "sash", "through the sash at the left front, barrel 60 deg toward the left hip", 60, y0=1.05)
    C += pistol_tuck(S, "belt_diag_F340", 340, "skin", "waist_belt", "through the belt left of the buckle, barrel 55 deg toward the left hip (cross draw)", 55)
    # ---- pistol sling across the chest, pistols hung diagonally like bandolier holsters
    C += pistol_tuck(S, "sling_diag_chestL", 340, "skin", "pistol_sling", "hung on a sling across the chest, left, barrel down-left 50 deg", 50, y0=1.27)
    C += pistol_tuck(S, "sling_diag_chestR", 20, "skin", "pistol_sling", "hung on a sling across the chest, right, barrel down-left 50 deg", 50, y0=1.20)
    # ---- pistol sling high on the chest (a brace hung like a bandolier, Johnson 1724)
    C += pistol_hook(S, "pistol_sling_chestL_high", 340, "skin", "pistol_sling", "high on the left chest, butt up-right", grip_y=1.24, butt="front")
    C += pistol_hook(S, "pistol_sling_chestR_high", 20, "skin", "pistol_sling", "high on the right chest, butt up-left", grip_y=1.24, butt="front")
    # ---- pistol sling / baldric (over the right shoulder to the left hip; pistols on the left)
    for cid, a, y in (("pistol_sling_chestL", 330, 1.13), ("pistol_sling_ribsL", 305, 1.06), ("pistol_sling_hipL", 280, 0.99)):
        C += pistol_hook(S, cid, a, "skin", "pistol_sling", "hung from a shoulder sling, butt forward", grip_y=y, butt="front")
    # ---- powder horn options (the pistol takes the right hip)
    C += horn(S, "horn_backR_low", 185, 0.87, 125, 0.80, "pelvis", "behind the right hip below the belt, spout forward-down",
              "strap over the left shoulder")
    C += horn(S, "horn_backR_high", 170, 1.08, 120, 0.99, "spinec", "right back above the belt, spout forward-down (under the right arm, behind)",
              "strap over the left shoulder")
    C += horn(S, "horn_underarm_R", 140, 1.10, 75, 1.02, "spinec", "under the right arm (Knox 1757 literal)",
              "strap over the left shoulder")
    C += horn(S, "horn_hipL_over_pouch", 215, 1.00, 280, 0.95, "spinea", "left hip above the shot pouch, spout forward",
              "strap over the right shoulder (with the pouch)")
    C += horn(S, "horn_backL_high", 190, 1.08, 240, 0.99, "spinec", "left back above the belt, spout forward-down",
              "strap over the right shoulder")
    C += horn(S, "horn_chest_front", 330, 1.22, 20, 1.12, "spined", "high on the chest (short strap)", "strap over the right shoulder")
    C += horn(S, "horn_backR_top", 185, 1.15, 138, 1.07, "spinec", "behind the right arm above the pistol butt, base plug at the spine, spout forward-down",
              "strap over the left shoulder (shortened)")
    C += horn(S, "horn_backR_top2", 192, 1.16, 150, 1.05, "spinec", "behind the right arm above the pistol butt, spout ending 12 cm behind the side seam",
              "strap over the left shoulder (shortened)")
    C += horn(S, "horn_backR_top_flat", 190, 1.12, 140, 1.09, "spinec", "behind the right arm, nearly level, spout forward",
              "strap over the left shoulder (shortened)")
    C += horn(S, "horn_backR_under", 170, 0.90, 145, 0.76, "pelvis", "behind the right hip below the belt, spout down-back of the pistol",
              "strap over the left shoulder (lengthened)")
    C += horn(S, "horn_backL_top", 175, 1.15, 222, 1.07, "spinec", "behind the left arm above the belt, base plug at the spine, spout forward-down",
              "strap over the right shoulder (with the shot pouch)")
    # ---- back: long weapons and quiver (rigid on spinec; musket also on spineb / spined)
    items = raw["items"]
    musket_len = items["musket"]["size"][2]          # 1.588
    bow_len = items["bow"]["size"][1]                # 1.526
    spear_len = items["spear"]["size"][2]            # 1.80
    dart_len = items["atlatl_dart"]["size"][2]       # 1.65
    R_top, R_bot = (-0.13, 1.42), (0.13, 0.80)       # LONG_R: upper end behind the right shoulder
    L_top, L_bot = (0.13, 1.42), (-0.13, 0.80)       # LONG_L: upper end behind the left shoulder
    for bone in ("spinec", "spineb", "spined"):
        C += back_line(S, "musket_L_up_%s" % bone, "musket_L_up_%s" % bone, "musket", L_top, L_bot, musket_len, 0.035, bone,
                       musket_len - 0.62, "muzzle up over the left shoulder, butt behind the right hip (sling over the left shoulder)")
    C += back_line(S, "musket_R_up", "musket_R_up", "musket", R_top, R_bot, musket_len, 0.035, "spineb",
                   musket_len - 0.62, "muzzle up over the right shoulder, butt behind the left hip")
    C += back_line(S, "musket_L_up_steep", "musket_L_up_steep", "musket", (0.10, 1.42), (-0.06, 0.80), musket_len, 0.035,
                   "spineb", musket_len - 0.62, "15 deg from vertical, muzzle up over the left shoulder")
    # the source stow: grip at the grab point, muzzle down (Brown Bess: 1.30 m grip -> muzzle)
    src = next((e for e in raw["draws"] if e["clip"] == "actor_b-lg-stealth-stow^idle--arm-r" and e["kind"] == "stow_finish"), None)
    if src:
        f0 = src["frames"][0]
        g = np.array(f0["r_prop"])
        z = unit(f0["r_prop_zdir"])
        C.append(cap("musket_source_muzzle_down", "musket_source_muzzle_down", "spineb", g - z * 0.29, g + z * 1.298, 0.035,
                     "musket", "back", "source long-gun stow: grip at the grab point, barrel along the source prop +Z (muzzle down)"))
    bsrc = next((e for e in raw["draws"] if e["clip"] == "actor_b-p-bow-stow-grab^idle--part"), None)
    if bsrc:
        f0 = bsrc["frames"][0]
        g = np.array(f0["l_prop"])
        yv = unit(f0["l_prop_ydir"])
        p0, p1 = g - yv * 0.763, g + yv * 0.763
        p0, p1 = clear_line2(S, p0, p1, 0.02, np.array([0.0, 0.0, -1.0]))
        C.append(cap("bow_source", "bow_source", "spineb", p0, p1, 0.02, "bow", "back",
                      "source bow stow: grip at the grab point, stave along the source prop +Y, pushed clear of the back", grip=0.5))
    C += back_line(S, "bow_R", "bow_R", "bow", R_top, R_bot, bow_len, 0.02, "spineb", bow_len * 0.55, "stave across the back, top limb behind the right shoulder")
    C += back_line(S, "bow_L", "bow_L", "bow", L_top, L_bot, bow_len, 0.02, "spineb", bow_len * 0.55, "stave across the back, top limb behind the left shoulder")
    C += back_line(S, "spears_R", "spears_R", "spear_pair", R_top, R_bot, spear_len, 0.035, "spineb", 0.90, "two spears tied, points up behind the right shoulder")
    C += back_line(S, "spears_L", "spears_L", "spear_pair", L_top, L_bot, spear_len, 0.035, "spineb", 0.90, "two spears tied, points up behind the left shoulder")
    C += back_line(S, "darts_R", "darts_R", "dart_bundle", R_top, R_bot, dart_len, 0.035, "spineb", 0.80, "five darts tied, nocks up behind the right shoulder")
    C += back_line(S, "darts_L", "darts_L", "dart_bundle", L_top, L_bot, dart_len, 0.035, "spineb", 0.80, "five darts tied, nocks up behind the left shoulder")
    C += back_line(S, "quiver_R", "quiver_R", "quiver", (-0.15, 1.45), (-0.02, 0.90), 0.66, 0.05, "spineb", 0.12,
                   "back quiver, arrow nocks behind the right shoulder (source reach), bottom toward the small of the back")
    C += back_line(S, "quiver_R_outer", "quiver_R_outer", "quiver", (-0.15, 1.45), (-0.02, 0.90), 0.66, 0.05, "spineb", 0.12,
                   "as quiver_R, one long-weapon layer further out", z_extra=0.075)
    C += back_line(S, "musket_L_up_outer", "musket_L_up_outer", "musket", L_top, L_bot, musket_len, 0.035, "spineb",
                   musket_len - 0.62, "as musket_L_up, outside a crossing item", z_extra=0.075)
    # Attachment. Belt items ride on the pelvis (rigid): the belt band's own skin weights
    # blend pelvis and spine, and a single band vertex shears up to ~50 deg against the next
    # one in hip-twisting clips (run-bw-lt), which would slide items into each other. Sash
    # items (higher band) ride on spinea, back items on spineb (the source holster_long
    # parent; the best back fit in the survey).
    for c in C:
        if c["bone"] != "skin":
            continue
        top_y = max(c["origin"][1], c["origin"][1] + c["axis"][1] * c["length"])
        if c["gear"] in ("sash",) or (c["gear"] == "pistol_sling"):
            c["bone"] = "spinea" if c["gear"] == "sash" else "spined"
        else:
            c["bone"] = "pelvis"
    # two-anchor variants: the item lies on the body and follows the skin at two points
    # (a sling / belt holds it there) instead of one rigid bone
    extra = []
    for c in C:
        base = c["id"].split(":")[0]
        if c["bone"] not in ("pelvis", "spinec", "spineb") or c["length"] < 0.2:
            continue
        if c["kind"] not in ("pistol",) and base not in ("tomahawk_185_edgeL", "tomahawk_200_edgeL", "knife_L230", "knife_L285",
                                                          "atlatl_180", "atlatl_200_lean20", "saber_L", "quiver_R",
                                                          "musket_L_up_spinec", "bow_R", "spears_R"):
            continue
        if c["kind"] in ("musket", "bow", "spear_pair", "dart_bundle", "quiver"):
            o, ax, L = np.array(c["origin"]), np.array(c["axis"]), c["length"]
            ys = [o[1] + ax[1] * L * t for t in (0.0, 1.0)]
            def t_at(y):
                return float(min(max((y - ys[0]) / (ys[1] - ys[0]), 0.0), 1.0))
            ta, tb = sorted((t_at(0.97), t_at(1.30)))
            if tb - ta < 0.05:
                continue
            anchors = [round(ta, 3), round(tb, 3)]
        elif c["kind"] in ("pistol", "tomahawk", "knife", "atlatl", "saber") and c["length"] >= 0.25:
            anchors = [0.08, 0.7]
        else:
            continue
        e = dict(c)
        e["id"] = c["id"].replace(base, base + "~s2", 1)
        e["item"] = base + "~s2"
        e["bone"] = "skin2"
        e["anchors"] = anchors
        extra.append(e)
    C += extra
    for c in C:
        c["group"] = c["gear"]
    with open(out_path, "w") as f:
        json.dump({"note": "Generated by tools/loadout/make_candidates.py from the measured surface; rig space +Y up, faces +Z, right = -X.",
                   "gap_m": GAP, "points": C}, f, indent=1)
    print("wrote %s: %d capsules" % (out_path, len(C)))


if __name__ == "__main__":
    main()
