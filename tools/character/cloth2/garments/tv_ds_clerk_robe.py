"""The magistrate's clerk's robe (cloth2 recipe type robe, mode crossed: cloth2.dress.ROBE): a long crossed robe of
court indigo to the shin, narrow sleeves, a pearl-white collar band and cuffs. The clerk of R1 (with tv_ds_clerk_cap,
a ledger and a seal)."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_ds_rolled_trousers"]

SPEC = Spec(
    id="tv_ds_clerk_robe", name="Clerk's robe", set="tv_delta", slot="vest", layer={"default": 36},
    description="A long crossed robe of court indigo to the shin, narrow sleeves, a pearl-white collar band and cuffs.",
    history="Design note: the clerk is a column of indigo with one white line at the collar: the court's colour "
            "without its gold (Vạn Thủy court banners).",
    zones=[Zone(0, "court cloth", "cloth", "LIN", TV.DELTA, "tv_deep_navy"),
           Zone(1, "collar and cuffs", "band", "LIN", TV.DELTA, "tv_pearl"),
           Zone(2, "unused", "metal", "MET", TV.METALS, "tv_gold"),
           Zone(3, "ties", "ribbon", "FLAT", TV.DELTA, "tv_pearl")],
    sources=[], evidence="C", tags=["men", "women", "tv_delta", "dragon_sea", "npc", "floodgate_clerk"], budget=9000,
    over=UNDER,
    extra=TV.extra({0: "weave", 1: "weave", 2: "metal", 3: "cord"},
                   note="cloth2.dress.robe mode crossed, hem 0.25, sleeves to 0.93 with cuffs from 0.84, a 3.6 cm "
                        "collar band (zone 1), side slits to 0.70."))

STYLE = recipes.style(dress.ROBE, mode="crossed", hem=(0.25, 0.25, 0.25), flare=0.12, folds=0.007, steps=12,
                      sleeve_end=0.93, sleeve_ease=(0.003, 0.012), over=tuple(UNDER), over_gap=0.007, over_relax=1,
                      skirt_gap=0.045, slits=[(84.0, 96.0, 0.70)], cuffs={"t0": 0.84, "h": 0.003},
                      collar_band={"w": 0.036, "h": 0.0035}, ties=[(-50.0, 1.05), (-50.0, 0.98)])


def build(g, st=STYLE):
    recipes.robe(g, st)


build_and_export = G.runner(SPEC, build)
