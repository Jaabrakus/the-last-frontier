"""Regimental coats (costume bible §5.1-5.3): the British 1751-pattern coat (lapelled to the
waist in the facing colour, round cuffs, turned-back skirts, regimental lace loops), the
same docked and stripped of lace for the woods in 1758 (Howe's reforms), and the French
justaucorps of the troupes de la marine (grey-white, collarless, buttoned down the front,
deep blue cuffs, blue lining).

Construction (Blender space, z up, front -y):
  outer form  the coat's hang: the body torso with the anatomy bridged (coat_torso_shapes),
              the sleeves around the arms, and a skirt form (superellipse sections, side
              pleats) smoothly united, offset to the outer clearance (outer band 13-18 mm
              over the torso, 11-14 mm on the sleeves, cuffs to 21 mm). Lapels, cuffs, pocket
              flaps and turnbacks are raised 2 mm (a fold of cloth has an edge).
  region      the cuts: hem, front opening (the skirts' fronts cut away), back vent,
              neckline, sleeve ends.
  sheet       lib sdf_object of the solid, caps removed, rim fixed (_base.sheet); zone
              borders cut along planes (lapel edge, cuff top, turnback edge) so the facing
              colour has straight edges.
  layers      the skirt gets a full lining (visible when the tails swing and at the vent);
              the body and sleeves only a rim lip at their open edges (the inside is never
              seen past the waistcoat and arms).
  weights     body weights (torso-from-torso above the waist), the skirt blending into the
              driven skirt-panel helpers below the waist (lib.weights.skirt_weights: the hem
              and panel constants are the legacy coat's, CharacterBodyMesh.SKIRT_HEMS).
Zones: 0 cloth, 1 facing (lapels, cuffs, turnbacks, skirt lining), 2 lace loops, 3 buttons.
"""

import math

import numpy as np

from lib import regions as RG
from lib.body_shapes import arm_shapes
from lib.helpers import SKIRT_HEMS_GODOT
from lib.remesh import join, material, mesh_arrays
from lib.sdf import Fn, Offset, SymUnion, Union, log, nrm, peval, smoothstep, v3

from . import _base as B
from ._trims import Trims, hit, normals_at, project

# ---------------------------------------------------------------------------
# styles
# ---------------------------------------------------------------------------
BRITISH_1751 = {
    "name": "br1751",
    # front opening half-width by height: lapels nearly meeting at the neck, the skirts'
    # fronts cut away below the waist
    "open_z": [0.40, 0.52, 0.62, 0.75, 0.86, 0.93, 1.00, 1.10, 1.20, 1.28, 1.36, 1.50],
    "open_w": [0.215, 0.205, 0.185, 0.145, 0.095, 0.055, 0.038, 0.028, 0.020, 0.018, 0.030, 0.06],
    "lapels": {"z": (0.975, 1.285), "w": (0.058, 0.074), "buttons": 8, "lace": True},
    "cuff_t0": 0.50, "sleeve_end": 0.82, "cuff_buttons": 4, "cuff_lace": True,
    "hem": 0.525, "front_rise": 0.06, "vent_top": 0.80,
    "turnbacks": {"w_hem": 0.105, "z_top": 0.90},
    "pockets": {"z": (0.835, 0.885), "a": (52.0, 98.0), "buttons": 4, "lace": True, "on_flap": False},
    "back_buttons": True, "front_buttons": 0, "shoulder_strap": True,
    "button_r": 0.0085,
}
BRITISH_1758 = dict(BRITISH_1751, name="br1758", hem=0.655, front_rise=0.035, vent_top=0.83,
                    lapels=dict(BRITISH_1751["lapels"], lace=False), cuff_lace=False,
                    turnbacks={"w_hem": 0.075, "z_top": 0.90},
                    pockets=dict(BRITISH_1751["pockets"], lace=False, z=(0.845, 0.89)))
FRENCH_MARINE = {
    "name": "frmarine",
    "open_z": [0.40, 0.52, 0.62, 0.75, 0.86, 0.93, 1.00, 1.10, 1.20, 1.28, 1.36, 1.50],
    "open_w": [0.11, 0.10, 0.085, 0.060, 0.030, 0.012, 0.010, 0.010, 0.010, 0.012, 0.030, 0.06],
    "lapels": None,
    "cuff_t0": 0.46, "sleeve_end": 0.82, "cuff_buttons": 3, "cuff_lace": False,
    "hem": 0.525, "front_rise": 0.05, "vent_top": 0.80,
    "turnbacks": None,
    "pockets": {"z": (0.83, 0.885), "a": (50.0, 100.0), "buttons": 5, "lace": False, "on_flap": True},
    "back_buttons": True, "front_buttons": 13, "shoulder_strap": False,
    "button_r": 0.0080,
}

