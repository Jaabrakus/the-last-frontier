"""Center-seam moccasins with two cuff flaps (costume bible §3.2, §3.8 `ew_moccasins_m`).

Soft-soled, one piece, a centre seam up the front that gathers the toe, a heel seam and
ankle cuffs; two separate cuff flaps were said to indicate men's moccasins [M11]. The seam
and the cuffs quilled (orange, black, white) and edged with white beads [M11]. Grade A.
"""

from garments.woodlands import _common as C
from garments.woodlands import _feet

SPEC = C.spec(
    id="ew_moccasins_m", name="Center-seam moccasins, two-flap cuffs", slot="feet", layer={"default": 40},
    description="Soft-soled one-piece moccasins with a puckered centre seam over the toe and two cuff flaps at the "
                "ankle, the seam and cuffs worked with dyed porcupine quills and edged with white beads.",
    history="Center-seam, puckered-toe moccasins with a heel seam; two separate cuff flaps were said to mark men's "
            "moccasins. Quills in orange, black and white; raised beadwork belongs to the 19th century [M11].",
    zones=[C.WZone(0, "leather", "SUEDE", ["buckskin_smoked", "buckskin_pale", "leather_brown", "logwood_black"],
                   name="leather"),
           C.WZone(1, "quill", "FLAT", ["quill_orange", "quill_black", "quill_white", "quill_red", "quill_yellow"],
                   name="seam quills"),
           C.WZone(2, "trim", "SUEDE", ["buckskin_smoked", "stroud_red", "stroud_blue", "logwood_black"],
                   name="cuffs", fabrics=["SUEDE", "WOOL"],
                   bands={"axis": "x", "from": "cuff lower edge", "rows_max": 3, "row_width": 0.004, "gap": 0.002,
                          "palette": ["bead_white", "quill_orange", "quill_black", "quill_white", "quill_red"],
                          "default": ["bead_white", "quill_orange", "quill_black"]})],
    evidence="A", sources=["M11", "P2"], budget=2600, tags=["men"],
    extra={"edge_uv": {"x": "distance from the cuff's lower edge (cuffs) or the opening (upper), metres",
                       "y": "distance from the centre seam, metres (quill band on the vamp)"}},
)


def build(ctx):
    return _feet.build_moccasins(ctx, SPEC, women=False)
