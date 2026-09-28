"""Hair v3 recipes (2026-09-28): a hair style written as a short recipe, not as code.

The user asked for "a procedure system to make it easy for us". A style module keeps its SPEC (the
catalog entry, history and sources) and a RECIPE dict, and its build is one line:

    def build(ctx):
        return R.build(ctx, SPEC, RECIPE)

The recipe (every key but "layers" optional):

  domain    where the hair grows (hair/_strands.Domain): {"front": m (a receding or shaved forehead),
            "nape": z (a higher nape), "patch": "crown" (only a patch on the crown: a plucked head)}
  flow      how it is combed:
              ("back", point)          straight back from the hairline to a gather point (a queue)
              ("parted_back", point)   parted in the middle, then drawn back to the point (a braid, a bun)
              ("parted", {...})        parted and falling (loose hair; x, back, down)
              ("whorl", point)         out from the crown whorl and a little down (a crop)
            points by name (POINTS: nape, crown, bun, ...) or (x, y, z)
  layers    strips over the scalp: a preset (name, {options}) or a list of layer dicts
              {"n": count, "slot": atlas slot, "w": width m, "len": length m, "off": (root, top) m
               off the scalp, "taper": 0..1, "step": m}
            presets: combed (a dense base, clumps, fine strands; length, density, volume),
            crop (short hair all over), coily (stacked shells of coily strips; depth)
  hairline  the row of strands at the hairline itself, over the others: {"n", "slot", "w"}; None: none
  fall      long loose hair: past `z` (or off the scalp) a strand falls with gravity, `clearance` off
            the body: {"z": 1.47, "clearance": 0.012}
  tail      a queue, braid or lock hanging from the gather point: {"path": [points] or
            ("back", [z, ...], clearance) (down the back from the gather point), "radii": [m per path
            point], "count": strips round it, "slot": "tail" | "braid", "core": core strips, "tuft":
            m of loose tail strips past the end, "rigid": True (on the head, not the pendulum)}
  bun       a coiled knot at the gather point: {"radii": (rx, ry, rz), "rings": n}
  accents   ribbons, ties and garters (zone 1 of the SPEC): [("bow", {"at": 0}), ("band", {"at": i,
            "t": 0..1, "r": m, "len": m})] on the tail path's segment `at`
  seed      the random seed

The strips are "<id>_tex" (hair_tex.gdshader over the strand atlas), the accents "<id>" (hair.gdshader);
the scalp under the domain is tinted by the style's baked scalp mask. See hair/_strands.py.
"""

import math

import numpy as np

from hair import _common as H
from hair import _strands as ST
from lib import regions as RG
from lib.pipeline import Surface
from lib.sdf import Fn, Inter, Offset, nrm, smoothstep, v3

# Named points (Blender space, the body cache's female base): the gather points of the styles
POINTS = {
    "nape": v3(*H.QUEUE_ROOT),                 # the queue's tie (the pendulum's root)
    "nape_low": v3(0.0, 0.064, 1.405),
    "crown": v3(0.0, 0.040, 1.590),            # the crown lock's root
    "top": v3(0.0, 0.010, 1.612),              # a topknot
    "whorl": v3(0.0, 0.052, 1.580),            # the crown whorl (a crop)
}

TEX = {"straight": "straight", "wavy": "straight", "coily": "coily", "crop": "cropped"}


# named points relative to the head bone (the v1 styles' knots and buns)
HEAD_POINTS = {"bun": (0.0, 0.0845, 0.0060), "bun_high": (0.0, 0.079, 0.046), "knot": (0.0, 0.018, 0.1595),
               "shimada": (0.0, 0.050, 0.140)}


def point(ctx, p):
    """A named point, (name, (dx, dy, dz)) a named point moved, or (x, y, z)."""
    if isinstance(p, str):
        if p in HEAD_POINTS:
            return ctx.K["headb"] + v3(*HEAD_POINTS[p])
        return POINTS[p]
    if len(p) == 2 and isinstance(p[0], str):
        return point(ctx, p[0]) + v3(*p[1])
    return v3(*p)


