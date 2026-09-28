"""Winter mittens of smoked hide, fur on the back of the hand and a deep fur cuff over the wrist,
with a separate trigger finger.

Costume bible §2.2 / §2.6: mittens of knit wool or sewn wool cloth are documented for the
rangers [M2] (`mittens_wool`, grade A); in cold weather they were carried in the belted bosom
of the frock [P3]. Hide mittens with fur backs and cuffs fit the northern winter dress of the
Canadians and the Native nations [M7] but are not specifically cited here: grade B. The
separate index finger is a game choice: the hand keeps its hold on the trigger and the index
finger does not poke through the mitten when it straightens.

Geometry per hand: the body's hand shape (lib.body_shapes: palm, finger mass, thumb) with the
middle, ring and little fingers joined in one pocket, the index finger and the thumb apart,
offset 5.5 mm, as a hollow shell open at the top of a flared gauntlet cuff 7.5 cm up the
forearm. Weights: the body's (nearest point); the pocket's finger weights all go to the middle
finger's chain, so the pocket bends as one piece. Surfaces: main (zone 0 hide SUEDE, 1 the fur
base), fur (shells over the cuff and the back of the hand; guard hairs).
"""

import numpy as np

from garments.frontier import _frontier_common as FC
from lib.body_shapes import FINGERS, THUMB, BodyParams, hand_frame
from lib.catalog import GarmentSpec, Zone
from lib.pipeline import Surface, garment_body_weights
from lib.remesh import material, mesh_arrays
from lib.sdf import Ellipsoid, Fn, Inter, Offset, Onion, RoundBox, RoundCone, Union, frame_from, lerp, nrm, peval, v3
from lib.weights import limit_normalize, mesh_adjacency, smooth_weights

FURS = ["fur_beaver", "fur_red_fox", "fur_raccoon", "fur_wolf", "fur_black_bear"]

SPEC = GarmentSpec(
    id="mittens_fur", name="Mittens, hide with fur backs", slot="accessories.hands", set="frontier",
    description=("Winter mittens of smoked hide with the fur left on the back of the hand and a deep fur cuff turned "
                 "over the wrist; a separate trigger finger."),
    layer={"default": 40}, weights="body",
    zones=[Zone(0, "leather", "SUEDE", ["buckskin_smoked", "leather_brown", "buckskin_pale"], "buckskin_smoked",
                name="hide"),
           Zone(1, "fur", "FUR", FURS, "fur_beaver", name="fur")],
    surfaces={"main": "mittens_fur", "fur": "mittens_fur_fur"},
    hides_regions=["wrist_l", "hand_l", "wrist_r", "hand_r"],
    evidence="B",
    history=("Knit or cloth mittens are documented for the rangers, carried in the bosom of the frock in cold "
             "weather; hide mittens with fur backs and cuffs fit Canadian and Native winter dress but are not "
             "specifically cited. The trigger finger is a game choice."),
    sources=["M2", "P3", "M7"], budget={"tris_max": 12000},
    tags=["winter", "fur", "men", "women"],
    extra={"fur": FC.fur_block("mittens_fur_fur", FURS, strap_envelope=None, length_scale=0.9)},
)
SPEC.extra["fur"]["palette_zone"] = 1
SPEC.extra["deform_limits"] = FC.deform_limits(SPEC)

FUR = FC.FurParams(shells=10, base_tris=700, nominal=0.03, cards=260, card_len=0.035, card_w=0.004,
                   edge_taper=(0.0, 0.01, 0.6))
OFF = 0.0055             # the mitten over the skin
SHELL = 0.0022           # hide thickness
CUFF_UP = 0.075          # the gauntlet reaches this far up the forearm from the wrist
CUFF_R = (0.037, 0.047)  # its radius at the wrist and at the top
POCKET = {"ring": "middle", "pinky": "middle"}
POCKET_BONES = {"ring_metacarpal": "middle_metacarpal", "ringa": "middlea", "ringb": "middleb", "ringc": "middlec",
                "pinkya": "middle_metacarpal", "pinkyb": "middlea", "pinkyc": "middleb", "pinkyd": "middlec"}


def hand_solid(K, s, P=BodyParams()):
    """The hand with the middle, ring and little fingers in one pocket (lib.body_shapes.hand_shapes
    with the index finger apart)."""
    W = K.side("wrist", s)
    u, v, w = hand_frame(K, s)
    knuck = [K.side(ch[1], s) for _, ch in FINGERS]
    L = np.linalg.norm(np.mean(knuck, 0) - W)
    R = np.stack([u, v, w], 1)
    palm = RoundBox(W + u * (0.52 * L) + w * 0.002, (0.52 * L, 0.035 * P.hand_w, 0.0125 * P.hand_t), 0.011 * P.hand_t, R)
    fr = P.finger_r
    radii = {"index": (0.0088, 0.008, 0.0074), "middle": (0.009, 0.0082, 0.0076),
             "ring": (0.0086, 0.0079, 0.0073), "pinky": (0.0078, 0.0072, 0.0066)}
    tips = {"index": 0.019, "middle": 0.020, "ring": 0.019, "pinky": 0.016}
    pocket, index = [], []
    for name, ch in FINGERS:
        a, b, c = [K.side(n, s) for n in ch[1:]]
        tip = c + nrm(c - b) * tips[name]
        r0, r1, r2 = [r * fr for r in radii[name]]
        segs = [RoundCone(a, b, r0, r1), RoundCone(b, c, r1, r2), RoundCone(c, tip, r2, r2 * 0.92)]
        (index if name == "index" else pocket).extend(segs)
    ta, tb, tc = [K.side(n, s) for n in THUMB]
    ttip = tc + nrm(tc - tb) * 0.021
    thumb = Union([Ellipsoid(lerp(ta, tb, 0.45) + w * 0.004, (0.016 * fr, 0.013 * fr, 0.024), frame_from(tb - ta, w)),
                   RoundCone(ta, tb, 0.0125 * fr, 0.0105 * fr), RoundCone(tb, tc, 0.0105 * fr, 0.0092 * fr),
                   RoundCone(tc, ttip, 0.0092 * fr, 0.0082 * fr)], k=0.008)
    return Union([Union([palm, Union(pocket, k=0.03)], k=0.012), Union(index, k=0.002), thumb], k=0.006)


