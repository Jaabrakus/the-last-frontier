"""British regimental breeches (costume bible §5.1, §5.6 `br_breeches`).

Wool breeches with a fall front, buttoned at the outer knee and buckled below it. In the
1750s they were red, like the waistcoat; the 1768 warrant made small clothes white or buff
[P5][P6][M1]. Grade A.
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _legs as L

HIDES = ["pelvis_center", "pelvis_side", "thigh_upper_l", "thigh_upper_r", "thigh_lower_l", "thigh_lower_r"]

SPEC = B.MilSpec(
    id="br_breeches", name="Regimental breeches", slot="legs.lower", layer={"default": 20},
    description="Wool knee breeches with a fall front, buttoned at the outer knee and buckled below it.",
    zones=[Zone(0, "cloth", "WOOL", ["madder_red", "white_facing", "buff", "pale_buff"], "madder_red", name="cloth"),
           Zone(3, "button", "MET", ["pewter", "brass", "silver"], "pewter", name="buttons and buckles")],
    hides_regions=HIDES, deform_class="breeches", cov_dist=0.25,
    evidence="A", sources=["P5", "P6", "M1"], budget={"tris_max": 2000},
    history=("Red in the 1750s, like the waistcoat (Fort Ticonderoga's 1758 guideline also allows leather or linen); "
             "the 1768 warrant made small clothes white or buff."),
    tags=["regulars", "british"],
)


def build(ctx):
    return {"main": L.breeches(ctx, SPEC)}
