"""Waistcoats (costume bible §5.1-5.3): the British regimental waistcoat (sleeveless, single-
breasted, to the top of the thigh, pocket flaps) and the French veste (sleeved, longer,
buttoned down the front).

The body is built on the same bridged torso as the coats (_base.coat_torso_shapes) at the
mid band (11 mm), so the coat (17 mm on the same form) always clears it by 6 mm; below the
waist the skirts hang over the breeches (their form + 14.5 mm) and take the coat skirt's
weight field (lib.weights.skirt_weights through _base.skirt_W), so waistcoat and coat
skirts keep their order when the thighs push them.
Zones: 0 cloth, 3 buttons.
"""

import math

import numpy as np

from lib.body_shapes import arm_shapes, neck_shape
from lib.remesh import material
from lib.sdf import Fn, Inter, SymUnion, Union, smoothstep, v3, zslab

from . import _base as B
from . import _legs as L
from ._trims import Trims, hit

BRITISH = {
    "name": "br_waistcoat", "sleeves": False,
    "hem": (0.800, 0.835, 0.875),            # front, side, back
    "split_z": 0.915,                        # the fronts part below the last button
    "split_w": 0.045,                        # half-gap of the fronts at the hem
    "v_neck": 1.165,                         # bottom of the neck opening
    "buttons": 10, "pocket": {"z": (0.855, 0.885), "a": (32.0, 72.0), "buttons": 3},
    "sleeve_end": None,
}
FRENCH = {
    "name": "fr_veste", "sleeves": True,
    "hem": (0.735, 0.765, 0.800),
    "split_z": 0.905, "split_w": 0.050, "v_neck": 1.175,
    "buttons": 14, "pocket": {"z": (0.800, 0.835), "a": (30.0, 74.0), "buttons": 3},
    "sleeve_end": 0.885, "sleeve_out": 0.0092,
}

VEST_OUT = 0.0110           # mid band (<= 12 mm) on the bridged torso
SKIRT_OUT = 0.0145          # over the breeches (<= 11 mm) below the waist
THICK = 0.0028


def hem_z(st, X, Y):
    ang = np.degrees(np.arctan2(np.abs(X), -Y))
    f, s_, b = st["hem"]
    return np.where(ang < 90.0, f + (s_ - f) * smoothstep(20.0, 90.0, ang), s_ + (b - s_) * smoothstep(90.0, 160.0, ang))


def outer_form(ctx, st):
    K = ctx.K
    base = Union([B.coat_torso_shapes(K), neck_shape(K)], k=0.035)
    if not st["sleeves"]:
        # the shoulder straps pass over the deltoids (build_body's cape base), which the
        # torso alone leaves out
        from lib.sdf import Sphere
        delts = [Sphere(K.side("shoulder", s) + v3(s * 0.007, 0.002, 0.004), 0.042) for s in (1, -1)]
        base = SymUnion(base, delts[0], delts[1], k=0.04)
    torso = B.bumped(base, VEST_OUT, [], r_max=VEST_OUT + 0.001)
    hips = Inter(B.bumped(L.breeches_base(K, L.lower_body(ctx)), SKIRT_OUT, [], r_max=SKIRT_OUT + 0.001),
                 zslab(0.60, 0.99))
    body = Union([torso, hips], k=0.02)
    if st["sleeves"]:
        sl = [B.bumped(arm_shapes(K, s), st["sleeve_out"], [], r_max=st["sleeve_out"] + 0.001) for s in (1, -1)]
        body = SymUnion(body, sl[0], sl[1], k=0.02)
    return body


