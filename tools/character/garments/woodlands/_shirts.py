"""Linen shirts worn loose (costume bible §3.2, §3.3): the men's shirt, plain or ruffled, worn
loose over the breechcloth [P1][P2][R3], and the women's long shirt (shift) worn outside the
wrap skirt, nearly to the knee [R1].

Cut: 18th-century shirt shape - a body snug over the chest and waist (the base layer
envelope, <= 6 mm, so any waistcoat or coat fits over it), full sleeves gathered into a
wrist band, a standing collar band, a front slit, and below the waist the body opens out
into tails that hang free (hull form: they bridge the thighs and clear the breechcloth flaps
or the wrap skirt; layer "tails" 35) with side slits from the hem. Ruffled: frills down the
front slit and at the wrists (Smith's "new ruffled shirt", 1755 [P1]).

Weights: the nearest body point (torso-from-torso above the waist, twist helpers on the
sleeves); the tails go from the pelvis at the hips to the skirt panels (front / side / back
by the angle round the body, left / right never fully one-sided); ruffles take the weights
of their root.
"""

import math

import numpy as np

from lib.body_shapes import arm_shapes, forearm_t, neck_shape, torso_shapes
from lib.sdf import Fn, Inter, Offset, Onion, Sub, SymUnion, Union, frame_from, nrm, peval, smoothstep, \
    surface_point, v3, zslab

from garments.woodlands import _common as C

LINEN = 0.0010                # half thickness of the linen shell
BODY_OFF = 0.0047             # torso mid surface over the skin (base envelope <= 6 mm)
CUFF_T = (0.905, 0.935)       # wrist band along elbow -> wrist
NECK_TOP = 1.336
COLLAR_Z = 1.296              # lower edge of the collar band


def tails_clear(hem, extra=0.0):
    """Clearance of the hanging part over the body hull, by height (`extra` below the
    waist: the women's shift hangs over the wrap skirt)."""
    def f(z):
        # (near the top the hull form sinks below the snug torso so the spine groove fades
        # in gradually instead of leaving a notch where the hanging part ends)
        return float(np.interp(z, [hem - 0.05, 0.84, 0.90, 0.935, 0.955, 0.985, 1.03],
                               [0.036, 0.034, 0.026, 0.019, 0.012, 0.0, -0.006])) + extra * float(smoothstep(0.99, 0.90, z))
    return f


def folds(hem):
    """Soft vertical folds on the tails: stronger toward the hem, none above the hips."""
    def f(TH, Z):
        a = 0.0045 * smoothstep(0.86, hem, Z)
        return a * (np.sin(7.0 * TH + 0.6) * 0.65 + np.sin(13.0 * TH + 1.9) * 0.35)
    return f


def shirt_solid(ctx, hem, extra=0.0):
    """The shirt as a solid form (its surface = the cloth's outer surface), uncut."""
    K = ctx.K
    hull = C.Hull(ctx)
    form = hull.form(tails_clear(hem, extra), hang_top=1.00, folds=folds(hem), z_range=(hem - 0.03, 1.06))
    torso = Inter(Offset(Union([torso_shapes(K, smooth=True), neck_shape(K)], k=0.05), BODY_OFF + LINEN),
                  zslab(0.93, 1.40))
    tails = Inter(form.node(), zslab(hem - 0.03, 1.03))
    sleeves = []
    for s in (1, -1):
        t, E, fa, L = forearm_t(K, s)
        r = lambda X, Y, Z, t=t: BODY_OFF + LINEN + 0.0012 + 0.0030 * smoothstep(0.62, 0.86, t(X, Y, Z)) \
            - 0.0012 * smoothstep(0.88, 0.905, t(X, Y, Z))
        sleeves.append(Offset(arm_shapes(K, s), r, r_max=0.010))
    body = Union([torso, tails], k=0.03)
    return SymUnion(body, sleeves[0], sleeves[1], k=0.02), form


def slit_w(z, collar_open):
    k = (collar_open - 0.0025) / (NECK_TOP - 1.15)
    return 0.0025 + k * (np.asarray(z) - 1.15)


