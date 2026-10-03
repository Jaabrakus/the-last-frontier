"""The linen shirt tucked in (cloth2 recipe: recipes.shirt's cut without hanging tails): the same shirt as
shirt_linen, its tails tucked into the breeches, so nothing hangs below a short waistcoat or a sleeved veste worn as
the outer garment (a working man in his shirt-sleeves, a ranger in his veste)."""

from cloth2 import garment as G
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="shirt_tucked", name="Linen shirt, tucked in", set="colonial", slot="shirt", layer={"default": 10},
    description="A linen shirt with full sleeves gathered into wrist bands and a low standing collar, its tails tucked "
                "into the breeches.",
    history="Men and women of every rank wore a linen shirt or shift next to the skin; a man's shirt tails, long enough "
            "to reach the thigh, were tucked into his breeches and served as his drawers. Checked, striped or white "
            "linen for working men and rangers (the Fort Ticonderoga guidelines) [P1][M2][S5].",
    zones=[Zone(0, "linen", "cloth", "LIN", ["linen_white", "linen_unbleached", "tow", "check_blue"], "linen_white",
                pattern={"options": ["none", "check"],
                         "check": {"colors": ["check_blue", "linen_white"], "scale_m": 0.012}}),
           Zone(1, "collar and wrist bands", "trim", "LIN", ["linen_white", "linen_unbleached", "tow"], "linen_white")],
    sources=["P1", "M2", "S5"], evidence="A", tags=["men", "colonial"], budget=4600,
    extra={"wear_note": "Worn with breeches (their waistband, 0.97-1.02 m, covers the shirt's lower edge at 0.905 m).",
           "references": ["https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Siege-of-Carillon-Rogers-Rangers-Guidelines.pdf"]})


def build(g):
    # recipes.shirt without its tails: the body ends at the hips, inside the breeches
    g.shell(G.TORSO + G.ARMS)
    g.neckline().bottom(0.905)
    g.sleeves(end=0.925, ease=(0.006, 0.013), gather=0.008)
    g.seams()
    g.fit(ease=0.0055)
    g.collar_zone(1, 0.035)
    g.zone(1, limb=("arm_l", "arm_r"), t_above=0.88)
    g.hem_below(0.95)
    g.uv()


build_and_export = G.runner(SPEC, build)
