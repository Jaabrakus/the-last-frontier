"""The ring sashes: a long sash wound twice round the waist over the side's tunic (recipes.sash with turns:
dress.wound_sash), the end hanging at the left front. One per side because each is fitted over its own tunic."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

from ring_garments import _common as C


def make(gid, name, element, under, pal, cloth, fringe, z=(0.95, 1.07), height=0.068, end_len=0.28):
    spec = Spec(
        id=gid, name=name, set=C.SET, slot="accessories.waist", layer={"default": 38},
        description="A long sash wound twice round the waist over the tunic, the end hanging at the left front.",
        history=C.HISTORY,
        zones=[Zone(0, "sash", "cloth", "WOOL", pal, cloth), Zone(3, "fringe", "fringe", "WOOL", pal, fringe)],
        evidence="C", tags=C.tags(element), budget=4500, over=list(under),
        extra={"presets": {element: {"0": cloth, "3": fringe}},
               "recipe_note": "recipes.sash turns 2 (dress.wound_sash) over %s." % ", ".join(under)})
    style = {"turns": 2, "z": z, "height": height, "lift": 0.024, "step": 0.0032, "start": 52.0,
             "end": {"len": end_len, "w": 0.068}, "over": tuple(under), "over_gap": 0.004}

    def build(g):
        recipes.sash(g, style)
    return spec, build, G.runner(spec, build)
