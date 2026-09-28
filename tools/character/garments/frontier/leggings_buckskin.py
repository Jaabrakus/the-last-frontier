"""Buckskin leggings with a fringed outside seam, long to the upper thigh (tied up to the
belt), gartered below the knee.

Costume bible §2.2 / §2.6 `leggings_buckskin` (grade B): buckskin leggings are more
typical of the 1770s-80s [R3] (Fort Ticonderoga rejects them for 1758-59 portrayals
[M1][M2]); wool leggings with the flap outside are the grade-A form of the 1750s. With a
breechcloth the frontier leggings were lengthened to the upper thigh and tied to the same
belt, leaving the hip bare [P3]. The seam and its fringe are on the outside of the leg.

Surfaces: main (zone 0 buckskin, 2 garters), fringe (zone 1: cards along the outside seam).
"""

import math

import numpy as np

from garments.frontier import _frontier_common as FC
from lib.body_shapes import leg_shapes
from lib.catalog import GarmentSpec, Zone
from lib.pipeline import Surface, garment_body_weights
from lib.remesh import join, material, mesh_arrays, sdf_object
from lib.sdf import Fn, Inter, Offset, Onion, RoundCone, Sphere, Union, lerp, nrm, peval, smoothstep, v3, zslab
from lib.weights import limit_normalize, mesh_adjacency, smooth_weights

SPEC = GarmentSpec(
    id="leggings_buckskin", name="Buckskin leggings, fringed", slot="legs.over", set="frontier",
    description=("Long leggings of smoked or pale buckskin with the seam and a fringe on the outside of the leg, tied "
                 "up to the belt and gartered below the knee."),
    layer={"default": 30}, weights="body",
    zones=[Zone(0, "leather", "SUEDE", ["buckskin_smoked", "buckskin_pale", "leather_brown"], "buckskin_smoked",
                name="buckskin"),
           Zone(1, "fringe", "SUEDE", ["buckskin_smoked", "buckskin_pale", "leather_brown"], "buckskin_smoked",
                name="fringe"),
           Zone(2, "band", "LEA", ["leather_brown", "madder_red", "stroud_blue", "buckskin_smoked"], "leather_brown",
                name="garters")],
    surfaces={"main": "leggings_buckskin", "fringe": "leggings_buckskin_fringe"},
    evidence="B",
    history=("Buckskin leggings with a fringed side seam belong mostly to the 1770s-80s; in the 1750s wool leggings "
             "with the flap outside were usual. Long leggings were tied to the belt over a breechcloth."),
    sources=["R3", "M1", "M2", "P3"], budget={"tris_max": 3200},
    tags=["men", "women", "backcountry"],
    extra={"fringe": {"surface": "leggings_buckskin_fringe", "shader": "res://assets/character/shaders/fringe.gdshader",
                      "zone": 1}},
)
SPEC.extra["deform_limits"] = FC.deform_limits(SPEC)

BOTTOM = 0.086                  # into the moccasin cuff
TOP_IN, TOP_OUT = 0.728, 0.80   # top edge inside / outside of the thigh
GARTER_Z = (0.394, 0.416)       # 5-7 cm below the knee joint: rigid on the shin (as the legacy garters)
FRINGE = dict(width=0.036, length=0.058, droop=0.45, z0=0.15, z1=0.77)


def legging_radius(X, Y, Z):
    return np.interp(Z, [0.07, 0.14, 0.40, 0.55, 0.70], [0.0145, 0.0135, 0.0142, 0.0152, 0.0162])


def top_z(s, X):
    return TOP_IN + (TOP_OUT - TOP_IN) * smoothstep(0.03, 0.16, X * s)


def seg_dist_b(X, Y, Z, a, b):
    """Distance of broadcastable coordinates to the segment a-b."""
    ab = b - a
    L2 = float(ab @ ab)
    px, py, pz = X - a[0], Y - a[1], Z - a[2]
    t = np.clip((px * ab[0] + py * ab[1] + pz * ab[2]) / L2, 0.0, 1.0)
    return np.sqrt((px - t * ab[0]) ** 2 + (py - t * ab[1]) ** 2 + (pz - t * ab[2]) ** 2)


