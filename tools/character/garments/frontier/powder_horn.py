"""Powder horn on a shoulder strap: a bullock's horn hung under the right arm from a strap
over the left shoulder, with a wooden base plug and a stopper (costume bible §2.2, §2.6
`powder_horn`, grade A: Knox 1757 via [M2]). Four envelope variants (_frontier_gear.py).
"""

from garments.frontier import _frontier_common as FC
from garments.frontier import _frontier_gear as G
from lib.catalog import GarmentSpec, Zone

SPEC = GarmentSpec(
    id="powder_horn", name="Powder horn", slot="accessories.shoulder", set="frontier",
    description="Bullock's horn with a wooden plug and stopper, hung under the right arm from a strap over the left shoulder.",
    layer={"default": 60}, weights="body",
    zones=[Zone(0, "trim", "FLAT", ["#C9B48A", "#A8793C", "#E0D2A8"], "#C9B48A", name="horn"),
           Zone(1, "leather", "LEA", ["leather_brown", "buckskin_smoked", "ribbon_red", "tow"], "leather_brown",
                name="strap"),
           Zone(2, "trim", "FLAT", ["#5E3E25", "#3F2A1A"], "#5E3E25", name="wood")],
    evidence="A", history="A bullock's horn hung under the right arm from a strap over the left shoulder (Knox, 1757).",
    sources=["M2", "P3"], budget={"tris_max": 1300}, tags=["men", "women", "gear"],
    extra={"envelope_variants": "strap on the outermost torso layer: env10 shirt, env20 waistcoat, env40 coat or "
                                "hunting shirt, env50 blanket / fur robe / fur coat"},
)
SPEC.extra["deform_limits"] = FC.deform_limits(SPEC)


def build(ctx):
    return G.build_with_variants(ctx, SPEC, horn=True, pouch=False,
                                 generator="tools/character/garments/frontier/powder_horn.py")
