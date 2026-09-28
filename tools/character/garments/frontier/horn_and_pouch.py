"""Powder horn and shot pouch on crossed shoulder straps: the usual frontier pair as one
accessory (costume bible §2.2 / §2.6 `powder_horn` + `shot_pouch`; the design's "horn and
pouch kit", one item in accessories.shoulder). Four envelope variants (_frontier_gear.py).
"""

from garments.frontier import _frontier_common as FC
from garments.frontier import _frontier_gear as G
from lib.catalog import GarmentSpec, Zone

SPEC = GarmentSpec(
    id="horn_and_pouch", name="Powder horn and shot pouch", slot="accessories.shoulder", set="frontier",
    description="Powder horn under the right arm and shot pouch on the left hip, on straps crossed over the chest.",
    layer={"default": 60}, weights="body",
    zones=[Zone(0, "trim", "FLAT", ["#C9B48A", "#A8793C", "#E0D2A8"], "#C9B48A", name="horn"),
           Zone(1, "leather", "LEA", ["leather_brown", "buckskin_smoked", "ribbon_red", "tow"], "leather_brown",
                name="straps"),
           Zone(2, "trim", "FLAT", ["#5E3E25", "#3F2A1A"], "#5E3E25", name="wood"),
           Zone(3, "leather", "LEA", ["leather_brown", "buckskin_smoked", "logwood_black"], "leather_brown",
                name="pouch")],
    evidence="A", history="The powder horn under the right arm and the shot pouch on the other side, on crossed straps.",
    sources=["M2", "P3"], budget={"tris_max": 2400}, tags=["men", "women", "gear"],
)
SPEC.extra["deform_limits"] = FC.deform_limits(SPEC)


def build(ctx):
    return G.build_with_variants(ctx, SPEC, horn=True, pouch=True,
                                 generator="tools/character/garments/frontier/horn_and_pouch.py")
