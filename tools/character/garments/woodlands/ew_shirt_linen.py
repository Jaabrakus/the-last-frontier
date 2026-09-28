"""Linen shirt, worn loose (costume bible §3.2, §3.8 `ew_shirt_linen`).

Linen, white or checked; worn loose over the breechcloth and could be left off in fighting
or hunting [R3]; Heckewelder calls blankets, "plain or ruffled shirts and leggings" the
ordinary dress [P2]. Grade A.
"""

from garments.woodlands import _common as C
from garments.woodlands import _shirts

PATTERNS = {"options": ["none", "check"],
            "check": {"colors": ["check_blue", "linen_white"], "scale_m": 0.012, "note": "blue-and-white check linen"}}

SPEC = C.spec(
    id="ew_shirt_linen", name="Linen shirt, worn loose", slot="shirt", layer={"default": 10, "hips": 35, "thighs": 35},
    description="A plain linen shirt with full sleeves gathered at the wrist and a small collar band, worn loose over "
                "the breechcloth with the tails hanging to mid-thigh.",
    history="White or checked linen, worn loose over the breechcloth and left off in fighting or hunting [R3]; "
            "blankets, plain or ruffled shirts and leggings were the ordinary dress (Heckewelder [P2]).",
    zones=[C.WZone(0, "cloth", "LIN", ["linen_white", "linen_unbleached", "tow"], name="linen", pattern=PATTERNS),
           C.WZone(1, "trim", "LIN", ["linen_white", "linen_unbleached", "tow"], name="collar and wrist bands")],
    evidence="A", sources=["R3", "P2", "P1"], budget=4400, tags=["men"], alt_slots=[],
    extra={"edge_uv": {"x": "distance from the hem or the wrist band's end, metres",
                       "y": "distance from the front slit, metres"}},
)


def build(ctx):
    return _shirts.build_shirt(ctx, SPEC, hem=0.62, slit_top=0.72)
