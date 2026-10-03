"""The linen stock (cloth2 recipe: recipes.neckwear "stock"): a stiffened band of pleated white linen round the
neck, over the shirt's collar (which shows above it), buckled behind."""

from cloth2 import bridge as BR
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="stock_linen", name="Linen stock", set="colonial", slot="accessories.neck", layer={"default": 15},
    description="A stiffened band of pleated linen round the neck over the shirt's collar, fastened behind with a "
                "small buckle.",
    history="The everyday neckwear of the period for gentlemen and soldiers: a pleated linen stock buckled behind, "
            "or a roller or neckerchief [R20][M3]; linen neck stocks or rollers for the British regulars of 1759 "
            "(Fort Ticonderoga's guidelines) [S4].",
    zones=[Zone(0, "stock", "cloth", "LIN", ["linen_white", "logwood_black", "linen_unbleached"], "linen_white"),
           Zone(2, "buckle", "metal", "MET", ["pewter", "brass", "silver"], "pewter")],
    sources=["R20", "M3", "S4"], evidence="A", tags=["men", "colonial", "regulars"], budget=900,
    over=["shirt_linen", "shirt_tucked", "shirt_check"],
    extra={"references": ["https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Siege-of-Carillon-British-Regulars-Guidelines.pdf"]})


SIDE_EASE = 0.006            # more room over the shirt's collar at the sides of the neck (2026-10-03: it came through)


def build(g):
    recipes.neckwear(g, "stock")
    BR.ease_sides(g, SIDE_EASE)
    g.over(SPEC.over, 0.003)


build_and_export = G.runner(SPEC, build)
