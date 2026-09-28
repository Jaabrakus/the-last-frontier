"""Wool leggings (costume bible §3.2, §3.3, §7): stroud cloth sewn into a tube with the seam
allowance left as a flap standing out on the OUTSIDE of the leg [M1][P3], edged with
ribbon or beads [P1]; gartered below the knee with finger-woven or quilled garters [P1].
Men's are thigh-high (tied to the belt), women's knee-high "from the knees, into the mouth
of the moccasins" [P4] with the edge bound in silk and beads [R1].

Tube: the body offset by the legwear clearance (14-20 mm; lib.layers "legwear" 12-19 mm),
a 2.4 mm wool shell, open at the top and over the instep. Flap: a solid strip along the
outer side, weighted row by row like the leg under its root (it bends with the knee and
never flares; design §7). Garters: rigid on the shin, as the legacy garters.
"""

import math

import numpy as np

from lib.sdf import Fn, Inter, Offset, Onion, RoundCone, Sphere, Union, nrm, peval, smoothstep, surface_point, v3, zslab

from garments.woodlands import _common as C

WOOL = 0.0012                 # half thickness of the stroud shell
FLAP_T = 0.0024               # flap thickness (two layers of cloth)
GARTER_Z = (0.394, 0.416)     # below the knee joint (z 0.468): rigid on the shin


def radius_m(X, Y, Z):
    return np.interp(Z, [0.07, 0.10, 0.15, 0.40, 0.55, 0.66, 0.82], [0.0200, 0.0185, 0.0146, 0.0146, 0.0170, 0.0188, 0.0190])


def radius_f(X, Y, Z):
    return np.interp(Z, [0.07, 0.10, 0.15, 0.40, 0.46], [0.0200, 0.0185, 0.0146, 0.0146, 0.0150])


def leg_frame(K, s, z):
    """Point on the leg axis (hip -> knee -> ankle) at height z and the outward direction
    perpendicular to it."""
    H, Kn, A = K.side("upper_leg", s), K.side("knee", s), K.side("ankle", s)
    if z >= Kn[2]:
        a, b = Kn, H
    else:
        a, b = A, Kn
    t = (z - a[2]) / (b[2] - a[2])
    p = a + (b - a) * t
    ax = nrm(b - a)
    out = v3(s, 0, 0)
    out = nrm(out - ax * (out @ ax))
    return p, out, ax


def flap_grid(K, s, mid, zs, widths, cols=3):
    """Mid-surface points of the flap: rows at heights zs, from the root on the tube's
    outer side (2 mm inside it) out to width w; plus the root points."""
    P = np.zeros((len(zs), cols, 3))
    roots = np.zeros((len(zs), 3))
    for i, (z, w) in enumerate(zip(zs, widths)):
        p, out, ax = leg_frame(K, s, z)
        o = p + v3(0, 0.004, 0)                     # the seam a little behind the side
        root = surface_point(mid, o + out * 0.2, -out, 0.0, 0.2) - out * 0.002
        roots[i] = root
        for j, u in enumerate(np.linspace(0.0, 1.0, cols)):
            P[i, j] = root + out * (w + 0.002) * u
    return P, roots


def thigh_follow(ctx, W, V, keep_top=0.25, z=(0.70, 0.80)):
    """The legging is cloth round the thigh: near the hip crease it follows the thigh bone
    (the skin there blends the pelvis and folds in a crouch; a legging top pressed into the
    crease crumples). The pelvis / lower spine share moves to that side's thigh, except
    `keep_top` of it at the very top edge."""
    bi = {bn: i for i, bn in enumerate(ctx.bones)}
    trunk = [bi[n] for n in ("pelvis", "spinea", "spineb")]
    keep = keep_top * smoothstep(z[0], z[1], V[:, 2])
    W = W.copy()
    for s, sd in ((1, "l"), (-1, "r")):
        m = np.sign(V[:, 0]) == s
        Wm = W[m]
        moved = Wm[:, trunk].sum(1) * (1.0 - keep[m])
        Wm[:, trunk] *= keep[m][:, None]
        Wm[:, bi[sd + "_upper_leg"]] += moved
        W[m] = Wm
    return W