def leg_node(K, body, s):
    base = Offset(body, legging_radius, r_max=0.0165)
    H, Kn, A = K.side("upper_leg", s), K.side("knee", s), K.side("ankle", s)

    def region(X, Y, Z):
        near_leg = np.minimum(seg_dist_b(X, Y, Z, H + v3(0, 0, 0.05), Kn), seg_dist_b(X, Y, Z, Kn, A)) - 0.13
        return np.maximum(np.maximum(np.maximum(BOTTOM - Z, Z - top_z(s, X)), 0.003 - X * s), near_leg)
    return Inter(base, Fn(region, (min(0, s * 0.35) - 0.01, -0.3, BOTTOM - 0.01), (max(0, s * 0.35) + 0.01, 0.3, TOP_OUT + 0.02)),
                 k=0.003)


def seam_points(node, K, s, zs):
    """Points of the outside seam: the legging surface seen from the outside of the leg."""
    out = []
    for z in zs:
        kn, an, hp = K.side("knee", s), K.side("ankle", s), K.side("upper_leg", s)
        ax = np.interp(z, [an[2], kn[2], hp[2]], [an[0], kn[0], hp[0]])
        ay = np.interp(z, [an[2], kn[2], hp[2]], [an[1], kn[1], hp[1]])
        o = v3(ax + s * 0.3, ay + 0.004, z)
        p = FC.ray_hit(node, o, v3(-s, 0, 0), 0.3)
        if p is not None:
            out.append(p)
    return np.array(out)


