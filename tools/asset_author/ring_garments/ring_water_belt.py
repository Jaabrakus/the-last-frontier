"""The water side's belt (recipes.belt): a broad leather belt over the parka with a bone-white buckle and a small
pouch at the right front."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

from ring_garments import _common as C

UNDER = ["ring_water_parka"]

SPEC = Spec(
    id="ring_water_belt", name="Water side belt", set=C.SET, slot="accessories.waist", layer={"default": 60},
    description="A broad leather belt over the parka with a pale buckle and a small pouch at the right front.",
    history=C.HISTORY,
    zones=[Zone(0, "belt", "leather", "LEA", ["ring_navy", "ring_seal", "leather_brown", "leather_black"], "ring_navy"),
           Zone(1, "pouch", "leather", "SUEDE", ["ring_seal", "ring_ice", "leather_brown"], "ring_seal"),
           Zone(2, "buckle", "metal", "MET", ["silver", "pewter", "brass"], "silver", metal=True)],
    evidence="C", tags=C.tags("water"), budget=2500, over=UNDER,
    extra={"presets": {"water": {"0": "ring_navy", "1": "ring_seal", "2": "silver"}},
           "recipe_note": "recipes.belt 5.5 cm wide over the parka, a pouch box at the right front."})

STYLE = {"z": (0.955, 1.010), "lift": 0.026, "over": tuple(UNDER), "over_gap": 0.004,
         "buckle": {"w": 0.055, "h": 0.06}, "pouch": {"size": (0.07, 0.06, 0.03)}}


def build(g):
    recipes.belt(g, STYLE)


build_and_export = G.runner(SPEC, build)
