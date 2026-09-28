"""Procedural 18th-century longbow / woodland self bow, shown braced.

Yew stave (cream sapwood on the flat back, orange-brown heartwood on the
rounded belly), D-section limbs tapering to dark horn nocks, a spiral
leather grip with thread whippings at both ends, an inlaid bone arrow plate
on the left of the handle and a braced linen string with a centre serving,
nocking point, top loop and bottom hitch.

Run headless (factory scene):
  Blender -b --factory-startup --python tools/models/bow.py -- \
      [--out assets/weapons/bow.glb] [--renders DIR] [--blend FILE.blend] \
      [--arrow assets/weapons/arrow.glb]   (only used to preview a nocked arrow)

Conventions (Godot / glTF axes), matching scripts/weapons/weapon_models.gd:
  * origin = centre of the leather-wrapped handle (held in the LEFT hand)
  * forward (arrow flight) = -Z: the flat back of the stave faces -Z, the
    rounded belly and the braced string face the archer at +Z
  * up = +Y: the limbs run along +/-Y, the string lies on x = 0, z = +0.16
  * the arrow passes on the LEFT (-X) side of the handle, just above the
    grip, against the bone arrow plate
  * "Muzzle" empty = arrow-rest point (centre of the arrow shaft where it
    lies on the bow hand against the arrow plate), identity rotation so its
    -Z is the shot direction
  * helper empties: "NockPoint" (arrow nock on the string, level with the
    Muzzle), "StringTop" / "StringBottom" (string ends at the nock loops) for
    a future dynamic string
  * two meshes: "Bow" (stave, horn nocks, grip, arrow plate) and "String",
    one shared material/texture atlas

Blender works Z-up and the glTF exporter maps Blender (x, y, z) to glTF
(x, z, -y), so all geometry is computed in Godot axes and converted by B().
"""

import argparse
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

# --------------------------------------------------------------------------
# Dimensions (metres, Godot axes)
# --------------------------------------------------------------------------
STRING_Z = 0.16          # braced string line (brace height ~14 cm from the grip belly)
S_GROOVE = 0.765         # arc length handle centre -> string groove (nock-to-nock 1.53 m)
S_HORN0 = 0.742          # horn nock starts (stave ends inside it)
S_TIP = 0.790            # horn tip (overall length along the bow ~1.58 m)
GRIP_HALF = 0.049        # leather grip from y = -0.049 to +0.049
ARROW_R = 0.0044         # arrow shaft radius (tools/models/arrow.py)
ARROW_Y = 0.054          # arrow rests on the bow hand just above the grip
N_RING = 16              # stave / horn / grip cross-section vertices
SAP_FRAC = 0.20          # sapwood layer: side height of the D as a fraction of depth

# Stave cross-section along |s|: (s, width X, depth Z, roundness 1=oval .. 0=D).
PROFILE = [
    (0.000, 0.0290, 0.0350, 1.00),
    (0.050, 0.0292, 0.0345, 1.00),
    (0.085, 0.0310, 0.0320, 0.55),
    (0.125, 0.0330, 0.0290, 0.00),
    (0.300, 0.0310, 0.0250, 0.00),
    (0.500, 0.0245, 0.0200, 0.00),
    (0.680, 0.0165, 0.0145, 0.00),
    (0.740, 0.0128, 0.0118, 0.00),
    (0.800, 0.0100, 0.0095, 0.00),
]
# Loft stations of one limb (the grip segment between +/-0.046 is hidden).
STAVE_STATIONS = [0.046, 0.065, 0.085, 0.105, 0.130, 0.170, 0.220, 0.280, 0.340,
                  0.400, 0.460, 0.520, 0.580, 0.630, 0.680, 0.715, S_HORN0]

# Horn nock rings: (s, radius or None, morph from stave section 1 -> round 0).
HORN = [(S_HORN0, None, 1.0), (0.749, 0.0068, 0.5), (0.7565, 0.0064, 0.0),
        (0.7615, 0.0061, 0.0), (0.7630, 0.0050, 0.0), (0.7670, 0.0050, 0.0),
        (0.7685, 0.0060, 0.0), (0.7750, 0.0056, 0.0), (0.7820, 0.0043, 0.0),
        (0.7870, 0.0025, 0.0)]
GROOVE_R = 0.0050
LOOP_R = 0.0015          # minor radius of the string loop sitting in the groove
HITCH_R = 0.0019         # bottom timber hitch is a little fatter

# Leather grip: (y, extra radius over the stave, material) along the handle.
GRIP = [(-0.0490, 0.0004, "thread"), (-0.0478, 0.0027, "thread"), (-0.0430, 0.0027, "thread"),
        (-0.0418, 0.0021, "leather"), (0.0418, 0.0021, "thread"), (0.0430, 0.0027, "thread"),
        (0.0478, 0.0027, "thread"), (0.0490, 0.0004, None)]
# Material of each segment = the tag of its first ring.

# String: radii and serving.
R_STRING = 0.00125
R_SERVING = 0.0017
R_NOCKPT = 0.0023
SERVING = (-0.072, 0.105)
NOCKPT = (ARROW_Y + ARROW_R + 0.001, ARROW_Y + ARROW_R + 0.008)

# Arrow plate (bone inlay) on the -X side above the grip.
PLATE_Y = (0.0505, 0.0745)
PLATE_HALF_Z = 0.0072
PLATE_PROUD = 0.0008

