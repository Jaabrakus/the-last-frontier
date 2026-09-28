"""Afro-textured hair grown out and combed into a rounded shape.

Period descriptions of people of African descent in the colonies mention hair worn
"bushy", "combed" or grown long (costume bible 1.3: runaway and sale advertisements [M15]).
Grade B.

Hair v3 recipe (hair/_recipe.py): shells of short coily strips stacked about 2.4 cm off the scalp.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_coily_rounded", name="Natural, rounded", slot="hair", set="hair", kind="hair",
    description="Afro-textured hair grown out and combed into a rounded shape.",
    zones=[Zone(0, "hair", name="hair")], hair_zones=["crown", "sides", "back"], evidence="B", sources=["M15"],
    budget={"tris_max": 10000}, tags=["men", "women", "any"], surfaces={"strands": "hair_coily_rounded_tex"},
    history="Natural hair grown out and combed, as described in period advertisements.",
    extra={"hair": {"queue": False, "texture": "coily"}},
)

RECIPE = {
    "flow": ("whorl",),
    "layers": ("coily", {"depth": 0.024}),
    "hairline": {"n": 110, "slot": "coily", "w": 0.02, "len": 0.03, "off": (0.001, 0.006), "step": 0.01},
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
