"""Skirted coats of the militia set, built like the legacy hunting frock of
actor_b_body.glb (build_body.coat_node): a solid 15 mm over a torso with the anatomy bridged,
sleeves 12 mm over the arms cut at 82 % of elbow -> wrist with turned-back cuffs, a skirt
shell (4.5 mm) with side pleats, a sloped hem and a back vent, hanging on the six skirt
panel helpers below the waist; the front opening, the vent and the neck are cut out.
Options per coat: the shoulder cape, the collar (standing, falling or none), lapels, pocket
flaps, buttons, deeper cuffs.

Zones: 0 cloth, 1 lining (the skirt's inside), 2 facings (cuffs, collar, lapels, cape),
3 buttons.
"""

import math

import numpy as np

from lib import sdf as S
from lib.body_shapes import neck_shape
from lib.remesh import Prims, join

from garments.militia import _militia as M

CAPE_Z = 1.168


class CoatCut:
    def __init__(self, skirt, opening, coat_off=0.015, sleeve_off=0.013, sleeve_end=0.82, cuff=(0.645, 0.009),
                 cape=False, collar="stand", lapels=None, pockets=None, buttons=None, cuff_buttons=0,
                 neck_r=0.016):
        self.skirt, self.opening = skirt, opening
        self.coat_off, self.sleeve_off, self.sleeve_end, self.cuff = coat_off, sleeve_off, sleeve_end, cuff
        self.cape, self.collar, self.lapels, self.pockets = cape, collar, lapels, pockets
        self.buttons, self.cuff_buttons, self.neck_r = buttons, cuff_buttons, neck_r


def open_w(cut, z):
    return np.interp(z, cut.opening[0], cut.opening[1])


def lapel_region(cut, z0=1.00, z1=1.285, w0=0.052, w1=0.070):
    """Lapels: bands beside the front opening from z0 to z1, w0 wide at the bottom and w1
    at the top, rounded at the bottom."""
    def f(X, Y, Z):
        X, Y, Z = np.broadcast_arrays(X, Y, Z)
        w = open_w(cut, Z)
        lw = w0 + (w1 - w0) * np.clip((Z - z0) / (z1 - z0), 0, 1)
        ax = np.abs(X)
        d = np.maximum.reduce([w - ax, ax - (w + lw), z0 - Z, Z - z1, Y + 0.02])
        return d
    return S.Fn(f, (-0.3, -0.4, z0 - 0.01), (0.3, -0.02, z1 + 0.01))


def coat_node(K, cut):
    sk = cut.skirt
    torso = M.coat_torso_form(K, cut.coat_off, sk)
    sleeves, cuffs = M.sleeves(K, cut.sleeve_off, cut.sleeve_end, cut.cuff)
    body = S.SymUnion(torso, sleeves[0], sleeves[1], k=0.03)
    skirt = sk.shell_node()
    parts = {"cuffs": cuffs}
    pieces = [body]
    if cut.cape:
        cape = S.Inter(S.Inter(M.cape_base(K), S.Fn(lambda X, Y, Z: CAPE_Z - Z, (-0.3, -0.3, CAPE_Z - 0.03), (0.3, 0.3, 1.5)),
                               k=0.006), S.zslab(1.10, 1.40))
        pieces = [S.Union([body, cape], k=0.008)]
        parts["cape"] = cape
    collar = None
    if cut.collar == "stand":
        collar = S.Inter(S.Offset(neck_shape(K), 0.021), S.zslab(1.27, 1.345))
    elif cut.collar == "fall":
        collar = S.Inter(S.Offset(neck_shape(K), lambda X, Y, Z: 0.020 + 0.011 * S.smoothstep(1.335, 1.272, Z),
                                  r_max=0.031), S.zslab(1.266, 1.338), k=0.004)
    if collar is not None:
        parts["collar"] = collar
    coat = S.Union(pieces + [skirt] + ([collar] if collar is not None else []), k=0.0)
    if cut.lapels:
        lap = S.Inter(S.Offset(M.coat_torso_shapes(K), cut.coat_off + 0.0028), lapel_region(cut, **cut.lapels), k=0.002)
        parts["lapels"] = lap
        coat = S.Union([coat, lap], k=0.0015)
    if cut.pockets:
        flaps = pocket_flaps(K, sk, **cut.pockets)
        parts["pockets"] = flaps
        coat = S.Union([coat] + flaps, k=0.003)
    node = S.Sub(S.Sub(S.Sub(coat, M.front_opening(cut.opening), k=0.003), sk.back_split(), k=0.0015),
                 M.neck_hole(K, cut.neck_r), k=0.003)
    return node, parts


