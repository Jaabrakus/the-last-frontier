"""The woman's linen shift (cloth2 recipe): the undergarment every woman wore, knee-length, with elbow sleeves."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="shift_linen", name="Linen shift", set="colonial", slot="shirt", layer={"default": 10, "hips": 25, "thighs": 25},
    description="A knee-length linen shift with elbow-length sleeves and a wide low neckline, slit at the sides.",
    history="A linen shift was the woman's shirt: worn next to the skin, day and night, knee-length with sleeves to the "
            "elbow and a neckline that showed above the stays and the gown [M2][P1].",
    zones=[Zone(0, "linen", "cloth", "LIN", ["linen_white", "linen_unbleached", "tow"], "linen_white"),
           Zone(1, "neckline and sleeve bands", "trim", "LIN", ["linen_white", "linen_unbleached", "tow"], "linen_white")],
    sources=["M2", "P1"], evidence="B", tags=["women", "colonial"], budget=4400)


def build(g):
    recipes.shirt(g, hem=0.44, side_hem=0.52, sleeve_end=0.55, neck=dict(a=0.098, b=0.080, z0=1.315), dip=0.03, dip_width=0.10, gather=0.006,
                  sleeve_ease=(0.006, 0.011), steps=10, flare=0.05, slit_top=0.60, tail_gap=0.008, z_full=0.50)


build_and_export = G.runner(SPEC, build)
