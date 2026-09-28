"""Center-seam moccasins (costume bible §3.2, §3.3; [M11] Six Nations Polytechnic, "Moccasin
Styles"): soft-soled, one piece, a centre seam up the front that gathers ("puckers") the
toe, a heel seam and ankle cuffs. Men's: two separate cuff flaps; women's: one cuff
wrapped all the way round, with small tinkling cones at the ankle [P2][R1]. Quillwork on
the seam and the cuffs, white bead edging (1750s-60s: no raised beadwork, which is
19th-century [M11]).

Built around the body's foot and ankle (lib.body_shapes) with the leather ~2 mm thick,
the upper up to just above the ankle bone, the cuffs folded down over it and flaring a
little. Everything stays inside the legwear envelope at the ankle (leggings go over the
moccasin top). Weights: the nearest body point (foot, ankle, heel, ball), smoothed; the
cones are rigid pieces.
"""

import math

import numpy as np

from lib.body_shapes import foot_shapes, leg_shapes
from lib.remesh import Prims
from lib.sdf import Ellipsoid, Fn, Inter, Offset, Onion, RoundCone, Sub, Union, log, nrm, peval, smoothstep, \
    surface_point, v3, zslab

from garments.woodlands import _common as C

UPPER_OFF = 0.0063          # mid surface of the leather over the skin
LEATHER = 0.0011            # half thickness
CUFF_OFF = 0.0094           # cuff mid surface at the fold
CUFF_FLARE = 0.0050         # extra at the cuff's lower edge
CUFF_H = 0.040              # cuff height (fold -> lower edge)


def top_z(Y):
    """Height of the opening: 0.125 at the back of the heel, 0.104 in front of the ankle."""
    return 0.112 + 0.13 * (Y - 0.050)


def foot_base(K, s):
    """The body's own leg + foot blend (lib.body_shapes.limbs: k = 0.02) below the calf."""
    return Inter(Union([leg_shapes(K, s), foot_shapes(K, s)], k=0.02), zslab(-0.1, 0.20))


def seam_path(node, K, s):
    """Centre seam: up the toe front and along the top of the vamp to the instep."""
    A, B = K.side("ankle", s), K.side("ball", s)
    xs = A[0] - s * 0.004
    c = v3(xs, B[1] - 0.030, 0.022)
    pts = []
    for a in np.radians(np.linspace(-25.0, 85.0, 12)):          # from forward-down, up over the toe
        d = v3(0, -math.cos(a), math.sin(a))
        pts.append(surface_point(node, c + d * 0.12, -d, 0.0, 0.12))
    for y in np.linspace(c[1] + 0.008, A[1] - 0.070, 6):         # along the vamp top
        pts.append(surface_point(node, v3(xs, y, 0.2), v3(0, 0, -1), 0.0, 0.17))
    P = np.array(pts)
    keep = [0]
    for i in range(1, len(P)):
        if np.linalg.norm(P[i] - P[keep[-1]]) > 0.004:
            keep.append(i)
    return P[keep]


def seam_nodes(path, normal_node):
    """Seam ridge (quilled) and the toe puckers across it."""
    ridge = Union([RoundCone(path[i], path[i + 1], 0.0026, 0.0026) for i in range(len(path) - 1)], k=0.002)
    puck = []
    L = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))])
    for t in np.arange(0.004, min(L[-1], 0.075), 0.0065):
        p = np.array([np.interp(t, L, path[:, k]) for k in range(3)])
        q = np.array([np.interp(t + 0.002, L, path[:, k]) for k in range(3)])
        d = nrm(q - p)
        from lib.sdf import sdf_normal
        n = sdf_normal(normal_node, p)
        side = nrm(np.cross(d, n))
        R = np.stack([side, d, n], 1)
        puck.append(Ellipsoid(p - n * 0.0006, (0.0085, 0.0020, 0.0024), R))
    return ridge, Union(puck, k=0.0015)


def cuff_grid(cmid, ax, yc, s, angs, rows=4):
    """Mid-surface points of a cuff (rows from the fold down to the lower edge, columns at
    the angles `angs` round the ankle: 0 = front, 90 = the outer side, 180 = the heel)."""
    P = np.zeros((rows, len(angs), 3))
    for j, a in enumerate(np.radians(angs)):
        d = v3(s * math.sin(a), -math.cos(a), 0.0)
        for i, t in enumerate(np.linspace(0.0, 1.0, rows)):
            y = yc + 0.045 * math.cos(math.pi - a)
            z = top_z(y) + 0.0008 - t * CUFF_H
            o = v3(ax, yc, z)
            P[i, j] = surface_point(cmid, o + d * 0.14, -d, 0.0, 0.14)
    return P