COAT_OUT, SLEEVE_OUT, CUFF_OUT = 0.0170, 0.0140, 0.0205
LAPEL_TOP = 0.08                # the lapels run up to the neckline (cut by it)
RAISE = 0.0021                  # lapels, cuffs edge, flaps, turnbacks stand this much proud
THICK = 0.003                   # cloth thickness (lining / rim lip)
SKIRT_TOP = 0.925               # below: the skirt piece (lined, panel weights)
NECK_R = 0.071                  # neckline: cylinder round the neck axis (the collarless edge ~2 cm off the neck)

# skirt sections by height (the legacy frock's hang, fuller at the hem)
SKIRT_Z = [0.45, 0.51, 0.60, 0.75, 0.85, 0.93, 0.99]
SKIRT_A = [0.258, 0.254, 0.242, 0.216, 0.192, 0.152, 0.128]
SKIRT_B = [0.190, 0.186, 0.176, 0.156, 0.143, 0.114, 0.094]
SKIRT_C = [0.008, 0.008, 0.009, 0.010, 0.012, 0.006, 0.004]
SKIRT_BACK_N = 3.0
SKIRT_PLEATS = (96.0, 134.0, 3, 0.0040)


def opening_w(st, Z):
    return np.interp(Z, st["open_z"], st["open_w"])


def hem_z(st, X, Y):
    ang = np.degrees(np.arctan2(np.abs(X), -Y))
    return st["hem"] + st["front_rise"] * (1 - smoothstep(50.0, 130.0, ang))


def skirt_pleat(X, Y, Z):
    a0, a1, count, depth = SKIRT_PLEATS
    c = np.interp(Z, SKIRT_Z, SKIRT_C)
    ang = np.degrees(np.arctan2(np.abs(X), -(Y - c)))
    w = smoothstep(a0 - 8.0, a0 + 2.0, ang) * (1 - smoothstep(a1 - 2.0, a1 + 8.0, ang)) * smoothstep(0.84, 0.70, Z)
    return depth * w * np.cos((ang - a0) / (a1 - a0) * count * 2.0 * np.pi)


def skirt_form():
    """Solid whose surface is the skirt's outer hang (distance units approximate)."""
    def f(X, Y, Z):
        a = np.interp(Z, SKIRT_Z, SKIRT_A)
        b = np.interp(Z, SKIRT_Z, SKIRT_B)
        c = np.interp(Z, SKIRT_Z, SKIRT_C)
        n = 2.0 + (SKIRT_BACK_N - 2.0) * smoothstep(0.86, 0.62, Z) * (Y > c)
        r = (np.abs(X / a) ** n + np.abs((Y - c) / b) ** n) ** (1.0 / n)
        return (r - 1.0) * np.minimum(a, b) - skirt_pleat(X, Y, Z)
    return Fn(f, (-0.30, -0.24, 0.42), (0.30, 0.24, 1.02))


# ---------------------------------------------------------------------------
# raised features (fields added to the outer offset)
# ---------------------------------------------------------------------------
def lapel_line(st, s):
    """(x0, z0), (x1, z1): bottom and top of the lapel's outer edge, side s."""
    lp = st["lapels"]
    z0, z1 = lp["z"]
    return (s * (opening_w(st, z0) + lp["w"][0]), z0), (s * (opening_w(st, z1) + lp["w"][1]), z1)


def lapel_dist(st, X, Z, s):
    """Signed horizontal distance to the lapel's outer edge (negative inside the lapel)."""
    (x0, z0), (x1, z1) = lapel_line(st, s)
    t = np.clip((Z - z0) / (z1 - z0), -0.5, 1.5)
    xe = x0 + (x1 - x0) * t
    return (np.abs(X) - np.abs(xe))


