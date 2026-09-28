"""Black felt cocked hat (tricorn), costume bible §4.5 `tricorn`: the legacy hat of
actor_b_body.glb (elliptical crown, round brim cocked up on three sides, a black ribbon
cockade with a button), now with its binding tape as a colour zone (worsted tape, none =
felt colour, or an officer's gold lace).

Bible: "The cocked hat was of black wool felt (beaver felt for the better-off), sometimes
bound with worsted tape" [R21]. Grade A. Worn over the hair: it hides the hair's crown zone.
"""

import math

import numpy as np

from lib.sdf import v3

from garments.militia import _hats as H
from garments.militia import _militia as M

SPEC = M.spec(
    id="tricorn", name="Cocked hat (tricorn)", slot="head", layer={"default": 80},
    zones=[M.MZone(0, "cloth", "WOOL", ["logwood_black", "walnut_brown", "slate_grey"], "logwood_black", name="felt"),
           M.MZone(1, "trim", "WOOL", ["logwood_black", "linen_white", "white_facing", "gold_lace", "silver_lace"],
                   "logwood_black", name="binding"),
           M.MZone(2, "ribbon", "FLAT", ["logwood_black", "ribbon_black", "ribbon_white", "ribbon_red"],
                   "ribbon_black", name="cockade"),
           M.MZone(3, "button", "MET", ["brass", "pewter", "silver"], "brass", name="button")],
    description="Black wool felt hat with the brim turned up on three sides, a ribbon cockade and an optional "
                "binding tape along the brim edge.",
    history="The everyday hat of the colonies: black wool felt, beaver felt for the better-off, often bound with "
            "worsted tape. Felt reads as WOOL with a low normal strength.",
    sources=["R21", "M3", "M1"], budget=1600, hides_hair_zones=["crown"], tags=["frontier", "regulars"],
    extra={"felt": {"normal_strength": 0.2, "roughness_add": 0.1}})


def build(ctx):
    hb = ctx.K["headb"]
    mats = M.zone_mats(SPEC)
    center = hb + v3(*H.HAT_CENTER)
    # the legacy brim: a round brim of radius 0.176 (beyond the crown ellipse), cocked up
    # along three chords 0.104 from the centre at 78 degrees
    bw = lambda th: 0.176 - math.hypot(0.079 * math.cos(th), 0.101 * math.sin(th))
    bm, pc, pn = H.felt_hat(center, H.HAT_TILT, crown_a=0.079, crown_b=0.101, crown_h=0.060, brim_w=bw,
                            folds=(0.104, 78.0), segs=36, rings=5, thick=0.0045)
    H.add_cockade(bm, pc, pn)
    ob = H.to_object(bm, SPEC.id, mats)
    M.set_sharp_hat(ob)
    zones = M.zones_of(ob)
    W = M.rigid_bone(ctx, np.zeros((len(ob.data.vertices), len(ctx.bones))), np.ones(len(ob.data.vertices), bool),
                     "headb")
    uv = H.hat_uvs(ob, center, M)
    return M.finish(ctx, SPEC, ob, zones, W, uv, hide_candidates=[])
