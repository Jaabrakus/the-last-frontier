"""Shared pieces of the hair styles (tools/character/hair/<style_id>.py).

A hair style is a glb with the full Actor_B joint list: surface "<id>" (opaque cap,
tails, braids, wraps: zone 0 hair, 1 accent = ribbon / wrap / cord / garter, 2 metal)
and optionally "<id>_cards" (alpha strands: loose ends, tufts, flyaways).

Regions (hide mask ids, lib/regions.HAIR_ZONES): crown 48 (above the hat band plane),
sides 49 and back 50 (below it, in front of / behind the ears), queue 51 (anything on
the pendulum), lock 52 (the crown lock). A hat lists the zones it covers in
hides_hair_zones (tricorn: crown; head wrap: crown, sides, back).

Weights: the cap copies the head / neck weights of the nearest body point (smoothed); a
queue, club or braid below QUEUE_ROOT (the ribbon wrap at the nape) hangs on the
pendulum bone (lib/helpers QUEUE_HELPER, driven by CharacterBodyMesh), with a soft root
and the head -> neck field between the cap and the wrap (as the legacy queue).
UVs follow the combing direction: u across the strands, v along them, in metres.
"""

import math

import numpy as np

from lib import regions as RG
from lib import uv as UV
from lib.cards import Card, cards_object
from lib.helpers import QUEUE_HELPER, QUEUE_ROOT
from lib.pipeline import Surface, body_weights_at
from lib.remesh import join, material, mesh_arrays, sdf_object
from lib.sdf import (Ellipsoid, Fn, Inter, Offset, RoundBox, RoundCone, Sphere, Sub, Union, lerp, nrm, peval,
                     smoothstep, surface_point, v3)
from lib.weights import mesh_adjacency, queue_weights, seg_dist, smooth_weights, transfer_from_tris

ZONE_COLORS = ["#3b2718", "#1c1b20", "#c8cacc"]      # preview colours: hair, accent, metal
CROWN_P = v3(0, -0.03, 1.545)                         # hat band plane (crown above it)
CROWN_N = nrm(v3(0, -0.12, 1.0))
BACK_Y = 0.015                                        # sides | back (the ears are at y ~ 0)
ROOT = v3(*QUEUE_ROOT)


def mats():
    return [material("hair_z%d" % i, h, 0.6, 1.0 if i == 2 else 0.0) for i, h in enumerate(ZONE_COLORS)]


def cranium(K):
    return Ellipsoid(K["headb"] + v3(0, -0.027, 0.061), (0.074, 0.098, 0.092))


def ears(K, r=0.026):
    hb = K["headb"]
    return Union([Sphere(v3(s * 0.075, hb[1] + 0.004, hb[2] + 0.018), r) for s in (1, -1)], 0)


def hairline(p0=(0, -0.108, 1.528), n=(0, 0.13, 0.18)):
    """Half space behind / above the front hairline plane (legacy: through the forehead,
    reaching the nape at z ~ 1.40)."""
    p0, n = v3(*p0), nrm(v3(*n))
    return Fn(lambda X, Y, Z: -((Y - p0[1]) * n[1] + (Z - p0[2]) * n[2]), (-0.2, -0.3, 1.3), (0.2, 0.3, 1.7))


def head_base(K, ears=True):
    """The body's head and neck (as body_node blends them): the cap is offset from the real
    skin, so a thin hairline never sinks into the blended forehead or nape. ears=False: the head
    without its ears (a cap offset from the ears keeps a shell of them outside the ear carve)."""
    from lib.body_shapes import BodyParams, head_shapes, neck_shape
    P = BodyParams.female()
    if not ears and P.head_model == 2:
        from lib import face as FC
        return Union([neck_shape(K), FC.head_node(K, P.face, ears=False)], k=0.03)
    return Union([neck_shape(K), head_shapes(K, P)], k=0.03)


