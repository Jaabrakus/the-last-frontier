"""British regimental coat cropped for the woods, 1758 (costume bible §5.1, §5.6
`br_coat_cropped_1758`).

Lord Howe's reforms before Ticonderoga (Dr Richard Huck, 29 May 1758): coats "docked"
shorter than the Highlanders', the lace taken off, hat brims cut down, hair cropped [M1].
The same lapelled red coat with the skirts shortened to the upper thigh and plain
buttonholes. Grade A.
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _coat as C
from garments.military_lib import _regiments as R

ST = C.BRITISH_1758
SPEC = B.MilSpec(
    id="br_coat_cropped_1758", name="Regimental coat, cropped (1758)", slot="outer", layer={"default": 40},
    description="The lapelled regimental coat with its skirts docked to the upper thigh and the lace taken off.",
    zones=[Zone(0, "cloth", "WOOL", ["madder_red", "scarlet"], "madder_red", name="coat"),
           Zone(1, "trim", "WOOL", R.BRITISH_FACINGS, "buff", name="facings and lining"),
           Zone(3, "button", "MET", ["pewter", "brass", "silver"], "pewter", name="buttons")],
    hides_regions=["chest_upper_side", "chest_upper_back", "chest_side", "chest_back", "abdomen_side",
                   "abdomen_back", "upper_arm_l", "upper_arm_r", "forearm_a_l", "forearm_a_r"],
    skirt=C.skirt_catalog(ST), helpers=["shoulder_twist", "forarm_twist", "upper_leg_front_helper",
                                        "upper_leg_thigh_helper", "upper_leg_rear_helper"],
    evidence="A", sources=["M1", "M3", "P5"], budget={"tris_max": 8000}, deform_class="coat", cov_dist=0.25,
    history=("In 1758 Lord Howe had the army's coats docked shorter than the Highlanders' and the lace removed; "
             "gorgets and sashes were left behind (Huck, 29 May 1758)."),
    tags=["regulars", "british", "1758"],
    extra={"regiments": R.BRITISH_REGIMENTS, "female_body_note": "Grade C on a female body (bible §5.1)."},
)


def build(ctx):
    return {"main": C.coat(ctx, SPEC, ST)}
