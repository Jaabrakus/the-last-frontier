"""Long linen shirt worn over the skirt (costume bible §3.3, §3.8 `ew_shift_f`).

Linen or calico, long enough to reach nearly to the knee, worn outside the skirt; a fine
white linen shift with a red collar was a mark of rank (Loskiel, 1794); dress shifts were
ruffled and covered with small brooches (Cresswell, 1774) [R1]. Grade A.
"""

from garments.woodlands import _common as C
from garments.woodlands import _shirts

SPEC = C.spec(
    id="ew_shift_f", name="Long linen shirt, worn over the skirt", slot="shirt",
    layer={"default": 10, "hips": 35, "thighs": 35},
    description="A long linen shirt with full sleeves and a collar band, worn outside the wrap skirt and reaching "
                "nearly to the knee; the collar may be red.",
    history="Linen or calico, nearly to the knee and worn outside the skirt; a fine white shift with a red collar "
            "marked rank (Loskiel); dress shifts were ruffled and set with small brooches (Cresswell) [R1].",
    zones=[C.WZone(0, "cloth", "LIN", ["linen_white", "linen_unbleached", "tow"], name="linen",
                   pattern={"options": ["none", "check", "calico_small"],
                            "check": {"colors": ["check_blue", "linen_white"], "scale_m": 0.012},
                            "calico_small": {"colors": ["madder_red", "indigo_mid", "linen_white"], "scale_m": 0.02,
                                             "evidence": "B (1770s)"}}),
           C.WZone(1, "trim", "LIN", ["linen_white", "madder_red", "linen_unbleached"], name="collar and wrist bands")],
    evidence="A", sources=["R1"], budget=5600, tags=["women"],
    extra={"edge_uv": {"x": "distance from the hem or the wrist band's end, metres",
                       "y": "distance from the front slit, metres"}},
)


def build(ctx):
    return _shirts.build_shirt(ctx, SPEC, hem=0.52, slit_top=0.63, extra=0.006, collar_open=0.013,
                               focus=((0.0, 0.0, 0.92), 1.12))