def region(ctx, st):
    K = ctx.K
    nk, ha = K["neck"], K["heada"]
    a = v3(0, nk[1] + 0.012, nk[2] - 0.07)
    b = v3(0, ha[1] + 0.012, ha[2] + 0.12)
    arms = [(K.side("elbow", s), K.side("wrist", s)) for s in (1, -1)]

    def f(X, Y, Z):
        shape = np.broadcast(X, Y, Z).shape
        X, Y, Z = [np.broadcast_to(q, shape) for q in (X, Y, Z)]
        r = hem_z(st, X, Y) - Z
        # the fronts part below split_z
        w = st["split_w"] * smoothstep(st["split_z"], min(st["hem"]), Z)
        r = np.maximum(r, -np.maximum(np.abs(X) - w, Y + 0.02))
        # neck: V opening in front and a round neck behind
        wv = 0.004 + np.maximum(Z - st["v_neck"], 0.0) * 0.42
        r = np.maximum(r, -np.maximum.reduce([np.abs(X) - wv, st["v_neck"] - Z, Y + 0.01]))
        P = np.stack([X, Y, Z], -1).reshape(-1, 3)
        t = np.clip(((P - a) @ (b - a)) / ((b - a) @ (b - a)), 0.0, 1.0)
        dn = (np.linalg.norm(P - (a + t[:, None] * (b - a)), axis=1) - 0.066).reshape(shape)
        r = np.maximum(r, -dn)
        if st["sleeves"]:
            for E, W in arms:
                L_ = float(np.linalg.norm(W - E))
                u = ((P - E) @ (W - E)) / (L_ * L_)
                dax = np.linalg.norm(P - (E + np.clip(u, 0, 2)[:, None] * (W - E)), axis=1)
                cut = np.maximum((st["sleeve_end"] - u) * L_, dax - 0.10)
                r = np.maximum(r, -cut.reshape(shape))
        else:
            # armholes: the shoulder cut off at |x| = 0.137 (build_body's waistcoat), rounded
            # into the side seam below the armpit
            ax = 0.137 + 0.012 * (1 - smoothstep(1.08, 1.17, Z))
            r = np.maximum(r, np.abs(X) - ax)
        return np.maximum(r, Z - 1.42)
    return Fn(f)


def vest(ctx, spec, st):
    K = ctx.K
    outer = outer_form(ctx, st)
    reg = region(ctx, st)

    def vis(P):
        X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
        L_ = np.full(len(P), 0.034)
        L_ = np.where(Y < -0.02, 0.026, L_)
        L_ = np.where(np.abs(Z - hem_z(st, X, Y)) < 0.03, 0.022, L_)
        return L_

    ob = B.sheet(spec.id, outer, reg, 0.003, 2400, material(spec.id, "#8e2b21"), sizing=vis, feature_deg=35.0,
                 sharp_deg=60, domain=zslab(min(st["hem"]) - 0.05, 1.44))
    B.solidify(ob, THICK, rim_only=True)
    sol = Inter(outer, reg)
    tm = Trims()
    # buttons down the wearer's right front edge
    zs = np.linspace(st["v_neck"] - 0.012, st["split_z"] - 0.005, st["buttons"])
    for z in zs:
        p, n = hit(sol, v3(-0.011, -0.30, z), v3(0, 1, 0), 0.32)
        tm.button(p, n, r=0.0065, h=0.0026, segs=6)
    pk = st["pocket"]
    for s in (1, -1):
        for i in range(pk["buttons"]):
            a_ = math.radians(pk["a"][0] + 6.0 + (pk["a"][1] - pk["a"][0] - 12.0) * i / max(pk["buttons"] - 1, 1))
            d = v3(s * math.sin(a_), -math.cos(a_), 0)
            p, n = hit(sol, v3(0, 0.0, pk["z"][0] - 0.012) + d * 0.35, -d, 0.35)
            tm.button(p, n, r=0.0058, h=0.0024, segs=6)

    def weights(ctx_, V):
        W = B.body_W(ctx_, V)
        low = (V[:, 2] < 0.94) & ~B.sleeve_mask(K, V)
        return B.skirt_W(ctx_, V, W, low, 0.525, 0.80)

    def shade(V, inner):
        c = np.ones(len(V))
        c[inner] *= 0.75
        X, Y, Z = V[:, 0], V[:, 1], V[:, 2]
        c *= 1 - 0.12 * (1 - smoothstep(0.0, 0.06, Z - hem_z(st, X, Y)))
        return c

    pieces = [B.Piece(ob, "cloth", zone=B.CLOTH, uv="body", weights=weights, shade=shade),
              B.Piece(tm.to_object(spec.id + "_buttons"), "trim", zone=B.METAL, uv="attr")]

    def edge_fn(V):
        X, Y, Z = V[:, 0], V[:, 1], V[:, 2]
        return np.clip(Z - hem_z(st, X, Y), 0, 1), np.where(Y < 0, np.clip(np.abs(X), 0, 1), 1.0)
    return B.assemble(ctx, spec, pieces, edge_fn=edge_fn, smooth=(1, 0.3))
