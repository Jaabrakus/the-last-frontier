"""Fine braids in rows from the forehead to the crown, the ends free in a round mass behind (shuruba).

Ethiopian women plaited the front and top of the hair in fine rows running back from the forehead
(shuruba), the hair behind left free and combed out into a round mass. Grade B: a customizer choice
for the game's wider cast.

Hair v3 recipe (hair/_recipe.py): plaited rows from the hairline back to the crown, coily shells
behind it.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_shuruba_f", name="Braided rows, free behind (shuruba)", slot="hair", set="hair", kind="hair",
    description="Fine braids in rows from the forehead back over the top, the hair behind left free in a round mass.",
    zones=[Zone(0, "hair", name="hair")], hair_zones=["crown", "sides", "back"], evidence="B",
    sources=[], budget={"tris_max": 12000}, tags=["women", "any"], surfaces={"strands": "hair_shuruba_f_tex"},
    history="Ethiopian women plaited the hair in rows from the forehead (shuruba), the ends free behind.",
    extra={"hair": {"queue": False, "texture": "coily"}},
)

BACK = ("in", ("behind", {"y0": 0.030}))

RECIPE = {
    "flow": ("back", (0.0, 0.050, 1.560)),
    "hairline": None,
    "rows": {"step_deg": 7.5, "max_deg": 95.0, "w": 0.012, "len": 0.30, "off": (0.0025, 0.0035), "slot": "braid",
             "to": (0.0, 0.050, 1.560)},
    "layers": [dict(L, region=BACK) for L in R.coily(depth=0.028, length=0.06, density=0.9)],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
