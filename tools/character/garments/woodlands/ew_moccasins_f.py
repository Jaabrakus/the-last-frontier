"""Center-seam moccasins with a wrap-around cuff and tinkling cones (costume bible §3.3,
§3.8 `ew_moccasins_f`).

Like the men's, but with a single cuff wrapped all the way round [M11]; dress moccasins
carried quills and trinkets, with small bells and brass thimbles at the ankle [P2], here
small tinkling cones hanging from the cuff edge. Grade A.
"""

from garments.woodlands import _common as C
from garments.woodlands import _feet

SPEC = C.spec(
    id="ew_moccasins_f", name="Center-seam moccasins, wrap cuff", slot="feet", layer={"default": 40},
    description="Soft-soled one-piece moccasins with a puckered centre seam and a single cuff wrapped all round the "
                "ankle, quilled and bead-edged, with small metal cones hanging from the cuff.",
    history="Women's center-seam moccasins had one cuff wrapped all the way round [M11]; dress moccasins were covered "
            "with quills and trinkets, with bells and brass thimbles at the ankle [P2].",
    zones=[C.WZone(0, "leather", "SUEDE", ["buckskin_smoked", "buckskin_pale", "leather_brown", "logwood_black"],
                   name="leather"),
           C.WZone(1, "quill", "FLAT", ["quill_orange", "quill_black", "quill_white", "quill_red", "quill_yellow"],
                   name="seam quills"),
           C.WZone(2, "trim", "SUEDE", ["buckskin_smoked", "stroud_red", "stroud_blue", "logwood_black"],
                   name="cuff", fabrics=["SUEDE", "WOOL"],
                   bands={"axis": "x", "from": "cuff lower edge", "rows_max": 3, "row_width": 0.004, "gap": 0.002,
                          "palette": ["bead_white", "quill_orange", "quill_black", "quill_white", "quill_red"],
                          "default": ["bead_white", "quill_white"]}),
           C.WZone(3, "metal", "MET", ["brass", "#B06A3B", "silver"], "brass", name="cones")],
    evidence="A", sources=["M11", "P2", "R1"], budget=3200, tags=["women"],
    extra={"edge_uv": {"x": "distance from the cuff's lower edge (cuff) or the opening (upper), metres",
                       "y": "distance from the centre seam, metres (quill band on the vamp)"},
           "palette_notes": {"#B06A3B": "copper"}},
)


def build(ctx):
    return _feet.build_moccasins(ctx, SPEC, women=True)