# --------------------------------------------------------------------------
# Texture atlas layout (UV, v up). Blocks fill the image; rects are inset.
# --------------------------------------------------------------------------
ATLAS_W, ATLAS_H = 1024, 256
ROUGH_W, ROUGH_H = 256, 64
BLOCKS = {                 # (u0, u1, v0, v1) of each material block
    "heart": (0.00, 1.00, 0.50, 1.00),
    "sap": (0.00, 1.00, 0.30, 0.50),
    "leather": (0.00, 0.40, 0.00, 0.30),
    "thread": (0.40, 0.50, 0.00, 0.30),
    "linen": (0.50, 0.75, 0.00, 0.15),
    "serving": (0.50, 0.75, 0.15, 0.30),
    "horn": (0.75, 0.90, 0.00, 0.30),
    "bone": (0.90, 1.00, 0.00, 0.30),
}
ROUGHNESS = {"heart": 0.42, "sap": 0.46, "leather": 0.62, "thread": 0.72, "linen": 0.80,
             "serving": 0.58, "horn": 0.26, "bone": 0.34}
UV_MARGIN = 0.02           # 1-2 roughness-map texels


def rect(name):
    u0, u1, v0, v1 = BLOCKS[name]
    mu, mv = UV_MARGIN * 0.5, UV_MARGIN
    return (u0 + mu, u1 - mu, v0 + mv, v1 - mv)


def in_rect(name, fu, fv):
    u0, u1, v0, v1 = rect(name)
    return (u0 + (u1 - u0) * fu, v0 + (v1 - v0) * fv)


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
def B(p):
    """Godot-space Vector -> Blender-space Vector."""
    return Vector((p.x, -p.z, p.y))


def GV(x, y, z):
    return Vector((x, y, z))


X_AXIS = GV(1.0, 0.0, 0.0)


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def profile(s):
    a = abs(s)
    cols = list(zip(*PROFILE))
    return tuple(float(np.interp(a, cols[0], c)) for c in cols[1:])


# --------------------------------------------------------------------------
# Braced centre line: curvature profile scaled so the string loop at the
# groove lands exactly on z = STRING_Z.
# --------------------------------------------------------------------------
DS = 0.0005
CS = np.arange(0.0, 0.8 + DS, DS)


def _kappa_shape(s):
    if s < 0.055:
        return 0.0                      # stiff handle
    if s < 0.16:
        return smoothstep(0.055, 0.16, s)
    if s < 0.50:
        return 1.0
    if s < S_GROOVE:
        return lerp(1.0, 0.6, (s - 0.5) / (S_GROOVE - 0.5))
    return 0.25                         # horn


KSHAPE = np.array([_kappa_shape(s) for s in CS])


def integrate(k):
    kap = k * KSHAPE
    phi = np.concatenate([[0.0], np.cumsum(0.5 * (kap[1:] + kap[:-1]) * DS)])
    c, sn = np.cos(phi), np.sin(phi)
    y = np.concatenate([[0.0], np.cumsum(0.5 * (c[1:] + c[:-1]) * DS)])
    z = np.concatenate([[0.0], np.cumsum(0.5 * (sn[1:] + sn[:-1]) * DS)])
    return phi, y, z


class Curve:
    def __init__(self):
        lo, hi = 0.0, 4.0
        for _ in range(60):
            k = 0.5 * (lo + hi)
            self.phi, self.y, self.z = integrate(k)
            if self.loop_point(1.0).z < STRING_Z:
                lo = k
            else:
                hi = k
        self.k = k

    def frame(self, s):
        """Centre C, outward tangent T and belly normal N at signed arc length s."""
        a = abs(s)
        sg = 1.0 if s >= 0.0 else -1.0
        phi = float(np.interp(a, CS, self.phi))
        c = GV(0.0, sg * float(np.interp(a, CS, self.y)), float(np.interp(a, CS, self.z)))
        t = GV(0.0, sg * math.cos(phi), math.sin(phi))
        n = GV(0.0, -sg * math.sin(phi), math.cos(phi))
        return c, t, n

    def loop_point(self, sg):
        """Belly-side centre of the string loop wire at the nock groove."""
        c, _, n = self.frame(sg * S_GROOVE)
        return c + n * (GROOVE_R + LOOP_R)


def section_uv(theta, w, t, rnd):
    """Cross-section point (u along X, v along the belly normal) at angle theta.
    theta 0 = +X side, pi/2 = belly (toward the string), 3pi/2 = back."""
    c, sn = math.cos(theta), math.sin(theta)
    sh = SAP_FRAC * t
    if sn >= 0.0:                      # rounded belly
        du = 0.5 * w * c
        dv = sh + (t - sh) * sn
    else:                              # flat back, rounded corners (superellipse)
        du = 0.5 * w * math.copysign(abs(c) ** 0.5, c)
        dv = sh * (1.0 - abs(sn) ** 0.5)
    dv -= 0.5 * t
    ou, ov = 0.5 * w * c, 0.5 * t * sn  # oval handle
    return lerp(du, ou, rnd), lerp(dv, ov, rnd)


def ring_theta(j):
    return 2.0 * math.pi * j / N_RING


def stave_ring(curve, s, scale=1.0, extra=0.0):
    w, t, rnd = profile(s)
    c, _, n = curve.frame(s)
    pts = []
    for j in range(N_RING):
        u, v = section_uv(ring_theta(j), w + 2.0 * extra, t + 2.0 * extra, rnd)
        pts.append(c + X_AXIS * (u * scale) + n * (v * scale))
    return c, pts


