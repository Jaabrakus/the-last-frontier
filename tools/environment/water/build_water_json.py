#!/usr/bin/env python3
"""R1's water network (WaterNetwork, scripts/world/water/water_network.gd; its numpy twin water_net.py) from R1's layout
(data/world/maps/r1/layout.json, the lead's file: the only source of coordinates and levels). Writes
data/world/maps/r1/water.json. Nobody hand-edits water.json: the lead changes the layout, or the rules below change, and
this runs again.

    python3 tools/environment/water/build_water_json.py [--layout PATH] [--out PATH] [--check]

--check: build in memory and fail (exit 1) if the written water.json differs (a stale water.json).

What it makes of the layout:
  channels   each channel's few layout nodes become a smooth centre line sampled every STEP_M m: the nodes stay on it
             exactly; between them x(z) (z-monotonic channels; the torrent: z(x)) is a cubic Hermite with Catmull-Rom
             slopes, so the main channel stays strictly z-monotonic for WorldRiver. Each sample carries s (m along),
             x, z, half_width and level (linear between the layout nodes), bed_depth and speed (the rules below).
  bed        the channel's cross-section: bed = level - bed_depth * (1 - |offset / half_width| ^ exponent), 0 deep at its
             edge; bed_depth = BED[ch].depth0 + BED[ch].per_hw * half_width (first numbers for T4's carving)
  speed      m/s along the centre line: SPEED_MPS[ch] x the node's flow_scale x the narrows (sqrt(median half_width /
             half_width), clamped NARROWS) x FALL_SPEED over a fall; world state scales it per reach at runtime
  falls      the torrent's falls_x: FALL_SHARE of the drop between its two layout nodes taken over FALL_LEN m there, the
             rest spread along the segment (so the level is still continuous)
  junction   a channel that `joins` another ends at the junction at the other's level there; over its last MOUTH_M m
             outside the other's water the runtime eases its level onto the other's (continuous at the bank). Where
             two channels overlap, the one joined wins (channels listed in rank order).
  reaches    z_from/z_to (layout) as s_from/s_to; flow x scale_by_state inside, eased back to 1 over ease_m past the
             ends (the shape of WorldRiver.rapid_at's ramp)
  steps      the lock step as s_upper/s_lower with its two levels, marked with its milestone (M2): until then the level
             eases through it as the layout's nodes have it; from M2 the channel holds level_upper down to s_lower,
             then drops
  pounds     rects and paddy step runs as polygons (x, z), each flat at its level, with a flat bed POUND_DEPTH under it.
             Paddy steps run southward (+z) edge to edge from first_center, each step_drop_m lower (the layout does not
             say which way; a T4/lead check). A pound within FEED_M m of a channel's water below a reach that stops in
             some state is fed by it and carries the downstream drop curve.
  curves     downstream_drop: the level change of such pounds by bible days since the river stopped (S1's first day),
             -DROP_M x (1 - e^(-day / DROP_TAU_DAYS)), sampled daily over a Book (DROP_DAYS); first numbers, proposal.
Milestones: every channel, pound and step carries one; WaterNetwork leaves out what is later than its own (default M1).
"""
import argparse
import hashlib
import json
import math
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
LAYOUT = os.path.join(ROOT, "data", "world", "maps", "r1", "layout.json")
OUT = os.path.join(ROOT, "data", "world", "maps", "r1", "water.json")

STEP_M = 8.0
BED = {"main": {"depth0": 0.6, "per_hw": 0.1, "exponent": 2.0},
       "torrent": {"depth0": 0.4, "per_hw": 0.1, "exponent": 3.0}}
BED_DEFAULT = {"depth0": 0.5, "per_hw": 0.1, "exponent": 2.0}
SPEED_MPS = {"main": 0.45, "torrent": 1.2}        # main: today's WaterSurface.RIVER_MPS
NARROWS = (0.7, 1.6)
FALL_LEN = 6.0
FALL_SHARE = 0.6
FALL_SPEED = 2.5
MOUTH_M = 24.0
POUND_DEPTH = {"lock_chamber": 4.0, "barge_basin": 3.0, "paddies": 0.15}
FEED_M = 40.0
DROP_M = 1.5
DROP_TAU_DAYS = 9.0
DROP_DAYS = 150
CHANNEL_MILESTONE = {"main": "M0"}                 # others: M1 (the layout: "WaterNetwork only (M1+)")
MILESTONES = ["M0", "M1", "M2"]
ND = 4                                             # decimals written


def r(v):
    return round(float(v), ND)


