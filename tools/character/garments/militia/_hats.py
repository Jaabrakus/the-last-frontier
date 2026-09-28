"""Felt hats of the militia set: the legacy tricorn of build_body.py (an elliptical crown and
a round brim folded up along three chords) generalized to the cut-down round hat of 1758
(no folds, a 2.5-inch brim). Built directly as bmesh (brim solidified, crown wall with a
rounded top edge and a low dome); the crown is open at the bottom (it sits on the head,
no closing fan inside the skull).

Faces carry a zone in material_index: 0 felt, 1 trim (binding tape / hat band),
2 cockade, 3 button.
"""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

from lib.remesh import link
from lib.sdf import frame_from, nrm, v3

HAT_CENTER = (0.0, -0.028, 0.104)      # crown base centre relative to headb (legacy)
HAT_TILT = -7.0                         # deg about x, front edge down


def felt_hat(center, tilt_deg, crown_a, crown_b, crown_h, brim_w, folds=None, segs=40, rings=6, thick=0.0045,
             tape_rings=1, band_h=0.0, droop=0.0, fold_soft=0.35):
    """bmesh of a felt hat. brim_w: brim width beyond the crown ellipse (float or fn(theta)).
    folds: None (flat brim) or (chord, fold_deg) for a cocked (three-cornered) brim.
    band_h: height of a hat band (zone 1) round the crown base. droop: the brim edge sags
    by this much (m). Returns (bm, cockade point, cockade normal)."""
    bm = bmesh.new()
    rot = Matrix.Rotation(math.radians(tilt_deg), 4, "X")
    C = Vector(center)
    normals = [v3(0, 1, 0), v3(math.sin(math.radians(120)), -0.5, 0), v3(-math.sin(math.radians(120)), -0.5, 0)]

    def fold(px, py):
        p = v3(px, py, 0.0)
        if folds is None:
            return p
        chord, fold_deg = folds
        fa = math.radians(fold_deg)
        ups = [0.0]
        for n in normals:
            o = p[0] * n[0] + p[1] * n[1] - chord
            if o > 0:
                p = p - n * o * (1 - math.cos(fa))
                ups.append(o * math.sin(fa))
        ups.sort()
        up = ups[-1] + fold_soft * ups[-2] if len(ups) > 2 else ups[-1]
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
            w = brim_w(th) if callable(brim_w) else brim_w
            f = i / rings
            r = r_in + w * f
            p = fold(ca * r, sa * r)
            p = p - v3(0, 0, droop * f * f)
            row.append(bm.verts.new(xf(p)))
        grid.append(row)
    brim_faces = []
    for i in range(rings):
        for j in range(segs):
            a, b = grid[i][j], grid[i][(j + 1) % segs]
            c, d = grid[i + 1][(j + 1) % segs], grid[i + 1][j]
            brim_faces.append(bm.faces.new((a, d, c, b)))
    wall = []
    hs = [0.0] + ([band_h / crown_h] if band_h > 0 else []) + [0.35, 0.7, 1.0]
    hs = sorted(set(hs))
    for hh in hs:
        row = []
        for j in range(segs):
            th = 2 * math.pi * j / segs
            bulge = 1.0 + 0.04 * math.sin(math.pi * hh)
            row.append(bm.verts.new(xf((crown_a * bulge * math.cos(th), crown_b * bulge * math.sin(th), crown_h * hh))))
        wall.append(row)
    crown_faces, band_faces = [], []
    for k in range(len(hs) - 1):
        for j in range(segs):
            a, b = wall[k][j], wall[k][(j + 1) % segs]
            c, d = wall[k + 1][(j + 1) % segs], wall[k + 1][j]
            f = bm.faces.new((a, b, c, d))
            (band_faces if band_h > 0 and hs[k + 1] <= band_h / crown_h + 1e-6 else crown_faces).append(f)
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
    res = bmesh.ops.solidify(bm, geom=brim_faces, thickness=thick)
    solid = [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]
    for f in brim_faces + crown_faces + solid:
        f.material_index = 0
        f.smooth = True
    for f in band_faces:
        f.material_index = 1
        f.smooth = True
    # binding tape: the faces at the brim edge (the outer rings of both sides and the rim)
    edge_verts = set()
    bm.faces.index_update()
    crown_ids = {f.index for f in crown_faces}
    for i in range(max(rings + 1 - tape_rings, 1), rings + 1):
        edge_verts |= set(grid[i])
    for f in bm.faces:
        if f.material_index == 0 and f.index not in crown_ids and sum(1 for v in f.verts if v in edge_verts) >= 2:
            f.material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    # cockade: on the outer face of the left-front brim wall (cocked hats)
    n = normals[1]
    if folds is not None:
        chord, fold_deg = folds
        fa = math.radians(fold_deg)
        p = fold(*(n[:2] * (chord + 0.032)))
        out = np.array(rot.to_3x3() @ Vector(n * math.sin(fa) - v3(0, 0, 1) * math.cos(fa)))
    else:
        th = math.radians(-60.0)
        p = v3(crown_a * math.cos(th) * 1.04, crown_b * math.sin(th) * 1.04, band_h * 0.5)
        out = nrm(np.array(rot.to_3x3() @ Vector(v3(math.cos(th) / crown_a, math.sin(th) / crown_b, 0))))
    return bm, np.array(xf(p)) + out * 0.004, out


def add_cockade(bm, pc, pn, r=0.021, button_r=0.006):
    """Ribbon cockade (a disc, zone 2) with a button (zone 3) at its centre."""
    from lib.remesh import _perp
    R = frame_from(pn, _perp(pn))
    M = Matrix.Identity(4)
    res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=20, radius1=1.0, radius2=1.0, depth=1.0)
    A = R @ np.diag((r, r, 0.004))
    for i in range(3):
        for j in range(3):
            M[i][j] = A[i, j]
        M[i][3] = (pc + pn * 0.002)[i]
    bmesh.ops.transform(bm, matrix=M, verts=res["verts"])
    for f in {f for v in res["verts"] for f in v.link_faces}:
        f.material_index = 2
        f.smooth = True
    res = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=1.0)
    A = R @ np.diag((button_r, button_r, 0.004))
    M = Matrix.Identity(4)
    for i in range(3):
        for j in range(3):
            M[i][j] = A[i, j]
        M[i][3] = (pc + pn * 0.005)[i]
    bmesh.ops.transform(bm, matrix=M, verts=res["verts"])
    for f in {f for v in res["verts"] for f in v.link_faces}:
        f.material_index = 3
        f.smooth = True


def to_object(bm, name, mats):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    for m in mats:
        me.materials.append(m)
    return ob


def hat_uvs(ob, center, M):
    """Brim (and top) faces facing up or down: a planar map seen from above; walls: a
    cylinder round the vertical axis through the crown."""
    N = M.poly_normals(ob)
    part = np.where(np.abs(N[:, 2]) > 0.55, 1, 0)
    c = np.asarray(center, float)
    maps = [M.Cyl(c, c + v3(0, 0, 1), v3(0, -1, 0)), M.Flat(c, v3(1, 0, 0), v3(0, -1, 0))]
    return M.loop_uvs(ob, maps, part)
