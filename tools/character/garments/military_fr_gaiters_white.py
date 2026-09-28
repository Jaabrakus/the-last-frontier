"""French white gaiters (costume bible §5.2-5.3, §5.6 `fr_gaiters_white`).

White linen gaiters to the thigh, buttoned up the outside and fastened below the knee,
worn by the troupes de la marine in garrison and by the metropolitan regiments [M4][M5]
[R25]. Grade A.
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _legs as L

SPEC = B.MilSpec(
    id="fr_gaiters_white", name="Guêtres (white gaiters)", slot="legs.over", layer={"default": 30, "feet": 45},
    description="White linen gaiters to the thigh, buttoned up the outer side and fastened below the knee.",
    zones=[Zone(0, "cloth", "LIN", ["linen_white", "linen_unbleached"], "linen_white", name="linen"),
           Zone(2, "leather", "LEA", ["leather_black", "buff"], "leather_black", name="garter strap"),
           Zone(3, "button", "MET", ["pewter", "brass"], "pewter", name="buttons and buckles")],
    deform_class="leggings",
    hides_regions=["shin_upper_l", "shin_upper_r", "shin_lower_l", "shin_lower_r", "ankle_l", "ankle_r"],
    evidence="A", sources=["M4", "M5", "R25"], budget={"tris_max": 2500},
    history=("Part of the garrison uniform of the Compagnies franches de la marine and of the regiments of the "
             "troupes de terre; on campaign many changed to mitasses (wool leggings) and moccasins."),
    tags=["regulars", "french"],
)


def build(ctx):
    return {"main": L.gaiters(ctx, SPEC, top=0.585)}
