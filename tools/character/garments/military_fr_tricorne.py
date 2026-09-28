"""French tricorne (costume bible §5.2, §5.6 `fr_tricorne`).

Black felt tricorne edged with false-gold lace (silver for some regiments), worn low, with
the white cockade of the French crown [M6][R25]. Grade A. Rigid on the head; it hides the
hair's crown zone.
"""

from lib.catalog import Zone

from garments.military_lib import _base as B
from garments.military_lib import _hats as H

SPEC = B.MilSpec(
    id="fr_tricorne", name="Tricorne, laced", slot="head", layer={"default": 80},
    description="Black felt tricorne edged with false-gold lace, with a white cockade.",
    zones=[Zone(0, "cloth", "WOOL", ["logwood_black"], "logwood_black", name="felt"),
           Zone(1, "trim", "MET", ["false_gold", "silver_lace", "gold_lace"], "false_gold", name="lace"),
           Zone(2, "ribbon", "FLAT", ["ribbon_white"], "ribbon_white", name="cockade"),
           Zone(3, "button", "MET", ["brass", "silver"], "brass", name="button")],
    hides_hair_zones=["crown"], weights="headb",
    evidence="A", sources=["M6", "R25", "M4"], budget={"tris_max": 1800}, deform_class="rigid",
    history="The colonial regulars wore the tricorne with false-gold lace, pulled low; officers' lace was fine gold.",
    tags=["regulars", "french"],
    extra={"felt_note": "Felt uses the WOOL kit with a low normal strength (bible §7)."},
)


def build(ctx):
    return {"main": H.hat(ctx, SPEC, H.FRENCH)}
