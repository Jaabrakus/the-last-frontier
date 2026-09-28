"""British linen or black stock (costume bible §5.1, §5.6 `br_stock`).

A stiffened band round the neck, buckled behind: white linen or black (horsehair or
leather) [P6][M1]. Grade A.
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _neck as N

SPEC = B.MilSpec(
    id="br_stock", name="Stock", slot="accessories.neck", layer={"default": 15},
    description="A stiffened band worn round the neck and buckled behind.",
    zones=[Zone(0, "cloth", "LIN", ["logwood_black", "linen_white"], "logwood_black", name="stock"),
           Zone(3, "metal", "MET", ["brass", "pewter"], "brass", name="buckle")],
    hides_regions=["neck_lower"],
    evidence="A", sources=["P6", "M1"], budget={"tris_max": 900}, deform_class="linen",
    history="The soldier's stock was buckled behind the neck; black stocks became regulation later in the century.",
    tags=["regulars", "british"],
)


def build(ctx):
    return {"main": N.neckwear(ctx, SPEC, cravat=False)}