def load_layout(path):
    with open(path, encoding="utf-8") as fh:
        raw = fh.read()
    return json.loads(raw), hashlib.sha1(raw.encode("utf-8")).hexdigest()


# --- the centre line -------------------------------------------------------------------------------------------------

def _slopes(u, v):
    """Catmull-Rom slopes dv/du at each node (one-sided at the ends)."""
    n = len(u)
    m = []
    for i in range(n):
        a, b = max(i - 1, 0), min(i + 1, n - 1)
        m.append((v[b] - v[a]) / (u[b] - u[a]))
    return m


def _hermite(u0, u1, v0, v1, m0, m1, uu):
    h = u1 - u0
    t = (uu - u0) / h
    t2, t3 = t * t, t * t * t
    return ((2 * t3 - 3 * t2 + 1) * v0 + (t3 - 2 * t2 + t) * h * m0 + (-2 * t3 + 3 * t2) * v1 + (t3 - t2) * h * m1)


def _axis(ch):
    """The axis the channel runs along: z if the layout calls it z-monotonic, else x if it is monotonic in x."""
    nodes = ch["nodes"]
    zs = [n[1] for n in nodes]
    xs = [n[0] for n in nodes]
    if ch.get("z_monotonic"):
        if not all(b > a for a, b in zip(zs, zs[1:])):
            raise SystemExit("channel %s is marked z_monotonic but its nodes' z do not rise" % ch["id"])
        return "z"
    if all(b > a for a, b in zip(xs, xs[1:])) or all(b < a for a, b in zip(xs, xs[1:])):
        return "x"
    raise SystemExit("channel %s is monotonic in neither z nor x; the builder needs a chord-length spline" % ch["id"])


def _fall_breaks(ch, nodes, axis):
    """The torrent's falls as level control points [(u, level)] on top of its nodes, and the fall spans in u."""
    u = [n[0] if axis == "x" else n[1] for n in nodes]
    lv = [n[3] for n in nodes]
    flip = u[-1] < u[0]
    ctrl = list(zip(u, lv))
    spans = []
    for fx in ch.get("falls_x", []):
        for i in range(len(u) - 1):
            lo, hi = sorted((u[i], u[i + 1]))
            if lo < fx < hi:
                seg = abs(u[i + 1] - u[i])
                drop = lv[i] - lv[i + 1]
                d = 1.0 if not flip else -1.0
                a = fx - d * FALL_LEN * 0.5
                b = fx + d * FALL_LEN * 0.5
                top = lv[i] - (1.0 - FALL_SHARE) * drop * abs(a - u[i]) / (seg - FALL_LEN)
                ctrl += [(a, top), (b, top - FALL_SHARE * drop)]
                spans.append((min(a, b), max(a, b), fx, FALL_SHARE * drop))
                break
        else:
            raise SystemExit("fall at x %s lies on no torrent segment" % fx)
    ctrl.sort(key=lambda p: p[0], reverse=flip)
    return ctrl, spans


def _interp(ctrl, uu, flip):
    """Piecewise-linear value at uu over control points [(u, v)] (u increasing, or decreasing if flip)."""
    pts = ctrl[::-1] if flip else ctrl
    if uu <= pts[0][0]:
        return pts[0][1]
    for (u0, v0), (u1, v1) in zip(pts, pts[1:]):
        if uu <= u1:
            return v0 + (v1 - v0) * (uu - u0) / (u1 - u0)
    return pts[-1][1]


