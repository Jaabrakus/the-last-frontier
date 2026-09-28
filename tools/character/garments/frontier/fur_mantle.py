"""Fur robe (mantle) worn as a wrap: a robe of skins sewn with the fur all lying one way, wrapped
round the hips and belted, the upper part brought across the body and over the left shoulder.

Costume bible §2.4 item 1 / §2.6 `fur_mantle` (grade A): Lenape robes of beaver, raccoon and
bear skins sewn with the fur lying one way so rain ran off, worn fur-in when cold and dry,
fur-out when wet [P2]; "coat beaver" robes worn by Native hunters before trade [M7d]; French
soldiers used bearskins as blankets [M4]. Game form: over a capot or a coat, the fur outside.

The drape is the matchcoat's (garments/woodlands/ew_matchcoat.py: one documented way of
wearing a robe or blanket that keeps the right arm free for a musket or a bow); the robe is
the hide (zone 0, FUR base) with fur shells and guard hairs over its outer faces, and the belt
(zone 1). Surfaces: main, fur.
"""

import numpy as np

from garments.frontier import _frontier_common as FC
from garments.woodlands import ew_matchcoat as EW
from lib.catalog import GarmentSpec, Zone
from lib.pipeline import Surface
from lib.remesh import mesh_arrays
from lib.body_shapes import torso_shapes
from lib.sdf import Offset

FURS = ["fur_black_bear", "fur_brown_bear", "fur_beaver", "fur_wolf", "fur_raccoon"]

SPEC = GarmentSpec(
    id="fur_mantle", name="Fur robe, belted", slot="accessories.wrap", set="frontier",
    description=("A robe of skins sewn with the fur lying one way, worn fur outside: wrapped round the hips and "
                 "belted, the upper part across the body and over the left shoulder, the right arm free."),
    layer={"default": 50}, weights="body",
    zones=[Zone(0, "fur", "FUR", FURS, "fur_black_bear", name="fur"),
           Zone(1, "leather", "LEA", ["leather_brown", "buckskin_smoked", "logwood_black"], "leather_brown",
                name="belt")],
    surfaces={"main": "fur_mantle", "fur": "fur_mantle_fur"},
    evidence="A",
    history=("Lenape robes of beaver, raccoon and bear skins, the fur lying one way so rain ran off, worn fur-in "
             "when cold and dry and fur-out when wet (Heckewelder); beaver robes worn by Native hunters before "
             "they were traded; bearskins used as blankets by French soldiers. The drape is one way of wearing a "
             "robe, chosen so the right arm stays free."),
    sources=["P2", "M7d", "M4"], budget={"tris_max": 34000},
    tags=["winter", "fur", "men", "women"],
    extra={"fur": FC.fur_block("fur_mantle_fur", FURS)},
)
SPEC.extra["deform_limits"] = FC.deform_limits(SPEC)

FUR = FC.FurParams(shells=12, base_tris=2200, nominal=0.035, cards=600, card_len=0.055, card_w=0.0045)


def build(ctx):
    K = ctx.K
    body = ctx.body()
    res = EW.build(ctx)
    ms = res["main"]
    ob, W = ms.ob, ms.weights
    zones = np.array(ms.zones)
    for k in ("hides_regions", "occupies_regions", "skirt", "helpers"):
        if hasattr(EW.SPEC, k):
            setattr(SPEC, k, getattr(EW.SPEC, k))
    C, N, _ = FC.poly_arrays(ob)
    # outer faces: away from the torso's core
    core = Offset(torso_shapes(K, smooth=True), 0.0)
    outer = (N * FC.sdf_grad(core, C)).sum(1) > 0.15
    fur = outer & (zones == 0)
    FC.log("  fur polygons: %d of %d" % (fur.sum(), len(zones)))
    V = mesh_arrays(ob)
    Tm, _ = FC.triangles(ob)
    straps = [FC.strap_path(K, 1, "env50"), FC.strap_path(K, -1, "env50")]
    uv_fn = ms.uv if callable(ms.uv) else FC.coat_uv_fn(K)
    fob, fz, fh, fW, fcol, (belt, strap), fstats = FC.fur_surface(
        ctx, "fur_mantle_fur", ob, W, fur, FUR, uv_fn, blockers=[(body.V, body.F), (V, Tm)], strap_paths=straps)
    FC.log("  fur: %s" % fstats)
    SPEC.extra["fur"]["stats"] = fstats
    ob.name = "fur_mantle"
    return {"main": Surface(ob, zones=zones, weights=W, uv=ms.uv, colors=ms.colors, edge=ms.edge,
                            regions=ms.regions),
            "fur": Surface(fob, zones=fz, h=fh, weights=fW, colors=fcol, edge=(belt, strap))}
