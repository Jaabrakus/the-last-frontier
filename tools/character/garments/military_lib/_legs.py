"""Legwear: regimental breeches (British / French), long gaiters (British 1750s black or
white linen, French white thigh-length), knit stockings.

All are thin shells over the body (lib.layers envelopes: breeches mid 20 <= 11 mm over
the skin, gaiters legwear 30 at 12-19 mm, stockings base 10 <= 3 mm), weighted from the
body (the nearest body point) except the garter straps (rigid on the shin) and the
buttons / buckles (rigid per piece on the cloth under them).
"""

import numpy as np

from lib.body_shapes import foot_shapes, leg_shapes
from lib.remesh import material, sdf_object
from lib.sdf import Ellipsoid, Fn, Inter, Union, mirror_x, peval, smoothstep, v3, xband, zslab

from . import _base as B
from ._trims import Trims, hit

# ---------------------------------------------------------------------------
# breeches
# ---------------------------------------------------------------------------
BREECHES_TOP = 1.0
BREECHES_BOTTOM = 0.405          # the knee band just below the knee (thigh_lower ends at ~0.421)
BR_IN, BR_OUT = 0.0050, 0.0095   # shell clearance over the skin (mid layer: <= 11 mm)


def breeches_base(K, body):
    """The body with the groin bridged by a fall-front panel and a fuller seat
    (build_body.breeches_node)."""
    hc = (K["l_upper_leg"] + mirror_x(K["l_upper_leg"])) * 0.5
    fall = Ellipsoid(hc + v3(0, -0.028, -0.065), (0.080, 0.045, 0.080))
    seat = Ellipsoid(hc + v3(0, 0.050, -0.040), (0.130, 0.070, 0.090))
    return Union([body, Union([fall, seat], k=0.02)], k=0.025)


def _knee_band(X, Y, Z):
    return 0.0016 * B.smooth_band(Z, BREECHES_BOTTOM, BREECHES_BOTTOM + 0.028, 0.0025)


def _waist_band(X, Y, Z):
    return 0.0010 * B.smooth_band(Z, BREECHES_TOP - 0.035, BREECHES_TOP + 0.05, 0.002)


def _fall(X, Y, Z):
    """The fall front flap: a raised panel across the front below the waistband."""
    return 0.0011 * B.smooth_band(np.abs(X), -1.0, 0.078, 0.003) * B.smooth_band(Z, 0.875, BREECHES_TOP - 0.033, 0.003) \
        * smoothstep(-0.02, -0.05, Y)


def lower_body(ctx):
    """The body's torso, legs and feet as body_node blends them (arms and head left out, so
    nothing hanging at the hips is caught by a legwear form)."""
    from lib.sdf import SymUnion
    g = ctx.body_groups()
    legs = [Union([g["leg_" + sd], g["foot_" + sd]], k=0.02) for sd in "lr"]
    return SymUnion(g["torso"], legs[0], legs[1], k=0.035)


