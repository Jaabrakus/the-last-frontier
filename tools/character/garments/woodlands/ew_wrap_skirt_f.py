"""Wool wrap skirt (costume bible §3.3, §3.8 `ew_wrap_skirt_f`, §7).

A piece of broadcloth about two yards long, in blue, red or black, wrapped tightly round
the hips (Zeisberger, Loskiel [R1]). Mary Jemison's was broadcloth with the list (white
selvedge) at top and bottom, tied on with a string, the top quarter-yard turned down over
the string so that the list and a band of cloth showed [P4]. Dress skirts were edged with
silk ribbon or gartering, set with silver brooches [P2]. Grade A.

Game limit (design §5.6, v1): the skirt panels are rigid from the hip, so the hem ships at
about 7 cm below the knee joint; Jemison's hung halfway between knee and ankle. The
catalog entry says so ("history") and declares the hem points for the helper driver
("skirt"). Cloth: the body hull hanging straight down from the hips, with a turned-down
band at the top and the overlapping edge of the wrap at the front left. Weights: the pelvis
at the waist, the skirt panel helpers below the hip crease (front / side / back by the
angle round the body, left and right never fully one-sided).
"""

import math

import numpy as np

from lib.sdf import Fn, Inter, smoothstep, v3, zslab

from garments.woodlands import _common as C

RIBBONS = ["ribbon_red", "ribbon_green", "ribbon_yellow", "ribbon_blue", "ribbon_white", "ribbon_black"]
HEM, TOP = 0.40, 0.930
BAND = (0.853, 0.936)
WOOL = 0.0024
WRAP_EDGE_DEG = 28.0          # the outer layer's edge: this far left of the front centre
BACK_TH = math.pi / 2         # theta of the back centre (the sheet's seam)

SPEC = C.spec(
    id="ew_wrap_skirt_f", name="Wrap skirt, wool stroud", slot="legs.lower",
    layer={"default": 20, "thighs": 35, "shins": 35},
    description="A length of wool broadcloth wrapped tightly round the hips and tied, the top turned down over the "
                "string to show the white list, with rows of silk ribbon above the hem.",
    history="About two yards of broadcloth wrapped round the hips (Zeisberger, Loskiel [R1]); Jemison's had the list "
            "at top and bottom and the top quarter-yard turned down over the string [P4]; dress skirts were edged "
            "with ribbon [P2]. Game limit: it hangs to just below the knee; Jemison's reached halfway to the ankle.",
    zones=[C.WZone(0, "cloth", "WOOL", ["stroud_blue", "stroud_red", "logwood_black"], name="cloth",
                   bands={"axis": "x", "from": "hem", "list": {"width": 0.016, "color": "linen_white"},
                          "rows_max": 3, "row_width": 0.012, "gap": 0.008, "offset": 0.03, "palette": RIBBONS,
                          "default": []}),
           C.WZone(1, "trim", "WOOL", ["stroud_blue", "stroud_red", "logwood_black"], name="turned-down band",
                   bands={"axis": "y", "from": "band's lower edge", "list": {"width": 0.016, "color": "linen_white"},
                          "rows_max": 0})],
    evidence="A", sources=["R1", "P4", "P2"], budget=3600, tags=["women"],
    extra={"edge_uv": {"x": "distance from the hem, metres (list, then ribbon rows)",
                       "y": "distance from the turned-down band's lower edge (band) or the wrap edge (cloth), "
                            "metres"}},
)


def clear(z):
    return float(np.interp(z, [0.36, 0.55, 0.70, 0.80, 0.88, 0.95], [0.026, 0.022, 0.018, 0.014, 0.011, 0.010]))


def knee_room(TH, Z):
    """Extra clearance in front of the knees toward the hem: the knees come forward in a
    bent-leg stance faster than the front skirt panels follow them."""
    front = np.clip(np.cos(TH - C.FRONT), 0.0, 1.0) ** 2
    return 0.020 * front * smoothstep(0.62, 0.42, Z)


def skirt_folds(TH, Z):
    a = 0.0055 * smoothstep(0.80, HEM, Z)
    return a * (np.sin(9.0 * TH + 0.3) * 0.6 + np.sin(5.0 * TH + 2.0) * 0.4)


