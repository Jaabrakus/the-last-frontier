"""Center-seam puckered moccasins with ankle flaps.

Costume bible §2.2 / §2.6 `moccasins_puckered` (grade A): deerskin, "mostly made of a
single piece with a gathering seam along the top of the foot" and a heel seam, with flaps
tied round the ankle [P3]; puckered-toe styles were preferred, with wool liners in winter
[M2]. Soft sole (no heel). The flaps stand off the ankle enough to go over the leggings'
lower end (legwear band 12-19 mm).

Surface: main (zone 0 buckskin, 1 ankle thong).
"""

import math

import numpy as np

from garments.frontier import _frontier_common as FC
from lib.catalog import GarmentSpec, Zone
from lib.pipeline import Surface, garment_body_weights
from lib.remesh import join, material, mesh_arrays, sdf_object
from lib.sdf import (Ellipsoid, Fn, Inter, Offset, Onion, RoundCone, Sub, Union, frame_from, lerp, nrm, peval, smoothstep,
                     v3, zslab)
from lib.weights import limit_normalize, mesh_adjacency, smooth_weights

SPEC = GarmentSpec(
    id="moccasins_puckered", name="Center-seam moccasins", slot="feet", set="frontier",
    description=("Soft-soled deerskin moccasins of one piece, gathered along a seam over the top of the foot, "
                 "with flaps folded down round the ankle and tied with a thong."),
    layer={"default": 40}, weights="body",
    zones=[Zone(0, "leather", "SUEDE", ["buckskin_smoked", "buckskin_pale", "leather_brown"], "buckskin_smoked",
                name="deerskin"),
           Zone(1, "leather", "LEA", ["leather_brown", "buckskin_smoked", "logwood_black"], "leather_brown",
                name="thong")],
    evidence="A",
    history=("Deerskin, mostly of a single piece with a gathering seam along the top of the foot and flaps tied round "
             "the ankle (Doddridge); puckered toes were preferred, with wool liners in winter."),
    sources=["P3", "M2", "M11"], budget={"tris_max": 2600},
    tags=["men", "women", "backcountry", "summer", "winter"],
)
SPEC.extra["deform_limits"] = FC.deform_limits(SPEC)

PREVIEW_CENTER, PREVIEW_SCALE = (0.0, -0.02, 0.10), 0.5
TOP_Z = 0.118            # top of the moccasin at the ankle
FLAP = (0.080, 0.121)    # folded-down flaps: bottom edge, fold
FLAP_OFF = (0.0215, 0.0175)   # flap offset from the skin at the bottom / at the fold
UPPER_OFF = 0.0062


def foot_region(K, s):
    A, B = K.side("ankle", s), K.side("ball", s)
    heel = K.side("heel", s)

    def f(X, Y, Z):
        a, b = heel + v3(0, 0.03, 0.03), B + v3(0, -0.09, 0.02)
        ab = b - a
        t = np.clip(((X - a[0]) * ab[0] + (Y - a[1]) * ab[1] + (Z - a[2]) * ab[2]) / (ab @ ab), 0, 1)
        d = np.sqrt((X - a[0] - t * ab[0]) ** 2 + (Y - a[1] - t * ab[1]) ** 2 + (Z - a[2] - t * ab[2]) ** 2)
        return np.maximum(np.maximum(d - 0.09, -Z), (Z - TOP_Z) + 0.0 * X)
    lo = np.minimum(heel, B) - 0.15
    hi = np.maximum(heel, B) + 0.15
    return Fn(f, lo, hi)


def seam_path(upper, K, s, n=9):
    """The centre seam over the top of the foot, from the toe to the instep."""
    A, B = K.side("ankle", s), K.side("ball", s)
    x = A[0] - s * 0.004
    pts = []
    for y in np.linspace(B[1] - 0.075, A[1] - 0.045, n):
        p = FC.ray_hit(upper, v3(x, y, 0.20), v3(0, 0, -1), 0.2)
        if p is not None:
            pts.append(p)
    return np.array(pts)