def lapel_field(st):
    lp = st["lapels"]

    def f(X, Y, Z):
        if lp is None:
            return 0.0 * X
        out = np.zeros(np.broadcast(X, Y, Z).shape)
        for s in (1, -1):
            side = (X * s) > 0
            m = (1 - smoothstep(-0.0015, 0.0015, lapel_dist(st, X, Z, s))) * B.smooth_band(Z, lp["z"][0], lp["z"][1] + LAPEL_TOP, 0.0015)
            out = out + np.where(side, m, 0.0)
        return RAISE * out * smoothstep(-0.005, -0.03, Y)
    return f


def cuff_field(K, st):
    def f(X, Y, Z):
        out = np.zeros(np.broadcast(X, Y, Z).shape)
        P = np.stack(np.broadcast_arrays(X, Y, Z), -1).reshape(-1, 3)
        for s in (1, -1):
            t, d = B.arm_t(K, P, s)
            m = smoothstep(st["cuff_t0"] - 0.012, st["cuff_t0"] + 0.004, t) * (d < 0.09)
            out = out + m.reshape(out.shape)
        return (CUFF_OUT - SLEEVE_OUT) * out
    return f


def pocket_field(st):
    pk = st["pockets"]

    def f(X, Y, Z):
        if pk is None:
            return 0.0 * X
        ang = B.angle_front(X, Y, 0.01)
        m = B.smooth_band(ang, pk["a"][0], pk["a"][1], 1.2) * B.smooth_band(Z, pk["z"][0], pk["z"][1], 0.0015)
        return RAISE * 0.9 * m
    return f


def turnback_field(st, edge):
    tb = st["turnbacks"]

    def f(X, Y, Z):
        if tb is None:
            return 0.0 * X
        return RAISE * 0.8 * (1 - smoothstep(-0.0015, 0.0015, edge(X, Y, Z))) * (Z < tb["z_top"] + 0.01) * (Y < 0.02)
    return f


def turnback_edge(st):
    """Signed distance-like field to the turnback's inner edge (negative on the turned-back
    triangle next to the front opening): the triangle is 0 wide at z_top and w_hem wide at
    the hem, measured round the skirt from the opening edge (arc ~ angle * radius)."""
    tb = st["turnbacks"]
    if tb is None:
        return None

    def f(X, Y, Z):
        a = np.interp(Z, SKIRT_Z, SKIRT_A)
        ang = np.arctan2(np.abs(X), -Y)
        ow = opening_w(st, Z)
        a_open = np.arcsin(np.clip(ow / np.maximum(a, 1e-3), 0, 1))
        width = tb["w_hem"] * np.clip((tb["z_top"] - Z) / (tb["z_top"] - st["hem"]), 0.0, 1.0)
        return (ang - a_open) * a - width
    return f


# ---------------------------------------------------------------------------
# forms
# ---------------------------------------------------------------------------
def neck_field(K):
    """The coat stands 3 mm further off near the neckline (a rolled edge; the neck band
    of the envelope asks 18 mm over the neck)."""
    nk, ha = K["neck"], K["heada"]
    a = v3(0, nk[1] + 0.012, nk[2] - 0.07)
    b = v3(0, ha[1] + 0.012, ha[2] + 0.12)

    def f(X, Y, Z):
        shape = np.broadcast(X, Y, Z).shape
        P = np.stack(np.broadcast_arrays(X, Y, Z), -1).reshape(-1, 3)
        t = np.clip(((P - a) @ (b - a)) / ((b - a) @ (b - a)), 0.0, 1.0)
        d = np.linalg.norm(P - (a + t[:, None] * (b - a)), axis=1)
        return (0.003 * (1 - smoothstep(NECK_R + 0.004, NECK_R + 0.04, d))).reshape(shape)
    return f


def outer_form(ctx, st, neck=True):
    """The coat's outer surface (zero set). neck=False leaves out the neck column (belts are
    laid on the coat's shoulders, not up its uncut neck form)."""
    K = ctx.K
    torso_bumps = [lapel_field(st), neck_field(K)]
    edge = turnback_edge(st)
    from lib.body_shapes import neck_shape
    base = Union([B.coat_torso_shapes(K), neck_shape(K)], k=0.035) if neck else B.coat_torso_shapes(K)
    torso = B.bumped(base, COAT_OUT, torso_bumps, r_max=COAT_OUT + RAISE + 0.004)
    sleeves = [B.bumped(arm_shapes(K, s), SLEEVE_OUT, [cuff_field(K, st)], r_max=CUFF_OUT + 0.001) for s in (1, -1)]
    skirt_b = [pocket_field(st)] + ([turnback_field(st, edge)] if edge else [])
    skirt = B.bumped(skirt_form(), 0.0, skirt_b, r_max=RAISE + 0.001)
    upper = SymUnion(torso, sleeves[0], sleeves[1], k=0.03)
    return Union([upper, skirt], k=0.015)