def pocket_flaps(K, sk, z=0.845, ang=58.0, half=(0.058, 0.020, 0.0035)):
    """Pocket flaps lying on the skirt at `ang` degrees from the front centre."""
    out = []
    form = S.Offset(sk.form(), sk.shell)
    for s in (1, -1):
        a = math.radians(ang)
        d = S.v3(s * math.sin(a), -math.cos(a), 0)
        p = S.surface_point(form, S.v3(0, 0.01, z) + d * 0.4, -d, 0.0, 0.4)
        n = S.sdf_normal(form, p)
        out.append(S.RoundBox(p + n * 0.0015, half, 0.003, S.frame_from(n, np.cross(S.v3(0, 0, 1), n))))
    return out


def zones_of_coat(ob, K, cut, parts, node):
    C = M.poly_centers(ob)
    z = np.zeros(len(C), int)
    sk = cut.skirt
    N = M.poly_normals(ob)
    radial = C * np.array([1.0, 1.0, 0.0]) - np.array([0.0, float(np.interp(0.7, sk.Z, sk.C)), 0.0])
    radial /= np.maximum(np.linalg.norm(radial, axis=1, keepdims=True), 1e-9)
    inward = (N * radial).sum(1) < -0.35
    lining = (S.peval(sk.form(), C) < -0.0015) & (C[:, 2] < 0.89) & inward
    z[lining] = 1
    facing = list(parts.get("cuffs", []))
    for key in ("lapels", "collar"):
        if key in parts:
            facing.append(parts[key])
    fac = np.zeros(len(C), bool)
    for p in facing:
        fac |= S.peval(p, C) < 0.0012
    z[fac & ~lining] = 2
    return z


def coat_shading(ob, K, cut, zones_v=None):
    """COLOR_0 multiplier (as build_body.coat_shading): darker skirt lining and hem band,
    pleat valleys, the vent edges and the centre-back seam, the cape's lower edge, the
    turned cuffs."""
    V = M.mesh_arrays(ob)
    X, Y, Z = V[:, 0], V[:, 1], V[:, 2]
    sk = cut.skirt
    c = np.ones(len(V))
    skirt = Z < 0.90
    c[skirt] *= 1 - 0.30 * (1 - S.smoothstep(0.0, 0.10, Z[skirt] - sk.hem_z(X[skirt], Y[skirt])))
    lining = skirt & (S.peval(sk.form(), V) < -0.0015)
    c[lining] *= 0.72
    a0, a1, count, depth = sk.pleats
    pl = sk.pleat(X[skirt], Y[skirt], Z[skirt]) / depth
    c[skirt] *= 1 - 0.16 * np.clip(-pl, 0.0, 1.0)
    back = Y > 0.02
    vent = back & (Z < sk.vent_top + 0.01)
    c[vent] *= 0.75 + 0.25 * S.smoothstep(0.010, 0.035, np.abs(X[vent]))
    seam = back & (Z >= sk.vent_top + 0.01) & (Z < 1.30)
    c[seam] *= 0.80 + 0.20 * S.smoothstep(0.008, 0.03, np.abs(X[seam]))
    if cut.cape:
        near = np.abs(Z - CAPE_Z) < 0.02
        near[near] &= S.peval(M.cape_base(K), V[near]) < 0.010
        c[near] *= 1 - 0.30 * (1 - S.smoothstep(0.0, 0.011, np.abs(Z[near] - (CAPE_Z - 0.003))))
    if cut.cuff is not None:
        t0 = cut.cuff[0]
        for s in (1, -1):
            t, d = M.forearm_param_v(V, K, s)
            cuff = (np.sign(X) == s) & (d < 0.09)
            c[cuff] *= 1 - 0.12 * S.smoothstep(t0 - 0.05, t0 + 0.01, t[cuff]) * (1 - S.smoothstep(cut.sleeve_end, cut.sleeve_end + 0.04, t[cuff]))
    return c