# --------------------------------------------------------------------------------------------
# flows


def flow_parted_back(G, part_x=0.0, spread=0.05):
    """Parted at x = part_x, drawn back to G: away from the parting near it, toward G further off."""
    G = np.asarray(G, float)

    def f(q, n):
        s = 1.0 if q[0] >= part_x else -1.0
        near = 1.0 - smoothstep(0.0, spread, abs(q[0] - part_x))
        to = G - q
        L = np.linalg.norm(to)
        if L < 1e-6:
            return None
        return ST._tangent(to / L + v3(s * 1.4 * near, 0.0, -0.3 * near), n)
    return f


def _flow(ctx, spec):
    kind = spec[0]
    arg = spec[1] if len(spec) > 1 else None
    if kind in ("back", "up", "to"):
        G = point(ctx, arg)
        return ST.flow_to(G), G
    if kind == "dir":
        return ST.flow_dir(arg), None
    if kind == "nearest":
        # to the nearest of several gather points (side braids: each side to its own)
        Gs = [point(ctx, q) for q in arg]

        def f(q, n):
            g = min(Gs, key=lambda c: np.linalg.norm(c - q))
            return ST._tangent(g - q, n)
        return f, None
    if kind == "parted_back":
        G = point(ctx, arg)
        return flow_parted_back(G), G
    if kind == "parted":
        o = dict(arg or {})
        return ST.flow_parted(o.get("x", 0.0), o.get("back", 0.3), o.get("down", 0.8)), None
    if kind == "whorl":
        return ST.flow_whorl(point(ctx, arg or "whorl"), 0.35), None
    raise ValueError("unknown flow %r" % (kind,))


# --------------------------------------------------------------------------------------------
# layer presets


def combed(length=0.30, density=1.0, volume=1.0, slot_clumps="clumps"):
    """Long hair combed over the head: a dense base, clumps over it, fine strands on top."""
    v = volume
    return [
        {"n": int(70 * density), "slot": "dense", "w": 0.032, "len": length, "off": (0.0015 * v, 0.0055 * v), "taper": 0.15},
        {"n": int(110 * density), "slot": slot_clumps, "w": 0.022, "len": length, "off": (0.0030 * v, 0.0085 * v), "taper": 0.35},
        {"n": int(45 * density), "slot": "fine", "w": 0.013, "len": length, "off": (0.0050 * v, 0.0110 * v), "taper": 0.55},
    ]


def loose(length=0.42, density=1.0, volume=1.0):
    """Long hair hanging loose: wider strips (they fall as a sheet), longer steps past the head."""
    v = volume
    return [
        {"n": int(95 * density), "slot": "dense", "w": 0.036, "len": length, "off": (0.0015 * v, 0.0060 * v), "taper": 0.2},
        {"n": int(120 * density), "slot": "clumps", "w": 0.026, "len": length, "off": (0.0035 * v, 0.0095 * v), "taper": 0.4},
        {"n": int(45 * density), "slot": "fine", "w": 0.014, "len": length * 0.9, "off": (0.0055 * v, 0.0120 * v), "taper": 0.6},
    ]


def crop(length=0.035, density=1.0):
    """Hair cropped short all over (about an inch): many short strips of the cropped slot."""
    return [
        {"n": int(520 * density), "slot": "crop", "w": 0.018, "len": length, "off": (0.0012, 0.0040), "taper": 0.3,
         "step": 0.008},
        {"n": int(300 * density), "slot": "crop", "w": 0.013, "len": length * 0.9, "off": (0.0035, 0.0075), "taper": 0.45,
         "step": 0.008},
    ]


def coily(depth=0.024, density=1.0, length=0.06):
    """Afro-textured hair grown out: shells of short, wide coily strips stacked to `depth` off the scalp,
    the outer shell fullest (it makes the rounded outline), each strip rising from the shell below."""
    shells = 5
    out = []
    for i in range(shells):
        o1 = 0.003 + depth * (i + 1) / shells
        o0 = max(0.0015, o1 - depth / shells * 1.6)
        out.append({"n": int((110 + 25 * i) * density), "slot": "coily", "w": 0.042, "len": length,
                    "off": (o0, o1), "taper": 0.05, "step": 0.012, "root_len": 0.0})
    return out


