"""British regimental coat, 1751 pattern (costume bible §5.1, §5.6 `br_regimental_coat_1751`).

Full-skirted red coat lapelled to the waist in the regiment's facing colour, round cuffs
and turned-back skirt corners in the facing colour, pocket flaps, the buttonholes bound
with regimental lace (white worsted tape with coloured stripes) and a shoulder strap for
the pouch belt. The 1751 Royal Clothing Warrant fixed the facing colours [P5]; privates wore
madder red, officers cochineal scarlet [R12]; David Morier's 1751 paintings are the
standard visual reference [M20]. Grade A. The facings and lace of the regiments that served
in the northeast (bible §5.1 table) are in the entry's "regiments" list.

Worn by a female body it is a game choice (grade C per the bible: no women's uniform
existed); the coat is fitted to the body, not redesigned.
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _coat as C
from garments.military_lib import _regiments as R

ST = C.BRITISH_1751
SPEC = B.MilSpec(
    id="br_regimental_coat_1751", name="Regimental coat, 1751 pattern", slot="outer", layer={"default": 40},
    description=("Full-skirted wool coat lapelled to the waist in the facing colour, with round cuffs, turned-back "
                 "skirts and lace-bound buttonholes."),
    zones=[Zone(0, "cloth", "WOOL", ["madder_red", "scarlet"], "madder_red", name="coat"),
           Zone(1, "trim", "WOOL", R.BRITISH_FACINGS, "yellow", name="facings and lining"),
           Zone(2, "trim", "FLAT", ["linen_white", "gold_lace", "silver_lace"], "linen_white",
                pattern={"type": "lace_stripes", "axis": "v", "stripes": [["ribbon_black", 0.35, 0.12]]},
                name="lace"),
           Zone(3, "button", "MET", ["pewter", "brass", "silver", "gold_lace"], "pewter", name="buttons")],
    hides_regions=["chest_upper_side", "chest_upper_back", "chest_side", "chest_back", "abdomen_side",
                   "abdomen_back", "upper_arm_l", "upper_arm_r", "forearm_a_l", "forearm_a_r"],
    skirt=C.skirt_catalog(ST), helpers=["shoulder_twist", "forarm_twist", "upper_leg_front_helper",
                                        "upper_leg_thigh_helper", "upper_leg_rear_helper"],
    evidence="A", sources=["P5", "M20", "M5", "R12", "M1"], budget={"tris_max": 7500}, deform_class="coat", cov_dist=0.25,
    history=("The 1751 warrant fixed each regiment's facing colour and lace; privates' coats were madder red, "
             "officers' cochineal scarlet. Braddock's 44th and 48th wore this pattern in 1755."),
    tags=["regulars", "british"],
    extra={"regiments": R.BRITISH_REGIMENTS, "female_body_note": "Grade C on a female body (bible §5.1)."},
)


def build(ctx):
    return {"main": C.coat(ctx, SPEC, ST)}
