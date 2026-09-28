"""French buff waist belt with gargoussier (costume bible §5.2, §5.6 `fr_belt_gargoussier`).

A buff leather waist belt with a brass buckle carrying the small red Russia-leather cartridge
pouch (gargoussier) in front and the bayonet at the left hip, worn by the troupes de la
marine [M4][M5]. Grade A. Laid over the justaucorps (env40).
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _belts as BL

SPEC = B.MilSpec(
    id="fr_belt_gargoussier", name="Ceinturon with gargoussier", slot="accessories.waist", layer={"default": 60},
    description="Buff leather waist belt with a brass buckle, a small red leather cartridge pouch and the bayonet.",
    zones=[Zone(0, "leather", "LEA", ["buff", "white_buff", "pale_buff"], "buff", name="belt"),
           Zone(2, "leather", "LEA", ["madder_red", "leather_black"], "madder_red", name="gargoussier and scabbard"),
           Zone(3, "metal", "MET", ["brass", "pewter"], "brass", name="buckle and chape")],
    variants={"env40": "res://assets/character/garments/military/fr_belt_gargoussier.glb"},
    evidence="A", sources=["M4", "M5"], budget={"tris_max": 3000}, deform_class="strap",
    history="The gargoussier, a small pouch of red Russia leather, rode on the waist belt of the colonial regulars.",
    tags=["regulars", "french", "env40"],
    extra={"envelope_variant": "env40: laid 5 mm over the regimental coats' outer form (military_lib._coat)."},
)


def build(ctx):
    return {"main": BL.waist_belt(ctx, SPEC)}