PRESETS = {"combed": combed, "loose": loose, "crop": crop, "coily": coily}


def _layers(spec):
    if isinstance(spec, tuple):
        return PRESETS[spec[0]](**(spec[1] if len(spec) > 1 else {}))
    return list(spec)


# --------------------------------------------------------------------------------------------
# accents


def bow_node(q1, q2):
    """A ribbon at the tie: a band round the tail, a bow on its back (two loops out to the sides over
    a knot) and two tails hanging down it."""
    ax = nrm(q2 - q1)
    c = q1 + ax * 0.004
    back = nrm(np.cross(v3(1, 0, 0), ax))
    if back[1] < 0:
        back = -back
    side = np.cross(ax, back)

    def f(X, Y, Z):
        px, py, pz = X - c[0], Y - c[1], Z - c[2]
        t = px * ax[0] + py * ax[1] + pz * ax[2]
        bx = px * back[0] + py * back[1] + pz * back[2]
        sx = px * side[0] + py * side[1] + pz * side[2]
        r = np.sqrt(bx * bx + sx * sx)
        out = np.maximum(np.abs(r - 0.0155) - 0.0012, np.abs(t) - 0.0060)
        kb, kt = bx - 0.0175, t
        # the knot
        out = np.minimum(out, np.sqrt((sx / 0.0065) ** 2 + (kt / 0.0075) ** 2 + (kb / 0.0045) ** 2) * 0.0045 - 0.0045)
        for sgn in (1.0, -1.0):
            # a loop: a flattened hollow ellipsoid out to the side, tipped a little up
            ls = sx * sgn - 0.0165
            lt = kt + 0.0035 + ls * 0.18
            e = np.sqrt((ls / 0.0165) ** 2 + (lt / 0.0085) ** 2 + ((kb + 0.001) / 0.0048) ** 2)
            out = np.minimum(out, np.abs((e - 1.0) * 0.0048) - 0.0009)
            # a tail: a flat strip down the tail's back, spreading a little, cut on the slant
            length = 0.062 if sgn > 0 else 0.052
            u = kt - 0.004
            w = sx * sgn - (0.0035 + 0.2 * np.maximum(u, 0.0))
            depth = bx - 0.0165 + 0.03 * np.maximum(u, 0.0)
            out = np.minimum(out, np.maximum.reduce([np.abs(w) - 0.0036, np.abs(depth) - 0.0009, -u, u + w * 0.35 - length]))
        return out
    return Fn(f, c - 0.07, c + 0.09)