def side_x(s, vc):
    """x of the stave surface on the -X side at depth vc (for the arrow plate)."""
    w, t, rnd = profile(s)
    th = np.linspace(0.5 * math.pi, 1.5 * math.pi, 181)
    uv = [section_uv(a, w, t, rnd) for a in th]
    us = np.array([p[0] for p in uv])[::-1]
    vs = np.array([p[1] for p in uv])[::-1]
    return float(np.interp(vc, vs, us))


# --------------------------------------------------------------------------
# Mesh building
# --------------------------------------------------------------------------
class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def v(self, p):
        return self.bm.verts.new(B(p))

    def face(self, verts, uvs, out, smooth=True):
        """Face whose normal points along `out` (Godot-space vector)."""
        n = Vector()
        for i, a in enumerate(verts):
            b = verts[(i + 1) % len(verts)]
            n.x += (a.co.y - b.co.y) * (a.co.z + b.co.z)
            n.y += (a.co.z - b.co.z) * (a.co.x + b.co.x)
            n.z += (a.co.x - b.co.x) * (a.co.y + b.co.y)
        if n.dot(B(out)) < 0.0:
            verts = list(reversed(verts))
            uvs = list(reversed(uvs))
        f = self.bm.faces.new(verts)
        f.smooth = smooth
        for loop, t in zip(f.loops, uvs):
            loop[self.uv].uv = t
        return f

    def loft(self, rings, centers, uvf, smooth=True, closed=True):
        """Tube through rings of points. uvf(i, j, k) = UV of ring i at face j's
        vertex j (k=0) or j+1 (k=1)."""
        n = len(rings[0])
        vr = [[self.v(p) for p in ring] for ring in rings]
        for i in range(len(rings) - 1):
            ctr = (centers[i] + centers[i + 1]) * 0.5
            for j in range(n if closed else n - 1):
                k = (j + 1) % n
                mid = (rings[i][j] + rings[i][k] + rings[i + 1][k] + rings[i + 1][j]) * 0.25
                self.face([vr[i][j], vr[i][k], vr[i + 1][k], vr[i + 1][j]],
                          [uvf(i, j, 0), uvf(i, j, 1), uvf(i + 1, j, 1), uvf(i + 1, j, 0)],
                          mid - ctr, smooth)
        return vr


def build_stave(b, curve):
    """Continuous stave from the lower horn to the upper horn."""
    stations = [-s for s in reversed(STAVE_STATIONS)] + STAVE_STATIONS
    rings, centers = [], []
    for s in stations:
        c, pts = stave_ring(curve, s)
        rings.append(pts)
        centers.append(c)
    half = N_RING // 2

    def uvf(i, j, k):
        fu = (stations[i] + S_TIP) / (2.0 * S_TIP)
        if j < half:                               # belly: heartwood
            return in_rect("heart", fu, (j + k) / half)
        return in_rect("sap", fu, (j + k - half) / half)    # back: sapwood

    return b.loft(rings, centers, uvf)


def build_horn(b, curve, sg, stave_end_verts):
    rings, centers, ss = [], [], []
    for s_abs, r, morph in HORN:
        s = sg * s_abs
        c, _, n = curve.frame(s)
        _, st = stave_ring(curve, s, scale=1.07)
        pts = []
        for j in range(N_RING):
            th = ring_theta(j)
            circ = c + X_AXIS * ((r or 0.0) * math.cos(th)) + n * ((r or 0.0) * math.sin(th))
            pts.append(st[j] if r is None else st[j].lerp(circ, 1.0 - morph))
        rings.append(pts)
        centers.append(c)
        ss.append(s_abs)
    span = S_TIP - S_HORN0

    def uvf(i, j, k):
        return in_rect("horn", (ss[i] - S_HORN0) / span, (j + k) / N_RING)

    vr = b.loft(rings, centers, uvf)
    # Rounded tip.
    ct, tt, _ = curve.frame(sg * S_TIP)
    tip = b.v(ct)
    last = vr[-1]
    for j in range(N_RING):
        k = (j + 1) % N_RING
        mid = (rings[-1][j] + rings[-1][k] + ct) / 3.0
        b.face([last[j], last[k], tip],
               [in_rect("horn", 0.92, j / N_RING), in_rect("horn", 0.92, (j + 1) / N_RING),
                in_rect("horn", 1.0, (j + 0.5) / N_RING)],
               mid - centers[-1] + tt * 0.002)
    # Shoulder where the horn sleeve meets the stave.
    c0, t0, _ = curve.frame(sg * S_HORN0)
    base = vr[0]
    for j in range(N_RING):
        k = (j + 1) % N_RING
        b.face([stave_end_verts[j], stave_end_verts[k], base[k], base[j]],
               [in_rect("horn", 0.0, j / N_RING), in_rect("horn", 0.0, (j + 1) / N_RING),
                in_rect("horn", 0.02, (j + 1) / N_RING), in_rect("horn", 0.02, j / N_RING)],
               -t0, smooth=False)