def build(ctx):
    K = ctx.K
    body_sdf = ctx.body_sdf()
    legs = [leg_node(K, body_sdf, s) for s in (1, -1)]
    seams, ridges = [], []
    for s, lg in zip((1, -1), legs):
        pts = seam_points(lg, K, s, np.linspace(BOTTOM + 0.01, TOP_OUT - 0.012, 26))
        seams.append(pts)
        n = [nrm(v3(s, 0, 0))] * len(pts)
        rp = [p + v3(s, 0, 0) * 0.0015 for p in pts]
        ridges.append(Union([RoundCone(rp[i], rp[i + 1], 0.0032, 0.0032) for i in range(len(rp) - 1)], k=0.003))
    garters = []
    for s in (1, -1):
        band = Inter(Inter(Onion(Offset(body_sdf, 0.0192), 0.0022), zslab(*GARTER_Z)),
                     Fn(lambda X, Y, Z, s=s: 0.003 - X * s, (-0.4, -0.3, 0.3), (0.4, 0.3, 0.5)))
        kn = K.side("knee", s)
        zc = 0.5 * (GARTER_Z[0] + GARTER_Z[1])
        knot = FC.ray_hit(band, v3(kn[0] + s * 0.3, kn[1] - 0.004, zc), v3(-s, 0, 0), 0.3)
        knot = knot if knot is not None else v3(kn[0] + s * 0.05, kn[1], zc)
        tie = Union([Sphere(knot + v3(s * 0.002, 0, 0), 0.0065),
                     RoundCone(knot, knot + v3(s * 0.001, -0.007, -0.034), 0.0034, 0.0025),
                     RoundCone(knot, knot + v3(s * 0.001, 0.008, -0.030), 0.0034, 0.0025)], k=0.003)
        garters.append(Union([band, tie], k=0.003))
    leg_all = Union([Union([legs[0], ridges[0]], k=0.003), Union([legs[1], ridges[1]], k=0.003)], k=0.0)
    gar_all = Union(garters, k=0.0)

    def vis(Pt):
        rim = np.minimum(np.abs(Pt[:, 2] - BOTTOM), np.abs(Pt[:, 2] - top_z(np.sign(Pt[:, 0]), Pt[:, 0])))
        L = np.where(Pt[:, 2] < 0.14, 0.019, 0.031)
        return 0.013 + (L - 0.013) * smoothstep(0.003, 0.02, rim)
    main = FC.sdf_obj("leggings_buckskin", leg_all, 0.0022, 2000, material("lb_tmp", "#a07e55"),
                      sizing=FC.hidden_sizing(vis, 0.05, [body_sdf]), feature_deg=35.0, iters=26, sharp_deg=None)
    FC.log("  leggings: %d polygons inside the body deleted" % FC.delete_inside(ctx, main))
    gar = FC.sdf_obj("leggings_garters", gar_all, 0.0012, 280, material("lbg_tmp", "#5b3d26"), sharp_deg=45)
    ob = join([main, gar], "leggings_buckskin")
    is_g_poly = np.array([p.material_index for p in ob.data.polygons]) == 1
    V = mesh_arrays(ob)
    W = garment_body_weights(ctx, ob)
    W = limit_normalize(smooth_weights(W, mesh_adjacency(ob), 1, 0.3))
    is_g = np.zeros(len(V), bool)
    for p in ob.data.polygons:
        if is_g_poly[p.index]:
            is_g[list(p.vertices)] = True
    W[is_g] = 0.0
    W[is_g & (V[:, 0] >= 0), ctx.bones.index("l_knee")] = 1.0
    W[is_g & (V[:, 0] < 0), ctx.bones.index("r_knee")] = 1.0
    # hides: coverage of the leg regions (the top edge and the bottom are openings)
    C, N, _ = FC.poly_arrays(ob)
    openings = (np.abs(C[:, 2] - BOTTOM) < 0.004) | (np.abs(C[:, 2] - top_z(np.sign(C[:, 0]), C[:, 0])) < 0.006)
    cands = [n for n in FC.REGION_LIST if FC.region_group(n) in ("thighs", "shins")]
    cov = FC.coverage(ctx, ob, W=W, candidates=cands, edge_polys=openings, min_edge=0.012)
    FC.log_coverage(SPEC.id, cov)
    SPEC.hides_regions = FC.pick_hides(cov)
    SPEC.occupies_regions = sorted([n for n, (a, b) in cov.items() if max(a, b) > 0.3], key=lambda n: FC.REGIONS[n])
    zones = np.where(is_g_poly, 2, 0)
    # UVs: around the thigh and the shin, the seam (u = +-pi r) on the outside
    parts, part = [], np.zeros(len(C), int)
    for s in (1, -1):
        H, Kn, A = K.side("upper_leg", s), K.side("knee", s), K.side("ankle", s)
        inward = v3(-s, 0, 0)
        parts.append(FC.Cyl(H, Kn, inward))
        parts.append(FC.Cyl(Kn, A, inward, v0=float(np.linalg.norm(Kn - H))))
        side = np.sign(C[:, 0]) == s
        part[side & (C[:, 2] >= Kn[2])] = len(parts) - 2
        part[side & (C[:, 2] < Kn[2])] = len(parts) - 1

    def uv_fn(o):
        return FC.part_uvs(o, parts, part)
    # edge: x = height above the bottom, y = distance from the outside seam
    d_bot = np.maximum(V[:, 2] - BOTTOM, 0.0)
    d_seam = np.full(len(V), 1.0)
    for s, pts in zip((1, -1), seams):
        m = np.sign(V[:, 0]) == s
        d = np.min(np.linalg.norm(V[m][:, None, :] - pts[None, :, :], axis=2), axis=1)
        d_seam[m] = d
    col = np.ones((len(V), 4))
    # fringe along each outside seam, strands running out from the seam and drooping
    cards = []
    for s, pts in zip((1, -1), seams):
        zz = np.arange(FRINGE["z0"], FRINGE["z1"], FRINGE["width"] * 0.85)
        seam_z = pts[:, 2]
        roots = np.stack([np.interp(zz, seam_z, pts[:, k]) for k in range(3)], 1) + v3(s, 0, 0) * 0.003
        out = np.tile(v3(s, 0, 0), (len(roots), 1))
        fwd = np.tile(v3(0, -1, 0), (len(roots), 1))
        rng = np.random.default_rng(21 if s > 0 else 22)
        for p, o, n in zip(roots, out, fwd):
            L = FRINGE["length"] * (0.85 + 0.3 * rng.random())
            pts_c = [p + o * L * t + v3(0, 0, -1) * FRINGE["droop"] * L * t * t for t in np.linspace(0, 1, 4)]
            cards.append(FC.Card(pts_c, [FRINGE["width"]] * 4, n))
    fob, fh, fcidx = FC.fringe_object("leggings_buckskin_fringe", cards, seed=31)
    roots = np.array([c.P[0] for c in cards])
    fW = FC.rigid_card_weights(ob, W, roots, fcidx)
    FC.log("  leggings: %d fringe cards" % len(cards))
    return {"main": Surface(ob, zones=zones, weights=W, uv=uv_fn, colors=col, edge=(d_bot, d_seam)),
            "fringe": Surface(fob, zones=np.ones(len(fob.data.polygons), int), h=fh, weights=fW)}