def cuts(ctx, hem, slit_top, collar_open=0.017, side_slit=(95.5, 98.5)):
    """Planar cuts [(point, normal, select)] and keep(C) of the shirt: hem, neck opening,
    wrist ends, the front slit (a narrow V) and the side slits of the tails."""
    K = ctx.K
    k = (collar_open - 0.0025) / (NECK_TOP - 1.15)
    out = [((0, 0, hem), (0, 0, 1), lambda C: C[:, 2] < hem + 0.02),
           ((0, 0, NECK_TOP), (0, 0, 1), lambda C: (np.abs(C[:, 0]) < 0.10) & (C[:, 2] > 1.28))]
    ends = []
    for s in (1, -1):
        t, E, fa, L = forearm_t(K, s)
        p = E + fa * L * CUFF_T[1]
        out.append((p, fa, lambda C, s=s: (np.sign(C[:, 0]) == s) & (np.abs(C[:, 0]) > 0.2) & (C[:, 2] < 1.12)))
        ends.append((s, t))
    # (zone borders: the collar band and the wrist bands get their own clean edge loops)
    neck_y = K["neck"][1]
    out.append(((0, 0, COLLAR_Z), (0, 0, 1), lambda C: (np.hypot(C[:, 0], C[:, 1] - neck_y) < 0.085) & (C[:, 2] > 1.25)))
    for s in (1, -1):
        t, E, fa, L = forearm_t(K, s)
        out.append((E + fa * L * CUFF_T[0], fa, lambda C, s=s: (np.sign(C[:, 0]) == s) & (np.abs(C[:, 0]) > 0.2)
                    & (C[:, 2] < 1.12)))
    front_sel = lambda C: (C[:, 1] < -0.01) & (C[:, 2] > 1.13) & (np.abs(C[:, 0]) < 0.05)
    out += [((0.0025, 0, 1.15), (1, 0, -k), front_sel), ((-0.0025, 0, 1.15), (-1, 0, -k), front_sel),
            ((0, 0, 1.15), (0, 0, 1), lambda C: front_sel(C) & (np.abs(C[:, 0]) < 0.02) & (C[:, 2] < 1.17))]
    for s in (1, -1):
        for a in np.radians(side_slit):
            out.append(((0, 0.005, 0), (math.cos(a), s * math.sin(a), 0),
                        lambda C, s=s: (C[:, 2] < slit_top + 0.02) & (s * C[:, 0] > 0.05)))
        out.append(((0, 0, slit_top), (0, 0, 1), lambda C, s=s: (s * C[:, 0] > 0.05) & (np.abs(C[:, 2] - slit_top) < 0.02)
                    & (np.abs(C_ang(C) - 97.0) < 6.0)))

    def keep(C):
        X, Y, Z = C[:, 0], C[:, 1], C[:, 2]
        ok = Z > hem
        ok &= ~((np.abs(X) < 0.10) & (Z > NECK_TOP) & (Z > 1.28))
        for s, t in ends:
            ok &= ~((np.sign(X) == s) & (np.abs(X) > 0.2) & (Z < 1.12) & (t(X, Y, Z) > CUFF_T[1]))
        ok &= ~((Y < -0.01) & (Z > 1.15) & (np.abs(X) < slit_w(Z, collar_open)))
        ang = C_ang(C)
        ok &= ~((ang > side_slit[0]) & (ang < side_slit[1]) & (Z < slit_top))
        return ok
    return out, keep


def C_ang(C):
    return np.degrees(np.arctan2(np.abs(C[:, 0]), -(C[:, 1] - 0.005)))