def build_grip(b, curve):
    rings, centers, ys = [], [], []
    for y, extra, _ in GRIP:
        c, pts = stave_ring(curve, y, extra=extra)
        rings.append(pts)
        centers.append(c)
        ys.append(y)
    thread_len = 0.008

    # Faces built here (not via loft) to pick the material block per segment.
    vr = [[b.v(p) for p in ring] for ring in rings]
    for i in range(len(rings) - 1):
        tag = GRIP[i][2]
        ctr = (centers[i] + centers[i + 1]) * 0.5
        for j in range(N_RING):
            k = (j + 1) % N_RING
            if tag == "leather":
                uva = in_rect("leather", 0.0, j / N_RING)
                uvb = in_rect("leather", 0.0, (j + 1) / N_RING)
                uvc = in_rect("leather", 1.0, (j + 1) / N_RING)
                uvd = in_rect("leather", 1.0, j / N_RING)
            else:
                # Thread whipping: u across the rect proportional to length.
                ua = ((ys[i] + 0.05) % thread_len) / thread_len
                ub = min(1.0, ua + (ys[i + 1] - ys[i]) / thread_len)
                uva = in_rect("thread", ua, j / N_RING)
                uvb = in_rect("thread", ua, (j + 1) / N_RING)
                uvc = in_rect("thread", ub, (j + 1) / N_RING)
                uvd = in_rect("thread", ub, j / N_RING)
            mid = (rings[i][j] + rings[i][k] + rings[i + 1][k] + rings[i + 1][j]) * 0.25
            b.face([vr[i][j], vr[i][k], vr[i + 1][k], vr[i + 1][j]], [uva, uvb, uvc, uvd],
                   mid - ctr)


def build_arrow_plate(b, curve):
    """Thin bone inlay on the left (-X) of the handle, curved to the stave."""
    yc = 0.5 * (PLATE_Y[0] + PLATE_Y[1])
    hy = 0.5 * (PLATE_Y[1] - PLATE_Y[0])
    n = 16
    outline = []
    for i in range(n):
        a = 2.0 * math.pi * i / n
        # Rounded lozenge: a superellipse slightly squarer than an ellipse.
        ca, sa = math.cos(a), math.sin(a)
        outline.append((yc + hy * math.copysign(abs(ca) ** 0.8, ca),
                        PLATE_HALF_Z * math.copysign(abs(sa) ** 0.8, sa)))

    def pt(y, z, off, inset=1.0):
        yy = yc + (y - yc) * inset
        zz = z * inset
        return GV(side_x(yy, zz) - off, yy, zz)

    ring_top = [pt(y, z, PLATE_PROUD, 0.86) for y, z in outline]
    ring_edge = [pt(y, z, PLATE_PROUD * 0.55) for y, z in outline]
    ring_base = [pt(y, z, -0.0015) for y, z in outline]
    center = pt(yc, 0.0, PLATE_PROUD * 1.05)
    vt = [b.v(p) for p in ring_top]
    ve = [b.v(p) for p in ring_edge]
    vb = [b.v(p) for p in ring_base]
    vc = b.v(center)

    def puv(y, z, grow=1.0):
        return in_rect("bone", 0.5 + (y - yc) / (2.2 * hy) * grow, 0.5 + z / (2.2 * PLATE_HALF_Z) * grow)

    out = GV(-1.0, 0.0, 0.0)
    for i in range(n):
        k = (i + 1) % n
        yi, zi = outline[i]
        yk, zk = outline[k]
        b.face([vc, vt[i], vt[k]],
               [puv(yc, 0.0), puv(yi, zi, 0.86), puv(yk, zk, 0.86)], out, smooth=False)
        rad = GV(0.0, 0.5 * (yi + yk) - yc, 0.5 * (zi + zk))
        b.face([vt[i], vt[k], ve[k], ve[i]],
               [puv(yi, zi, 0.86), puv(yk, zk, 0.86), puv(yk, zk), puv(yi, zi)],
               rad.normalized() + out, smooth=True)
        b.face([ve[i], ve[k], vb[k], vb[i]],
               [puv(yi, zi), puv(yk, zk), puv(yk, zk, 1.05), puv(yi, zi, 1.05)],
               rad.normalized(), smooth=True)
    for i in range(n):
        e = b.bm.edges.get((vt[i], vt[(i + 1) % n]))
        if e:
            e.smooth = False


def build_loop(b, curve, sg, minor):
    """String loop / hitch sitting in the nock groove (a torus around the nock)."""
    c, t, n = curve.frame(sg * S_GROOVE)
    major = GROOVE_R + minor
    na, nb = 12, 5
    grid = []
    for ia in range(na):
        a = 2.0 * math.pi * ia / na + 0.5 * math.pi   # ia = 0 at the belly side
        d = X_AXIS * math.cos(a) + n * math.sin(a)
        q = c + d * major
        grid.append([q + (d * math.cos(2.0 * math.pi * ib / nb) + t * math.sin(2.0 * math.pi * ib / nb)) * minor
                     for ib in range(nb)])
    vg = [[b.v(p) for p in row] for row in grid]
    for ia in range(na):
        ja = (ia + 1) % na
        for ib in range(nb):
            jb = (ib + 1) % nb
            mid = (grid[ia][ib] + grid[ja][ib] + grid[ja][jb] + grid[ia][jb]) * 0.25
            qa = c + (X_AXIS * math.cos(2.0 * math.pi * (ia + 0.5) / na + 0.5 * math.pi)
                      + n * math.sin(2.0 * math.pi * (ia + 0.5) / na + 0.5 * math.pi)) * major
            b.face([vg[ia][ib], vg[ja][ib], vg[ja][jb], vg[ia][jb]],
                   [in_rect("linen", ia / na, ib / nb), in_rect("linen", (ia + 1) / na, ib / nb),
                    in_rect("linen", (ia + 1) / na, (ib + 1) / nb), in_rect("linen", ia / na, (ib + 1) / nb)],
                   mid - qa)