def breeches(ctx, spec, knee_buttons=4, fall_buttons=3):
    K = ctx.K
    base = breeches_base(K, lower_body(ctx))
    outer = B.bumped(base, BR_OUT, [_knee_band, _waist_band, _fall], r_max=BR_OUT + 0.003)
    region = zslab(BREECHES_BOTTOM, BREECHES_TOP)
    domain = zslab(BREECHES_BOTTOM - 0.04, BREECHES_TOP + 0.04)

    def vis(P):
        z = P[:, 2]
        L = np.full(len(P), 0.030)
        L = np.where((z < BREECHES_BOTTOM + 0.045) | (z > BREECHES_TOP - 0.045), 0.015, L)
        L = np.where((np.abs(P[:, 0]) < 0.10) & (z > 0.84) & (P[:, 1] < 0), 0.018, L)
        return L

    ob = B.sheet(spec.id, outer, region, 0.003, 1300, material(spec.id, "#8e2b21"), sizing=vis, feature_deg=35.0,
                 sharp_deg=60, domain=domain)
    B.solidify(ob, 0.003, rim_only=True)
    outer = Inter(outer, region)
    tr = Trims()
    # knee buttons up the outer side above the band, and the knee buckle on the band
    for s in (1, -1):
        Kn = K.side("knee", s)
        for i in range(knee_buttons):
            z = BREECHES_BOTTOM + 0.040 + 0.023 * i
            p, n = hit(outer, v3(s * 0.26, Kn[1] - 0.004, z), v3(-s, 0, 0), 0.15)
            tr.button(p, n, r=0.0055, h=0.0022, segs=6)
        p, n = hit(outer, v3(s * 0.26, Kn[1] - 0.012, BREECHES_BOTTOM + 0.014), v3(-s, 0, 0), 0.15)
        tr.buckle(p, n, v3(0, 0, 1), w=0.020, h=0.016, bar=0.0028, t=0.0022)
    for i in range(fall_buttons):
        x = (i - (fall_buttons - 1) / 2.0) * 0.05
        p, n = hit(outer, v3(x, -0.2, BREECHES_TOP - 0.018), v3(0, 1, 0), 0.2)
        tr.button(p, n, r=0.0065, h=0.0025, segs=6)
    trims = tr.to_object(spec.id + "_trims")

    def shade(V, inner):
        c = np.ones(len(V))
        c[inner] *= 0.72
        return c

    pieces = [B.Piece(ob, "cloth", zone=B.CLOTH, uv="body", shade=shade),
              B.Piece(trims, "trim", zone=B.METAL, uv="attr")]
    crotch = (lambda V: (np.abs(V[:, 0]) < 0.035) & (V[:, 2] < 0.78) & (V[:, 2] > 0.60), 8, 0.5)
    return B.assemble(ctx, spec, pieces, edge_fn=lambda V: (np.clip(V[:, 2] - BREECHES_BOTTOM, 0, 1),
                                                          np.clip(BREECHES_TOP - V[:, 2], 0, 1)),
                      local_smooth=[crotch])


# ---------------------------------------------------------------------------
# long gaiters
# ---------------------------------------------------------------------------
GA_IN, GA_OUT = 0.0135, 0.0165       # legwear band (12-19 mm) over the leg
GARTER_Z = (0.372, 0.393)            # strap 8-10 cm below the knee joint (clear of the knee's bend)


def leg_form(K, s):
    return Union([leg_shapes(K, s), foot_shapes(K, s)], k=0.02)


def gaiter_bottom(Y, A_y):
    """Lower edge height over the shoe: low at the heel and sides, rising over the instep
    so the shoe's vamp and toe stay free."""
    return 0.050 + 0.7 * np.maximum(0.0, (A_y - 0.03) - Y)


