"""The frock coat (cloth2 recipe: recipes.coat, the FROCK cut): the everyday coat of men of almost every rank, plain
wool with a turned-down collar, buttoned from the breast to the waist, the fronts curving away below it, pleated
skirts to just above the knee with a back vent, round cuffs and flapped pockets. Worn by the valley's settlers and
militia over the shirt, waistcoat and breeches."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import tailor as TL
from cloth2.spec import Spec, Zone

PAL = ["walnut_brown", "drab", "slate_grey", "stroud_blue", "butternut", "snuff", "indigo_mid", "logwood_black",
       "ranger_green", "grey_white"]

SPEC = Spec(
    id="frock_coat", name="Frock coat", set="colonial", slot="outer", layer={"default": 40},
    description="A plain wool frock coat with a turned-down collar, buttoned from the breast to the waist, the fronts "
                "curving away below, pleated skirts with a back vent, round cuffs and flapped pockets.",
    history="Men at almost every level wore the frock for work and informal wear: plain cloth, a turn-down collar and "
            "an easy cut, in drab, brown, grey, blue or green [R20][M3]. In the Mohawk valley the Palatine farmers "
            "and their militia wore the same coats as their English neighbours; no dress source specific to German "
            "Flatts survives, so this follows rural Pennsylvania German and general 1750s evidence (Goschenhoppen "
            "Historians; the V&A's 1750s suit for the cut).",
    zones=[Zone(0, "coat", "cloth", "WOOL", PAL, "walnut_brown"),
           Zone(1, "collar, cuffs and lining", "trim", "WOOL", PAL + ["linen_unbleached", "madder_red", "buff"],
                "walnut_brown"),
           Zone(2, "buttons", "button", "MET", ["brass", "pewter", "horn", "logwood_black", "silver"], "pewter")],
    sources=["R20", "M3", "M15", "S9", "S12"], evidence="A", tags=["men", "colonial", "settlers", "militia"],
    budget=7800, over=["shirt_linen", "breeches", "waistcoat_sb", "waistcoat_skirted"],
    extra={"presets": {"palatine_brown": {"0": "walnut_brown", "1": "walnut_brown", "2": "horn"},
                       "palatine_drab": {"0": "drab", "1": "drab", "2": "pewter"},
                       "militia_blue": {"0": "stroud_blue", "1": "stroud_blue", "2": "pewter"},
                       "rook": {"0": "slate_grey", "1": "slate_grey", "2": "pewter"}},
           "references": ["https://goschenhoppen.org/colonial-clothing/",
                          "https://collections.vam.ac.uk/item/O127143/suit-unknown",
                          "https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Siege-of-Carillon-Rogers-Rangers-Guidelines.pdf"],
           "female_body_note": "Built for every fit; on a woman it is artistic licence (the frock was a man's coat)."})

# recipes.FROCK, open at the throat in a small V (the neckerchief shows; the collar turns down round it), buttoned from
# the breast to the waist
FROCK = recipes.style(recipes.FROCK, over=tuple(SPEC.over), vent=0.84, collar=("fall", 0.05),
                      opening=[(0.40, 0.16), (0.52, 0.15), (0.62, 0.13), (0.75, 0.10), (0.86, 0.06), (0.95, 0.022),
                               (1.0, 0.0), (1.20, 0.0), (1.27, 0.022), (1.33, 0.042), (1.6, 0.09)],
                      front_buttons={"n": 8, "z": (1.205, 0.995), "inset": 0.012, "side": -1})


def build(g):
    recipes.coat(g, FROCK)
    TL.clean(g)


build_and_export = G.runner(SPEC, build)
