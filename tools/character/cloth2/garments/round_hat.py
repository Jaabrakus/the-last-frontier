"""The round hat (cloth2 recipe: recipes.rigid_hat with a broad-brimmed hats.ROUND_HAT): the farmer's black felt hat,
uncocked, a low round crown and a broad brim drooping a little, a plain band. Rigid on the head; it hides the hair's
crown zone."""

from cloth2 import garment as G
from cloth2 import hats
from cloth2 import recipes
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="round_hat", name="Round hat, broad-brimmed", set="colonial", slot="head", layer={"default": 80},
    description="A black felt hat with a low round crown and a broad uncocked brim, with a plain band.",
    history="Farmers and labourers often wore their felt hats uncocked, the brim left broad against sun and rain; "
            "black wool felt round hats are acceptable for the rangers of 1759 too [S5][S9][M3].",
    zones=[Zone(0, "felt", "cloth", "WOOL", ["logwood_black", "walnut_brown", "slate_grey", "drab"], "logwood_black"),
           Zone(1, "band", "ribbon", "FLAT", ["ribbon_black", "logwood_black", "walnut_brown"], "ribbon_black")],
    hides_hair_zones=["crown"], sources=["S5", "S9", "M3"], evidence="B", tags=["colonial", "settlers"], budget=1500,
    extra={"felt_note": "Felt uses the WOOL kit with a soft nap (ClothMaterials FELT_WORDS: the id has 'hat').",
           "references": ["https://goschenhoppen.org/colonial-clothing/",
                          "https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Siege-of-Carillon-Rogers-Rangers-Guidelines.pdf"]})

STYLE = dict(hats.ROUND_HAT, brim_r=0.168, crown_h=0.080, droop=0.018, band_h=0.018)


def build(g):
    recipes.rigid_hat(g, STYLE)


build_and_export = G.runner(SPEC, build)
