"""A Japanese woman's dressed hair (shimada): full side locks, a projection at the nape, a knot on top.

Women of the Edo period dressed long hair up: the side locks (bin) puffed out, the hair at the nape
drawn into a projection (tabo), the rest gathered into a knot on the top of the head (the shimada
mage), held with combs and pins. Japanese travellers were all but unknown in the 1750s northeast: a
customizer choice for the game's wider cast.

Hair v3 recipe (hair/_recipe.py): combed up with volume at the sides, a knot at the top back, the
nape's projection a short flat tail, a pin through the knot.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_shimada_f", name="Dressed up (shimada)", slot="hair", set="hair", kind="hair",
    description="Long hair dressed up: full side locks, a projection at the nape and a knot on the top of the head "
                "held with a pin.",
    zones=[Zone(0, "hair", name="hair"),
           Zone(1, "pin", "FLAT", ["logwood_black", "ribbon_red", "linen_unbleached"], "logwood_black", name="pin")],
    surfaces={"main": "hair_shimada_f", "strands": "hair_shimada_f_tex"},
    hair_zones=["crown", "sides", "back"], evidence="B",
    licence_note="Period style of Edo Japan; Japanese travellers were all but unknown in the 1750s northeast.",
    sources=[], budget={"tris_max": 15000}, tags=["women", "any"],
    history="Edo-period Japanese women dressed the hair up in the shimada: side locks, nape projection, top knot.",
    extra={"hair": {"queue": False, "texture": "straight"}},
)

RECIPE = {
    "flow": ("up", "shimada"),
    "layers": ("combed", {"length": 0.30, "volume": 2.0, "density": 0.9}),
    "bun": {"radii": (0.024, 0.038, 0.022), "rings": 12},
    "tails": [{"path": ["nape_low", (0.0, 0.090, 1.410), (0.0, 0.104, 1.428)], "radii": [0.015, 0.016, 0.010],
               "aspect": 1.8, "count": 8, "slot": "dense", "follow": "body"}],
    "accents": [("rod", {"a": ("shimada", (-0.045, 0.010, 0.004)), "b": ("shimada", (0.045, 0.010, 0.004)), "r": 0.0022})],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
