"""The women's jacket (cloth2 recipe: recipes.jacket, a short fitted coat): wool or linen, closed edge to edge with
pins down the front over the stays, a low wide neckline filled by the kerchief, sleeves to just past the elbow with
turned-back cuffs, a short basque flaring over the petticoat and apron."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import settlers as ST
from cloth2.spec import Spec, Zone

PAL = ["indigo_mid", "walnut_brown", "madder_red", "butternut", "drab", "logwood_black", "linen_unbleached",
       "full_green"]

SPEC = Spec(
    id="jacket_womens", name="Jacket (women's)", set="colonial", slot="outer", layer={"default": 40},
    description="A fitted wool or linen jacket pinned edge to edge over the stays, a low wide neckline, sleeves to just "
                "past the elbow with turned-back cuffs, and a short basque over the petticoat.",
    history="With a petticoat, a jacket was the commonest working dress of the 1750s: fitted over the stays, pinned "
            "edge to edge, sleeves to the elbow, in worsted, linen or printed cotton, striped stuffs common (the Fort "
            "Ticonderoga guidelines) [S6]. The loose Pennsylvania German shortgown belongs to the later decades and "
            "is not used for 1757 [S10][S9].",
    zones=[Zone(0, "jacket", "cloth", "WOOL", PAL, "indigo_mid",
                pattern={"options": ["none", "stripes"],
                         "stripes": {"colors": ["madder_red", "linen_unbleached"], "axis": "v", "scale_m": 0.014,
                                     "note": "a striped worsted or linen"}}),
           Zone(1, "cuffs and edges", "trim", "WOOL", PAL, "indigo_mid")],
    sources=["S6", "S10", "S9", "M2"], evidence="B", tags=["women", "colonial", "settlers"], budget=4600,
    over=["shift_linen", "stays_laced", "petticoat", "apron", "kerchief_womens"],
    extra={"presets": {"margaretha": {"0": "indigo_mid", "1": "indigo_mid"},
                       "anna": {"0": "logwood_black", "1": "logwood_black"},
                       "striped": {"0": "linen_unbleached", "1": "madder_red", "pattern": "stripes"}},
           "references": ["https://fortticonderoga.org/wp-content/uploads/2024/06/Zipped-1759-Siege-of-Carillon-French-Women-Guidelines.pdf",
                          "https://marariley.net/jackets/shortgown.htm", "https://marariley.net/jackets/jackets.htm"],
           "male_body_note": "Built for every fit; on a man it is artistic licence."})

STYLE = recipes.style(recipes.JACKET, over=tuple(SPEC.over), sleeve_end=0.505,
                      neck={"a": 0.108, "b": 0.094, "z0": 1.305, "tilt": 17.0},
                      cuffs={"t0": 0.425, "h": 0.0045, "flare": 0.006}, front_buttons=None,
                      opening=[(0.80, 0.06), (0.88, 0.016), (1.0, 0.004), (1.17, 0.004), (1.24, 0.034), (1.30, 0.07),
                               (1.6, 0.12)],
                      hem=(0.875, 0.868, 0.862), flare=0.035, steps=4, skirt_gap=0.024,
                      # (roomier sleeves and less relief under the arm: the shift's full sleeve is under them)
                      sleeve_ease=(0.004, 0.011), armpit_relief={"depth": 0.003, "radius": 0.05},
                      # (2026-10-03) over the stays' cone, not the bust: the front hangs straight from the apex, the
                      # cleavage spanned (the stays under it are flat-fronted too)
                      bust={"fits": ("f", "bl", "bs"), "z_min": 0.90, "bottom_z": 0.92, "reach": 0.07, "gap": 0.012})


def build(g):
    recipes.jacket(g, STYLE)
    # (the basque once more over the apron and petticoat: the recipe fitted it before its opening was cut)
    g.over(SPEC.over, 0.004, where=lambda P: P[:, 2] < 1.06)
    ST.settle_gauge(g)


build_and_export = G.runner(SPEC, build)
