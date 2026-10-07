"""The Mountain Folk brow band (cloth2 recipe type head_wrap, band: cloth2.dress.HEAD_BAND): one flat roll of madder
cloth round the brow, the crown bare for the topknot, the two ends hanging behind."""

import numpy as np

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import hats as HT
from cloth2 import recipes
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="tv_mf_brow_band", name="Brow band", set="tv_highland", slot="head", layer={"default": 80},
    description="A flat roll of madder cloth round the brow, the ends hanging behind.",
    history="Design note: a strip of the sash's red at the brow, under the knot and the feathers (the hunter's sheet "
            "binds the hair with cord; the band is the everyday form).",
    zones=[Zone(0, "band", "cloth", "WOOL", TV.HIGHLAND, "tv_madder")],
    sources=[], evidence="C", tags=["men", "women", "tv_highland", "mountain_folk", "everyday"], budget=1500,
    extra=TV.extra({0: "weave"}, presets={"madder": {"0": "tv_madder"}, "indigo": {"0": "tv_indigo_black"},
                                          "hemp": {"0": "tv_hemp"}},
                   note="cloth2.dress.head_wrap band: one roll r 1.6 cm flattened to 0.42 at z 1.545 (tilt 2.6 cm), "
                        "rigid on headb; two ends (hats.tube, flattened) 0.16 m down the back of the head."))

STYLE = dress._style(dress.HEAD_BAND, {"rolls": dict(dress.HEAD_BAND["rolls"], r=0.015, flat=0.5, z0=1.528,
                                                     tilt=0.026, ease=0.013)})
ENDS = [(-0.022, 0.16), (0.018, 0.13)]


def build(g, st=STYLE):
    recipes.head_wrap(g, st)
    fits = g.fits
    hb = HT.headb(fits)
    z0 = st["rolls"]["z0"] + st["rolls"]["tilt"]
    for dx, ln in ENDS:
        k = np.linspace(0.0, 1.0, 9)
        back = hb[1] + 0.085
        path = np.stack([np.full(9, dx) + k * dx * 0.6, back + 0.012 + 0.03 * k, z0 - 0.005 - ln * k], 1)
        g.add(HT.tube(fits, g.m, path, np.full(9, 0.009), segs=6, zone=0, part=0))


build_and_export = G.runner(SPEC, build)