def build_coat(ctx, spec_, cut, extra_col=None, sizing=None, target=3600):
    K = ctx.K
    mats = M.zone_mats(spec_)
    node, parts = coat_node(K, cut)
    sk = cut.skirt
    sform = sk.form()
    fopen = M.front_opening(cut.opening)
    bsplit = sk.back_split()
    nhole = M.neck_hole(K, cut.neck_r)

    def vis(P):
        inner = (S.peval(sform, P) < 0) & (P[:, 2] < 0.89)
        L = np.where(inner, 0.050, 0.034)
        pleat = (np.abs(sk.pleat(P[:, 0], P[:, 1], P[:, 2])) > 0.0) & (P[:, 2] < 0.84)
        L = np.where(pleat, np.where(inner, 0.038, 0.023), L)
        from lib.weights import sleeve_factor
        L = np.where((sleeve_factor(P, K) > 0.5) & (P[:, 2] > 0.88), 0.021, L)   # sleeves: round, over the shirt
        L = np.where(np.abs(P[:, 0]) > 0.27, 0.019, L)               # cuffs
        L = np.where(P[:, 2] > 1.26, 0.018, L)                      # collar
        rim = np.minimum.reduce([np.abs(P[:, 2] - sk.hem_z(P[:, 0], P[:, 1])), np.abs(S.peval(fopen, P)),
                                 np.abs(S.peval(bsplit, P)), np.abs(S.peval(nhole, P)),
                                 np.where(P[:, 2] > 1.10, np.abs(CAPE_Z - P[:, 2]) if cut.cape else 1.0, 1.0)])
        return 0.012 + (L - 0.012) * S.smoothstep(0.004, 0.025, rim)
    ob = M.sdf_part(ctx, spec_.id, node, 0.0025, target, mats[0], visible=sizing or vis, hidden=0.042,
                    hidden_below=0.009, feature_deg=32.0, iters=22, sharp_deg=55)
    M.strip_to_envelope(ctx, ob, "outer")
    M.drop_small_islands(ob)
    # buttons
    bp = Prims()
    nb = 0
    if cut.buttons:
        for (x, z, r) in cut.buttons:
            M.buttons_on(bp, node, [(S.v3(x, -0.35, z), S.v3(0, 1, 0))], radius=r, thick=r * 0.5, mi=3)
            nb += 1
    if cut.cuff_buttons and cut.cuff is not None:
        for s in (1, -1):
            t, E, fa, L = M.forearm_t(K, s)
            for k in range(cut.cuff_buttons):
                tt = cut.cuff[0] + 0.05 + k * 0.05
                c = E + fa * tt * L
                out = S.nrm(np.cross(fa, S.v3(0, 1, 0))) * (1 if s > 0 else -1)
                out = out if out[0] * s > 0 else -out
                M.buttons_on(bp, node, [(c + out * 0.2, -out)], radius=0.0045, thick=0.0022, mi=3)
                nb += 1
    if cut.pockets:
        pk = cut.pockets
        for s in (1, -1):
            a = math.radians(pk.get("ang", 58.0))
            for dx in (-0.032, 0.0, 0.032):
                d = S.v3(s * math.sin(a), -math.cos(a), 0)
                tdir = S.nrm(np.cross(S.v3(0, 0, 1), d))
                p0 = S.v3(0, 0.01, pk.get("z", 0.845) - 0.034) + tdir * dx
                M.buttons_on(bp, node, [(p0 + d * 0.4, -d)], radius=0.0048, thick=0.0024, mi=3)
                nb += 1
    btn_ob = bp.to_object("buttons", mats) if nb else None
    M.fit_budget(ob, spec_.budget["tris_max"] - M.button_tris(btn_ob) - 20)
    zones = zones_of_coat(ob, K, cut, parts, node)
    M.set_zone(ob, zones)
    M.with_mats(ob, mats)
    if nb:
        ob = join([ob, btn_ob], spec_.id)
        M.with_mats(ob, mats)
    zones = M.zones_of(ob)
    # weights: body (torso-from-torso), the skirt on the panel helpers, rigid buttons
    V = M.mesh_arrays(ob)
    W = M.body_weights(ctx, ob, smooth=0)
    skirt_m = (np.abs(S.peval(sform, V)) < 0.02) & (V[:, 2] < 0.93)
    buttons = M.vert_mask_of_zone(ob, zones, {3})
    # the two back panels share the weights across the vent down to 8 cm above the hem
    # (skirt_weights parts them in the lowest third of `vent_top`): a vent laps over, it
    # does not gape when the legs stand apart
    W = M.blend_skirt(ctx, ob, W, skirt_m.astype(float), sk.hem, sk.hem + 0.24)
    from lib.weights import smooth_weights
    W = smooth_weights(W, M.mesh_adjacency(ob), 1, 0.3)
    W = M.one_weight_per_piece(ob, W, buttons, ~buttons)
    uv = M.garment_uvs(ctx, ob, "torso")
    col = coat_shading(ob, K, cut)
    if extra_col is not None:
        col *= extra_col(V)
    # edge distances (CUSTOM0): from the hem, from the front opening (lace, bindings)
    hem_src = np.nonzero((np.abs(V[:, 2] - sk.hem_z(V[:, 0], V[:, 1])) < 0.004) & (V[:, 2] < 0.75))[0]
    open_src = np.nonzero((np.abs(S.peval(fopen, V)) < 0.0015) & (V[:, 1] < -0.02))[0]
    d_hem = M.geodesic(ob, hem_src)
    d_open = M.geodesic(ob, open_src)
    hides = ["chest_upper_side", "chest_upper_back", "chest_side", "chest_back", "abdomen_side", "abdomen_back",
             "pelvis_side"]
    for sd in "lr":
        hides += ["upper_arm_" + sd, "forearm_a_" + sd, "forearm_b_" + sd]
    spec_.skirt = {"hems_godot": sk.hems_godot(), "hem_z": sk.hem, "front_rise": sk.front_rise,
                   "vent_top": sk.vent_top, "helpers": ["upper_leg_front_helper", "upper_leg_thigh_helper",
                                                        "upper_leg_rear_helper"]}
    spec_.helpers = ["shoulder_twist", "forarm_twist", "skirt"]
    return M.finish(ctx, spec_, ob, zones, W, uv, hide_candidates=hides, edge=(d_hem, d_open), colors=M.rgba(col))


def front_buttons(cut, z0, z1, n, inset=0.012, r=0.0062, side=-1):
    """Buttons down one front edge (side -1: the wearer's right)."""
    return [(side * (float(open_w(cut, z)) + inset), float(z), r) for z in np.linspace(z1, z0, n)]


def buttonhole_shade(cut, z0, z1, n, inset=0.012, side=1, length=0.020):
    zs = np.linspace(z1, z0, n)

    def f(V):
        c = np.ones(len(V))
        for z in zs:
            x0 = side * (float(open_w(cut, z)) + inset)
            m = (V[:, 1] < -0.02) & (np.abs(V[:, 2] - z) < 0.0026) & (np.abs(V[:, 0] - (x0 + side * length * 0.3)) < length * 0.5)
            c[m] *= 0.62
        return c
    return f
