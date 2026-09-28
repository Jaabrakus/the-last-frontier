"""The petticoat (cloth2 recipe): the woman's skirt of the 1750s-60s, tied at the waist, ankle-length."""

from cloth2 import garment as G
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="petticoat", name="Petticoat", set="colonial", slot="legs.lower", layer={"default": 30, "hips": 35, "thighs": 35},
    description="A gathered ankle-length petticoat of wool or linsey, tied on a waistband over the shift and stays.",
    history="The petticoat was the woman's skirt: wool, linsey-woolsey, linen or cotton, tied at the waist by tapes, "
            "full at the hem and ankle-length so the shoes showed; jacket and petticoat was the commonest working dress "
            "[P3][M2].",
    zones=[Zone(0, "cloth", "cloth", "WOOL", ["indigo_mid", "walnut_brown", "madder_red", "drab", "stroud_blue",
                                              "ranger_green", "buff"], "indigo_mid"),
           Zone(1, "waistband", "trim", "LIN", ["linen_white", "linen_unbleached", "tow"], "linen_unbleached")],
    hides_force=["pelvis_center", "pelvis_side", "abdomen_front", "abdomen_side", "abdomen_back"],
    sources=["P3", "M2"], evidence="A", tags=["women", "colonial"], budget=3200)


def build(g):
    g.shell(G.TORSO)
    g.top(1.03).bottom(0.955)
    g.seams(back=True, limbs=())
    g.fit(ease=0.02, gap=0.012)
    g.tails(hem=0.26, side_hem=0.26, flare=0.20, folds=0.022, steps=12, z_full=0.40, x_limit=0.6, gap=0.032)
    g.zone(1, above=1.0)
    g.uv(axis_top=1.05, axis_bottom=0.3, limbs=())


build_and_export = G.runner(SPEC, build)
