"""Afro-textured hair, short and natural.

Costume bible §1.3, §6: New England advertisements describe natural hair "combed" in
fashion [M15]; natural-texture variants of the short styles for every set. Grade A.

Hair v3 recipe (hair/_recipe.py): short coily shells about a centimetre deep.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_natural_short", name="Natural, short", slot="hair", set="hair", kind="hair",
    description="Afro-textured hair worn short and natural.",
    zones=[Zone(0, "hair", name="hair")], hair_zones=["crown", "sides", "back"], evidence="A", sources=["M15"],
    budget={"tris_max": 9000}, tags=["men", "women", "any"], surfaces={"strands": "hair_natural_short_tex"},
    history="Natural hair, cut short or combed, as described in period advertisements.",
    extra={"hair": {"queue": False, "texture": "coily"}},
)

RECIPE = {
    "flow": ("whorl",),
    "layers": ("coily", {"depth": 0.009, "length": 0.04, "density": 1.1}),
    "hairline": {"n": 110, "slot": "coily", "w": 0.018, "len": 0.025, "off": (0.001, 0.004), "step": 0.01},
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