def region(ctx, st):
    K = ctx.K
    nk, ha = K["neck"], K["heada"]
    a = v3(0, nk[1] + 0.012, nk[2] - 0.07)
    b = v3(0, ha[1] + 0.012, ha[2] + 0.12)
    ab = b - a
    r_neck = NECK_R
    arms = []
    for s in (1, -1):
        E, W = K.side("elbow", s), K.side("wrist", s)
        arms.append((E, W, float(np.linalg.norm(W - E))))

    def f(X, Y, Z):
        shape = np.broadcast(X, Y, Z).shape
        X, Y, Z = [np.broadcast_to(q, shape) for q in (X, Y, Z)]
        r = hem_z(st, X, Y) - Z                                                   # keep above the hem
        ow = opening_w(st, Z)
        r = np.maximum(r, -np.maximum(np.abs(X) - ow, Y + 0.02))                  # front opening
        P = np.stack([X, Y, Z], -1).reshape(-1, 3)
        t = np.clip(((P - a) @ ab) / (ab @ ab), 0.0, 1.0)
        dn = np.linalg.norm(P - (a + t[:, None] * ab), axis=1) - r_neck
        r = np.maximum(r, -dn.reshape(shape))                                    # neckline
        for E, W, L in arms:
            u = ((P - E) @ (W - E)) / (L * L)
            dax = np.linalg.norm(P - (E + np.clip(u, 0, 2)[:, None] * (W - E)), axis=1)
            cut = np.maximum((st["sleeve_end"] - u) * L, dax - 0.10)
            r = np.maximum(r, -cut.reshape(shape))                                # sleeve end
        return np.maximum(r, Z - 1.46)
    return Fn(f)


# ---------------------------------------------------------------------------
# zone border cuts
# ---------------------------------------------------------------------------
def cut_zone_borders(ctx, ob, st):
    """Zone borders and the waist seam cut along their curves (_base.cut_levelset)."""
    K = ctx.K
    front = lambda C: C[:, 1] < -0.015
    if st["lapels"]:
        z0, z1 = st["lapels"]["z"]
        for s in (1, -1):
            B.cut_levelset(ob, lambda P, s=s: lapel_dist(st, P[:, 0], P[:, 2], s),
                           lambda C, s=s: front(C) & (C[:, 0] * s > 0) & (C[:, 2] > z0 - 0.02), name="lapel edge")
            for zc, nm in ((z0, "lapel bottom"), (z1 + LAPEL_TOP, "lapel top")):
                B.cut_levelset(ob, lambda P, zc=zc: P[:, 2] - zc,
                               lambda C, s=s: front(C) & (C[:, 0] * s > 0) & (lapel_dist(st, C[:, 0], C[:, 2], s) < 0.02),
                               name=nm)
    for s in (1, -1):
        B.cut_levelset(ob, lambda P, s=s: B.arm_t(K, P, s)[0] - st["cuff_t0"],
                       lambda C, s=s: (C[:, 0] * s > 0.20) & (B.arm_t(K, C, s)[1] < 0.09) & (B.arm_t(K, C, s)[0] > 0.2),
                       name="cuff")
    edge = turnback_edge(st)
    if edge is not None:
        zt = st["turnbacks"]["z_top"]
        B.cut_levelset(ob, lambda P: edge(P[:, 0], P[:, 1], P[:, 2]), lambda C: (C[:, 2] < zt) & (C[:, 1] < 0.03),
                       name="turnback edge")
    B.cut_levelset(ob, lambda P: P[:, 2] - SKIRT_TOP, lambda C: ~B.sleeve_mask(K, C) & (np.abs(C[:, 2] - SKIRT_TOP) < 0.06),
                   name="waist seam")


# ---------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------
def split_faces(ob, keep_mask, name):
    """Copy of `ob` with only the faces in keep_mask (by polygon index); `ob` keeps the rest."""
    import bmesh
    import bpy
    ob2 = ob.copy()
    ob2.data = ob.data.copy()
    ob2.name = name
    bpy.context.scene.collection.objects.link(ob2)
    for o, keep in ((ob2, keep_mask), (ob, ~keep_mask)):
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.faces.ensure_lookup_table()
        dead = [f for f in bm.faces if not keep[f.index]]
        bmesh.ops.delete(bm, geom=dead, context="FACES")
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()
    return ob2