def build_shirt(ctx, sp, hem, slit_top, ruffled=False, collar_open=0.017, focus=None, tris=1100, extra=0.0):
    K = ctx.K
    b = C.Builder(sp)
    solid, form = shirt_solid(ctx, hem, extra)
    planes, keep = cuts(ctx, hem, slit_top, collar_open)
    b.cloth("shirt", solid, 0.0026, planes, keep, tris, 2 * LINEN, 0)
    if ruffled:
        add_ruffles(ctx, b, collar_open)
    bt = b.build()
    ob, V = bt.ob, bt.V
    zones = bt.zones.copy()
    Cp = C.poly_centers(ob)
    band = np.zeros(len(Cp), bool)
    band |= (Cp[:, 2] > COLLAR_Z) & (np.hypot(Cp[:, 0], Cp[:, 1] - K["neck"][1]) < 0.085) & bt.pmask("shirt")
    for s in (1, -1):
        t, E, fa, L = forearm_t(K, s)
        band |= (t(Cp[:, 0], Cp[:, 1], Cp[:, 2]) > CUFF_T[0]) & (np.sign(Cp[:, 0]) == s) & bt.pmask("shirt") \
            & (Cp[:, 2] < 1.1)
    zones[band] = 1
    bt.set_zones(zones)

    # UVs: torso cylinder (seam at the back centre... front slit is cut anyway), sleeves
    # round the arm axis (seam underneath), ruffles their own
    from lib.weights import sleeve_factor
    sl = sleeve_factor(Cp, K) > 0.5
    part = np.where(sl, np.where(Cp[:, 0] > 0, 1, 2), 0)
    if ruffled:
        part[bt.pmask(*[n for n in bt.names if n.startswith("ruffle")])] = -1
    uv = C.loop_uvs(ob, [C.torso_cyl(ctx, ref=(0, -1, 0)), C.arm_cyl(ctx, 1), C.arm_cyl(ctx, -1)], part,
                    vertex_uv=bt.attrs.get("uv"))

    # edges: x = from the hem (tails) / the cuff end (sleeves); y = from the front slit
    shirt_v = bt.vmask("shirt")
    hem_m = shirt_v & (V[:, 2] < hem + 0.004)
    cuff_m = np.zeros(len(V), bool)
    for s in (1, -1):
        t, E, fa, L = forearm_t(K, s)
        cuff_m |= shirt_v & (t(V[:, 0], V[:, 1], V[:, 2]) > CUFF_T[1] - 0.006) & (np.sign(V[:, 0]) == s) & (V[:, 2] < 1.0)
    d_hem = C.dist_from(ob, hem_m | cuff_m)
    slit_m = shirt_v & (np.abs(V[:, 0]) < slit_w(V[:, 2], collar_open) + 0.003) & (V[:, 1] < -0.01) & (V[:, 2] > 1.149)
    d_open = C.dist_from(ob, slit_m)
    if ruffled:
        rm = ~shirt_v
        e = bt.attrs["edge"]
        d_hem = np.where(rm, np.nan_to_num(e[:, 0], nan=1.0), d_hem)
        d_open = np.where(rm, np.nan_to_num(e[:, 1], nan=1.0), d_open)

    # weights
    W = C.no_hands(ctx, C.body_W(ctx, V))
    # tails: the pelvis down to the hip crease, the skirt panels below it (the panels pivot
    # at the hip joints: cloth above the pivot must not follow them)
    from lib.weights import sleeve_factor as _sf
    tails = shirt_v & (V[:, 2] < 0.96) & (np.abs(V[:, 0]) < 0.26) & (_sf(V, K) < 0.5)
    Wp = C.panel_W(ctx, V[tails], lr_width=0.14, pelvis_z=(0.62, 0.83), lr_gain=0.4)
    t = smoothstep(0.96, 0.90, V[tails, 2])[:, None]
    W[tails] = W[tails] * (1 - t) + Wp * t
    W = C.smooth(ob, W, 2, 0.4)
    if ruffled:
        W = ruffle_weights(ctx, bt, W)
    W = C.normalize(W)

    col = np.ones(len(V))
    col[shirt_v] *= C.inner_shade(V[shirt_v], solid, dark=0.78)
    ang = np.arctan2(V[:, 1] - 0.005, V[:, 0])
    fold = folds(hem)(ang, V[:, 2]) / 0.0045
    col *= np.where(tails, 1.0 + 0.07 * np.clip(fold, -1, 1), 1.0)
    cands = ["chest_upper_side", "chest_upper_back", "chest_front", "chest_side", "chest_back", "abdomen_front",
             "abdomen_side", "abdomen_back", "pelvis_side"]
    for sd in "lr":
        cands += ["upper_arm_" + sd, "forearm_a_" + sd, "forearm_b_" + sd, "forearm_c_" + sd]
    return C.finish(ctx, sp, bt, W, uv, hide_candidates=cands, edge=(d_hem, d_open), colors=C.rgba(col),
                    focus=focus or ((0.0, 0.0, 0.98), 1.02))