def _accent_nodes(ctx, path, radii, accents):
    """[(name, node, h, tris, zone)] of the accents: on the tail path's segment `at`, or between two
    points `a` and `b` (named or (x, y, z))."""
    out = []
    for i, (kind, o) in enumerate(accents):
        name = "%s_%d" % (kind, i)
        zone = int(o.get("zone", 1))
        if "a" in o:
            a, b = point(ctx, o["a"]), point(ctx, o["b"])
            r0 = o.get("r", 0.012)
        else:
            at = int(o.get("at", 0))
            a, b = path[at], path[min(at + 1, len(path) - 1)]
            r0 = o.get("r", radii[at] + 0.0025)
        if kind == "bow":
            out.append((name, bow_node(a, b), 0.0005, int(o.get("tris", 2000)), zone))
        elif kind == "band":
            out.append((name, H.wrap_band(a, b, r0, o.get("len", 0.010), o.get("t", 0.3), thick=o.get("thick", 0.0016)),
                        0.0006, int(o.get("tris", 400)), zone))
        elif kind == "wrap":
            # a wrap over a flat club: the club's flattened section (the tail's radii, `aspect` wider
            # across) offset by `pad`, from `from` to `to` of the path's length
            club = H.flat_chain(list(path[:len(radii)]), list(radii), o.get("aspect", 3.6))
            p0, p1 = path[0], path[len(radii) - 1]
            ax = nrm(p1 - p0)
            L = float(np.linalg.norm(p1 - p0))
            t0, t1 = o.get("from", 0.16), o.get("to", 0.97)

            def span(X, Y, Z, p0=p0, ax=ax, L=L, t0=t0, t1=t1):
                t = ((X - p0[0]) * ax[0] + (Y - p0[1]) * ax[1] + (Z - p0[2]) * ax[2]) / L
                return np.maximum(t0 - t, t - t1) * L
            out.append((name, Inter(Offset(club, o.get("pad", 0.0018)), Fn(span, p0 - 0.2, p0 + 0.2)), 0.0012,
                        int(o.get("tris", 900)), zone))
        elif kind == "box":
            # a flat bag (a bag wig's black silk bag): a rounded box, `c` from the path's start
            from lib.sdf import RoundBox
            c = (path[0] if path is not None else v3(0, 0, 0)) + v3(*o["c"])
            out.append((name, RoundBox(c, tuple(o["half"]), o.get("r", 0.006)), 0.0008, int(o.get("tris", 900)), zone))
        elif kind == "rod":
            # a pin through a knot (a Korean binyeo, a Japanese kanzashi)
            out.append((name, H.chain([a, b], [o.get("r", 0.0025), o.get("r_end", o.get("r", 0.0025))]), 0.0006,
                        int(o.get("tris", 300)), zone))
        else:
            raise ValueError("unknown accent %r" % kind)
    return out


# --------------------------------------------------------------------------------------------
# domain patches (plucked heads)


def crown_patch(center=(0.0, 0.012), half=(0.046, 0.049), r=0.02, z0=1.55):
    """The crown patch of a plucked head ("about 3-4 inches square"): a rounded square seen from above."""
    cx, cy = center
    hx, hy = half

    def sd(P):
        qx = np.abs(P[:, 0] - cx) - (hx - r)
        qy = np.abs(P[:, 1] - cy) - (hy - r)
        d = np.hypot(np.maximum(qx, 0.0), np.maximum(qy, 0.0)) + np.minimum(np.maximum(qx, qy), 0.0) - r
        return np.minimum(-d, P[:, 2] - z0)
    return sd


def qing_front(y0=-0.012):
    """The Qing queue's shaved front: hair only behind a line from ear to ear over the crown."""
    return lambda P: np.atleast_2d(P)[:, 1] - y0


def sakayaki(half_x=0.042, y_back=0.035, z0=1.53, r=0.012):
    """The Japanese sakayaki: the pate shaved from the forehead back over the crown (a band about
    8 cm wide); hair outside it."""
    def sd(P):
        P = np.atleast_2d(P)
        qx = np.abs(P[:, 0]) - (half_x - r)
        qy = P[:, 1] - (y_back - r)
        qz = z0 - P[:, 2]
        d = np.hypot(np.maximum(qx, 0.0), np.maximum(qy, 0.0)) + np.minimum(np.maximum(qx, qy), 0.0) - r
        return np.maximum(d, qz)        # > 0 outside the shaved band
    return sd


def tuft(center=(0.0, 0.020), radius=0.022, z0=1.56):
    """A small round tuft on the crown (the shikha), seen from above."""
    cx, cy = center
    return lambda P: np.minimum(radius - np.hypot(np.atleast_2d(P)[:, 0] - cx, np.atleast_2d(P)[:, 1] - cy),
                                np.atleast_2d(P)[:, 2] - z0)


def behind(y0=0.045):
    """The back of the head: behind y = y0."""
    return lambda P: np.atleast_2d(P)[:, 1] - y0


PATCHES = {"crown": crown_patch, "qing": qing_front, "sakayaki": sakayaki, "tuft": tuft, "behind": behind}


def _patch(spec):
    """("name", {options}) or "name" -> the patch's signed distance (> 0 inside)."""
    name, o = (spec, {}) if isinstance(spec, str) else (spec[0], spec[1] if len(spec) > 1 else {})
    return PATCHES[name](**o)


