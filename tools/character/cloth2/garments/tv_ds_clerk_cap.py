"""The clerk's cap (cloth2 rigid_hat profile TALL_CROWN, low: cloth2.dress.lathe_hat): a small flat-topped black cap
over the knot, a lacquer-black band. With tv_ds_clerk_robe."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="tv_ds_clerk_cap", name="Clerk's cap", set="tv_delta", slot="head", layer={"default": 80},
    description="A small flat-topped black cap with a band.",
    history="Design note: a low black cap that keeps the clerk's head small and neat beside the soldiers' cones.",
    zones=[Zone(0, "cap", "cloth", "WOOL", TV.DELTA + ["tv_lacquer_black"], "tv_lacquer_black"),
           Zone(1, "band", "trim", "WOOL", TV.DELTA + ["tv_lacquer_black"], "tv_lacquer_black")],
    hides_hair_zones=["crown"], sources=[], evidence="C", tags=["men", "women", "tv_delta", "npc", "floodgate_clerk"],
    budget=1500,
    extra=TV.extra({0: "felt", 1: "felt"}, note="cloth2.dress.lathe_hat TALL_CROWN h 0.075, taper 0.95, band 2.5 cm."))

STYLE = dress._style(dress.TALL_CROWN, {"h": 0.075, "taper": 0.95, "band": {"h": 0.025, "out": 0.004, "zone": 1},
                                        "lower": 0.020})


def build(g, st=STYLE):
    recipes.lathe_hat(g, st)


build_and_export = G.runner(SPEC, build)
