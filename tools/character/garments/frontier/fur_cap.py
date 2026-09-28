"""Round fur cap with a turned-up fur band.

Costume bible §2.2 / §2.6 `fur_cap` (grade B, winter): fur caps were for winter only
[R8][R14b]; Canadians wore a red wool tuque or a fur cap [M7]. Colourings: beaver,
raccoon, red fox, black bear (and wolf). It sits over the hair: the hair's crown zone is
hidden (hides_hair_zones), the sides and back show below the band.

Surfaces: main (zone 0 fur base, 1 lining inside the band), fur (shells and guard hairs).
Rigid on the head (headb).
"""

import math

import numpy as np

from garments.frontier import _frontier_common as FC
from lib.catalog import GarmentSpec, Zone
from lib.pipeline import Surface
from lib.remesh import material, mesh_arrays, sdf_object
from lib.sdf import Ellipsoid, Fn, Inter, Offset, RoundCone, Union, nrm, peval, smoothstep, v3

FURS = ["fur_beaver", "fur_raccoon", "fur_red_fox", "fur_black_bear", "fur_wolf", "fur_brown_bear"]

SPEC = GarmentSpec(
    id="fur_cap", name="Fur cap", slot="head", set="frontier",
    description="Round winter cap of fur with a turned-up fur band, worn over the hair.",
    layer={"default": 80}, weights="headb",
    zones=[Zone(0, "fur", "FUR", FURS, "fur_beaver", name="fur"),
           Zone(1, "lining", "WOOL", ["stroud_red", "linen_unbleached", "walnut_brown"], "stroud_red", name="lining")],
    surfaces={"main": "fur_cap", "fur": "fur_cap_fur"},
    hides_hair_zones=["crown"],
    evidence="B",
    history="Fur caps were winter wear on the frontier; Canadian habitants and militia wore a fur cap or a red tuque.",
    sources=["R8", "R14b", "M7"], budget={"tris_max": 7500},
    tags=["winter", "fur", "men", "women"],
    extra={"fur": FC.fur_block("fur_cap_fur", FURS, strap_envelope=None, length_scale=1.7)},
)
SPEC.extra["deform_limits"] = FC.deform_limits(SPEC)

PREVIEW_HEAD = True
FUR = FC.FurParams(shells=12, base_tris=420, nominal=0.04, cards=240, card_len=0.05, card_w=0.0045,
                   edge_taper=(0.0, 0.012, 0.7))
CAP_OFF = 0.026            # over the cranium (clears every hair style's sides and back)
BAND_R = 0.017             # the turned-up band's roll


def rim_z(Y):
    """Lower edge of the cap: above the brows in front, over the tops of the ears at the
    sides, lower at the back (the cap hugs the head below its widest part)."""
    return 1.486 - 0.12 * (Y + 0.005)


def cap_node(K):
    hb = K["headb"]
    c = hb + v3(0, -0.027, 0.061)
    cran = Ellipsoid(c, (0.074, 0.098, 0.092))
    # a round cap: the cranium widened a little toward the band, the top domed
    body = Ellipsoid(c + v3(0, 0.0, -0.012), (0.081, 0.103, 0.100))
    crown = Inter(Union([Offset(cran, CAP_OFF), Offset(body, CAP_OFF - 0.004)], k=0.02),
                  Fn(lambda X, Y, Z: rim_z(Y) - Z, (-0.2, -0.3, 1.40), (0.2, 0.3, 1.70)), k=0.006)
    # turned-up band: a roll along the rim
    pts = []
    for a in np.linspace(0, 2 * math.pi, 33):
        d = v3(math.sin(a), -math.cos(a), 0)
        o = v3(0, c[1], rim_z(c[1] + d[1] * 0.1) + 0.016) + d * 0.3
        p = FC.ray_hit(Offset(cran, CAP_OFF), o, -d, 0.3)
        if p is None:
            p = v3(0, c[1], 1.5) + d * 0.12
        pts.append(p + d * 0.004)
    roll = Union([RoundCone(pts[i], pts[i + 1], BAND_R, BAND_R) for i in range(len(pts) - 1)], k=0.004)
    return Union([crown, roll], k=0.01)


def build(ctx):
    K = ctx.K
    body = ctx.body()
    body_sdf = ctx.body_sdf()
    node = cap_node(K)
    main = FC.sdf_obj("fur_cap", node, 0.0016, 500, material("fcap_tmp", "#5a3b25"),
                      sizing=FC.hidden_sizing(0.0145, 0.035, [body_sdf]), feature_deg=40.0, iters=20)
    FC.log("  fur cap: %d polygons inside the body deleted" % FC.delete_inside(ctx, main))
    C, N, _ = FC.poly_arrays(main)
    hb = K["headb"]
    cc = hb + v3(0, -0.027, 0.061)
    radial = C - cc
    radial /= np.linalg.norm(radial, axis=1, keepdims=True)
    outer = ((N * radial).sum(1) > 0.25) & (N[:, 2] > -0.55)
    zones = np.where(outer, 0, 1)
    W = FC.rigid(ctx.bones, len(main.data.vertices), "headb")
    V = mesh_arrays(main)
    T, _ = FC.triangles(main)
    uv_fn = lambda o: FC.part_uvs(o, [FC.Cyl(cc - v3(0, 0, 0.2), cc + v3(0, 0, 0.2), v3(0, -1, 0))],
                                  np.zeros(len(o.data.polygons), int))
    fob, fz, fh, fW, fcol, (belt, strap), fstats = FC.fur_surface(
        ctx, "fur_cap_fur", main, W, outer, FUR, uv_fn, blockers=[(body.V, body.F)], strap_paths=())
    FC.log("  fur: %s" % fstats)
    SPEC.extra["fur"]["stats"] = fstats
    SPEC.occupies_regions = ["head"]
    return {"main": Surface(main, zones=zones, weights=W, uv=uv_fn),
            "fur": Surface(fob, zones=fz, h=fh, weights=fW, colors=fcol, edge=(belt, strap))}
