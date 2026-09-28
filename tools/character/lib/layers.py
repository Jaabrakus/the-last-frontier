"""Layers and envelopes (design §5.2-5.3).

A garment is built against the ENVELOPE of the layer below it (the clearance above the
skin reserved for that band), never around one particular inner garment, so any shirt
fits under any coat. ENVELOPES[group][layer] = (inner min, outer max) in metres above
the skin; None = free (skirt shells, wraps hang free).

    node = layers.envelope_node(ctx.K, "mid", which=1)          # body SDF offset by the mid band's outer clearance
    ok, report = layers.check_envelope(body, V, region_of_vertex, "outer", sdf=ctx.body_sdf())
                                                                # at bind, per region group (lib.pipeline runs it)

Region groups come from lib/regions.py (head, neck, torso_upper, torso_lower, hips,
arms_upper, arms_lower, hands, thighs, shins, feet).
"""

import numpy as np

from .body_shapes import body_groups, body_node
from .catalog import LAYERS
from .regions import REGION_NAMES, region_group
from .sdf import Offset, peval

# group -> {layer name: (inner min clearance, outer max clearance)} (m above the skin)
ENVELOPES = {
    "torso_upper": {"base": (0.0, 0.006), "mid": (0.0055, 0.012), "outer": (0.013, 0.018), "wrap": (0.022, None)},
    "torso_lower": {"base": (0.0, 0.006), "mid": (0.0055, 0.012), "outer": (0.013, 0.018), "wrap": (0.022, None)},
    "hips": {"base": (0.0, 0.003), "mid": (0.0025, 0.011), "legwear": (0.012, 0.019), "outer": (0.013, None),
             "wrap": (0.022, None)},
    "arms_upper": {"base": (0.0, 0.0095), "outer": (0.011, 0.014), "wrap": (0.022, None)},
    "arms_lower": {"base": (0.0, 0.0095), "outer": (0.011, 0.021), "wrap": (0.022, None)},
    "thighs": {"base": (0.0, 0.003), "mid": (0.0025, 0.011), "legwear": (0.012, 0.019), "outer": (0.013, None)},
    "shins": {"base": (0.0, 0.003), "mid": (0.0025, 0.012), "legwear": (0.012, 0.019)},
    "feet": {"base": (0.0, 0.003), "outer": (0.004, 0.008)},
    "neck": {"base": (0.0, 0.006), "outer": (0.018, None), "wrap": (0.025, None)},
    "head": {"hair": (0.0, None), "head": (0.004, None)},
    "hands": {"base": (0.0, 0.004), "outer": (0.005, None)},
}
LAYER_OF_VALUE = {v: k for k, v in LAYERS.items()}


def clearance(group, layer, which=0):
    v = ENVELOPES.get(group, {}).get(layer)
    return None if v is None else v[which]


def envelope_node(K, layer, P=None, which=0, default=0.0):
    """Body SDF offset by the layer's clearance (inner min when which=0, outer max when
    which=1), per region group of the nearest body part (approximated from the body group
    labels and the heights of the region borders)."""
    groups = body_groups(K, P) if P is not None else body_groups(K)
    body = body_node(groups)
    labels = list(groups)
    def cl(g):
        c = clearance(g, layer, which)
        return default if c is None else c

    def off(X, Y, Z):
        shape = np.broadcast(X, Y, Z).shape
        Pt = np.stack(np.broadcast_arrays(X, Y, Z), -1).reshape(-1, 3)
        D = np.stack([peval(groups[g], Pt) for g in labels], 1)
        lab = np.array(labels)[np.argmin(D, 1)]
        z = Pt[:, 2]
        r = np.full(len(Pt), default)
        r[lab == "head"] = cl("head")
        r[lab == "neck"] = cl("neck")
        t = lab == "torso"
        r[t & (z > 1.03)] = cl("torso_upper")
        r[t & (z <= 1.03) & (z > 0.93)] = cl("torso_lower")
        r[t & (z <= 0.93)] = cl("hips")
        a = np.char.startswith(lab, "arm")
        r[a & (z > 1.07)] = cl("arms_upper")
        r[a & (z <= 1.07)] = cl("arms_lower")
        r[np.char.startswith(lab, "hand")] = cl("hands")
        g = np.char.startswith(lab, "leg")
        r[g & (z > 0.44)] = cl("thighs")
        r[g & (z <= 0.44)] = cl("shins")
        r[np.char.startswith(lab, "foot")] = cl("feet")
        return r.reshape(shape)
    rmax = max((v[which] or 0.0) for g in ENVELOPES.values() for k, v in g.items() if k == layer) if any(
        layer in g for g in ENVELOPES.values()) else default
    return Offset(body, off, r_max=max(rmax, default))


def check_envelope(body, V, freg_of_vertex, layer, sdf=None, tol=0.0015):
    """Clearance check at bind of garment vertices V against the skin: returns
    (ok, {group: {min, max, below, above, n}}). `body` = BodyData, `freg_of_vertex` =
    body region id of the nearest body triangle of each vertex, `sdf` = body SDF node
    (signed distance to the skin; defaults to the nearest-point distance)."""
    d = peval(sdf, V) if sdf is not None else None
    rep, ok = {}, True
    groups = np.array([region_group(REGION_NAMES[int(r)]) for r in freg_of_vertex], dtype=object)
    for g in sorted(set(groups)):
        m = groups == g
        lo, hi = clearance(g, layer, 0), clearance(g, layer, 1)
        dd = d[m] if d is not None else None
        if dd is None:
            continue
        below = int((dd < (lo or 0.0) - tol).sum()) if lo is not None else 0
        above = int((dd > hi + tol).sum()) if hi is not None else 0
        rep[g] = {"n": int(m.sum()), "min": round(float(dd.min()), 4), "max": round(float(dd.max()), 4),
                  "below_inner": below, "above_outer": above, "band": [lo, hi]}
        ok = ok and below == 0
    return ok, rep
