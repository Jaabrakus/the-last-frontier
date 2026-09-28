"""UVs in metres, aligned with the grain (design §8.4): u around the body, v along the
limb or garment axis. Model-space triplanar mapping is not used because Godot skins
before vertex(), so a projection there would swim over the cloth.

    segs = [uv.Segment("torso", a, b, ref, radius), ...]
    part = per-polygon index into segs (or -1 for a planar projection)
    uv.write(ob, "UVMap", uv.segment_uvs(ob, segs, part))

Each Segment maps a polygon cylindrically around the a -> b axis: u = angle * radius,
v = v0 + distance along the axis. `ref` points to where u = 0; the seam (u = +-pi *
radius) is on the opposite side, so pass the direction AWAY from the seam (for sleeves
and legs the outer side: the seam goes to the inseam). Polygons that straddle the
seam are unwrapped so they never span the whole texture. Planar parts use a frame.

The UV layer order is the glTF TEXCOORD order: create "UVMap" (0 -> Godot UV) first,
then "Region" (1 -> UV2), then "Edge" (2 -> CUSTOM0). The exporter writes V as 1 - v.
"""

import math

import numpy as np

from .sdf import nrm


class Segment:
    def __init__(self, name, a, b, ref, radius, v0=0.0):
        self.name = name
        self.a = np.asarray(a, float)
        self.d = nrm(np.asarray(b, float) - self.a)
        r = np.asarray(ref, float)
        r = r - self.d * (r @ self.d)
        self.x = nrm(r)
        self.y = np.cross(self.d, self.x)
        self.radius = float(radius)
        self.v0 = float(v0)

    def map(self, P):
        q = P - self.a
        ang = np.arctan2(q @ self.y, q @ self.x)
        return ang * self.radius, self.v0 + q @ self.d, ang


class Planar:
    """u, v = coordinates in the plane (origin o, axes ex, ey), in metres."""

    def __init__(self, name, o, ex, ey):
        self.name = name
        self.o = np.asarray(o, float)
        self.ex = nrm(ex)
        self.ey = nrm(np.asarray(ey, float) - self.ex * (np.asarray(ey, float) @ self.ex))
        self.radius = 0.0

    def map(self, P):
        q = P - self.o
        return q @ self.ex, q @ self.ey, None


def loop_topology(ob):
    """(vertex index per loop, polygon index per loop)."""
    me = ob.data
    nl = len(me.loops)
    lv = np.empty(nl, int)
    me.loops.foreach_get("vertex_index", lv)
    lp = np.empty(nl, int)
    for p in me.polygons:
        lp[p.loop_start:p.loop_start + p.loop_total] = p.index
    return lv, lp


def segment_uvs(ob, parts, part_of_poly):
    """Per-loop (u, v) for polygons mapped by parts[part_of_poly[p]]."""
    me = ob.data
    V = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", V)
    V = V.reshape(-1, 3)
    lv, lp = loop_topology(ob)
    part_of_poly = np.asarray(part_of_poly, int)
    uv = np.zeros((len(lv), 2))
    pl = part_of_poly[lp]
    for k, seg in enumerate(parts):
        m = pl == k
        if not m.any():
            continue
        u, v, ang = seg.map(V[lv[m]])
        if ang is not None:
            # polygons straddling the seam: lift their negative angles by 2 pi
            idx = np.nonzero(m)[0]
            polys = lp[idx]
            amin = np.full(len(me.polygons), np.inf)
            amax = np.full(len(me.polygons), -np.inf)
            np.minimum.at(amin, polys, ang)
            np.maximum.at(amax, polys, ang)
            wrap = (amax[polys] - amin[polys]) > math.pi
            ang = np.where(wrap & (ang < 0), ang + 2 * math.pi, ang)
            u = ang * seg.radius
        uv[m, 0] = u
        uv[m, 1] = v
    return uv


def write(ob, name, uv):
    me = ob.data
    lay = me.uv_layers.get(name) or me.uv_layers.new(name=name)
    lay.data.foreach_set("uv", np.asarray(uv, np.float32).ravel())
    return lay


def ensure_layers(ob, names=("UVMap", "Region")):
    """Creates the UV layers in glTF TEXCOORD order (existing ones are kept)."""
    me = ob.data
    for n in names:
        if me.uv_layers.get(n) is None:
            me.uv_layers.new(name=n)


def body_parts(K, poly_lab, poly_reg):
    """Segments / planes of the body UVs and the part of each polygon, from the polygon's
    body group label and region name."""
    yc = K["spineb"][1]
    hb = K["headb"]
    parts = [Segment("torso", (0, yc, 0.0), (0, yc, 1.0), (0, -1, 0), 0.13),
             Segment("head", (0, hb[1], 0.0), (0, hb[1], 1.0), (0, -1, 0), 0.08)]
    idx = {}
    for s, sd in ((1, "l"), (-1, "r")):
        S, E, W = K.side("shoulder", s), K.side("elbow", s), K.side("wrist", s)
        H, Kn, A = K.side("upper_leg", s), K.side("knee", s), K.side("ankle", s)
        out = np.array([s, 0.0, 0.0])
        idx["upper_arm_" + sd] = len(parts)
        parts.append(Segment("upper_arm_" + sd, S, E, out, 0.04))
        idx["forearm_" + sd] = len(parts)
        parts.append(Segment("forearm_" + sd, E, W, out, 0.035, v0=np.linalg.norm(E - S)))
        idx["hand_" + sd] = len(parts)
        parts.append(Planar("hand_" + sd, W, K.side("middlea", s) - W, K.side("indexa", s) - K.side("pinkyb", s)))
        idx["thigh_" + sd] = len(parts)
        parts.append(Segment("thigh_" + sd, H, Kn, out, 0.07))
        idx["shin_" + sd] = len(parts)
        parts.append(Segment("shin_" + sd, Kn, A, out, 0.045, v0=np.linalg.norm(Kn - H)))
        idx["foot_" + sd] = len(parts)
        parts.append(Planar("foot_" + sd, A * np.array([1, 1, 0]), (0, -1, 0), (s, 0, 0)))
    part = np.zeros(len(poly_lab), int)
    for i, (lab, reg) in enumerate(zip(poly_lab, poly_reg)):
        if lab == "head" or reg == "neck_upper":
            part[i] = 1
        elif reg.startswith("upper_arm"):
            part[i] = idx["upper_arm_" + reg[-1]]
        elif reg.startswith(("forearm", "wrist")):
            part[i] = idx["forearm_" + reg[-1]]
        elif reg.startswith("hand"):
            part[i] = idx["hand_" + reg[-1]]
        elif reg.startswith("thigh"):
            part[i] = idx["thigh_" + reg[-1]]
        elif reg.startswith(("shin", "ankle")):
            part[i] = idx["shin_" + reg[-1]]
        elif reg.startswith("foot"):
            part[i] = idx["foot_" + reg[-1]]
        else:
            part[i] = 0
    return parts, part
