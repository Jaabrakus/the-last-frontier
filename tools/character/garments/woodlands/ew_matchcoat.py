"""Wool blanket worn as a matchcoat (costume bible §3.2, §3.3, §3.8 `ew_matchcoat`).

The word comes from an Algonquian word for a robe: a rectangle of stroud (about 60 x 65
in; blue most common through the century) or a white duffel blanket with coloured end
stripes, wrapped or belted round the body [R3][R17]; dress versions edged with ribbon and
set with brooches [P2][R3]; women's in blue or scarlet cloth, worn over the shoulders or the
head [P2][R1]. Grade A.

This drape (a game choice among the documented ways of wearing it): wrapped round the
hips and belted at the waist, the upper part brought up across the body and over the left
shoulder, front and back, leaving the right arm and shoulder free (a musket or bow arm).
Pieces: the lower wrap (the body hull hanging from the hips, 3-6 cm out: over any shirt,
shift, skirt or breechcloth), the upper part (the torso and the left shoulder cap offset by
the wrap clearance, cut to a diagonal band) and the belt. Weights: the lower wrap the
pelvis and the skirt panels; the upper part the body's (torso-from-torso; the shoulder cap
blends the upper arm); the belt band-averaged on the pelvis.
"""

import math

import numpy as np

from lib.body_shapes import arm_shapes, neck_shape, torso_shapes
from lib.sdf import Fn, Inter, Offset, Sphere, Union, nrm, smoothstep, v3, zslab

from garments.woodlands import _common as C

WOOL = 0.0034                 # a heavy blanket
HEM = 0.52
WRAP_TOP = 0.962
BELT_Z = (0.952, 0.990)
UP_EDGE = ((-0.14, 1.05), (0.13, 1.45))     # the band's upper edge (x, z): below the right armpit, over the left shoulder
BAND_W = 0.25                               # band width, perpendicular to its edges

SPEC = C.spec(
    id="ew_matchcoat", name="Wool blanket (matchcoat)", slot="accessories.wrap", layer={"default": 50},
    description="A stroud or duffel blanket worn as a matchcoat: wrapped round the hips and belted, the upper part "
                "brought across the body and over the left shoulder, leaving the right arm free.",
    history="A rectangle of stroud about 60 x 65 inches, blue most common, or a white duffel blanket with coloured "
            "end stripes, wrapped or belted round the body [R3][R17]; dress versions were edged with ribbon and set "
            "with brooches [P2]. This drape is one way of wearing it, chosen so the arms stay free.",
    zones=[C.WZone(0, "cloth", "WOOL", ["stroud_blue", "stroud_red", "linen_white", "logwood_black"], name="blanket",
                   fabrics=["WOOL", "TWILL"],
                   pattern={"options": ["none", "end_stripes"],
                            "end_stripes": {"colors": ["stroud_blue", "madder_red"], "note": "white duffel blanket",
                                            "axis": "x", "offset": 0.05, "width": 0.03}},
                   bands={"axis": "y", "from": "blanket edges", "rows_max": 3, "row_width": 0.014, "gap": 0.006,
                          "palette": ["ribbon_red", "ribbon_green", "ribbon_yellow", "ribbon_blue", "ribbon_white",
                                      "ribbon_black"], "default": [], "note": "dress edging"}),
           C.WZone(1, "leather", "LEA", ["leather_brown", "buckskin_smoked", "logwood_black"], name="belt")],
    evidence="A", sources=["R3", "R17", "P2", "R1"], budget=6000, tags=["men", "women", "winter"],
    extra={"edge_uv": {"x": "distance from the lower wrap's hem, metres (end stripes)",
                       "y": "distance from the blanket's edges (the upper part's diagonal edges and the lower "
                            "wrap's top), metres (ribbon edging)"}},
)


def wrap_clear(z):
    return float(np.interp(z, [0.45, 0.60, 0.75, 0.88, 0.935, 0.97], [0.060, 0.058, 0.054, 0.046, 0.036, 0.030]))


def wrap_folds(TH, Z):
    a = 0.007 * smoothstep(0.86, HEM, Z)
    return a * (np.sin(6.0 * TH + 1.1) * 0.6 + np.sin(11.0 * TH + 0.2) * 0.4)


def band_n():
    (x0, z0), (x1, z1) = UP_EDGE
    d = nrm(v3(x1 - x0, 0.0, z1 - z0))
    return v3(-d[2], 0.0, d[0]), v3(x0, 0.0, z0)      # normal (up and to the right side), a point


