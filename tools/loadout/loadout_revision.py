#!/usr/bin/env python3
"""Loadout design, revisions 2-3: extra candidates and the checks the design review asked for.

Revision 3 (loadout_design.md changelog) adds: dz4_* (belt pistols lying on the hip, the surface map without
the old horn; front sash tucks; horns behind the right hip), dz5_* (pistols tilted along the belt; more
horns), y_* (yielding copies of the hanging items, measure_body_fit.gd "yield"), and step 2: revise() /
revise_after() (picks, handoff phases, the musket path, the bow, draw paths per preset with slung-item
yields, riding, prone, traversal policies, camera readability, the sling-all finish). build_loadout_data.py
build <raw> <pose dump> calls them and stores the results in data/loadout/design_fit_check.json revision.

Used by tools/loadout/build_loadout_data.py (step 1 adds these capsules to
tools/loadout/design_candidates.json; step 2 reads the survey run and its pose dump and writes
the results into data/loadout/design_fit_check.json and carry_gear.json).

    python3 tools/loadout/build_loadout_data.py candidates
    Godot --headless --path . -s tools/loadout/measure_body_fit.gd -- out=<scratch>/raw.json samples=6 \
        candidates=res://tools/loadout/design_candidates.json extra=1 pose_dump=<scratch>/dump.json \
        dump_torso=lg-stealth,bow-reload,switch-hands,bow-draw
    python3 tools/loadout/build_loadout_data.py build <scratch>/raw.json <scratch>/dump.json

Candidate groups written here (ids start with dz3_ / mir: / push):
  dz3_rhip   first pistol at the right hip, TWO-ANCHOR (the attach mode of the design), barrel hanging
             straight down, lock out (the left flat of the stock on the belt: belt hook), butt to the
             rear, at 71 / 80 / 90 / 100 / 110 / 125 deg (review item 1)
  dz3_horn   powder horn under the right arm, 95-110 deg, y 1.02-1.14, above the pistol butt (item 12)
  dz3_bow    bow on long_B with the string OUTWARD (review item 3, option 1): high (the survey line),
             lowered 15 cm, lowered 15 cm and 10 cm to the left; stave as four segments of the braced
             arc, string as its own capsule
  dz3_lhip   left-hip pistol hooked lock OUT, butt forward (the period cross-draw carry; item 10a)
  dz3_sash   pistol thrust through the front of a sash, front right (item 10c)
  dz3_longA  long_A musket with its butt 5 cm further inboard (item 9)
  mir:<id>   sagittal mirror of a placement, sampled only in the draw clips: the mirrored draws
             (left hip, right chest) are checked as the unmirrored clip against mirrored items
  push<d>:<id> / swing<a>:<id>  traversal policies (review item 11), sampled only in traversal clips

Frames: rig (skeleton) space at the bind pose null-add: +Y up, the character faces +Z, character
right = -X. Angles about the torso axis: 0 front, 90 right, 180 back, 270 left.

Provenance: rig, bind pose and clip measurements are Actor_B data.
"""
import json
import math
import os

import numpy as np

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DATA = os.path.join(ROOT, "data", "loadout")

BASE_CATS = ["idle", "walk", "run", "sprint", "crouch", "aim", "throw", "carry", "reload"]
TRAV_CATS = ["jump", "land", "vault", "climb", "ladder", "ledge"]
DRAW_CATS = ["draw", "draw_c"]
RIDE_CATS = ["ride", "mount", "prone"]
ALL_CATS = BASE_CATS + TRAV_CATS + DRAW_CATS + RIDE_CATS

PISTOL = {"muzzle": 0.31, "butt_back": 0.081, "butt_down": 0.089, "r_barrel": 0.018, "r_stock": 0.026}
BOW = {"half": 0.7632, "depth": 0.1859, "r": 0.02, "r_string": 0.006}
HORN = {"length": 0.30, "r_base": 0.032, "r_spout": 0.018}
SKIP_OLD_HORN = ["horn", "wood", "horn_tip"]


def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def load(name):
    return json.load(open(os.path.join(DATA, name)))


_BF = {}


def body_fit():
    if not _BF:
        _BF.update(load("body_fit.json"))
    return _BF


def joints():
    return {k: np.array(v, float) for k, v in body_fit()["bind_landmarks"]["joints"].items()}


def axis_at(y):
    """Torso axis (x, y, z) at height y from the bind joints pelvis .. neck (as measure_body_fit.gd)."""
    j = joints()
    pts = [j[b] for b in ("pelvis", "spinea", "spineb", "spinec", "spined", "neck")]
    if y <= pts[0][1]:
        return np.array([pts[0][0], y, pts[0][2]])
    for i in range(1, len(pts)):
        if y <= pts[i][1]:
            a, b = pts[i - 1], pts[i]
            u = (y - a[1]) / max(b[1] - a[1], 1e-6)
            p = a + (b - a) * u
            return np.array([p[0], y, p[2]])
    p = pts[-1]
    return np.array([p[0], y, p[2]])


def dir_of(a_deg):
    a = math.radians(a_deg)
    return np.array([-math.sin(a), 0.0, math.cos(a)])


def angle_of(p, centre=None):
    c = axis_at(p[1]) if centre is None else centre
    return (math.degrees(math.atan2(-(p[0] - c[0]), p[2] - c[2])) + 360.0) % 360.0


def outer_r(y, a_deg):
    """Legacy outer-surface radius about the torso axis at (y, angle): bilinear over the body-fit
    5 cm x 15 deg bins, nearest available bin where one is empty."""
    rows = body_fit()["outer_surface"]["rows"]
    ys = sorted(float(k) for k, v in rows.items() if v)

    def row_r(yk):
        r = rows["%.2f" % yk]
        angs = sorted(int(k) for k in r)
        a = a_deg % 360.0
        lo = max([x for x in angs if x <= a], default=None)
        hi = min([x for x in angs if x >= a], default=None)
        if lo is None:
            lo = angs[-1]
        if hi is None:
            hi = angs[0]
        rl, rh = r[str(lo)]["outer_r"], r[str(hi)]["outer_r"]
        span = (hi - lo) % 360.0
        if span == 0:
            return rl
        u = ((a - lo) % 360.0) / span
        return rl * (1 - u) + rh * u
    y = min(max(y, ys[0]), ys[-1])
    lo = max([v for v in ys if v <= y + 1e-9])
    hi = min([v for v in ys if v >= y - 1e-9])
    if hi == lo:
        return row_r(lo)
    u = (y - lo) / (hi - lo)
    return row_r(lo) * (1 - u) + row_r(hi) * u


def surface_point(a_deg, y, standoff):
    return axis_at(y) + dir_of(a_deg) * (outer_r(y, a_deg) + standoff)


# Bins of the body-fit outer-surface map whose outermost material is the OLD right-hip horn (it moves:
# change request) are replaced by the nearest bins above and below at the same angle (revision 3).
MOVING_LABELS = ("horn", "wood", "horn_tip")


def clean_outer_r(y, a_deg):
    """outer_r without the old horn: the legacy outer surface (coat, belt, straps, pouch) at (y, angle)."""
    rows = body_fit()["outer_surface"]["rows"]
    ys = sorted(float(k) for k, v in rows.items() if v)

    def bin_r(yk, ak):
        r = rows["%.2f" % yk].get(str(ak))
        if r and r.get("label") not in MOVING_LABELS:
            return r["outer_r"]
        lo = [v for v in ys if v < yk and rows["%.2f" % v].get(str(ak), {}).get("label") not in MOVING_LABELS + (None,)]
        hi = [v for v in ys if v > yk and rows["%.2f" % v].get(str(ak), {}).get("label") not in MOVING_LABELS + (None,)]
        if lo and hi:
            y0, y1 = max(lo), min(hi)
            r0, r1 = rows["%.2f" % y0][str(ak)]["outer_r"], rows["%.2f" % y1][str(ak)]["outer_r"]
            return r0 + (r1 - r0) * (yk - y0) / (y1 - y0)
        v = max(lo) if lo else min(hi)
        return rows["%.2f" % v][str(ak)]["outer_r"]

    def row_r(yk):
        r = rows["%.2f" % yk]
        angs = sorted(int(k) for k in r)
        a = a_deg % 360.0
        lo = max([x for x in angs if x <= a], default=angs[-1])
        hi = min([x for x in angs if x >= a], default=angs[0])
        rl, rh = bin_r(yk, lo), bin_r(yk, hi)
        span = (hi - lo) % 360.0
        return rl if span == 0 else rl + (rh - rl) * (((a - lo) % 360.0) / span)
    y = min(max(y, ys[0]), ys[-1])
    lo = max([v for v in ys if v <= y + 1e-9])
    hi = min([v for v in ys if v >= y - 1e-9])
    if hi == lo:
        return row_r(lo)
    u = (y - lo) / (hi - lo)
    return row_r(lo) * (1 - u) + row_r(hi) * u


def radial_clearance(p, r_item, standoff=0.005):
    """How far a point of an item (radius r_item) is outside the legacy surface (without the old horn), m."""
    c = axis_at(p[1])
    rad = math.hypot(p[0] - c[0], p[2] - c[2])
    return rad - (clean_outer_r(p[1], angle_of(p, c)) + r_item + standoff)


# --- revision 3: hooked pistols that LIE on the hip (barrel straight down in the side view, leaning out
# only as far as the hip / coat skirt under it pushes it) -------------------------------------------------

HOOK_Y = 0.955            # the grip at the source grab height (0.950); the hook on the lock plate sits on the belt


def hook_pistol_lean(a_deg, y=HOOK_Y, standoff=0.004, max_lean=40, tilt_deg=0.0):
    """Belt-hook pistol at angle a: grip on the belt surface (without the old horn), barrel hanging
    straight down (tilt_deg 0; positive tilts the muzzle toward the front along the belt, negative
    toward the back), leaning outward (in the plane of the belt normal) by the smallest angle that keeps
    the barrel on the surface under it; lock out (+X along the belt normal), so on the right side the top
    faces forward and the butt goes to the rear, on the left side the top faces the rear and the butt goes
    forward. Returns (4x4 bind transform, lean deg)."""
    n = dir_of(a_deg)
    fwd = unit(np.cross([0.0, 1.0, 0.0], n))
    if np.dot(fwd, [0.0, 0.0, 1.0]) < 0:
        fwd = -fwd
    tt = math.radians(tilt_deg)
    down = np.array([0.0, -math.cos(tt), 0.0]) + fwd * math.sin(tt)
    p = axis_at(y) + n * (clean_outer_r(y, a_deg) + PISTOL["r_stock"] + standoff)
    lean = max_lean
    for deg in range(0, max_lean + 1):
        t = math.radians(deg)
        d = down * math.cos(t) + n * math.sin(t)
        if all(radial_clearance(p + d * PISTOL["muzzle"] * u, PISTOL["r_barrel"]) >= 0.0 for u in (0.3, 0.45, 0.6, 0.75, 0.9, 1.0)):
            lean = deg
            break
    t = math.radians(lean)
    d = unit(down * math.cos(t) + n * math.sin(t))
    z = -d                                           # model -Z = barrel
    x = unit(n - z * np.dot(n, z))                   # lock out
    yv = np.cross(z, x)
    t4 = np.eye(4)
    t4[:3, :3] = np.column_stack([x, yv, z])
    t4[:3, 3] = p
    return t4, lean


RHIP4_ANGLES = [71, 80, 90, 100, 110, 125]
LHIP4_ANGLES = [270, 280, 290]


def sash_tuck(a_deg, y, tilt_deg, standoff=0.004):
    """Pistol thrust through the front of a sash (the period front tuck): grip at angle a, barrel
    across the belly toward the other side and down by tilt_deg from vertical, lock out (forward),
    pushed out until the whole barrel clears the belly. Rigid on the pelvis."""
    n = dir_of(a_deg)
    side = 1.0 if a_deg < 180 else -1.0              # right-front grip: the barrel runs to the left (+X)
    t = math.radians(tilt_deg)
    d = unit(np.array([side * math.sin(t), -math.cos(t), 0.0]))
    p = axis_at(y) + n * (clean_outer_r(y, a_deg) + PISTOL["r_stock"] + standoff)
    for _ in range(40):
        worst = min(radial_clearance(p + d * PISTOL["muzzle"] * u, PISTOL["r_barrel"]) for u in (0.2, 0.4, 0.6, 0.8, 1.0))
        if worst >= 0.0:
            break
        p = p + np.array([0.0, 0.0, 0.004])
    z = -d
    fwd = np.array([0.0, 0.0, 1.0])
    x = unit(fwd - z * np.dot(fwd, z))               # lock toward the front
    yv = np.cross(z, x)
    t4 = np.eye(4)
    t4[:3, :3] = np.column_stack([x, yv, z])
    t4[:3, 3] = p
    return t4


# horn candidates behind the right hip, above the pistol butt and behind the swing of the arm
HORN4_VARIANTS = {
    "B135": [(170.0, 1.13), (138.0, 1.10), (110.0, 1.06)],
    "B150": [(185.0, 1.10), (155.0, 1.08), (126.0, 1.04)],
    "B150lo": [(182.0, 1.05), (152.0, 1.03), (124.0, 0.99)],
}


def horn_caps4(hid, pts, group, cats, dump=True):
    base = axis_at(pts[0][1]) + dir_of(pts[0][0]) * (clean_outer_r(pts[0][1], pts[0][0]) + HORN["r_base"] + 0.004)
    mid = axis_at(pts[1][1]) + dir_of(pts[1][0]) * (clean_outer_r(pts[1][1], pts[1][0]) + (HORN["r_base"] + HORN["r_spout"]) * 0.5 + 0.004)
    tip = axis_at(pts[2][1]) + dir_of(pts[2][0]) * (clean_outer_r(pts[2][1], pts[2][0]) + HORN["r_spout"] + 0.004)
    return [cap("dz4_horn_%s:base" % hid, "horn", "spinec", base, mid, HORN["r_base"], group, cats, nopair=False, dump=dump),
            cap("dz4_horn_%s:spout" % hid, "horn", "spinec", mid, tip, HORN["r_spout"], group, cats, nopair=False, dump=dump)]


