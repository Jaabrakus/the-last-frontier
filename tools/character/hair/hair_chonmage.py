"""The chonmage: the pate shaved, the hair of the sides and back drawn up into a knot folded forward.

Japanese men of the Edo period shaved the top of the head from the forehead back over the crown
(sakayaki) and drew the long hair of the sides and back up to the back of the crown, tied it with a
paper cord and folded the tail forward over the shaved pate. Japanese travellers were all but unknown
in the 1750s northeast (the country was closed): a customizer choice for the game's wider cast.

Hair v3 recipe (hair/_recipe.py): no hair on the shaved band, the rest combed up to the knot's root;
the knot a short thick tail laid forward over the pate (on the head), a white cord at its root.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_chonmage", name="Topknot, shaved pate (chonmage)", slot="hair", set="hair", kind="hair",
    description="The pate shaved from the forehead over the crown; the hair of the sides and back drawn up, tied and "
                "folded forward over the crown.",
    zones=[Zone(0, "hair", name="hair"),
           Zone(1, "cord", "FLAT", ["linen_bleached", "logwood_black"], "linen_bleached", name="cord")],
    surfaces={"main": "hair_chonmage", "strands": "hair_chonmage_tex"},
    hair_zones=["crown", "sides", "back", "lock"], evidence="B",
    licence_note="Period style of Edo Japan; Japanese travellers were all but unknown in the 1750s northeast.",
    sources=[], budget={"tris_max": 11000}, tags=["men", "any"],
    history="Edo-period Japanese men: the pate shaved (sakayaki), the hair tied and folded forward (chonmage).",
    extra={"hair": {"queue": False, "texture": "straight"}},
)

ROOT = (0.0, 0.056, 1.560)

RECIPE = {
    "domain": {"patch": "sakayaki"},
    "flow": ("back", ROOT),
    "layers": ("combed", {"length": 0.22}),
    "hairline": {"n": 80, "len": 0.18},
    # the knot about 2 cm thick, oiled and laid forward over the pate
    "tail": {"path": ("over", [(0.0, 0.040), (0.0, 0.014), (0.0, -0.014), (0.0, -0.040)], 0.0135),
             "radii": [0.0130, 0.0125, 0.0120, 0.0112, 0.0100], "count": 9, "slot": "dense", "follow": "lock",
             "outer": {"slot": "clumps", "count": 7, "scale": 1.08, "jitter": 0.0006}},
    "accents": [("band", {"at": 0, "t": 0.6, "len": 0.008})],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