def build(ctx):
    K = ctx.K
    b = C.Builder(SPEC)
    hull = C.Hull(ctx)
    # lower wrap: a closed sheet hanging from the hips
    form = hull.form(wrap_clear, hang_top=0.97, folds=wrap_folds, z_range=(HEM - 0.04, 1.0))
    th = math.pi / 2 + np.linspace(0.0, 2 * math.pi, 44, endpoint=False)
    zs = np.linspace(WRAP_TOP, HEM, 12)
    P = np.array([form.point(th, np.full(len(th), z), extra=-WOOL * 0.5) for z in zs])
    C.sheet_piece(b, "wrap", P, WOOL, 0, closed_u=True)
    # upper part: torso + left shoulder cap offset by the wrap clearance (less under the
    # right arm, where the cloth passes between the arm and the ribs)
    S = K.side("shoulder", 1)
    E = K.side("elbow", 1)
    cap = Union([arm_shapes(K, 1), Sphere(S + v3(0.01, 0.0, 0.01), 0.05)], k=0.02)
    cap = Inter(cap, Fn(lambda X, Y, Z: ((np.stack(np.broadcast_arrays(X, Y, Z), -1) - S) @ nrm(E - S))
                        - 0.42 * np.linalg.norm(E - S), (-1, -1, -1), (1, 1, 3)))
    base = Union([torso_shapes(K, smooth=True), cap], k=0.05)

    def clr(X, Y, Z):
        under_r = smoothstep(-0.09, -0.13, X) * smoothstep(0.98, 1.10, Z)
        return 0.026 - 0.010 * under_r
    solid = Inter(Offset(base, clr, r_max=0.026), zslab(0.93, 1.60))
    n, p0 = band_n()
    Sa, Ea = S, E

    def keep(Cc):
        X, Y, Z = Cc[:, 0], Cc[:, 1], Cc[:, 2]
        s = (Cc - p0) @ n
        ok = (s <= 0.0) & (s >= -BAND_W) & (Z > WRAP_TOP - 0.012)
        neck = np.hypot(X, Y - K["neck"][1]) < 0.095
        ok &= ~(neck & (Z > 1.27))
        # open under the left arm: the cloth there would follow the armpit's skin, which
        # stretches many times over with the arm overhead
        ok &= ~((X > 0.10) & (Z > 0.99) & (Z < 1.235) & (Y > -0.045) & (Y < 0.10))
        t = ((Cc - Sa) @ nrm(Ea - Sa)) / np.linalg.norm(Ea - Sa)
        ok &= ~((X > 0.16) & (t > 0.40))
        return ok
    cuts = [(p0, n, lambda Cc: np.ones(len(Cc), bool)),
            (p0 - n * BAND_W, n, lambda Cc: np.ones(len(Cc), bool)),
            ((0, 0, WRAP_TOP - 0.012), (0, 0, 1), lambda Cc: Cc[:, 2] < WRAP_TOP + 0.02),
            (S + (E - S) * 0.40, nrm(E - S), lambda Cc: Cc[:, 0] > 0.16)]
    b.cloth("upper", solid, 0.003, cuts, keep, 1200, WOOL, 0, symmetric=False, max_edge=0.065)
    # belt over both, at the waist
    bform = hull.form(lambda z: wrap_clear(z) + 0.004, hang_top=0.97, z_range=(0.9, 1.02))
    zb = np.linspace(BELT_Z[1], BELT_Z[0], 3)
    P = np.array([bform.point(th, np.full(len(th), z), extra=0.0) for z in zb])
    C.sheet_piece(b, "belt", P, 0.004, 1, closed_u=True)
    bt = b.build()
    ob, V = bt.ob, bt.V

    wrap, upper, belt = bt.vmask("wrap"), bt.vmask("upper"), bt.vmask("belt")
    part = np.full(len(ob.data.polygons), -1, int)
    part[bt.pmask("upper")] = 0
    uv = C.loop_uvs(ob, [C.torso_cyl(ctx, ref=(0, -1, 0))], part, vertex_uv=bt.attrs["uv"],
                    vertex_uwrap=bt.attrs["uwrap"])
    e = np.nan_to_num(bt.attrs["edge"], nan=1.0)
    s = (V - p0) @ n
    edge_up = upper & ((s > -0.004) | (s < -BAND_W + 0.004))
    d_band = C.dist_from(ob, edge_up)
    d_hem = np.where(wrap, e[:, 0], 1.0)
    top_wrap = np.where(wrap, np.nan_to_num(bt.attrs["uv"][:, 1], nan=1.0), 1.0)
    d_open = np.where(upper, d_band, np.where(wrap, top_wrap, 1.0))

    # weights
    bi = {bn: i for i, bn in enumerate(ctx.bones)}
    W = np.zeros((len(V), len(ctx.bones)))
    W[wrap] = C.panel_W(ctx, V[wrap], lr_width=0.18, pelvis_z=(0.64, 0.84), lr_gain=0.30)
    Wu = C.no_hands(ctx, C.body_W(ctx, V[upper]))
    # the shoulder cap: half the upper arm, half the shoulder girdle (a blanket lying on the
    # shoulder is lifted by the arm but does not turn with it)
    from lib.weights import sleeve_factor
    Vu = V[upper]
    sf = sleeve_factor(Vu, K)[:, None]
    from lib.pipeline import body_weights_at
    Wt = body_weights_at(ctx, Vu, torso_only=np.ones(len(Vu), bool))
    Wu = Wu * (1 - 0.5 * sf) + Wt * (0.5 * sf)
    # the part hanging low on the right side follows the pelvis like the wrap it joins
    tl = smoothstep(1.04, 0.97, V[upper, 2])[:, None]
    Wp = np.zeros_like(Wu)
    Wp[:, bi["pelvis"]] = 1.0
    W[upper] = Wu * (1 - tl) + Wp * tl
    W[belt] = 0.0
    W[belt, bi["pelvis"]] = 1.0
    W = C.smooth(ob, W, 2, 0.4, lock=belt)
    W = C.normalize(W)

    col = np.ones(len(V))
    ang = np.arctan2(V[:, 1] - 0.005, V[:, 0])
    col[wrap] *= 1.0 + 0.10 * np.clip(wrap_folds(ang[wrap], V[wrap, 2]) / 0.007, -1, 1)
    cands = ["pelvis_center", "pelvis_side", "thigh_upper_l", "thigh_upper_r"]
    return C.finish(ctx, SPEC, bt, W, uv, hide_candidates=cands, edge=(d_hem, d_open), colors=C.rgba(col),
                    focus=((0.0, 0.0, 0.95), 1.10))
