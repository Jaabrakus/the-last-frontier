"""Leather shot pouch on the left hip from a strap over the right shoulder (costume bible
§2.2, §2.6 `shot_pouch`, grade A [M2][P3]). Four envelope variants (_frontier_gear.py).
"""

from garments.frontier import _frontier_common as FC
from garments.frontier import _frontier_gear as G
from lib.catalog import GarmentSpec, Zone

SPEC = GarmentSpec(
    id="shot_pouch", name="Shot pouch", slot="accessories.shoulder", set="frontier",
    description="Leather pouch with a flap for balls and flints, on the left hip from a strap over the right shoulder.",
    layer={"default": 60}, weights="body",
    zones=[Zone(0, "leather", "LEA", ["leather_brown", "buckskin_smoked", "logwood_black"], "leather_brown",
                name="pouch"),
           Zone(1, "leather", "LEA", ["leather_brown", "buckskin_smoked", "ribbon_red", "tow"], "leather_brown",
                name="strap")],
    evidence="A", history="A leather shot bag or pouch on a strap or the belt, with the knife carried nearby.",
    sources=["M2", "P3"], budget={"tris_max": 1100}, tags=["men", "women", "gear"],
)
SPEC.extra["deform_limits"] = FC.deform_limits(SPEC)


def build(ctx):
    return G.build_with_variants(ctx, SPEC, horn=False, pouch=True,
                                 generator="tools/character/garments/frontier/shot_pouch.py")
