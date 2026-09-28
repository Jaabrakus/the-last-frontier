"""Cocked hats (costume bible §5.1-5.3): the British private's black felt hat bound with
white tape, with a black cockade on the left front, and the French tricorne with false-gold
lace and the white cockade.

The felt hat is build_body's tricorn (an elliptical crown and a round brim folded up along
three chords, front point forward), sized to sit on every hair style: its crown wall
starts at the hair's hat-band plane (hair zone "crown" hidden, hair/_common.CROWN_P) and it
is rigid on headb. Zones: 0 felt, 1 binding tape or lace (the brim's edge band, both
sides), 2 cockade, 3 button and loop.
"""

import math

import bmesh
import numpy as np
from mathutils import Matrix, Vector

from lib.remesh import Prims, material, set_sharp
from lib.sdf import frame_from, v3

from . import _base as B

BRITISH = {"tilt": -7.0, "crown_a": 0.080, "crown_b": 0.102, "crown_h": 0.062, "brim_r": 0.178, "chord": 0.104,
           "fold": 78.0, "cockade": True, "tape_rings": 1, "lower": 0.0}
FRENCH = dict(BRITISH, tilt=-9.0, lower=0.004, tape_rings=1)


def tricorn(prims, mi_felt, mi_trim, center, tilt_deg, crown_a, crown_b, crown_h, brim_r=0.176,
            chord=0.104, fold_deg=78.0, segs=64, rings=7, thick=0.0045, tape_rings=1):
    """build_body.tricorn: felt tricorn with an elliptical crown and a round brim folded up
    along three chords (front point forward = -Y); the outer `tape_rings` rings of the brim
    (both sides) are the binding. Returns (cockade position, its outward normal)."""
    bm = prims.bm
    rot = Matrix.Rotation(math.radians(tilt_deg), 4, "X")
    C = Vector(center)
    normals = [v3(0, 1, 0), v3(math.sin(math.radians(120)), -0.5, 0), v3(-math.sin(math.radians(120)), -0.5, 0)]
    fa = math.radians(fold_deg)

    def fold(px, py):
        p = v3(px, py, 0.0)
        ups = [0.0]
        for n in normals:
            o = p[0] * n[0] + p[1] * n[1] - chord
            if o > 0:
                p = p - n * o * (1 - math.cos(fa))
                ups.append(o * math.sin(fa))
        ups.sort()
        up = ups[-1] + 0.35 * ups[-2] if len(ups) > 2 else ups[-1]
        return v3(p[0], p[1], up)

    def xf(p):
        return C + rot @ Vector(p)

    grid = []
    for i in range(rings + 1):
        row = []
        for j in range(segs):
            th = 2 * math.pi * j / segs
            ca, sa = math.cos(th), math.sin(th)
            r_in = math.hypot(crown_a * ca, crown_b * sa)
            r = r_in + (brim_r - r_in) * (i / rings)
            row.append(bm.verts.new(xf(fold(ca * r, sa * r))))
        grid.append(row)
    brim_faces = []
    for i in range(rings):
        for j in range(segs):
            a, b = grid[i][j], grid[i][(j + 1) % segs]
            c, d = grid[i + 1][(j + 1) % segs], grid[i + 1][j]
            brim_faces.append(bm.faces.new((a, d, c, b)))
    wall = []
    hs = [0.0, 0.35, 0.7, 1.0]
    for hh in hs:
        row = []
        for j in range(segs):
            th = 2 * math.pi * j / segs
            bulge = 1.0 + 0.04 * math.sin(math.pi * hh)
            row.append(bm.verts.new(xf((crown_a * bulge * math.cos(th), crown_b * bulge * math.sin(th), crown_h * hh))))
        wall.append(row)
    crown_faces = []
    for k in range(len(hs) - 1):
        for j in range(segs):
            a, b = wall[k][j], wall[k][(j + 1) % segs]
            c, d = wall[k + 1][(j + 1) % segs], wall[k + 1][j]
            crown_faces.append(bm.faces.new((a, b, c, d)))
    prev = wall[-1]
    for sc, dz in ((0.955, 0.0048), (0.86, 0.0088), (0.66, 0.0118), (0.38, 0.0132)):
        ring = []
        for j in range(segs):
            th = 2 * math.pi * j / segs
            ring.append(bm.verts.new(xf((crown_a * sc * math.cos(th), crown_b * sc * math.sin(th), crown_h + dz))))
        for j in range(segs):
            crown_faces.append(bm.faces.new((prev[j], prev[(j + 1) % segs], ring[(j + 1) % segs], ring[j])))
        prev = ring
    apex = bm.verts.new(xf((0, 0, crown_h + 0.0138)))
    for j in range(segs):
        crown_faces.append(bm.faces.new((prev[j], prev[(j + 1) % segs], apex)))
    bottom = bm.verts.new(xf((0, 0, 0.004)))
    for j in range(segs):
        crown_faces.append(bm.faces.new((wall[0][(j + 1) % segs], wall[0][j], bottom)))
    res = bmesh.ops.solidify(bm, geom=brim_faces, thickness=thick)
    for f in brim_faces + crown_faces + [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]:
        f.material_index = mi_felt
        f.smooth = True
    edge_verts = set(v for row in grid[rings - tape_rings + 1:] for v in row) if tape_rings > 1 else set(grid[-1])
    for f in bm.faces:
        if f.material_index == mi_felt and sum(1 for v in f.verts if v in edge_verts) >= 2:
            f.material_index = mi_trim
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    n = normals[1]
    p = fold(*(n[:2] * (chord + 0.032)))
    out = np.array(rot.to_3x3() @ Vector(n * math.sin(fa) - v3(0, 0, 1) * math.cos(fa)))
    return np.array(xf(p)) + out * 0.004, out, np.array(C), rot


