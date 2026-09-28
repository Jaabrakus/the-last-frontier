"""Tailored fur coat: sleeved, above-knee coat of dressed skins with the fur outside, a
standing fur collar, turned-back fur cuffs and wooden toggles.

Costume bible §2.4 item 4 (grade C, "Artistic licence"): a tailored fur coat is not
documented for 1750s-60s northeastern frontiersmen; it answers the owner's request for fur
coats in bear, beaver and wolf colourings. The documented forms are the fur robe or mantle
(grade A) and fur trim on a capot (grade B).

Surfaces: main (zone 0 fur base FUR, 1 hide lining SUEDE, 2 toggles), fur (zone 0: 10
shells over the outer surface, zone 1: guard-hair cards). The pile colour and length come
from the fur zone's palette token (catalog "fur" block, shader fur_shell.gdshader).
"""

import numpy as np

from garments.frontier import _frontier_common as FC
from lib.catalog import GarmentSpec, Zone
from lib.pipeline import Surface
from lib.remesh import Prims, join, material, mesh_arrays, sdf_object
from lib.sdf import frame_from, peval, smoothstep, surface_point, v3
from lib.weights import mesh_adjacency, rigid_islands, sleeve_factor

FURS = ["fur_black_bear", "fur_brown_bear", "fur_beaver", "fur_wolf", "fur_raccoon"]

SPEC = GarmentSpec(
    id="fur_coat_tailored", name="Fur coat, tailored", slot="outer", set="frontier",
    description=("Above-knee coat of dressed skins worn fur outside, with a standing fur collar, turned-back fur "
                 "cuffs and wooden toggles. Bear, beaver, wolf or raccoon."),
    layer={"default": 40}, weights="body",
    zones=[Zone(0, "fur", "FUR", FURS, "fur_beaver", name="fur"),
           Zone(1, "lining", "SUEDE", ["buckskin_smoked", "leather_brown", "buckskin_pale"], "buckskin_smoked",
                name="hide lining"),
           Zone(2, "button", "FLAT", ["#5E3E25", "#C9B48A"], "#5E3E25", name="toggles")],
    surfaces={"main": "fur_coat_tailored", "fur": "fur_coat_tailored_fur"},
    evidence="C",
    licence_note=("Artistic licence: tailored fur coats are not documented for 1750s-60s northeastern "
                  "frontiersmen. Fur robes and mantles (grade A) and fur-trimmed capots (grade B) are."),
    history=("Heckewelder mentions Lenape 'long frocks of fine fur' only as ancient dress; the period forms were "
             "fur robes worn fur-in or fur-out, and fur trim on Canadian winter capots."),
    sources=["P2", "M7", "M7d", "R14b"], budget={"tris_max": 30000},
    tags=["winter", "fur", "men", "women"],
    extra={"fur": FC.fur_block("fur_coat_tailored_fur", FURS)},
)
SPEC.extra["deform_limits"] = FC.deform_limits(SPEC)

P = FC.CoatParams(off=0.016, sleeve_off=0.013, sleeve_off_lower=0.0135, sleeve_end=0.86, cuff=(0.70, 0.0095),
                  hem=0.50, front_rise=0.05, skirt_scale=(1.03, 1.04), skirt_flare=0.10, skirt_half=0.005,
                  open_z=[0.40, 0.50, 0.62, 0.72, 0.80, 0.86, 0.95], open_w=[0.085, 0.07, 0.045, 0.025, 0.010, -0.01, -0.01],
                  vent_top=0.70, collar=dict(off=0.030, thick=0.009, z0=1.262, z1=1.37, w0=0.016, slope=0.30), neck_r=0.008)

FUR = FC.FurParams(shells=12, base_tris=1700, nominal=0.026, cards=560, card_len=0.05, card_w=0.0045)


def toggles(K, coat):
    """Three wooden toggles on the front edge (on the overlap, left of centre)."""
    pr = Prims()
    for z in (1.17, 1.07, 0.975):
        p = surface_point(coat, v3(0.012, -0.30, z), v3(0, 1, 0), 0.0, 0.30)
        n = v3(0, -1, 0)
        R = frame_from(v3(1, 0, 0), v3(0, 0, 1))
        pr.cylinder(p + n * 0.004, v3(1, 0, 0), 0.0042, 0.030, mi=0, segs=8)
    return pr.to_object("toggles", [material("toggle_tmp", "#5e3e25")])


