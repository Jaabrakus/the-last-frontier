"""The Mountain Folk woven wrap vest (cloth2 recipe type robe, mode crossed, sleeveless: cloth2.dress.ROBE sleeves
None): a short crossed robe without sleeves, the left front over the right, tied at the right side, a woven band along
the collar and the overlapping edge, the skirts to the top of the thigh with side slits. The everyday upper garment of
the high places (the Common Folk lineup's porter): the tattooed arms bare, the band in madder."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_mf_trousers"]

SPEC = Spec(
    id="tv_mf_wrap_vest", name="Woven wrap vest", set="tv_highland", slot="shirt", layer={"default": 20},
    description="A sleeveless wrap vest of indigo-black homespun, the left front crossed over the right and tied at the "
                "side, a woven madder band along the collar and the front edge, skirts to the top of the thigh with "
                "side slits.",
    history="Design note: the porter's vest of the Common Folk lineup and the Trường Sơn pass sheet. Read as one dark "
            "wedge from the shoulders to the hips, so the madder band and the sash carry the colour; the arms stay "
            "bare for the tattoos. The band is our own ridge-and-ladder weave (band_motif), straight cuts only.",
    zones=[Zone(0, "homespun", "cloth", "LIN", TV.HIGHLAND, "tv_indigo_black"),
           Zone(1, "woven band", "band", "LIN", TV.HIGHLAND, "tv_madder"),
           Zone(2, "unused", "metal", "MET", TV.METALS, "tv_bronze"),
           Zone(3, "ties", "ribbon", "HES", TV.HIGHLAND, "tv_hemp")],
    sources=[], evidence="C", tags=["men", "women", "tv_highland", "mountain_folk", "everyday"], budget=6000,
    over=UNDER,
    extra=TV.extra({0: "weave", 1: "weave", 2: "metal", 3: "cord"}, {1: TV.BAND},
                   presets=TV.clan_presets(),
                   note="cloth2.dress.robe mode crossed, sleeves None (round armholes, recipes.coat sleeveless); hem "
                        "0.86 with side slits to 0.95; a 3 cm collar band raised 3 mm along the neck and the "
                        "overlapping edge (zone 1); two ties at -50 deg."))

STYLE = recipes.style(dress.ROBE, mode="crossed", sleeves=None, hem=(0.86, 0.86, 0.865), flare=0.045, folds=0.005,
                      steps=5, over=tuple(UNDER), over_gap=0.006, skirt_gap=0.035, slits=[(80.0, 100.0, 0.95)],
                      collar_band={"w": 0.034, "h": 0.0035},
                      overlap_line=dict(dress.ROBE["overlap_line"], split_below=0.93),
                      ties=[(-50.0, 1.05), (-50.0, 0.98)])


def build(g, st=STYLE):
    recipes.robe(g, st)


build_and_export = G.runner(SPEC, build)