def build(ctx):
    b = C.Builder(SPEC)
    hull = C.Hull(ctx)
    form = hull.form(clear, hang_top=TOP, folds=lambda TH, Z: skirt_folds(TH, Z) + knee_room(TH, Z),
                     z_range=(HEM - 0.04, 0.97))
    solid = Inter(form.node(), zslab(HEM - 0.03, 0.96))
    # the skirt and the turned-down band are radial forms: regular sheets (rows down,
    # columns round the body from the back centre; the seam column is duplicated)
    th = BACK_TH + np.linspace(0.0, 2 * math.pi, 40, endpoint=False)
    zs = np.linspace(TOP, HEM, 14)
    P = np.array([form.point(th, np.full(len(th), z), extra=-WOOL * 0.5) for z in zs])
    C.sheet_piece(b, "skirt", P, WOOL, 0, closed_u=True)
    zb = np.linspace(BAND[1], BAND[0], 4)
    P = np.array([form.point(th, np.full(len(th), z), extra=WOOL * 0.5 + 0.0012) for z in zb])
    C.sheet_piece(b, "band", P, WOOL, 1, closed_u=True)
    # the overlapping edge of the wrap: a narrow strip of the outer layer lying on the skirt
    th0 = C.FRONT + math.radians(WRAP_EDGE_DEG)
    zs = np.linspace(BAND[0] + 0.004, HEM, 14)
    rows = []
    for z in zs:
        r = float(form.radius(th0, z)) + 0.0022
        dth = 0.028 / r
        t3 = th0 + np.linspace(-dth, 0.0, 3)
        rows.append(form.point(t3, np.full(3, z), extra=0.0022))
    P = np.array(rows)
    u_edge = np.linalg.norm(P - P[:, -1:], axis=2)
    C.sheet_piece(b, "wrap_edge", P, 0.0020, 0, d_side=u_edge)
    bt = b.build()
    ob, V = bt.ob, bt.V

    # UVs: a cylinder round the body (u metres round, v metres down; the seam at the back)
    part = np.full(len(ob.data.polygons), -1, int)
    uv = C.loop_uvs(ob, [], part, vertex_uv=bt.attrs["uv"], vertex_uwrap=bt.attrs["uwrap"])

    skirt = bt.vmask("skirt")
    band = bt.vmask("band")
    edge = bt.vmask("wrap_edge")
    e = np.nan_to_num(bt.attrs["edge"], nan=1.0)
    d_hem = np.where(skirt | edge, e[:, 0], 1.0)
    d_open = np.where(band, e[:, 0], np.where(edge, e[:, 1], 1.0))

    # weights: pelvis at the waist, the panels below the hip crease
    W = C.panel_W(ctx, V, lr_width=0.16, pelvis_z=(0.64, 0.84), lr_gain=0.42)
    W = C.smooth(ob, W, 2, 0.4)
    W = C.normalize(W)

    col = np.ones(len(V))
    col *= C.inner_shade(V, Inter(hull.form(clear, hang_top=TOP, folds=skirt_folds).node(), zslab(0.3, 1.0)),
                         dark=0.72, depth=0.0004)
    ang = np.arctan2(V[:, 1] - 0.005, V[:, 0])
    col *= 1.0 + 0.08 * np.clip(skirt_folds(ang, V[:, 2]) / 0.0055, -1, 1)
    col[band] *= 0.94
    # hem points of the panels for the helper driver (left leg, Godot space: x, z, -y)
    hems = []
    for ang_deg in (35.0, 90.0, 145.0):
        th = -math.pi / 2 + math.radians(ang_deg)        # from the front toward the left (+x)
        p = form.point(th, HEM)
        hems.append([round(float(p[0]), 3), HEM, round(float(-p[1]), 3)])
    SPEC.skirt = {"hems_godot": hems, "note": "front, side, back hem points (left leg) for SKIRT_HEMS / the floor "
                                              "lift; the legacy coat's are higher (0.525-0.585)"}
    cands = ["pelvis_center", "pelvis_side", "thigh_upper_l", "thigh_lower_l", "thigh_upper_r", "thigh_lower_r"]
    return C.finish(ctx, SPEC, bt, W, uv, hide_candidates=cands, edge=(d_hem, d_open), colors=C.rgba(col),
                    focus=((0.0, 0.0, 0.66), 0.80))
