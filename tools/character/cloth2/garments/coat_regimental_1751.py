"""The British regimental coat of the 1751 Clothing Warrant (cloth2 recipe: recipes.coat, the REGIMENTAL_1751 cut):
red cloth, lapels of the facing colour from the neck to the waist with ten buttons each and white tape loops, small
round cuffs with four buttons, the skirts turned back to show the lining, pocket flaps with four buttons, a shoulder
strap on the left. Its default is the 22nd Foot's: red faced buff, pewter buttons, plain white tape."""

import numpy as np

from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import tailor as TL
from cloth2 import settlers as ST
from cloth2.mesh import smoothstep
from cloth2.spec import Spec, Zone

FACINGS = ["buff", "pale_buff", "deep_yellow", "yellow", "pale_yellow", "full_green", "deep_green", "royal_blue",
           "white_facing", "logwood_black", "orange"]

SPEC = Spec(
    id="coat_regimental_1751", name="Regimental coat (1751)", set="colonial", slot="outer", layer={"default": 40},
    description="A red wool coat with facing-coloured lapels buttoned back from the neck to the waist and laced with "
                "white tape, small round cuffs, the skirts turned back to show the lining, pocket flaps and a shoulder "
                "strap on the left.",
    history="The 1751 Clothing Warrant fixed the cut of the British private's coat: red, lapels of the regiment's "
            "facing colour to the waist, small round cuffs, the skirts hooked back, the buttonholes bound with the "
            "regiment's worsted lace (Morier's grenadier paintings of 1751) [S17][S4]. A detachment of the 22nd Foot, "
            "red faced buff, wintered at the German Flatts in 1758 (Capt. Philip Townsend's letter of 1 March) [S16]. "
            "Its lace pattern is not confirmed, so the loops are plain white tape. Howe's cut-down coats came only in "
            "the summer of 1758.",
    zones=[Zone(0, "coat", "cloth", "WOOL", ["madder_red", "scarlet", "stroud_red"], "madder_red"),
           Zone(1, "facings and lining", "trim", "WOOL", FACINGS, "buff"),
           Zone(2, "buttons", "button", "MET", ["pewter", "brass", "silver", "gold_lace"], "pewter"),
           Zone(3, "lace", "trim", "WOOL", ["white_facing", "linen_white", "gold_lace", "silver_lace"], "white_facing")],
    sources=["S17", "S16", "S4", "M1"], evidence="A", tags=["men", "colonial", "regulars", "british"], budget=8000,
    over=["shirt_linen", "breeches", "waistcoat_skirted", "waistcoat_sb"],
    extra={"presets": {"22nd_foot": {"0": "madder_red", "1": "buff", "2": "pewter", "3": "white_facing"},
                       "officer": {"0": "scarlet", "1": "buff", "2": "gold_lace", "3": "gold_lace"}},
           "regiment_note": "Facings by regiment: the old garments/military_lib/_regiments.BRITISH_FACINGS. The 22nd's "
                            "lace pattern is unconfirmed (plain white tape).",
           "references": ["https://col.rct.uk/collection/405585/grenadiers-22nd-and-24th-regiments-of-foot-and-23rd-royal-welch-fusiliers-1751",
                          "https://cdn.rockislandauction.com/flipbooks/4093/BOOK+2/files/basic-html/page225.html",
                          "https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Siege-of-Carillon-British-Regulars-Guidelines.pdf"],
           "female_body_note": "Built for every fit; on a woman it is artistic licence."})

# the skirts cut away a little less than recipes.REGIMENTAL_1751 below the waist (the turned-back fronts then cover the
# shirt's tails under the waistcoat's points)
OPENING = [(0.40, 0.165), (0.52, 0.15), (0.62, 0.13), (0.75, 0.10), (0.86, 0.072), (0.93, 0.05), (1.00, 0.038),
           (1.10, 0.028), (1.20, 0.020), (1.28, 0.018), (1.36, 0.030), (1.6, 0.06)]
REG = recipes.style(recipes.REGIMENTAL_1751, over=tuple(SPEC.over), opening=OPENING, steps=6,
                    turnbacks={"w_hem": 0.09, "z_top": 0.90})
LAPEL_BUTTONS = 10
LACE_H = 0.0055              # half the height of a lace loop (the tape about 1 cm wide)


def lapel_w(z):
    lp = REG["lapels"]
    z0, z1 = lp["z"]
    w0, w1 = lp["w"]
    t = np.clip((np.asarray(z, float) - z0) / (z1 - z0), -0.5, 1.5)
    return w0 + (w1 - w0) * t


def build(g):
    recipes.coat(g, REG)
    TL.clean(g)
    # the lace loops: from the lapel's front edge out to its button, ten a side
    zs = np.linspace(1.258, 1.002, LAPEL_BUTTONS)
    x_in = g.opening_w(zs) + 0.007
    x_out = g.opening_w(zs) + lapel_w(zs) - 0.008

    def lace(P):
        X, Y, Z = np.abs(P[:, 0]), P[:, 1], P[:, 2]
        f = np.full(len(P), 1.0)
        for z, a, b in zip(zs, x_in, x_out):
            f = np.minimum(f, np.maximum.reduce([np.abs(Z - z) - LACE_H, a - X, X - b]))
        return f + 10.0 * smoothstep(-0.03, -0.005, Y)
    ST.stripe(g, lace, 3)
    # the lapel buttons at the outer ends of the loops
    for sg in (1.0, -1.0):
        P = g.front_points(sg * (x_out - 0.004), zs)
        g.buttons(P, 2, r=0.0072, h=0.003, segs=6)
    g.uv()


build_and_export = G.runner(SPEC, build)
