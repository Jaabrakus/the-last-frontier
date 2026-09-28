"""Accoutrements over the regimental coats (costume bible §5.1-5.2): the British buff cross
belts (the pouch belt over the left shoulder carrying the black cartridge pouch at the right
hip, the bayonet belt over the right shoulder with the frog and scabbard at the left hip)
and the French buff waist belt with its brass buckle, the red leather gargoussier in front
and the bayonet at the left hip.

Belts are the "env40" variant of the design (§5.5): they lie on the regimental coats'
outer form (_coat.outer_form: the same bridged torso and skirt the coats are cut from),
4.5 mm off it, so they clear the lapels and buttons. Worn without a coat they stand off the
waistcoat by about 1.5 cm (an env20 variant is future work).

Weights (build_body's leather bands): every vertex takes the weights of the band's CENTRE
LINE (so the leather keeps its width), leg and skirt bones moved to the pelvis (the ends at
the hips stay on the torso like stiff leather), Gaussian-averaged along the band and put on
two spine-chain bones (lib.weights band_smooth / chain_weights). The pouch and gargoussier
are rigid on the pelvis; the bayonet scabbard takes the coat skirt's weights at its middle
(it hangs against the skirt and swings with it). Zones: 0 buff leather, 2 black / red
leather, 3 metal.
"""

import math

import numpy as np

from lib.remesh import join, material, mesh_arrays, sdf_object
from lib.sdf import Fn, Inter, Offset, RoundBox, RoundCone, Union, frame_from, log, nrm, peval, smoothstep, v3, zslab
from lib.weights import band_smooth, chain_weights, limit_normalize

from . import _base as B
from . import _coat as C
from ._trims import Trims, hit

BELT_OFF = 0.0045          # outer surface of the band above the coat's outer surface
BELT_THICK = 0.0025
STRAP_HALF = 0.029         # 2.25-inch buff shoulder belts
WAIST_Z = (0.925, 0.975)   # French waist belt (5 cm)


def coat_form(ctx, style="br"):
    st = C.BRITISH_1751 if style == "br" else C.FRENCH_MARINE
    return C.outer_form(ctx, st, neck=False)


def strap_path(form, s, n=72):
    """Centre line of the belt over the s shoulder to the opposite hip, round the torso
    (build_body.strap_path): the loop where the mid plane through the shoulder top and the
    opposite hip meets `form`."""
    p0 = v3(s * 0.092, 0.02, 1.352)
    p1 = v3(-s * 0.205, 0.005, 0.905)
    nrm_ = nrm(np.cross(p1 - p0, v3(0, 1, 0)))
    a = nrm(np.cross(v3(0, 1, 0), nrm_))
    c0 = 0.5 * (p0 + p1) * v3(1, 0, 1)
    pts = []
    for th in np.linspace(0.0, 2 * np.pi, n, endpoint=False):
        d = a * math.cos(th) + v3(0, 1, 0) * math.sin(th)
        pts.append(hit(form, c0 + d * 0.50, -d, 0.50)[0])
    return np.array(pts)


def poly_nearest(P, path, closed=True):
    """(nearest point on the polyline, distance, arc position) for each point."""
    P = np.asarray(P, float)
    best = np.full(len(P), np.inf)
    Q = np.zeros_like(P)
    S = np.zeros(len(P))
    s0 = 0.0
    m = len(path) if closed else len(path) - 1
    for i in range(m):
        a, b = path[i], path[(i + 1) % len(path)]
        ab = b - a
        L = float(np.linalg.norm(ab))
        t = np.clip(((P - a) @ ab) / max(L * L, 1e-12), 0.0, 1.0)
        q = a + t[:, None] * ab
        d = np.linalg.norm(P - q, axis=1)
        k = d < best
        best[k], Q[k], S[k] = d[k], q[k], s0 + t[k] * L
        s0 += L
    return Q, best, S


def band_weights(ctx, V, centre_fn, band_id):
    """Leather band weights (see the module docstring). centre_fn(V) -> centre points."""
    Cp = centre_fn(V)
    W = B.labels_W(ctx, Cp, ["torso", "neck"])
    W = B.strip_bones(ctx, W, B.LEG_BONES, "pelvis")
    W = band_smooth(W, Cp, band_id)
    W = chain_weights(W, band_id > 0, ctx.bones)
    return limit_normalize(W)


