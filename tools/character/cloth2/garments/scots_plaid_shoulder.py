"""The belted plaid's upper part (cloth2 recipe type drape, anchor belted: cloth2.dress.BELTED): a great tartan
plaid tucked under the belt behind, rising over the back to the left shoulder and pinned there in front with a ring
brooch, the right arm free, its end hanging behind over the left side. Worn over the philabeg; the belt holds both.
Part of the Highland dress (a set any character may wear)."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["madder_red", "deep_green", "stroud_blue", "full_green", "logwood_black", "indigo_mid", "deep_yellow", "drab"]
SETT = {"options": ["plaid", "none", "check"], "default": "plaid",
        "plaid": {"sett": "madder_red", "scale_m": 0.16},
        "check": {"colors": ["logwood_black", "linen_white"], "scale_m": 0.012},
        "note": "our own setts (assets/character/fabrics/setts.json), never registered or clan tartans; the sett "
                "aligned with the philabeg's"}
UNDER = ["shirt_linen", "scots_philabeg"]

SPEC = Spec(
    id="scots_plaid_shoulder", name="Belted plaid (shoulder)", set="highland", slot="accessories.wrap",
    layer={"default": 50},
    description="A great tartan plaid tucked under the belt behind, over the back to the left shoulder and pinned "
                "there with a ring brooch, the right arm free, the end hanging behind.",
    history="The belted plaid was a great length of tartan pleated and belted round the waist, its upper half thrown "
            "over the left shoulder and pinned with a brooch, the end hanging behind; with the philabeg the upper "
            "part was worn on its own the same way [EU-H2][EU-H3][EU-H8b]. Highland dress was banned in Scotland 'for "
            "man or boy' from 1 August 1747 to 1782; soldiers were exempt and the Act did not run in America [EU-H1].",
    zones=[Zone(0, "tartan", "cloth", "WOOL", PAL, "madder_red", pattern=SETT),
           Zone(2, "belt", "leather", "LEA", ["leather_black", "leather_brown"], "leather_black"),
           Zone(3, "brooch and buckle", "metal", "MET", ["silver", "brass", "pewter"], "silver")],
    sources=["EU-H2", "EU-H3", "EU-H8b", "EU-H1"], evidence="A", tags=["men", "women", "highland"], budget=7000,
    over=UNDER,
    extra={"presets": {"red_sett": {"0": "madder_red", "2": "leather_black", "3": "silver"},
                       "green_sett": {"0": "deep_green", "2": "leather_black", "3": "silver", "sett": "hill_green"},
                       "hodden": {"0": "drab", "2": "leather_brown", "3": "brass", "sett": "drab_hodden"}},
           "set_note": "The Highland dress is a clothing set (the owner, 2026-10-03), not a people: offered to everyone.",
           "law_note": "Dress Act 1747-82 (Scotland only; soldiers exempt): historical context, never enforced.",
           "recipe_note": "cloth2.dress.drape anchor belted: the envelope over the left shoulder and arm (above 1.12), "
                          "cut to the outline: under the belt behind at 0.99, over the back to the left shoulder, "
                          "the front flap to 1.23, the end behind over the left of the back to 0.56; a belt "
                          "0.965-1.005 with a buckle, a ring brooch r 2.8 cm at 1.27, 32 deg.",
           "references": ["[EU-H2] Burt via https://en.wikipedia.org/wiki/Arisaid",
                          "[EU-H8b] Full plaid: https://en.wikipedia.org/wiki/Full_plaid",
                          "[EU-H1] The Dress Act: https://historyofparliament.com/2020/11/17/banning-scottish-highland-dress-in-the-aftermath-of-culloden/"]})

STYLE = dress._style(dress.BELTED, {"over": tuple(UNDER)})


def build(g):
    recipes.drape(g, STYLE)


build_and_export = G.runner(SPEC, build)
