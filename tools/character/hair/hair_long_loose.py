"""Native men and women of the Eastern Woodlands wore long hair loose, tied or braided (costume bible 3.4, 6:
[P1][R1]); long loose hair was also worn by women of many peoples at home. Grade B.

Hair v3 recipe (hair/_recipe.py): parted in the middle, combed down and back, falling loose down
the back past the shoulders.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_long_loose", name="Long, loose", slot="hair", set="hair", kind="hair",
    description="Long straight hair parted in the middle and worn loose down the back.",
    zones=[Zone(0, "hair", name="hair")], hair_zones=["crown", "sides", "back", "queue"], evidence="B", sources=["P1", "R1"],
    budget={"tris_max": 16000}, tags=["women", "men", "woodlands", "any"], surfaces={"strands": "hair_long_loose_tex"},
    history="Long hair worn loose, tied or braided by Native men and women of the northeast.",
    extra={"hair": {"queue": False, "texture": "straight", "part": "centre"}},
)

RECIPE = {
    "flow": ("parted", {"x": 0.0, "back": 0.45, "down": 0.75}),
    "layers": ("loose", {"length": 0.42}),
    "hairline": {"n": 80, "len": 0.36},
    # over the collar and the coat's back (1.4 cm off the body it vanished under the clothes)
    "fall": {"z": 1.47, "clearance": 0.032},
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
