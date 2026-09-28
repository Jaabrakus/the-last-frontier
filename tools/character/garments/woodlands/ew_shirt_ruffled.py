"""Linen shirt, ruffled (costume bible §3.2, §3.8 `ew_shirt_linen`, the dress version).

A ruffled shirt was the dress version: James Smith was given "a new ruffled shirt" at his
adoption in 1755 [P1]; Heckewelder: "plain or ruffled shirts" [P2]. Grade A.
"""

from garments.woodlands import _common as C
from garments.woodlands import _shirts

SPEC = C.spec(
    id="ew_shirt_ruffled", name="Linen shirt, ruffled", slot="shirt", layer={"default": 10, "hips": 35, "thighs": 35},
    description="The dress linen shirt: full sleeves with ruffles at the wrists and a ruffle down each side of the "
                "front opening, worn loose with the tails hanging to mid-thigh.",
    history="The dress version of the shirt: Smith was given a new ruffled shirt at his adoption in 1755 [P1]; "
            "plain or ruffled shirts were ordinary dress (Heckewelder [P2]). Often worn with silver brooches.",
    zones=[C.WZone(0, "cloth", "LIN", ["linen_white", "linen_unbleached", "tow"], name="linen",
                   pattern={"options": ["none", "check"],
                                                           "check": {"colors": ["check_blue", "linen_white"],
                                                                     "scale_m": 0.012}}),
           C.WZone(1, "trim", "LIN", ["linen_white", "linen_unbleached", "tow"], name="collar and wrist bands"),
           C.WZone(2, "trim", "LIN", ["linen_white", "linen_unbleached"], name="ruffles")],
    evidence="A", sources=["P1", "P2"], budget=5600, tags=["men"],
    extra={"edge_uv": {"x": "distance from the hem, the wrist band's end or the ruffle's free edge, metres",
                       "y": "distance from the front slit, metres"}},
)


def build(ctx):
    return _shirts.build_shirt(ctx, SPEC, hem=0.62, slit_top=0.72, ruffled=True)
