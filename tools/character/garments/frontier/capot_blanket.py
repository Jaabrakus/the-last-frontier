"""Blanket coat (capot): a knee-length hooded coat of blanket cloth, overlapped in front and
tied with ribbons, the hood lying on the back.

Costume bible §2.2 / §2.6 `capot_blanket` (grade A for Canada, B for Anglo rangers):
Canadian in origin and issued to Canadian militiamen with a breechcloth, leggings,
moccasins and a blanket; rangers used them in winter [M5][M7][R8]. For the 1750s-60s the
cloth is plain white, blue or red blanket cloth, or white duffel with one to three red or
blue stripes from the blanket's end [R3] (the Hudson's Bay point blanket dates from 1779).
The stripes are drawn by the cloth shader from the hem distance (CUSTOM0.x) as zone 0
`bands`; ribbon ties are zone 1. A sash (accessories.waist) usually closes it.
"""

import numpy as np

from garments.frontier import _frontier_common as FC
from lib.catalog import GarmentSpec, Zone
from lib.pipeline import Surface
from lib.remesh import Prims, join, material, mesh_arrays, sdf_object
from lib.sdf import Fn, Inter, Offset, Onion, RoundCone, Union, frame_from, peval, smoothstep, surface_point, v3
from lib.weights import mesh_adjacency, rigid_islands

BANDS = {"axis": "x", "source": "CUSTOM0.x (height above the hem, or distance from the cuff end; metres)",
         "rows_max": 3, "default_rows": 2, "offset_m": 0.05, "width_m": 0.035, "gap_m": 0.025,
         "palette": ["stroud_blue", "madder_red", "stroud_red", "logwood_black"], "default": "stroud_blue"}

SPEC = GarmentSpec(
    id="capot_blanket", name="Blanket coat (capot)", slot="outer", set="frontier",
    description=("Knee-length hooded coat of blanket cloth, overlapped in front and tied with ribbons; plain, or white "
                 "with one to three stripes near the hem and cuffs."),
    layer={"default": 40}, weights="body",
    zones=[Zone(0, "cloth", "WOOL", ["#E3DED0", "stroud_blue", "stroud_red", "madder_red", "grey_white", "drab"],
                "#E3DED0", bands=BANDS, name="blanket"),
           Zone(1, "ribbon", "FLAT", ["ribbon_red", "ribbon_blue", "ribbon_black", "ribbon_green"], "ribbon_red",
                name="ties")],
    surfaces={"main": "capot_blanket"},
    evidence="A",
    history=("Canadian hooded blanket coat, issued to the militia and worn by rangers in winter. White capots with blue "
             "bands are documented from the 1770s; for the 1750s-60s plain blanket cloth or duffel with end stripes."),
    sources=["M5", "M7", "R8", "R3", "M7b"], budget={"tris_max": 8000},
    tags=["winter", "men", "women", "canada"],
    extra={"fabric_options": {"blanket": ["WOOL", "TWILL"]}},
)
SPEC.extra["deform_limits"] = FC.deform_limits(SPEC)

P = FC.CoatParams(off=0.017, sleeve_off=0.0135, sleeve_off_lower=0.0145, sleeve_end=0.86, cuff=(0.72, 0.0075),
                  hem=0.475, front_rise=0.04, skirt_scale=(1.05, 1.06), skirt_flare=0.12, skirt_half=0.005,
                  open_z=[0.40, 0.47, 0.60, 0.72, 0.80, 0.86, 0.95], open_w=[0.10, 0.09, 0.06, 0.035, 0.015, -0.01, -0.01],
                  vent_top=0.66, collar=dict(off=0.031, thick=0.009, z0=1.262, z1=1.335, w0=0.022, slope=0.35),
                  neck_r=0.012)

HOOD_TIP, HOOD_TOP, HOOD_W = 1.04, 1.315, 0.15


def hood_node(K):
    """The hood lying flat on the back: a shell 12-20 mm over the coat, pointed below."""
    yc = K["spineb"][1]
    base = Onion(Offset(FC.coat_torso_shapes(K), 0.0285), 0.0045)

    def region(X, Y, Z):
        u = np.clip((Z - HOOD_TIP) / 0.21, 0.0, 1.0)
        w = HOOD_W * np.sqrt(u) * (1.0 - 0.25 * smoothstep(0.8, 1.0, u)) + 0.006     # pointed below, rounded top
        return np.maximum(np.maximum(np.abs(X) - w, HOOD_TIP - Z), np.maximum(Z - HOOD_TOP, (yc + 0.03) - Y))
    return Inter(base, Fn(region, (-0.2, yc, HOOD_TIP - 0.03), (0.2, 0.3, HOOD_TOP + 0.03)), k=0.004)