def _region(dom, reg):
    """A layer's part of the domain: ("crown", {options}) inside the crown patch, ("rest", {...}) outside
    it; ("in", patch) / ("out", patch) for any patch ("tuft", ("tuft", {...}), ...)."""
    kind, o = (reg, {}) if isinstance(reg, str) else (reg[0], reg[1] if len(reg) > 1 else {})
    if kind in ("in", "out"):
        sd = _patch(o)
        kind = "crown" if kind == "in" else "rest"
    else:
        sd = crown_patch(**o)
    if kind == "crown":
        return lambda P: dom(P) & (sd(np.atleast_2d(P)) > 0.0)
    if kind == "rest":
        return lambda P: dom(P) & (sd(np.atleast_2d(P)) <= 0.0)
    raise ValueError("unknown region %r" % (kind,))


# --------------------------------------------------------------------------------------------
# plaited rows and hand-placed locks


def _rows(ctx, b, scalp, dom, rng, o):
    """Rows of plaits flat to the head (cornrows): the rows start along the hairline every `step_deg`
    degrees round the head (from one side to the other, the sides behind the ears too) and run back
    to the gather point at the nape, converging there as straight-back rows do. A row is a plait strip
    with a narrower one over it (the plait's round back). Returns the rows' centre lines (for the
    scalp mask: the partings between them stay skin)."""
    G = point(ctx, o.get("to", "nape_low"))

    def flow(q, n):
        # straight back over the forehead and the top, then down to the nape (aimed at the nape from
        # the front, a row ran down the forehead and out of the hair at once)
        to = G - q
        L = np.linalg.norm(to)
        if L < 1e-6:
            return None
        w = smoothstep(-0.03, 0.05, q[1])
        return ST._tangent(to / L * w + v3(0.0, 1.0, 0.25) * (1.0 - w), n)
    lines = []
    C = scalp.C
    d = dom.sd(C)
    band = (d > 0.0) & (d < 0.012)
    ang = np.sign(C[:, 0]) * ST.head_angle(C)
    lim = o.get("max_deg", 135.0)
    for a in np.arange(-lim, lim + 1e-6, o.get("step_deg", 11.0)):
        m = band & (np.abs(ang - a) < 3.0)
        if not m.any():
            continue
        cand = C[m]
        start = cand[np.argmin(dom.sd(cand))]
        pts, nrms = ST.grow(scalp, start, flow, o.get("len", 0.42), step=o.get("step", 0.008), off=o.get("off", (0.0025, 0.0035)),
                            gather=G, gather_r=0.012, inside=dom)
        if len(pts) < o.get("min_points", 7):
            continue          # a stub (a row stopped by the ear at once)
        w = o.get("w", 0.012)
        b.strip(pts, nrms, w, o.get("slot", "braid"), rng, taper=0.25, u_window=0.9, root_len=0.008)
        b.strip(pts + nrms * 0.0018, nrms, w * 0.6, o.get("slot", "braid"), rng, taper=0.25, u_window=0.6, root_len=0.008)
        lines.append(pts)
    return lines


def rows_sd(lines, half):
    """Signed distance (m, > 0 on a row) to the nearest row centre line."""
    from mathutils.kdtree import KDTree
    pts = []
    for L in lines:
        for a, c in zip(L[:-1], L[1:]):
            n = max(2, int(np.linalg.norm(c - a) / 0.001))
            pts += [a + (c - a) * t for t in np.linspace(0.0, 1.0, n, endpoint=False)]
    kd = KDTree(len(pts))
    for i, q in enumerate(pts):
        kd.insert(q, i)
    kd.balance()

    def sd(P):
        P = np.atleast_2d(P)
        return np.array([half - kd.find(q)[2] for q in P])
    return sd