def build(ctx):
    K = ctx.K
    body_sdf = ctx.body_sdf()
    parts, flaps, thongs, seams = [], [], [], []
    for s in (1, -1):
        upper = Inter(Inter(Offset(body_sdf, UPPER_OFF), foot_region(K, s)), zslab(0.0, TOP_Z), k=0.002)
        sp = seam_path(upper, K, s)
        seams.append(sp)
        ridge = Union([RoundCone(sp[i] + v3(0, 0, 0.001), sp[i + 1] + v3(0, 0, 0.001), 0.0026, 0.0026)
                       for i in range(len(sp) - 1)], k=0.002)
        # puckers: short gathers across the seam, closer together toward the toe
        gathers = []
        for i, t in enumerate(np.linspace(0.02, 0.62, 9)):
            k = t * (len(sp) - 1)
            j = min(int(k), len(sp) - 2)
            c = lerp(sp[j], sp[j + 1], k - j)
            d = nrm(sp[min(j + 1, len(sp) - 1)] - sp[j])
            for side in (1, -1):
                off = np.cross(d, v3(0, 0, 1)) * side * 0.009
                gathers.append(Ellipsoid(c + off + v3(0, 0, -0.001), (0.0085, 0.0022, 0.0028),
                                         frame_from(np.cross(d, v3(0, 0, 1)), d)))
        parts.append(Union([upper, ridge, Union(gathers, k=0.0)], k=0.0025))
        A = K.side("ankle", s)

        def flap_r(X, Y, Z):
            return np.interp(Z, [FLAP[0], FLAP[1]], [FLAP_OFF[0], FLAP_OFF[1]])
        flap = Inter(Onion(Offset(body_sdf, flap_r, r_max=FLAP_OFF[0]), 0.0022), zslab(*FLAP))
        near = Fn(lambda X, Y, Z, A=A: np.sqrt((X - A[0]) ** 2 + (Y - A[1] + 0.005) ** 2) - 0.075,
                  A - 0.12, A + 0.12)
        # two flaps: a narrow gap over the instep
        gap = Fn(lambda X, Y, Z, A=A: np.maximum(np.abs(X - A[0]) - 0.006, (Y - A[1]) + 0.02),
                 A - v3(0.1, 0.15, 0.1), A + v3(0.1, 0.0, 0.1))
        flaps.append(Sub(Inter(flap, near), gap, k=0.002))
        thong = Inter(Onion(Offset(body_sdf, UPPER_OFF + 0.0045), 0.0014), zslab(0.1045, 0.1095))
        thongs.append(Inter(thong, near))
    mocc = Union([Union([parts[0], flaps[0]], k=0.002), Union([parts[1], flaps[1]], k=0.002)], k=0.0)

    def vis(Pt):
        L = np.where(Pt[:, 2] > 0.075, 0.016, 0.019)
        return np.where(peval(body_sdf, Pt) > 0.012, 0.012, L)     # the flaps keep a clean edge
    main = FC.sdf_obj("moccasins_puckered", mocc, 0.0014, 1300, material("moc_tmp", "#a07e55"),
                      sizing=FC.hidden_sizing(vis, 0.03, [body_sdf]), feature_deg=40.0, iters=24, sharp_deg=None)
    FC.log("  moccasins: %d polygons inside the body deleted" % FC.delete_inside(ctx, main))
    th = FC.sdf_obj("moccasin_thong", Union(thongs, k=0.0), 0.0009, 300, material("moct_tmp", "#5b3d26"))
    ob = join([main, th], "moccasins_puckered")
    zones = np.array([p.material_index for p in ob.data.polygons])
    W = garment_body_weights(ctx, ob)
    W = limit_normalize(smooth_weights(W, mesh_adjacency(ob), 1, 0.3))
    C, N, _ = FC.poly_arrays(ob)
    on_flap = peval(body_sdf, C) > 0.012
    openings = (C[:, 2] > TOP_Z - 0.006) | (on_flap & (np.abs(C[:, 2] - FLAP[0]) < 0.004))
    cands = ["ankle_l", "foot_l", "ankle_r", "foot_r"]
    cov = FC.coverage(ctx, ob, W=W, candidates=cands, edge_polys=openings, min_edge=0.01)
    FC.log_coverage(SPEC.id, cov)
    SPEC.hides_regions = FC.pick_hides(cov, need=0.97)
    SPEC.occupies_regions = sorted([n for n, (a, b) in cov.items() if max(a, b) > 0.3], key=lambda n: FC.REGIONS[n])
    # UVs: around the foot's long axis (seam under the sole) and around the shin for the flaps
    parts_uv, part = [], np.zeros(len(C), int)
    for s in (1, -1):
        A, B, H = K.side("ankle", s), K.side("ball", s), K.side("heel", s)
        parts_uv.append(FC.Cyl(v3(A[0], H[1] + 0.03, 0.035), v3(A[0], B[1] - 0.08, 0.03), v3(0, 0, 1)))
        parts_uv.append(FC.Cyl(A + v3(0, 0, -0.05), A + v3(0, 0, 0.1), v3(0, -1, 0), v0=0.2))
        side = np.sign(C[:, 0]) == s
        part[side] = len(parts_uv) - 2
        part[side & (C[:, 2] > FLAP[0] - 0.003) & (np.abs(C[:, 1] - A[1]) < 0.06)] = len(parts_uv) - 1

    def uv_fn(o):
        return FC.part_uvs(o, parts_uv, part)
    V = mesh_arrays(ob)
    d_top = np.maximum(TOP_Z - V[:, 2], 0.0)
    d_seam = np.full(len(V), 1.0)
    for s, sp in zip((1, -1), seams):
        m = np.sign(V[:, 0]) == s
        d_seam[m] = np.min(np.linalg.norm(V[m][:, None, :] - sp[None, :, :], axis=2), axis=1)
    return {"main": Surface(ob, zones=zones, weights=W, uv=uv_fn, edge=(d_top, d_seam))}
