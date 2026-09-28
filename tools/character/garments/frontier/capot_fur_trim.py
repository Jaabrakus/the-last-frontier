"""Blanket coat (capot) with fur trim: the capot_blanket cut with a fur collar and fur cuffs.

Costume bible §2.4 item 2 / §2.6 `capot_fur_trim` (grade B): fur collar, cuffs and hood lining
are consistent with Canadian winter dress [M7], without a specific citation. The capot itself
is grade A for Canada (blanket cloth, hooded, closed with a sash) [M5][M7][R8]; for the
1750s-60s plain white, blue or red blanket cloth, or white duffel with one to three end stripes
[R3] (the Hudson's Bay point blanket dates from 1779 [M7b]).

The geometry is capot_blanket's (same coat, hood and ties); the trim is fur shells and guard
hairs over the collar and the turned cuffs, on the outer faces only (a fur facing down the
front edges was tried: the band's polygon edge read as a zigzag stripe at game distance). Surfaces: main (zone 0 blanket WOOL, 1 ribbon ties, 2 the hide under the fur),
fur (shells and guard hairs; the pile colour is the fur zone's token, catalog "fur" block).
"""

import numpy as np

from garments.frontier import _frontier_common as FC
from garments.frontier import capot_blanket as CAP
from lib.catalog import GarmentSpec, Zone
from lib.pipeline import Surface
from lib.remesh import mesh_arrays
from lib.weights import sleeve_factor

FURS = ["fur_beaver", "fur_red_fox", "fur_raccoon", "fur_wolf", "fur_black_bear"]

SPEC = GarmentSpec(
    id="capot_fur_trim", name="Blanket coat (capot), fur-trimmed", slot="outer", set="frontier",
    description=("Knee-length hooded blanket coat with a fur collar and fur cuffs, tied with ribbons; closed with "
                 "a sash in the Canadian way."),
    layer={"default": 40}, weights="body",
    zones=[Zone(0, "cloth", "WOOL", ["#E3DED0", "stroud_blue", "stroud_red", "madder_red", "grey_white", "drab"],
                "#E3DED0", bands=CAP.BANDS, name="blanket"),
           Zone(1, "ribbon", "FLAT", ["ribbon_red", "ribbon_blue", "ribbon_black", "ribbon_green"], "ribbon_red",
                name="ties"),
           Zone(2, "fur", "FUR", FURS, "fur_beaver", name="fur trim")],
    surfaces={"main": "capot_fur_trim", "fur": "capot_fur_trim_fur"},
    evidence="B",
    history=("A Canadian winter capot of blanket cloth; fur collars, cuffs and hood linings fit the Canadian winter "
             "dress of the period but are not specifically documented. White capots with blue bands are documented "
             "from the 1770s; for the 1750s-60s plain blanket cloth or duffel with end stripes."),
    sources=["M7", "M5", "R8", "R3", "M7b"], budget={"tris_max": 20000},
    tags=["winter", "fur", "men", "women", "canada"],
    extra={"fur": FC.fur_block("capot_fur_trim_fur", FURS), "fabric_options": {"blanket": ["WOOL", "TWILL"]}},
)
SPEC.extra["fur"]["palette_zone"] = 2
SPEC.extra["deform_limits"] = FC.deform_limits(SPEC)

FUR = FC.FurParams(shells=10, base_tris=1100, nominal=0.03, cards=300, card_len=0.04, card_w=0.004,
                   edge_taper=(0.0, 0.012, 0.6))
CUFF_LEN = 0.075        # m of fur up from the sleeve end
COLLAR_Z = 1.245        # the fur collar: above this, round the neck


def build(ctx):
    K = ctx.K
    body = ctx.body()
    res = CAP.build(ctx)
    ms = res["main"]
    main, W, zones, col = ms.ob, ms.weights, np.array(ms.zones), ms.colors
    d_hem, d_open = ms.edge
    for k in ("hides_regions", "occupies_regions", "skirt", "helpers"):
        setattr(SPEC, k, getattr(CAP.SPEC, k))
    body_sdf = ctx.body_sdf()
    cls = FC.coat_face_class(main, K, CAP.P, body=body_sdf)
    V = mesh_arrays(main)
    C, N, _ = FC.poly_arrays(main)
    polys = [list(p.vertices) for p in main.data.polygons]
    ph = np.array([d_hem[p].mean() for p in polys])
    sleeve = sleeve_factor(C, K) > 0.5
    r_neck = np.hypot(C[:, 0], C[:, 1] - K["neck"][1])
    collar = (C[:, 2] > COLLAR_Z) & (r_neck < 0.16) & ~sleeve
    cuff = sleeve & (ph < CUFF_LEN)
    trim = (collar | cuff) & (cls == 0) & (zones == 0)
    zones = np.where(trim, 2, zones)
    FC.log("  trim polygons: collar %d, cuffs %d" % ((collar & trim).sum(), (cuff & trim).sum()))
    Tm, _ = FC.triangles(main)
    straps = [FC.strap_path(K, 1, "env40"), FC.strap_path(K, -1, "env40")]
    uv_fn = FC.coat_uv_fn(K)
    fob, fz, fh, fW, fcol, (belt, strap), fstats = FC.fur_surface(
        ctx, "capot_fur_trim_fur", main, W, trim, FUR, uv_fn,
        blockers=[(body.V, body.F), (V, Tm)], sleeve_fn=lambda Q: sleeve_factor(Q, K) > 0.5, strap_paths=straps)
    FC.log("  fur: %s" % fstats)
    SPEC.extra["fur"]["stats"] = fstats
    main.name = "capot_fur_trim"
    return {"main": Surface(main, zones=zones, weights=W, uv=uv_fn, colors=col, edge=(d_hem, d_open)),
            "fur": Surface(fob, zones=fz, h=fh, weights=fW, colors=fcol, edge=(belt, strap))}
