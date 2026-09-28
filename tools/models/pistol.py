"""Procedural mid-18th-century flintlock holster pistol (British military
pattern flavour, c. 1740-1760): walnut full stock with a swelling butt, a
9.4 in round barrel with an octagonal breech and girdle, bright lock with a
goose-neck cock at full cock holding a flint, frizzen, frizzen spring and
pan, brass butt cap with long spurs, trigger guard, side plate, nose cap,
thumb plate and ramrod pipes, and a steel ramrod with a trumpet head.

Run headless (factory scene):
  Blender -b --factory-startup --python tools/models/pistol.py -- \
      [--out assets/weapons/pistol.glb] [--renders DIR] [--blend FILE.blend] \
      [--verify] [--texture-png FILE.png]

Conventions (Godot / glTF axes), matching scripts/weapons/weapon_models.gd and
the rotation-only pistol_offset in scripts/player/player.gd:
  * origin = the centre of the grip where the fist closes (the hand prop
    joint); the grip axis passes through it, raked back 38 degrees
  * forward (barrel) = -Z, up = +Y, the lock is on the right (+X)
  * bore axis at y = +0.050; muzzle face at z = -0.310 (same as the
    placeholder); barrel 0.238 m (9.4 in); overall length ~0.39 m (15.5 in)
  * a top-level empty "Muzzle" at (0, 0.050, -0.310), identity rotation
  * a top-level empty "Pan" at the priming pan (0.022, 0.0505, -0.078), where
    the priming flash goes (same role as the musket's "Pan" node)

Blender works Z-up and the glTF exporter maps Blender (x, y, z) to glTF
(x, z, -y), so everything here is written in Godot coordinates and converted
once by to_blender(): Godot (x, y, z) -> Blender (x, -z, y).

Output is one mesh "Pistol" with five materials (walnut with a baked grain
texture, brass, browned barrel iron, bright steel, flint/bore black) plus
the "Muzzle" and "Pan" empties.
"""

import argparse
import json
import math
import os
import struct
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

# --------------------------------------------------------------------------
# Materials
# --------------------------------------------------------------------------
WALNUT, BRASS, BARREL, STEEL, FLINT = range(5)
MAT_NAMES = ["PistolWalnut", "PistolBrass", "PistolBarrel", "PistolSteel", "PistolFlint"]

# --------------------------------------------------------------------------
# Key dimensions (Godot axes, metres)
# --------------------------------------------------------------------------
BORE_Y = 0.050
MUZZLE_Z = -0.310
BREECH_Z = -0.072
BORE_R = 0.0079             # ~.62 in ball
RAMROD_Y = 0.0293

# Grip axis: through the origin, raked back 38 degrees from vertical at the
# hand and sweeping a further 9 degrees back toward the butt.
RAKE = math.radians(38.0)
RAKE_EXTRA = math.radians(9.0)
GRIP_LEN = 0.094
GRIP_D = (math.sin(RAKE), -math.cos(RAKE))       # (z, y) down the grip at the hand

# Lock layout (side view, (z, y)).
COCK_PIVOT = (-0.045, 0.038)
COCK_ANGLE = math.radians(18.0)   # tilt back from the design pose = full cock
FRIZZEN_PIVOT = (-0.0955, 0.0465)


def V(x, y, z):
    return Vector((x, y, z))


def to_blender(p):
    return Vector((p.x, -p.z, p.y))


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def interp(table, x):
    if x <= table[0][0]:
        return table[0][1]
    for (x0, y0), (x1, y1) in zip(table, table[1:]):
        if x <= x1:
            return lerp(y0, y1, (x - x0) / (x1 - x0))
    return table[-1][1]


def zy3(x, zy):
    """(z, y) side-view point + x -> Godot 3D."""
    return V(x, zy[1], zy[0])


# --------------------------------------------------------------------------
# Mesh builder
# --------------------------------------------------------------------------
class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.has_uv = self.bm.faces.layers.int.new("has_uv")
        self.sharp = []

    def v(self, p):
        return self.bm.verts.new(to_blender(p))

    def face(self, verts, mat, out=None, uvs=None):
        if out is not None:
            n = Vector()
            for i, a in enumerate(verts):
                b = verts[(i + 1) % len(verts)]
                n.x += (a.co.y - b.co.y) * (a.co.z + b.co.z)
                n.y += (a.co.z - b.co.z) * (a.co.x + b.co.x)
                n.z += (a.co.x - b.co.x) * (a.co.y + b.co.y)
            if n.dot(to_blender(out)) < 0.0:
                verts = list(reversed(verts))
                if uvs:
                    uvs = list(reversed(uvs))
        try:
            f = self.bm.faces.new(verts)
        except ValueError:
            return None
        f.material_index = mat
        f.smooth = True
        if uvs:
            for loop, t in zip(f.loops, uvs):
                loop[self.uv].uv = t
            f[self.has_uv] = 1
        return f

    def mark_sharp(self, a, b):
        self.sharp.append((a, b))

    # ---- generic primitives ------------------------------------------------
    def extrude_x(self, pts, x0, x1, mat, bevel=0.0005, cap_lo=True, cap_hi=True,
                  bevel_lo=True, bevel_hi=True):
        """Extrude a side-view outline [(z, y)] across x0..x1 with chamfered
        edges. Returns nothing; faces are oriented outward."""
        n = len(pts)
        area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1]
                   for i in range(n))
        sgn = 1.0 if area > 0 else -1.0
        en = []
        for i in range(n):
            a, b = pts[i], pts[(i + 1) % n]
            dz, dy = b[0] - a[0], b[1] - a[1]
            L = math.hypot(dz, dy) or 1e-9
            en.append((sgn * dy / L, -sgn * dz / L))
        vn = []
        for i in range(n):
            n1, n2 = en[i - 1], en[i]
            mz, my = n1[0] + n2[0], n1[1] + n2[1]
            ml = math.hypot(mz, my)
            m = n2 if ml < 1e-9 else (mz / ml, my / ml)
            c = m[0] * n2[0] + m[1] * n2[1]
            s = 1.0 / max(c, 0.4)
            vn.append((m[0] * s, m[1] * s))

        def ring(x, inset):
            return [self.v(V(x, p[1] - d[1] * inset, p[0] - d[0] * inset)) for p, d in zip(pts, vn)]

        rings, xs = [], []
        if bevel_lo and bevel > 0:
            rings += [ring(x0, bevel), ring(x0 + bevel, 0.0)]
            xs += [-1.0, 0.0]
        else:
            rings += [ring(x0, 0.0)]
            xs += [0.0]
        if bevel_hi and bevel > 0:
            rings += [ring(x1 - bevel, 0.0), ring(x1, bevel)]
            xs += [0.0, 1.0]
        else:
            rings += [ring(x1, 0.0)]
            xs += [0.0]
        for k in range(len(rings) - 1):
            xo = xs[k] + xs[k + 1]
            for i in range(n):
                j = (i + 1) % n
                out = V(xo, en[i][1], en[i][0])
                self.face([rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]], mat, out)
        if cap_lo:
            self.face(rings[0], mat, V(-1, 0, 0))
        if cap_hi:
            self.face(rings[-1], mat, V(1, 0, 0))

    def lathe(self, p0, axis, prof, segs, mat, cap_start=False, cap_end=False,
              ref=None, phase=0.0, mats=None):
        """Surface of revolution. prof = [(t, r)] along `axis` from p0.
        r == 0 makes a pole. mats optionally gives a material per segment."""
        axis = axis.normalized()
        ref = ref or (V(0, 1, 0) if abs(axis.y) < 0.9 else V(1, 0, 0))
        e1 = (ref - axis * ref.dot(axis)).normalized()
        e2 = axis.cross(e1)
        rings = []
        for t, r in prof:
            c = p0 + axis * t
            if r < 1e-7:
                rings.append([self.v(c)])
            else:
                ring = []
                for k in range(segs):
                    a = phase + 2 * math.pi * k / segs
                    ring.append(self.v(c + (e1 * math.cos(a) + e2 * math.sin(a)) * r))
                rings.append(ring)
        for i in range(len(rings) - 1):
            m = mats[i] if mats else mat
            ra, rb = rings[i], rings[i + 1]
            ta, tb = prof[i][0], prof[i + 1][0]
            cmid = p0 + axis * ((ta + tb) * 0.5)
            for k in range(segs):
                k2 = (k + 1) % segs
                a = phase + 2 * math.pi * (k + 0.5) / segs
                radial = e1 * math.cos(a) + e2 * math.sin(a)
                # Face direction: radial, tilted by the slope of the profile.
                dr = prof[i + 1][1] - prof[i][1]
                dt = tb - ta
                out = radial * dt - axis * dr if abs(dt) + abs(dr) > 0 else radial
                if len(ra) == 1:
                    self.face([ra[0], rb[k], rb[k2]], m, out)
                elif len(rb) == 1:
                    self.face([ra[k], ra[k2], rb[0]], m, out)
                else:
                    self.face([ra[k], ra[k2], rb[k2], rb[k]], m, out)
        if cap_start and len(rings[0]) > 2:
            self.face(rings[0], mats[0] if mats else mat, -axis)
        if cap_end and len(rings[-1]) > 2:
            self.face(rings[-1], mats[-1] if mats else mat, axis)
        return rings

    def sweep(self, path, widths, thicks, mat, nsec=8, expo=2.6, cap_start=True, cap_end=True):
        """Tube along a path lying in (or parallel to) the YZ plane; width is
        across X, thickness across the in-plane normal."""
        rings = []
        cents = []
        for i, p in enumerate(path):
            a = path[max(i - 1, 0)]
            b = path[min(i + 1, len(path) - 1)]
            t = (b - a).normalized()
            nrm = V(0, -t.z, t.y).normalized()
            ring = []
            for k in range(nsec):
                ang = 2 * math.pi * (k + 0.5) / nsec
                c, s = math.cos(ang), math.sin(ang)
                X = math.copysign(abs(c) ** (2 / expo), c) * widths[i] * 0.5
                N = math.copysign(abs(s) ** (2 / expo), s) * thicks[i] * 0.5
                ring.append(self.v(p + V(X, 0, 0) + nrm * N))
            rings.append(ring)
            cents.append(p)
        for i in range(len(rings) - 1):
            cm = (cents[i] + cents[i + 1]) * 0.5
            for k in range(nsec):
                k2 = (k + 1) % nsec
                # Blender -> Godot for the orientation hint
                mid_b = (rings[i][k].co + rings[i][k2].co + rings[i + 1][k].co + rings[i + 1][k2].co) / 4
                mid = V(mid_b.x, mid_b.z, -mid_b.y)
                self.face([rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]], mat, mid - cm)
        if cap_start:
            self.face(rings[0], mat, path[0] - path[1])
        if cap_end:
            self.face(rings[-1], mat, path[-1] - path[-2])
        return rings

    def screw(self, center, axis, r, h, mat, segs=8):
        """Domed screw head sitting on a surface at `center`, facing `axis`."""
        prof = [(-0.0003, r), (h * 0.55, r * 0.86), (h, 0.0)]
        self.lathe(center, axis, prof, segs, mat)