def cap_node(K, off=0.0075, line=None, part=False, extra=(), ear_r=0.026, k=0.004, edge=0.0028, feather=None,
             profile=None, profile_max=1.0, ear_shell=True):
    """Hair cap: the head offset by `off`, thinning to `edge` over `feather` metres toward
    the hairline (a soft hairline instead of a helmet edge), cut at the hairline, the ears
    left free. part: a shallow centre parting groove from the forehead to the crown.
    profile: fn(X, Y, Z) -> factor on `off` (at most profile_max): hair longer on the crown than
    at the sides and nape (a crop cut close at the sides). ear_shell=False offsets the head
    without its ears (no shell of the ears left outside the ear carve; the styles of 2026-09-26
    use it, the older styles keep their built shape). Note: a thick cap whose hairline runs low
    behind the ear stands off the neck there (apparently head_base blends the neck in more fully
    than the body's skin) and reads as a dark flap behind the ear (hair_cropped_1758); a higher
    nape hairline avoids it (hair_siamese_crop)."""
    line = line or hairline()
    feather = feather or max(0.03, 3.0 * off)

    def thick(X, Y, Z):
        s = -line.f(X, Y, Z)                  # distance behind the hairline plane
        o = off if profile is None else off * profile(X, Y, Z)
        return edge + (o - edge) * smoothstep(0.0, feather, s)
    cap = Inter(Offset(head_base(K, ears=ear_shell), thick, r_max=off * (1.0 if profile is None else profile_max)), line,
                k=k)
    for e in extra:
        cap = Union([cap, e], k=0.012)
    cap = Sub(cap, ears(K, ear_r), k=0.006)
    if part:
        hb = K["headb"]
        groove = RoundBox(hb + v3(0, -0.075, 0.150), (0.0018, 0.055, 0.03), 0.0015)
        cap = Sub(cap, groove, k=0.0035)
    return cap


def flat_chain(points, radii, width_scale):
    """A chain of round cones flattened across (x wider by width_scale): a flat club."""
    base = chain([np.asarray(p, float) * np.array([1.0 / width_scale, 1, 1]) for p in points], radii, k=0.002)
    P = np.asarray(points, float)
    lo = P.min(0) - max(radii) * np.array([width_scale, 1, 1]) - 0.02
    hi = P.max(0) + max(radii) * np.array([width_scale, 1, 1]) + 0.02
    return Fn(lambda X, Y, Z: peval(base, np.stack(np.broadcast_arrays(X / width_scale, Y, Z), -1).reshape(-1, 3))
              .reshape(np.broadcast(X, Y, Z).shape), lo, hi)


def chain(points, radii, k=0.006):
    return Union([RoundCone(points[i], points[i + 1], radii[i], radii[i + 1]) for i in range(len(points) - 1)], k=k)


def back_path(body_sdf, zs, clearance, x=0.0, y_from=0.35):
    """Points behind the body's back (the skin found from behind at each height) moved out by
    `clearance`: the centre line of a braid or club hanging down the back."""
    out = []
    for z in zs:
        p = surface_point(body_sdf, v3(x, y_from, z), v3(0, -1, 0), 0.0, y_from + 0.1)
        out.append(p + v3(0, clearance, 0))
    return np.array(out)


def braid_node(path, r0, r1, period=0.036):
    """Three-strand braid along `path` (radius r0 at the root -> r1 at the end): three
    strands weaving in figure-eights, strand k at side A sin(w t + 2 pi k / 3) and depth
    B sin(2 (w t + 2 pi k / 3)), one full cycle every `period` metres."""
    P = np.asarray(path, float)
    seg = np.linalg.norm(np.diff(P, axis=0), axis=1)
    L = seg.sum()
    s = np.concatenate([[0.0], np.cumsum(seg)])

    def at(t):
        return np.array([np.interp(min(max(t, 0.0), L), s, P[:, k]) for k in range(3)])
    n = max(int(L / period * 10), 8)
    strands = []
    for k in range(3):
        pts, rad = [], []
        for i in range(n + 1):
            t = L * i / n
            c = at(t)
            d = nrm(at(t + 0.004) - at(t - 0.004))
            side = np.cross(d, v3(0, 1, 0))
            side = nrm(side) if np.linalg.norm(side) > 1e-6 else v3(1, 0, 0)
            depth = np.cross(side, d)
            R = r0 + (r1 - r0) * t / L
            ph = 2 * math.pi * t / period + 2 * math.pi * k / 3
            pts.append(c + side * (0.46 * R * math.sin(ph)) + depth * (0.22 * R * math.sin(2 * ph)))
            rad.append(0.56 * R)
        strands.append(chain(pts, rad, k=0.0015))
    core = chain([P[0], at(L * 0.5), P[-1]], [r0 * 0.55, (r0 + r1) * 0.27, r1 * 0.55], k=0.003)
    return Union([core] + strands, k=0.0015)