# ---------------------------------------------------------------------------
# ruffles
# ---------------------------------------------------------------------------
RUFFLE_T = 0.0008


def add_ruffles(ctx, b, collar_open):
    K = ctx.K
    torso = Offset(Union([torso_shapes(K, smooth=True), neck_shape(K)], k=0.05), BODY_OFF + LINEN)
    # down each edge of the front slit: a frill 3 cm wide lying forward and out
    zs = np.linspace(1.325, 1.17, 16)
    for s in (1, -1):
        rows = []
        for z in zs:
            w = float(slit_w(z, collar_open))
            root = surface_point(torso, v3(s * (w + 0.003), -0.3, z), v3(0, 1, 0), 0.0, 0.3)
            out = nrm(v3(s * 0.9, -0.6, -0.2))
            wave = 0.0045 * math.sin((z - 1.17) / 0.0135 * math.pi)
            row = [root + out * (0.030 * u) + v3(s, 0, 0) * wave * u for u in np.linspace(0.0, 1.0, 4)]
            rows.append(row)
        P = np.array(rows)
        C.sheet_piece(b, "ruffle_front_" + "lr"[s < 0], P, RUFFLE_T, 2)
    # at the wrists: a frill flaring out of the wrist band
    for s in (1, -1):
        t, E, fa, L = forearm_t(K, s)
        Wr = K.side("wrist", s)
        c0 = E + fa * L * CUFF_T[1]
        x = nrm(np.cross(fa, v3(0, 1, 0)))
        y = np.cross(fa, x)
        n = 25
        P = np.zeros((4, n, 3))
        arm = Offset(arm_shapes(K, s), BODY_OFF + 0.002)
        for j, a in enumerate(np.linspace(0.0, 2 * math.pi, n)):
            d = x * math.cos(a) + y * math.sin(a)
            root = surface_point(arm, c0 + d * 0.1, -d, 0.0, 0.1) - fa * 0.004
            for i, u in enumerate(np.linspace(0.0, 1.0, 4)):
                wave = 0.004 * math.sin(10 * a) * u
                P[i, j] = root + fa * (0.028 * u) + d * (0.010 * u * u + wave)
        C.sheet_piece(b, "ruffle_cuff_" + "lr"[s < 0], P, RUFFLE_T, 2)


def ruffle_weights(ctx, bt, W):
    """Each ruffle vertex takes the (final) weights of the nearest shirt vertex to its
    root (the frill's first column / row), so frills move with the cloth they are sewn to."""
    V = bt.V
    shirt = np.nonzero(bt.vmask("shirt"))[0]
    ij = bt.attrs["ij"]
    for name in bt.names:
        if not name.startswith("ruffle"):
            continue
        m = np.nonzero(bt.vmask(name))[0]
        front = name.startswith("ruffle_front")
        # root: column 0 (front frills: along the slit) or row 0 (cuff frills: round the band)
        key = ij[m, 0] if front else ij[m, 1]
        for k in np.unique(key):
            sel = m[key == k]
            root_idx = sel[ij[sel, 1] == 0] if front else sel[ij[sel, 0] == 0]
            root = V[root_idx].mean(0)
            near = shirt[np.argsort(np.linalg.norm(V[shirt] - root, axis=1))[:4]]
            w = W[near].mean(0)
            W[sel] = w / max(w.sum(), 1e-12)
    return W