# --------------------------------------------------------------------------
# Splines
# --------------------------------------------------------------------------
def cr_centripetal(P0, P1, P2, P3, t, alpha=0.5):
    def tj(ti, a, b):
        return ti + max((b - a).length, 1e-9) ** alpha
    t0 = 0.0
    t1 = tj(t0, P0, P1)
    t2 = tj(t1, P1, P2)
    t3 = tj(t2, P2, P3)
    tt = lerp(t1, t2, t)
    A1 = P0 * ((t1 - tt) / (t1 - t0)) + P1 * ((tt - t0) / (t1 - t0))
    A2 = P1 * ((t2 - tt) / (t2 - t1)) + P2 * ((tt - t1) / (t2 - t1))
    A3 = P2 * ((t3 - tt) / (t3 - t2)) + P3 * ((tt - t2) / (t3 - t2))
    B1 = A1 * ((t2 - tt) / (t2 - t0)) + A2 * ((tt - t0) / (t2 - t0))
    B2 = A2 * ((t3 - tt) / (t3 - t1)) + A3 * ((tt - t1) / (t3 - t1))
    return B1 * ((t2 - tt) / (t2 - t1)) + B2 * ((tt - t1) / (t2 - t1))


def spline_pt(keys, u):
    n = len(keys)
    i = max(0, min(n - 2, int(math.floor(u))))
    t = u - i
    P1, P2 = keys[i], keys[i + 1]
    P0 = keys[i - 1] if i > 0 else P1 * 2 - P2
    P3 = keys[i + 2] if i + 2 < n else P2 * 2 - P1
    if t < 0 or t > 1:           # linear extrapolation past the ends
        return P1 + (P2 - P1) * t
    return cr_centripetal(P0, P1, P2, P3, t)


def spline_scalar(vals, u):
    n = len(vals)
    i = max(0, min(n - 2, int(math.floor(u))))
    t = max(0.0, min(1.0, u - i))
    p1, p2 = vals[i], vals[i + 1]
    p0 = vals[i - 1] if i > 0 else p1
    p3 = vals[i + 2] if i + 2 < n else p2
    t2, t3 = t * t, t * t * t
    return 0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                  + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)


# --------------------------------------------------------------------------
# Stock definition: two rails in side view (T = top / back strap, B = bottom
# / front strap) plus cross-section half-widths and superellipse exponents.
# --------------------------------------------------------------------------
def grip_rake(s):
    return RAKE + RAKE_EXTRA * max(0.0, s / GRIP_LEN) ** 1.6


def grip_axis(s):
    """Point on the grip axis (z, y) at distance s below the origin."""
    if s <= 0.0:
        return (math.sin(RAKE) * s, -math.cos(RAKE) * s)
    n = 48
    ds = s / n
    z = y = 0.0
    for i in range(n):
        r = grip_rake((i + 0.5) * ds)
        z += math.sin(r) * ds
        y -= math.cos(r) * ds
    return (z, y)


def _grip_row(s, hf, hb):
    az, ay = grip_axis(s)
    r = grip_rake(s)
    nb = (math.cos(r), math.sin(r))      # toward the back strap
    B = (az - nb[0] * hf, ay - nb[1] * hf)
    T = (az + nb[0] * hb, ay + nb[1] * hb)
    return T, B


def _tilt_row(B, ang_deg, L):
    a = math.radians(ang_deg)
    return (B[0] + L * math.sin(a), B[1] + L * math.cos(a)), B


# (T(z,y), B(z,y), w_top, w_bottom, n_top, n_bottom)
_ROWS = [
    (((-0.2875, 0.0500), (-0.2875, 0.0292)), 0.0116, 0.0080, 6.0, 2.2),   # 0 nose
    (((-0.2300, 0.0500), (-0.2300, 0.0282)), 0.0120, 0.0083, 6.0, 2.2),   # 1
    (((-0.1850, 0.0502), (-0.1850, 0.0268)), 0.0127, 0.0090, 6.0, 2.3),   # 2
    (((-0.1480, 0.0507), (-0.1480, 0.0234)), 0.0141, 0.0107, 5.5, 2.6),   # 3
    (((-0.1320, 0.0523), (-0.1320, 0.0190)), 0.0170, 0.0146, 5.0, 3.0),   # 4 lock panel
    (((-0.1150, 0.0540), (-0.1150, 0.0152)), 0.0179, 0.0158, 4.5, 3.4),   # 5
    (((-0.0780, 0.0560), (-0.0780, 0.0132)), 0.0181, 0.0160, 4.5, 3.4),   # 6 breech
    (((-0.0680, 0.0605), (-0.0680, 0.0130)), 0.0181, 0.0160, 4.2, 3.4),   # 7 tang
    (((-0.0450, 0.0612), (-0.0450, 0.0126)), 0.0179, 0.0158, 4.0, 3.4),   # 8
    (_tilt_row((-0.0300, 0.0118), 12.0, 0.0475), 0.0174, 0.0155, 3.4, 3.0),  # 9 wrist
    (_tilt_row((-0.0272, 0.0048), 31.0, 0.0445), 0.0165, 0.0150, 2.8, 2.7),  # 10
    (_grip_row(-0.010, 0.0190, 0.0212), 0.0154, 0.0147, 2.4, 2.5),        # 11 grip
    (_grip_row(0.016, 0.0180, 0.0192), 0.0146, 0.0142, 2.3, 2.3),         # 12 slimmest
    (_grip_row(0.040, 0.0192, 0.0204), 0.0154, 0.0150, 2.3, 2.3),         # 13
    (_grip_row(0.062, 0.0224, 0.0236), 0.0176, 0.0170, 2.3, 2.3),         # 14 cap edge
    (_grip_row(0.080, 0.0258, 0.0270), 0.0199, 0.0191, 2.3, 2.3),         # 15 swell
    (_grip_row(0.094, 0.0238, 0.0252), 0.0185, 0.0177, 2.3, 2.3),         # 16 end
]
T_KEYS = [Vector(r[0][0]) for r in _ROWS]
B_KEYS = [Vector(r[0][1]) for r in _ROWS]
WT = [r[1] for r in _ROWS]
WB = [r[2] for r in _ROWS]
NT = [r[3] for r in _ROWS]
NB = [r[4] for r in _ROWS]
U_MAX = len(_ROWS) - 1