def build_channel(ch, rank):
    cid = ch["id"]
    nodes = ch["nodes"]
    axis = _axis(ch)
    u = [n[0] if axis == "x" else n[1] for n in nodes]
    w = [n[1] if axis == "x" else n[0] for n in nodes]       # the other coordinate, as a function of u
    flip = u[-1] < u[0]
    ctrl_level, fall_spans = _fall_breaks(ch, nodes, axis) if ch.get("falls_x") else ([(a, n[3]) for a, n in zip(u, nodes)], [])
    hw_ctrl = [(a, n[2]) for a, n in zip(u, nodes)]
    fs_ctrl = [(a, n[4] if len(n) > 4 else 1.0) for a, n in zip(u, nodes)]
    m = _slopes(u, w)
    # samples: every layout node and fall edge exactly, STEP_M or finer between
    breaks = sorted(set(u) | {p[0] for p in ctrl_level}, reverse=flip)
    us = [breaks[0]]
    for a, b in zip(breaks, breaks[1:]):
        k = max(1, int(math.ceil(abs(b - a) / STEP_M)))
        us += [a + (b - a) * j / k for j in range(1, k + 1)]
    bed = BED.get(cid, BED_DEFAULT)
    hw_med = sorted(n[2] for n in nodes)
    hw_med = 0.5 * (hw_med[(len(hw_med) - 1) // 2] + hw_med[len(hw_med) // 2])
    rows = []
    s = 0.0
    px = pz = None
    for uu in us:
        # which layout segment
        i = 0
        while i < len(u) - 2 and ((uu > u[i + 1]) if not flip else (uu < u[i + 1])):
            i += 1
        ww = _hermite(u[i], u[i + 1], w[i], w[i + 1], m[i], m[i + 1], uu)
        x, z = (uu, ww) if axis == "x" else (ww, uu)
        if px is not None:
            s += math.hypot(x - px, z - pz)
        px, pz = x, z
        hw = _interp(hw_ctrl, uu, flip)
        level = _interp(ctrl_level, uu, flip)
        fs = _interp(fs_ctrl, uu, flip)
        narrows = min(max(math.sqrt(hw_med / hw), NARROWS[0]), NARROWS[1])
        in_fall = any(a - 1e-6 <= uu <= b + 1e-6 for a, b, _, _ in fall_spans)
        speed = SPEED_MPS.get(cid, 0.6) * fs * narrows * (FALL_SPEED if in_fall else 1.0)
        rows.append([s, x, z, hw, level, bed["depth0"] + bed["per_hw"] * hw, speed])
    out = {
        "id": cid,
        "rank": rank,
        "milestone": CHANNEL_MILESTONE.get(cid, "M1"),
        "z_monotonic": bool(ch.get("z_monotonic", False)),
        "length": None,
        "bed": {"exponent": bed["exponent"]},
        "nodes": rows,
        "reaches": [],
        "steps": [],
        "falls": [],
    }
    for a, b, fx, drop in fall_spans:
        out["falls"].append({"x": fx, "s_from": None, "s_to": None, "drop": drop, "_u": (a, b)})
    return out


# --- along a built channel -------------------------------------------------------------------------------------------

def _col(chb, k):
    return [row[k] for row in chb["nodes"]]


def s_at_coord(chb, key, v):
    """s where the centre line crosses coordinate `key` (1 = x, 2 = z) = v (monotonic channels)."""
    us = _col(chb, key)
    ss = _col(chb, 0)
    inc = us[-1] > us[0]
    for i in range(len(us) - 1):
        a, b = us[i], us[i + 1]
        if (a <= v <= b) if inc else (b <= v <= a):
            t = (v - a) / (b - a) if b != a else 0.0
            return ss[i] + t * (ss[i + 1] - ss[i])
    raise SystemExit("coordinate %s=%s is off channel %s" % ("xz"[key - 1], v, chb["id"]))


def value_at_s(chb, k, s):
    ss = _col(chb, 0)
    vs = _col(chb, k)
    for i in range(len(ss) - 1):
        if s <= ss[i + 1]:
            t = (s - ss[i]) / (ss[i + 1] - ss[i])
            return vs[i] + t * (vs[i + 1] - vs[i])
    return vs[-1]


def project(chb, x, z):
    """(s, distance, offset, half_width) of the nearest centre-line point (no clamp check; the builder's own use)."""
    best = None
    n = chb["nodes"]
    for i in range(len(n) - 1):
        ax, az, bx, bz = n[i][1], n[i][2], n[i + 1][1], n[i + 1][2]
        dx, dz = bx - ax, bz - az
        L2 = dx * dx + dz * dz
        t = min(max(((x - ax) * dx + (z - az) * dz) / L2, 0.0), 1.0)
        qx, qz = ax + t * dx, az + t * dz
        d2 = (x - qx) ** 2 + (z - qz) ** 2
        if best is None or d2 < best[0]:
            L = math.sqrt(L2)
            side = (x - qx) * (-dz / L) + (z - qz) * (dx / L)
            best = (d2, i, t, side)
    d2, i, t, side = best
    s = n[i][0] + t * (n[i + 1][0] - n[i][0])
    hw = n[i][3] + t * (n[i + 1][3] - n[i][3])
    d = math.sqrt(d2)
    return s, d, (d if side >= 0 else -d), hw


# --- pounds ----------------------------------------------------------------------------------------------------------

def _rect(cx, cz, sx, sz):
    return [[cx - sx / 2, cz - sz / 2], [cx + sx / 2, cz - sz / 2], [cx + sx / 2, cz + sz / 2], [cx - sx / 2, cz + sz / 2]]


def build_pounds(lay):
    out = []
    for p in lay.get("pounds", []):
        base = {"cell": p.get("cell", ""), "milestone": p.get("milestone", "M1")}
        if "steps" in p:
            fx, fz = p["first_center"]
            sx, sz = p["step_size"]
            for k in range(int(p["steps"])):
                lv = p["top_level"] - k * p["step_drop_m"]
                out.append(dict(base, id="%s_%d" % (p["id"], k + 1), group=p["id"], kind="paddy",
                                polygon=_rect(fx, fz + k * sz, sx, sz), level=lv, bed=lv - POUND_DEPTH["paddies"]))
        elif "level_upper" in p:
            cx, cz = p["rect_center"]
            out.append(dict(base, id=p["id"], group=p["id"], kind="lock_chamber",
                            polygon=_rect(cx, cz, p["size"][0], p["size"][1]), level=p["level_lower"],
                            level_upper=p["level_upper"], level_lower=p["level_lower"],
                            bed=p["level_lower"] - POUND_DEPTH["lock_chamber"]))
        else:
            cx, cz = p["rect_center"]
            out.append(dict(base, id=p["id"], group=p["id"], kind="basin",
                            polygon=_rect(cx, cz, p["size"][0], p["size"][1]), level=p["level"],
                            bed=p["level"] - POUND_DEPTH["barge_basin"]))
    return out


def _poly_points(poly, n=6):
    """The polygon's corners, edge points and centre (for feeding checks)."""
    pts = []
    for (ax, az), (bx, bz) in zip(poly, poly[1:] + poly[:1]):
        pts += [[ax + (bx - ax) * j / n, az + (bz - az) * j / n] for j in range(n)]
    pts.append([sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly)])
    return pts


# --- the whole network -----------------------------------------------------------------------------------------------

def build(lay, sha):
    chans = lay["channels"]
    # rank: a channel others join first (it wins where they overlap)
    joined = {c.get("joins", {}).get("channel") for c in chans if c.get("joins")}
    order = sorted(chans, key=lambda c: (0 if c["id"] in joined else 1, chans.index(c)))
    built = {c["id"]: build_channel(c, k) for k, c in enumerate(order)}
    by_layout = {c["id"]: c for c in chans}
    junctions = []
    for c in order:
        chb = built[c["id"]]
        lc = by_layout[c["id"]]
        ax = 2 if chb["z_monotonic"] else 1
        # falls: their s
        for f in chb["falls"]:
            a, b = f.pop("_u")
            f["s_from"], f["s_to"] = sorted((s_at_coord(chb, ax, a), s_at_coord(chb, ax, b)))
        # reaches and steps (layout z; z-monotonic channels only)
        for rc in lc.get("reaches", []):
            chb["reaches"].append({"id": rc["id"], "z_from": rc["z_from"], "z_to": rc["z_to"],
                                   "s_from": s_at_coord(chb, 2, rc["z_from"]), "s_to": s_at_coord(chb, 2, rc["z_to"]),
                                   "ease_m": rc.get("ease_m", 40.0), "scale_by_state": rc.get("scale_by_state", {})})
        for st in lc.get("steps", []):
            su, sl = s_at_coord(chb, 2, st["z_upper"]), s_at_coord(chb, 2, st["z_lower"])
            chb["steps"].append({"id": st["id"], "z_upper": st["z_upper"], "z_lower": st["z_lower"], "s_upper": su,
                                 "s_lower": sl, "level_upper": value_at_s(chb, 4, su),
                                 "level_lower": value_at_s(chb, 4, sl), "milestone": st.get("milestone", "M2"),
                                 "pound": None})
    for c in order:
        j = by_layout[c["id"]].get("joins")
        if not j:
            continue
        chb, into = built[c["id"]], built[j["channel"]]
        jx, jz = j["at"]
        s_into, _, _, _ = project(into, jx, jz)
        lv = value_at_s(into, 4, s_into)
        # the joining channel's last layout node at the other's level there (its samples after the previous node
        # re-levelled linearly onto it)
        last = chb["nodes"][-1]
        old = last[4]
        prev_layout = by_layout[c["id"]]["nodes"][-2]
        s_prev = project(chb, prev_layout[0], prev_layout[1])[0]
        for row in chb["nodes"]:
            if row[0] >= s_prev:
                k = (row[0] - s_prev) / (last[0] - s_prev)
                row[4] += (lv - old) * k
        junctions.append({"id": "%s_into_%s" % (c["id"], j["channel"]), "channel": c["id"], "into": j["channel"],
                          "at": [jx, jz], "s": last[0], "s_into": s_into, "level": lv, "mouth_m": MOUTH_M})
    for chb in built.values():
        chb["length"] = chb["nodes"][-1][0]
    pounds = build_pounds(lay)
    # which pounds a stopping reach feeds (the downstream drop), and which pound a step's chamber is
    for p in pounds:
        for chb in sorted(built.values(), key=lambda c: c["rank"]):
            best = None
            for qx, qz in _poly_points(p["polygon"]):
                s, d, _, hw = project(chb, qx, qz)
                if d - hw <= FEED_M and (best is None or d - hw < best[1]):
                    best = (s, d - hw)
            if best is None:
                continue
            stops = [rc for rc in chb["reaches"] if rc["s_to"] <= best[0] and min(rc["scale_by_state"].values() or [1.0]) < 1.0]
            p["fed_by"] = {"channel": chb["id"], "s": r(best[0])}
            if stops:
                p["curve"] = "downstream_drop"
            for st in chb["steps"]:
                cx = sum(q[0] for q in p["polygon"]) / 4.0
                cz = sum(q[1] for q in p["polygon"]) / 4.0
                if p["kind"] == "lock_chamber" and st["z_upper"] <= cz <= st["z_lower"]:
                    st["pound"] = p["id"]
            break
    curve = [[d, r(-DROP_M * (1.0 - math.exp(-d / DROP_TAU_DAYS)))] for d in range(DROP_DAYS + 1)]
    chans_out = sorted(built.values(), key=lambda c: c["rank"])
    for chb in chans_out:
        chb["nodes"] = [[r(v) for v in row] for row in chb["nodes"]]
        chb["length"] = r(chb["length"])
        for coll in ("reaches", "steps", "falls"):
            for e in chb[coll]:
                for k, v in list(e.items()):
                    if isinstance(v, float):
                        e[k] = r(v)
    for jn in junctions:
        for k in ("s", "s_into", "level"):
            jn[k] = r(jn[k])
    for p in pounds:
        p["polygon"] = [[r(a), r(b)] for a, b in p["polygon"]]
        for k in ("level", "bed", "level_upper", "level_lower"):
            if k in p:
                p[k] = r(p[k])
    return {
        "_doc": [
            "R1's water network: GENERATED by tools/environment/water/build_water_json.py from "
            "data/world/maps/r1/layout.json. Do not hand-edit; change the layout (the lead) or the builder and rerun.",
            "Read by WaterNetwork (scripts/world/water/water_network.gd) and tools/environment/water/water_net.py.",
            "Units m and m/s; north is -Z. Channel nodes are node_fields rows every ~%g m along the centre line; values "
            "between two rows are linear in s. offset is signed, + on the right bank looking downstream." % STEP_M,
            "Reaches scale flow by world state, eased back to 1 over ease_m past their ends. Steps and pounds are "
            "live from their milestone on. Pound curves are by bible days since the river stopped (S1's first day).",
            "First numbers (bed depths, speeds, the drop curve) are proposals for T4 and the lead to confirm.",
        ],
        "version": 1,
        "source": {"layout": "data/world/maps/r1/layout.json", "sha1": sha},
        "milestones": MILESTONES,
        "states": ["S0", "S1", "S2", "S3", "S4"],
        "node_fields": ["s", "x", "z", "half_width", "level", "bed_depth", "speed"],
        "channels": chans_out,
        "junctions": junctions,
        "pounds": pounds,
        "curves": {"downstream_drop": {"by": "bible_days_since_silence", "drop_m": DROP_M, "tau_days": DROP_TAU_DAYS,
                                       "status": "proposal", "nodes": curve}},
    }


def dumps(d):
    """Compact rows, readable structure."""
    txt = json.dumps(d, indent=1, ensure_ascii=False)
    # one row per node / polygon corner / curve point
    import re
    return re.sub(r"\[\s+(-?[\d.e+-]+(?:,\s+-?[\d.e+-]+)*)\s+\]",
                  lambda m: "[" + ", ".join(v.strip() for v in m.group(1).split(",")) + "]", txt) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--layout", default=LAYOUT)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    lay, sha = load_layout(a.layout)
    txt = dumps(build(lay, sha))
    if a.check:
        old = open(a.out, encoding="utf-8").read() if os.path.exists(a.out) else ""
        if old != txt:
            print("water.json is stale: rerun build_water_json.py")
            sys.exit(1)
        print("water.json is up to date")
        return
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with open(a.out, "w", encoding="utf-8") as fh:
        fh.write(txt)
    print("wrote %s (%d bytes)" % (os.path.relpath(a.out, ROOT), len(txt)))


if __name__ == "__main__":
    main()
