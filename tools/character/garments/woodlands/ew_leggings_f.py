"""Knee-high wool leggings, silk and bead edge (costume bible §3.3, §3.8 `ew_leggings_f`).

Knee-high or mid-calf, blue or red fine cloth, the edge bound in silk and beads [R1][P4];
Mary Jemison's were blue broadcloth "from the knees, into the mouth of the moccasins" [P4];
Heckewelder describes leggings decorated like the skirt [P2]. Grade A.
"""

from garments.woodlands import _common as C
from garments.woodlands import _legs

RIBBONS = ["ribbon_red", "ribbon_green", "ribbon_yellow", "ribbon_blue", "ribbon_white", "ribbon_black", "bead_white"]

SPEC = C.spec(
    id="ew_leggings_f", name="Wool leggings, knee-high", slot="legs.over", layer={"default": 30},
    description="Knee-high leggings of fine wool broadcloth with a narrow side flap, the edges bound in silk ribbon "
                "and white beads, gartered below the knee.",
    history="Knee-high or mid-calf, of blue or red fine cloth, the edge bound in silk and beads (Zeisberger, "
            "Loskiel [R1]); Jemison's reached from the knees into the mouth of the moccasins [P4].",
    zones=[C.WZone(0, "cloth", "WOOL", ["stroud_blue", "stroud_red", "logwood_black"], name="cloth",
                   bands={"axis": "y", "from": "top edge", "rows_max": 2, "row_width": 0.006, "gap": 0.003,
                          "palette": RIBBONS, "default": ["ribbon_red"]}),
           C.WZone(1, "trim", "WOOL", ["stroud_blue", "stroud_red", "logwood_black"], name="flap",
                   bands={"axis": "y", "from": "flap edge", "rows_max": 2, "row_width": 0.005, "gap": 0.002,
                          "palette": RIBBONS, "default": ["ribbon_yellow", "bead_white"]}),
           C.WZone(2, "band", "KNIT", ["madder_red", "stroud_blue", "logwood_black"], name="garters",
                   pattern={"type": "beads", "colors": ["bead_white"], "note": "white beads woven in"})],
    evidence="A", sources=["R1", "P4", "P2"], budget=2200, tags=["women"],
    extra={"edge_uv": {"x": "distance from the lower hem (tube) or the flap's lower end, metres",
                       "y": "distance from the top edge (tube) or the flap's free edge (flap), metres"}},
)


def build(ctx):
    return _legs.build_leggings(ctx, SPEC, women=True)
