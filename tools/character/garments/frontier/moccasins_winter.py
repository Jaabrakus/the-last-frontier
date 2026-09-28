"""Winter moccasins: the center-seam puckered moccasins made of hide with the fur left on, worn
fur inside, the ankle flaps turned down so the fur shows as a cuff.

Costume bible §2.2 / §2.6: `moccasins_puckered` (grade A) were worn with wool liners in winter
[M2]; moccasins of hide with the hair left on, worn fur inside, fit the northern winter [M7]
but are not specifically cited here: grade B. The geometry is moccasins_puckered's; the fur
is shells and guard hairs over the outer faces of the turned-down flaps.

Surfaces: main (zone 0 deerskin SUEDE, 1 ankle thong, 2 the hide under the fur), fur.
"""

import numpy as np

from garments.frontier import _frontier_common as FC
from garments.frontier import moccasins_puckered as MP
from lib.catalog import GarmentSpec, Zone
from lib.pipeline import Surface
from lib.remesh import mesh_arrays
from lib.sdf import peval, v3

FURS = ["fur_beaver", "fur_raccoon", "fur_red_fox", "fur_wolf", "fur_black_bear"]

SPEC = GarmentSpec(
    id="moccasins_winter", name="Winter moccasins, fur cuffs", slot="feet", set="frontier",
    description=("Center-seam puckered moccasins of hide with the hair left on, worn fur inside; the ankle flaps "
                 "turned down show the fur as a cuff."),
    layer={"default": 40}, weights="body",
    zones=[Zone(0, "leather", "SUEDE", ["buckskin_smoked", "buckskin_pale", "leather_brown"], "buckskin_smoked",
                name="deerskin"),
           Zone(1, "leather", "LEA", ["leather_brown", "buckskin_smoked", "logwood_black"], "leather_brown",
                name="thong"),
           Zone(2, "fur", "FUR", FURS, "fur_beaver", name="fur cuff")],
    surfaces={"main": "moccasins_winter", "fur": "moccasins_winter_fur"},
    evidence="B",
    history=("Puckered moccasins were worn with wool liners in winter (Rogers' rangers); hide moccasins with the "
             "hair left on, fur inside, fit the northern winter but are not specifically cited here."),
    sources=["P3", "M2", "M7"], budget={"tris_max": 9000},
    tags=["winter", "fur", "men", "women"],
    extra={"fur": FC.fur_block("moccasins_winter_fur", FURS, strap_envelope=None, length_scale=0.9)},
)
SPEC.extra["fur"]["palette_zone"] = 2
SPEC.extra["deform_limits"] = FC.deform_limits(SPEC)

FUR = FC.FurParams(shells=10, base_tris=500, nominal=0.03, cards=180, card_len=0.035, card_w=0.004,
                   edge_taper=(0.0, 0.01, 0.6))


def build(ctx):
    K = ctx.K
    body = ctx.body()
    body_sdf = ctx.body_sdf()
    res = MP.build(ctx)
    ms = res["main"]
    ob, W = ms.ob, ms.weights
    zones = np.array(ms.zones)
    for k in ("hides_regions", "occupies_regions"):
        setattr(SPEC, k, getattr(MP.SPEC, k))
    C, N, _ = FC.poly_arrays(ob)
    on_flap = (peval(body_sdf, C) > 0.012) & (C[:, 2] > MP.FLAP[0] - 0.004)
    outer = (N * FC.sdf_grad(body_sdf, C)).sum(1) > 0.2
    fur = on_flap & outer & (zones == 0)
    zones = np.where(fur, 2, zones)
    FC.log("  fur cuff polygons: %d" % fur.sum())
    V = mesh_arrays(ob)
    Tm, _ = FC.triangles(ob)
    # the shells' UVs: around each shin at the ankle (the flaps' own cylinder in moccasins_puckered)
    cyls = [FC.Cyl(K.side("ankle", s) + v3(0, 0, -0.05), K.side("ankle", s) + v3(0, 0, 0.1), v3(0, -1, 0), v0=0.2)
            for s in (1, -1)]

    def shell_uv(o):
        Co, _, _ = FC.poly_arrays(o)
        return FC.part_uvs(o, cyls, np.where(Co[:, 0] >= 0, 0, 1))
    fob, fz, fh, fW, fcol, (belt, strap), fstats = FC.fur_surface(
        ctx, "moccasins_winter_fur", ob, W, fur, FUR, shell_uv, blockers=[(body.V, body.F), (V, Tm)], strap_paths=())
    FC.log("  fur: %s" % fstats)
    SPEC.extra["fur"]["stats"] = fstats
    ob.name = "moccasins_winter"
    return {"main": Surface(ob, zones=zones, weights=W, uv=ms.uv, edge=ms.edge),
            "fur": Surface(fob, zones=fz, h=fh, weights=fW, colors=fcol, edge=(belt, strap))}
