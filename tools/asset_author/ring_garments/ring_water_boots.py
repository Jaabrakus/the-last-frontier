"""The water side's boots (cloth2.feet.SockTube): soft hide boots to mid-calf over the trousers, a deep fur cuff at
the top, a seam band down the front and a sole of thick leather."""

import numpy as np

from cloth2 import garment as G
from cloth2.mesh import REF, BIG_FIELD, smoothstep
from cloth2.spec import Spec, Zone

from ring_garments import _common as C
from ring_garments import _feet as F

UNDER = ["ring_trousers_fitted"]
TOP = 0.34

SPEC = Spec(
    id="ring_water_boots", name="Water side boots", set=C.SET, slot="feet", layer={"default": 40},
    description="Soft hide boots to mid-calf over the trousers with a deep fur cuff, a band down the front and a thick "
                "sole.",
    history=C.HISTORY,
    zones=[Zone(0, "hide", "leather", "SUEDE", ["ring_seal", "ring_navy", "ring_deep", "leather_brown"], "ring_seal"),
           Zone(1, "fur cuff", "fur", "FUR", ["ring_snow_fur", "ring_seal", "drift_frost", "fur_wolf"], "ring_snow_fur"),
           Zone(2, "sole and front band", "leather", "LEA", ["ring_sole", "ring_navy", "ring_ice", "leather_black"],
                "ring_sole")],
    evidence="C", tags=C.tags("water", "winter"), budget=3600, over=UNDER,
    extra={"presets": {"water": {"0": "ring_seal", "1": "ring_snow_fur", "2": "ring_navy"}},
           "recipe_note": "feet.SockTube 7 mm off the skin to 0.34 over the fitted trousers, a raised fur cuff from "
                          "0.285, the sole below 1.6 cm."})


def build(g):
    F.tube(g, TOP, 0.0070, under=UNDER, gap=0.004)
    g.raised(lambda P: (TOP - 0.055) - P[:, 2], 0.009, 1)
    F.sole(g, 2, z=0.016)
    # a band down the front of the shin to the instep
    J = g.fits.J

    def band(P):
        out = np.full(len(P), 1.0)
        for s in ("l", "r"):
            sg = 1.0 if s == "l" else -1.0
            on = (sg * P[:, 0]) > 0.0
            xc = J[s + "_ankle"][0]
            f = np.abs(P[:, 0] - xc) - 0.012 + BIG_FIELD * smoothstep(-0.02, 0.01, P[:, 1] - J[s + "_ankle"][1] + 0.03) + \
                BIG_FIELD * smoothstep(TOP - 0.06, TOP - 0.05, P[:, 2]) + BIG_FIELD * (1.0 - smoothstep(0.03, 0.04, P[:, 2]))
            out[on] = f[on]
        return out
    g.raised(band, 0.0015, 2)
    g.hem = lambda m: m.boundary()[1] & (m.V[REF][:, 2] > TOP - 0.06)
    F.uv(g)


build_and_export = G.runner(SPEC, build)