def build_string(b, curve):
    top = curve.loop_point(1.0)
    bot = curve.loop_point(-1.0)
    z = 0.5 * (top.z + bot.z)
    y0, y1 = bot.y, top.y
    st = [(y0, R_STRING, "linen"), (SERVING[0] - 0.002, R_STRING, "linen"),
          (SERVING[0], R_SERVING, "serving"), (NOCKPT[0] - 0.001, R_SERVING, "serving"),
          (NOCKPT[0], R_NOCKPT, "serving"), (NOCKPT[1], R_NOCKPT, "serving"),
          (NOCKPT[1] + 0.001, R_SERVING, "serving"), (SERVING[1], R_SERVING, "serving"),
          (SERVING[1] + 0.002, R_STRING, "linen"), (y1, R_STRING, None)]
    sides = 6
    rings, centers = [], []
    for y, r, _ in st:
        c = GV(0.0, y, z)
        centers.append(c)
        rings.append([c + GV(r * math.cos(2 * math.pi * j / sides + math.pi / 6), 0.0,
                             r * math.sin(2 * math.pi * j / sides + math.pi / 6)) for j in range(sides)])
    vr = [[b.v(p) for p in ring] for ring in rings]
    for i in range(len(st) - 1):
        tag = st[i][2]
        ctr = (centers[i] + centers[i + 1]) * 0.5
        if tag == "linen":
            f0 = (st[i][0] - y0) / (y1 - y0)
            f1 = (st[i + 1][0] - y0) / (y1 - y0)
        else:
            f0 = (st[i][0] - SERVING[0]) / (SERVING[1] - SERVING[0])
            f1 = (st[i + 1][0] - SERVING[0]) / (SERVING[1] - SERVING[0])
        for j in range(sides):
            k = (j + 1) % sides
            mid = (rings[i][j] + rings[i][k] + rings[i + 1][k] + rings[i + 1][j]) * 0.25
            b.face([vr[i][j], vr[i][k], vr[i + 1][k], vr[i + 1][j]],
                   [in_rect(tag, f0, j / sides), in_rect(tag, f0, (j + 1) / sides),
                    in_rect(tag, f1, (j + 1) / sides), in_rect(tag, f1, j / sides)],
                   mid - ctr)
    return top, bot, z


# --------------------------------------------------------------------------
# Texture atlas (numpy)
# --------------------------------------------------------------------------
class Noise:
    def __init__(self, seed):
        self.lat = np.random.default_rng(seed).random((256, 256))

    def value(self, x, y):
        xf, yf = np.floor(x), np.floor(y)
        fx, fy = x - xf, y - yf
        xi, yi = xf.astype(np.int64) & 255, yf.astype(np.int64) & 255
        x1, y1 = (xi + 1) & 255, (yi + 1) & 255
        sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        L = self.lat
        top = L[yi, xi] + (L[yi, x1] - L[yi, xi]) * sx
        bot = L[y1, xi] + (L[y1, x1] - L[y1, xi]) * sx
        return top + (bot - top) * sy

    def fbm(self, x, y, octaves=4):
        s, amp, tot = 0.0, 0.5, 0.0
        for o in range(octaves):
            f = 2.0 ** o
            s = s + amp * self.value(x * f + 17.3 * o, y * f + 9.1 * o)
            tot += amp
            amp *= 0.5
        return s / tot


def _sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def _mix(c0, c1, t):
    c0, c1 = np.asarray(c0, float), np.asarray(c1, float)
    return c0 + (c1 - c0) * t[..., None]