def _skirt_row(ctx, P):
    """The coat skirt's weights at point P (a scabbard hanging against the skirt)."""
    P = np.asarray(P, float)[None]
    W = B.body_W(ctx, P)
    return B.skirt_W(ctx, P, W, np.ones(1, bool), 0.525, 0.80)[0]


def scabbard(ctx, top, side):
    """Bayonet frog and scabbard hanging from `top` at the `side` hip, angled back.
    Returns (object, weights row)."""
    d = nrm(v3(side * 0.10, 0.30, -1.0))
    tip = top + d * 0.36
    body = Union([RoundCone(top + d * 0.03, tip, 0.0125, 0.0065),
                  RoundBox(top + d * 0.012, (0.020, 0.008, 0.030), 0.004, frame_from(d, v3(side, 0, 0)))], k=0.006)
    ob = sdf_object("scabbard", body, 0.0022, 320, material("scabbard", "#1d1b19", 0.6), symmetric=False)
    row = _skirt_row(ctx, top + d * 0.16)
    return ob, tip, d, row


def cross_belts(ctx, spec):
    K = ctx.K
    form = coat_form(ctx, "br")
    tr_leather, tr_metal = Trims(), Trims()
    pieces = []
    paths = {}
    for s, extra in ((1, 0.0028), (-1, 0.0)):        # the pouch belt (left shoulder) lies over the bayonet belt
        mid = Offset(form, BELT_OFF - 0.5 * BELT_THICK + extra)
        path = strap_path(mid, s)
        paths[s] = path
        outer = Offset(form, BELT_OFF + extra)

        def region(X, Y, Z, path=path):
            P = np.stack(np.broadcast_arrays(X, Y, Z), -1).reshape(-1, 3)
            _, d, _ = poly_nearest(P, path)
            return np.maximum(d - STRAP_HALF, 0.915 - P[:, 2]).reshape(np.broadcast(X, Y, Z).shape)
        reg = Fn(region)
        dom = Union([RoundCone(path[i], path[(i + 1) % len(path)], STRAP_HALF + 0.03, STRAP_HALF + 0.03)
                     for i in range(len(path))], k=0.0)

        def siz(P):
            return np.full(len(P), 0.016)
        ob = B.sheet("%s_strap_%d" % (spec.id, s), outer, reg, 0.0026, 900, material("strap", "#e6e0d0"), sizing=siz,
                     feature_deg=40.0, domain=dom)
        B.solidify(ob, BELT_THICK, rim_only=True)

        def w_strap(ctx_, V, path=path, s=s):
            band = np.full(len(V), 2 if s > 0 else 3)
            return band_weights(ctx_, V, lambda P: poly_nearest(P, path)[0], band)
        pieces.append(B.Piece(ob, "cloth", zone=B.CLOTH, uv="attr", weights=w_strap))
        B.set_point_uv(ob, _strap_uv(ob, path))
    # the cartridge pouch at the right hip, behind, where the pouch belt's ends meet
    pouch_c = v3(-0.215, 0.085, 0.845)
    pn = nrm(v3(-0.72, 0.62, 0.0))
    R = frame_from(pn, v3(0, 0, 1))                   # x ~ up, y ~ along the hip, z out
    box = RoundBox(pouch_c, (0.062, 0.100, 0.026), 0.008, R)
    flap = RoundBox(pouch_c + pn * 0.024 + R[:, 0] * 0.012, (0.052, 0.103, 0.004), 0.003, R)
    pouch = sdf_object("pouch", Union([box, flap], k=0.004), 0.0022, 420, material("pouch", "#1d1b19", 0.6),
                       symmetric=False)
    pieces.append(B.Piece(pouch, "rigid", zone=B.LACE, uv=_box_uv(pouch_c, R), weights={"pelvis": 1.0}))
    # regimental badge on the flap (brass) and the belt's buckles at the pouch
    p_badge = pouch_c + pn * 0.030 + R[:, 0] * 0.010
    tr_metal.button(p_badge, pn, r=0.017, h=0.003, segs=10)
    # the bayonet frog and scabbard at the left hip (the bayonet belt's ends)
    sc, tip, d, row = scabbard(ctx, v3(0.206, 0.050, 0.885), 1)
    pieces.append(B.Piece(sc, "rigid", zone=B.LACE, uv=_seg_uv(v3(0.206, 0.05, 0.885), d), weights=_row_dict(ctx, row)))
    chape = sdf_object("chape", RoundCone(tip - d * 0.035, tip + d * 0.004, 0.0078, 0.0055), 0.0015, 90,
                       material("chape", "#b58f4a", 0.4), symmetric=False)
    pieces.append(B.Piece(chape, "rigid", zone=B.METAL, uv="attr", weights=_row_dict(ctx, row)))
    if not tr_metal.empty():
        pieces.append(B.Piece(tr_metal.to_object(spec.id + "_badge"), "rigid", zone=B.METAL, uv="attr",
                              weights={"pelvis": 1.0}))
    return B.assemble(ctx, spec, pieces, smooth=None)