U_CAP = 14.10          # butt cap starts here
U_STOCK_END = 14.22    # stock loft ends (inside the cap)
STOCK_U = [0.0, 1.0, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 6.0, 6.5, 7.0, 7.5,
           8.0, 8.33, 8.67, 9.0, 9.33, 9.67, 10.0, 10.33, 10.67, 11.0, 11.5, 12.0, 12.5,
           13.0, 13.5, 14.0, U_STOCK_END]
K_STOCK = 16


def rails(u):
    return spline_pt(T_KEYS, u), spline_pt(B_KEYS, u)


def section(u, K, grow=0.0):
    """Cross-section of the stock at u: K points (Godot 3D), starting at the
    bottom / front strap (phi=-90) and going bottom -> right (+X) -> top ->
    left. Returns (points, centre, e_h)."""
    T, B = rails(u)
    wt = spline_scalar(WT, u)
    wb = spline_scalar(WB, u)
    nt = spline_scalar(NT, u)
    nb = spline_scalar(NB, u)
    C = (T + B) * 0.5
    d = T - B
    L = d.length
    eh = d / L
    b = L * 0.5 + grow
    pts = []
    for j in range(K):
        phi = -math.pi / 2 + 2 * math.pi * j / K
        c, s = math.cos(phi), math.sin(phi)
        n = nt if s > 0 else nb
        X = math.copysign(abs(c) ** (2 / n), c)
        H = math.copysign(abs(s) ** (2 / n), s)
        w = lerp(wb, wt, (H + 1) * 0.5) + grow
        h = H * b
        zy = C + eh * h
        pts.append(V(w * X, zy[1], zy[0]))
    return pts, V(0, C[1], C[0]), V(0, eh[1], eh[0])


def u_for_rail(which, coord, value, lo=0.0, hi=U_MAX):
    """Bisection for u where rail T or B has component coord (0=z, 1=y)
    equal to value; assumes monotonic in the bracket."""
    f = (lambda u: rails(u)[0][coord]) if which == "T" else (lambda u: rails(u)[1][coord])
    a, b = lo, hi
    fa = f(a) - value
    for _ in range(60):
        m = 0.5 * (a + b)
        fm = f(m) - value
        if (fm < 0) == (fa < 0):
            a, fa = m, fm
        else:
            b = m
    return 0.5 * (a + b)