def revision3_candidates():
    main = BASE_CATS + TRAV_CATS + DRAW_CATS + RIDE_CATS
    caps = []
    for a in RHIP4_ANGLES:
        caps += pistol_caps("dz4_rhip_a%03d" % a, hook_pistol_lean(a)[0], "dz4_rhip", main)
    for a in LHIP4_ANGLES:
        caps += pistol_caps("dz4_lhip_x%03d" % a, hook_pistol_lean(a)[0], "dz4_lhip", main)
    for a, tilt in ((35, 55), (35, 70), (45, 62)):
        caps += pistol_caps("dz4_sash_a%02dt%02d" % (a, tilt), sash_tuck(a, 1.02, tilt), "dz4_sash", main, two_anchor=False)
    for hid, pts in HORN4_VARIANTS.items():
        caps += horn_caps4(hid, pts, "dz4_horn", main)
    # round 5: the straight-down hook puts the butt at the elbow (y 1.035 vs the idle elbow at 1.047);
    # tilting the muzzle toward the front (right hip) / the back (left hip) lowers the butt
    for a in RHIP5_ANGLES:
        for tl in RHIP5_TILTS:
            caps += pistol_caps("dz5_rhip_a%03dt%02d" % (a, tl), hook_pistol_lean(a, tilt_deg=tl)[0], "dz5_rhip", main)
    for a in LHIP5_ANGLES:
        for tl in LHIP5_TILTS:
            caps += pistol_caps("dz5_lhip_x%03dt%02d" % (a, -tl), hook_pistol_lean(a, tilt_deg=tl)[0], "dz5_lhip", main)
    for hid, pts in HORN5_VARIANTS.items():
        c2 = horn_caps4(hid, pts, "dz5_horn", main)
        for c in c2:
            c["id"] = c["id"].replace("dz4_", "dz5_")
        caps += c2
    extra = []
    extra += [mirror_cap(c, DRAW_CATS) for c in caps if c["group"] in ("dz4_rhip", "dz4_lhip", "dz5_rhip", "dz5_lhip")]
    for c in caps:
        extra.append(push_cap(c, 0.05, TRAV_CATS))
        extra.append(push_cap(c, 0.10, TRAV_CATS))
        if c["group"] in ("dz4_rhip", "dz4_lhip", "dz5_rhip", "dz5_lhip"):
            extra.append(swing_cap(c, 25, TRAV_CATS))
    return caps + extra


RHIP5_ANGLES = [71, 80, 90, 100, 110]
RHIP5_TILTS = [15, 30, 45]
LHIP5_ANGLES = [280, 290]
LHIP5_TILTS = [-15, -30, -45]
HORN5_VARIANTS = {
    "B165": [(195.0, 1.08), (166.0, 1.06), (138.0, 1.02)],
    "B150hi": [(185.0, 1.15), (155.0, 1.13), (126.0, 1.09)],
}


def cap(cid, kind, bone, a, b, r, group, cats=None, grip_at=0.0, nopair=True, dump=False, anchors=None, skip=None):
    a = np.asarray(a, float)
    b = np.asarray(b, float)
    L = float(np.linalg.norm(b - a))
    c = {"id": cid, "item": cid.split(":")[0], "kind": kind, "gear": group, "group": group, "bone": bone,
         "origin": [round(float(v), 4) for v in a], "axis": [round(float(v), 5) for v in (b - a) / L], "length": round(L, 4),
         "radius": r, "grip_at": grip_at, "skip_labels": skip if skip is not None else SKIP_OLD_HORN, "nopair": nopair}
    if cats is not None:
        c["cats"] = cats
    if dump:
        c["dump"] = True
    if anchors is not None:
        c["anchors"] = anchors
    return c


def cap_ends(c):
    a = np.array(c["origin"], float)
    return a, a + np.array(c["axis"], float) * c["length"]


# --- pistols -------------------------------------------------------------------------------------

def hook_pistol(a_deg, y, standoff=0.004, tilt_fwd_deg=0.0):
    """A pistol hung on the belt by a belt hook at angle a: barrel straight down (optionally swung
    tilt_fwd_deg about the belt normal, muzzle toward the front), the LEFT flat of the stock on the
    belt so the lock (+X) faces out along the belt normal. For a right-handed lock this fixes the
    top: on the right side of the body the top faces forward and the butt goes to the rear; on the
    left side the top faces the rear and the butt goes forward (the cross-draw carry).
    The grip (model origin) sits on the outer belt surface plus the stock radius and `standoff`."""
    n = dir_of(a_deg)
    fwd = unit(np.cross([0.0, 1.0, 0.0], n))        # belt tangent toward the front of the body
    if np.dot(fwd, [0.0, 0.0, 1.0]) < 0:
        fwd = -fwd
    p = axis_at(y) + n * (outer_r(y, a_deg) + PISTOL["r_stock"] + standoff)
    z = np.array([0.0, 1.0, 0.0])                    # -Z = barrel = down
    if tilt_fwd_deg:
        t = math.radians(tilt_fwd_deg)
        z = unit(np.array([0.0, math.cos(t), 0.0]) - fwd * math.sin(t))   # muzzle swings forward
    x = unit(n - z * np.dot(n, z))                   # lock out
    yv = np.cross(z, x)                              # right-handed: X x Y = Z
    t4 = np.eye(4)
    t4[:3, :3] = np.column_stack([x, yv, z])
    t4[:3, 3] = p
    return t4


def pistol_caps(cid, t, group, cats, two_anchor=True, dump=True, nopair=False):
    o = t[:3, 3]
    r = t[:3, :3]
    muzzle = o + r @ np.array([0.0, 0.0, -PISTOL["muzzle"]])
    butt = o + r @ np.array([0.0, -PISTOL["butt_down"], PISTOL["butt_back"]])
    bar = cap(cid + ":barrel", "pistol", "skin2" if two_anchor else "pelvis", o, muzzle, PISTOL["r_barrel"], group, cats,
              nopair=nopair, dump=dump, anchors=[0.08, 0.7] if two_anchor else None)
    stk = cap(cid + ":stock", "pistol", "pelvis", o, butt, PISTOL["r_stock"], group, cats, nopair=nopair, dump=dump)
    return [bar, stk]


RHIP_ANGLES = [71, 80, 90, 100, 110, 125]
RHIP_Y = 0.93


def rhip_transform(a_deg):
    return hook_pistol(a_deg, RHIP_Y)


# --- horn ------------------------------------------------------------------------------------------

HORN_VARIANTS = {
    # id: [(angle, y) base plug, (angle, y) bend, (angle, y) spout]; the horn lies along the right
    # flank under the arm, plug to the rear, spout forward and a little down (Knox 1757: "under the
    # right arm", strap over the left shoulder)
    # the 0.30 m horn (0.27 m chord) spans about 75 deg of the flank at r 0.19; the centre angle and
    # height are the review's range (95-110 deg, y 1.05-1.12)
    "R100": [(140.0, 1.15), (102.0, 1.10), (66.0, 1.05)],
    "R105": [(145.0, 1.16), (107.0, 1.12), (72.0, 1.07)],
    "R110": [(150.0, 1.14), (112.0, 1.10), (76.0, 1.05)],
}


def horn_caps(hid, pts, group, cats, dump=True):
    base = surface_point(pts[0][0], pts[0][1], HORN["r_base"] + 0.004)
    mid = surface_point(pts[1][0], pts[1][1], (HORN["r_base"] + HORN["r_spout"]) * 0.5 + 0.004)
    tip = surface_point(pts[2][0], pts[2][1], HORN["r_spout"] + 0.004)
    return [cap("dz3_horn_%s:base" % hid, "horn", "spinec", base, mid, HORN["r_base"], group, cats, nopair=False, dump=dump),
            cap("dz3_horn_%s:spout" % hid, "horn", "spinec", mid, tip, HORN["r_spout"], group, cats, nopair=False, dump=dump)]


# --- bow -------------------------------------------------------------------------------------------

def bow_points(t):
    """Braced bow in the model frame of t: stave arc handle -> tips at +Z depth, string tip-to-tip."""
    h, d = BOW["half"], BOW["depth"]
    pts = {}
    for name, s in (("up", 1.0), ("lo", -1.0)):
        for k, u in (("q", 0.5), ("tip", 1.0)):
            pts[name + "_" + k] = t[:3, :3] @ np.array([0.0, s * h * u, d * u * u]) + t[:3, 3]
    pts["handle"] = t[:3, 3].copy()
    return pts


def bow_caps(bid, t, group, cats, dump=True):
    p = bow_points(t)
    cs = [cap("%s:stave_lo_tip" % bid, "bow", "spineb", p["lo_tip"], p["lo_q"], BOW["r"], group, cats, nopair=False, dump=dump),
          cap("%s:stave_lo" % bid, "bow", "spineb", p["lo_q"], p["handle"], BOW["r"], group, cats, nopair=False, dump=dump),
          cap("%s:stave_up" % bid, "bow", "spineb", p["handle"], p["up_q"], BOW["r"], group, cats, nopair=False, dump=dump),
          cap("%s:stave_up_tip" % bid, "bow", "spineb", p["up_q"], p["up_tip"], BOW["r"], group, cats, nopair=False, dump=dump),
          cap("%s:string" % bid, "bow", "spineb", p["lo_tip"], p["up_tip"], BOW["r_string"], group, cats, nopair=False, dump=dump)]
    return cs


def bow_frame(a, b, string_out=True):
    """Bow model transform from the survey stave line a (lower tip) -> b (upper tip): handle at the
    midpoint, +Y up the line, +Z (string) outward (string_out) or toward the body."""
    ax = unit(b - a)
    mid = (a + b) * 0.5
    n = unit([mid[0] - axis_at(mid[1])[0], 0.0, mid[2] - axis_at(mid[1])[2]])
    z = n - ax * np.dot(n, ax)
    z = unit(z if string_out else -z)
    x = np.cross(ax, z)
    t = np.eye(4)
    t[:3, :3] = np.column_stack([x, ax, z])
    t[:3, 3] = mid
    return t


def bow_variants(cs):
    c = cs["placements"]["back.long_B.bow"]["capsules"]["bow_R"]
    a, b = np.array(c["from"]), np.array(c["to"])
    ax = unit(b - a)
    out = {}
    out["dz3_bow_hi"] = bow_frame(a, b)
    out["dz3_bow_lo15"] = bow_frame(a - ax * 0.15, b - ax * 0.15)
    sh = np.array([0.10, 0.0, 0.0])
    out["dz3_bow_lo15L10"] = bow_frame(a - ax * 0.15 + sh, b - ax * 0.15 + sh)
    return out


# --- other variants --------------------------------------------------------------------------------

def mirror_cap(c, cats):
    a, b = cap_ends(c)
    m = np.array([-1.0, 1.0, 1.0])
    e = cap("mir:" + c["id"], c.get("kind", ""), c["bone"], a * m, b * m, c["radius"], "mirror", cats, c.get("grip_at", 0.0),
            nopair=True, dump=False, anchors=c.get("anchors"), skip=c.get("skip_labels"))
    return e


def push_cap(c, d, cats):
    a, b = cap_ends(c)
    mid = (a + b) * 0.5
    ax = axis_at(mid[1])
    n = unit([mid[0] - ax[0], 0.0, mid[2] - ax[2]])
    return cap("push%02d:%s" % (round(d * 100), c["id"]), c.get("kind", ""), c["bone"], a + n * d, b + n * d, c["radius"], "push", cats,
               c.get("grip_at", 0.0), nopair=True, anchors=c.get("anchors"), skip=c.get("skip_labels"))


def swing_cap(c, deg, cats):
    """The capsule turned about its origin (the hook / upper contact) so the far end moves outward."""
    a, b = cap_ends(c)
    ax = axis_at(a[1])
    n = unit([a[0] - ax[0], 0.0, a[2] - ax[2]])
    v = b - a
    k = unit(np.cross(v, n))            # rotation axis: along the belt tangent
    th = math.radians(deg)
    kx = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    r = np.eye(3) + math.sin(th) * kx + (1 - math.cos(th)) * kx @ kx
    v2 = r @ v
    if np.dot(v2 - v, n) < 0:
        r = np.eye(3) - math.sin(th) * kx + (1 - math.cos(th)) * kx @ kx
        v2 = r @ v
    return cap("swing%02d:%s" % (deg, c["id"]), c.get("kind", ""), c["bone"], a, a + v2, c["radius"], "swing", cats,
               c.get("grip_at", 0.0), nopair=True, anchors=c.get("anchors"), skip=c.get("skip_labels"))


def revision_candidates(cs, finals):
    """All revision-2 capsules. `finals`: the current final-placement capsules (for mirrors / pushes)."""
    caps = []
    main = BASE_CATS + TRAV_CATS + DRAW_CATS + RIDE_CATS
    for a in RHIP_ANGLES:
        caps += pistol_caps("dz3_rhip_a%03d" % a, rhip_transform(a), "dz3_rhip", main)
    for hid, pts in HORN_VARIANTS.items():
        caps += horn_caps(hid, pts, "dz3_horn", main)
    for bid, t in bow_variants(cs).items():
        caps += bow_caps(bid, t, "dz3_bow", main)
    # left hip, lock out and butt forward (period cross-draw carry), two heights of the hook
    for a in (280, 295):
        caps += pistol_caps("dz3_lhip_x%03d" % a, hook_pistol(a, RHIP_Y), "dz3_lhip", main)
    # front of a sash, front right: thrust through the band, barrel down, lock out
    for a in (35, 50):
        caps += pistol_caps("dz3_sash_f%03d" % a, hook_pistol(a, 0.965, standoff=0.0), "dz3_sash", main)
    # long_A musket, butt 5 cm further inboard (turned about the upper contact at the shoulder)
    m = cs["placements"]["back.long_A.musket"]["capsules"]["musket_L_up_spineb"]
    a, b = np.array(m["from"]), np.array(m["to"])
    pivot = a + (b - a) * ((1.40 - a[1]) / (b[1] - a[1]))
    a2 = a + np.array([0.05, 0.0, 0.0])
    b2 = pivot + unit(pivot - a2) * np.linalg.norm(b - pivot)
    caps.append(cap("dz3_longA_in5", "musket", "spineb", a2, b2, 0.035, "dz3_longA", main, nopair=False, dump=True))
    # mirrors for the mirrored draws, sampled in the draw clips only
    mir_src = [c for c in finals] + [c for c in caps if c["group"] in ("dz3_rhip", "dz3_horn", "dz3_bow")]
    caps += [mirror_cap(c, DRAW_CATS) for c in mir_src]
    # traversal policies: push out 5 / 10 cm, swing belt items 25 deg about the hook
    trav_src = [c for c in finals] + [c for c in caps if c["group"] in ("dz3_rhip", "dz3_horn", "dz3_bow")]
    for c in trav_src:
        caps.append(push_cap(c, 0.05, TRAV_CATS))
        caps.append(push_cap(c, 0.10, TRAV_CATS))
        if c["bone"] in ("pelvis", "skin2") and c.get("kind") in ("pistol", "tomahawk", "atlatl", "knife", "saber"):
            caps.append(swing_cap(c, 25, TRAV_CATS))
    caps += revision3_candidates()
    return caps + yield_candidates(finals + caps)


# =====================================================================================================
# Step 2: checks on the survey run (raw) and its pose dump
# =====================================================================================================

LOCO_GROUPS = {"locomotion": ["idle", "walk", "run", "sprint"], "crouch": ["crouch"],
               "weapon_use": ["aim", "throw", "carry", "reload"],
               "traversal": ["jump", "land", "vault", "climb", "ladder", "ledge"]}


def m12(a):
    m = np.eye(4)
    m[:3, 0] = a[0:3]
    m[:3, 1] = a[3:6]
    m[:3, 2] = a[6:9]
    m[:3, 3] = a[9:12]
    return m