def waist_belt(ctx, spec):
    form = coat_form(ctx, "fr")
    outer = Offset(form, BELT_OFF + 0.0008)
    zc = 0.5 * (WAIST_Z[0] + WAIST_Z[1])
    reg = Fn(lambda X, Y, Z: np.maximum(WAIST_Z[0] - Z, Z - WAIST_Z[1]))
    ob = B.sheet(spec.id + "_band", outer, reg, 0.0025, 900, material("belt", "#e6e0d0"),
                 sizing=lambda P: np.full(len(P), 0.016), feature_deg=40.0, domain=zslab(0.89, 1.01))
    # the arms hang next to the waist: keep only the band round the body
    B.drop_faces(ob, lambda C_: np.abs(C_[:, 0]) > 0.24)
    B.solidify(ob, BELT_THICK, rim_only=True)

    def centre(P):
        Q = np.asarray(P, float).copy()
        Q[:, 2] = zc
        return Q

    def w_band(ctx_, V):
        return band_weights(ctx_, V, centre, np.ones(len(V), int))
    pieces = [B.Piece(ob, "cloth", zone=B.CLOTH, uv="body", weights=w_band)]
    sol = Inter(outer, reg)
    tm = Trims()
    p, n = hit(sol, v3(0.0, -0.30, zc), v3(0, 1, 0), 0.32)
    tm.buckle(p + n * 0.0008, n, v3(0, 0, 1), w=0.056, h=0.050, bar=0.0045, t=0.004)
    pieces.append(B.Piece(tm.to_object(spec.id + "_buckle"), "trim", zone=B.METAL, uv="attr"))
    # the gargoussier: a small curved red leather box on the belt, front right
    gp, gn = hit(outer, v3(-0.095, -0.30, zc - 0.035), v3(0, 1, 0), 0.32)
    R = frame_from(gn, v3(0, 0, 1))
    gc = gp + gn * 0.024
    garg = Union([RoundBox(gc, (0.042, 0.072, 0.021), 0.009, R),
                  RoundBox(gc + gn * 0.019 + R[:, 0] * 0.012, (0.034, 0.075, 0.004), 0.003, R)], k=0.004)
    g_ob = sdf_object("gargoussier", garg, 0.0018, 380, material("garg", "#8e2b21", 0.6), symmetric=False)
    pieces.append(B.Piece(g_ob, "rigid", zone=B.LACE, uv=_box_uv(gc, R), weights={"pelvis": 1.0}))
    # bayonet frog and scabbard at the left hip
    sc, tip, d, row = scabbard(ctx, v3(0.200, 0.045, 0.905), 1)
    pieces.append(B.Piece(sc, "rigid", zone=B.LACE, uv=_seg_uv(v3(0.2, 0.045, 0.905), d), weights=_row_dict(ctx, row)))
    chape = sdf_object("chape", RoundCone(tip - d * 0.035, tip + d * 0.004, 0.0078, 0.0055), 0.0015, 90,
                       material("chape", "#b58f4a", 0.4), symmetric=False)
    pieces.append(B.Piece(chape, "rigid", zone=B.METAL, uv="attr", weights=_row_dict(ctx, row)))
    return B.assemble(ctx, spec, pieces, smooth=None)


# ---------------------------------------------------------------------------
def _row_dict(ctx, row):
    return {ctx.bones[j]: float(row[j]) for j in np.nonzero(row > 1e-4)[0]}


def _strap_uv(ob, path):
    V = mesh_arrays(ob)
    Q, d, S = poly_nearest(V, path)
    return np.stack([d, S], 1)


def _box_uv(c, R):
    def fn(P):
        q = (P - c) @ np.asarray(R)
        return np.stack([q[:, 1], q[:, 0]], 1)
    return fn


def _seg_uv(a, d):
    def fn(P):
        q = P - a
        return np.stack([np.linalg.norm(np.cross(q, d), axis=1), q @ d], 1)
    return fn