def cuff_axis(K, s):
    W, E = K.side("wrist", s), K.side("elbow", s)
    return W, nrm(E - W)


def mitten_node(K, s):
    W, up = cuff_axis(K, s)
    hand = Offset(hand_solid(K, s), OFF)
    cuff = RoundCone(W - up * 0.012, W + up * CUFF_UP, CUFF_R[0], CUFF_R[1])
    solid = Union([hand, cuff], k=0.012)
    top = W + up * CUFF_UP
    cut = Fn(lambda X, Y, Z, top=top, up=up: (X - top[0]) * up[0] + (Y - top[1]) * up[1] + (Z - top[2]) * up[2],
             W - 0.25, W + 0.25)
    return Inter(Onion(solid, SHELL * 0.5), cut, k=0.0), solid


def build(ctx):
    K = ctx.K
    body = ctx.body()
    body_sdf = ctx.body_sdf()
    nodes = [mitten_node(K, s) for s in (1, -1)]
    node = Union([nodes[0][0], nodes[1][0]], k=0.0)
    ob = FC.sdf_obj("mittens_fur", node, 0.0012, 3200, material("mit_tmp", "#a07e55"), feature_deg=40.0, iters=20,
                    sharp_deg=None)
    FC.log("  mittens: %d polygons inside the body deleted" % FC.delete_inside(ctx, ob))
    V = mesh_arrays(ob)
    C, N, _ = FC.poly_arrays(ob)
    # weights: nearest body point; the pocket follows the middle finger
    W = garment_body_weights(ctx, ob)
    bones = list(ctx.bones)
    for sd in "lr":
        for src, dst in POCKET_BONES.items():
            a, b = sd + "_" + src, sd + "_" + dst
            if a in bones and b in bones:
                ia, ib = bones.index(a), bones.index(b)
                W[:, ib] += W[:, ia]
                W[:, ia] = 0.0
    # (4 passes at 0.5 were tried: more triangles collapse in a closing fist, 8.9 % against 5.8 %)
    W = limit_normalize(smooth_weights(W, mesh_adjacency(ob), 1, 0.3))
    # fur: outer faces of the gauntlet cuff and of the back of the hand (not the palm, fingers or thumb)
    fur_poly = np.zeros(len(C), bool)
    along = np.zeros(len(C))
    for s, (nd, solid) in zip((1, -1), nodes):
        side = np.sign(C[:, 0]) == s
        Wr, up = cuff_axis(K, s)
        t = (C - Wr) @ up
        along[side] = t[side]
        u, v, w = hand_frame(K, s)
        outer = (N * FC.sdf_grad(solid, C)).sum(1) > 0.3
        cuff = side & (t > -0.004) & outer
        palm_c = K.side("palm", s)
        back = side & ((N @ (-w)) > 0.35) & ((C - palm_c) @ u < 0.035) & (t < 0.0) & outer
        fur_poly |= cuff | back
    zones = np.where(fur_poly, 1, 0)
    # UVs: around the forearm -> middle finger axis per hand, the seam on the palm side
    parts = []
    for s in (1, -1):
        Wr, up = cuff_axis(K, s)
        u, v, w = hand_frame(K, s)
        parts.append(FC.Cyl(Wr + up * 0.1, K.side("middlec", s), w))

    def uv_fn(o):
        Co, _, _ = FC.poly_arrays(o)
        return FC.part_uvs(o, parts, np.where(Co[:, 0] >= 0, 0, 1))
    top_d = np.zeros(len(V))
    for s in (1, -1):
        Wr, up = cuff_axis(K, s)
        m = np.sign(V[:, 0]) == s
        top_d[m] = np.maximum(CUFF_UP - (V[m] - Wr) @ up, 0.0)
    Tm, _ = FC.triangles(ob)
    fob, fz, fh, fW, fcol, (belt, strap), fstats = FC.fur_surface(
        ctx, "mittens_fur_fur", ob, W, fur_poly, FUR, uv_fn, blockers=[(body.V, body.F), (V, Tm)], strap_paths=())
    FC.log("  fur: %s" % fstats)
    SPEC.extra["fur"]["stats"] = fstats
    SPEC.occupies_regions = ["forearm_c_l", "wrist_l", "hand_l", "forearm_c_r", "wrist_r", "hand_r"]
    return {"main": Surface(ob, zones=zones, weights=W, uv=uv_fn, edge=(top_d, top_d)),
            "fur": Surface(fob, zones=fz, h=fh, weights=fW, colors=fcol, edge=(belt, strap))}
