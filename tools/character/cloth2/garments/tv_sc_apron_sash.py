"""The Stone Children apron and sash (cloth2: recipes.apron for a leather apron, cloth2.dress.wound_sash over its band,
tv_dress.dangles for the tools): a dust-buff sash wound twice round the waist, a heavy leather apron hanging from under
it to the knee, and from the sash two chisels tied in kiln-red cord and a jade disc pendant with a tassel. One garment
of two parts (one per slot, as the catalog wants)."""

import numpy as np

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import tv_dress as TVD
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_sc_trousers", "tv_sc_work_tunic"]

SPEC = Spec(
    id="tv_sc_apron_sash", name="Apron and sash", set="tv_stone", slot="accessories.waist", layer={"default": 60},
    description="A dust-buff sash wound twice round the waist, a heavy leather apron hanging from it to the knee, two "
                "chisels tied in red cord and a jade disc pendant.",
    history="Design note: the mason's waist on the lineup: a broad band, a hanging leather panel, tools and a jade "
            "pendant at the sash (Thạch Uyên's carved jade). The tools are cosmetic, never a stat.",
    zones=[Zone(0, "sash", "cloth", "LIN", TV.STONE, "tv_dust_buff"),
           Zone(1, "leather apron", "leather", "LEA", TV.STONE, "tv_leather"),
           Zone(2, "jade and iron", "metal", "MET", TV.METALS + ["tv_slate_plate"], "tv_jade"),
           Zone(3, "cords and tassel", "fringe", "HES", TV.STONE, "tv_kiln_brick")],
    sources=[], evidence="C", tags=["men", "women", "tv_stone", "stone_children", "everyday"], budget=5500, over=UNDER,
    extra=TV.extra({0: "weave", 1: "leather", 2: "metal", 3: "cord"},
                   presets={"dust": {"0": "tv_dust_buff", "1": "tv_leather"},
                            "ochre": {"0": "tv_ochre_banner", "1": "tv_leather"}},
                   note="recipes.apron (band 0.955-0.985, hem 0.50, the front 50 deg each way) under "
                        "cloth2.dress.wound_sash (2 turns 6 cm, 0.95-1.05, 1.5 cm proud of the apron's band); "
                        "tv_dress.dangles: two chisels with red cord ties, a jade disc and a kiln-red tassel."))

APRON = {"band": (0.955, 0.985), "ease": 0.026, "hem": 0.50, "edge_angle": 50.0, "flare": 0.05, "folds": 0.006,
         "steps": 8, "z_full": 0.55, "gap": 0.016, "over": tuple(UNDER), "over_gap": 0.006}
STYLE = {"turns": 2, "z": (0.95, 1.05), "height": 0.062, "lift": 0.034, "step": 0.004, "start": -40.0,
         "end": {"len": 0.16, "w": 0.06}, "over": tuple(UNDER), "over_gap": 0.006}
STRINGS = [(-58.0, [("bead", {"r": 0.006}, 3), ("chisel", {"length": 0.14}, 2)]),
           (-72.0, [("bead", {"r": 0.006}, 3), ("chisel", {"length": 0.12, "w": 0.010}, 2)]),
           (55.0, [("bead", {"r": 0.007}, 3), ("jade_disc", {"r": 0.026}, 2), ("tassel", {"length": 0.07}, 3)])]


def build(g, st=STYLE, apron=APRON):
    recipes.apron(g, apron)
    g.m.fa["zone"][:] = 1
    fits = g.fits
    sub = G.Garment(fits, g.spec)
    dress.wound_sash(sub, st)
    fits.clear(sub.m, 0.006, surface=fits.obstacles([g.m]), max_push=0.04)
    sub.m.fa["zone"][sub.m.fa["zone"] == 3] = 0
    g.m = TVD.concat([g.m, sub.m])
    strings = []
    for th, pieces in STRINGS:
        Q = g.around_points(st["z"][0] + 0.006, np.array([th]))
        if len(Q):
            strings.append({"at": Q[0], "pieces": pieces, "gap": 0.003, "sway": th * 0.15})
    if strings:
        TVD.dangles(g, strings, lift=0.009)
    g.uv(axis_top=1.1, axis_bottom=0.4, limbs=())
    dress.arc_uv(g)


build_and_export = G.runner(SPEC, build)