def _locks(b, scalp, rng, locks):
    """Hand-placed locks (a Siamese temple lock tucked behind the ear): strips along given points,
    each laid on the head `off` m out (the ear left out: the lock passes over its root and behind
    it), mirrored to the other side with "mirror"."""
    F = scalp.F
    A, B_, C_ = scalp.V[F[:, 0]], scalp.V[F[:, 1]], scalp.V[F[:, 2]]
    N = np.cross(B_ - A, C_ - A)
    N /= np.linalg.norm(N, axis=1)[:, None] + 1e-12
    Q = np.c_[np.abs(scalp.C[:, 0]), scalp.C[:, 1], scalp.C[:, 2]]
    off_ear = np.linalg.norm((Q - ST.EAR_C) / ST.EAR_R, axis=1) > 1.05
    Cs, Ns = scalp.C[off_ear], N[off_ear]
    for o in locks:
        paths = [np.array([v3(*q) for q in o["pts"]])]
        if o.get("mirror", True):
            paths.append(paths[0] * np.array([-1.0, 1.0, 1.0]))
        for P in paths:
            idx = [int(np.argmin(np.linalg.norm(Cs - p, axis=1))) for p in P]
            base = Cs[idx] + Ns[idx] * o.get("off", 0.004)
            for k in range(o.get("n", 2)):
                J = base + rng.normal(size=base.shape) * 0.0012 * np.array([1.0, 1.0, 0.3])
                b.strip(J, Ns[idx], o.get("w", 0.010), o.get("slot", "clumps"), rng, taper=0.5, root_len=0.01)


# --------------------------------------------------------------------------------------------
# the build


def front_path(body_sdf, zs, clearance, x=0.0):
    """Points in front of the body (the skin found from the front at each height), moved out by
    `clearance`: a braid hanging over the chest."""
    from lib.sdf import surface_point
    return np.array([surface_point(body_sdf, v3(x, -0.35, z), v3(0, 1, 0), 0.0, 0.45) + v3(0, -clearance, 0) for z in zs])