def build_leggings(ctx, sp, women=False):
    K = ctx.K
    body = C.body_f(ctx)
    b = C.Builder(sp)
    radius = radius_f if women else radius_m
    z_bot = 0.070
    fins = {}
    for s, sd in ((1, "l"), (-1, "r")):
        if women:
            top = Fn(lambda X, Y, Z: Z - 0.446, (-1, -1, -1), (1, 1, 1))
        else:
            # thigh-high: higher on the outside (tied to the belt), lower at the crotch
            top = Fn(lambda X, Y, Z, s=s: Z - (0.733 + np.clip(s * X - 0.02, 0.0, 0.2) * 0.43), (-1, -1, -1), (1, 1, 1))
        side = Fn(lambda X, Y, Z, s=s: np.maximum(0.010 - s * X, s * X - 0.26), (-1, -1, -1), (1, 1, 1))
        mid = Inter(Offset(body, radius, r_max=0.02), side)
        # cloth: the outer surface of the tube, cut clean at the hem and the top, 2.4 mm thick
        outer = Inter(Inter(Offset(body, lambda X, Y, Z: radius(X, Y, Z) + WOOL, r_max=0.022), side),
                      zslab(z_bot - 0.03, 0.90))
        if women:
            tplane = ((0, 0, 0.446), (0, 0, 1))
            topz = lambda P: np.full(len(P), 0.446)
        else:
            tplane = ((s * 0.02, 0, 0.733), (-0.43 * s, 0, 1.0))
            topz = lambda P, s=s: 0.733 + (s * P[:, 0] - 0.02) * 0.43
        sel = lambda P, s=s: s * P[:, 0] > 0.0
        cuts = [((0, 0, z_bot), (0, 0, 1), lambda P, s=s: sel(P) & (P[:, 2] < z_bot + 0.02)),
                (tplane[0], tplane[1], lambda P, s=s: sel(P) & (P[:, 2] > 0.40))]
        keep = lambda P, s=s, topz=topz: (P[:, 2] > z_bot) & (P[:, 2] < topz(P)) & (s * P[:, 0] > 0.010)
        b.cloth("tube_" + sd, outer, 0.0022, cuts, keep, 300 if women else 560, 2 * WOOL, 0, symmetric=False,
                max_edge=0.085)
        # flap on the outer side
        if women:
            zs = np.linspace(0.425, 0.095, 12)
            widths = np.interp(zs, [0.09, 0.2, 0.42], [0.012, 0.016, 0.016])
        else:
            zs = np.concatenate([np.linspace(0.785, 0.50, 9), np.linspace(0.47, 0.095, 12)])
            widths = np.interp(zs, [0.09, 0.2, 0.45, 0.65, 0.79], [0.020, 0.028, 0.030, 0.032, 0.014])
        P, roots = flap_grid(K, s, mid, zs, widths)
        u_tip = np.linalg.norm(P - P[:, :1], axis=2)
        d_tip = u_tip[:, -1:] - u_tip
        fins[s] = roots
        C.sheet_piece(b, "flap_" + sd, P, FLAP_T, 1, normals=np.broadcast_to(v3(0, -1, 0), P.shape), d_side=d_tip)
        # garter below the knee, with a knot and two short ties on the outer side
        zc = 0.5 * sum(GARTER_Z)
        gband = Inter(Inter(Onion(Offset(body, 0.0192), 0.0013), zslab(*GARTER_Z)), side)
        p, out, _ = leg_frame(K, s, zc)
        gsolid = Inter(Offset(body, 0.0192), side)
        kn = surface_point(gsolid, p + out * 0.2 + v3(0, 0.004, 0), -out, 0.0, 0.2) + out * 0.004
        ties = Union([Sphere(kn, 0.0060),
                      RoundCone(kn, kn + v3(s * 0.002, -0.008, -0.034), 0.0032, 0.0024),
                      RoundCone(kn, kn + v3(s * 0.002, 0.009, -0.030), 0.0032, 0.0024)], k=0.003)
        b.sdf("garter_" + sd, Union([gband, ties], k=0.003), 0.0011, 260, 2, symmetric=False, max_tris=240)
    bt = b.build()
    ob, V = bt.ob, bt.V

    # UVs: one cylinder per leg, the seam on the outside (under the flap); flaps their own
    maps, part = [C.leg_cyl(ctx, 1, seam_outside=True), C.leg_cyl(ctx, -1, seam_outside=True)], None
    Cp = C.poly_centers(ob)
    part = np.where(Cp[:, 0] > 0, 0, 1)
    part[bt.pmask("flap_l", "flap_r")] = -1
    uv = C.loop_uvs(ob, maps, part, vertex_uv=bt.attrs["uv"])

    # edges: x = from the lower hem (tube) / the flap's lower end; y = from the flap's
    # free edge (ribbon / bead edging) and, on the women's tube, from the top edge (binding)
    tube = bt.vmask("tube_l", "tube_r")
    hem = tube & (V[:, 2] < z_bot + 0.003)
    d_hem = C.dist_from(ob, hem)
    flap = bt.vmask("flap_l", "flap_r")
    e = bt.attrs["edge"]
    d_hem = np.where(flap, np.nan_to_num(e[:, 0], nan=1.0), d_hem)
    d_open = np.where(flap, np.nan_to_num(e[:, 1], nan=1.0), 1.0)
    if women:
        topm = tube & (V[:, 2] > 0.446 - 0.003)
        d_open = np.where(tube, C.dist_from(ob, topm), d_open)

    # weights: tube = nearest body point, smoothed; flap rows = the tube at their root;
    # garters rigid on the shin
    W = C.body_W(ctx, V, torso=False)
    if not women:
        W = thigh_follow(ctx, W, V)
    W = C.smooth(ob, W, 3, 0.5)
    ij = bt.attrs["ij"]
    for s, sd in ((1, "l"), (-1, "r")):
        fm = bt.vmask("flap_" + sd)
        roots = fins[s]
        Wr = C.body_W(ctx, roots, torso=False)
        if not women:
            Wr = thigh_follow(ctx, Wr, roots)
        rows = ij[fm, 0].astype(int)
        W[fm] = Wr[rows]
        g = bt.vmask("garter_" + sd)
        W = C.set_rigid(ctx, W, g, sd + "_knee")
    W = C.normalize(W)

    col = np.ones(len(V))
    col[tube] *= np.where(peval(Offset(body, radius, r_max=0.02), V[tube]) < -0.0004, 0.7, 1.0)
    if women:
        cands = ["shin_upper_l", "shin_lower_l", "ankle_l", "shin_upper_r", "shin_lower_r", "ankle_r"]
        focus = ((0.0, 0.0, 0.26), 0.70)
    else:
        cands = ["thigh_lower_l", "shin_upper_l", "shin_lower_l", "ankle_l",
                 "thigh_lower_r", "shin_upper_r", "shin_lower_r", "ankle_r"]
        focus = ((0.0, 0.0, 0.44), 1.02)
    return C.finish(ctx, sp, bt, W, uv, hide_candidates=cands, edge=(d_hem, d_open), colors=C.rgba(col), focus=focus)
