"""British long gaiters (costume bible §5.1, §5.6 `br_gaiters`).

Linen or canvas gaiters reaching above the knee, buttoned up the outside, with a leather
garter strap below the knee and the lower edge over the shoe. White in the 1750s (Morier's
1751 grenadiers [M20]); the 1768 warrant made them black linen [P6]. Grade A.
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _legs as L

SPEC = B.MilSpec(
    id="br_gaiters", name="Long gaiters", slot="legs.over", layer={"default": 30, "feet": 45},
    description="Linen gaiters to above the knee, buttoned up the outer side, strapped below the knee.",
    zones=[Zone(0, "cloth", "LIN", ["linen_white", "logwood_black", "slate_grey"], "linen_white", name="linen"),
           Zone(2, "leather", "LEA", ["leather_black", "leather_brown"], "leather_black", name="garter strap"),
           Zone(3, "button", "MET", ["pewter", "leather_black", "brass"], "pewter", name="buttons and buckles")],
    deform_class="leggings",
    hides_regions=["shin_upper_l", "shin_upper_r", "shin_lower_l", "shin_lower_r", "ankle_l", "ankle_r"],
    evidence="A", sources=["M20", "P6", "M1"], budget={"tris_max": 2500},
    history=("Long white gaiters over the knee in the 1750s (Morier, 1751); black linen gaiters from the 1768 "
             "warrant. In the woods in 1758 the army changed to wool leggings."),
    tags=["regulars", "british"],
)


def build(ctx):
    return {"main": L.gaiters(ctx, SPEC, top=0.575)}