def rot_deg(ra, rb):
    r = ra.T @ rb
    return math.degrees(math.acos(max(-1.0, min(1.0, (np.trace(r) - 1.0) / 2.0))))


def axis_angle(k, deg):
    k = unit(k)
    th = math.radians(deg)
    kx = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + math.sin(th) * kx + (1 - math.cos(th)) * kx @ kx


def seg_seg(p1, q1, p2, q2):
    d1, d2, r = q1 - p1, q2 - p2, p1 - p2
    a, e, f = d1 @ d1, d2 @ d2, d2 @ r
    s = t = 0.0
    if a <= 1e-12 and e <= 1e-12:
        return float(np.linalg.norm(p1 - p2))
    if a <= 1e-12:
        t = min(max(f / e, 0.0), 1.0)
    else:
        c = d1 @ r
        if e <= 1e-12:
            s = min(max(-c / a, 0.0), 1.0)
        else:
            b = d1 @ d2
            den = a * e - b * b
            s = min(max((b * f - c * e) / den, 0.0), 1.0) if den > 1e-12 else 0.0
            t = (b * s + f) / e
            if t < 0.0:
                t, s = 0.0, min(max(-c / a, 0.0), 1.0)
            elif t > 1.0:
                t, s = 1.0, min(max((b - c) / a, 0.0), 1.0)
    return float(np.linalg.norm((p1 + d1 * s) - (p2 + d2 * t)))


def slerp_m(ra, rb, w):
    """Rotation matrix slerp (shortest arc) from ra to rb."""
    r = ra.T @ rb
    ang = math.acos(max(-1.0, min(1.0, (np.trace(r) - 1.0) / 2.0)))
    if ang < 1e-6:
        return ra.copy()
    k = np.array([r[2, 1] - r[1, 2], r[0, 2] - r[2, 0], r[1, 0] - r[0, 1]])
    if np.linalg.norm(k) < 1e-6:          # ~180 deg: the axis is numerically arbitrary
        w_, v = np.linalg.eigh((r + r.T) / 2.0)
        k = v[:, int(np.argmax(w_))]
    return ra @ axis_angle(k, math.degrees(ang) * w)


def cand_map(raw):
    return {c["id"]: c for c in raw["candidates"]}


def pair_gap(raw_c, a, b, grp="loco"):
    """Closest gap (m) between two measured capsules in ordinary play (loco) or traversal (trav)."""
    best = None
    for x, y in ((a, b), (b, a)):
        e = raw_c.get(x, {}).get("pairs", {}).get(y, {}).get(grp)
        if e is not None and (best is None or e[0] < best[0]):
            best = e
    return best


def item_pair_gap(raw_c, ids_a, ids_b, grp="loco"):
    best = None
    for a in ids_a:
        for b in ids_b:
            e = pair_gap(raw_c, a, b, grp)
            if e is not None and (best is None or e[0] < best[0]):
                best = e
    return best


def cm(v):
    return None if v is None else round(float(v) * 100.0, 1)


# --- dump access ---------------------------------------------------------------------------------

class Dump:
    def __init__(self, path):
        d = json.load(open(path))
        self.limb_r = d["limb_r"]
        self.bind = {k: m12(v) for k, v in d["bind_bones"].items()}
        self.samples = d["samples"]
        for s in self.samples:
            s["B"] = {k: m12(v) for k, v in s["bones"].items()}
            s["L"] = {k: (np.array(v[:3]), np.array(v[3:])) for k, v in s["limbs"].items()}
            s["C"] = {k: (np.array(v[:3]), np.array(v[3:])) for k, v in s["cands"].items()}
            if "torso" in s:
                t = np.array(s["torso"], float)
                s["TP"], s["TN"] = t[:, :3], t[:, 3:]

    def by_key(self, key):
        return sorted([s for s in self.samples if s["key"] == key], key=lambda s: s["t"])

    def by_cat(self, cat):
        return [s for s in self.samples if s["cat"] == cat]

    def carry(self, s, bone, t_bind):
        """A bind-space transform carried rigidly by `bone` into sample s."""
        return s["B"][bone] @ np.linalg.inv(self.bind[bone]) @ t_bind

    def to_bind(self, s, bone, p):
        """A posed point expressed in the bind pose of `bone` (bind-equivalent)."""
        m = self.bind[bone] @ np.linalg.inv(s["B"][bone])
        return (m @ np.append(p, 1.0))[:3]