def _tail(b, rng, path, radii, t, flag):
    """The strips of one tail along `path` (radii per point): the ring of `slot` strips, a core, an
    outer loose ring, a fold (a club) and a tuft of loose ends; `flag` marks them as the pendulum's
    (or the lock's). Returns the path (with the tuft)."""
    slot = t.get("slot", "tail")
    asp, jit = t.get("aspect", 1.0), t.get("jitter", 0.0)
    b.ring(path, radii, t.get("count", 9), slot, rng, width_scale=t.get("width_scale", 1.35), aspect=asp, jitter=jit,
           tail=flag)
    if t.get("core", True):
        b.ring(path, [r * 0.6 for r in radii], max(4, t.get("count", 9) // 2), "dense", rng, aspect=asp, tail=flag)
    if t.get("outer"):
        o = t["outer"]
        b.ring(path, [r * o.get("scale", 1.15) for r in radii], o.get("count", 7), o.get("slot", "clumps"), rng,
               aspect=asp, jitter=o.get("jitter", 0.003), tail=flag)
    if t.get("fold"):
        # a club: the tail folded up behind itself toward the tie
        ax = nrm(path[-1] - path[0])
        back = nrm(np.cross(v3(1.0, 0.0, 0.0), ax))
        if back[1] < 0:
            back = -back
        n = len(radii)
        fp = np.array([path[i] + back * (radii[i] * (0.4 if i == n - 1 else 0.95) + t["fold"]) for i in range(n - 1, 0, -1)])
        fr = [radii[i] * 0.8 for i in range(n - 1, 0, -1)]
        b.ring(fp, fr, max(6, t.get("count", 9) - 3), slot, rng, aspect=asp, tail=flag)
    if t.get("tuft"):
        end, prev = path[-1], path[-2]
        ax = nrm(end - prev)
        tuft = np.array([end - ax * 0.008, end + ax * t["tuft"] * 0.5, end + ax * t["tuft"]])
        b.ring(tuft, [radii[-1] * 0.9, radii[-1] * 1.1, radii[-1] * 0.6], 7, "tail", rng, aspect=asp, tail=flag)
        path = np.vstack([path, tuft[1:]])
    return path


def body_surface_path(ctx, zs, clearance, x, side):
    """Points on the body cache's surface behind (side "back") or in front ("front") at (x, z), moved out
    by `clearance`; where nothing is there (beside the neck) the point keeps the last depth."""
    V = ctx.body().V
    out, last = [], None
    for z in zs:
        m = (np.abs(V[:, 0] - x) < 0.008) & (np.abs(V[:, 2] - z) < 0.008)
        if m.any():
            y = V[m, 1].max() + clearance if side == "back" else V[m, 1].min() - clearance
        else:
            y = last if last is not None else 0.0
        out.append(v3(x, y, z))
        last = y
    return np.array(out)


def _scalp_cast(scalp, origin, direction, clearance):
    from mathutils import Vector
    hit = scalp.bvh.ray_cast(Vector(origin), Vector(direction))
    if hit[0] is None:
        raise ValueError("no scalp under %s" % (origin,))
    return np.array(hit[0]) - np.asarray(direction, float) * clearance


def _tail_path(ctx, G, t, scalp=None):
    """The tail's centre line, from the gather point (or `root`; none for explicit points):
      ("back" | "front", [z...], clearance[, x])  down the body (behind it or in front)
      ("over", [(x, y)...], clearance)            over the top of the head (a knot laid forward)
      ("side", [(y, z)...], clearance)            along the side of the head (+x; a wig's side roll)
      [points]                                    explicit"""
    p = t["path"]
    root = point(ctx, t["root"]) if t.get("root") is not None else G
    if isinstance(p, tuple) and p[0] in ("back", "front"):
        x = p[3] if len(p) > 3 else 0.0
        if x == 0.0:
            f = H.back_path if p[0] == "back" else front_path
            pts = f(ctx.body_sdf(), p[1], p[2], x=x)
        else:
            pts = body_surface_path(ctx, p[1], p[2], x, p[0])
        return np.vstack([root, pts]) if root is not None else pts
    if isinstance(p, tuple) and p[0] == "over":
        pts = np.array([_scalp_cast(scalp, (x, y, 1.9), (0.0, 0.0, -1.0), p[2]) for x, y in p[1]])
        return np.vstack([root, pts]) if root is not None else pts
    if isinstance(p, tuple) and p[0] == "side":
        return np.array([_scalp_cast(scalp, (0.2, y, z), (-1.0, 0.0, 0.0), p[2]) for y, z in p[1]])
    return np.array([point(ctx, q) for q in p])


def build(ctx, spec, R):
    K = ctx.K
    rng = np.random.default_rng(R.get("seed", 1758))
    scalp = ST.Scalp(ctx)
    d = dict(R.get("domain", {}))
    patch = d.pop("patch", None)
    if patch is not None:
        d["extra"] = _patch(patch)
    dom = ST.Domain(**d)
    flow, G = _flow(ctx, R["flow"])
    bun = R.get("bun")
    gather = G
    if bun is not None:
        # the hair meets the bun where it sits on the head (not at its middle: no strands in the air)
        gs = scalp.nearest(G)[0]
        gather = G + (gs - G) * 0.6
    fall = R.get("fall")
    sdf = ctx.body_sdf() if fall else None
    b = ST.Builder(spec.id + "_strands")
    for L in _layers(R.get("layers", [])):
        ok = _region(dom, L["region"]) if L.get("region") else dom
        fl = _flow(ctx, L["flow"])[0] if L.get("flow") else flow
        ST.layer(b, scalp, K, ok, fl, rng, L["n"], L["slot"], L["w"], L["len"], L["off"], gather=gather,
                 taper=L.get("taper", 0.4), step=L.get("step", 0.012), fall=fall["z"] if fall else None, sdf=sdf,
                 clearance=fall.get("clearance", 0.012) if fall else 0.012, root_len=L.get("root_len", 0.02), domain=ok)
    hl = R.get("hairline", {})
    if hl is not None:
        ST.layer(b, scalp, K, ST.hairline_band(dom, hl.get("depth", 0.012)), flow, rng, hl.get("n", 90),
                 hl.get("slot", "fine"), hl.get("w", 0.012), hl.get("len", 0.30), hl.get("off", (0.0012, 0.0055)),
                 gather=gather, taper=0.4, step=hl.get("step", 0.010), domain=dom, fall=fall["z"] if fall else None,
                 sdf=sdf, clearance=fall.get("clearance", 0.012) if fall else 0.012)
    mask_dom = dom
    if R.get("rows"):
        o = R["rows"]
        lines = _rows(ctx, b, scalp, dom, rng, o)
        rsd = rows_sd(lines, o.get("w", 0.012) * 0.5)
        base = d.get("extra")
        mask_dom = ST.Domain(**dict(d, extra=(lambda P: np.minimum(base(P), rsd(P))) if base else rsd))
    if R.get("locks"):
        _locks(b, scalp, rng, R["locks"])
    # tails: "tail" (the first) and "tails"; each follows the pendulum (a queue, a braid down the back:
    # one per style), the head as a lock ("rigid": the crown lock) or the body ("follow": "body": side
    # braids, a wig's side rolls: the nearest body point's weights)
    tail_axis, rigid, radius, lie = None, False, 0.03, None
    acc_pieces = []              # (name, node, h, tris, zone, group: "pendulum" | "lock" | "head")
    tails = ([R["tail"]] if R.get("tail") else []) + list(R.get("tails", []))
    for i, t in enumerate(tails):
        follow = t.get("follow", "lock" if t.get("rigid") else "pendulum")
        flag = follow in ("pendulum", "lock") and tail_axis is None
        paths = [_tail_path(ctx, G, t, scalp)]
        if t.get("mirror"):
            paths.append(paths[0] * np.array([-1.0, 1.0, 1.0]))
        for path in paths:
            ST.log("  tail %d (%s): %s" % (i, follow, " ".join("(%.3f %.3f %.3f)" % tuple(q) for q in path)))
            radii = list(t["radii"])
            path = _tail(b, rng, path, radii, t, flag)
            accs = (R.get("accents", []) if i == 0 else []) + list(t.get("accents", []))
            group = follow if flag else "head"
            acc_pieces += [pc + (group,) for pc in _accent_nodes(ctx, path, radii, accs)]
            if flag:
                tail_axis, rigid, radius, lie = list(path), follow == "lock", t.get("radius", 0.03), t.get("lie")
                flag = False
    if not tails and R.get("accents"):
        acc_pieces += [pc + ("head",) for pc in _accent_nodes(ctx, None, [], R["accents"])]
    if bun is not None:
        b.coil(G, bun["radii"], rng, rings=bun.get("rings", 12))
    accents = None
    if acc_pieces:
        acc, zones, piece = H.build_objects([(n, node, h, tris, zone, False) for n, node, h, tris, zone, _ in acc_pieces])
        group = np.array([acc_pieces[k][5] for k in piece])
        nv = len(acc.data.vertices)
        pend_v = np.zeros(nv, bool)
        for poly, g in zip(acc.data.polygons, group):
            if g == "pendulum":
                pend_v[list(poly.vertices)] = True
        W = np.zeros((nv, len(ctx.bones)))
        W = H.rigid_zone(W, pend_v, H.QUEUE_HELPER, ctx.bones)
        W = H.rigid_zone(W, ~pend_v, "headb", ctx.bones)
        reg = {"pendulum": RG.HAIR_ZONES["queue"], "lock": RG.HAIR_ZONES["lock"], "head": RG.HAIR_ZONES["crown"]}
        accents = Surface(acc, zones=zones, regions=np.array([reg[g] for g in group]), weights=W)
    h = spec.extra.setdefault("hair", {})
    h.setdefault("strand_map", ST.ATLAS)
    h["builder"] = "hair v3 recipe"
    return ST.finish(ctx, spec, b, tail_axis=tail_axis, tail_radius=radius, accents=accents, domain=mask_dom,
                     tail_rigid="headb" if rigid else None, lie=lie)