def hat(ctx, spec, st):
    K = ctx.K
    hb = K["headb"]
    hp = Prims()
    center = hb + v3(0, -0.028, 0.104 - st["lower"])
    pc, pn, C, rot = tricorn(hp, 0, 1, center, tilt_deg=st["tilt"], crown_a=st["crown_a"], crown_b=st["crown_b"],
                             crown_h=st["crown_h"], brim_r=st["brim_r"], chord=st["chord"], fold_deg=st["fold"],
                             segs=36, rings=5, tape_rings=st["tape_rings"])
    if st["cockade"]:
        R = frame_from(pn, v3(0, 0, 1))
        # a pleated silk rosette (a flat disc with a raised centre) held by a loop and button
        hp.cylinder(pc + pn * 0.0022, pn, 0.024, 0.0036, mi=2, segs=16)
        hp.cylinder(pc + pn * 0.0045, pn, 0.014, 0.0022, mi=2, segs=12)
        up = R[:, 1]
        hp.box(pc + pn * 0.0048 + up * 0.010, (0.018, 0.0035, 0.0012), frame_from(pn, up), mi=1)
        hp.sphere(pc + pn * 0.0068 + up * 0.019, (0.0055, 0.0055, 0.0035), frame_from(pn, up), mi=3, segs=8, rings=4)
    ob = hp.to_object(spec.id, [material(spec.id + "_felt", "#1c1b20", 0.9), material(spec.id + "_tape", "#e8e3d3", 0.8),
                                material(spec.id + "_cockade", "#151417", 0.7), material(spec.id + "_metal", "#9a9c9a", 0.4)])
    set_sharp(ob, 60)
    zones = np.array([p.material_index for p in ob.data.polygons])

    def hat_uv(P):
        # box projection in the hat's frame: brim top / bottom from above, the crown wall
        # round its axis (metres)
        Rm = np.array(rot.to_3x3())
        q = (P - C) @ Rm
        ang = np.arctan2(q[:, 1], q[:, 0])
        wall = (q[:, 2] > 0.004) & (np.hypot(q[:, 0] / st["crown_a"], q[:, 1] / st["crown_b"]) < 1.06)
        u = np.where(wall, ang * 0.09, q[:, 0])
        v = np.where(wall, q[:, 2], q[:, 1])
        return np.stack([u, v], 1)

    pieces = [B.Piece(ob, "rigid", zone_fn=lambda C_, N, L: zones[:len(C_)] if len(C_) == len(zones) else np.zeros(len(C_), int),
                      uv=hat_uv, weights={"headb": 1.0})]
    return B.assemble(ctx, spec, pieces, smooth=None)
