"""The cocked hat (cloth2 recipe: recipes.rigid_hat with hats.TRICORNE): black felt, the round brim cocked up on
three sides, an edge tape or lace, a cockade held by a loop and button. Rigid on the head; it hides the hair's
crown zone (the hair's hat_fit shape presses the rest under the band)."""

from cloth2 import garment as G
from cloth2 import hats
from cloth2 import recipes
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="cocked_hat", name="Cocked hat", set="colonial", slot="head", layer={"default": 80},
    description="A black felt hat with the brim cocked up on three sides, bound with tape or lace, with a cockade "
                "on the left held by a loop and button.",
    history="The three-cornered felt hat was the common hat of men in the 1750s, civilian and soldier: bound with "
            "white worsted tape for British privates, with false-gold lace for the French colonial regulars (the "
            "1758 prize sale's hats with broad tinsel lace), the cockade black for the British and white for the "
            "French [M6][R25][M4].",
    zones=[Zone(0, "felt", "cloth", "WOOL", ["logwood_black", "walnut_brown", "slate_grey"], "logwood_black"),
           Zone(1, "edge tape or lace", "trim", "WOOL", ["logwood_black", "white_facing", "false_gold", "silver_lace",
                                                         "gold_lace"], "logwood_black"),
           Zone(2, "cockade", "ribbon", "FLAT", ["ribbon_black", "ribbon_white", "logwood_black"], "ribbon_black"),
           Zone(3, "button", "button", "MET", ["brass", "pewter", "silver", "logwood_black"], "pewter")],
    hides_hair_zones=["crown"], sources=["M6", "R25", "M4"], evidence="A", tags=["colonial"], budget=1800,
    extra={"presets": {"civilian": {"1": "logwood_black", "2": "ribbon_black", "3": "pewter"},
                       "british_private": {"1": "white_facing", "2": "ribbon_black", "3": "pewter"},
                       "marine": {"1": "false_gold", "2": "ribbon_white", "3": "brass"}},
           "felt_note": "Felt uses the WOOL kit with a soft nap (ClothMaterials FELT_WORDS: the id has 'hat')."})


def build(g):
    recipes.rigid_hat(g, hats.TRICORNE)


build_and_export = G.runner(SPEC, build)
