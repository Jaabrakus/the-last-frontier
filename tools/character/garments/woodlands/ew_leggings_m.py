"""Thigh-high wool leggings with the flap outside (costume bible §3.2, §3.8 `ew_leggings_m`,
`ew_garters`).

Wool stroud, thigh-high, sewn so the flap stands out on the outside of the leg, tied to the
belt and gartered below the knee [M1][P3]; James Smith's (1755) were "done off with ribbons
and beads" [P1]. Blue predominated in the war years [R3]. The finger-woven garters are part
of the item (zone "garters"). Grade A.
"""

from garments.woodlands import _common as C
from garments.woodlands import _legs

RIBBONS = ["ribbon_red", "ribbon_green", "ribbon_yellow", "ribbon_blue", "ribbon_white", "ribbon_black", "bead_white"]

SPEC = C.spec(
    id="ew_leggings_m", name="Wool leggings, ribbon-edged", slot="legs.over", layer={"default": 30},
    description="Thigh-high wool stroud leggings with the seam flap standing out on the outside of the leg, edged "
                "with silk ribbon or white beads, and finger-woven garters tied below the knee.",
    history="Coarse wool, the flaps outside, tied to the belt and gartered below the knee (Knox, 1758 [M1]; "
            "Doddridge [P3]); Smith's were done off with ribbons and beads [P1]. Blue was the most common [R3].",
    zones=[C.WZone(0, "cloth", "WOOL", ["stroud_blue", "stroud_red", "ranger_green", "logwood_black"], name="cloth"),
           C.WZone(1, "trim", "WOOL", ["stroud_blue", "stroud_red", "ranger_green", "logwood_black"], name="flap",
                   bands={"axis": "y", "from": "flap edge", "rows_max": 2, "row_width": 0.006, "gap": 0.003,
                          "palette": RIBBONS, "default": ["ribbon_red", "bead_white"]}),
           C.WZone(2, "band", "KNIT", ["madder_red", "stroud_blue", "logwood_black", "quill_orange"], name="garters",
                   pattern={"type": "beads", "colors": ["bead_white"], "note": "white beads woven in"})],
    evidence="A", sources=["M1", "P1", "P3", "R3"], budget=3000, tags=["men"],
    extra={"edge_uv": {"x": "distance from the lower hem (tube) or the flap's lower end, metres",
                       "y": "distance from the flap's free edge, metres (ribbon / bead edging)"},
           "notes": "The tie from the legging top to the belt is not modelled (it would span the hip joint)."},
)


def build(ctx):
    return _legs.build_leggings(ctx, SPEC, women=False)
