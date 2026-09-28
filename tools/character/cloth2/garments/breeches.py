"""Knee breeches (cloth2 recipe): the men's lower garment of the 1750s-60s, and worn by frontier women who went
into the woods."""

from cloth2 import garment as G
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="breeches", name="Knee breeches", set="colonial", slot="legs.lower", layer={"default": 30},
    description="Knee breeches cut close over the hips and thighs, a waistband above the navel, a button fall in "
                "front and a buttoned band below each knee.",
    history="Breeches of wool, linen, buckskin or leather were the men's lower garment of the 1750s and 60s, cut high "
            "in the waist, close over the hip and gathered at the knee with a buckled or buttoned band [P1][M2].",
    zones=[Zone(0, "cloth", "cloth", "WOOL", ["buff", "drab", "walnut_brown", "stroud_blue", "madder_red", "buckskin_pale"], "drab"),
           Zone(1, "waistband and knee bands", "trim", "WOOL", ["buff", "drab", "walnut_brown", "stroud_blue", "buckskin_pale"], "drab"),
           Zone(2, "buttons", "button", "MET", ["brass", "pewter"], "brass")],
    hides_force=["pelvis_center", "pelvis_side", "abdomen_front", "abdomen_side", "abdomen_back", "thigh_upper_l", "thigh_upper_r"],
    sources=["P1", "M2"], evidence="A", tags=["men", "colonial"], budget=3600)


def build(g):
    g.shell(["abdomen_front", "abdomen_side", "abdomen_back", "pelvis_center", "pelvis_side",
             "thigh_upper_l", "thigh_lower_l", "thigh_upper_r", "thigh_lower_r", "shin_upper_l", "shin_upper_r"])
    g.top(1.02).legs(end=0.52, ease=(0.0125, 0.0125), gather=0.0)
    g.seams(back=True, limbs=())
    g.crotch()
    g.fit(ease=0.0125, gap=0.003)
    g.zone(1, above=0.97)
    g.zone(1, limb=("leg_l", "leg_r"), t_above=0.47)
    g.uv(axis_top=1.05, axis_bottom=0.75, limbs=())


build_and_export = G.runner(SPEC, build)
