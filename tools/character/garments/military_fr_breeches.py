"""French breeches (costume bible §5.2-5.3, §5.6 `fr_breeches`).

Troupes de la marine: blue breeches with the blue veste and stockings; troupes de terre:
grey-white breeches [M4][M5][M6]. Same cut as the British pair: fall front, buttoned and
buckled at the knee. Grade A.
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _legs as L

SPEC = B.MilSpec(
    id="fr_breeches", name="Culottes (breeches)", slot="legs.lower", layer={"default": 20},
    description="Wool knee breeches with a fall front, buttoned at the outer knee and buckled below it.",
    zones=[Zone(0, "cloth", "WOOL", ["royal_blue", "grey_white", "madder_red"], "royal_blue", name="cloth"),
           Zone(3, "button", "MET", ["brass", "pewter"], "brass", name="buttons and buckles")],
    deform_class="breeches", cov_dist=0.25,
    hides_regions=["pelvis_center", "pelvis_side", "thigh_upper_l", "thigh_upper_r", "thigh_lower_l", "thigh_lower_r"],
    evidence="A", sources=["M4", "M5", "M6", "R25"], budget={"tris_max": 2000},
    history=("Troupes de la marine wore blue breeches with the blue veste; the metropolitan regiments sent to "
             "Canada from 1755 wore grey-white ones."),
    tags=["regulars", "french"],
)


def build(ctx):
    return {"main": L.breeches(ctx, SPEC)}
