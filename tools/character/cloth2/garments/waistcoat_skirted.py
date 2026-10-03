"""The long-skirted waistcoat of the 1750s (cloth2 recipe: recipes.waistcoat with long skirts): wool, buttoned from
the neck to below the waist, the skirts to mid-thigh with pocket flaps, the fronts parting a little below the last
button; the back of linen. The British private's red waistcoat of the 1751 Clothing Warrant under the regimental coat
(and under the frock coat and the skirted coat): the coats' open skirts show it, and it covers the shirt's tails."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="waistcoat_skirted", name="Waistcoat, long-skirted", set="colonial", slot="vest",
    layer={"default": 20, "hips": 25, "thighs": 25},
    description="A long wool waistcoat buttoned from the neck to below the waist, its skirts to mid-thigh with pocket "
                "flaps, the back of linen.",
    history="Under the 1751 regimental coat the private wore a long waistcoat, red for most regiments (the facing "
            "colour for a few), its skirts reaching the thigh below the coat's turned-back fronts (Morier's grenadier "
            "paintings of 1751) [S17][S4]. The summer 1758 orders cut waistcoats short; Lisle's men at the German "
            "Flatts that winter still had the long ones. Gentlemen's waistcoats of the 1750s were as long, of cloth or "
            "silk, often buff or matching the coat (the V&A's 1750s suit) [S12].",
    zones=[Zone(0, "fronts", "cloth", "WOOL", ["madder_red", "scarlet", "buff", "white_facing", "pale_buff",
                                               "royal_blue", "full_green", "snuff", "walnut_brown", "drab"], "madder_red"),
           Zone(1, "back", "lining", "LIN", ["linen_unbleached", "linen_white", "madder_red"], "linen_unbleached"),
           Zone(2, "buttons", "button", "MET", ["pewter", "brass", "silver", "gold_lace"], "pewter")],
    sources=["S17", "S4", "M1", "S12"], evidence="A", tags=["men", "colonial", "regulars", "british", "gentry"], budget=4200,
    over=["shirt_linen", "breeches"],
    extra={"worn_under": ["coat_regimental_1751", "frock_coat", "coat_skirted"],
           "presets": {"22nd_foot": {"0": "madder_red", "1": "linen_unbleached", "2": "pewter"},
                       "buff": {"0": "buff", "1": "linen_unbleached", "2": "brass"}},
           "references": ["https://col.rct.uk/collection/405585/grenadiers-22nd-and-24th-regiments-of-foot-and-23rd-royal-welch-fusiliers-1751",
                          "https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Siege-of-Carillon-British-Regulars-Guidelines.pdf",
                          "https://collections.vam.ac.uk/item/O127143/suit-unknown"]})

# recipes.WAISTCOAT with long skirts: buttoned to 0.86, the fronts barely parting below, the hem at mid-thigh (the
# shirt's tails, 0.60 in front, hang inside it); close over the hips, so the skirted coats' skirts clear it
STYLE = recipes.style(recipes.WAISTCOAT, over=tuple(SPEC.over), hem=(0.585, 0.62, 0.64), flare=0.03, steps=8,
                      skirt_gap=0.018,
                      opening=[(0.55, 0.022), (0.70, 0.012), (0.80, 0.004), (0.86, 0.0), (1.16, 0.0), (1.24, 0.034),
                               (1.30, 0.060), (1.40, 0.10), (1.6, 0.12)],
                      buttons={"n": 12, "z": (1.15, 0.87), "x": -0.0075, "r": 0.0065},
                      pockets={"z": (0.80, 0.835), "x": (0.05, 0.14), "h": 0.0028})


def build(g):
    recipes.waistcoat(g, STYLE)


build_and_export = G.runner(SPEC, build)