def build(ctx):
    K = ctx.K
    body = ctx.body()
    body_sdf = ctx.body_sdf()
    node = FC.coat_node(K, P, body=body_sdf)
    sform = FC.skirt_form(P)
    fopen, bvent = FC.front_opening(P), FC.back_vent(P)

    def vis(Pt):
        rim = np.minimum.reduce([np.abs(Pt[:, 2] - FC.hem_z(P, Pt[:, 0], Pt[:, 1])), np.abs(peval(fopen, Pt)),
                                 np.abs(peval(bvent, Pt)), np.abs(Pt[:, 2] - 1.36)])
        L = np.where(peval(sform, Pt) < 0, 0.050, 0.032)        # skirt lining / outside
        L = np.where(Pt[:, 2] > 0.90, 0.030, L)                   # torso
        L = np.where(np.abs(Pt[:, 0]) > 0.22, 0.024, L)          # sleeves / cuffs
        L = np.where(Pt[:, 2] > 1.25, 0.017, L)                   # collar
        L = 0.014 + (L - 0.014) * smoothstep(0.004, 0.03, rim)
        vent = (np.abs(Pt[:, 0]) < 0.018) & (Pt[:, 1] > 0.05) & (Pt[:, 2] < P.vent_top + 0.015)
        return np.where(vent, np.minimum(L, 0.007), L)            # keep the narrow vent slit
    coat = FC.sdf_obj("fur_coat_tailored", node, 0.0024, 4200, material("fct_tmp", "#5a3b25"),
                      sizing=FC.hidden_sizing(vis, 0.045, [body_sdf]), feature_deg=32.0, iters=18, sharp_deg=None)
    tg = toggles(K, node)
    main = join([coat, tg], "fur_coat_tailored")
    W = FC.coat_weights(ctx, main, P)
    # hides: regions the closed coat covers in both fits (not by the swinging skirt)
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
    npoly = len(main.data.polygons)
    mi = np.array([p.material_index for p in main.data.polygons])
    is_tg_poly = mi == 1
    cls = FC.coat_face_class(main, K, P, body=body_sdf)
    outer = (cls == 0) & ~is_tg_poly
    zones = np.where(cls == 1, 1, 0)                              # the hide shows on the inside only
    zones[is_tg_poly] = 2
    V = mesh_arrays(main)
    is_tg = np.zeros(len(V), bool)
    inner_v = np.zeros(len(V), bool)
    for p in main.data.polygons:
        if is_tg_poly[p.index]:
            is_tg[list(p.vertices)] = True
        if zones[p.index] == 1:
            inner_v[list(p.vertices)] = True
    W = rigid_islands(W, mesh_adjacency(main), is_tg)
    uv_fn = FC.coat_uv_fn(K)
    col = np.ones((len(V), 4))
    col[inner_v, :3] = 0.85                                        # the hide lining a little darker
    d_hem, d_open = FC.coat_edge_uv(main, K, P)
    Tm, _ = FC.triangles(main)
    straps = [FC.strap_path(K, 1, "env40"), FC.strap_path(K, -1, "env40")]
    fob, fz, fh, fW, fcol, (belt, strap), fstats = FC.fur_surface(
        ctx, "fur_coat_tailored_fur", main, W, outer, FUR, uv_fn,
        blockers=[(body.V, body.F), (V, Tm)], sleeve_fn=lambda Q: sleeve_factor(Q, K) > 0.5, strap_paths=straps)
    FC.log("  fur: %s" % fstats)
    SPEC.skirt = {"hems_godot": [[0.12, P.hem + P.front_rise, 0.15], [0.25, P.hem + 0.5 * P.front_rise, -0.01],
                                 [0.12, P.hem, -0.19]], "hem_z": P.hem, "front_rise": P.front_rise}
    SPEC.helpers = ["shoulder_twist", "forarm_twist", "skirt"]
    SPEC.extra["fur"]["stats"] = fstats
    return {"main": Surface(main, zones=zones, weights=W, uv=uv_fn, colors=col, edge=(d_hem, d_open)),
            "fur": Surface(fob, zones=fz, h=fh, weights=fW, colors=fcol, edge=(belt, strap))}
