"""The Mountain Folk layered hip panels (cloth2 recipe type wrap_skirt, wound layers: cloth2.dress.WRAP_SKIRT, plus
tv_dress.hip_panels): a short indigo-black cloth wound round the hips in three stepped layers to above the knee, and
two woven madder panels hanging over it at the front and the left side with hand-cut ragged hems. Worn over the
trousers and the vest or robe, under the sash."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import tv_dress as TVD
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_mf_trousers", "tv_mf_wrap_vest", "tv_mf_short_robe"]

SPEC = Spec(
    id="tv_mf_hip_panels", name="Layered hip panels", set="tv_highland", slot="accessories.wrap",
    layer={"default": 50},
    description="An indigo-black cloth wound three times round the hips to above the knee, each layer stepping out, "
                "and two woven madder panels hanging over it at the front and the left with ragged hems.",
    history="Design note: the layered hip line of the hunter's sheet and the lineup (cloth over cloth, a woven panel "
            "in front). It gives the Mountain Folk silhouette its stepped hips under a narrow red waist; the panels "
            "carry the band weave in large (band_motif).",
    zones=[Zone(0, "wound cloth", "cloth", "LIN", TV.HIGHLAND, "tv_indigo_black"),
           Zone(1, "woven panels", "band", "LIN", TV.HIGHLAND, "tv_madder")],
    sources=[], evidence="C", tags=["men", "women", "tv_highland", "mountain_folk", "everyday"], budget=7000,
    over=UNDER,
    extra=TV.extra({0: "weave", 1: "weave"}, {1: TV.BAND}, presets=TV.clan_presets(),
                   note="cloth2.dress.wrap_skirt from 1.035, hem 0.60, rims at 0.92 and 0.80 (3 wound layers, each "
                        "step 5 mm), the overlap's edge at -30 deg; tv_dress.hip_panels: a longer wrap (hem 0.40) "
                        "clipped to -22..22 deg (hem 0.43) and 56..102 deg (hem 0.47), ragged 3.5 cm, 6 mm over it.",
           layers_variant={"A": "3 layers (rims 0.92, 0.80)", "B": "2 layers (rim 0.86)", "C": "4 layers"}))

STYLE = dress._style(dress.WRAP_SKIRT, {"hem": 0.60, "flare": 0.07, "folds": 0.010, "tail_gap": 0.030, "ease": 0.024,
                                        "rims": [(0.92, 0.005), (0.80, 0.005)], "over": tuple(UNDER),
                                        "over_gap": 0.006})
PANELS = {"panels": [{"from": -22.0, "to": 22.0, "hem": 0.43}, {"from": 56.0, "to": 102.0, "hem": 0.47}],
          "ragged": 0.035, "skirt": {"hem": 0.40, "flare": 0.09, "folds": 0.010}, "gap": 0.006, "zone": 1}


def build(g, st=STYLE, panels=PANELS):
    recipes.wrap_skirt(g, st)
    if panels:
        TVD.hip_panels(g, st, panels)


build_and_export = G.runner(SPEC, build)
