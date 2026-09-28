"""Silver wrist bands (costume bible §3.2, §3.8 `ew_wristbands`).

Silver wrist bands [P1][P2][R2][M11]. A pair over the lower forearm, just above the shirt's
wrist band. Grade A.

Each band is rigid on the forearm's last twist helper (forarm_twist_c: 90 % of the wrist's
roll), what the forearm under it follows at that height (lib.weights FA_KNOTS).
"""

import numpy as np

from lib.body_shapes import arm_shapes
from lib.sdf import Offset

from garments.woodlands import _common as C
from garments.woodlands import _silver as S

SPEC = C.spec(
    id="ew_wristbands", name="Silver wrist bands", slot="accessories.arms", layer={"default": 85},
    description="A pair of silver bands worn on the lower forearms, above the wrists.",
    history="Silver wrist bands were part of the trade silver worn by men and women (Smith [P1], Heckewelder [P2], "
            "Jones [R2]; [M11]).",
    zones=[C.WZone(0, "metal", "MET", S.SILVER, "silver", name="bands")],
    evidence="A", sources=["P1", "P2", "R2", "M11"], budget=1000, tags=["men", "women"],
    extra={"combine": {"with": ["ew_armbands"], "note": "may be worn together with the arm bands (both "
                                                        "accessories.arms)"}},
)


def build(ctx):
    K = ctx.K
    b = C.Builder(SPEC)
    for s, sd in ((1, "l"), (-1, "r")):
        node = Offset(arm_shapes(K, s), 0.0104)
        S.band_piece(b, "band_" + sd, node, K.side("elbow", s), K.side("wrist", s), 0.79, 0.86)
    bt = b.build()
    ob, V = bt.ob, bt.V
    uv = C.loop_uvs(ob, [], np.full(len(ob.data.polygons), -1, int), vertex_uv=bt.attrs["uv"],
                    vertex_uwrap=bt.attrs["uwrap"])
    W = C.rigid_W(ctx, len(V), "l_forarm_twist_c")
    W = C.set_rigid(ctx, W, bt.vmask("band_r"), "r_forarm_twist_c")
    return C.finish(ctx, SPEC, bt, W, uv, hide_candidates=[], focus=((0.0, 0.0, 0.98), 0.85))
