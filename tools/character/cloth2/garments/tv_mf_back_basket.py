"""The highland carry basket (cloth2 recipe type carry, tall: cloth2.tv_dress.TALL_BASKET): a tall tapered basket of
woven split cane on two shoulder straps and a bar across the back, its rim and ribs bound in walnut-dark cane. The
porter's load on the Trường Sơn passes; shared hardware (tv_common's cut)."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import tv_dress as TVD
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_mf_wrap_vest", "tv_mf_shoulder_mantle"]

SPEC = Spec(
    id="tv_mf_back_basket", name="Highland carry basket", set="tv_highland", slot="accessories.shoulder",
    layer={"default": 85},
    description="A tall tapered basket of woven split cane carried on two shoulder straps, its rim and ribs bound dark.",
    history="Design note: the porter of the Common Folk lineup carries a basket taller than his back; here 0.55 m, "
            "0.34 m across the mouth, so it reads behind the head from the front and fills the back view.",
    zones=[Zone(0, "woven cane", "cloth", "HES", TV.HIGHLAND + ["tv_straw"], "tv_straw"),
           Zone(1, "rim, ribs and straps", "leather", "LEA", TV.HIGHLAND, "tv_walnut")],
    sources=[], evidence="C", tags=["men", "women", "tv_highland", "tv_common", "mountain_folk", "everyday"],
    budget=2500, over=UNDER,
    extra=TV.extra({0: "straw", 1: "leather"}, presets={"cane": {"0": "tv_straw", "1": "tv_walnut"}},
                   note="cloth2.tv_dress.carry tall: a double-walled lathe 0.55 m high, 0.26 -> 0.34 m across, a "
                        "rolled rim, a foot ring and 4 ribs, 4.5 cm off the back; two 3.5 cm straps over the shoulders "
                        "and a bar across the back it is bound to (rigid on the upper back)."))

STYLE = dict(TVD.TALL_BASKET, over=tuple(UNDER))


def build(g, st=STYLE):
    recipes.carry(g, st)


build_and_export = G.runner(SPEC, build)