# Hi-res section cache for surface-conforming parts.
_HI = {}
K_HI = 192
SIDE_J = {"bottom": 0, "right": K_HI // 4, "top": K_HI // 2, "left": 3 * K_HI // 4}


def hi_section(u):
    key = round(u, 5)
    if key not in _HI:
        pts, C, eh = section(u, K_HI)
        cum = [0.0]
        for j in range(1, K_HI + 1):
            cum.append(cum[-1] + (pts[j % K_HI] - pts[j - 1]).length)
        _HI[key] = (pts, C, eh, cum)
    return _HI[key]


def surface_at(u, side, offset_arc):
    """Point + outward normal on the smooth stock surface at u, `offset_arc`
    metres around the outline from the named side (positive = increasing j)."""
    pts, C, eh, cum = hi_section(u)
    per = cum[-1]
    j0 = SIDE_J[side]
    a = (cum[j0] + offset_arc) % per
    # locate segment
    lo, hi = 0, K_HI
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if cum[mid] <= a:
            lo = mid
        else:
            hi = mid
    t = (a - cum[lo]) / max(cum[lo + 1] - cum[lo], 1e-12)
    p0, p1 = pts[lo % K_HI], pts[(lo + 1) % K_HI]
    p = p0.lerp(p1, t)
    tang = (p1 - p0).normalized()
    # Section plane normal (along the stock): X cross e_h.
    ns = V(1, 0, 0).cross(eh)
    nrm = tang.cross(ns).normalized()
    if nrm.dot(p - C) < 0:
        nrm = -nrm
    return p, nrm


# --------------------------------------------------------------------------
# Parts
# --------------------------------------------------------------------------
_ULEN = None


def stock_uv(u, side, arc):
    """UV of a point on the stock surface, matching build_stock()."""
    global _ULEN
    if _ULEN is None:
        us = [i * 0.02 for i in range(int(U_MAX / 0.02) + 1)]
        cs = [section(x, 4)[1] for x in us]
        acc = [0.0]
        for i in range(1, len(cs)):
            acc.append(acc[-1] + (cs[i] - cs[i - 1]).length)
        _ULEN = (us, acc)
    us, acc = _ULEN
    i = max(0, min(len(us) - 2, int(u / 0.02)))
    ul = lerp(acc[i], acc[i + 1], (u - us[i]) / 0.02)
    pts, C, eh, cum = hi_section(u)
    v = ((cum[SIDE_J[side]] + arc) % cum[-1]) / cum[-1]
    return (ul / 0.5, v)


def build_stock(b):
    rings = []
    centers = []
    for u in STOCK_U:
        pts, C, _ = section(u, K_STOCK)
        rings.append(pts)
        centers.append(C)
    # UV: u along the centre line (0..1 over 0.5 m), v around by arc length.
    ulen = [0.0]
    for i in range(1, len(centers)):
        ulen.append(ulen[-1] + (centers[i] - centers[i - 1]).length)
    vr = [[b.v(p) for p in ring] for ring in rings]

    def under_barrel(ps):
        for p in ps:
            if p.z > BREECH_Z - 0.001:
                return False
            if math.hypot(p.x, p.y - BORE_Y) > barrel_min_r(p.z) - 0.0004:
                return False
        return True

    for i in range(len(rings) - 1):
        ua, ub = ulen[i] / 0.5, ulen[i + 1] / 0.5
        va_list = _arc_fracs(rings[i])
        vb_list = _arc_fracs(rings[i + 1])
        for j in range(K_STOCK):
            k = j + 1
            kk = k % K_STOCK
            quad = (rings[i][j], rings[i][kk], rings[i + 1][j], rings[i + 1][kk])
            if under_barrel(quad):
                continue
            mid = (quad[0] + quad[1] + quad[2] + quad[3]) * 0.25
            cm = (centers[i] + centers[i + 1]) * 0.5
            b.face([vr[i][j], vr[i][kk], vr[i + 1][kk], vr[i + 1][j]], WALNUT, mid - cm,
                   [(ua, va_list[j]), (ua, va_list[k]), (ub, vb_list[k]), (ub, vb_list[j])])
    return vr


def barrel_min_r(z):
    """Smallest barrel radius at z (octagon apothem / round radius)."""
    if z >= -0.1502:
        return lerp(0.0136, 0.0127, (BREECH_Z - z) / (BREECH_Z + 0.1502))
    return interp([(-0.2980, 0.0107), (-0.1580, 0.0124)], z)


def _arc_fracs(ring):
    cum = [0.0]
    for j in range(1, len(ring) + 1):
        cum.append(cum[-1] + (ring[j % len(ring)] - ring[j - 1]).length)
    return [c / cum[-1] for c in cum]


def build_cap_loft(b, us, grows, mat, dome=None, front_fan=False, lip=None):
    """Brass shell over the stock (nose cap / butt cap), one ring per u with
    an outward `grow`. `lip` = (ring index, grow) adds an inward lip at that
    end ring so no gap shows between shell and stock. `dome` = [(dist,
    scale)] extra rings past the last u along the stock, closed with a pole.
    `front_fan` closes ring 0 with a fan (nose cap face)."""
    rings, centers = [], []
    for u, g in zip(us, grows):
        pts, C, _ = section(u, K_STOCK, g)
        rings.append(pts)
        centers.append(C)
    if dome:
        C = centers[-1]
        d = _along(us[-1])
        base = rings[-1]
        for dist, sc in dome:
            c2 = C + d * dist
            rings.append([c2 + (p - C) * sc for p in base])
            centers.append(c2)
        rings.append(None)
        centers.append(C + d * (dome[-1][0] * 1.08 + 0.0006))
    vr = [[b.v(c)] if ring is None else [b.v(p) for p in ring] for ring, c in zip(rings, centers)]
    for i in range(len(vr) - 1):
        ra, rb = vr[i], vr[i + 1]
        cm = (centers[i] + centers[i + 1]) * 0.5
        step = centers[i + 1] - centers[i]
        for j in range(K_STOCK):
            k = (j + 1) % K_STOCK
            if len(rb) == 1:
                mid = (rings[i][j] + rings[i][k]) * 0.5
                b.face([ra[j], ra[k], rb[0]], mat, mid - cm + step)
            else:
                mid = (rings[i][j] + rings[i][k] + rings[i + 1][j] + rings[i + 1][k]) * 0.25
                b.face([ra[j], ra[k], rb[k], rb[j]], mat, mid - cm)
    if front_fan:
        c = b.v(centers[0])
        for j in range(K_STOCK):
            k = (j + 1) % K_STOCK
            b.face([vr[0][j], vr[0][k], c], mat, -_along(us[0]))
    if lip is not None:
        idx, g = lip
        pts, _, _ = section(us[idx], K_STOCK, g)
        inner = [b.v(p) for p in pts]
        s = -1.0 if idx == 0 else 1.0
        for j in range(K_STOCK):
            k = (j + 1) % K_STOCK
            b.face([vr[idx][j], vr[idx][k], inner[k], inner[j]], mat, _along(us[idx]) * s)
    return vr


def _along(u):
    Tn, Bn = rails(u + 0.01)
    Tp, Bp = rails(u - 0.01)
    cn = (Tn + Bn) * 0.5 - (Tp + Bp) * 0.5
    return V(0, cn[1], cn[0]).normalized()


def surface_strip(b, u0, u1, side, hw_fn, th, mat, n_along=8, n_across=2, raise_fn=None,
                  sink=0.0008, center_fn=None, uv_top=False):
    """Thin plate conforming to the stock surface, e.g. a tang, spur or a
    raised wood panel. hw_fn(t) = half width (m, measured around the
    section) at t in 0..1 from u0 to u1; center_fn(t) shifts the strip
    around the section from the named side. uv_top maps the top faces with
    the stock's own UVs so the wood grain continues."""
    top, lo_l, lo_r = [], [], []
    uvs = []
    ends = {}
    for i in range(n_along + 1):
        t = i / n_along
        u = lerp(u0, u1, t)
        hw = max(hw_fn(t), 0.00025)
        c0 = center_fn(t) if center_fn else 0.0
        extra = raise_fn(t) if raise_fn else 0.0
        row, uvrow = [], []
        for k in range(n_across + 1):
            a = c0 + lerp(-hw, hw, k / n_across)
            p, nrm = surface_at(u, side, a)
            row.append(b.v(p + nrm * (th + extra)))
            if uv_top:
                uvrow.append(stock_uv(u, side, a))
            if i in (0, n_along):
                ends.setdefault(i, []).append(b.v(p - nrm * sink))
        top.append(row)
        uvs.append(uvrow)
        pl, nl = surface_at(u, side, c0 - hw)
        pr, nr = surface_at(u, side, c0 + hw)
        lo_l.append(b.v(pl - nl * sink))
        lo_r.append(b.v(pr - nr * sink))
    for i in range(n_along):
        t = (i + 0.5) / n_along
        u = lerp(u0, u1, t)
        c0 = center_fn(t) if center_fn else 0.0
        pc, nc = surface_at(u, side, c0)
        for k in range(n_across):
            quv = ([uvs[i][k], uvs[i][k + 1], uvs[i + 1][k + 1], uvs[i + 1][k]] if uv_top else None)
            b.face([top[i][k], top[i][k + 1], top[i + 1][k + 1], top[i + 1][k]], mat, nc, quv)
        # side walls
        pl, _ = surface_at(u, side, c0 - 1.0e-3)
        pr, _ = surface_at(u, side, c0 + 1.0e-3)
        across = pr - pl
        b.face([lo_l[i], lo_l[i + 1], top[i + 1][0], top[i][0]], mat, -across)
        b.face([lo_r[i], lo_r[i + 1], top[i + 1][n_across], top[i][n_across]], mat, across)
    # end walls
    for i, sgn in ((0, -1.0), (n_along, 1.0)):
        along = _along(lerp(u0, u1, i / n_along)) * (sgn if u1 > u0 else -sgn)
        low = ends[i]
        for k in range(n_across):
            b.face([low[k], low[k + 1], top[i][k + 1], top[i][k]], mat, along)


def build_panels(b):
    """Raised flats around the lock plate (right) and the side plate (left),
    each ending in the teardrop that runs back onto the wrist."""
    u0 = u_for_rail("B", 0, -0.1288)
    u1 = 10.45
    t_of = lambda u: (u - u0) / (u1 - u0)
    # centre of the panel, measured up the side from the section's middle
    up = [(t_of(u0), 0.0030), (t_of(8.5), 0.0032), (t_of(9.0), 0.0046), (t_of(9.5), 0.0080),
          (t_of(10.0), 0.0122), (1.0, 0.0148)]
    hw = [(0.0, 0.0030), (t_of(u0 + 0.10), 0.0085), (t_of(u0 + 0.28), 0.0114),
          (t_of(u0 + 0.5), 0.0123), (t_of(9.1), 0.0123), (t_of(9.6), 0.0100),
          (t_of(10.0), 0.0062), (t_of(10.3), 0.0026), (1.0, 0.0004)]
    for side, sgn in (("right", 1.0), ("left", -1.0)):
        surface_strip(b, u0, u1, side, lambda t: interp(hw, t), 0.0008, WALNUT,
                      n_along=14, n_across=3, center_fn=lambda t, s_=sgn: s_ * interp(up, t),
                      uv_top=True)


def build_barrel(b):
    # Octagonal breech section, flats at top / bottom / sides.
    z0, z1 = BREECH_Z, -0.1502
    ap0, ap1 = 0.0136, 0.0127
    k = 1.0 / math.cos(math.pi / 8)
    rings = []
    for z, ap in ((z0, ap0), (z1, ap1)):
        ring = []
        for i in range(8):
            a = math.pi / 8 + i * math.pi / 4
            ring.append(b.v(V(math.cos(a) * ap * k, BORE_Y + math.sin(a) * ap * k, z)))
        rings.append(ring)
    for i in range(8):
        j = (i + 1) % 8
        a = (i + 0.5) * math.pi / 4 + math.pi / 8
        b.face([rings[0][i], rings[0][j], rings[1][j], rings[1][i]], BARREL,
               V(math.cos(a), math.sin(a), 0))
        b.mark_sharp(rings[0][i], rings[1][i])
    b.face(rings[0], BARREL, V(0, 0, 1))
    # Girdle, tapered round barrel, muzzle astragal, crown and bore.
    prof = [
        (0.1500, 0.0139), (0.1512, 0.0142), (0.1558, 0.0142), (0.1572, 0.0129),
        (0.1580, 0.0124), (0.2980, 0.0107), (0.2988, 0.0113), (0.3028, 0.0113),
        (0.3036, 0.0108), (0.3094, 0.0108), (0.3100, 0.0101), (0.3100, BORE_R),
        (0.2960, BORE_R), (0.2960, 0.0),
    ]
    mats = [BARREL] * 11 + [FLINT, FLINT]
    b.lathe(V(0, BORE_Y, 0), V(0, 0, -1), prof, 16, BARREL, cap_start=True, mats=mats,
            ref=V(0, 1, 0), phase=math.pi / 16)
    # Blade front sight.
    b.extrude_x([(-0.2975, 0.0600), (-0.2915, 0.0600), (-0.2922, 0.0624), (-0.2950, 0.0634),
                 (-0.2970, 0.0627)], -0.0008, 0.0008, BRASS, bevel=0.0)


def build_ramrod(b):
    p0 = V(0, RAMROD_Y, -0.080)
    # Rear end is buried in the stock, so it is left open.
    prof = [(0.0, 0.0036), (0.2105, 0.0036), (0.2140, 0.0043), (0.2185, 0.0056),
            (0.2203, 0.0058), (0.2211, 0.0050), (0.2208, 0.0)]
    b.lathe(p0, V(0, 0, -1), prof, 8, STEEL, ref=V(0, 1, 0))
    # Front pipe and entry (tail) pipe, brass.
    pipe = [(0.0, 0.0040), (0.0005, 0.0058), (0.0125, 0.0058), (0.0130, 0.0040)]
    b.lathe(V(0, RAMROD_Y, -0.2290), V(0, 0, -1), pipe, 8, BRASS, ref=V(0, 1, 0))
    entry = [(0.0, 0.0040), (0.0004, 0.0055), (0.0100, 0.0056), (0.0150, 0.0065),
             (0.0180, 0.0065), (0.0183, 0.0040)]
    b.lathe(V(0, RAMROD_Y, -0.1630), V(0, 0, -1), entry, 8, BRASS, ref=V(0, 1, 0))
    u_a = u_for_rail("B", 0, -0.1655)
    u_b = u_for_rail("B", 0, -0.1500)
    surface_strip(b, u_a, u_b, "bottom",
                  lambda t: interp([(0, 0.0036), (0.55, 0.0030), (0.8, 0.0024), (1.0, 0.0006)], t),
                  0.0011, BRASS, n_along=5, n_across=2)


LOCK_PLATE = [(-0.1250, 0.0400), (-0.1238, 0.0436), (-0.1195, 0.0462), (-0.1100, 0.0476),
              (-0.0900, 0.0481), (-0.0660, 0.0481), (-0.0450, 0.0479), (-0.0310, 0.0472),
              (-0.0215, 0.0458), (-0.0160, 0.0438), (-0.0130, 0.0410), (-0.0128, 0.0380),
              (-0.0150, 0.0355), (-0.0210, 0.0328), (-0.0320, 0.0302), (-0.0500, 0.0287),
              (-0.0750, 0.0286), (-0.1000, 0.0300), (-0.1150, 0.0322), (-0.1225, 0.0355)]

PAN = [(-0.0880, 0.0505), (-0.0690, 0.0505), (-0.0690, 0.0547), (-0.0664, 0.0547),
       (-0.0660, 0.0470), (-0.0700, 0.0440), (-0.0780, 0.0426), (-0.0850, 0.0438),
       (-0.0885, 0.0472)]

FRIZZEN = [
    # pan cover (toe) resting on the pan
    (-0.0870, 0.0507), (-0.0693, 0.0507), (-0.0690, 0.0520), (-0.0695, 0.0533),
    (-0.0795, 0.0537),
    # striking face, rear surface going up
    (-0.0800, 0.0590), (-0.0806, 0.0650), (-0.0816, 0.0710), (-0.0830, 0.0765),
    # top with a small forward curl
    (-0.0838, 0.0785), (-0.0855, 0.0795), (-0.0875, 0.0790),
    # front surface going down
    (-0.0868, 0.0745), (-0.0855, 0.0690), (-0.0846, 0.0630), (-0.0846, 0.0575),
    # arm forward to the pivot boss
    (-0.0872, 0.0535), (-0.0915, 0.0505),
    (-0.0955, 0.0503), (-0.0982, 0.0492), (-0.0993, 0.0465),
    # toe beyond the pivot, bearing on the frizzen spring
    (-0.1005, 0.0440), (-0.0995, 0.0428), (-0.0960, 0.0427),
    (-0.0925, 0.0445), (-0.0890, 0.0485),
]

FRIZZEN_SPRING = [(-0.1215, 0.0418), (-0.1100, 0.0431), (-0.0990, 0.0428), (-0.0990, 0.0416),
                  (-0.1100, 0.0417), (-0.1172, 0.0404), (-0.1182, 0.0396), (-0.1172, 0.0387),
                  (-0.1080, 0.0372), (-0.0995, 0.0366), (-0.0995, 0.0352), (-0.1080, 0.0356),
                  (-0.1185, 0.0372), (-0.1224, 0.0388), (-0.1230, 0.0403), (-0.1225, 0.0413)]

# Goose-neck cock in its design frame (a = forward, b = up, pivot at 0,0,
# jaws level). Rotated back by COCK_ANGLE to full cock.
COCK = [
    # body front ("breast") and the front edge of the goose neck
    (0.0080, -0.0012), (0.0079, 0.0025), (0.0062, 0.0058), (0.0033, 0.0076),
    (0.0003, 0.0118), (-0.0012, 0.0154), (-0.0005, 0.0187), (0.0018, 0.0209),
    # lower jaw
    (0.0045, 0.0228), (0.0195, 0.0240), (0.0212, 0.0252), (0.0212, 0.0268), (0.0200, 0.0277),
    (0.0010, 0.0277),
    # comb (spine) the top jaw rides on
    (-0.0008, 0.0292), (-0.0010, 0.0440), (-0.0022, 0.0460), (-0.0040, 0.0460),
    (-0.0052, 0.0442), (-0.0052, 0.0290),
    # rear edge of the neck
    (-0.0058, 0.0213), (-0.0068, 0.0150), (-0.0052, 0.0095), (-0.0060, 0.0055),
    # tail and underside of the body
    (-0.0085, 0.0034), (-0.0125, 0.0020), (-0.0158, 0.0004), (-0.0156, -0.0018),
    (-0.0125, -0.0040), (-0.0080, -0.0060), (-0.0036, -0.0076), (0.0006, -0.0080),
    (0.0042, -0.0070), (0.0068, -0.0045),
]
COCK_LOWER_JAW = [(0.0005, 0.0238), (0.0195, 0.0243), (0.0210, 0.0252), (0.0210, 0.0268),
                  (0.0198, 0.0277), (0.0005, 0.0277)]
COCK_TOP_JAW = [(-0.0006, 0.0334), (0.0158, 0.0334), (0.0170, 0.0342), (0.0168, 0.0358),
                (0.0156, 0.0366), (-0.0006, 0.0366)]
FLINT_SHAPE = [(0.0060, 0.0279), (0.0300, 0.0279), (0.0222, 0.0333), (0.0060, 0.0333)]
JAW_SCREW_A = 0.0030


def cock_xform(a, b_):
    """Design frame (a fwd, b up) -> side view (z, y) at full cock."""
    c, s = math.cos(COCK_ANGLE), math.sin(COCK_ANGLE)
    a2 = a * c - b_ * s
    b2 = a * s + b_ * c
    return (COCK_PIVOT[0] - a2, COCK_PIVOT[1] + b2)


def cock_dir(a, b_):
    z0, y0 = cock_xform(0, 0)
    z1, y1 = cock_xform(a, b_)
    return V(0, y1 - y0, z1 - z0)


def build_lock(b):
    b.extrude_x(LOCK_PLATE, 0.0125, 0.0192, STEEL, bevel=0.0007, cap_lo=False, bevel_lo=False)
    b.extrude_x(PAN, 0.0170, 0.0270, STEEL, bevel=0.0004, cap_lo=False, bevel_lo=False)
    b.extrude_x(FRIZZEN, 0.0180, 0.0282, STEEL, bevel=0.0005, bevel_lo=False)
    b.extrude_x(FRIZZEN_SPRING, 0.0186, 0.0218, STEEL, bevel=0.0003, cap_lo=False, bevel_lo=False)
    # Cock, jaws, flint.
    b.extrude_x([cock_xform(*p) for p in COCK], 0.0198, 0.0262, STEEL, bevel=0.0006, bevel_lo=False)
    b.extrude_x([cock_xform(*p) for p in COCK_LOWER_JAW], 0.0184, 0.0276, STEEL, bevel=0.0004)
    b.extrude_x([cock_xform(*p) for p in COCK_TOP_JAW], 0.0186, 0.0274, STEEL, bevel=0.0004)
    b.extrude_x([cock_xform(*p) for p in FLINT_SHAPE], 0.0164, 0.0296, FLINT, bevel=0.0003)
    # Jaw screw: shank above the top jaw and a domed head.
    up = cock_dir(0, 1).normalized()
    base = zy3(0.0230, cock_xform(JAW_SCREW_A, 0.0366))
    b.lathe(base - up * 0.0005, up, [(0.0, 0.0016), (0.0052, 0.0016), (0.0052, 0.0031),
                                     (0.0072, 0.0027), (0.0084, 0.0)],
            6, STEEL)
    # Screws: cock (tumbler) screw, frizzen pivot, frizzen spring.
    b.screw(zy3(0.0260, COCK_PIVOT), V(1, 0, 0), 0.0033, 0.0018, STEEL)
    b.screw(zy3(0.0282, FRIZZEN_PIVOT), V(1, 0, 0), 0.0027, 0.0014, STEEL)
    b.screw(zy3(0.0218, (-0.1068, 0.0364)), V(1, 0, 0), 0.0021, 0.0011, STEEL, segs=6)


SIDE_PLATE = [(-0.0960, 0.0378), (-0.0945, 0.0412), (-0.0900, 0.0432), (-0.0850, 0.0430),
              (-0.0780, 0.0412), (-0.0600, 0.0404), (-0.0440, 0.0414), (-0.0360, 0.0426),
              (-0.0300, 0.0418), (-0.0240, 0.0395), (-0.0205, 0.0374), (-0.0240, 0.0356),
              (-0.0300, 0.0334), (-0.0360, 0.0326), (-0.0440, 0.0338), (-0.0600, 0.0350),
              (-0.0780, 0.0344), (-0.0850, 0.0326), (-0.0900, 0.0324), (-0.0945, 0.0342)]

TRIGGER = [(-0.0490, 0.0170), (-0.0452, 0.0170), (-0.0450, 0.0090), (-0.0458, 0.0030),
           (-0.0474, -0.0015), (-0.0496, -0.0042), (-0.0510, -0.0044), (-0.0512, -0.0030),
           (-0.0497, -0.0008), (-0.0485, 0.0030), (-0.0481, 0.0090)]


def build_furniture(b):
    # Side plate (left) with two side-nail heads.
    b.extrude_x(SIDE_PLATE, -0.0189, -0.0130, BRASS, bevel=0.0006, cap_hi=False, bevel_hi=False)
    b.screw(V(-0.0189, 0.0378, -0.0880), V(-1, 0, 0), 0.0030, 0.0014, STEEL)
    b.screw(V(-0.0189, 0.0376, -0.0360), V(-1, 0, 0), 0.0030, 0.0014, STEEL)
    # Trigger.
    b.extrude_x(TRIGGER, -0.0021, 0.0021, STEEL, bevel=0.0004)

    # Trigger guard: front tang along the stock bottom, then the bow.
    zs = [-0.1280, -0.1266, -0.1238, -0.1205, -0.1170, -0.1100, -0.0950, -0.0795]
    ws = [0.0012, 0.0048, 0.0062, 0.0042, 0.0066, 0.0080, 0.0082, 0.0080]
    ts = [0.0012, 0.0016, 0.0019, 0.0017, 0.0019, 0.0020, 0.0021, 0.0022]
    path = []
    for z, t in zip(zs, ts):
        u = u_for_rail("B", 0, z)
        p, nrm = surface_at(u, "bottom", 0.0)
        path.append(p + nrm * (t * 0.5 - 0.0004))
    bow = [(-0.0775, 0.0098), (-0.0752, 0.0055), (-0.0718, 0.0006), (-0.0668, -0.0044),
           (-0.0600, -0.0084), (-0.0520, -0.0104), (-0.0440, -0.0107), (-0.0370, -0.0092),
           (-0.0318, -0.0062), (-0.0283, -0.0022), (-0.0263, 0.0022), (-0.0250, 0.0068),
           (-0.0240, 0.0105)]
    for z, y in bow:
        path.append(V(0, y, z))
    ws += [0.0078, 0.0076] + [0.0074] * (len(bow) - 2)
    ts += [0.0027, 0.0032] + [0.0034] * (len(bow) - 2)
    b.sweep(path, ws, ts, BRASS, nsec=6, expo=2.8)
    # Rear tang down the front strap of the grip, ending in a small finial.
    u_a = 9.85
    u_b = 13.18
    surface_strip(b, u_a, u_b, "bottom",
                  lambda t: interp([(0, 0.0038), (0.60, 0.0035), (0.72, 0.0024), (0.80, 0.0033),
                                    (0.88, 0.0030), (0.95, 0.0017), (1.0, 0.0004)], t),
                  0.0017, BRASS, n_along=10, n_across=2)

    # Nose cap.
    u_nc = u_for_rail("B", 0, -0.2795)
    build_cap_loft(b, [0.0, u_nc], [0.0006, 0.0006], BRASS, front_fan=True, lip=(1, -0.0010))

    # Butt cap: raised rim, shell, domed end, inward lip at the top edge.
    us = [U_CAP, U_CAP + 0.08, U_CAP + 0.14, 14.7, 15.3, 16.0]
    gs = [0.0015, 0.0015, 0.0008, 0.0008, 0.0008, 0.0008]
    build_cap_loft(b, us, gs, BRASS, dome=[(0.0046, 0.88), (0.0080, 0.58)], lip=(0, -0.0015))
    # Spurs running up both sides of the grip.
    u_tip = 12.25
    for side in ("right", "left"):
        surface_strip(b, u_tip, U_CAP + 0.02, side,
                      lambda t: interp([(0, 0.0004), (0.08, 0.0024), (0.18, 0.0029), (0.30, 0.0021),
                                        (0.48, 0.0028), (0.75, 0.0048), (1.0, 0.0070)], t),
                      0.0009, BRASS, n_along=8, n_across=2)

    # Thumb plate (escutcheon) on top of the wrist.
    surface_strip(b, 8.95, 9.85, "top",
                  lambda t: 0.0050 * math.sqrt(max(0.0, 1 - (2 * t - 1) ** 2)) + 0.0002,
                  0.0007, BRASS, n_along=8, n_across=2)

    # Barrel tang on top of the wrist (iron), flush with the barrel at the breech.
    u_a = u_for_rail("T", 0, -0.0755, 5.0, 9.0)
    u_b = u_for_rail("T", 0, -0.0330, 5.0, 9.5)
    top_breech = BORE_Y + 0.0136

    def tang_raise(t):
        u = lerp(u_a, u_b, t)
        p, n = surface_at(u, "top", 0.0)
        need = max(0.0, top_breech - 0.0012 - p.y)
        return need * (1.0 - smoothstep(0.0, 0.28, t))

    surface_strip(b, u_a, u_b, "top",
                  lambda t: interp([(0, 0.0056), (0.8, 0.0038), (0.9, 0.0033), (0.96, 0.0024),
                                    (1.0, 0.0008)], t),
                  0.0012, BARREL, n_along=8, n_across=2, raise_fn=tang_raise)
    ut = lerp(u_a, u_b, 0.72)
    p, n = surface_at(ut, "top", 0.0)
    b.screw(p + n * 0.0011, n, 0.0026, 0.0012, STEEL)


# --------------------------------------------------------------------------
# Walnut grain texture
# --------------------------------------------------------------------------
def make_walnut(W=1024, H=256, seed=1757):
    rng = np.random.default_rng(seed)

    def noise(cx, cy):
        g = rng.random((cy, cx))
        xs = np.arange(W) * cx / W
        ys = np.arange(H) * cy / H
        x0 = np.floor(xs).astype(int)
        fx = xs - x0
        x1 = (x0 + 1) % cx
        y0 = np.floor(ys).astype(int)
        fy = ys - y0
        y1 = (y0 + 1) % cy
        sx = fx * fx * (3 - 2 * fx)
        sy = fy * fy * (3 - 2 * fy)
        a = g[np.ix_(y0, x0)]
        b_ = g[np.ix_(y0, x1)]
        c = g[np.ix_(y1, x0)]
        d = g[np.ix_(y1, x1)]
        top = a + (b_ - a) * sx[None, :]
        bot = c + (d - c) * sx[None, :]
        return top + (bot - top) * sy[:, None]

    v = (np.arange(H) / H)[:, None]
    warp = noise(5, 3) * 0.9 + noise(18, 6) * 0.25
    bands = v * 11.0 + warp * 1.7
    g = 0.5 + 0.5 * np.sin(2 * np.pi * bands)
    g = g ** 1.8
    streak = noise(30, 150)
    broad = noise(6, 4)
    t = np.clip(0.18 + 0.42 * g + 0.25 * streak + 0.25 * broad - 0.1, 0.0, 1.0)
    dark = np.array([0.20, 0.105, 0.055])
    light = np.array([0.52, 0.33, 0.18])
    rgb = dark[None, None, :] + (light - dark)[None, None, :] * t[:, :, None]
    # Open pores: short dark dashes running with the grain.
    pores = noise(260, 210)
    pm = np.clip((pores - 0.83) / 0.07, 0.0, 1.0)
    rgb *= (1.0 - 0.22 * pm)[:, :, None]
    rgb *= (0.94 + 0.06 * noise(64, 32))[:, :, None]
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((H, W, 1))], axis=2).astype(np.float32)
    img = bpy.data.images.new("pistol_walnut", W, H, alpha=False)
    img.pixels.foreach_set(rgba.ravel())
    img.update()
    return img


