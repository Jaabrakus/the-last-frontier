"""The head shaved but for a tuft at the crown (the shikha), knotted.

Many Hindu men of India shaved the head and kept a tuft of long hair at the crown (the shikha,
choti), often tied in a small knot. Travellers from India were rare in the 1750s northeast: a
customizer choice for the game's wider cast.

Hair v3 recipe (hair/_recipe.py): the stubble the scalp's tint, the crown's tuft combed to a small knot.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_shikha", name="Shaved, crown tuft (shikha)", slot="hair", set="hair", kind="hair",
    description="The head shaved but for a tuft of long hair at the crown, tied in a small knot.",
    zones=[Zone(0, "hair", name="hair")], hair_zones=["crown", "sides", "back"], evidence="B",
    licence_note="Period practice of India; travellers from India were rare in the 1750s northeast.",
    sources=[], budget={"tris_max": 11000}, tags=["men", "any"], surfaces={"strands": "hair_shikha_tex"},
    history="Hindu men of India shaved the head but for the shikha, a tuft at the crown, often knotted.",
    extra={"hair": {"queue": False, "texture": "straight", "scalp_strength": 0.55}},
)

TUFT = ("tuft", {"center": (0.0, 0.022), "radius": 0.024})

RECIPE = {
    "flow": ("back", (0.0, 0.024, 1.604)),
    "layers": [{"region": ("in", TUFT), "n": 70, "slot": "dense", "w": 0.018, "len": 0.06, "off": (0.0015, 0.005),
                "taper": 0.2, "step": 0.008},
               {"region": ("in", TUFT), "n": 70, "slot": "clumps", "w": 0.014, "len": 0.06, "off": (0.003, 0.008),
                "taper": 0.3, "step": 0.008}],
    "hairline": None,
    "bun": {"radii": (0.011, 0.011, 0.010), "rings": 8},
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