def wrap_band(a, b, r, length, center_t, thick=0.0016):
    """A flat band (ribbon, garter, sinew) wrapped round the a -> b axis at center_t."""
    ax = nrm(b - a)
    c = lerp(a, b, center_t)

    def f(X, Y, Z):
        px, py, pz = X - c[0], Y - c[1], Z - c[2]
        t = px * ax[0] + py * ax[1] + pz * ax[2]
        qx, qy, qz = px - ax[0] * t, py - ax[1] * t, pz - ax[2] * t
        rr = np.sqrt(qx * qx + qy * qy + qz * qz)
        return np.maximum(np.abs(rr - r) - thick, np.abs(t) - length * 0.5)
    return Fn(f, c - (r + length + 0.01), c + (r + length + 0.01))


def build_objects(pieces, sizing=None):
    """[(name, node, h, target_tris, zone, symmetric)] -> (joined object, zone per polygon,
    piece index per polygon). Pieces are joined in order (the first piece's polygons first)."""
    M = mats()
    obs, zones, piece = [], [], []
    for i, (name, node, h, tris, zone, sym) in enumerate(pieces):
        ob = sdf_object(name, node, h, tris, M[zone], sizing=sizing if zone == 0 else None, symmetric=sym,
                        sharp_deg=None)
        obs.append(ob)
        zones += [zone] * len(ob.data.polygons)
        piece += [i] * len(ob.data.polygons)
    ob = join(obs, pieces[0][0]) if len(obs) > 1 else obs[0]
    assert len(ob.data.polygons) == len(zones)
    return ob, np.array(zones), np.array(piece)


# ---------------------------------------------------------------------------
# regions
# ---------------------------------------------------------------------------
def cut_zone_borders(ob):
    RG.cut_planes(ob, [("crown", CROWN_P, CROWN_N, lambda C, lab: np.ones(len(C), bool)),
                       ("back", v3(0, BACK_Y, 0), v3(0, 1, 0),
                        lambda C, lab: ((C - CROWN_P) @ CROWN_N) < 0.004)],
                  lambda C: np.array(["hair"] * len(C)), tol=0.0015)


def cap_regions(C, queue=None, lock=None):
    """Region id per polygon centroid: crown / sides / back; queue and lock masks override."""
    r = np.where(((C - CROWN_P) @ CROWN_N) > 0, RG.HAIR_ZONES["crown"],
                 np.where(C[:, 1] > BACK_Y, RG.HAIR_ZONES["back"], RG.HAIR_ZONES["sides"]))
    if queue is not None:
        r[np.asarray(queue, bool)] = RG.HAIR_ZONES["queue"]
    if lock is not None:
        r[np.asarray(lock, bool)] = RG.HAIR_ZONES["lock"]
    return r


def poly_centers(ob):
    return np.array([p.center for p in ob.data.polygons], float)


# ---------------------------------------------------------------------------
# UVs along the combing direction
# ---------------------------------------------------------------------------
def sphere_flow(center, pole, ref, radius=0.09):
    """Segment-like mapping on the cap: v = angular distance from the pole's antipode
    (strands run from there toward the pole, e.g. the queue root), u = azimuth."""
    center, pole = np.asarray(center, float), nrm(pole)
    ref = nrm(np.asarray(ref, float) - pole * (np.asarray(ref, float) @ pole))
    other = np.cross(pole, ref)

    class _M:
        name = "sphere"

        def map(self, P):
            q = P - center
            q = q / np.maximum(np.linalg.norm(q, axis=1, keepdims=True), 1e-9)
            polar = np.arccos(np.clip(q @ (-pole), -1, 1))        # 0 at the antipode
            ang = np.arctan2(q @ other, q @ ref)
            return ang * radius, polar * radius, ang
    m = _M()
    m.radius = radius
    return m


def flow_uvs(ob, parts, part_of_poly):
    return UV.segment_uvs(ob, parts, part_of_poly)


