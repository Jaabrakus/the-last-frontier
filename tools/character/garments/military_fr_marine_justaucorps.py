"""Justaucorps of the Compagnies franches de la marine (costume bible §5.2, §5.6
`fr_marine_justaucorps`).

The colonial regulars' garrison coat: greyish-white wool, collarless in the colonies,
buttoned down the front to the skirts, deep blue cuffs with three buttons, pocket flaps with
five buttons, blue lining, brass buttons [M6][M5][R25]. Grade A. The metropolitan regiments'
coats (troupes de terre) share the cut with regimental cuff colours: see "regiments_terre".
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _coat as C
from garments.military_lib import _regiments as R

ST = C.FRENCH_MARINE
SPEC = B.MilSpec(
    id="fr_marine_justaucorps", name="Justaucorps, troupes de la marine", slot="outer", layer={"default": 40},
    description=("Grey-white collarless wool coat buttoned down the front, with deep blue cuffs, blue lining and "
                 "brass buttons."),
    zones=[Zone(0, "cloth", "WOOL", ["grey_white", "royal_blue"], "grey_white", name="coat"),
           Zone(1, "trim", "WOOL", ["royal_blue", "madder_red"], "royal_blue", name="cuffs and lining"),
           Zone(3, "button", "MET", ["brass", "pewter", "silver", "gold_lace"], "brass", name="buttons")],
    hides_regions=["chest_upper_side", "chest_upper_back", "chest_side", "chest_back", "abdomen_side",
                   "abdomen_back", "upper_arm_l", "upper_arm_r", "forearm_a_l", "forearm_a_r"],
    skirt=C.skirt_catalog(ST), helpers=["shoulder_twist", "forarm_twist", "upper_leg_front_helper",
                                        "upper_leg_thigh_helper", "upper_leg_rear_helper"],
    evidence="A", sources=["M6", "M5", "R25", "M4"], budget={"tris_max": 8500}, deform_class="coat", cov_dist=0.25,
    history=("The colonial companies kept the grey-white justaucorps buttoned to the hem after the Army dropped it "
             "in 1736; officers had gilt buttons, the drummer the King's blue livery."),
    tags=["regulars", "french"],
    extra={"regiments_terre": R.FRENCH_TERRE, "female_body_note": "Grade C on a female body (bible §5.1)."},
)


def build(ctx):
    return {"main": C.coat(ctx, SPEC, ST)}