def ties(K, coat):
    """Two ribbon bows on the front edge (knot and two short tails)."""
    pr = Prims()
    for z in (1.19, 1.08):
        p = surface_point(coat, v3(0.0, -0.30, z), v3(0, 1, 0), 0.0, 0.30)
        n = v3(0, -1, 0)
        c = p + n * 0.004
        pr.sphere(c, (0.008, 0.005, 0.006), mi=0, segs=10, rings=6)
        for sx in (1, -1):
            a = c + v3(sx * 0.004, -0.001, -0.002)
            b = c + v3(sx * 0.012, -0.002, -0.045)
            pr.cylinder((a + b) * 0.5, b - a, 0.0045, float(np.linalg.norm(b - a)), mi=0, segs=6)
    return pr.to_object("ties", [material("tie_tmp", "#b2202c")])


def build(ctx):
    K = ctx.K
    body_sdf = ctx.body_sdf()
    node = FC.coat_node(K, P, extra=[hood_node(K)], body=body_sdf)
    sform = FC.skirt_form(P)
    fopen, bvent = FC.front_opening(P), FC.back_vent(P)

    def vis(Pt):
        rim = np.minimum.reduce([np.abs(Pt[:, 2] - FC.hem_z(P, Pt[:, 0], Pt[:, 1])), np.abs(peval(fopen, Pt)),
                                 np.abs(peval(bvent, Pt))])
        L = np.where(peval(sform, Pt) < 0, 0.05, 0.034)
        L = np.where(Pt[:, 2] > 0.90, 0.032, L)
        L = np.where(np.abs(Pt[:, 0]) > 0.22, 0.026, L)
        L = np.where(Pt[:, 2] > 1.07, np.minimum(L, 0.024), L)   # hood, collar
        L = 0.014 + (L - 0.014) * smoothstep(0.004, 0.03, rim)
        vent = (np.abs(Pt[:, 0]) < 0.016) & (Pt[:, 1] > 0.05) & (Pt[:, 2] < P.vent_top + 0.015)
        return np.where(vent, np.minimum(L, 0.0065), L)
    coat = FC.sdf_obj("capot_blanket", node, 0.0024, 4500, material("cap_tmp", "#e3ded0"),
                      sizing=FC.hidden_sizing(vis, 0.045, [body_sdf]), feature_deg=32.0, iters=20, sharp_deg=None)
    main = join([coat, ties(K, node)], "capot_blanket")
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
    is_tie_poly = np.array([p.material_index for p in main.data.polygons]) == 1
    V = mesh_arrays(main)
    is_tie = np.zeros(len(V), bool)
    for p in main.data.polygons:
        if is_tie_poly[p.index]:
            is_tie[list(p.vertices)] = True
    W = rigid_islands(W, mesh_adjacency(main), is_tie)
    zones = np.where(is_tie_poly, 1, 0)
    cls = FC.coat_face_class(main, K, P, body=body_sdf)
    col = np.ones((len(V), 4))
    inner_v = np.zeros(len(V), bool)
    for p in main.data.polygons:
        if cls[p.index] == 1:
            inner_v[list(p.vertices)] = True
    col[inner_v, :3] = 0.85
    # the hood's shadow on the back of the coat around its edge
    hn = hood_node(K)
    dh = peval(hn, V)
    near_hood = (dh > 0.002) & (dh < 0.02) & (V[:, 1] > 0.0) & (V[:, 2] > HOOD_TIP - 0.02)
    col[near_hood, :3] *= (0.78 + 0.22 * smoothstep(0.002, 0.02, dh[near_hood]))[:, None]
    d_hem, d_open = FC.coat_edge_uv(main, K, P)
    SPEC.skirt = {"hems_godot": [[0.125, P.hem + P.front_rise, 0.155], [0.26, P.hem + 0.5 * P.front_rise, -0.01],
                                 [0.125, P.hem, -0.20]], "hem_z": P.hem, "front_rise": P.front_rise}
    SPEC.helpers = ["shoulder_twist", "forarm_twist", "skirt"]
    return {"main": Surface(main, zones=zones, weights=W, uv=FC.coat_uv_fn(K), colors=col, edge=(d_hem, d_open))}
