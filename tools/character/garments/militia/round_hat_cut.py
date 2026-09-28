"""Cut-down round hat of the 1758 campaign, costume bible §4.5 `round_hat_cut`: a felt hat
with a flat brim of 2.5 inches (6.35 cm) all round and a ribbon band.

Bible: on 4 July 1758 Abercromby's whole army, provincials included, cut its hats down into
round hats with 2½-inch brims; a Connecticut private noted "This day I cut my hat" [M1][M3].
Grade A (1758). The crown is the tricorn's; hides the hair's crown zone.
"""

import numpy as np

from lib.sdf import v3

from garments.militia import _hats as H
from garments.militia import _militia as M

SPEC = M.spec(
    id="round_hat_cut", name="Round hat, cut down (1758)", slot="head", layer={"default": 80},
    zones=[M.MZone(0, "cloth", "WOOL", ["logwood_black", "walnut_brown", "drab", "slate_grey"], "logwood_black",
                   name="felt"),
           M.MZone(1, "ribbon", "FLAT", ["logwood_black", "ribbon_black", "leather_brown", "ribbon_red", "linen_white"],
                   "ribbon_black", name="band")],
    description="Felt hat with the brim cut down to about two and a half inches all round, with a plain band.",
    history="In July 1758 Abercromby's army, provincials included, cut its cocked hats down into round hats with "
            "2½-inch brims for the woods (Fort Ticonderoga, 1758 campaign).",
    sources=["M1", "M3"], budget=1400, hides_hair_zones=["crown"], tags=["frontier", "regulars"],
    extra={"felt": {"normal_strength": 0.2, "roughness_add": 0.1}})


def build(ctx):
    hb = ctx.K["headb"]
    mats = M.zone_mats(SPEC)
    center = hb + v3(0.0, -0.026, 0.101)
    bm, _, _ = H.felt_hat(center, -4.0, crown_a=0.079, crown_b=0.101, crown_h=0.066, brim_w=0.0635,
                          folds=None, segs=36, rings=4, thick=0.004, tape_rings=0, band_h=0.016, droop=0.007)
    ob = H.to_object(bm, SPEC.id, mats)
    M.set_sharp_hat(ob)
    zones = M.zones_of(ob)
    n = len(ob.data.vertices)
    W = M.rigid_bone(ctx, np.zeros((n, len(ctx.bones))), np.ones(n, bool), "headb")
    uv = H.hat_uvs(ob, center, M)
    return M.finish(ctx, SPEC, ob, zones, W, uv, hide_candidates=[])
