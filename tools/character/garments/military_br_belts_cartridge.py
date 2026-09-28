"""British buff cross belts with cartridge pouch and bayonet (costume bible §5.1, §5.6
`br_belts_cartridge`).

Two buff (or whitened) shoulder belts about 2 1/4 inches wide crossing on the chest and
back: the pouch belt over the left shoulder carries the black leather cartridge pouch with
a brass badge at the right hip; the bayonet belt over the right shoulder carries the frog
and scabbard at the left hip [P6][M1][M5]. Grade B as a pair: the bible's 1750s pattern hung
the bayonet from a waist belt, and the crossed pair is the later (1760s-1768) arrangement.
Laid over the regimental coats (env40).
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _belts as BL

SPEC = B.MilSpec(
    id="br_belts_cartridge", name="Cross belts with cartridge pouch", slot="accessories.shoulder",
    layer={"default": 60},
    description=("Two buff leather shoulder belts crossed on the chest, with the black cartridge pouch at the right hip "
                 "and the bayonet at the left."),
    zones=[Zone(0, "leather", "LEA", ["white_buff", "buff", "pale_buff"], "white_buff", name="belts"),
           Zone(2, "leather", "LEA", ["leather_black", "leather_brown"], "leather_black", name="pouch and scabbard"),
           Zone(3, "metal", "MET", ["brass", "pewter", "silver"], "brass", name="badge and fittings")],
    variants={"env40": "res://assets/character/garments/military/br_belts_cartridge.glb"},
    evidence="B", sources=["P6", "M1", "M5"], budget={"tris_max": 4000}, deform_class="strap",
    history=("The pouch belt over the left shoulder was standard; in the 1750s the bayonet usually hung from a waist "
             "belt, and the crossed pair became the rule in the 1760s. Belts were buff, whitened for parade."),
    tags=["regulars", "british", "env40"],
    extra={"envelope_variant": "env40: laid 4.5 mm over the regimental coats' outer form (military_lib._coat)."},
)


def build(ctx):
    return {"main": BL.cross_belts(ctx, SPEC)}
