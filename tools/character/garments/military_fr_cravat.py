"""French white cravat (costume bible §5.2, §5.6 `fr_cravat`).

The white linen neckcloth of the troupes de la marine's garrison uniform, knotted at the
throat with the short ends tucked into the veste [M6][R25]. Grade A. (A black stock is the
British item `br_stock`.)
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _neck as N

SPEC = B.MilSpec(
    id="fr_cravat", name="Cravate (neckcloth)", slot="accessories.neck", layer={"default": 15},
    description="A white linen neckcloth wound round the neck and knotted at the throat.",
    zones=[Zone(0, "cloth", "LIN", ["linen_white", "logwood_black"], "linen_white", name="linen")],
    hides_regions=["neck_lower"],
    evidence="A", sources=["M6", "R25"], budget={"tris_max": 900}, deform_class="linen",
    history="Part of the garrison uniform of the Compagnies franches de la marine with the grey-white justaucorps.",
    tags=["regulars", "french"],
)


def build(ctx):
    return {"main": N.neckwear(ctx, SPEC, cravat=True)}
