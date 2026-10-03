"""The Spanish capa (cloth2 recipe type cloak: cloth2.dress.CLOAK): a long circle cape of broadcloth from a small
stand collar to the shins, clasped at the throat and worn thrown back from the arms, its fronts turned back to show
the embozos (the front facings, often of velvet)."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["undyed_brown", "walnut_brown", "logwood_black", "stroud_blue", "slate_grey", "madder_red"]
UNDER = ["shirt_linen", "veste_sleeved", "breeches", "stockings"]

SPEC = Spec(
    id="spanish_capa", name="Capa (Spanish cape)", set="spanish", slot="accessories.wrap", layer={"default": 50},
    description="A long circle cape of broadcloth from a small stand collar to the shins, clasped at the throat and "
                "thrown back from the arms, the fronts turned back to show their velvet facings.",
    history="The long cape and the broad hat were the dress of every Spaniard, high and low, until the decree of 10 "
            "March 1766 that cut them short and set off the Esquilache riots: a three-quarter to full circle of paño "
            "broadcloth from Segovia or Bejar, pardo brown for ordinary men, dark brown, black or blue with red or "
            "green velvet embozos for the better-off; muffled to the eyes (embozado) it hid the face [EU-S1][EU-S2].",
    zones=[Zone(0, "broadcloth", "cloth", "WOOL", PAL, "undyed_brown"),
           Zone(1, "embozos (front facings)", "lining", "WOOL", PAL + ["scarlet", "full_green", "deep_green"],
                "madder_red"),
           Zone(2, "clasp", "metal", "MET", ["brass", "silver", "pewter"], "brass")],
    sources=["EU-S1", "EU-S2"], evidence="A", tags=["men", "women", "spanish"], budget=7000, over=UNDER,
    extra={"presets": {"pardo": {"0": "undyed_brown", "1": "walnut_brown", "2": "brass"},
                       "better_off": {"0": "logwood_black", "1": "scarlet", "2": "silver"},
                       "blue": {"0": "stroud_blue", "1": "full_green", "2": "brass"}},
           "styles_note": "Styles from the same recipe: the short capa (hem 0.55), embozado (the right front thrown "
                          "over the left shoulder: static, later), the esclavina (a shoulder cape to 1.12).",
           "recipe_note": "cloth2.dress.cloak: the envelope over the shoulders and the upper arms (above 1.08), "
                          "behind the forearms below, closed at the throat (+-3.5 deg) and parting to 92-104 deg below "
                          "the arms (worn thrown back: the forearms come out in front of the edges); hem 0.22 at the "
                          "fronts / 0.20 behind; the embozos a band 5 cm along each front edge raised 2.2 mm (zone 1); "
                          "a 3.4 cm stand collar; two clasp discs at 1.33.",
           "arms_note": "Muffled to the eyes with the arms inside (embozado) is a later static style: in the bind "
                        "pose's A the arms cannot sit inside a cape that also hangs right when they come down.",
           "references": ["[EU-S1] Esquilache riots: https://en.wikipedia.org/wiki/Esquilache_Riots",
                          "[EU-S2] FIT, the Spanish cape: https://fashionhistory.fitnyc.edu/spanish-cape/"]})

STYLE = dress._style(dress.CLOAK, {"over": tuple(UNDER)})


def build(g):
    recipes.cloak(g, STYLE)


build_and_export = G.runner(SPEC, build)
