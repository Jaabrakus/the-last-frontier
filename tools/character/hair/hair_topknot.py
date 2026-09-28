"""Hair drawn up into a topknot on the crown, tied with a cord.

A man's style of East Asia (the Korean sangtu of married men, the Japanese mage, here
without a shaved pate) and of parts of South and Southeast Asia in the mid-1700s. People
from these regions were rare in the colonial northeast: grade C, a customizer choice for
the game's wider cast.

Hair v3 recipe (hair/_recipe.py): combed up from every side to the crown, wound into a knot there,
a cord round its base.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_topknot", name="Topknot", slot="hair", set="hair", kind="hair",
    description="Long hair combed up and tied in a knot on the crown with a cord.",
    zones=[Zone(0, "hair", name="hair"),
           Zone(1, "ribbon", "FLAT", ["logwood_black", "linen_unbleached", "ribbon_red", "ribbon_blue"], "logwood_black",
                name="cord")],
    surfaces={"main": "hair_topknot", "strands": "hair_topknot_tex"},
    hair_zones=["crown", "sides", "back"], evidence="C",
    licence_note=("Period style of Korea, Japan and parts of South and Southeast Asia (without the shaved pate of the "
                  "Japanese mage); such travellers were rare in the 1750s northeast."),
    sources=[], budget={"tris_max": 13000}, tags=["men", "any"],
    history="The topknot of East, South and Southeast Asian men in the eighteenth century.",
    extra={"hair": {"queue": False, "texture": "straight"}},
)

RECIPE = {
    "flow": ("up", "knot"),
    "layers": ("combed", {"length": 0.28, "density": 0.85}),
    "bun": {"radii": (0.0190, 0.0200, 0.0185), "rings": 11},
    "accents": [("band", {"a": (0.0, 0.020, 1.590), "b": (0.0, 0.022, 1.612), "r": 0.0150, "len": 0.0070, "t": 0.5})],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
