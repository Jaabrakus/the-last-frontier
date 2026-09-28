"""British regimental waistcoat (costume bible §5.1, §5.6 `br_waistcoat`).

Sleeveless, single-breasted wool waistcoat to the top of the thigh, the fronts parting below
the last button, pocket flaps with three buttons. Red in the 1750s (like the breeches),
white or buff from the 1768 warrant [P5][P6][M1]. Grade A.
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _vest as V

SPEC = B.MilSpec(
    id="br_waistcoat", name="Regimental waistcoat", slot="vest", layer={"default": 20, "hips": 25, "thighs": 25},
    description="Sleeveless single-breasted wool waistcoat to the top of the thigh, with buttoned pocket flaps.",
    zones=[Zone(0, "cloth", "WOOL", ["madder_red", "white_facing", "buff", "pale_buff"], "madder_red", name="cloth"),
           Zone(3, "button", "MET", ["pewter", "brass", "silver"], "pewter", name="buttons")],
    hides_regions=["chest_front", "chest_side", "chest_back", "chest_upper_back", "abdomen_front", "abdomen_side",
                   "abdomen_back"],
    evidence="A", sources=["P5", "P6", "M1"], budget={"tris_max": 3200}, deform_class="coat", cov_dist=0.25,
    history="Red in the 1750s, like the breeches; the 1768 warrant made waistcoats white or buff, plain.",
    tags=["regulars", "british"],
)


def build(ctx):
    return {"main": V.vest(ctx, SPEC, V.BRITISH)}