def make_atlas():
    W, H = ATLAS_W, ATLAS_H
    u = (np.arange(W) + 0.5) / W
    v = (np.arange(H) + 0.5) / H
    U, V = np.meshgrid(u, v)                      # row 0 = bottom (v small)
    img = np.zeros((H, W, 3))
    nz = [Noise(s) for s in range(10)]
    rng = np.random.default_rng(1760)

    def block(name):
        u0, u1, v0, v1 = BLOCKS[name]
        m = (U >= u0) & (U < u1) & (V >= v0) & (V < v1)
        # Local coords relative to the inset rect (so UV 0..1 maps to it).
        r0, r1, s0, s1 = rect(name)
        return m, (U - r0) / (r1 - r0), (V - s0) / (s1 - s0)

    # Yew heartwood: orange-brown, dark grain lines following the limb, pin knots.
    m, lu, lv = block("heart")
    along = lu * 1.6
    warp = 0.35 * nz[1].fbm(along * 2.5, lv * 1.5) + 0.15 * nz[2].fbm(along * 9.0, lv * 3.0)
    knot_d = np.full(U.shape, 9.0)
    knots = [(rng.uniform(0.1, 1.5), rng.uniform(0.15, 0.85)) for _ in range(11)]
    for ka, kv in knots:
        d = np.sqrt(((along - ka) / 0.005) ** 2 + ((lv - kv) / 0.05) ** 2)
        knot_d = np.minimum(knot_d, d)
    warp = warp + 0.06 * np.exp(-knot_d * 0.5)
    g = lv * 11.0 + warp * 3.0
    band = 0.5 + 0.5 * np.sin(2 * np.pi * g)
    lines = _sstep(0.72, 0.98, band)
    tone = nz[3].fbm(along * 1.2, lv * 0.8)
    streak = nz[4].fbm(along * 30.0, lv * 40.0)
    base = _mix((0.60, 0.31, 0.14), (0.74, 0.43, 0.21), np.clip(tone * 1.2 - 0.1, 0, 1))
    col = base + (np.array([0.40, 0.18, 0.08]) - base) * (lines * 0.55)[..., None]
    col = col * (0.92 + 0.16 * streak)[..., None]
    knot = np.exp(-knot_d ** 2 * 1.2)
    col = col + (np.array([0.22, 0.09, 0.04]) - col) * (knot * 0.9)[..., None]
    img[m] = col[m]

    # Sapwood: cream, faint grain.
    m, lu, lv = block("sap")
    along = lu * 1.6
    warp = 0.3 * nz[5].fbm(along * 2.0, lv * 1.2)
    band = 0.5 + 0.5 * np.sin(2 * np.pi * (lv * 7.0 + warp * 3.0))
    lines = _sstep(0.8, 1.0, band)
    tone = nz[6].fbm(along * 1.5, lv)
    col = _mix((0.82, 0.69, 0.47), (0.89, 0.79, 0.59), tone)
    col = col + (np.array([0.72, 0.58, 0.38]) - col) * (lines * 0.45)[..., None]
    col = col * (0.95 + 0.08 * nz[7].fbm(along * 25.0, lv * 20.0))[..., None]
    img[m] = col[m]

    # Leather: spiral-wrapped strap, darkened by handling.
    m, lu, lv = block("leather")
    p = lu * 5.0 + lv
    fr = p - np.floor(p)
    shade = 0.72 + 0.28 * _sstep(0.0, 0.9, fr)
    groove = 1.0 - 0.55 * (1.0 - _sstep(0.0, 0.06, fr))
    pores = nz[8].fbm(lu * 90.0, lv * 60.0)
    mottle = nz[9].fbm(lu * 6.0, lv * 4.0)
    col = _mix((0.26, 0.15, 0.08), (0.36, 0.22, 0.12), mottle)
    col = col * (shade * groove * (0.88 + 0.24 * pores))[..., None]
    img[m] = col[m]

    # Thread whipping: tight madder-red turns.
    m, lu, lv = block("thread")
    fr = lu * 11.0 + lv * 0.3
    turns = 0.70 + 0.30 * np.sin(np.pi * (fr - np.floor(fr)))
    col = np.array([0.50, 0.13, 0.09]) * (turns * (0.9 + 0.2 * nz[1].fbm(lu * 30, lv * 30)))[..., None]
    img[m] = col[m]

    # Linen string: twisted, off-white.
    m, lu, lv = block("linen")
    tw = 0.86 + 0.14 * np.sin(2 * np.pi * (lu * 30.0 + lv * 2.0))
    col = np.array([0.84, 0.79, 0.67]) * (tw * (0.93 + 0.12 * nz[2].fbm(lu * 40, lv * 8)))[..., None]
    img[m] = col[m]

    # Serving: waxed thread wrapped across the string.
    m, lu, lv = block("serving")
    fr = lu * 80.0
    turns = 0.75 + 0.25 * np.sin(np.pi * (fr - np.floor(fr)))
    col = np.array([0.52, 0.42, 0.28]) * turns[..., None]
    img[m] = col[m]

    # Horn: near-black with amber streaks along the nock.
    m, lu, lv = block("horn")
    st = nz[3].fbm(lu * 2.0, lv * 12.0)
    st = _sstep(0.45, 0.85, st)
    col = _mix((0.10, 0.075, 0.055), (0.46, 0.33, 0.19), st * (0.4 + 0.6 * lu))
    img[m] = col[m]

    # Bone plate: ivory with faint streaks.
    m, lu, lv = block("bone")
    st = nz[4].fbm(lu * 3.0, lv * 18.0)
    col = _mix((0.74, 0.68, 0.54), (0.86, 0.81, 0.69), st)
    img[m] = col[m]

    img = img + rng.uniform(-0.015, 0.015, img.shape[:2])[..., None]
    img = np.clip(img, 0.0, 1.0)
    rgba = np.concatenate([img, np.ones((H, W, 1))], axis=2).astype(np.float32)
    im = bpy.data.images.new("bow_atlas", W, H, alpha=False)
    im.pixels.foreach_set(rgba.ravel())
    im.update()

    # Metallic/roughness map (glTF: G = roughness, B = metallic).
    rw, rh = ROUGH_W, ROUGH_H
    ru = (np.arange(rw) + 0.5) / rw
    rv = (np.arange(rh) + 0.5) / rh
    RU, RV = np.meshgrid(ru, rv)
    rough = np.ones((rh, rw, 4), np.float32)
    for name, (u0, u1, v0, v1) in BLOCKS.items():
        mm = (RU >= u0) & (RU < u1) & (RV >= v0) & (RV < v1)
        rough[mm, 1] = ROUGHNESS[name]
        rough[mm, 2] = 0.0
    rim = bpy.data.images.new("bow_orm", rw, rh, alpha=False)
    rim.colorspace_settings.name = "Non-Color"
    rim.pixels.foreach_set(rough.ravel())
    rim.update()
    return im, rim


