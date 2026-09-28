"""Wool stroud breechcloth (costume bible §3.2, §3.8 `ew_breechcloth`).

A strip of wool stroud about a yard long and 9-10 inches wide, passed between the legs and
over a belt front and back, the ends hanging as flaps [P1][P3][R3]; blue most common, red
occasional [R3], red, blue or black cloth [P2]; the white undyed selvedge ("list") often
left visible [R15][P4]. Grade A.

Pieces: the belt (a cord at the waist), the part between the legs (close over the skin,
under the belt) and the front and back flaps folded over the belt and hanging free in front
of the thighs (hull form: they bridge the thighs and clear the leggings' tops). Weights:
belt band-averaged on the torso; the part between the legs the body's, smoothed and biased
to the pelvis; the flaps the pelvis at the belt and the skirt panel helpers below, front
panels for the front flap and back panels for the back one, left / right blended across
the whole width (design §7: "weight them to the front and back panels plus the pelvis").
"""

import math

import numpy as np

from lib.sdf import Fn, Inter, Offset, Onion, peval, smoothstep, v3, zslab

from garments.woodlands import _common as C

SPEC = C.spec(
    id="ew_breechcloth", name="Wool breechcloth", slot="legs.lower", layer={"default": 20, "thighs": 35},
    description="A strip of wool stroud about a yard long and nine inches wide, passed between the legs and over a "
                "belt, the ends hanging as flaps front and back with the white selvedge showing.",
    history="About a yard long and 9-10 inches wide, passed between the legs and over a belt front and back "
            "(Smith [P1], Doddridge [P3]); blue most common, red occasional [R3]; the white list of the stroud was "
            "often left visible [R15][P4].",
    zones=[C.WZone(0, "cloth", "WOOL", ["stroud_blue", "stroud_red", "logwood_black"], name="cloth",
                   bands={"axis": "x", "from": "flap ends", "rows_max": 1, "row_width": 0.018, "gap": 0.004,
                          "palette": ["linen_white", "linen_unbleached"], "default": ["linen_white"],
                          "name": "white list (selvedge)"}),
           C.WZone(1, "leather", "LEA", ["leather_brown", "buckskin_smoked", "logwood_black"], name="belt")],
    evidence="A", sources=["P1", "P3", "R3", "P2", "R15", "P4"], budget=2200, tags=["men"],
    extra={"skirt": {"hems_godot": None, "note": "flaps hang from the belt to z 0.60-0.62, above the legacy skirt hems"},
           "edge_uv": {"x": "distance from the flap's lower end, metres (the white list)",
                       "y": "distance from the flap's side edges, metres"}},
)

BELT_Z = (0.929, 0.942)
FOLD = [(0.954, 0.0070), (0.9525, 0.0120), (0.9475, 0.0142)]


def flap_rows(z_end, n=11):
    zs = list(np.linspace(0.935, z_end, n))
    cl = list(np.interp(zs, [0.60, 0.72, 0.80, 0.86, 0.935], [0.027, 0.027, 0.025, 0.020, 0.0150]))
    return [f[0] for f in FOLD] + zs, [f[1] for f in FOLD] + cl


def flap_grid(form, center_th, z_rows, c_rows, half_w=0.115, cols=9):
    P = np.zeros((len(z_rows), cols, 3))
    for i, (z, c) in enumerate(zip(z_rows, c_rows)):
        r = float(form.radius(center_th, z)) + c
        dth = half_w / r
        th = center_th + np.linspace(-dth, dth, cols)
        P[i] = form.point(th, np.full(cols, z), extra=c)
    return P


def build(ctx):
    body = C.body_f(ctx)
    b = C.Builder(SPEC)
    hull = C.Hull(ctx)
    form = hull.form(0.0, hang_top=0.955)
    # belt: a flat cord round the waist, 1.3 cm tall, 5.5-11.5 mm over the skin
    arms_out = Fn(lambda X, Y, Z: np.abs(X) - 0.24, (-0.24, -1, -1), (0.24, 1, 2))
    belt = Inter(Inter(Onion(Offset(body, 0.0096), 0.0030), zslab(*BELT_Z)), arms_out)
    b.sdf("belt", belt, 0.0012, 360, 1, max_tris=340)
    # between the legs: close over the skin under the belt, 17 cm wide at the belt,
    # narrowing to 7 cm in the crotch

    def width(X, Y, Z):
        return np.abs(X) - (0.036 + 0.050 * smoothstep(0.75, 0.90, Z))
    strip = Inter(Inter(Onion(Offset(body, 0.0042), 0.0011), zslab(0.726, 0.9405)),
                  Fn(width, (-0.1, -0.2, 0.7), (0.1, 0.2, 1.0)))
    b.sdf("strip", strip, 0.0013, 520, 0, max_tris=520)
    zf, cf = flap_rows(0.620)
    C.sheet_piece(b, "flap_front", flap_grid(form, C.FRONT, zf, cf), 0.0024, 0)
    zb, cb = flap_rows(0.600)
    C.sheet_piece(b, "flap_back", flap_grid(form, C.BACK, zb, cb), 0.0024, 0)
    bt = b.build()
    ob, V = bt.ob, bt.V

    # UVs: flaps their own (u across, v down), the rest a torso cylinder
    part = np.zeros(len(ob.data.polygons), int)
    part[bt.pmask("flap_front", "flap_back")] = -1
    uv = C.loop_uvs(ob, [C.torso_cyl(ctx)], part, vertex_uv=bt.attrs["uv"])
    e = bt.attrs["edge"]
    flap = bt.vmask("flap_front", "flap_back")
    d_hem = np.where(flap, np.nan_to_num(e[:, 0], nan=1.0), 1.0)
    d_open = np.where(flap, np.nan_to_num(e[:, 1], nan=1.0), 1.0)

    # weights: the belt and the fold over it rigid on the pelvis (the iliac crest; the
    # skin's spine blend there stretches in a crouch); between the legs the body's; the
    # flaps from the pelvis above the hip crease to the skirt panels below it, left and
    # right never fully one-sided (a flap spans both thighs)
    bi = {n: i for i, n in enumerate(ctx.bones)}
    W = np.zeros((len(V), len(ctx.bones)))
    m = bt.vmask("belt")
    W[m, bi["pelvis"]] = 1.0
    m = bt.vmask("strip")
    Ws = C.body_W(ctx, V[m], torso=False)
    t = smoothstep(0.86, 0.92, V[m, 2])[:, None]
    Wp = np.zeros_like(Ws)
    Wp[:, bi["pelvis"]] = 1.0
    W[m] = Ws * (1 - t) + Wp * t
    for name in ("flap_front", "flap_back"):
        m = bt.vmask(name)
        W[m] = C.panel_W(ctx, V[m], lr_width=0.115, pelvis_z=(0.74, 0.87), lr_gain=0.35)
    W = C.smooth(ob, W, 2, 0.4, lock=bt.vmask("belt", "flap_front", "flap_back"))
    W = C.normalize(W)

    col = np.ones(len(V))
    col[flap] *= 0.93 + 0.07 * smoothstep(0.0, 0.03, np.nan_to_num(e[flap, 0], nan=1.0))
    return C.finish(ctx, SPEC, bt, W, uv, hide_candidates=["pelvis_center"], edge=(d_hem, d_open),
                    colors=C.rgba(col), focus=((0.0, 0.0, 0.80), 0.62))