def gaiters(ctx, spec, top=0.575, buttons=11, garter=True, foot_out=0.0115):
    K = ctx.K
    tr = Trims()
    outers = []
    for s in (1, -1):
        leg = leg_form(K, s)
        A = K.side("ankle", s)

        def rad(X, Y, Z):
            # over the shoe the gaiter comes in to foot_out
            return foot_out + (GA_OUT - foot_out) * smoothstep(0.07, 0.13, Z)

        def flap(X, Y, Z, s=s, A=A):
            ang = np.degrees(np.arctan2(Y - A[1] - 0.004, (X - A[0]) * s))    # 0 = straight out
            return 0.0010 * B.smooth_band(ang, -14.0, 14.0, 4.0) * smoothstep(0.05, 0.08, Z)

        def strap(X, Y, Z):
            return 0.0018 * B.smooth_band(Z, GARTER_Z[0], GARTER_Z[1], 0.0015) if garter else 0.0 * Z

        outers.append(B.bumped(leg, rad, [flap, strap], r_max=GA_OUT + 0.004))
    A_y = K.side("ankle", 1)[1]

    def cut(X, Y, Z):
        return np.maximum(gaiter_bottom(Y, A_y) - Z, Z - top)
    outer = Union(outers, k=0.0)
    region = Fn(cut, (-2, -2, 0.0), (2, 2, top))

    def vis(P):
        z = P[:, 2]
        L = np.full(len(P), 0.028)
        L = np.where(z < 0.13, 0.015, L)
        L = np.where(np.abs(z - 0.5 * sum(GARTER_Z)) < 0.025, 0.012, L)
        L = np.where(z > top - 0.03, 0.016, L)
        return L
    ob = B.sheet(spec.id, outer, region, 0.0026, 1600, material(spec.id, "#e8e3d3"), sizing=vis, feature_deg=35.0,
                 sharp_deg=60, domain=zslab(-0.02, top + 0.04))
    B.solidify(ob, GA_OUT - GA_IN, rim_only=True)
    outer = Inter(outer, region)
    # buttons up the outer side, a buckle on each garter
    for s in (1, -1):
        A, Kn = K.side("ankle", s), K.side("knee", s)
        for i in range(buttons):
            z = 0.085 + (top - 0.11) * i / (buttons - 1)
            t = (z - A[2]) / (Kn[2] - A[2])
            c = A + (Kn - A) * np.clip(t, 0, 1.2)
            if garter and abs(z - 0.5 * sum(GARTER_Z)) < 0.018:
                continue
            if abs(z - (Kn[2] + 0.01)) < 0.035:
                continue                  # none over the knee joint (they would fold with it)
            p, n = hit(outer, v3(c[0] + s * 0.15, c[1] + 0.004, z), v3(-s, 0, 0), 0.15)
            tr.button(p, n, r=0.0048, h=0.0022, segs=6)
        if garter:
            z = 0.5 * sum(GARTER_Z)
            t = (z - A[2]) / (Kn[2] - A[2])
            c = A + (Kn - A) * t
            p, n = hit(outer, v3(c[0] + s * 0.03, c[1] - 0.12, z), v3(0, 1, 0), 0.12)
            tr.buckle(p + n * 0.0012, n, v3(0, 0, 1), w=0.018, h=0.020, bar=0.003, t=0.0025)
    trims = tr.to_object(spec.id + "_trims")

    def zone_fn(C, N, L):
        z = np.full(len(C), B.CLOTH)
        if garter:
            z[(C[:, 2] > GARTER_Z[0] - 0.001) & (C[:, 2] < GARTER_Z[1] + 0.001) & (L == 0)] = B.LACE
        return z

    def weights(ctx_, V):
        # the garter strap is part of the sheet and follows the leg like the cloth (5 cm
        # below the knee the leg is on the knee bone anyway); a rigid band inside one sheet
        # only moves the stretch to its edges
        return B.body_W(ctx_, V)

    def shade(V, inner):
        c = np.ones(len(V))
        c[inner] *= 0.7
        return c

    pieces = [B.Piece(ob, "cloth", zone_fn=zone_fn, uv="body", weights=weights, shade=shade),
              B.Piece(trims, "trim", zone=B.METAL, uv="attr")]
    Ay = K.side("ankle", 1)[1]
    return B.assemble(ctx, spec, pieces, leg_seam_out=True,
                      edge_fn=lambda V: (np.clip(V[:, 2] - gaiter_bottom(V[:, 1], Ay), 0, 1),
                                         np.clip(top - V[:, 2], 0, 1)))


# ---------------------------------------------------------------------------
# stockings
# ---------------------------------------------------------------------------
ST_IN, ST_OUT = 0.0005, 0.0030


def stockings(ctx, spec, top=0.60):
    K = ctx.K
    outer = B.bumped(Union([leg_form(K, s) for s in (1, -1)], k=0.0), ST_OUT, [], r_max=ST_OUT + 0.001)
    region = Fn(lambda X, Y, Z: Z - top, (-2, -2, -1), (2, 2, top))

    def vis(P):
        z = P[:, 2]
        return np.where(z < 0.16, 0.015, np.where(z > top - 0.03, 0.018, 0.023))
    ob = B.sheet(spec.id, outer, region, 0.0024, 1400, material(spec.id, "#233c78"), sizing=vis, feature_deg=40.0,
                 domain=zslab(-0.02, top + 0.04))
    pieces = [B.Piece(ob, "cloth", zone=B.CLOTH, uv="body")]
    return B.assemble(ctx, spec, pieces, edge_fn=lambda V: (np.clip(V[:, 2], 0, 1), np.clip(top - V[:, 2], 0, 1)))