# ---------------------------------------------------------------------------
# weights
# ---------------------------------------------------------------------------
def cap_weights(ctx, ob, smooth=6, scalp_beyond=None):
    """Nearest body point (head / neck), smoothed so the nape never frays. scalp_beyond
    (metres, thick caps): a vertex farther than that off the head and neck takes, blended
    over 1.2 cm, the weights of the cranium point under it instead, so a volume of hair
    behind the neck moves with the head rather than stretching with the neck."""
    V = mesh_arrays(ob)
    W = body_weights_at(ctx, V)
    if scalp_beyond is not None:
        d = peval(head_base(ctx.K), V)
        cr = cranium(ctx.K)
        h = 4e-4
        g = np.stack([(peval(cr, V + e * h) - peval(cr, V - e * h)) / (2 * h) for e in np.eye(3)], 1)
        g /= np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-9)
        Ws = body_weights_at(ctx, V - g * peval(cr, V)[:, None])
        t = smoothstep(scalp_beyond, scalp_beyond + 0.012, d)
        W = W * (1 - t[:, None]) + Ws * t[:, None]
    return smooth_weights(W, mesh_adjacency(ob), smooth, 0.5)


def axis_param(V, axis_pts):
    """(arc length along the polyline of the nearest axis point, distance to the axis)."""
    A = [np.asarray(p, float) for p in axis_pts]
    best_d = np.full(len(V), np.inf)
    s_out = np.zeros(len(V))
    s0 = 0.0
    for i in range(len(A) - 1):
        a, b = A[i], A[i + 1]
        ab = b - a
        L = float(np.linalg.norm(ab))
        t = np.clip(((V - a) @ ab) / max(L * L, 1e-12), 0.0, 1.0)
        d = np.linalg.norm(V - (a + t[:, None] * ab), axis=1)
        m = d < best_d
        best_d[m] = d[m]
        s_out[m] = s0 + t[m] * L
        s0 += L
    return s_out, best_d


def tail_weights(ctx, ob, W, axis_pts, radius, in_tail=None, soft=0.022, neck_field=True, lie=None):
    """The queue / club / braid below QUEUE_ROOT on the pendulum (soft root `soft` above the
    wrap); between the cap and the wrap the z-based head -> neck field (legacy queue).
    lie = (s0, s1, rest): a long tail lies on the back: from s0 to s1 metres along the axis
    its pendulum share drops to `rest`, the remainder following the upper back (the torso
    weights of the nearest body point), so it keeps its clearance when the spine curves
    instead of swinging out rigidly with the torso's top."""
    V = mesh_arrays(ob)
    bones = ctx.bones
    bi = {b: i for i, b in enumerate(bones)}
    hb = ctx.K["headb"]
    # the axis runs on past the tail's end (tufts, blunt ends) so nothing there is left on
    # the body's weights while the tail swings
    A = [np.asarray(p, float) for p in axis_pts]
    axis_pts = A + [A[-1] + nrm(A[-1] - A[-2]) * 0.06]
    s_ax, d = axis_param(V, axis_pts)
    near = d < radius if in_tail is None else np.asarray(in_tail, bool)
    W = W.copy()
    if neck_field:
        u = smoothstep(hb[1] + 0.045, hb[1] + 0.065, V[:, 1]) * (near & (V[:, 2] < 1.47))
        W = W * (1 - u[:, None]) + queue_weights(V, bones) * u[:, None]
    pq = smoothstep(ROOT[2] + soft, ROOT[2] + 0.002, V[:, 2]) * (near & (V[:, 1] > 0.045))
    pend = np.ones(len(V))
    if lie is not None:
        s0, s1, rest = lie
        pend = 1.0 - (1.0 - rest) * smoothstep(s0, s1, s_ax)
    back = pq * (1.0 - pend)
    W = W * (1 - pq[:, None])
    idx = np.nonzero(back > 1e-4)[0]
    if len(idx):
        W[idx] += body_weights_at(ctx, V[idx], torso_only=np.ones(len(idx), bool)) * back[idx, None]
    W[:, bi[QUEUE_HELPER]] += pq * pend
    return W, pq


def rigid_zone(W, mask, bone, bones):
    W = W.copy()
    W[mask] = 0.0
    W[mask, bones.index(bone)] = 1.0
    return W