def coat(ctx, spec, st):
    K = ctx.K
    outer = outer_form(ctx, st)
    reg = region(ctx, st)
    sform = skirt_form()
    edge = turnback_edge(st)

    def vis(P):
        X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
        L = np.full(len(P), 0.034)
        L = np.where(Y < -0.02, 0.027, L)                                       # front
        skirt = Z < SKIRT_TOP
        L = np.where(skirt, 0.040, L)
        pleat = (np.abs(skirt_pleat(X, Y, Z)) > 0.0) & (Z < 0.84)
        L = np.where(pleat, 0.018, L)
        if st["lapels"]:
            for s in (1, -1):
                near = (np.abs(lapel_dist(st, X, Z, s)) < 0.02) & (X * s > 0) & (Y < -0.02) & (Z > st["lapels"]["z"][0] - 0.02)
                L = np.where(near, 0.018, L)
        for s in (1, -1):
            t, d = B.arm_t(K, P, s)
            L = np.where((X * s > 0.2) & (d < 0.09) & (t > st["cuff_t0"] - 0.1), 0.019, L)
            ua, da = B.segment_t(P, K.side("shoulder", s), K.side("elbow", s))
            L = np.where((X * s > 0.12) & (da < 0.08) & (ua > 0.15) & (ua < 1.2), np.minimum(L, 0.028), L)
        L = np.where(np.abs(Z - hem_z(st, X, Y)) < 0.03, np.minimum(L, 0.024), L)
        L = np.where(np.abs(np.abs(X) - opening_w(st, Z)) < 0.02, np.minimum(L, 0.022), L)
        return L

    ob = B.sheet(spec.id, outer, reg, 0.0032, 4000, material(spec.id, "#8e2b21"), sizing=vis, feature_deg=32.0,
                 iters=18, sharp_deg=55)
    cut_zone_borders(ctx, ob, st)
    # the back vent: a slit (the two tails meet; the skirt panels part them)
    B.split_seam(ob, lambda P: P[:, 0], lambda C: (C[:, 1] > 0.03) & (C[:, 2] < st["vent_top"]) & (np.abs(C[:, 0]) < 0.06),
                 name="back vent", gap=0.0)
    B.dissolve_slivers(ob, 0.0025)
    # skirt below the waist seam: lined; body and sleeves: a rim lip only
    C, _ = B.poly_arrays(ob)
    sk = (C[:, 2] < SKIRT_TOP) & ~B.sleeve_mask(K, C)
    skirt_ob = split_faces(ob, sk, spec.id + "_skirt")
    B.solidify(skirt_ob, THICK, rim_only=False)
    B.solidify(ob, THICK, rim_only=True)

    tr_metal, tr_lace, tr_cloth = Trims(), Trims(), Trims()
    from lib.sdf import Inter
    place_trims(ctx, st, Inter(outer, reg), tr_metal, tr_lace, tr_cloth)
    pieces = []

    def zone_fn(C, N, L):
        X, Y, Z = C[:, 0], C[:, 1], C[:, 2]
        z = np.full(len(C), B.CLOTH)
        face = np.zeros(len(C), bool)
        if st["lapels"]:
            z0, z1 = st["lapels"]["z"]
            for s in (1, -1):
                face |= (X * s > 0) & (Y < -0.015) & (Z > z0) & (Z < z1 + LAPEL_TOP) & (lapel_dist(st, X, Z, s) < 0.0)
        for s in (1, -1):
            t, d = B.arm_t(K, C, s)
            face |= (X * s > 0.20) & (d < 0.09) & (t > st["cuff_t0"])
        if edge is not None:
            face |= (edge(X, Y, Z) < 0.0) & (Z < st["turnbacks"]["z_top"] + 0.005) & (Y < 0.02)
        z[face & (L == 0)] = B.FACING
        z[L == 1] = B.FACING
        return z

    def weights(ctx_, V):
        W = B.body_W(ctx_, V)
        # near the collarless neckline: mostly the torso's weights (the edge stands off the
        # neck; following the neck and head there only stretched the shoulders)
        up = (V[:, 2] > 1.20) & ~B.sleeve_mask(K, V)
        if up.any():
            t = 0.8 * smoothstep(1.22, 1.29, V[up, 2])
            W[up] = W[up] * (1 - t[:, None]) + B.labels_W(ctx_, V[up], ["torso"]) * t[:, None]
        mask = (V[:, 2] < 0.94) & ~B.sleeve_mask(K, V)
        # the vent is split: below its top each tail belongs wholly to its own side (the
        # split edges themselves are evaluated a little to their own side, _base.split_seam)
        Vs = V.copy()
        vent = (V[:, 1] > 0.02) & (V[:, 2] < st["vent_top"]) & (np.abs(V[:, 0]) < 0.006) & (V[:, 0] != 0.0)
        Vs[vent, 0] = np.sign(V[vent, 0]) * 0.006
        return B.skirt_W(ctx_, Vs, W, mask, st["hem"], st["vent_top"])

    def shade(V, inner):
        X, Y, Z = V[:, 0], V[:, 1], V[:, 2]
        c = np.ones(len(V))
        skirt = Z < SKIRT_TOP
        c[skirt] *= 1 - 0.18 * (1 - smoothstep(0.0, 0.10, Z[skirt] - hem_z(st, X[skirt], Y[skirt])))
        pl = skirt_pleat(X, Y, Z) / SKIRT_PLEATS[3]
        c *= 1 - 0.16 * np.clip(-pl, 0.0, 1.0)
        c[inner] *= 0.78
        back = Y > 0.02
        vent = back & (Z < st["vent_top"] + 0.01)
        c[vent] *= 0.78 + 0.22 * smoothstep(0.008, 0.03, np.abs(X[vent]))
        seam = back & (Z >= st["vent_top"] + 0.01) & (Z < 1.30)
        c[seam] *= 0.84 + 0.16 * smoothstep(0.006, 0.025, np.abs(X[seam]))
        return c

    pieces.append(B.Piece(ob, "cloth", zone_fn=zone_fn, uv="body", weights=weights, shade=shade))
    pieces.append(B.Piece(skirt_ob, "cloth", zone_fn=zone_fn, uv="skirt", weights=weights, shade=shade))
    if not tr_lace.empty():
        pieces.append(B.Piece(tr_lace.to_object(spec.id + "_lace", "#e8e3d3"), "trim", zone=B.LACE, uv="attr"))
    if not tr_cloth.empty():
        pieces.append(B.Piece(tr_cloth.to_object(spec.id + "_strap", "#8e2b21"), "trim", zone=B.CLOTH, uv="attr"))
    if not tr_metal.empty():
        pieces.append(B.Piece(tr_metal.to_object(spec.id + "_buttons"), "trim", zone=B.METAL, uv="attr"))

    def edge_fn(V):
        X, Y, Z = V[:, 0], V[:, 1], V[:, 2]
        d_hem = np.clip(Z - hem_z(st, X, Y), 0, 1)
        for s in (1, -1):
            t, d = B.arm_t(K, V, s)
            sl = (X * s > 0.2) & (d < 0.09)
            d_hem[sl] = np.clip((st["sleeve_end"] - t[sl]) * 0.232, 0, 1)
        d_open = np.where(Y < 0.0, np.clip(np.abs(X) - opening_w(st, Z), 0, 1), 1.0)
        return d_hem, d_open
    # no extra smoothing: the body and skirt fields are smooth already, and the two sides of
    # the waist seam (skirt / body pieces) must keep identical weights
    return B.assemble(ctx, spec, pieces, edge_fn=edge_fn, smooth=None)


