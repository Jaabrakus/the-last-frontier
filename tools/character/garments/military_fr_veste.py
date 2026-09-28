"""French veste (costume bible §5.2-5.3, §5.6 `fr_veste`).

The sleeved waistcoat worn under the justaucorps: blue for the troupes de la marine, red or
blue for the metropolitan regiments, buttoned down the front, long skirted with pocket
flaps [M4][M5][M6]. Its sleeves end just under the coat's cuff. Grade A.
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _vest as V

SPEC = B.MilSpec(
    id="fr_veste", name="Veste (sleeved waistcoat)", slot="vest",
    layer={"default": 20, "hips": 25, "thighs": 25},
    description="Sleeved wool waistcoat buttoned down the front, long in the skirt, with buttoned pocket flaps.",
    zones=[Zone(0, "cloth", "WOOL", ["royal_blue", "madder_red", "grey_white"], "royal_blue", name="cloth"),
           Zone(3, "button", "MET", ["brass", "pewter", "silver"], "brass", name="buttons")],
    hides_regions=["chest_front", "chest_side", "chest_back", "chest_upper_back", "chest_upper_side", "abdomen_front",
                   "abdomen_side", "abdomen_back", "upper_arm_l", "upper_arm_r", "forearm_a_l", "forearm_a_r"],
    evidence="A", sources=["M4", "M5", "M6"], budget={"tris_max": 4500}, deform_class="coat", cov_dist=0.25,
    history=("Blue for the troupes de la marine; La Reine, Guyenne and Berry wore red vestes, Béarn, Royal-Roussillon "
             "and Languedoc blue, La Sarre red."),
    tags=["regulars", "french"],
)


def build(ctx):
    return {"main": V.vest(ctx, SPEC, V.FRENCH)}