def cards_weights(main_ob, W_main, cards_ob, card_of_vertex=None):
    """Card weights: each card moves as one piece with the weights of the main surface at
    its root (the nearest main vertex to the card's first point), so thin strands never
    stretch between bones."""
    Vm = mesh_arrays(main_ob)
    Vc = mesh_arrays(cards_ob)
    if card_of_vertex is None:
        me = main_ob.data
        me.calc_loop_triangles()
        tris = np.array([t.vertices[:] for t in me.loop_triangles], int)
        Wc, _ = transfer_from_tris(Vm, tris, W_main, Vc)
        return Wc
    Wc = np.zeros((len(Vc), W_main.shape[1]))
    for c in np.unique(card_of_vertex):
        idx = np.nonzero(card_of_vertex == c)[0]
        root = Vc[idx[:2]].mean(0)             # the first two vertices are the root edge
        j = int(np.argmin(np.linalg.norm(Vm - root, axis=1)))
        Wc[idx] = W_main[j]
    return Wc


def hair_cards(name, cards):
    M = mats()
    ob, h, cidx = cards_object(name, cards, M[0])
    return ob, h, cidx


def strand_cards_on_tail(axis_pts, count, length_frac, radius, width=0.006, seed=3, spread=0.4, start=0.35):
    """Loose strand cards over the lower part of a tail: roots on the tail surface, lying
    along it and fanning out a little at the ends."""
    rng = np.random.default_rng(seed)
    P = np.asarray(axis_pts, float)
    seg = np.linalg.norm(np.diff(P, axis=0), axis=1)
    s = np.concatenate([[0.0], np.cumsum(seg)])
    L = s[-1]
    cards = []
    for i in range(count):
        t0 = (start + rng.random() * (1 - start - 0.05)) * L
        c0 = np.array([np.interp(t0, s, P[:, k]) for k in range(3)])
        t1 = min(t0 + length_frac * L * (0.6 + 0.8 * rng.random()), L * 1.12)
        ang = rng.random() * 2 * math.pi
        pts = []
        for j in range(5):
            tt = t0 + (t1 - t0) * j / 4
            c = np.array([np.interp(min(tt, L), s, P[:, k]) for k in range(3)])
            if tt > L:
                c = c + nrm(P[-1] - P[-2]) * (tt - L)
            off = v3(math.cos(ang), 0.35 * math.sin(ang), 0) * radius * (1.0 + spread * j / 4)
            off[1] = abs(off[1]) + radius * 0.3
            pts.append(c + off)
        cards.append(Card(pts, np.linspace(width, width * 0.35, 5), v3(0, 1, 0), twist=0.0))
    return cards


# ---------------------------------------------------------------------------
# one-call assembly of a style
# ---------------------------------------------------------------------------
def gathered_uvs(ob, K, tail_axis=None, tail_mask=None, pole=None, tail_radius=0.02):
    """Cap strands converge at `pole` (default: the queue root); polygons in tail_mask map
    along the tail axis (root -> end)."""
    hb = K["headb"]
    c = hb + v3(0, -0.027, 0.061)
    pole = nrm((ROOT if pole is None else np.asarray(pole, float)) - c)
    parts = [sphere_flow(c, pole, v3(0, 0, 1))]
    part = np.zeros(len(ob.data.polygons), int)
    if tail_axis is not None:
        A = np.asarray(tail_axis, float)
        parts.append(UV.Segment("tail", A[0], A[-1], v3(0, 1, 0), tail_radius))
        part[np.asarray(tail_mask, bool)] = 1
    return flow_uvs(ob, parts, part)


def finish_style(ctx, spec, main, zones, W, regions, uv, cards=None, cards_regions=None):
    """{surface: Surface} for the pipeline: main (+ cards, weighted like the nearest main
    triangle)."""
    out = {"main": Surface(main, zones=zones, regions=regions, weights=W, uv=uv)}
    if cards:
        cob, h, cidx = hair_cards(spec.id + "_cards", cards)
        Wc = cards_weights(main, W, cob, cidx)
        if cards_regions is None:
            cards_regions = cap_regions(poly_centers(cob))
        out["cards"] = Surface(cob, zones=np.zeros(len(cob.data.polygons), int), regions=cards_regions, h=h,
                               weights=Wc)
    return out
