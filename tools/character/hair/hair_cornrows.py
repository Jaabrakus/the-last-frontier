"""Hair plaited in rows flat to the head (cornrows), front to back.

Braiding the hair in rows flat to the head is an old West and Central African practice;
period advertisements in the colonies describe people of African descent with "plaited"
hair (costume bible 1.3 [M15]). Grade B.

Hair v3 recipe (hair/_recipe.py): a plait per row, the rows starting round the hairline and running
back to the nape; the scalp under the rows tinted, the partings between them left skin.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_cornrows", name="Plaited rows", slot="hair", set="hair", kind="hair",
    description="Hair plaited in rows flat to the head, from the hairline back to the nape.",
    zones=[Zone(0, "hair", name="hair")], hair_zones=["crown", "sides", "back"], evidence="B", sources=["M15"],
    budget={"tris_max": 9500}, tags=["men", "women", "any"], surfaces={"strands": "hair_cornrows_tex"},
    history="Rows of plaits flat to the head, an African practice kept in the colonies.",
    extra={"hair": {"queue": False, "texture": "coily"}},
)

RECIPE = {
    "flow": ("back", "nape_low"),
    "hairline": None,
    "rows": {"step_deg": 8.5, "max_deg": 135.0, "w": 0.0165, "len": 0.42, "off": (0.0025, 0.0035), "slot": "braid",
             "to": "nape_low"},
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
