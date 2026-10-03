"""The hunting cap (cloth2: a close cap over the head by hats.head_grid with a stiff peak, cloth2.settlers.peak): the
rangers' jockey cap of brown cloth, a round crown to the brow with a band, a short leather peak over the eyes and a
button on top. Rigid on the head; it hides the hair's crown zone."""

import numpy as np

from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import hats as HT
from cloth2 import recipes
from cloth2 import settlers as ST
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="hunting_cap", name="Hunting cap (jockey cap)", set="colonial", slot="head", layer={"default": 80},
    description="A close round cap of brown cloth with a band and a short stiff peak over the eyes, a button on top.",
    history="By 1759 the rangers' best headwear was the brown cloth hunting cap or jockey's cap; a 1759 deserter "
            "notice describes a ranger's hat cut into the form of a jockey cap [S5]. Hunting caps were in supply for "
            "the ranger companies from the spring of 1758 [S5][S18].",
    zones=[Zone(0, "cap", "cloth", "WOOL", ["walnut_brown", "snuff", "ranger_green", "logwood_black", "drab"],
                "walnut_brown"),
           Zone(1, "band and peak", "leather", "LEA", ["leather_black", "leather_brown", "walnut_brown"],
                "leather_black"),
           Zone(2, "button", "button", "MET", ["brass", "pewter", "logwood_black"], "logwood_black")],
    hides_hair_zones=["crown"], sources=["S5", "S18"], evidence="B", tags=["colonial", "rangers"], budget=1400,
    extra={"references": ["https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Siege-of-Carillon-Rogers-Rangers-Guidelines.pdf",
                          "https://www.military-history.org/feature/warrior-rogers-rangers.htm"]})

STYLE = {"edge": (64.0, 80.0, 88.0), "ease": 0.0105, "band": {"width": 0.028, "h": 0.003, "front_deg": 181.0},
         "tail": None, "caul": 0.0, "frill": None}


def build(g):
    recipes.soft_cap(g, "monmouth", STYLE)
    ST.peak(g, front_deg=58.0, width=0.058, droop=0.30, zone=1)
    top = HT.headb(g.fits) + np.array([0.0, -0.03, 0.30])
    hit, ok = HW.ray_points(g.m, [top], [0.0, 0.0, -1.0], 0.3)
    if ok[0]:
        g.hardware(hit[:1], HW.button(0.008, 0.004, segs=8), 2, up=(0.0, -1.0, 0.0))
    c = HT.headb(g.fits)
    g.uvparts = {0: ("cyl", c, c + np.array([0.0, 0.0, 0.2]), [0, -1, 0])}
    g.m.fa["part"][:] = 0
    g.shape_alias = {"sex_head": "m"}


build_and_export = G.runner(SPEC, build)
