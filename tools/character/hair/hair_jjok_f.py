"""A Korean married woman's chignon (jjok) held with a long pin (binyeo).

Married women of Joseon Korea parted the hair in the middle, drew it back smoothly and wound it into
a low chignon at the nape, fixed with a long hairpin of silver, jade or wood. Korean travellers were
all but unknown in the 1750s northeast: a customizer choice for the game's wider cast.

Hair v3 recipe (hair/_recipe.py): parted and drawn back to a low bun, the pin through it across.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_jjok_f", name="Low chignon with pin (jjok)", slot="hair", set="hair", kind="hair",
    description="Long hair parted in the middle, drawn back smoothly into a low chignon at the nape and held with a "
                "long pin.",
    zones=[Zone(0, "hair", name="hair"), Zone(2, "metal", "MET", ["silver"], "silver", name="pin")],
    surfaces={"main": "hair_jjok_f", "strands": "hair_jjok_f_tex"},
    hair_zones=["crown", "sides", "back"], evidence="B",
    licence_note="Period style of Joseon Korea; Korean travellers were all but unknown in the 1750s northeast.",
    sources=[], budget={"tris_max": 13500}, tags=["women", "any"],
    history="Married women of Joseon Korea: the hair in a low chignon (jjok) held with a long pin (binyeo).",
    extra={"hair": {"queue": False, "texture": "straight", "part": "centre"}},
)

RECIPE = {
    "flow": ("parted_back", "bun"),
    "layers": ("combed", {"length": 0.30, "density": 0.8}),
    "bun": {"radii": (0.030, 0.019, 0.021), "rings": 12},
    "accents": [("rod", {"a": ("bun", (-0.058, 0.004, 0.0)), "b": ("bun", (0.058, 0.004, 0.0)), "r": 0.0030,
                         "r_end": 0.0022, "zone": 2})],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