def principled(name, color=None, metallic=0.0, roughness=0.6, image=None):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if color:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    if image:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.interpolation = "Linear"
        tex.location = (-400, 200)
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    m.use_backface_culling = True
    return m


# --------------------------------------------------------------------------
# Assembly
# --------------------------------------------------------------------------
def box_uvs(bm, uv, has_uv, scale=8.0):
    for f in bm.faces:
        if f[has_uv]:
            continue
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for loop in f.loops:
            co = loop.vert.co
            if ax == 0:
                loop[uv].uv = (co.y * scale, co.z * scale)
            elif ax == 1:
                loop[uv].uv = (co.x * scale, co.z * scale)
            else:
                loop[uv].uv = (co.x * scale, co.y * scale)


def build_pistol(texture_png=None):
    b = Builder()
    build_stock(b)
    build_panels(b)
    build_barrel(b)
    build_ramrod(b)
    build_lock(b)
    build_furniture(b)

    bm = b.bm
    bm.normal_update()
    box_uvs(bm, b.uv, b.has_uv)
    # Shading: all smooth, hard edges by angle plus explicit ones.
    thr = math.radians(50.0)
    for e in bm.edges:
        if len(e.link_faces) == 2:
            try:
                ang = e.calc_face_angle()
            except ValueError:
                ang = 0.0
            e.smooth = ang < thr
        else:
            e.smooth = False
    for a, c in b.sharp:
        e = bm.edges.get((a, c))
        if e:
            e.smooth = False
    bm.faces.layers.int.remove(b.has_uv)

    mesh = bpy.data.meshes.new("Pistol")
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate()

    img = make_walnut()
    if texture_png:
        img.filepath_raw = texture_png
        img.file_format = "PNG"
        img.save()
        img.source = "FILE"
        img.reload()
    img.pack()
    mats = [
        principled(MAT_NAMES[WALNUT], roughness=0.46, image=img),
        principled(MAT_NAMES[BRASS], color=(0.76, 0.57, 0.27), metallic=1.0, roughness=0.34),
        principled(MAT_NAMES[BARREL], color=(0.15, 0.115, 0.085), metallic=0.8, roughness=0.44),
        principled(MAT_NAMES[STEEL], color=(0.36, 0.36, 0.37), metallic=1.0, roughness=0.34),
        principled(MAT_NAMES[FLINT], color=(0.045, 0.042, 0.038), metallic=0.0, roughness=0.3),
    ]
    for m in mats:
        mesh.materials.append(m)

    obj = bpy.data.objects.new("Pistol", mesh)
    bpy.context.scene.collection.objects.link(obj)
    wn = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    wn.mode = "FACE_AREA"
    wn.weight = 50
    wn.keep_sharp = True

    muzzle = bpy.data.objects.new("Muzzle", None)
    muzzle.empty_display_type = "PLAIN_AXES"
    muzzle.empty_display_size = 0.02
    muzzle.location = to_blender(V(0.0, BORE_Y, MUZZLE_Z))
    bpy.context.scene.collection.objects.link(muzzle)

    # Top of the pan bowl, centred between its side walls (x 0.017-0.027).
    pan = bpy.data.objects.new("Pan", None)
    pan.empty_display_type = "PLAIN_AXES"
    pan.empty_display_size = 0.01
    pan.location = to_blender(V(0.022, 0.0505, -0.078))
    bpy.context.scene.collection.objects.link(pan)
    return obj, muzzle, pan