def make_material(color_img, rough_img):
    m = bpy.data.materials.new("BowAtlas")
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = color_img
    tex.location = (-500, 250)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    rtex = nt.nodes.new("ShaderNodeTexImage")
    rtex.image = rough_img
    rtex.location = (-700, -100)
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    sep.location = (-400, -100)
    nt.links.new(rtex.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    m.use_backface_culling = True
    return m


def pack(img, png_path=None):
    if png_path:
        img.filepath_raw = png_path
        img.file_format = "PNG"
        img.save()
        img.source = "FILE"
        img.reload()
    img.pack()


# --------------------------------------------------------------------------
# Assembly / export
# --------------------------------------------------------------------------
def to_object(b, name, mat):
    mesh = bpy.data.meshes.new(name)
    b.bm.to_mesh(mesh)
    b.bm.free()
    mesh.validate()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def empty(name, p):
    o = bpy.data.objects.new(name, None)
    o.empty_display_type = "PLAIN_AXES"
    o.empty_display_size = 0.03
    o.location = B(p)
    bpy.context.scene.collection.objects.link(o)
    return o


def build_bow(tex_dir=None):
    curve = Curve()
    b = Builder()
    vr = build_stave(b, curve)
    build_horn(b, curve, 1.0, vr[-1])
    build_horn(b, curve, -1.0, vr[0])
    build_grip(b, curve)
    build_arrow_plate(b, curve)
    build_loop(b, curve, 1.0, LOOP_R)
    build_loop(b, curve, -1.0, HITCH_R)

    bs = Builder()
    top, bot, zs = build_string(bs, curve)

    cimg, rimg = make_atlas()
    pack(cimg, os.path.join(tex_dir, "bow_atlas.png") if tex_dir else None)
    pack(rimg, os.path.join(tex_dir, "bow_orm.png") if tex_dir else None)
    mat = make_material(cimg, rimg)
    bow = to_object(b, "Bow", mat)
    string = to_object(bs, "String", mat)

    mz_x = side_x(ARROW_Y, 0.0) - PLATE_PROUD - ARROW_R
    muzzle_p = GV(mz_x, ARROW_Y, 0.0)
    helpers = [empty("Muzzle", muzzle_p),
               empty("NockPoint", GV(0.0, ARROW_Y, zs)),
               empty("StringTop", top),
               empty("StringBottom", bot)]
    info = {"k": curve.k, "muzzle": muzzle_p, "top": top, "bot": bot,
            "tip": curve.frame(S_TIP)[0], "curve": curve}
    return bow, string, helpers, info


def export_glb(objs, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_texcoords=True, export_normals=True,
        export_materials="EXPORT", export_image_format="AUTO",
        export_cameras=False, export_lights=False, export_extras=False)


# --------------------------------------------------------------------------
# Preview renders
# --------------------------------------------------------------------------
def principled(name, color, roughness=0.8, emission=None):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    return m


def _box(name, center_g, size_g, mat):
    """Box given in Godot axes."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=B(center_g))
    o = bpy.context.active_object
    o.name = name
    o.scale = (size_g.x, size_g.z, size_g.y)
    o.data.materials.append(mat)
    return o


def _text(body, loc_g, size, mat, facing):
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    o = bpy.data.objects.new("txt_" + body, cu)
    o.location = B(loc_g)
    # facing: "-x" (side camera on Godot -X) or "+z" (front camera behind the string).
    o.rotation_euler = (math.radians(90), 0.0, math.radians(-90)) if facing == "-x" else (math.radians(90), 0.0, 0.0)
    o.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(o)
    return o


def _camera(name, loc_b, target_b, ortho=None, lens=50.0):
    cd = bpy.data.cameras.new(name)
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.lens = lens
    cd.clip_start = 0.005
    o = bpy.data.objects.new(name, cd)
    o.location = loc_b
    d = Vector(target_b) - Vector(loc_b)
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(o)
    return o


def _nocked_arrow(path, info):
    """Import the arrow GLB and lay it on the bow: nock on the string at the
    nocking point, shaft over the Muzzle (preview only)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    nock = GV(0.0, ARROW_Y, STRING_Z)
    d = (info["muzzle"] - nock).normalized()
    tip = nock + d * 0.72
    # Arrow GLB: tip at origin, flight along Godot -Z = Blender +Y.
    rot = Vector((0.0, 1.0, 0.0)).rotation_difference(B(d))
    for o in new:
        if o.parent is None:
            o.rotation_mode = "QUATERNION"
            o.rotation_quaternion = rot @ o.rotation_quaternion
            o.location = B(tip)
    return new


def render_previews(out_dir, info, arrow_path=None):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    try:
        sc.eevee.taa_render_samples = 64
    except AttributeError:
        pass
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = False

    world = bpy.data.worlds.new("PreviewWorld")
    try:
        world.use_nodes = True
    except Exception:
        pass
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.62, 0.64, 0.67, 1.0)
    bg.inputs["Strength"].default_value = 0.9
    sc.world = world

    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.2
    sun.angle = math.radians(8)
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(50), math.radians(-30), math.radians(-55))
    sc.collection.objects.link(so)

    white = principled("ScaleWhite", (0.9, 0.9, 0.9))
    black = principled("ScaleBlack", (0.02, 0.02, 0.02))
    red = principled("MarkRed", (0.9, 0.05, 0.03), 0.5, emission=(0.6, 0.0, 0.0))

    # Vertical 10 cm scale bar behind the bow (Godot x=+0.10, z=-0.12).
    helpers = []
    for i in range(-8, 8):
        helpers.append(_box("vbar%d" % i, GV(0.10, (i + 0.5) * 0.1, -0.12), GV(0.012, 0.1, 0.012),
                            black if i % 2 == 0 else white))
    for i in range(-8, 9):
        helpers.append(_text("%+d" % (i * 10) if i else "0", GV(0.10, i * 0.1, -0.19), 0.03, black, "-x"))
        helpers.append(_text("%+d" % (i * 10) if i else "0", GV(0.19, i * 0.1, -0.12), 0.03, black, "+z"))
    helpers.append(_text("Godot Y (cm), 10 cm blocks", GV(0.10, 0.86, -0.12), 0.03, black, "-x"))
    helpers.append(_text("Godot Y (cm), 10 cm blocks", GV(0.10, 0.86, -0.12), 0.03, black, "+z"))
    # Horizontal Godot-Z ruler, 2 cm blocks from z=-0.10 to +0.30, at y=-0.30.
    for i in range(-5, 15):
        helpers.append(_box("zbar%d" % i, GV(0.10, -0.30, (i + 0.5) * 0.02), GV(0.004, 0.008, 0.02),
                            black if i % 2 == 0 else white))
    for zc in (-0.1, 0.0, 0.1, 0.16, 0.2, 0.3):
        helpers.append(_text(("%d" % round(zc * 100)), GV(0.10, -0.33, zc), 0.022, black, "-x"))
    helpers.append(_text("Godot Z (cm)", GV(0.10, -0.37, 0.10), 0.022, black, "-x"))
    # Muzzle marker and shot direction (-Z).
    mz = info["muzzle"]
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.0035, location=B(mz), segments=16, ring_count=8)
    mk = bpy.context.active_object
    mk.data.materials.append(red)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.0012, depth=0.12, location=B(mz + GV(0, 0, -0.06)),
                                        rotation=(math.radians(90), 0, 0))
    ray = bpy.context.active_object
    ray.data.materials.append(red)

    # Floor with 10 cm checkers for perspective views.
    floor_m = bpy.data.materials.new("Floor")
    try:
        floor_m.use_nodes = True
    except Exception:
        pass
    nt = floor_m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    chk = nt.nodes.new("ShaderNodeTexChecker")
    chk.inputs["Scale"].default_value = 40.0      # 4 m plane / 40 = 10 cm squares
    chk.inputs["Color1"].default_value = (0.55, 0.55, 0.55, 1)
    chk.inputs["Color2"].default_value = (0.45, 0.45, 0.45, 1)
    nt.links.new(tc.outputs["Generated"], chk.inputs["Vector"])
    nt.links.new(chk.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    bpy.ops.mesh.primitive_plane_add(size=4.0, location=(0, 0, -0.84))
    floor = bpy.context.active_object
    floor.data.materials.append(floor_m)

    arrow_objs = []
    if arrow_path and os.path.exists(arrow_path):
        arrow_objs = _nocked_arrow(arrow_path, info)

    # (name, camera, resolution, show floor, show rulers, show arrow)
    tip = info["tip"]
    shots = [
        ("bow_side", _camera("cam_side", (-3.0, -0.08, 0.0), (0.0, -0.08, 0.0), ortho=1.86),
         (1000, 1900), False, True, False),
        ("bow_front", _camera("cam_front", (0.0, -3.0, 0.0), (0.0, 0.0, 0.0), ortho=1.86),
         (900, 1900), False, True, False),
        ("bow_3q", _camera("cam_3q", (-1.75, -1.95, 0.55), (0.0, -0.07, -0.02), lens=50),
         (1100, 1600), True, False, False),
        ("bow_3q_back", _camera("cam_3qb", (-1.6, 2.1, 0.35), (0.0, -0.07, -0.02), lens=50),
         (1100, 1600), True, False, False),
        ("bow_grip_detail", _camera("cam_grip", (-0.26, 0.17, 0.11), (-0.012, 0.0, 0.03), lens=50),
         (1600, 1000), False, False, False),
        ("bow_grip_archer", _camera("cam_grip2", (-0.20, -0.32, 0.12), (-0.005, -0.03, 0.035), lens=50),
         (1600, 1000), False, False, False),
        ("bow_grip_arrow", _camera("cam_grip3", (-0.30, -0.12, 0.16), (-0.012, -0.02, 0.04), lens=40),
         (1600, 1000), False, False, True),
        ("bow_nock_detail", _camera("cam_nock", tuple(B(tip + GV(-0.09, 0.04, 0.06))),
                                    tuple(B(tip + GV(0.0, -0.012, 0.0))), lens=50),
         (1400, 1000), False, False, False),
    ]
    for name, cam, (w, h), show_floor, show_rulers, show_arrow in shots:
        floor.hide_render = not show_floor
        for o in helpers:
            o.hide_render = not show_rulers
        for o in arrow_objs:
            o.hide_render = not show_arrow
        if show_arrow and not arrow_objs:
            continue
        sc.camera = cam
        sc.render.resolution_x = w
        sc.render.resolution_y = h
        sc.render.filepath = os.path.join(out_dir, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("RENDERED", sc.render.filepath)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
    project = os.path.abspath(os.path.join(here, "..", ".."))
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(project, "assets", "weapons", "bow.glb"))
    ap.add_argument("--renders", default=None)
    ap.add_argument("--blend", default=None)
    ap.add_argument("--tex-dir", default=None, help="also write the atlas PNGs here")
    ap.add_argument("--arrow", default=os.path.join(project, "assets", "weapons", "arrow.glb"),
                    help="arrow GLB shown nocked in one preview render")
    args = ap.parse_args(argv)

    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    bow, string, helpers, info = build_bow(args.tex_dir)
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in (bow, string)}
    print("BOW TRIS", tris, "TOTAL", sum(tris.values()))
    print("CURVE K %.4f  tip %s  string top %s bottom %s" % (info["k"], tuple(round(c, 4) for c in info["tip"]),
                                                             tuple(round(c, 4) for c in info["top"]),
                                                             tuple(round(c, 4) for c in info["bot"])))
    print("MUZZLE (godot)", tuple(round(c, 4) for c in info["muzzle"]))
    export_glb([bow, string] + helpers, args.out)
    print("EXPORTED", args.out)
    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    if args.renders:
        render_previews(args.renders, info, args.arrow)


if __name__ == "__main__":
    main()
