"""Hair parted in the middle and gathered into a low bun at the nape.

A common way of dressing long hair for women of many peoples in the mid-1700s: European
women pinned it up under a cap, East and South Asian women gathered it into a knot at the
nape. Grade B.

Hair v3 recipe (hair/_recipe.py): parted in the middle, drawn back smoothly to the bun, the bun
strips coiled round it.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_bun_low", name="Low bun", slot="hair", set="hair", kind="hair",
    description="Long hair parted in the middle, drawn back smoothly and gathered into a bun at the nape.",
    zones=[Zone(0, "hair", name="hair")], hair_zones=["crown", "sides", "back"], evidence="B",
    sources=["R13"], budget={"tris_max": 13500}, tags=["women", "any"], surfaces={"strands": "hair_bun_low_tex"},
    history="Long hair gathered at the nape: worn in many forms across Europe, Asia and the colonies.",
    extra={"hair": {"queue": False, "texture": "straight", "part": "centre"}},
)

RECIPE = {
    "flow": ("parted_back", "bun"),
    "layers": ("combed", {"length": 0.30, "density": 0.8}),
    "bun": {"radii": (0.030, 0.022, 0.025), "rings": 12},
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