def build_moccasins(ctx, sp, women=False):
    K = ctx.K
    b = C.Builder(sp)
    paths, cmids = {}, {}
    for s, sd in ((1, "l"), (-1, "r")):
        base = foot_base(K, s)
        mid = Offset(base, UPPER_OFF)
        opening = Fn(lambda X, Y, Z: Z - top_z(Y), (-1, -1, -1), (1, 1, 1))
        shell = Inter(Onion(mid, LEATHER), opening)
        path = seam_path(mid, K, s)
        paths[s] = path
        ridge, puck = seam_nodes(path, mid)
        upper = Union([shell, puck], k=0.0012)

        def sizing(P, mid=mid, path=path):
            L = np.where(peval(mid, P) < -0.0004, 0.020, 0.0100)
            d = np.min(np.linalg.norm(P[:, None, :] - path[None, :, :], axis=2), axis=1)
            return np.where(d < 0.008, 0.0048, L)
        b.sdf("upper_" + sd, upper, 0.0013, 760, 0, sizing=None, symmetric=False)
        b.sdf("seam_" + sd, Inter(ridge, Offset(mid, 0.004)), 0.0010, 110, 1, symmetric=False)
        # cuff: folded down from the opening, flaring a little toward its lower edge: a
        # sheet sampled round the ankle (clean edges; the leather is 2 mm thick)
        A = K.side("ankle", s)
        yc = A[1] - 0.004

        def cuff_r(X, Y, Z):
            return CUFF_OFF + CUFF_FLARE * smoothstep(0.0, CUFF_H, top_z(Y) - Z)
        cmid = Offset(base, cuff_r, r_max=CUFF_OFF + CUFF_FLARE)
        cmids[s] = cmid
        if women:
            flaps = [("cuff_" + sd, np.linspace(-180.0, 180.0, 25))]
        else:
            # two flaps, outer and inner side, parted at the front and at the heel seam
            flaps = [("cuff_out_" + sd, np.linspace(26.0, 160.0, 11)), ("cuff_in_" + sd, -np.linspace(26.0, 160.0, 11))]
        for name, angs in flaps:
            P = cuff_grid(cmid, A[0], yc, s, angs)
            out = P - np.array([A[0], yc, 0.0])
            out[..., 2] = 0.0
            C.sheet_piece(b, name, P, 2 * LEATHER, 2, normals=out)
        if women:
            pr = Prims()
            n_cones = 8
            for k in range(n_cones):
                a = math.radians(-150.0 + 300.0 * k / (n_cones - 1))            # round the cuff, not the front
                d = v3(s * math.sin(a), math.cos(a), 0.0)                        # 0 = back ... outward
                zb = top_z(yc + 0.05 * math.cos(a)) - CUFF_H
                o = v3(A[0], yc, zb + 0.004)
                p = surface_point(cmid, o + d * 0.12, -d, 0.0, 0.12) + d * 0.0035
                p[2] = zb - 0.0105
                axis = nrm(v3(0, 0, -1) + d * 0.18)
                pr.cylinder(p, axis, 0.0010, 0.019, segs=8, r2=0.0036)
            b.prims("cones_" + sd, pr, 3)
    bt = b.build(sharp_deg=None)
    ob, V = bt.ob, bt.V

    # UVs: a cylinder along the foot (heel -> toe, seam under the sole) for the upper and
    # the seam, the cuff sheets their own (u round, v down), the cones flat
    maps, part = [], np.zeros(len(ob.data.polygons), int)
    Cp = C.poly_centers(ob)
    for s, sd in ((1, "l"), (-1, "r")):
        A = K.side("ankle", s)
        maps.append(C.Cyl(v3(A[0], 0.11, 0.035), v3(A[0], -0.13, 0.035), v3(0, 0, 1)))
        part[np.sign(Cp[:, 0]) == s] = len(maps) - 1
    cuff_p = np.zeros(len(ob.data.polygons), bool)
    for n in bt.names:
        if n.startswith("cuff"):
            cuff_p |= bt.pmask(n)
    part[cuff_p] = -1
    uv = C.loop_uvs(ob, maps, part, vertex_uv=bt.attrs["uv"])

    # edge distances: x = from the cuff's lower edge (cuffs) or the opening (upper);
    # y = from the centre seam (the quilled vamp band)
    is_cuff = np.zeros(len(V), bool)
    for n in bt.names:
        if n.startswith("cuff"):
            is_cuff |= bt.vmask(n)
    zt = top_z(V[:, 1])
    up = bt.vmask("upper_l", "upper_r")
    top = up & (V[:, 2] > zt - 0.0025)
    d_top = C.dist_from(ob, top)
    d_hem = np.where(is_cuff, np.nan_to_num(bt.attrs["edge"][:, 0], nan=1.0), d_top)
    near_seam = np.zeros(len(V), bool)
    for s in (1, -1):
        P = paths[s]
        d = np.min(np.linalg.norm(V[:, None, :] - P[None, :, :], axis=2), axis=1)
        near_seam |= d < 0.0045
    d_open = C.dist_from(ob, near_seam)

    # weights: nearest body point (foot / ankle), smoothed; cones rigid
    W = C.body_W(ctx, V, torso=False)
    W = C.smooth(ob, W, 4, 0.5)
    if women:
        W = C.pieces_rigid(ob, W, bt.zone_vmask(3))
    W = C.normalize(W)

    # shading: the inner side and the sole darker, the fold of the cuff a little darker
    col = np.ones(len(V))
    col *= np.where(V[:, 2] < 0.012, 0.85, 1.0)
    col[is_cuff] *= 0.92 + 0.08 * smoothstep(0.0, 0.01, zt[is_cuff] - V[is_cuff, 2])
    return C.finish(ctx, sp, bt, W, uv, hide_candidates=["foot_l", "foot_r"], edge=(d_hem, d_open),
                    colors=C.rgba(col), focus=((0.0, -0.01, 0.075), 0.42))
