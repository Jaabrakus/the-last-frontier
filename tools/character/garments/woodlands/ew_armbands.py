"""Silver arm bands (costume bible §3.2, §3.3, §3.8 `ew_armbands`).

Silver arm bands above (and below) the elbow [P1][P2][R2][M11]; women wore arm spangles
"from her shoulder down to her wrist" (Heckewelder, 1788 [R1]). A pair above the elbows,
wide enough to sit over a shirt sleeve. Grade A.

Each band is rigid on the upper arm's two-thirds twist helper (shoulder_twist_d), which is
what the arm under it follows at that height (lib.weights UA_KNOTS).
"""

import numpy as np

from lib.body_shapes import arm_shapes

from garments.woodlands import _common as C
from garments.woodlands import _silver as S
from lib.sdf import Offset

SPEC = C.spec(
    id="ew_armbands", name="Silver arm bands", slot="accessories.arms", layer={"default": 85},
    description="A pair of broad silver bands worn on the upper arms above the elbows, over the shirt sleeves or "
                "on the bare arm.",
    history="Silver arm bands above and below the elbow were widely worn (Smith [P1], Heckewelder [P2], Jones "
            "[R2]; Six Nations silverwork [M11]).",
    zones=[C.WZone(0, "metal", "MET", S.SILVER, "silver", name="bands")],
    evidence="A", sources=["P1", "P2", "R2", "M11"], budget=1000, tags=["men", "women"],
)


def build(ctx):
    K = ctx.K
    b = C.Builder(SPEC)
    for s, sd in ((1, "l"), (-1, "r")):
        node = Offset(arm_shapes(K, s), 0.0098)
        S.band_piece(b, "band_" + sd, node, K.side("shoulder", s), K.side("elbow", s), 0.60, 0.70)
    bt = b.build()
    ob, V = bt.ob, bt.V
    uv = C.loop_uvs(ob, [], np.full(len(ob.data.polygons), -1, int), vertex_uv=bt.attrs["uv"],
                    vertex_uwrap=bt.attrs["uwrap"])
    W = C.rigid_W(ctx, len(V), "l_shoulder_twist_d")
    W = C.set_rigid(ctx, W, bt.vmask("band_r"), "r_shoulder_twist_d")
    return C.finish(ctx, SPEC, bt, W, uv, hide_candidates=[], focus=((0.0, 0.0, 1.15), 0.75))
