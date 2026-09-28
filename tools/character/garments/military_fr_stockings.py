"""French knit stockings (costume bible §5.2-5.3, §5.6 `fr_stockings`).

Knitted wool stockings drawn up over the knee under the breeches' knee band: blue for the
troupes de la marine, white or grey for the metropolitan regiments [M4][M5]. Grade A.
They share the legs.over slot with the gaiters, which cover them anyway.
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _legs as L

SPEC = B.MilSpec(
    id="fr_stockings", name="Bas (knit stockings)", slot="legs.over", layer={"default": 10},
    description="Knitted wool stockings drawn up over the knee under the breeches' knee band.",
    zones=[Zone(0, "cloth", "KNIT", ["royal_blue", "linen_white", "slate_grey"], "royal_blue", name="knit")],
    deform_class="leggings",
    hides_regions=["shin_upper_l", "shin_upper_r", "shin_lower_l", "shin_lower_r", "ankle_l", "ankle_r",
                   "foot_l", "foot_r"],
    evidence="A", sources=["M4", "M5", "M6"], budget={"tris_max": 2500},
    history="Blue stockings with the blue veste and breeches of the troupes de la marine.",
    tags=["regulars", "french"],
)


def build(ctx):
    return {"main": L.stockings(ctx, SPEC, top=0.60)}