def export_glb(objs, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
              export_apply=True, export_texcoords=True, export_normals=True,
              export_materials="EXPORT", export_cameras=False, export_lights=False,
              export_extras=False)
    try:
        bpy.ops.export_scene.gltf(export_image_format="JPEG", export_jpeg_quality=90, **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(export_image_format="AUTO", **kw)


# --------------------------------------------------------------------------
# Preview renders
# --------------------------------------------------------------------------
def _box(name, center, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.data.materials.append(mat)
    return o


def _text(body, loc, size, mat, rot, align="CENTER"):
    cu = bpy.data.curves.new("txt_" + body, "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = align
    o = bpy.data.objects.new("txt_" + body, cu)
    o.location = loc
    o.rotation_euler = rot
    o.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(o)
    return o


def _camera(name, loc, target, ortho=None, lens=50.0, rot=None):
    cd = bpy.data.cameras.new(name)
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.lens = lens
    cd.clip_start = 0.005
    o = bpy.data.objects.new(name, cd)
    o.location = loc
    if rot:
        o.rotation_euler = [math.radians(a) for a in rot]
    else:
        d = Vector(target) - Vector(loc)
        o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(o)
    return o


def _emissive(name, color, strength=1.0):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Emission Color"].default_value = (*color, 1)
    bsdf.inputs["Emission Strength"].default_value = strength
    return m


def render_previews(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    try:
        sc.eevee.taa_render_samples = 48
    except AttributeError:
        pass
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = False

    # World: studio HDR for lighting/reflections, flat grey to the camera.
    world = bpy.data.worlds.new("PreviewWorld")
    try:
        world.use_nodes = True
    except Exception:
        pass
    nt = world.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    mix = nt.nodes.new("ShaderNodeMixShader")
    lp = nt.nodes.new("ShaderNodeLightPath")
    bg_env = nt.nodes.new("ShaderNodeBackground")
    bg_flat = nt.nodes.new("ShaderNodeBackground")
    bg_flat.inputs["Color"].default_value = (0.50, 0.52, 0.55, 1.0)
    bg_flat.inputs["Strength"].default_value = 1.0
    hdr_dir = os.path.join(os.path.dirname(bpy.app.binary_path), "..", "Resources",
                           "%d.%d" % bpy.app.version[:2], "datafiles", "studiolights", "world")
    hdr = os.path.join(hdr_dir, "courtyard.exr")
    if os.path.exists(hdr):
        env = nt.nodes.new("ShaderNodeTexEnvironment")
        env.image = bpy.data.images.load(hdr)
        nt.links.new(env.outputs["Color"], bg_env.inputs["Color"])
        bg_env.inputs["Strength"].default_value = 0.9
    else:
        bg_env.inputs["Color"].default_value = (0.6, 0.6, 0.62, 1.0)
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs["Fac"])
    nt.links.new(bg_env.outputs["Background"], mix.inputs[1])
    nt.links.new(bg_flat.outputs["Background"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    sc.world = world

    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 2.6
    sun.angle = math.radians(6)
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(38), math.radians(-18), math.radians(60))
    sc.collection.objects.link(so)

    white = principled("ScaleWhite", color=(0.9, 0.9, 0.9), roughness=0.9)
    black = principled("ScaleBlack", color=(0.02, 0.02, 0.02), roughness=0.9)
    red = _emissive("MarkRed", (1.0, 0.05, 0.02), 2.0)
    green = _emissive("MarkGreen", (0.05, 0.9, 0.1), 2.0)

    # Scale bar (1 cm blocks, 40 cm) below the pistol for the side views.
    # Godot z runs -0.32 .. +0.08, i.e. Blender y from -0.08 to 0.32.
    zb = -0.125
    for i in range(40):
        y0 = -0.08 + i * 0.01
        _box("bar%d" % i, (0.0, y0 + 0.005, zb), (0.002, 0.01, 0.005), black if i % 2 == 0 else white)
    side_rot = (math.radians(90), 0.0, math.radians(90))
    for i in range(0, 41, 5):
        _text("%d" % i, (0.0, -0.08 + i * 0.01, zb - 0.013), 0.009, black, side_rot)
    _text("cm", (0.0, 0.335, zb - 0.004), 0.009, black, side_rot)
    # Origin / Muzzle markers (render only).
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.0025, location=(0, 0, 0))
    om = bpy.context.active_object
    om.data.materials.append(green)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.0025, location=to_blender(V(0, BORE_Y, MUZZLE_Z)))
    mm = bpy.context.active_object
    mm.data.materials.append(red)
    # Grip axis line (render only).
    ax0 = to_blender(V(0, -GRIP_D[1] * 0.03, -GRIP_D[0] * 0.03))
    ax1 = to_blender(V(0, GRIP_D[1] * 0.05, GRIP_D[0] * 0.05))
    mid = (ax0 + ax1) * 0.5
    bpy.ops.mesh.primitive_cylinder_add(radius=0.0006, depth=(ax1 - ax0).length, location=mid)
    gl = bpy.context.active_object
    gl.rotation_euler = (ax1 - ax0).to_track_quat("Z", "Y").to_euler()
    gl.data.materials.append(green)
    lbl_o = _text("origin", (0.03, 0.0, -0.004), 0.006, green, side_rot)
    lbl_m = _text("Muzzle", (0.03, 0.31, 0.058), 0.006, red, side_rot)
    markers = [om, mm, gl, lbl_o, lbl_m]

    # Backdrop for the side views, floor for the perspective views.
    floor_m = bpy.data.materials.new("Floor")
    try:
        floor_m.use_nodes = True
    except Exception:
        pass
    fnt = floor_m.node_tree
    fb = next(n for n in fnt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = fnt.nodes.new("ShaderNodeTexCoord")
    chk = fnt.nodes.new("ShaderNodeTexChecker")
    chk.inputs["Scale"].default_value = 20.0   # 5 cm squares on a 2 m plane
    chk.inputs["Color1"].default_value = (0.42, 0.42, 0.42, 1)
    chk.inputs["Color2"].default_value = (0.34, 0.34, 0.34, 1)
    fnt.links.new(tc.outputs["Generated"], chk.inputs["Vector"])
    fnt.links.new(chk.outputs["Color"], fb.inputs["Base Color"])
    fb.inputs["Roughness"].default_value = 0.9
    bpy.ops.mesh.primitive_plane_add(size=2.0, location=(0, 0.1, -0.106))
    floor = bpy.context.active_object
    floor.data.materials.append(floor_m)

    scale_objs = [o for o in bpy.data.objects if o.name.startswith(("bar", "txt_"))
                  and o not in (lbl_o, lbl_m)]

    shots = [
        # name, camera, res, show floor, show scale bar, show markers
        ("pistol_side_right", _camera("cam_side", (1.0, 0.12, -0.02), (0, 0.12, -0.02), ortho=0.46),
         (1800, 1000), False, True, True),
        ("pistol_side_left", _camera("cam_left", (-1.0, 0.12, -0.02), (0, 0.12, -0.02), ortho=0.46),
         (1800, 1000), False, False, False),
        ("pistol_3q", _camera("cam_3q", (0.36, 0.52, 0.20), (0.0, 0.10, -0.01), lens=55),
         (1600, 1000), True, False, False),
        ("pistol_3q_rear", _camera("cam_3qr", (-0.34, -0.30, 0.16), (0.0, 0.07, -0.01), lens=55),
         (1600, 1000), True, False, False),
        ("pistol_lock_detail", _camera("cam_lock", (0.20, 0.16, 0.11), (0.02, 0.055, 0.05), lens=55),
         (1600, 1000), False, False, False),
        ("pistol_top", _camera("cam_top", (0.0, 0.12, 1.0), None, ortho=0.46, rot=(0, 0, 90)),
         (1800, 700), False, False, False),
        ("pistol_front", _camera("cam_front", (0.0, 1.0, -0.005), None, ortho=0.22, rot=(90, 0, 180)),
         (1000, 1000), False, False, False),
    ]
    for name, cam, (w, h), show_floor, show_scale, show_markers in shots:
        floor.hide_render = not show_floor
        for o in scale_objs:
            o.hide_render = not show_scale
        for o in markers:
            o.hide_render = not show_markers
        sc.camera = cam
        sc.render.resolution_x = w
        sc.render.resolution_y = h
        sc.render.filepath = os.path.join(out_dir, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("RENDERED", sc.render.filepath)


# --------------------------------------------------------------------------
# Verification: parse the GLB and re-import it into an empty scene.
# --------------------------------------------------------------------------
def read_glb_json(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, ver, length = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67, "not a GLB"
    clen, ctype = struct.unpack_from("<II", data, 12)
    return json.loads(data[20:20 + clen].decode("utf-8"))


def verify(path):
    gj = read_glb_json(path)
    print("VERIFY glTF nodes:")
    for n in gj["nodes"]:
        print("   ", n.get("name"), "mesh" if "mesh" in n else "empty",
              "t=%s" % n.get("translation", [0, 0, 0]), "r=%s" % n.get("rotation", [0, 0, 0, 1]),
              "children=%s" % n.get("children", []))
    scene_roots = gj["scenes"][gj.get("scene", 0)]["nodes"]
    print("VERIFY scene roots:", [gj["nodes"][i]["name"] for i in scene_roots])
    mins = [1e9] * 3
    maxs = [-1e9] * 3
    tris = 0
    for mesh in gj["meshes"]:
        for prim in mesh["primitives"]:
            acc = gj["accessors"][prim["attributes"]["POSITION"]]
            for i in range(3):
                mins[i] = min(mins[i], acc["min"][i])
                maxs[i] = max(maxs[i], acc["max"][i])
            tris += gj["accessors"][prim["indices"]]["count"] // 3
    print("VERIFY glTF (= Godot) mesh bbox min=%s max=%s" % (
        [round(x, 4) for x in mins], [round(x, 4) for x in maxs]))
    print("VERIFY glTF triangles:", tris, "materials:", [m["name"] for m in gj["materials"]])

    # Fresh scene re-import.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    for o in bpy.context.scene.objects:
        mw = o.matrix_world
        loc = mw.translation
        g = (loc.x, loc.z, -loc.y)
        line = "VERIFY reimport %-8s type=%-5s godot_pos=(%.4f, %.4f, %.4f)" % (o.name, o.type, *g)
        if o.type == "MESH":
            cs = [mw @ v.co for v in o.data.vertices]
            gx = [c.x for c in cs]
            gy = [c.z for c in cs]
            gz = [-c.y for c in cs]
            line += " bbox_godot x[%.4f, %.4f] y[%.4f, %.4f] z[%.4f, %.4f] tris=%d" % (
                min(gx), max(gx), min(gy), max(gy), min(gz), max(gz),
                sum(len(p.vertices) - 2 for p in o.data.polygons))
        else:
            fwd = mw.to_3x3() @ Vector((0, 1, 0))     # Blender +Y = Godot -Z
            up = mw.to_3x3() @ Vector((0, 0, 1))
            line += " forward(-Z)->godot(%.3f, %.3f, %.3f) up->godot(%.3f, %.3f, %.3f)" % (
                fwd.x, fwd.z, -fwd.y, up.x, up.z, -up.y)
        print(line)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
    project = os.path.abspath(os.path.join(here, "..", ".."))
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(project, "assets", "weapons", "pistol.glb"))
    ap.add_argument("--renders", default=None)
    ap.add_argument("--blend", default=None)
    ap.add_argument("--texture-png", default=None, help="also write the walnut texture here")
    ap.add_argument("--verify", action="store_true")
    args = ap.parse_args(argv)

    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    obj, muzzle, pan = build_pistol(args.texture_png)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print("PISTOL TRIS", tris, "VERTS", len(obj.data.vertices), "FACES", len(obj.data.polygons))
    export_glb([obj, muzzle, pan], args.out)
    print("EXPORTED", args.out, os.path.getsize(args.out), "bytes")
    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    if args.renders:
        render_previews(args.renders)
    if args.verify:
        verify(args.out)


if __name__ == "__main__":
    main()
