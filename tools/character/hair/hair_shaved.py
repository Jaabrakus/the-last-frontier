"""The head shaved (worn under a turban or cap).

Townsmen of the Ottoman lands, Persia, Egypt and the Maghreb, and many men of India, shaved the head
and kept it covered with a turban or cap; the stubble of a few days shows when it is bared. Grade B:
a customizer choice for the game's wider cast.

Hair v3 recipe (hair/_recipe.py): the stubble mostly the scalp's tint over the hair domain
(skin.gdshader breaks it into fine specks), a few very short fine strands.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_shaved", name="Shaved (under a turban)", slot="hair", set="hair", kind="hair",
    description="The head shaved, a few days' stubble; worn under a turban or cap.",
    zones=[Zone(0, "hair", name="hair")], hair_zones=["crown", "sides", "back"], evidence="B",
    sources=[], budget={"tris_max": 9000}, tags=["men", "any"], surfaces={"strands": "hair_shaved_tex"},
    history="Men of the Ottoman lands, Persia, Egypt, the Maghreb and India shaved the head under the turban.",
    extra={"hair": {"queue": False, "texture": "cropped", "scalp_strength": 0.55}},
)

RECIPE = {
    "flow": ("whorl",),
    # the stubble is mostly the scalp's tint (fine specks; strips of the cropped strands read as spots),
    # with a few very short fine strands
    "layers": [{"n": 400, "slot": "fine", "w": 0.006, "len": 0.004, "off": (0.0003, 0.0006), "taper": 0.2,
                "step": 0.002, "root_len": 0.0}],
    "hairline": None,
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