def torso_sdist(s, q, k=5):
    d = np.linalg.norm(s["TP"] - q, axis=1)
    idx = np.argpartition(d, k)[:k]
    pd = np.sort(((q - s["TP"][idx]) * s["TN"][idx]).sum(axis=1))
    return float(pd[len(pd) // 2])


# --- A. first pistol at the right hip: two-anchor re-measure (review item 1) + handover (item 2) ------

def rhip_study(raw, fit_checks, src, dump):
    """src: {'stand': 4x4, 'crouch': 4x4} source grab model transforms (bind, pelvis-carried)."""
    C = cand_map(raw)
    rows = {}
    for a in RHIP_ANGLES:
        cid = "dz3_rhip_a%03d" % a
        ids = [cid + ":barrel", cid + ":stock"]
        if not all(i in C for i in ids):
            continue
        fc = fit_checks(raw, ids, "pistol")
        t = rhip_transform(a)
        e = {"angle_deg": a, "grip_bind": [round(float(v), 4) for v in t[:3, 3]], "fit": fc["groups"], "verdict": fc["verdict"],
             "worst_play_cm": fc["worst_play_cm"], "worst_clips": fc["worst_clips"][:3], "handover": {}}
        for st in ("stand", "crouch"):
            s = src[st]
            e["handover"][st] = {"grip_gap_cm": cm(np.linalg.norm(s[:3, 3] - t[:3, 3])),
                                 "rotation_deg": round(rot_deg(s[:3, :3], t[:3, :3]), 1)}
        # pre-contact pendulum: turn about the belt normal through the hook, at most 20 deg
        n = dir_of(a)
        best = (rot_deg(src["stand"][:3, :3], t[:3, :3]), 0)
        for deg in range(-20, 21):
            r = axis_angle(n, deg) @ t[:3, :3]
            ang = rot_deg(src["stand"][:3, :3], r)
            if ang < best[0] - 1e-9:
                best = (ang, deg)
        e["pendulum"] = {"swing_deg": best[1], "rotation_left_for_the_hand_deg": round(best[0], 1)}
        e["pairs_cm"] = {}
        for other, oids in (("long_A.musket", ["fin_long_A_musket"]), ("long_A.musket (butt 5 cm inboard)", ["dz3_longA_in5"]),
                            ("horn R100", ["dz3_horn_R100:base", "dz3_horn_R100:spout"]),
                            ("horn R105", ["dz3_horn_R105:base", "dz3_horn_R105:spout"]),
                            ("horn R110", ["dz3_horn_R110:base", "dz3_horn_R110:spout"]),
                            ("back.tomahawk", ["fin_back_tomahawk:haft", "fin_back_tomahawk:head"]),
                            ("quiver", ["fin_quiver_quiver"])):
            g = item_pair_gap(C, ids, oids)
            e["pairs_cm"][other] = cm(g[0]) if g else None
        rows[cid] = e
    ok = [r for r in rows.values() if r["verdict"] in ("clean", "contact")]
    pick = min(ok, key=lambda r: r["handover"]["stand"]["grip_gap_cm"]) if ok else \
        max(rows.values(), key=lambda r: r["worst_play_cm"])
    return {"candidates": rows, "pick": "dz3_rhip_a%03d" % pick["angle_deg"],
            "rule": "nearest to the source grab (standing grip gap) among the placements whose worst play clearance is at "
                    "worst contact (>= -3.5 cm); two-anchor, barrel hanging straight down, lock out, butt to the rear"}


def hand_motion(dump, key, prop="r_hand_prop_attachment"):
    """Peak linear (m/s) and angular (deg/s) speed of a prop bone over a clip, at the natural rate."""
    ss = dump.by_key(key)
    lin = ang = 0.0
    for a, b in zip(ss, ss[1:]):
        dt = b["t"] - a["t"]
        if dt <= 0:
            continue
        pa, pb = a["B"][prop], b["B"][prop]
        lin = max(lin, float(np.linalg.norm(pb[:3, 3] - pa[:3, 3])) / dt)
        ang = max(ang, rot_deg(pa[:3, :3], pb[:3, :3]) / dt)
    return {"peak_speed_mps": round(lin, 2), "peak_turn_dps": round(ang, 0), "samples": len(ss)}


def settle_plan(dump, pick_row, gap_m, draw_key, grab_key, draw_s=0.7, grab_s=0.2, quick=2.0, near_m=0.12):
    """In-hand settle and reach-IK decay for the first pistol, as phases of the draw clip."""
    hm = hand_motion(dump, draw_key)
    left = pick_row["pendulum"]["rotation_left_for_the_hand_deg"]
    out = {"hand_in_source_draw": hm, "rotation_in_hand_deg": left}
    # settle phase: long enough that the extra turn of the item in the hand stays under half the hand's
    # own peak turn rate and under 360 deg/s at the quick rate; at most 40 % of the draw
    for ph in [x / 100.0 for x in range(10, 41, 5)]:
        w = left / (ph * draw_s / quick)
        if w <= min(360.0, 0.5 * hm["peak_turn_dps"] * quick) or ph >= 0.40:
            out["settle_phase"] = [0.0, ph]
            out["settle_turn_rate_dps_quick"] = round(w, 0)
            break
    ik_ph = 0.35
    out["reach_ik_decay_phase"] = [0.0, ik_ph]
    out["reach_ik_speed_mps_quick"] = round(gap_m / (ik_ph * draw_s / quick), 2)
    out["hand_peak_speed_mps_quick"] = round(hm["peak_speed_mps"] * quick, 2)
    # when may the stowed pistol start its pendulum: the IK-corrected hand within near_m of the grip
    ss = dump.by_key(grab_key)
    if ss:
        grip = np.array(pick_row["grip_bind"])
        tt = None
        for s in ss:
            p = dump.to_bind(s, "pelvis", s["B"]["r_hand_prop_attachment"][:3, 3])
            w = min(max(s["t"] / grab_s, 0.0), 1.0)
            corr = p + w * (grip - np.array(SRC_GRIP_STAND))
            if np.linalg.norm(corr - grip) <= near_m and tt is None:
                tt = s["t"]
        out["pendulum_window_s_natural"] = [tt, grab_s] if tt is not None else None
        out["pendulum_rule"] = "the stowed pistol may swing only while the reaching hand is within %d cm of its grip" % round(near_m * 100)
    return out


SRC_GRIP_STAND = [-0.122, 0.950, 0.042]


# --- G. riding and prone (review item 7) ------------------------------------------------------------

# Saddle proxy in the rider's skeleton space: the origin of Actor_B's own rider clips is the saddle
# attach point and the rider faces +Z (horse design section 1: the pelvis sits 0.11 m above it; the
# dump shows 0.11-0.13 m). A 15-hand horse with a 1750s saddle: [name, a, b, radius].
SADDLE = [
    ["cantle", [-0.14, 0.06, -0.21], [0.14, 0.06, -0.21], 0.045],
    ["pommel", [-0.10, 0.06, 0.22], [0.10, 0.06, 0.22], 0.04],
    ["seat", [0.0, -0.06, 0.20], [0.0, -0.06, -0.20], 0.06],
    ["croup", [0.0, -0.36, -0.30], [0.0, -0.40, -0.95], 0.30],
    ["barrel", [0.0, -0.38, 0.45], [0.0, -0.38, -0.30], 0.27],
    ["neck", [0.0, -0.10, 0.50], [0.0, 0.30, 1.00], 0.15],
]


def saddle_clear(a, b, r):
    best = (9.0, "")
    for name, p, q, rr in SADDLE:
        d = seg_seg(a, b, np.array(p), np.array(q)) - r - rr
        if d < best[0]:
            best = (d, name)
    return best


def seated(s):
    p = s["B"]["pelvis"][:3, 3]
    return s["cat"] == "ride" or (s["cat"] == "mount" and p[1] < 0.3 and abs(p[0]) < 0.15)


def ground_of(s):
    return min(s["ground"][0], s["ground"][1] - 0.05)


def rotate_about(a, b, pivot, k, deg):
    r = axis_angle(k, deg)
    return pivot + r @ (a - pivot), pivot + r @ (b - pivot)


def ride_prone_study(dump, items, radius):
    """items: {placement key: [capsule ids]}; radius: {capsule id: m}. Per item the worst saddle /
    ground clearance of the stowed pose, and the per-state policies with their measured clearance."""
    seat = [s for s in dump.samples if s["cat"] in ("ride", "mount") and seated(s)]
    prone = dump.by_cat("prone")
    out = {"saddle_proxy": SADDLE, "calibration": {}, "items": {}, "samples": {"seated": len(seat), "prone": len(prone)}}
    # calibration: the rider's own legs against the proxy (they grip the horse: expect about 0 to -4 cm)
    for ln in ("r_thigh", "l_thigh", "r_shin", "l_shin"):
        w = min((saddle_clear(s["L"][ln][0], s["L"][ln][1], dump.limb_r[ln]) for s in seat), key=lambda x: x[0])
        out["calibration"][ln] = [cm(w[0]), w[1]]
    for key, ids in items.items():
        ids = [i for i in ids if seat and i in seat[0]["C"]]
        if not ids:
            continue
        e = {}
        w = (9.0, "", "")
        for s in seat:
            for i in ids:
                a, b = s["C"][i]
                d, part = saddle_clear(a, b, radius[i])
                if d < w[0]:
                    w = (d, part, s["key"])
        e["saddle_cm"] = [cm(w[0]), w[1], w[2]]
        g = (9.0, "")
        for s in prone:
            gr = ground_of(s)
            for i in ids:
                a, b = s["C"][i]
                d = min(a[1], b[1]) - radius[i] - gr
                if d < g[0]:
                    g = (d, s["key"] + "@%.2f" % s["t"])
        e["ground_cm"] = [cm(g[0]), g[1]]
        out["items"][key] = e
    return out


def ride_policy_long(dump, ids, radius, contact_bind, bone="spineb", need=0.02):
    """Long item: turn in the back plane about its upper (shoulder) contact until its lower end
    clears the saddle proxy by `need` in every seated sample. Returns (deg, clearance)."""
    seat = [s for s in dump.samples if s["cat"] in ("ride", "mount") and seated(s)]
    if not seat:
        return None
    best = None
    for sign in (1.0, -1.0):
        for deg in range(0, 71, 2):
            worst = 9.0
            for s in seat:
                m = s["B"][bone] @ np.linalg.inv(dump.bind[bone])
                pv = (m @ np.append(contact_bind, 1.0))[:3]
                ax = axis_at(contact_bind[1])
                n = unit([contact_bind[0] - ax[0], 0.0, contact_bind[2] - ax[2]])
                k = m[:3, :3] @ n
                for i in ids:
                    a, b = s["C"][i]
                    a2, b2 = rotate_about(a, b, pv, k, sign * deg)
                    worst = min(worst, saddle_clear(a2, b2, radius[i])[0])
            if worst >= need:
                if best is None or deg < best[0]:
                    best = (deg * sign, worst)
                break
    return {"turn_deg": best[0], "saddle_cm_after": cm(best[1])} if best else {"turn_deg": None}


def ride_policy_turn_up(dump, ids, radius, hook_bind, others, bone="pelvis"):
    """Belt item at the back: turned half a turn about the belt normal at the hook (haft up the back).
    Returns the saddle clearance and the closest other stowed item in the seated samples."""
    seat = [s for s in dump.samples if s["cat"] in ("ride", "mount") and seated(s)]
    worst, near = 9.0, (9.0, "")
    for s in seat:
        m = s["B"][bone] @ np.linalg.inv(dump.bind[bone])
        pv = (m @ np.append(hook_bind, 1.0))[:3]
        ax = axis_at(hook_bind[1])
        k = m[:3, :3] @ unit([hook_bind[0] - ax[0], 0.0, hook_bind[2] - ax[2]])
        for i in ids:
            a, b = s["C"][i]
            a2, b2 = rotate_about(a, b, pv, k, 180.0)
            worst = min(worst, saddle_clear(a2, b2, radius[i])[0])
            for o in others:
                if o in s["C"]:
                    oa, ob = s["C"][o]
                    d = seg_seg(a2, b2, oa, ob) - radius[i] - radius[o]
                    if d < near[0]:
                        near = (d, o)
    return {"saddle_cm_after": cm(worst), "closest_other": [cm(near[0]), near[1]]}


def prone_policy_swing_aside(dump, ids, radius, hook_bind, bone="spined", deg=75.0):
    """Chest pistol: turned about the vertical axis of its hook toward the side while lying flat."""
    out = 9.0
    for s in dump.by_cat("prone"):
        gr = ground_of(s)
        m = s["B"][bone] @ np.linalg.inv(dump.bind[bone])
        pv = (m @ np.append(hook_bind, 1.0))[:3]
        side = -1.0 if hook_bind[0] < 0 else 1.0
        k = m[:3, :3] @ np.array([0.0, 0.0, 1.0])        # about the body's forward axis: the barrel swings to the side
        for i in ids:
            a, b = s["C"][i]
            a2, b2 = rotate_about(a, b, pv, k, side * deg)
            out = min(out, min(a2[1], b2[1]) - radius[i] - gr)
    return {"turn_deg": deg, "ground_cm_after": cm(out)}


# --- I. draw paths through the other stowed items (review item 9) --------------------------------------

DRAW_CLIPS = {
    # draw set: ([clip keys without the category], drawing limbs, mirrored items)
    "pistol_no_pack": (["actor_b-p-stealth-idle^p-grab--arm-r--no-pack", "actor_b-p-stealth-draw-p^idle--arm-r--no-pack"], ["r_hand", "r_forearm"], False),
    "pistol_default": (["actor_b-p-crouch-idle^p-grab--arm-r", "actor_b-p-stealth-draw-p^idle--arm-r"], ["r_hand", "r_forearm"], False),
    "pistol_no_pack_mirrored": (["actor_b-p-stealth-idle^p-grab--arm-r--no-pack", "actor_b-p-stealth-draw-p^idle--arm-r--no-pack"], ["r_hand", "r_forearm"], True),
    "flashlight_left": (["actor_b-fist-ambi-flashlight-draw--part"], ["l_hand", "l_forearm"], False),
    "flashlight_right_mirrored": (["actor_b-fist-ambi-flashlight-draw--part"], ["l_hand", "l_forearm"], True),
    "throwable_back": (["actor_b-p-molotov-idle^draw--part", "actor_b-p-molotov-draw^idle--part"], ["r_hand", "r_forearm"], False),
    "long_gun_left": (["actor_b-lg-stealth-idle^grab--arm-r", "actor_b-lg-stealth-draw^idle--arm-r"], ["l_hand", "l_forearm", "r_hand", "r_forearm"], False),
    "bow_left": (["actor_b-p-bow-draw-idle^grab--part", "actor_b-p-bow-draw-grab^idle--part"], ["l_hand", "l_forearm"], False),
    "reach_right_shoulder": (["actor_b-p-bow-reload--part", "actor_b-p-crouch-bow-reload--part"], ["r_hand", "r_forearm"], False),
}


def draw_clearance(raw_c, draw_set, other_ids, stances=("draw", "draw_c")):
    """Worst clearance of the drawing hand / forearm against another stowed item over the grab and
    draw clips of a draw set (the holster replays the same poses). [cm, limb, clip key, t]."""
    if draw_set not in DRAW_CLIPS:
        return None
    clips, limbs, mir = DRAW_CLIPS[draw_set]
    best = None
    for oid in other_ids:
        c = raw_c.get(("mir:" + oid) if mir else oid)
        if c is None:
            continue
        for key, lm in c.get("by_clip_limb", {}).items():
            cat, clip = key.split(":", 1)
            if cat not in stances or clip not in clips:
                continue
            for ln in limbs:
                if ln in lm and (best is None or lm[ln][0] < best[0]):
                    best = [lm[ln][0], ln, key, lm[ln][1]]
    if best is None:
        return None
    best[0] = cm(best[0])
    return best


# --- K. traversal policies (review item 11) --------------------------------------------------------------

def trav_study(raw, fit_checks, items, kind_of):
    """Per item: the traversal worst case of the stowed pose and of each policy (push 5 / 10 cm,
    swing 25 deg about the hook for belt items), the chosen policy (the smallest that reaches contact,
    >= -3.5 cm) and the clips that still clip."""
    C = cand_map(raw)
    out = {}
    for key, ids in items.items():
        ids = [i for i in ids if i in C]
        if not ids:
            continue
        rows = {}
        for pol, pref in (("stowed", ""), ("push 5 cm", "push05:"), ("push 10 cm", "push10:"), ("swing 25 deg", "swing25:")):
            pids = [pref + i for i in ids]
            if not all(p in C for p in pids):
                # swing only exists for the capsules that hang from a hook
                pids = [p if p in C else i for p, i in zip(pids, ids)]
                if pids == ids and pol != "stowed":
                    continue
            wc = {}
            for p in pids:
                for clip, v in C[p]["by_clip"].items():
                    cat = raw["clips"].get(clip, {}).get("category")
                    if cat not in TRAV_CATS:
                        continue
                    w = wc.setdefault(clip, [9.0, "", 9.0])
                    if v[0] < w[0]:
                        w[0], w[1] = v[0], v[1]
                    w[2] = min(w[2], v[2])
            worst = min(wc.items(), key=lambda kv: min(kv[1][0], kv[1][2])) if wc else None
            still = sorted([[clip, cm(min(v[0], v[2])), v[1] if v[0] < v[2] else "surface"] for clip, v in wc.items()
                            if min(v[0], v[2]) < -0.035], key=lambda x: x[1])
            rows[pol] = {"worst_cm": cm(min(worst[1][0], worst[1][2])) if worst else None,
                         "worst_clip": worst[0] if worst else None, "clips_below_contact": still}
        order = ["stowed", "push 5 cm", "swing 25 deg", "push 10 cm"]
        choice = None
        for pol in order:
            if pol in rows and rows[pol]["worst_cm"] is not None and rows[pol]["worst_cm"] >= -3.5:
                choice = pol
                break
        if choice is None:
            choice = max((p for p in rows if rows[p]["worst_cm"] is not None), key=lambda p: rows[p]["worst_cm"])
        out[key] = {"policies": rows, "choice": choice, "residual_cm": rows[choice]["worst_cm"],
                    "still_clipping": rows[choice]["clips_below_contact"][:6]}
    return out


# --- H. camera readability (review item 8) ---------------------------------------------------------------

def camera_study(dump, items, radius, eye=2.3, crouch_drop=0.5, dist=3.6, fov=70.0, aspect=16.0 / 9.0):
    """Angular distance of each stowed item from the crosshair for the gameplay camera (player.gd:
    pivot eye_height above the feet, camera_distance behind, shoulder_offset 0, pitch 0), by the yaw of
    the camera relative to the body. Rig space: the body faces +Z, so the camera sits at -Z at yaw 0."""
    poses = {"stand idle": ("actor_b-p-stealth-idle", "idle"), "crouch idle": ("actor_b-p-crouch-idle", "crouch"),
             "rifle aim": ("actor_b-p-rifle-idle-aim", "aim"), "pistol aim": ("actor_b-p-pistol-aim-idle", "aim"),
             "bow aim": ("actor_b-p-bow-aim-idle", "aim")}
    out = {"camera": {"eye_height_m": eye, "crouch_eye_drop_m": crouch_drop, "distance_m": dist, "fov_v_deg": fov,
                      "note": "SOCOM-style camera of player.gd: centred behind, pivot and crosshair at the eye height"},
           "poses": {}}
    half_h = math.radians(fov / 2.0)
    half_w = math.atan(math.tan(half_h) * aspect)
    for pname, (clip, cat) in poses.items():
        ss = dump.by_key(clip)
        if not ss:
            continue
        s = ss[0]
        piv = np.array([0.0, eye - (crouch_drop if "crouch" in pname else 0.0), 0.0])
        e = {}
        for yaw in (0, 45, 90, 135, 180):
            yr = math.radians(yaw)
            cam = piv + np.array([-math.sin(yr) * -dist, 0.0, math.cos(yr) * -dist]) * np.array([1.0, 1.0, 1.0])
            cam = piv + np.array([dist * math.sin(yr), 0.0, -dist * math.cos(yr)])
            f = unit(piv - cam)
            right = unit(np.cross(f, [0.0, 1.0, 0.0]))
            up = np.cross(right, f)
            row = {}
            for key, ids in items.items():
                best = None
                for i in ids:
                    if i not in s["C"]:
                        continue
                    a, b = s["C"][i]
                    for u in np.linspace(0.0, 1.0, 9):
                        p = a + (b - a) * u
                        v = p - cam
                        x, y, z = v @ right, v @ up, v @ f
                        if z <= 0:
                            continue
                        ang = math.degrees(math.atan2(math.hypot(x, y), z))
                        if best is None or ang < best[0]:
                            best = (ang, round(float(p[1]), 2), round(math.degrees(math.atan2(x, z)), 1), round(math.degrees(math.atan2(y, z)), 1))
                if best:
                    row[key] = {"deg_from_crosshair": round(best[0], 1), "height_m": best[1], "screen_deg_xy": [best[2], best[3]]}
            e["yaw_%d" % yaw] = row
        out["poses"][pname] = e
    out["half_fov_deg"] = [round(math.degrees(half_w), 1), round(math.degrees(half_h), 1)]
    return out


# --- F. the musket handoff path (review item 6) ---------------------------------------------------------

FLIP = np.diag([-1.0, 1.0, -1.0])          # Basis(Vector3.UP, PI): the weapon offset on the prop bone
MUSKET_SPAN = (-1.298, 0.29)              # model z of the muzzle and the butt (grip at 0)


def musket_capsule(t):
    return t[:3, 3] + t[:3, :3] @ np.array([0, 0, MUSKET_SPAN[0]]), t[:3, 3] + t[:3, :3] @ np.array([0, 0, MUSKET_SPAN[1]])


def body_clear(s, a, b, r, dump, samples=13):
    """Clearance of a capsule against the posed torso subsample and the head capsule."""
    best = (9.0, "")
    if "TP" in s:
        for u in np.linspace(0.0, 1.0, samples):
            q = a + (b - a) * u
            d = torso_sdist(s, q) - r
            if d < best[0]:
                best = (d, "torso")
    ha, hb = s["L"]["head"]
    d = seg_seg(a, b, ha, hb) - r - dump.limb_r["head"]
    if d < best[0]:
        best = (d, "head")
    return best


def musket_path_study(dump, stow_bind, stance="draw", attach_s=0.37, quick=2.0):
    """The stowed musket (long_A, muzzle up) into the right-hand prop over the long-gun grab + draw.
    Two paths: 'offset slerp' (rev 1: the hand-relative offset slerps to the normal offset over 0.3 s)
    and 'world hold' (rev 2: keep the stowed orientation in world while the hand turns, carry the
    grip point with the hand, blend to the hand once the two orientations are within 45 deg, over
    the next 15 % of the draw)."""
    g = dump.by_key(stance + ":actor_b-lg-stealth-idle^grab--arm-r")
    d = dump.by_key(stance + ":actor_b-lg-stealth-draw^idle--arm-r")
    if not g or not d:
        return None
    sa = min(g, key=lambda s: abs(s["t"] - attach_s))
    prop0 = sa["B"]["r_hand_prop_attachment"]
    stow0 = dump.carry(sa, "spineb", stow_bind)
    off0 = np.linalg.inv(prop0) @ stow0
    ang0 = rot_deg(stow0[:3, :3], (prop0[:3, :3] @ FLIP))
    L = d[-1]["t"]
    # angle between the held (stowed) orientation and the hand-driven one over the draw
    curve = []
    for s in d:
        src = s["B"]["r_hand_prop_attachment"][:3, :3] @ FLIP
        curve.append([round(s["t"], 3), round(rot_deg(stow0[:3, :3], src), 1)])
    t_meet = next((t for t, a in curve if a <= 45.0), None)
    res = {"attach_turn_deg": round(ang0, 1), "angle_curve": curve, "draw_len_s": L,
           "meet_t_s": t_meet, "meet_phase": round(t_meet / L, 2) if t_meet is not None else None}
    paths = {}
    for name in ("offset slerp (rev 1)", "world hold (rev 2)"):
        worst = (9.0, "", 0.0)
        wmax = 0.0
        prev = None
        for s in d:
            prop = s["B"]["r_hand_prop_attachment"]
            src = prop.copy()
            src[:3, :3] = prop[:3, :3] @ FLIP
            if name.startswith("offset"):
                w = min(max(s["t"] / 0.3, 0.0), 1.0)
                w = w * w * (3 - 2 * w)
                off = np.eye(4)
                off[:3, :3] = slerp_m(off0[:3, :3], FLIP, w)
                off[:3, 3] = off0[:3, 3] * (1 - w)
                cur = prop @ off
            else:
                if t_meet is None or s["t"] < t_meet:
                    w = 0.0
                else:
                    w = min(max((s["t"] - t_meet) / (0.15 * L), 0.0), 1.0)
                    w = w * w * (3 - 2 * w)
                rot = slerp_m(stow0[:3, :3], src[:3, :3], w)
                held_p = prop[:3, 3] + (stow0[:3, 3] - prop0[:3, 3])
                cur = np.eye(4)
                cur[:3, :3] = rot
                cur[:3, 3] = held_p * (1 - w) + src[:3, 3] * w
            a, b = musket_capsule(cur)
            c = body_clear(s, a, b, 0.035, dump)
            if c[0] < worst[0]:
                worst = (c[0], c[1], s["t"])
            if prev is not None:
                dt = (s["t"] - prev[0]) / quick
                if dt > 0:
                    wmax = max(wmax, rot_deg(prev[1][:3, :3], cur[:3, :3]) / dt)
            prev = (s["t"], cur)
        paths[name] = {"worst_body_cm": cm(worst[0]), "against": worst[1], "at_t": worst[2], "peak_turn_dps_quick": round(wmax, 0)}
    # the source gun itself (for reference: the clip's own swing of the gun)
    worst = (9.0, "", 0.0)
    for s in d:
        prop = s["B"]["r_hand_prop_attachment"].copy()
        prop[:3, :3] = prop[:3, :3] @ FLIP
        a, b = musket_capsule(prop)
        c = body_clear(s, a, b, 0.035, dump)
        if c[0] < worst[0]:
            worst = (c[0], c[1], s["t"])
    paths["source gun in the hand (reference)"] = {"worst_body_cm": cm(worst[0]), "against": worst[1], "at_t": worst[2]}
    res["paths"] = paths
    return res


# =====================================================================================================
# Revision 3, step 2: picks, the studies the design review asked for, and the data they feed
# =====================================================================================================

RIDE_KEYS = ("ride", "mount")


def cand_defs():
    """The capsule definitions of tools/loadout/design_candidates.json by id."""
    d = json.load(open(os.path.join(ROOT, "tools", "loadout", "design_candidates.json")))
    return {c["id"]: c for c in d["points"]}


def ids_of(C, prefix):
    return sorted(i for i in C if i == prefix or i.startswith(prefix + ":"))


def pistol_row(raw, fit_checks, C, cid, t, src, n_axis):
    ids = ids_of(C, cid)
    fc = fit_checks(raw, ids, "pistol")
    e = {"id": cid, "grip_bind": [round(float(v), 4) for v in t[:3, 3]], "verdict": fc["verdict"],
         "worst_play_cm": fc["worst_play_cm"],
         "groups": {g: [v["surface_cm"], v["limb_cm"], v["limb"], v["limb_clip"]] for g, v in fc["groups"].items()},
         "worst_clips": fc["worst_clips"][:3], "handover": {}}
    for st in ("stand", "crouch"):
        s = src[st]
        e["handover"][st] = {"grip_gap_cm": cm(np.linalg.norm(s[:3, 3] - t[:3, 3])),
                             "rotation_deg": round(rot_deg(s[:3, :3], t[:3, :3]), 1)}
    best = (rot_deg(src["stand"][:3, :3], t[:3, :3]), 0)
    for deg in range(-20, 21):
        ang = rot_deg(src["stand"][:3, :3], axis_angle(n_axis, deg) @ t[:3, :3])
        if ang < best[0] - 1e-9:
            best = (ang, deg)
    e["pendulum"] = {"swing_deg": best[1], "rotation_left_for_the_hand_deg": round(best[0], 1)}
    return e


def pistol_hip_study(raw, fit_checks, src, side="R"):
    """Two-anchor hooked pistols at one hip: revision 2 (straight down, grip 0.93, horn in the surface),
    revision 3 (straight down, lying on the hip, grip 0.955) and revision 3b (muzzle tilted along the
    belt). Pick: nearest to the source grab (standing grip gap, then rotation) among the placements that
    are at worst contact; if none is, the smallest worst clearance among those within 10 cm of the source."""
    C = cand_map(raw)
    rows = {}
    if side == "R":
        fams = [("dz3", lambda a, tl: "dz3_rhip_a%03d" % a, RHIP_ANGLES, [0], lambda a, tl: rhip_transform(a)),
                ("dz4", lambda a, tl: "dz4_rhip_a%03d" % a, RHIP4_ANGLES, [0], lambda a, tl: hook_pistol_lean(a)[0]),
                ("dz5", lambda a, tl: "dz5_rhip_a%03dt%02d" % (a, tl), RHIP5_ANGLES, RHIP5_TILTS,
                 lambda a, tl: hook_pistol_lean(a, tilt_deg=tl)[0])]
    else:
        fams = [("dz4", lambda a, tl: "dz4_lhip_x%03d" % a, LHIP4_ANGLES, [0], lambda a, tl: hook_pistol_lean(a)[0]),
                ("dz5", lambda a, tl: "dz5_lhip_x%03dt%02d" % (a, -tl), LHIP5_ANGLES, LHIP5_TILTS,
                 lambda a, tl: hook_pistol_lean(a, tilt_deg=tl)[0])]
    for fam, name, angles, tilts, fn in fams:
        for a in angles:
            for tl in tilts:
                cid = name(a, tl)
                if not ids_of(C, cid):
                    continue
                t = fn(a, tl)
                e = pistol_row(raw, fit_checks, C, cid, t, src, dir_of(a))
                e["angle_deg"] = a
                e["tilt_deg"] = tl
                e["family"] = fam
                rows[cid] = e
    ok = [r for r in rows.values() if r["verdict"] in ("clean", "contact") and r["family"] != "dz3"]
    if ok:
        pick = min(ok, key=lambda r: (r["handover"]["stand"]["grip_gap_cm"], r["handover"]["stand"]["rotation_deg"]))
        rule = "nearest to the source grab (standing grip gap, then rotation) among the placements at worst contact"
    else:
        near = [r for r in rows.values() if r["handover"]["stand"]["grip_gap_cm"] <= 10.0 and r["family"] != "dz3"] or list(rows.values())
        pick = max(near, key=lambda r: r["worst_play_cm"])
        rule = ("no placement is at worst contact; best worst clearance among those within 10 cm of the source grab")
    return {"candidates": rows, "pick": pick["id"], "rule": rule}


def transform_of_pick(cid):
    """The bind transform of a dz4 / dz5 pistol id."""
    import re as _re
    m = _re.match(r"dz([345])_([rl])hip_[ax](\d+)(?:t(\d+))?$", cid)
    fam, side, a, tl = m.group(1), m.group(2), int(m.group(3)), int(m.group(4) or 0)
    if fam == "3":
        return rhip_transform(a)
    if side == "l":
        tl = -tl
    return hook_pistol_lean(a, tilt_deg=tl)[0]


# --- F. the musket handoff: an explicit world-space path (review item 6) ---------------------------------

def _ss(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def _muzzle_up_frame(target_rot, lean_out, lean_fwd):
    """Muzzle up (leaning out to the character's left and forward), rolled to be closest to target_rot."""
    z = -unit([lean_out, 1.0, lean_fwd])
    x0 = unit(np.cross([0.0, 0.0, 1.0], z))
    best = None
    for deg in range(0, 360, 3):
        x = axis_angle(z, deg) @ x0
        m = np.column_stack([x, np.cross(z, x), z])
        a = rot_deg(target_rot, m)
        if best is None or a < best[0]:
            best = (a, m)
    return best[1]


MUSKET_PATH = {"lift_phase": 0.13, "join_phase": 0.33, "tail_phase": 0.15, "hand_out_m": 0.30, "lean_out": -0.2, "lean_fwd": 0.9}


def musket_path_v3(dump, stow_bind, stance="draw", P=MUSKET_PATH, attach_s=0.37, quick=2.0):
    """The stowed long_A musket (muzzle up) drawn with the source long-gun grab + draw, along an explicit path:
      phase 0 .. lift: the left hand (IK offset growing to hand_out_m toward the character's left) lifts the
          gun off the back, which turns from its stowed orientation to muzzle-up-in-front V (fixed endpoints,
          no 180 deg ambiguity), rigid at the hand's grip point on the fore-end;
      lift .. join: V turns into the source gun's orientation at the join phase while the IK offset returns;
      join .. join + tail: the gun follows the source gun, the grip point slides from the fore-end hold to
          the source grip (the hand slides down the fore-end).
    Phases are fractions of the draw clip, so they scale with the rate. Returns the swept-capsule body
    clearance before and after the join, the peak turn rate at `quick`, and the source hand's own."""
    g = dump.by_key(stance + ":actor_b-lg-stealth-idle^grab--arm-r")
    d = dump.by_key(stance + ":actor_b-lg-stealth-draw^idle--arm-r")
    if not g or not d:
        return None
    L = d[-1]["t"]
    p1, tj = P["lift_phase"] * L, P["join_phase"] * L
    sa = min(g, key=lambda s: abs(s["t"] - attach_s))
    S0 = dump.carry(sa, "spineb", stow_bind)
    L0 = sa["B"]["l_hand_prop_attachment"][:3, 3]
    ax = S0[:3, :3] @ np.array([0.0, 0.0, 1.0])
    zh = float((L0 - S0[:3, 3]) @ ax)
    off0 = (S0[:3, 3] + ax * zh) - L0
    sj = min(d, key=lambda s: abs(s["t"] - tj))
    Hj = sj["B"]["r_hand_prop_attachment"].copy()
    Hj[:3, :3] = Hj[:3, :3] @ FLIP
    V = _muzzle_up_frame(Hj[:3, :3], P["lean_out"], P["lean_fwd"])
    out = np.array([P["hand_out_m"], 0.0, 0.0])
    before, after = (9.0, "", 0.0), (9.0, "", 0.0)
    wmax, prev, src_w, prev_src = 0.0, None, 0.0, None
    for s in d:
        t = s["t"]
        Lt = s["B"]["l_hand_prop_attachment"][:3, 3]
        H = s["B"]["r_hand_prop_attachment"].copy()
        H[:3, :3] = H[:3, :3] @ FLIP
        if t <= tj:
            if t <= p1:
                w = _ss(t / p1)
                rot = slerp_m(S0[:3, :3], V, w)
                off = off0 * (1 - w) + out * w
            else:
                w = _ss((t - p1) / (tj - p1))
                rot = slerp_m(V, Hj[:3, :3], w)
                off = out * (1 - w)
            cur = np.eye(4)
            cur[:3, :3] = rot
            cur[:3, 3] = Lt + off - rot @ np.array([0.0, 0.0, zh])
        else:
            gp_j = sj["B"]["l_hand_prop_attachment"][:3, 3] - Hj[:3, :3] @ np.array([0.0, 0.0, zh])
            w = _ss((t - tj) / (P["tail_phase"] * L))
            cur = H.copy()
            cur[:3, 3] = H[:3, 3] + (gp_j - Hj[:3, 3]) * (1 - w)
        a, b = musket_capsule(cur)
        c = body_clear(s, a, b, 0.035, dump)
        if t <= tj and c[0] < before[0]:
            before = (c[0], c[1], t)
        if t > tj and c[0] < after[0]:
            after = (c[0], c[1], t)
        if prev is not None and t > prev[0]:
            dt = (t - prev[0]) / quick
            wmax = max(wmax, rot_deg(prev[1][:3, :3], cur[:3, :3]) / dt)
            src_w = max(src_w, rot_deg(prev_src[:3, :3], H[:3, :3]) / dt)
        prev, prev_src = (t, cur), H
    ref = (9.0, "", 0.0)
    for s in d:
        H = s["B"]["r_hand_prop_attachment"].copy()
        H[:3, :3] = H[:3, :3] @ FLIP
        c = body_clear(s, *musket_capsule(H), 0.035, dump)
        if c[0] < ref[0]:
            ref = (c[0], c[1], s["t"])
    return {"params": P, "draw_len_s": L, "attach_turn_deg_rev1": round(rot_deg(S0[:3, :3], Hj[:3, :3] if False else
                                                                                   (sa["B"]["r_hand_prop_attachment"][:3, :3] @ FLIP)), 1),
            "turn_to_V_deg": round(rot_deg(S0[:3, :3], V), 1), "turn_V_to_source_deg": round(rot_deg(V, Hj[:3, :3]), 1),
            "hold_point_up_the_forend_m": round(zh, 3), "slide_to_grip_m": round(abs(zh), 3),
            "worst_before_join": {"cm": cm(before[0]), "against": before[1], "t": before[2]},
            "worst_after_join": {"cm": cm(after[0]), "against": after[1], "t": after[2]},
            "source_gun_itself": {"cm": cm(ref[0]), "against": ref[1], "t": ref[2]},
            "peak_turn_dps_quick": round(wmax), "source_gun_peak_turn_dps_quick": round(src_w)}


# --- revision 3c: items that hang from a hook or a strap YIELD to the limbs (measure_body_fit.gd "yield") --

YIELD_MAX_DEG = 30.0
YIELD_SOURCES = ["dz4_rhip_a090", "dz4_rhip_a100", "dz4_rhip_a110", "dz4_rhip_a125", "dz5_rhip_a071t30", "dz5_rhip_a080t30",
                 "dz5_rhip_a090t30", "dz5_rhip_a090t45", "dz5_rhip_a110t15", "dz4_rhip_a071", "dz4_rhip_a080", "fin_R_hip_pistol",
                 "dz4_lhip_x280", "dz5_lhip_x280t15", "dz5_lhip_x290t15", "fin_L_hip_pistol",
                 "dz4_horn_B150", "dz4_horn_B150lo", "dz5_horn_B150hi", "dz5_horn_B165", "dz3_horn_R105", "fin_horn",
                 "fin_back_tomahawk", "fin_back_tomahawk2", "fin_back_atlatl", "fin_back_left_knife", "fin_L_hip_saber",
                 "fin_chest_L_pistol", "fin_chest_R_pistol"]


def yield_candidates(src_caps):
    """Copies of the hanging items with "yield": they swing about their hook (the first capsule's origin)
    away from the limbs, at most YIELD_MAX_DEG; sampled in every category, paired, dumped. Ids: 'y:' + id."""
    main = BASE_CATS + TRAV_CATS + DRAW_CATS + RIDE_CATS
    out = []
    for c in src_caps:
        base = c["id"].split(":")[0]
        if base not in YIELD_SOURCES or c["id"].startswith(("push", "swing", "mir:")):
            continue
        e = dict(c)
        e["id"] = "y_" + c["id"]
        e["group"] = "yield"
        e["gear"] = "yield"
        e["yield"] = YIELD_MAX_DEG
        e["cats"] = main
        e["dump"] = True
        e["nopair"] = False
        out.append(e)
    return out


# --- C. the bow (review item 3) --------------------------------------------------------------------------

def bow_tips(t):
    h, d = BOW["half"], BOW["depth"]
    return t[:3, 3] + t[:3, :3] @ np.array([0.0, h, d]), t[:3, 3] + t[:3, :3] @ np.array([0.0, -h, d])


def string_ribbon_check(t_rev1):
    """Revision 1 drew the bow string as a ribbon: upper nock -> top of the right shoulder -> across the
    chest -> left hip -> round the left side -> lower nock. A string cannot stretch: the ribbon must not be
    longer than the braced string (+2 cm)."""
    j = joints()
    up, lo = bow_tips(t_rev1)
    shoulder = j["r_shoulder"] + np.array([0.0, 0.08, 0.0])
    sternum = axis_at(1.20) + dir_of(0.0) * (outer_r(1.20, 0.0) + 0.005)
    lhip_front = axis_at(0.95) + dir_of(315.0) * (clean_outer_r(0.95, 315.0) + 0.005)
    lhip_side = axis_at(0.88) + dir_of(265.0) * (clean_outer_r(0.88, 265.0) + 0.005)
    pts = [up, shoulder, sternum, lhip_front, lhip_side, lo]
    L = sum(float(np.linalg.norm(b - a)) for a, b in zip(pts, pts[1:]))
    chord = float(np.linalg.norm(up - lo))
    return {"anchors": [[round(float(v), 3) for v in p] for p in pts], "ribbon_m": round(L, 3), "braced_string_m": round(chord, 3),
            "excess_cm": round((L - chord) * 100, 1), "passes": L <= chord + 0.02,
            "rule": "ribbon length <= braced string length + 2 cm (a string does not stretch)"}


def bow_alt_study(dump, bow_t, bow_ids):
    """The all-source alternative (review item 3): the right hand takes the bow over the right shoulder
    (bow nock reach, actor_b-p-bow-reload--part, 0-0.5 s), then actor_b-p-switch-hands-knife forward
    passes it right -> left. Measured: the gap at the take, where on the stave the hand closes, the hand
    jump into the pass clip, the pass (exchange) mismatch against the bow's normal left-hand offset, and
    the swept clearance of the bow against the head and torso during the pass."""
    out = {}
    for st, reach_key, pass_key in (("stand", "draw:actor_b-p-bow-reload--part", "draw:actor_b-p-switch-hands-knife"),
                                    ("crouch", "draw_c:actor_b-p-crouch-bow-reload--part", "draw_c:actor_b-p-switch-hands-knife-crouch")):
        rs = [s for s in dump.by_key(reach_key) if s["t"] <= 0.5]
        ps = dump.by_key(pass_key)
        if not rs or not ps:
            continue
        best = None
        for s in rs:
            ha, hb = s["L"]["r_hand"]
            for i in bow_ids:
                if "string" in i or i not in s["C"]:
                    continue
                a, b = s["C"][i]
                d = seg_seg(ha, hb, a, b) - dump.limb_r["r_hand"] - BOW["r"]
                if best is None or d < best[0]:
                    best = (d, s, i)
        d, s_take, cap_id = best
        # contact point on the stave nearest the hand end, and its distance from the handle
        hand = s_take["B"]["r_hand_prop_attachment"][:3, 3]
        a, b = s_take["C"][cap_id]
        q = a + (b - a) * min(max(float((hand - a) @ (b - a)) / float((b - a) @ (b - a)), 0.0), 1.0)
        bow_now = dump.carry(s_take, "spineb", bow_t)
        slide = float(np.linalg.norm(q - bow_now[:3, 3]))
        # the bow rigid in the right hand from the take
        O = np.linalg.inv(s_take["B"]["r_hand_prop_attachment"]) @ bow_now
        jump = float(np.linalg.norm(ps[0]["B"]["r_hand_prop_attachment"][:3, 3] - hand))
        # exchange: the pass clip's frame where the two prop bones are closest
        sx = min(ps, key=lambda s: float(np.linalg.norm(s["B"]["r_hand_prop_attachment"][:3, 3] - s["B"]["l_hand_prop_attachment"][:3, 3])))
        bx = sx["B"]["r_hand_prop_attachment"] @ O
        lo = np.linalg.inv(sx["B"]["l_hand_prop_attachment"]) @ bx
        rot_left = rot_deg(lo[:3, :3], FLIP)
        grip_off = float(np.linalg.norm(lo[:3, 3]))
        worst = (9.0, "", 0.0)
        for s in ps:
            if s["t"] > sx["t"]:
                break
            bw = s["B"]["r_hand_prop_attachment"] @ O
            up, low = bow_tips(bw)
            for p0, p1 in ((low, bw[:3, 3]), (bw[:3, 3], up)):
                c = body_clear(s, p0, p1, BOW["r"], dump) if "TP" in s else (9.0, "")
                if c[0] < worst[0]:
                    worst = (c[0], c[1], s["t"])
        out[st] = {"take_gap_cm": cm(max(d, 0.0)), "take_t_s": s_take["t"], "stave_segment": cap_id.split(":")[-1],
                   "hand_to_handle_m": round(slide, 3), "hand_jump_into_pass_m": round(jump, 3),
                   "exchange_t_s": sx["t"], "exchange_rotation_left_deg": round(rot_left, 1), "exchange_grip_offset_m": round(grip_off, 3),
                   "swept_body_cm": cm(worst[0]), "swept_against": worst[1], "swept_t_s": worst[2]}
    return out


# --- I. draw paths through the other stowed items (review item 9) ---------------------------------------

DRAW_DUMP = {
    # draw set: ([(grab key, len), (draw key, len)] stand, same crouch, limbs, IK carrier bone or None)
    "pistol_no_pack": ([("actor_b-p-stealth-idle^p-grab--arm-r--no-pack", 0.2), ("actor_b-p-stealth-draw-p^idle--arm-r--no-pack", 0.7)],
                       ["r_hand", "r_forearm"], "pelvis"),
    "pistol_default": ([("actor_b-p-crouch-idle^p-grab--arm-r", 0.2), ("actor_b-p-stealth-draw-p^idle--arm-r", 0.7)],
                       ["r_hand", "r_forearm"], "pelvis"),
    "throwable_back": ([("actor_b-p-molotov-idle^draw--part", 0.5), ("actor_b-p-molotov-draw^idle--part", 0.5)],
                       ["r_hand", "r_forearm"], "pelvis"),
    "long_gun_left": ([("actor_b-lg-stealth-idle^grab--arm-r", 0.4), ("actor_b-lg-stealth-draw^idle--arm-r", 0.9)],
                      ["l_hand", "l_forearm", "r_hand", "r_forearm"], None),
    "bow_left": ([("actor_b-p-bow-draw-idle^grab--part", 0.3), ("actor_b-p-bow-draw-grab^idle--part", 0.9)],
                 ["l_hand", "l_forearm"], "spineb"),
    "reach_right_shoulder": ([("actor_b-p-bow-reload--part", 0.5)], ["r_hand", "r_forearm"], None),
    "flashlight_left": ([("actor_b-fist-ambi-flashlight-draw--part", 1.0)], ["l_hand", "l_forearm"], "spined"),
}


def draw_path_clearance(dump, draw_set, other_ids, ik_bind=None, ik_bone=None, stance="draw", ik_decay=0.35):
    """Worst clearance (cm) of the drawing hand / forearm against other stowed capsules over the grab and draw
    clips of a draw set, with the reach-IK offset applied (weight 0 -> 1 over the grab, 1 -> 0 over the first
    ik_decay of the draw). Returns [cm, limb, other id, clip, t] or None."""
    spec = DRAW_DUMP.get(draw_set)
    if spec is None:
        return None
    clips, limbs, bone = spec
    worst = None
    for ci, (key, L) in enumerate(clips):
        if draw_set == "reach_right_shoulder" and stance == "draw_c":
            key = "actor_b-p-crouch-bow-reload--part"
        for s in dump.by_key(stance + ":" + key):
            if s["t"] > L + 1e-6:
                continue
            off = np.zeros(3)
            if ik_bind is not None and ik_bone:
                if len(clips) > 1 and ci == 0:
                    w = s["t"] / L
                else:
                    w = max(0.0, 1.0 - s["t"] / (ik_decay * L)) if len(clips) > 1 else 1.0
                off = s["B"][ik_bone][:3, :3] @ np.linalg.inv(dump.bind[ik_bone][:3, :3]) @ np.asarray(ik_bind) * w
            for ln in limbs:
                la, lb = s["L"][ln]
                if ln.endswith("hand"):
                    la, lb = la + off, lb + off
                else:
                    lb = lb + off
                for oid in other_ids:
                    if oid not in s["C"]:
                        continue
                    a, b = s["C"][oid]
                    d = seg_seg(la, lb, a, b) - dump.limb_r[ln] - RADII.get(oid, 0.03)
                    if worst is None or d < worst[0]:
                        worst = [d, ln, oid, key, s["t"]]
    if worst:
        worst[0] = cm(worst[0])
    return worst


RADII = {}


# --- G. riding and prone policies (review item 7) -----------------------------------------------------------

def seated_samples(dump):
    return [s for s in dump.samples if s["cat"] in RIDE_KEYS and seated(s)]


def ride_hip_pistol(dump, ids, radius):
    """Hip pistols while seated: the two-anchor pistol follows the horizontal thigh; the policy turns it
    about its hook so that the barrel lies along the thigh toward the knee, clear of the saddle and the
    thigh. Returns the seated clearance to the saddle and to the thigh, stowed and after the policy."""
    seat = seated_samples(dump)
    res = {}
    for name, deg in (("stowed", 0.0), ("along the thigh", None)):
        worst_s, worst_t = 9.0, 9.0
        for s in seat:
            a, b = s["C"][ids[0]]
            if deg is None:
                side = "r" if a[0] < 0 else "l"
                ka, kb = s["L"][side + "_thigh"]
                # swing the barrel into the direction of the thigh (hip -> knee), out by the thigh radius
                dthigh = unit(kb - ka)
                out = unit(np.cross(dthigh, [0.0, 1.0, 0.0])) * (1 if side == "l" else -1)
                b = a + unit(dthigh + out * 0.35) * float(np.linalg.norm(b - a))
            worst_s = min(worst_s, saddle_clear(a, b, radius[ids[0]])[0])
            for ln in ("r_thigh", "l_thigh"):
                la, lb = s["L"][ln]
                worst_t = min(worst_t, seg_seg(a, b, la, lb) - radius[ids[0]] - dump.limb_r[ln])
        res[name] = {"saddle_cm": cm(worst_s), "thigh_cm": cm(worst_t)}
    return res


# --- K. holster_finish of sling-all (review item 17) ---------------------------------------------------------

def holster_finish_check(dump):
    """Where the empty hand ends if the graph's standing holster_finish (= the draw clip played forward) is
    used for 'hands free', against the stow clip."""
    def end_pos(key, prop):
        ss = dump.by_key(key)
        return ss[-1]["B"][prop][:3, 3] if ss else None
    out = {}
    idle = dump.by_key("actor_b-p-stealth-idle")
    cidle = dump.by_key("actor_b-p-crouch-idle")
    for name, key, prop, ref in (("pistol stand: draw clip forward", "draw:actor_b-p-stealth-draw-p^idle--arm-r--no-pack",
                                  "r_hand_prop_attachment", idle),
                                 ("pistol crouch: stow clip", "draw_c:actor_b-p-stealth-stow-p^idle--arm-r--no-pack", "r_hand_prop_attachment", cidle),
                                 ("bow stand: draw clip forward", "draw:actor_b-p-bow-draw-grab^idle--part", "l_hand_prop_attachment", idle),
                                 ("musket: lg stow clip", "draw:actor_b-lg-stealth-stow^idle--arm-r", "r_hand_prop_attachment", idle)):
        p = end_pos(key, prop)
        if p is None or not ref:
            continue
        r = ref[0]["B"][prop][:3, 3]
        pel = dump.by_key(key)[-1]["B"]["pelvis"][:3, 3]
        out[name] = {"hand_end_from_idle_hand_cm": cm(np.linalg.norm(p - r)), "hand_end_above_pelvis_m": round(float(p[1] - pel[1]), 3),
                     "hand_end_in_front_of_pelvis_m": round(float(p[2] - pel[2]), 3)}
    return out


# --- revision 3: fit split (arm swing vs the rest) and the final picks -------------------------------------

PLAY_CATS = ["idle", "walk", "run", "sprint", "crouch", "aim", "throw", "carry", "reload"]
ARM_SWING = ("r_forearm", "r_hand", "l_forearm", "l_hand")


def fit_split(raw, ids):
    """Worst play clearance (cm) split into the body surface, the forearm / hand swing, and every other limb
    (upper arms, thighs, shins, head), with the clips below contact (-3.5 cm)."""
    C = cand_map(raw)
    clip_cat = {k: v["category"] for k, v in raw["clips"].items()}
    surf, arm, other = [9.0, ""], [9.0, "", ""], [9.0, "", ""]
    for i in ids:
        c = C.get(i)
        if c is None:
            continue
        for k, v in c["limbs"].items():
            cat, ln = k.split("|")
            if cat not in PLAY_CATS:
                continue
            tgt = arm if ln in ARM_SWING else other
            if v[0] < tgt[0]:
                tgt[:] = [v[0], ln, v[1]]
        for k, v in c["surface"].items():
            if k in PLAY_CATS and v[0] < surf[0]:
                surf[:] = [v[0], v[2]]
    below = {}
    for i in ids:
        for clip, v in C.get(i, {}).get("by_clip", {}).items():
            if clip_cat.get(clip) in PLAY_CATS and min(v[0], v[2]) < -0.035:
                w = min(v[0], v[2])
                if clip not in below or w < below[clip][0]:
                    below[clip] = [w, v[1] if v[0] < v[2] else "surface"]
    return {"surface_cm": cm(surf[0]), "surface_clip": surf[1], "arm_swing_cm": cm(arm[0]), "arm_limb": arm[1], "arm_clip": arm[2],
            "other_limbs_cm": cm(other[0]), "other_limb": other[1], "other_clip": other[2],
            "clips_below_contact": sorted([[k, cm(v[0]), v[1]] for k, v in below.items()], key=lambda x: x[1])}


def pick_right_hip(raw, fit_checks, src, rev1_t=None):
    """First pistol (user rule: on the belt at the right hip, where the horn is and the source draw reaches).
    Candidates: rev 2 straight-down (dz3), rev 3 lying on the hip (dz4), tilted along the belt (dz5), and the
    yielding copies (y_*) of the best of them. Rule: among the placements whose surface and non-forearm limb
    clearances are at worst contact (>= -3.5 cm) in play, the nearest to the source grab (standing grip gap,
    then rotation). The forearm / hand swing over the hip is reported separately: no hook point on the side
    of the hip avoids it (every candidate from 71 to 125 deg: -4.8 to -7.5 cm)."""
    base = pistol_hip_study(raw, fit_checks, src, "R")
    rows = base["candidates"]
    C = cand_map(raw)
    for cid in YIELD_SOURCES:
        if not cid.startswith(("dz4_rhip", "dz5_rhip", "fin_R_hip")) or not ids_of(C, "y_" + cid):
            continue
        if cid.startswith("fin_"):
            continue
        t = transform_of_pick(cid)
        import re as _re
        a = int(_re.search(r"_a(\d+)", cid).group(1))
        e = pistol_row(raw, fit_checks, C, "y_" + cid, t, src, dir_of(a))
        e["angle_deg"] = a
        e["tilt_deg"] = int(_re.search(r"t(\d+)$", cid).group(1)) if _re.search(r"t(\d+)$", cid) else 0
        e["family"] = "yield"
        rows["y_" + cid] = e
    if rev1_t is not None and ids_of(C, "y_fin_R_hip_pistol"):
        e = pistol_row(raw, fit_checks, C, "y_fin_R_hip_pistol", rev1_t, src, dir_of(125.0))
        e.update({"angle_deg": 125, "tilt_deg": None, "family": "rev1 + yield"})
        rows["y_fin_R_hip_pistol"] = e
    for cid, e in rows.items():
        e["split"] = fit_split(raw, ids_of(C, cid))
    ok = [e for e in rows.values() if e["split"]["surface_cm"] >= -3.5 and e["split"]["other_limbs_cm"] >= -3.5]
    pick = min(ok, key=lambda e: (e["handover"]["stand"]["grip_gap_cm"], e["handover"]["stand"]["rotation_deg"]))
    return {"candidates": rows, "pick": pick["id"],
            "rule": "among placements with surface and non-forearm limbs at worst contact (>= -3.5 cm) in play: nearest to the "
                    "source grab (standing grip gap, then rotation); the forearm / hand swing is reported separately",
            "eligible": sorted(e["id"] for e in ok)}


# --- the revision: final placements and every study, called by build_loadout_data.py build ----------------

def _defs_caps(D, prefix):
    return [dict(D[i]) for i in ids_of(D, prefix)]


def revise(F, raw, dump, h, rest, cs, fit_checks, stow_model):
    """Revision 3 of the slot map (loadout_design.md changelog). Mutates F (the rev 1 final placements) and
    returns the report stored in design_fit_check.json 'revision'."""
    D = cand_defs()
    C = cand_map(raw)
    rep = {"note": "Loadout design revision 3 (review of 2026-09-24): tools/loadout/loadout_revision.py; run %s" %
                   raw.get("meta", {}).get("tool", "")}
    src = {st: stow_model(h, "pistol_right_hip", st, "pelvis", rest)[0] for st in ("stand", "crouch")}
    srcL = {st: stow_model(h, "pistol_left_hip_mirrored", st, "pelvis", rest)[0] for st in ("stand", "crouch")}
    rev1 = {k: dict(v) for k, v in F.items()}

    # 1. first pistol: right hip
    rh = pick_right_hip(raw, fit_checks, src, rev1_t=F["R_hip.pistol"]["t"])
    pid = rh["pick"]
    base_id = pid[2:] if pid.startswith("y_") else pid
    t = transform_of_pick(base_id) if not base_id.startswith("fin_") else F["R_hip.pistol"]["t"]
    row = rh["candidates"][pid]
    rh["settle"] = settle_plan(dump, row, row["handover"]["stand"]["grip_gap_cm"] / 100.0,
                               "draw:actor_b-p-stealth-draw-p^idle--arm-r--no-pack", "draw:actor_b-p-stealth-idle^p-grab--arm-r--no-pack")
    # crouch: the same pendulum, then the in-hand turn over the smallest draw phase whose turn rate stays under the
    # source hand's own peak turn at the quick rate
    n_ax = dir_of(row["angle_deg"])
    best = (rot_deg(src["crouch"][:3, :3], t[:3, :3]), 0)
    for deg in range(-20, 21):
        a = rot_deg(src["crouch"][:3, :3], axis_angle(n_ax, deg) @ t[:3, :3])
        if a < best[0] - 1e-9:
            best = (a, deg)
    peak = rh["settle"]["hand_in_source_draw"]["peak_turn_dps"] * 2.0
    ph = next((x / 10.0 for x in range(3, 8) if best[0] / (x / 10.0 * 0.7 / 2.0) <= peak), 0.7)
    rh["settle_crouch"] = {"rotation_deg": round(rot_deg(src["crouch"][:3, :3], t[:3, :3]), 1), "pendulum_deg": best[1],
                           "rotation_left_for_the_hand_deg": round(best[0], 1), "settle_phase": [0.0, ph],
                           "settle_turn_rate_dps_quick": round(best[0] / (ph * 0.7 / 2.0)), "hand_peak_turn_dps_quick": peak}
    rep["r_hip"] = rh
    F["R_hip.pistol"].update({"t": t, "caps": _defs_caps(D, pid), "attach": "two_anchor", "yield_deg": YIELD_MAX_DEG,
                              "note": "Hooked on the belt at the right side seam (%d deg, where the old horn sat and the source draw reaches): "
                                      "belt hook on the left flat of the stock, so the lock faces out; the barrel hangs down the hip with "
                                      "the muzzle tilted %d deg toward the front along the belt, the butt lies back along the belt. "
                                      "Two-anchor, and it yields to the limbs (swings on its hook, at most %d deg)." %
                                      (row["angle_deg"], row["tilt_deg"] or 0, YIELD_MAX_DEG),
                              "basis": "revision 3 pick %s (%s)" % (pid, rh["rule"])})
    F["R_hip.pistol"].pop("grab_pose", None)
    F["R_hip.pistol"].pop("grab_caps", None)

    # 2. left hip: lock-out butt-forward (period cross-draw) measured; rev 1 (lock in, mirrored left-hand draw) kept
    lh = pistol_hip_study(raw, fit_checks, srcL, "L")
    for cid in ("y_dz4_lhip_x280", "y_dz5_lhip_x280t15", "y_dz5_lhip_x290t15"):
        if ids_of(C, cid):
            import re as _re
            a = int(_re.search(r"_x(\d+)", cid).group(1))
            tl = -int(_re.search(r"t(\d+)$", cid).group(1)) if _re.search(r"t(\d+)$", cid) else 0
            e = pistol_row(raw, fit_checks, C, cid, hook_pistol_lean(a, tilt_deg=tl)[0], srcL, dir_of(a))
            e.update({"angle_deg": a, "tilt_deg": tl, "family": "yield"})
            lh["candidates"][cid] = e
    e = pistol_row(raw, fit_checks, C, "y_fin_L_hip_pistol", F["L_hip.pistol"]["t"], srcL, dir_of(280.0))
    e.update({"angle_deg": 280, "tilt_deg": None, "family": "rev1 (lock in, butt back) + yield"})
    lh["candidates"]["y_fin_L_hip_pistol"] = e
    for cid, e in lh["candidates"].items():
        e["split"] = fit_split(raw, ids_of(C, cid))
    lh["decision"] = ("v1 keeps the rev 1 carry (thrust through the belt, lock IN, butt back: the mirror of the right-hip carry, drawn "
                      "by the mirrored left-hand draw; grade C). The period carry (hooked, lock OUT, butt FORWARD for a right-hand cross "
                      "draw; dz5_lhip_x280t15) turns the pistol 160-178 deg from the mirrored source grab, so it needs the Actor_A "
                      "hol-- cross draw after retargeting; its fit is measured here for that upgrade.")
    rep["l_hip"] = lh
    F["L_hip.pistol"].update({"caps": _defs_caps(D, "y_fin_L_hip_pistol"), "yield_deg": YIELD_MAX_DEG})

    # 3. hanging belt and sling items yield (tomahawks, atlatl, knife, saber, chest pistols)
    for key, cid in (("back.tomahawk", "fin_back_tomahawk"), ("back_2.tomahawk", "fin_back_tomahawk2"), ("back.atlatl", "fin_back_atlatl"),
                     ("back_left.knife", "fin_back_left_knife"), ("L_hip.saber", "fin_L_hip_saber"),
                     ("chest_L.pistol", "fin_chest_L_pistol"), ("chest_R.pistol", "fin_chest_R_pistol")):
        if key in F and ids_of(C, "y_" + cid):
            rep.setdefault("yield", {})[key] = {"stowed": fit_split(raw, ids_of(C, cid)), "yielding": fit_split(raw, ids_of(C, "y_" + cid)),
                                               "verdict_stowed": fit_checks(raw, ids_of(C, cid), key.split(".")[1])["verdict"],
                                               "verdict_yielding": fit_checks(raw, ids_of(C, "y_" + cid), key.split(".")[1])["verdict"]}
            if key.startswith("chest_"):
                # the yield solver of the survey ignores the head: a chest pistol swings its butt into the chin
                # (-5.9 cm in 30 clips). Chest pistols keep the rev 1 crouch / aim nudge instead (2.3).
                rep["yield"][key]["used"] = False
                continue
            rep["yield"][key]["used"] = True
            F[key].update({"caps": _defs_caps(D, "y_" + cid), "yield_deg": YIELD_MAX_DEG})

    # 4. sash front tuck (review item 10c): measured, rejected
    rep["sash_front"] = {cid: {"verdict": fit_checks(raw, ids_of(C, cid), "pistol")["verdict"], **fit_split(raw, ids_of(C, cid))}
                         for cid in sorted({i.split(":")[0] for i in C if i.startswith(("dz3_sash", "dz4_sash"))})}

    # 5. powder horn
    horns = {}
    for cid in ("dz3_horn_R100", "dz3_horn_R105", "dz3_horn_R110", "y_dz3_horn_R105", "dz4_horn_B135", "dz4_horn_B150", "y_dz4_horn_B150",
                "dz4_horn_B150lo", "y_dz4_horn_B150lo", "y_dz5_horn_B150hi", "y_dz5_horn_B165", "fin_horn", "y_fin_horn"):
        if not ids_of(C, cid):
            continue
        fc = fit_checks(raw, ids_of(C, cid), "horn")
        e = {"verdict": fc["verdict"], "worst_play_cm": fc["worst_play_cm"], **fit_split(raw, ids_of(C, cid)), "pairs_cm": {}}
        for other, oid in (("R_hip pistol (pick)", pid), ("long_A musket", "fin_long_A_musket"), ("quiver", "fin_quiver_quiver"),
                           ("back tomahawk", "y_fin_back_tomahawk"), ("long_B bow", "dz3_bow_hi")):
            g = item_pair_gap(C, ids_of(C, cid), ids_of(C, oid))
            e["pairs_cm"][other] = cm(g[0]) if g else None
        horns[cid] = e
    ok = [k for k, v in horns.items() if v["verdict"] in ("clean", "contact") and v["pairs_cm"]["R_hip pistol (pick)"] is not None
          and v["pairs_cm"]["R_hip pistol (pick)"] >= 0.0 and k != "y_fin_horn" and k != "fin_horn"]
    hpick = max(ok, key=lambda k: horns[k]["worst_play_cm"]) if ok else "y_fin_horn"
    rep["horn"] = {"candidates": horns, "pick": hpick,
                   "rule": "a right-side place (not the rev 1 mid-back one) at worst contact in play and clear of the right-hip pistol; "
                           "best worst clearance"}
    F["horn.powder_horn"].update({"caps": _defs_caps(D, hpick), "yield_deg": YIELD_MAX_DEG,
                                  "note": "Behind the right hip above the pistol butt, plug toward the spine, spout forward to the right "
                                          "side; on its strap over the left shoulder it swings clear of the arm (yield). Knox 1757 hangs it "
                                          "under the right arm: that place clips the swinging upper arm (%s cm even when yielding)." %
                                          horns.get("y_dz3_horn_R105", {}).get("other_limbs_cm"),
                                  "basis": "revision 3 pick %s" % hpick})

    # 6. the bow: string outward (option 1); ribbon check of rev 1; the all-source alternative
    bt = bow_variants(cs)["dz3_bow_hi"]
    bows = {}
    for cid in ("dz3_bow_hi", "dz3_bow_lo15", "dz3_bow_lo15L10", "fin_long_B_bow"):
        fc = fit_checks(raw, ids_of(C, cid), "bow")
        bows[cid] = {"verdict": fc["verdict"], "worst_play_cm": fc["worst_play_cm"], "groups": fc["groups"]}
    rep["bow"] = {"candidates": bows, "pick": "dz3_bow_hi", "string_ribbon_rev1": string_ribbon_check(rev1["long_B.bow"]["t"]),
                  "all_source_alternative": bow_alt_study(dump, bt, ids_of(C, "dz3_bow_hi")),
                  "tips_bind": [[round(float(v), 3) for v in p] for p in bow_tips(bt)], "handle_bind": [round(float(v), 3) for v in bt[:3, 3]]}
    F["long_B.bow"].update({"t": bt, "caps": _defs_caps(D, "dz3_bow_hi"),
                            "note": "Stave on the back, string OUTWARD (the model's own String mesh stays; no string ribbon), upper limb "
                                    "behind the right shoulder over the quiver, lower limb behind the left hip; held by the quiver strap.",
                            "basis": "revision 3 (review option 1): the survey line of back.long_B.bow, string turned outward"})
    F.pop("long_A.bow", None)

    # 7. musket path
    rep["musket_path"] = {st: musket_path_v3(dump, F["long_A.musket"]["t"], st) for st in ("draw", "draw_c")}

    # 8. holster_finish of sling-all
    rep["holster_finish"] = holster_finish_check(dump)
    return rep


def _kind(v):
    return (v if isinstance(v, str) else v["kind"]).split("@")[0]


def _base(i):
    return i[2:] if i.startswith("y_") else i


def trav_study2(raw, items):
    """Traversal (jump, land, vault, climb, ladder, ledge) worst clearance per item and policy: stowed, push
    out 5 / 10 cm, swing 25 deg about the hook (belt items), yield (swing on the hook away from the limbs,
    at most 30 deg). Choice: the first policy in that order that reaches contact (>= -3.5 cm), else the best;
    the clips still below contact under the choice are listed."""
    C = cand_map(raw)
    out = {}
    for key, ids in items.items():
        base = [_base(i) for i in ids]
        pols = {"stowed": base, "push 5 cm": ["push05:" + i for i in base], "push 10 cm": ["push10:" + i for i in base],
                "swing 25 deg": ["swing25:" + i for i in base], "yield": ["y_" + i for i in base]}
        rows = {}
        for pol, pids in pols.items():
            pids = [p for p in pids if p in C]
            if not pids:
                continue
            wc = {}
            for p in pids:
                for clip, v in C[p]["by_clip"].items():
                    if raw["clips"].get(clip, {}).get("category") not in TRAV_CATS:
                        continue
                    w = min(v[0], v[2])
                    if clip not in wc or w < wc[clip][0]:
                        wc[clip] = [w, v[1] if v[0] < v[2] else "surface"]
            if not wc:
                continue
            worst = min(wc.items(), key=lambda kv: kv[1][0])
            rows[pol] = {"worst_cm": cm(worst[1][0]), "worst_clip": worst[0], "by": worst[1][1],
                         "clips_below_contact": sorted([[k, cm(v[0]), v[1]] for k, v in wc.items() if v[0] < -0.035], key=lambda x: x[1])}
        choice = None
        for pol in ("stowed", "yield", "push 5 cm", "swing 25 deg", "push 10 cm"):
            if pol in rows and rows[pol]["worst_cm"] >= -3.5:
                choice = pol
                break
        if choice is None and rows:
            choice = max(rows, key=lambda p: rows[p]["worst_cm"])
        if choice:
            out[key] = {"policies": {p: {k: v for k, v in r.items() if k != "clips_below_contact"} for p, r in rows.items()},
                        "choice": choice, "residual_cm": rows[choice]["worst_cm"],
                        "still_below_contact": rows[choice]["clips_below_contact"][:8],
                        "n_clips_below_contact": len(rows[choice]["clips_below_contact"])}
    return out


def revise_after(F, raw, dump, presets, handovers, draw_for, rep):
    """The studies over the final slot map: draw paths per preset, riding and prone, traversal, camera."""
    D = cand_defs()
    C = cand_map(raw)
    RADII.update({k: v["radius"] for k, v in D.items()})
    ids = {k: [c["id"] for c in v["caps"]] for k, v in F.items()}
    radius = {i: D[i]["radius"] for v in ids.values() for i in v if i in D}

    # I. draw paths through the other stowed items, per preset
    dp = {}
    for pid, pr in presets["presets"].items():
        keys = {}
        for pt, v in pr["items"].items():
            k = "%s.%s" % (pt, _kind(v))
            if k in F:
                keys[k] = (pt, _kind(v))
        if "horn_strap" in pr["gear"]:
            keys["horn.powder_horn"] = ("horn", "powder_horn")
        res = {}
        for k, (pt, kind) in keys.items():
            sets = draw_for(pt, kind)
            if not sets:
                continue
            ds = sets[0]
            others = [i for kk in keys if kk != k for i in ids.get(kk, [])]
            if not others:
                continue
            ho = handovers.get(k, {})
            e = {"draw_set": ds}
            if ds in DRAW_DUMP:
                bone = DRAW_DUMP[ds][2]
                for st, stn in (("draw", "stand"), ("draw_c", "crouch")):
                    ikv = None
                    s0 = ho.get("stances", {}).get(stn, {})
                    if ho.get("reach_ik") and bone:
                        if "grip_gap_m" in s0 and kind == "pistol":
                            ikv = (F[k]["t"][:3, 3] - np.array(SRC_GRIP_STAND)) if stn == "stand" else None
                        elif "contact_bind" in s0:
                            ikv = np.array(s0["contact_bind"]) - np.array(s0["hand_bind_equiv"])
                    e[stn] = draw_path_clearance(dump, ds, others, ikv, bone, st)
                    # slung items (long items, quiver) hang from straps: they yield to the drawing arm about their upper end
                    slung = [kk for kk in keys if kk != k and F[kk]["bone"] == "spineb"]
                    if e[stn] and e[stn][0] < -1.0 and slung:
                        clips = DRAW_DUMP[ds][0]
                        kl = []
                        for ci, (ck, L) in enumerate(clips):
                            if ds == "reach_right_shoulder" and st == "draw_c":
                                ck = "actor_b-p-crouch-bow-reload--part"
                            kl.append((st + ":" + ck, L, "grab" if (len(clips) > 1 and ci == 0) else "draw"))
                        need = {}
                        for kk in slung:
                            if F[kk]["kind"] == "bow":
                                r = rigid_yield_needed(dump, kl, [i for i in ids[kk] if "string" not in i], F[kk]["t"][:3, 3],
                                                       DRAW_DUMP[ds][1], max_deg=40, ik=ikv, ik_bone=bone)
                                need[kk] = r["max_swing_deg"] if r["max_swing_deg"] is not None else 99
                                continue
                            for i in ids[kk]:
                                r = strap_yield_needed(dump, kl, i, "hi", DRAW_DUMP[ds][1], max_deg=40, ik=ikv, ik_bone=bone)
                                v = r["max_swing_deg"] if r["max_swing_deg"] is not None else 99
                                need[kk] = max(need.get(kk, 0), v)
                        need = {kk: (v if v < 99 else "more than 40") for kk, v in need.items()}
                        rest_ids = [i for kk in keys if kk != k and kk not in slung for i in ids.get(kk, [])]
                        e[stn + "_slung_yield_deg"] = need
                        e[stn + "_rest_after_yield"] = draw_path_clearance(dump, ds, rest_ids, ikv, bone, st) if rest_ids else None
                e["reach_ik_applied"] = bool(ho.get("reach_ik"))
            else:
                e["stand"] = draw_clearance(C, ds, [_base(i) for i in others], ("draw",))
                e["crouch"] = draw_clearance(C, ds, [_base(i) for i in others], ("draw_c",))
                e["reach_ik_applied"] = False
                e["note"] = "mirrored draw: the unmirrored clip against the mirrored items (no IK)"
            res[k] = e
        dp[pid] = res
    rep["draw_paths"] = dp

    # G. riding and prone
    items = {k: v for k, v in ids.items() if all(i in C for i in v)}
    rp = ride_prone_study(dump, items, radius)
    pol = {}
    for k, v in items.items():
        bone = F[k]["bone"]
        if F[k]["point"] in ("long_A", "long_B", "quiver"):
            a, b = cap_ends(D[v[0]])
            lo, hi = (a, b) if a[1] < b[1] else (b, a)
            u = (1.40 - lo[1]) / max(hi[1] - lo[1], 1e-6)
            contact = lo + (hi - lo) * min(max(u, 0.0), 1.0)
            pol[k] = {"ride": "turn about the shoulder contact", **(ride_policy_long(dump, v, radius, contact) or {})}
        elif k in ("back.tomahawk", "back_2.tomahawk", "back.atlatl", "back_left.knife"):
            a, b = cap_ends(D[v[0]])
            hook = a if abs(a[1] - 0.95) < abs(b[1] - 0.95) else b
            oth = [i for kk, vv in items.items() if kk != k and F[kk]["point"] in ("back", "back_2", "back_left", "long_A", "long_B", "quiver")
                   for i in vv]
            pol[k] = {"ride": "turned up (haft up the back, head on the belt)", **ride_policy_turn_up(dump, v, radius, hook, oth)}
        elif k in ("R_hip.pistol", "L_hip.pistol"):
            pol[k] = {"ride": "swings along the thigh", **ride_hip_pistol(dump, v, radius)}
        if k in ("chest_L.pistol", "chest_R.pistol"):
            grip = np.array(D[v[0]]["origin"])
            pol.setdefault(k, {})["prone"] = prone_policy_swing_aside(dump, v, radius, grip)
    rep["ride_prone"] = {"study": rp, "policies": pol}

    # K. traversal
    rep["traversal"] = trav_study2(raw, items)

    # H. camera, per preset (yaw 0 is the gameplay view: player.gd keeps the body facing the camera while alive)
    cam = camera_study(dump, items, radius)
    aim_of = {"musket": "rifle aim", "pistol": "pistol aim", "bow": "bow aim"}
    per = {}
    for pid, pr in presets["presets"].items():
        hand = _kind(pr.get("in_hand", ""))
        stowed = []
        for pt, v in pr["items"].items():
            k = "%s.%s" % (pt, _kind(v))
            if k in items and not (_kind(v) == hand and hand != "spear_pair" and ("@" not in pr.get("in_hand", "") or
                                                                              pr["in_hand"].split("@")[1] == pt)):
                stowed.append(k)
        if "horn_strap" in pr["gear"]:
            stowed.append("horn.powder_horn")
        row = {}
        for pose in ("stand idle", "crouch idle", aim_of.get(hand, "rifle aim")):
            yaws = cam["poses"].get(pose, {})
            e = {}
            for yaw in ("yaw_0", "yaw_90", "yaw_180"):
                cand = [(k, yaws.get(yaw, {}).get(k)) for k in stowed if yaws.get(yaw, {}).get(k)]
                if cand:
                    k, v = min(cand, key=lambda kv: kv[1]["deg_from_crosshair"])
                    e[yaw] = {"nearest": k, "deg": v["deg_from_crosshair"], "height_m": v["height_m"]}
            row[pose] = e
        per[pid] = {"stowed": stowed, "in_hand": hand, "nearest_to_crosshair": row}
    rep["camera"] = {"camera": cam["camera"], "half_fov_deg": cam["half_fov_deg"], "per_preset": per,
                     "all_items_yaw0": {p: e.get("yaw_0") for p, e in cam["poses"].items()}}
    return rep


def clearance_swing(dump, draw_set, blocker_caps, ik_bind=None, ik_bone=None, stance="draw", ik_decay=0.35, max_deg=25):
    """A slung item (long item or quiver) that blocks a draw swings its lower end out about its upper
    (shoulder) contact while the hand passes. Returns the smallest swing (deg) that keeps the drawing hand /
    forearm at >= 0 cm from it over the whole grab + draw, and the clearance reached, or None."""
    spec = DRAW_DUMP.get(draw_set)
    if spec is None:
        return None
    clips, limbs, bone = spec
    samples = []
    for ci, (key, L) in enumerate(clips):
        if draw_set == "reach_right_shoulder" and stance == "draw_c":
            key = "actor_b-p-crouch-bow-reload--part"
        for s in dump.by_key(stance + ":" + key):
            if s["t"] > L + 1e-6:
                continue
            off = np.zeros(3)
            if ik_bind is not None and ik_bone:
                w = s["t"] / L if (len(clips) > 1 and ci == 0) else (max(0.0, 1.0 - s["t"] / (ik_decay * L)) if len(clips) > 1 else 1.0)
                off = s["B"][ik_bone][:3, :3] @ np.linalg.inv(dump.bind[ik_bone][:3, :3]) @ np.asarray(ik_bind) * w
            samples.append((s, off))
    for deg in range(0, max_deg + 1):
        worst = 9.0
        for s, off in samples:
            m = s["B"]["spineb"] @ np.linalg.inv(dump.bind["spineb"])
            for cid, (a_b, b_b, r) in blocker_caps.items():
                a_b, b_b = np.asarray(a_b), np.asarray(b_b)
                hi, lo = (a_b, b_b) if a_b[1] > b_b[1] else (b_b, a_b)
                ax = axis_at(hi[1])
                n = unit([hi[0] - ax[0], 0.0, hi[2] - ax[2]])
                k = unit(np.cross(lo - hi, n))
                lo2 = hi + axis_angle(k, deg) @ (lo - hi)
                if np.dot(lo2 - lo, n) < 0:
                    lo2 = hi + axis_angle(k, -deg) @ (lo - hi)
                pa = (m @ np.append(hi, 1.0))[:3]
                pb = (m @ np.append(lo2, 1.0))[:3]
                for ln in limbs:
                    la, lb = s["L"][ln]
                    la, lb = (la + off, lb + off) if ln.endswith("hand") else (la, lb + off)
                    worst = min(worst, seg_seg(la, lb, pa, pb) - dump.limb_r[ln] - r)
        if worst >= 0.0:
            return {"swing_deg": deg, "clearance_cm": cm(worst)}
    return {"swing_deg": None, "clearance_cm": cm(worst), "note": "more than %d deg needed" % max_deg}


def strap_yield_needed(dump, keys, item_id, pivot_end, limbs, max_deg=45, step=5, ik=None, ik_bone=None):
    """Per sample of the given dump clips: the smallest swing of a strap-hung item about one of its ends
    (pivot_end 'hi' = the upper end, e.g. the quiver mouth), in any of 8 directions, that keeps the given limbs
    at >= 0 cm. Returns the largest such swing over the samples (deg) and where it is needed."""
    need = (0.0, "", 0.0)
    for key, L, phase in keys:
        for s in dump.by_key(key):
            if s["t"] > L + 1e-6 or item_id not in s["C"]:
                continue
            a, b = s["C"][item_id]
            hi, lo = (a, b) if a[1] > b[1] else (b, a)
            piv, free = (hi, lo) if pivot_end == "hi" else (lo, hi)
            off = np.zeros(3)
            if ik is not None:
                w = (s["t"] / L) if phase == "grab" else max(0.0, 1.0 - s["t"] / (0.35 * L))
                off = s["B"][ik_bone][:3, :3] @ np.linalg.inv(dump.bind[ik_bone][:3, :3]) @ np.asarray(ik) * w
            segs = []
            for ln in limbs:
                la, lb = s["L"][ln]
                segs.append((ln, (la + off, lb + off) if ln.endswith("hand") else (la, lb + off)))
            r = RADII.get(item_id, 0.05)

            def clear(p, q):
                return min(seg_seg(p, q, sa, sb) - dump.limb_r[ln] - r for ln, (sa, sb) in segs)
            if clear(piv, free) >= 0.0:
                continue
            u = unit(free - piv)
            p0 = unit(np.cross(u, [0.0, 1.0, 0.0]))
            q0 = np.cross(u, p0)
            found = None
            for deg in range(step, max_deg + 1, step):
                for kk in range(8):
                    az = 2 * math.pi * kk / 8
                    axis = unit(p0 * math.cos(az) + q0 * math.sin(az))
                    f2 = piv + axis_angle(axis, deg) @ (free - piv)
                    if clear(piv, f2) >= 0.0:
                        found = deg
                        break
                if found:
                    break
            d = found if found else 999
            if d > need[0]:
                need = (d, key, s["t"])
    return {"max_swing_deg": need[0] if need[0] < 999 else None, "where": need[1], "t": need[2]}


def rigid_yield_needed(dump, keys, item_ids, pivot_bind, limbs, bone="spineb", max_deg=30, ik=None, ik_bone=None):
    """strap_yield_needed for a rigid multi-capsule item (the bow) turning about a bind-space pivot carried by
    `bone` (the bow: its handle, where the quiver strap holds it)."""
    need = (0.0, "", 0.0)
    for key, L, phase in keys:
        for s in dump.by_key(key):
            if s["t"] > L + 1e-6:
                continue
            caps = [s["C"][i] for i in item_ids if i in s["C"]]
            if not caps:
                continue
            m = s["B"][bone] @ np.linalg.inv(dump.bind[bone])
            piv = (m @ np.append(pivot_bind, 1.0))[:3]
            off = np.zeros(3)
            if ik is not None:
                w = (s["t"] / L) if phase == "grab" else max(0.0, 1.0 - s["t"] / (0.35 * L))
                off = s["B"][ik_bone][:3, :3] @ np.linalg.inv(dump.bind[ik_bone][:3, :3]) @ np.asarray(ik) * w
            segs = []
            for ln in limbs:
                la, lb = s["L"][ln]
                segs.append((ln, (la + off, lb + off) if ln.endswith("hand") else (la, lb + off)))

            def clear(rot):
                return min(seg_seg(piv + rot @ (a - piv), piv + rot @ (b - piv), sa, sb) - dump.limb_r[ln] - BOW["r"]
                           for a, b in caps for ln, (sa, sb) in segs)
            if clear(np.eye(3)) >= 0.0:
                continue
            lo = min((p for c in caps for p in c), key=lambda p: p[1])
            u = unit(lo - piv)
            p0 = unit(np.cross(u, [0.0, 1.0, 0.0]))
            q0 = np.cross(u, p0)
            found = None
            for deg in range(1, max_deg + 1):
                for kk in range(8):
                    az = 2 * math.pi * kk / 8
                    if clear(axis_angle(unit(p0 * math.cos(az) + q0 * math.sin(az)), deg)) >= 0.0:
                        found = deg
                        break
                if found:
                    break
            d = found if found else 999
            if d > need[0]:
                need = (d, key, s["t"])
    return {"max_swing_deg": need[0] if need[0] < 999 else None, "where": need[1], "t": need[2]}
