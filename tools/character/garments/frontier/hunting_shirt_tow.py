"""Caped hunting shirt of tow linen, fringed at the cape and the hem.

Costume bible §2.2 / §2.6 `hunting_shirt_tow` (grade A for the Pennsylvania / Virginia
backcountry from 1758; B for New York and New England before 1775): a loose frock reaching
about halfway down the thigh, wide enough to overlap in front (here a closed overlap with
a V at the neck and the skirt parting below the waist), large sleeves, a shoulder cape, the
cape and hem fringed, sometimes with fringe of a different colour [P3][R5]. Normally worn
in the `outer` slot over a shirt and waistcoat; `alt_slots` shirt for the summer look with
nothing under it.

Surfaces: main (zone 0 linen), fringe (zone 1: cards along the cape edge and the hem,
fringe.gdshader).
"""

import math

import numpy as np

from garments.frontier import _frontier_common as FC
from lib.catalog import GarmentSpec, Zone
from lib.pipeline import Surface
from lib.remesh import material, mesh_arrays, sdf_object
from lib.sdf import peval, smoothstep

SPEC = GarmentSpec(
    id="hunting_shirt_tow", name="Hunting shirt, caped and fringed", slot="outer", alt_slots=["shirt"], set="frontier",
    description=("Loose, caped frock of tow linen reaching halfway down the thigh, overlapped in front, with "
                 "fringe along the cape and the hem."),
    layer={"default": 40}, weights="body",
    zones=[Zone(0, "cloth", "LIN", ["linen_unbleached", "tow", "walnut_brown", "butternut", "indigo_mid", "drab"],
                "tow", name="cloth"),
           Zone(1, "fringe", "LIN", ["linen_unbleached", "tow", "ribbon_red", "linen_white", "stroud_blue",
                                     "walnut_brown"], "linen_unbleached", name="fringe")],
    surfaces={"main": "hunting_shirt_tow", "fringe": "hunting_shirt_tow_fringe"},
    evidence="A",
    history=("Doddridge: a loose frock halfway down the thigh with large sleeves and a large cape, sometimes fringed "
             "with cloth of a different colour; usually linsey or tow linen. Virginia troops wore it on the Forbes "
             "road in 1758."),
    sources=["P3", "R5", "R4", "P7"], budget={"tris_max": 6500},
    tags=["summer", "men", "women", "backcountry"],
    extra={"fabric_options": {"cloth": ["LIN", "HES", "WOOL"], "fringe": ["LIN", "HES", "WOOL"]},
           "fringe": {"surface": "hunting_shirt_tow_fringe", "shader": "res://assets/character/shaders/fringe.gdshader",
                      "zone": 1}},
)
SPEC.extra["deform_limits"] = FC.deform_limits(SPEC)

P = FC.CoatParams(off=0.015, sleeve_off=0.013, sleeve_off_lower=0.0145, sleeve_end=0.93, cuff=(0.865, 0.0035),
                  hem=0.585, front_rise=0.03, skirt_scale=(0.98, 0.99), skirt_half=0.0035,
                  open_z=[0.50, 0.58, 0.66, 0.74, 0.82, 0.87, 0.95], open_w=[0.05, 0.042, 0.03, 0.018, 0.006, -0.01, -0.01],
                  vent_top=0.68, cape=(1.095, 0.028, 0.5), v_neck=(1.175, 0.004, 0.26), neck_r=0.006)

CAPE_FRINGE = dict(width=0.030, length=0.052, droop=0.10, count=64)
HEM_FRINGE = dict(width=0.030, length=0.060, droop=0.10, count=72)


def fringe_roots(node, heights_fn, count, keep_fn, phase=0.0):
    a = np.linspace(-math.pi, math.pi, count, endpoint=False) + phase
    z = heights_fn(a)
    P, N, D = FC.edge_roots(node, z, a)
    k = keep_fn(P)
    return P[k], N[k], D[k]