# ---------------------------------------------------------------------------
# buttons and lace loops
# ---------------------------------------------------------------------------
def _front_hit(outer, x, z, y0=-0.35):
    return hit(outer, v3(x, y0, z), v3(0, 1, 0), 0.36)


def place_trims(ctx, st, outer, tm, tl, tc):
    K = ctx.K
    br = st["button_r"]
    lp = st["lapels"]
    if lp:
        z0, z1 = lp["z"]
        for s in (1, -1):
            for i in range(lp["buttons"]):
                z = z0 + 0.022 + (z1 - z0 - 0.05) * i / (lp["buttons"] - 1)
                ow = float(opening_w(st, z))
                (x0, zz0), (x1, zz1) = lapel_line(st, s)
                xe = abs(x0 + (x1 - x0) * (z - zz0) / (zz1 - zz0))
                pb, nb = _front_hit(outer, s * (xe - 0.012), z)
                if lp["lace"]:
                    pa, _ = _front_hit(outer, s * (ow + 0.007), z)
                    pts = np.array([pa + (pb - pa) * k / 4.0 for k in range(5)])
                    tl.strip(outer, pts, 0.0105, lift=0.0010)
                tm.button(pb + nb * 0.0008, nb, r=br, h=0.0032)
    fb = st.get("front_buttons", 0)
    if fb:
        # buttons down the wearer's right front edge (x < 0), from the neck to the skirt
        zs = np.linspace(1.265, 0.62, fb)
        for z in zs:
            ow = float(opening_w(st, z))
            p, n = _front_hit(outer, -(ow + 0.013), z)
            tm.button(p, n, r=br, h=0.0032)
    # cuffs: buttons in a row along the forearm on the outer-back side of the cuff
    for s in (1, -1):
        E, W = K.side("elbow", s), K.side("wrist", s)
        ax = nrm(W - E)
        side = nrm(np.cross(ax, v3(0, 1, 0))) * s
        side = nrm(side + v3(0, 0.6, 0))
        n = st["cuff_buttons"]
        for i in range(n):
            t = st["cuff_t0"] + 0.05 + (st["sleeve_end"] - st["cuff_t0"] - 0.09) * i / max(n - 1, 1)
            c = E + (W - E) * t
            p, nn = hit(outer, c + side * 0.10, -side, 0.10)
            if st["cuff_lace"]:
                up = nrm(np.cross(nn, ax))
                pts = np.array([p + up * (0.012 - 0.030 * k / 3.0) for k in range(4)])
                tl.strip(outer, pts, 0.0095, lift=0.0009)
            tm.button(p + nn * 0.0006, nn, r=br * 0.85, h=0.003, segs=6)
    # pocket flaps
    pk = st["pockets"]
    if pk:
        n = pk["buttons"]
        for s in (1, -1):
            for i in range(n):
                a = math.radians(pk["a"][0] + 7.0 + (pk["a"][1] - pk["a"][0] - 14.0) * i / max(n - 1, 1))
                d = v3(s * math.sin(a), -math.cos(a), 0)
                zc = pk["z"][0] + (0.012 if pk["on_flap"] else -0.018)
                p, nn = hit(outer, v3(0, 0.01, zc) + d * 0.40, -d, 0.40)
                if pk["lace"]:
                    top = hit(outer, v3(0, 0.01, pk["z"][0] + 0.036) + d * 0.40, -d, 0.40)[0]
                    pts = np.array([p + (top - p) * k / 3.0 for k in range(4)])
                    tl.strip(outer, pts, 0.0095, lift=0.0009)
                tm.button(p + nn * 0.0006, nn, r=br * 0.9, h=0.003, segs=6)
    # back: a button at the top of each pleat group
    if st["back_buttons"]:
        for s in (1, -1):
            a = math.radians(118.0)
            d = v3(s * math.sin(a), -math.cos(a), 0)
            p, nn = hit(outer, v3(0, 0.01, 0.905) + d * 0.40, -d, 0.40)
            tm.button(p, nn, r=br, h=0.0032)
    # shoulder strap (left shoulder: it keeps the pouch belt in place) and its button
    if st.get("shoulder_strap"):
        S, Cl = K.side("shoulder", 1), K["l_clavicle"]
        a = S + v3(-0.01, 0.0, 0.0)
        b = Cl + v3(0.088, 0.0, 0.0)
        up = v3(0, 0, 1)
        pts = []
        for k in range(5):
            q = a + (b - a) * k / 4.0
            pts.append(hit(outer, q + up * 0.15, -up, 0.20)[0])
        tc.strip(outer, np.array(pts), 0.022, lift=0.0015)
        p, nn = hit(outer, b + v3(0.005, 0, 0) + up * 0.15, -up, 0.20)
        tm.button(p + nn * 0.0015, nn, r=br * 0.8, h=0.003, segs=6)


def skirt_catalog(st):
    """Catalog "skirt": the hems of the three panels (left leg, Godot bind space). The driver
    uses the legacy constants (CharacterBodyMesh.SKIRT_HEMS), which these coats keep."""
    return {"hems_godot": [list(h) for h in SKIRT_HEMS_GODOT], "hem_back": st["hem"],
            "hem_front": st["hem"] + st["front_rise"], "vent_top": st["vent_top"],
            "panels": ["upper_leg_front_helper", "upper_leg_thigh_helper", "upper_leg_rear_helper"]}
