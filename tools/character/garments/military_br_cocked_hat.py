"""British private's cocked hat (costume bible §5.1, §5.6 `br_cocked_hat`).

Black wool felt, the brim cocked up on three sides and bound with white tape, a black
cockade held by a loop and button on the left front [P6][M20]. Officers' hats were laced
with gold or silver. Grade A. Rigid on the head; it hides the hair's crown zone.
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _hats as H

SPEC = B.MilSpec(
    id="br_cocked_hat", name="Cocked hat", slot="head", layer={"default": 80},
    description="Black felt hat cocked on three sides, bound with white tape, with a black cockade.",
    zones=[Zone(0, "cloth", "WOOL", ["logwood_black"], "logwood_black", name="felt"),
           Zone(1, "trim", "LIN", ["linen_white", "gold_lace", "silver_lace"], "linen_white", name="binding"),
           Zone(2, "ribbon", "FLAT", ["logwood_black", "ribbon_black"], "logwood_black", name="cockade"),
           Zone(3, "button", "MET", ["pewter", "brass", "silver"], "pewter", name="button")],
    hides_hair_zones=["crown"], weights="headb",
    evidence="A", sources=["P6", "M20", "M1"], budget={"tris_max": 1800}, deform_class="rigid",
    history=("Black felt hats bound with white tape; in 1758 many brims were cut down to round hats for the woods "
             "(the round hat is a separate item)."),
    tags=["regulars", "british"],
    extra={"felt_note": "Felt uses the WOOL kit with a low normal strength (bible §7)."},
)


def build(ctx):
    return {"main": H.hat(ctx, SPEC, H.BRITISH)}