def build(ctx):
    K = ctx.K
    body_sdf = ctx.body_sdf()
    node = FC.coat_node(K, P, body=body_sdf)
    sform = FC.skirt_form(P)
    fopen, bvent = FC.front_opening(P), FC.back_vent(P)

    def vis(Pt):
        rim = np.minimum.reduce([np.abs(Pt[:, 2] - FC.hem_z(P, Pt[:, 0], Pt[:, 1])), np.abs(peval(fopen, Pt)),
                                 np.abs(peval(bvent, Pt)), np.abs(Pt[:, 2] - P.cape[0])])
        L = np.where(peval(sform, Pt) < 0, 0.05, 0.035)         # skirt inside / outside
        L = np.where(Pt[:, 2] > 0.90, 0.033, L)
        L = np.where(np.abs(Pt[:, 0]) > 0.22, 0.027, L)          # sleeves
        L = np.where(Pt[:, 2] > 1.25, 0.019, L)                   # neck
        L = 0.014 + (L - 0.014) * smoothstep(0.004, 0.03, rim)
        vent = (np.abs(Pt[:, 0]) < 0.016) & (Pt[:, 1] > 0.05) & (Pt[:, 2] < P.vent_top + 0.015)
        return np.where(vent, np.minimum(L, 0.0065), L)
    main = FC.sdf_obj("hunting_shirt_tow", node, 0.0024, 4000, material("hst_tmp", "#a99570"),
                      sizing=FC.hidden_sizing(vis, 0.045, [body_sdf]), feature_deg=32.0, iters=24, sharp_deg=None)
    W = FC.coat_weights(ctx, main, P)
    cands = [n for n in FC.REGION_LIST if FC.region_group(n) in ("neck", "torso_upper", "torso_lower", "hips",
                                                               "arms_upper", "arms_lower")]
    cov = FC.coverage(ctx, main, W=W, exclude_bones=["%s_%s" % (sd, h) for sd in "lr" for h in FC.SKIRT_HELPERS],
                      candidates=cands, edge_polys=FC.coat_openings(main, K, P, body=body_sdf))
    FC.log_coverage(SPEC.id, cov)
    SPEC.hides_regions = FC.pick_hides(cov)
    SPEC.occupies_regions = sorted([n for n, (a, b) in cov.items() if max(a, b) > 0.3], key=lambda n: FC.REGIONS[n])
    ndel = FC.delete_inside(ctx, main)
    FC.log("  %s: %d polygons inside the body deleted" % (SPEC.id, ndel))
    W = FC.coat_weights(ctx, main, P)
    cls = FC.coat_face_class(main, K, P, body=body_sdf)
    zones = np.zeros(len(main.data.polygons), int)
    V = mesh_arrays(main)
    col = np.ones((len(V), 4))
    inner_v = np.zeros(len(V), bool)
    for p in main.data.polygons:
        if cls[p.index] == 1:
            inner_v[list(p.vertices)] = True
    col[inner_v, :3] = 0.88
    # the cape's shadow line on the body of the shirt just below its edge
    under = (V[:, 2] < P.cape[0]) & (V[:, 2] > P.cape[0] - 0.03) & (peval(FC.cape_node(K, P), V) > 0.003)
    col[under, :3] *= (0.72 + 0.28 * smoothstep(0.0, 0.03, P.cape[0] - V[under, 2]))[:, None]
    d_hem, d_open = FC.coat_edge_uv(main, K, P)
    # fringe: along the cape edge (where the cape is outermost) and along the hem
    cape = FC.cape_node(K, P)
    ce = P.cape[0] + 0.003
    Pc, Nc, Dc = fringe_roots(node, lambda a: np.full(len(a), ce), CAPE_FRINGE["count"],
                              lambda Q: np.abs(peval(cape, Q)) < 0.002)

    def hem_h(a):
        deg = np.degrees(np.abs(a))
        return P.hem + P.front_rise * (1 - smoothstep(50.0, 130.0, deg)) + 0.004

    def hem_keep(Q):
        w = np.interp(Q[:, 2], P.open_z, P.open_w)
        front = (Q[:, 1] < 0) & (np.abs(Q[:, 0]) < w + 0.016)
        back = (Q[:, 1] > 0) & (np.abs(Q[:, 0]) < 0.018)
        return ~front & ~back
    Ph, Nh, Dh = fringe_roots(node, hem_h, HEM_FRINGE["count"], hem_keep, phase=0.02)
    cards = FC.fringe_cards(Pc, Nc, Dc, CAPE_FRINGE["width"], CAPE_FRINGE["length"], CAPE_FRINGE["droop"], seed=3)
    cards += FC.fringe_cards(Ph, Nh, Dh, HEM_FRINGE["width"], HEM_FRINGE["length"], HEM_FRINGE["droop"], seed=4)
    fob, fh, fcidx = FC.fringe_object("hunting_shirt_tow_fringe", cards)
    roots = np.array([c.P[0] for c in cards])
    fW = FC.rigid_card_weights(main, W, roots, fcidx)
    FC.log("  fringe: %d cards on the cape, %d on the hem" % (len(Pc), len(Ph)))
    SPEC.skirt = {"hems_godot": [[0.12, P.hem + P.front_rise, 0.145], [0.24, P.hem + 0.5 * P.front_rise, -0.01],
                                 [0.12, P.hem, -0.18]], "hem_z": P.hem, "front_rise": P.front_rise}
    SPEC.helpers = ["shoulder_twist", "forarm_twist", "skirt"]
    uv_fn = FC.coat_uv_fn(K)
    return {"main": Surface(main, zones=zones, weights=W, uv=uv_fn, colors=col, edge=(d_hem, d_open)),
            "fringe": Surface(fob, zones=np.ones(len(fob.data.polygons), int), h=fh, weights=fW)}
