"""Thủy Vân ROCK kit, authored procedurally in Blender (our own shapes after the owner's Trường Sơn / Thạch Uyên sheets,
in the style guide's WoW-Classic spirit: chunky, exaggerated, painted). Re-runnable and deterministic (fixed seeds).
Run headless (through the shared lock):

    zsh <plan>/bin/blender_run.sh -b -P tools/thuyvan_art/rock/rock_kit.py -- --out assets/thuyvan/rock [--blend x]

(rock_render.py imports this module, builds the same kit, exports it and renders the lineups.)

Writes into --out (glTF binary, +Y up; Blender -Y = Godot +Z = the piece's front; origins as listed):
    karst_hero_a..e.glb (+ _lod1)   R01 hero towers 110-240 m: leaning, 3-6 stacked slab tiers stepping in, vertical
                                    fluting, undercut foot or waist on some, flat-ish crowns; ledges = pine/house seats
    karst_far_a..f.glb              R02 backdrop towers (about 1-1.6k tris), modelled 200 m tall: scale to the K height
    cliff_<kind>_<h>.glb (+ _lod1)  R03 gorge-wall modules 40 m wide: straight / convex / concave / notch (waterfall)
                                    / ledge (house seat); strata 7 m; origin on the top lip's centre, the face hangs
                                    down to -h and faces +Z; left/right edges share one profile so modules chain
    boulder_a..f.glb (+ _lod1)      R04 limestone boulders 1-6 m; origin on the ground (20% of the height sunk)
    white_stones.glb (+ _lod1)      R05 the 12 Đá Trắng stones (one node each, white_stone_00..11), 0.3-3 m;
                                    origin on the ground (25% sunk); white_stones_c1.json (scatter) places them
    two_heights_bridge.glb (+_lod1) R06 the arched stone bridge: two piers 100 m tall from the deck, a two-tier centre
                                    bay, side arches, deck, parapets, turrets; TWO MAKER SIGNS on the north pier's east
                                    face; bolt plates with frayed offerings. Origin: the deck surface between the piers
    two_heights_head_n/_s.glb       R06 the two natural stone heads (89 / 77 m), flat crowns with a gate-tower seat
    bridge_needle.glb (+ _lod1)     R07 the white-limestone pillar 62 m above the riverbed, a 5 m flat cap
    cairn_a..e.glb                  R08 burial cairns 1.2-2.2 m
    rock_kit.json                   per piece: Godot-frame size, tris per LOD, material keys, seats (pine / house /
                                    gate_tower / banner / fall_lip / rag_tie / platform) in the piece's Godot frame

Materials are named for their keys (see MATS); base colours are the ramp's mid tint. Vertex colour (COLOR_0): RGB =
baked occlusion x a top-light gradient (mean 0.85, clamped 0.5-1.0); A = moss mask. UVs are a box projection in metres
/ the key's tile, so a plain StandardMaterial3D with the key's texture also works; the intended material is
assets/thuyvan/rock/painted_rock.gdshader (world triplanar) via the .tres files in assets/thuyvan/rock/materials.
"""

import argparse
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
PALETTES = os.path.join(HERE, "..", "..", "..", "docs", "thuyvan", "plan", "look", "palettes.json")
_PAL = json.load(open(PALETTES))


def _hex(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def ramp(key, zone="r1"):
    return [_hex(h) for h in _PAL["albedo"][zone][key]]


# material key -> (texture file, tile metres, ramp for the tint)
MATS = {
    "rock_karst": ("karst_face.png", 16.0, ramp("karst_limestone")[1]),
    "rock_boulder": ("karst_face.png", 6.0, ramp("karst_limestone")[1]),
    "rock_pale": ("karst_pale.png", 12.0, ramp("white_stone")[1]),
    "stone_white": ("white_stone.png", 4.0, ramp("white_stone")[2]),
    "ashlar": ("ashlar.png", 8.0, ramp("worked_block", "thach_uyen")[1]),
    "moss": ("moss_cap.png", 4.0, ramp("moss")[1]),
    "carve": (None, 4.0, ramp("worked_block", "thach_uyen")[0]),
    "iron": (None, 4.0, ramp("iron")[2]),
    "cloth_madder": (None, 1.0, ramp("madder_cloth")[1]),
    "cloth_bone": (None, 1.0, ramp("bone_cloth")[1]),
    "cloth_indigo": (None, 1.0, ramp("indigo_cloth")[1]),
    "cloth_ochre": (None, 1.0, ramp("ochre_cloth")[1]),
}


def srgb_to_linear(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def key_material(name):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        r, g, b = srgb_to_linear(MATS[name][2])
        bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.92
    return m


def smoothstep(a, b, x):
    t = np.clip((np.asarray(x, float) - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


class Builder:
    """Faces per material key into one bmesh (one kit piece), as ring_kit.py's Builder."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []
        self.seats = []
        self.wl = self.bm.verts.layers.float.new("wet")   # wet factor: darkens the baked AO (the falls' chutes)
        self.sl = self.bm.verts.layers.float.new("tshade")   # painted slab light: 1 at a slab's top, darker below
        self.box_faces = []                                  # (face, box centre): re-aimed outward after recalc

    def mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def face(self, pts, mat, smooth=False):
        vs = [self.bm.verts.new(Vector(p)) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = self.mi(mat)
        f.smooth = smooth
        return f

    def face_out(self, pts, mat, d):
        """A face that must face direction d whatever recalc decides (a lone quad has no inside to tell it)."""
        f = self.face(pts, mat)
        c = Vector(np.mean(np.asarray(pts, float), axis=0)) - Vector(d)
        self.box_faces.append((f, c))
        return f

    def grid(self, P, mat, smooth=True, flip=False, close_cols=False):
        """P: (rows, cols, 3) quad grid. close_cols: the last column wraps to the first (a ring)."""
        rows, cols = P.shape[0], P.shape[1]
        V = [[self.bm.verts.new(Vector(P[i, j])) for j in range(cols)] for i in range(rows)]
        k = self.mi(mat)
        jmax = cols if close_cols else cols - 1
        for i in range(rows - 1):
            for j in range(jmax):
                j1 = (j + 1) % cols
                q = [V[i][j], V[i][j1], V[i + 1][j1], V[i + 1][j]]
                if flip:
                    q = q[::-1]
                f = self.bm.faces.new(q)
                f.material_index = k
                f.smooth = smooth
        return V

    def box(self, c, s, mat, rot=None):
        c, s = np.asarray(c, float), np.asarray(s, float) / 2.0
        R = np.eye(3) if rot is None else np.asarray(rot, float)
        corners = np.array([[x, y, z] for z in (-1, 1) for y in (-1, 1) for x in (-1, 1)]) * s
        P = corners @ R.T + c
        idx = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
        for q in idx:
            self.box_faces.append((self.face([P[i] for i in q], mat), Vector(c)))

    def prism(self, poly, z0, z1, mat, cap_top=True, cap_bottom=True):
        """A vertical prism of a CCW polygon [(x, y)] from z0 to z1."""
        n = len(poly)
        P = np.array([[[x, y, z] for (x, y) in poly] for z in (z0, z1)])
        V = self.grid(P, mat, smooth=False, close_cols=True)
        k = self.mi(mat)
        if cap_bottom:
            self.bm.faces.new([V[0][j] for j in range(n)][::-1]).material_index = k
        if cap_top:
            self.bm.faces.new([V[1][j] for j in range(n)]).material_index = k

    def seat(self, kind, p_blender, r=1.0, **kw):
        x, y, z = p_blender
        d = {"kind": kind, "pos": [round(float(x), 2), round(float(z), 2), round(float(-y), 2)], "r": round(float(r), 2)}
        d.update(kw)
        self.seats.append(d)


# ------------------------------------------------------------------------------------------------ finishing
def finish(b, ao_dist, ground=True, moss_faces=None, moss_rule=(0.45, 0.85), moss_gain=1.0, sharp_deg=48.0,
           recalc=True, expect_front=None):
    """bmesh -> object: normals, moss faces (faces with normal z > moss_faces get key 'moss'), box UVs in metres /
    tile, vertex colour RGB = AO x top light (mean 0.85, 0.5-1.0), A = moss mask."""
    bm = b.bm
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    for f, c in b.box_faces:         # boxes inside a larger shell can be turned inward by recalc: aim them out
        if f.is_valid and (f.calc_center_median() - c).dot(f.normal) < 0:
            f.normal_flip()
    bm.normal_update()
    if expect_front is not None:
        avg = sum((f.normal * f.calc_area() for f in bm.faces), Vector())
        if avg.dot(Vector(expect_front)) < 0:
            for f in bm.faces:
                if b.mats[f.material_index] != "moss":      # mounds are closed and already face out
                    f.normal_flip()
            bm.normal_update()
    if moss_faces is not None:
        km = b.mi("moss")
        rock_keys = {b.mi(k) for k in ("rock_karst", "rock_boulder", "rock_pale") if k in b.mats}
        for f in bm.faces:
            if f.material_index in rock_keys and f.normal.z > moss_faces:
                f.material_index = km
    for f in bm.faces:
        f.smooth = True
    # box UVs per face
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        tile = MATS[b.mats[f.material_index]][1]
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for lp in f.loops:
            co = lp.vert.co
            if ax == 2:
                u, v = co.x, co.y
            elif ax == 0:
                u, v = co.y * (1 if n.x > 0 else -1), co.z
            else:
                u, v = co.x * (-1 if n.y > 0 else 1), co.z
            lp[uv].uv = (u / tile, v / tile)
    me = bpy.data.meshes.new(b.name)
    bm.to_mesh(me)
    nverts = len(bm.verts)
    bm.free()
    for m in b.mats:
        me.materials.append(key_material(m))
    try:
        me.set_sharp_from_angle(angle=math.radians(sharp_deg))
    except Exception:
        pass
    if "moss" in b.mats and "sharp_edge" in me.attributes:
        # shrub mounds are soft balls: no hard edges inside them, whatever the angle
        km = b.mats.index("moss")
        soft = set()
        for poly in me.polygons:
            if poly.material_index == km:
                soft.update(poly.edge_keys)
        sh = me.attributes["sharp_edge"].data
        for e in me.edges:
            if e.key in soft:
                sh[e.index].value = False
    ob = bpy.data.objects.new(b.name, me)
    bpy.context.scene.collection.objects.link(ob)
    bake_vertex_colour(ob, ao_dist, ground, moss_rule, moss_gain)
    ob["seats"] = json.dumps(b.seats)
    ob["mats"] = json.dumps(b.mats)
    return ob


_DIRS = None


def _hemi(nrays=24, seed=7):
    global _DIRS
    if _DIRS is None:
        rng = np.random.default_rng(seed)
        u1, u2 = rng.random(nrays), rng.random(nrays)
        r, phi = np.sqrt(u1), 2 * math.pi * u2
        _DIRS = np.stack([r * np.cos(phi), r * np.sin(phi), np.sqrt(1 - u1)], -1)   # cosine-weighted, +Z hemisphere
    return _DIRS


def bake_vertex_colour(ob, dist, ground, moss_rule, moss_gain):
    """Occlusion by BVH ray casts (deterministic; no Cycles), 70/30 with a world-Z gradient; A = moss mask."""
    me = ob.data
    verts = [v.co.copy() for v in me.vertices]
    polys = [tuple(p.vertices) for p in me.polygons]
    zmin = min(v.z for v in verts)
    zmax = max(v.z for v in verts)
    if ground:
        big = 1e5
        g0 = len(verts)
        verts += [Vector((-big, -big, 0.0)), Vector((big, -big, 0.0)), Vector((big, big, 0.0)), Vector((-big, big, 0.0))]
        polys.append((g0, g0 + 1, g0 + 2, g0 + 3))
    tree = BVHTree.FromPolygons(verts, polys, all_triangles=False)
    D = _hemi()
    nv = len(me.vertices)
    ao = np.ones(nv)
    nz = np.zeros(nv)
    for i, v in enumerate(me.vertices):
        n = v.normal
        nz[i] = n.z
        t = n.orthogonal().normalized()
        bt = n.cross(t)
        o = v.co + n * 0.03
        hit = 0.0
        for d in D:
            w = t * d[0] + bt * d[1] + n * d[2]
            loc, _n, _i, dd = tree.ray_cast(o, w, dist)
            if loc is not None:
                hit += 1.0 - 0.5 * (dd / dist)
        ao[i] = 1.0 - hit / len(D)
    zs = np.array([v.co.z for v in me.vertices])
    g = 0.55 + 0.45 * np.clip((zs - zmin) / max(zmax - zmin, 1e-6), 0, 1) ** 0.7
    up = 0.5 + 0.5 * nz
    val = 0.7 * ao + 0.3 * (0.6 * g + 0.4 * up)
    if "wet" in me.attributes:
        wet = np.zeros(nv)
        me.attributes["wet"].data.foreach_get("value", wet)
        val *= 1.0 - 0.4 * wet
        me.attributes.remove(me.attributes["wet"])
    if "tshade" in me.attributes:
        ts = np.zeros(nv)
        me.attributes["tshade"].data.foreach_get("value", ts)
        val *= np.where(ts > 0, ts, 1.0)          # 0 = not painted (mounds, boxes): unchanged
        me.attributes.remove(me.attributes["tshade"])
    val = np.clip(val / max(val.mean(), 1e-6) * 0.85, 0.5, 1.0)
    moss = smoothstep(moss_rule[0], moss_rule[1], nz) * (0.45 + 0.55 * ao) * moss_gain
    col = np.stack([val, val, val, np.clip(moss, 0, 1)], -1).astype(np.float32)
    attr = me.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
    attr.data.foreach_set("color", col.ravel())
    me.color_attributes.active_color = attr
    try:
        me.color_attributes.render_color_index = me.color_attributes.active_color_index
    except Exception:
        pass


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


# ------------------------------------------------------------------------------------------------ karst towers
# A tower is a CLUSTER of faceted slab columns (the sheets' karst: sheer vertical slabs bundled together, each
# stepping in at ledges, a rounded green crown), not one turned solid. Columns share the tower's lean so the cluster
# leans as one. Every ledge and crown carries shrub mounds (key "moss"): the green caps that read from a kilometre
# before any tree is placed; their tops are pine seats.
def _plan(rng, sides, pinch=0.72, lump=0.12):
    """A column's faceted plan: per-vertex radius factors, every other vertex pinched in (the vertical clefts)."""
    th = np.linspace(0, 2 * math.pi, sides, endpoint=False) + rng.uniform(0, 2 * math.pi)
    rho = rng.uniform(1 - lump, 1 + lump, sides)
    rho[1::2] *= pinch * rng.uniform(0.94, 1.06, len(rho[1::2]))
    th = th + rng.uniform(-0.18, 0.18, sides) * (2 * math.pi / sides)
    return th, rho


def mound(b, c, r, rng, flat=0.55, sub=1):
    """A shrub mound (key 'moss'): a lumpy, flattened icosphere half sunk at c (Blender coords)."""
    s = bmesh.new()
    bmesh.ops.create_icosphere(s, subdivisions=sub, radius=1.0)
    ph = rng.uniform(0, 6.283, 3)
    ry = rng.uniform(0.8, 1.0)
    vm = {}
    for v in s.verts:
        p = np.array(v.co)
        k = 1 + 0.16 * math.sin(3 * p[0] + ph[0]) * math.cos(2 * p[1] + ph[1]) + 0.08 * math.sin(4 * p[2] + ph[2])
        q = p * k * np.array([r, r * ry, r * flat])
        lo = -0.25 * r * flat
        if q[2] < lo:
            q[2] = lo + (q[2] - lo) * 0.3
        vm[v] = b.bm.verts.new(Vector(np.asarray(c, float) + q))
    k = b.mi("moss")
    for f in s.faces:
        nf = b.bm.faces.new([vm[v] for v in f.verts])
        nf.material_index = k
    s.free()


def add_column(b, cx, cy, z_base, h, r, tiers, sides, lean_fn, rng, mat, lod, undercut=None, step=(0.8, 0.9),
               crown=0.06, flat_top=0.0, mounds=True, seats=True, mound_scale=1.0, crown_ring=(0.0, 0.6),
               crown_mounds=True, far=False, main=True):
    """One faceted slab column from z_base to z_base + h (plus a 6 m buried foot), `tiers` tiers stepping in at
    ledges. Returns (top centre, top radius)."""
    crown_h = crown * h
    body = h - crown_h
    fr = rng.uniform(0.75, 1.25, tiers)
    fr[0] *= 1.25
    fr /= fr.sum()
    zt = z_base + np.concatenate([[0.0], np.cumsum(fr) * body])
    s = [1.0]
    for _ in range(1, tiers):
        s.append(s[-1] * rng.uniform(*step))
    jit = [np.zeros(2)] + [rng.uniform(-0.10, 0.10, 2) * r for _ in range(1, tiers)]
    plans = [_plan(rng, sides) for _ in range(tiers)]
    bev = float(np.clip(0.05 * r, 0.3, 1.5))

    def ring(t, z, rad):
        th, rho = plans[t]
        c = lean_fn(z) + np.array([cx, cy]) + jit[t]
        xy = c[None, :] + (rad * rho)[:, None] * np.stack([np.cos(th), np.sin(th)], -1)
        return np.column_stack([xy, np.full(sides, z)]), c

    rows = []
    shade = []          # per row: the painted slab light (top of a slab lit, its foot in shade)
    ledges = []
    nmid = 1 if lod else 2
    for t in range(tiers):
        z0, z1 = zt[t], zt[t + 1]
        rb = r * s[t]
        fz = [0.0] + [(i + 1) / (nmid + 1) for i in range(nmid)] + [1.0]
        for i, f in enumerate(fz):
            z = z0 + f * (z1 - z0 - bev)
            k = 1 + 0.05 * math.sin(math.pi * f) - 0.05 * f
            if t == 0 and undercut == "foot":
                k *= 0.72 + 0.28 * smoothstep(0.0, 0.4, f)
            if t == 1 and undercut == "waist":
                k *= 1 - 0.2 * math.sin(math.pi * f)
            P, c = ring(t, z, rb * k)
            if i == 0 and rows:
                # the tier's foot sits inside the bevel ring below it: the flat between them is the ledge
                pb, pc = rows[-1]
                d = P[:, :2] - pc
                L = np.linalg.norm(d, axis=1)
                Lp = np.linalg.norm(pb[:, :2] - pc, axis=1)
                P[:, :2] = pc + d * (np.minimum(L, Lp - 1.0) / np.maximum(L, 1e-6))[:, None]
                ledges.append((pb, P))
            rows.append((P, c))
            shade.append(0.62 + 0.38 * f ** 0.8)
        # the bevel ring: the slab's rounded top edge
        P, c = ring(t, z1, rb * 0.92 - bev)
        rows.append((P, c))
        shade.append(1.0)
    # crown: a rounded, flat-ish top
    P_top, c_top = rows[-1]
    top = zt[-1]
    nd = 2 if lod else 3
    for i in range(1, nd + 1):
        f = i / nd
        rr = max((1 - f) ** 0.7, flat_top) if i < nd else 0.15
        zz = top + crown_h * (1 - (1 - f) ** 2)
        Q = P_top.copy()
        Q[:, :2] = c_top + (P_top[:, :2] - c_top) * rr
        Q[:, 2] = zz
        rows.append((Q, c_top))
        shade.append(1.0)
    # buried foot
    P0, c0 = rows[0]
    F = P0.copy()
    F[:, :2] = c0 + (P0[:, :2] - c0) * 1.05
    F[:, 2] = z_base - 6.0
    rows.insert(0, (F, c0))
    shade.insert(0, 0.55)
    V = b.grid(np.array([q[0] for q in rows]), mat, close_cols=True)
    for i, row in enumerate(V):
        for v in row:
            v[b.sl] = shade[i]
    b.bm.faces.new([V[-1][j] for j in range(sides)]).material_index = b.mi(mat)
    top_c = np.array([c_top[0], c_top[1], rows[-1][0][:, 2].mean()])
    top_r = float(np.linalg.norm(P_top[:, :2] - c_top, axis=1).mean())
    # mounds and seats on the ledges and the crown
    for pb, P in ledges:
        for j in range(0, sides, 3 if (lod or far) else 2):
            a, q = pb[j], P[j]
            w = float(np.linalg.norm(a[:2] - q[:2]))
            if w < 1.5:
                continue
            m = (a + q) / 2
            if mounds and rng.random() < 0.85:
                mr = float(np.clip(max(w * 1.1, 0.16 * r), 2.5, 10.0)) * mound_scale
                mound(b, m + np.array([0, 0, -0.15 * mr]), mr, rng, flat=0.85, sub=1)
                if seats:
                    b.seat("pine", m + np.array([0, 0, mr * 0.4]), r=mr * 0.6)
            elif seats:
                b.seat("house" if w > 7.0 else "pine", m, r=w / 2, ledge_w=round(w, 1))
    if mounds and crown_mounds:
        # the crown: a dome of shrub mounds over the whole top (the sheets' wooded caps)
        nm = (int(rng.integers(5, 9)) if main else int(rng.integers(2, 4))) if (lod == 0 and not far) else 3
        for k in range(nm):
            a = rng.uniform(0, 2 * math.pi)
            d = rng.uniform(*crown_ring) * top_r * 1.15
            mr = float(np.clip(top_r * rng.uniform(0.4, 0.7), 2.5, 14.0)) * mound_scale
            p = top_c + np.array([math.cos(a) * d, math.sin(a) * d, -crown_h * 0.3])
            mound(b, p, mr, rng, flat=0.75, sub=2 if (lod == 0 and main and not far) else 1)
            if seats:
                b.seat("pine", p + np.array([0, 0, mr * 0.45]), r=mr * 0.5, crown=True)
    if mounds:
        # shrubs clinging to the faces: mounds sunk into the wall at random rows (more toward the foot and in the
        # clefts, where soil gathers), so the green runs down the tower as in the sheets
        nrows = len(rows) - nd - 2
        nf = int(h / (16.0 if (lod == 0 and not far) else 45.0) * min(mound_scale, 1.2))
        for k in range(nf):
            i = 1 + int(rng.integers(0, max(nrows, 1)) * rng.uniform(0.3, 1.0))
            P, c = rows[min(i, len(rows) - 1)]
            j = int(rng.integers(0, sides // 2)) * 2 + 1          # the pinched (cleft) vertices
            j = j % sides
            q = P[j]
            out = q[:2] - c
            out = out / max(np.linalg.norm(out), 1e-6)
            mr = float(np.clip(r * rng.uniform(0.18, 0.3), 2.5, 8.0)) * mound_scale
            ctr = np.array([q[0] + out[0] * mr * 0.15, q[1] + out[1] * mr * 0.15, q[2]])
            mound(b, ctr, mr, rng, flat=0.8, sub=1)
    return top_c, top_r


def add_tower(b, p, lod, offset=(0, 0, 0), mat="rock_karst", seats=True):
    """The cluster: the main column (H, all tiers) and p['cols']-1 lower columns bundled against it. Returns the
    main column's (top centre, top radius) in the builder's frame."""
    rng = np.random.default_rng(p["seed"])
    H, R0 = p["H"], p["R0"]
    lean = math.radians(p["lean"])
    ld = math.radians(p["lean_dir"])
    off = np.asarray(offset, float)

    def lean_fn(z):
        k = math.tan(lean) * H * (max(z, 0.0) / H) ** p.get("lean_curve", 1.3)
        return np.array([math.cos(ld) * k, math.sin(ld) * k])

    sides = p["sides"][lod]
    sides_sub = max(5, sides - 2)
    ncols = p.get("cols", 4)
    main_r = R0 * (0.72 if ncols > 1 else 1.0)
    top = add_column(b, off[0], off[1], off[2], H, main_r, p["tiers"], sides, lean_fn, rng, mat, lod,
                     undercut=p.get("undercut"), step=p.get("step", (0.8, 0.9)), crown=p.get("crown", 0.06),
                     flat_top=p.get("flat_top", 0.0), mounds=p.get("mounds", True), seats=seats,
                     mound_scale=p.get("mound_scale", 1.0), crown_ring=p.get("crown_ring", (0.0, 0.6)),
                     crown_mounds=p.get("crown_mounds", True), far=p.get("far", False))
    base_ang = rng.uniform(0, 2 * math.pi)
    for k in range(1, ncols):
        a = base_ang + 2 * math.pi * k / (ncols - 1) + rng.uniform(-0.5, 0.5)
        hk = H * rng.uniform(*p.get("sub_h", (0.35, 0.8)))
        rk = R0 * rng.uniform(0.38, 0.55)
        d = main_r * rng.uniform(0.55, 0.85)
        tk = max(1, int(round(p["tiers"] * hk / H)))
        add_column(b, off[0] + math.cos(a) * d, off[1] + math.sin(a) * d, off[2], hk, rk, tk, sides_sub, lean_fn,
                   rng, mat, lod, step=p.get("step", (0.8, 0.9)), crown=0.08, mounds=p.get("mounds", True),
                   seats=seats, mound_scale=p.get("mound_scale", 1.0), far=p.get("far", False), main=False)
    return top


HERO = {
    # 110-240 m, 2.5-5 x as tall as wide, leaning 5-15 deg, 3-6 tiers, a third undercut; R0 = the cluster's radius
    "karst_hero_a": dict(H=110, R0=22, tiers=3, cols=3, lean=8, lean_dir=20, seed=11, undercut="foot"),
    "karst_hero_b": dict(H=170, R0=30, tiers=4, cols=4, lean=12, lean_dir=160, seed=12),
    "karst_hero_c": dict(H=240, R0=38, tiers=6, cols=5, lean=6, lean_dir=70, seed=13, step=(0.84, 0.93)),
    "karst_hero_d": dict(H=140, R0=24, tiers=4, cols=3, lean=14, lean_dir=-40, seed=14, undercut="waist"),
    "karst_hero_e": dict(H=200, R0=30, tiers=5, cols=4, lean=10, lean_dir=110, seed=15,
                         twin=dict(H=135, R0=21, tiers=4, cols=3, lean=15, lean_dir=290, seed=16, at=(-30, 20))),
}
FAR = {
    # backdrop: modelled 200 m, ~1-2k tris; scale uniformly to the K height
    "karst_far_a": dict(H=200, R0=24, tiers=4, cols=3, lean=6, lean_dir=30, seed=31),
    "karst_far_b": dict(H=200, R0=18, tiers=5, cols=2, lean=12, lean_dir=200, seed=32, undercut="foot"),
    "karst_far_c": dict(H=200, R0=34, tiers=3, cols=4, lean=4, lean_dir=90, seed=33, step=(0.66, 0.78)),
    "karst_far_d": dict(H=200, R0=21, tiers=4, cols=3, lean=15, lean_dir=-60, seed=34, undercut="waist"),
    "karst_far_e": dict(H=200, R0=26, tiers=3, cols=3, lean=7, lean_dir=140, seed=35,
                        twin=dict(H=150, R0=18, tiers=3, cols=2, lean=12, lean_dir=320, seed=36, at=(-28, 12))),
    "karst_far_f": dict(H=200, R0=28, tiers=5, cols=3, lean=9, lean_dir=250, seed=37, step=(0.82, 0.9)),
}
HERO_DEF = dict(sides=(11, 7))
FAR_DEF = dict(sides=(7, 5), mound_scale=1.4, far=True)


def karst(name, spec, lod, defaults, mat="rock_karst", moss=0.62, seats=True):
    p = dict(defaults)
    p.update({k: v for k, v in spec.items() if k != "twin"})
    b = Builder(name + ("_lod1" if lod else ""))
    add_tower(b, p, lod, mat=mat, seats=seats and lod == 0)
    if "twin" in spec:
        q = dict(defaults)
        q.update({k: v for k, v in spec["twin"].items() if k != "at"})
        ax, ay = spec["twin"]["at"]
        add_tower(b, q, lod, offset=(ax, ay, 0), mat=mat, seats=seats and lod == 0)
    return finish(b, ao_dist=15.0 if lod == 0 else 25.0, moss_faces=moss, sharp_deg=32.0)


# ------------------------------------------------------------------------------------------------ cliff walls
WALL_W = 40.0
STRATA = 7.0


def _shared_bands(nb):
    """Band depths shared by every module (so the edges chain): a ledge (the face above steps back 3-4.5 m) on every
    third boundary, otherwise +-1.2 m (overhangs included), mean reverting."""
    rng = np.random.default_rng(4242)
    D = [0.0]
    for b in range(1, nb + 1):
        if b % 3 == 2:
            D.append(D[-1] - rng.uniform(3.0, 4.5))      # the band below protrudes: a ledge on top of it
        else:
            D.append(D[-1] * 0.5 + rng.uniform(-1.2, 1.2))
    return np.array(D)


def _xvar(x, z, phases, amps, W):
    v = np.zeros_like(x)
    for k, (ph, a) in enumerate(zip(phases, amps), start=1):
        v += a * np.cos(2 * math.pi * k * x / W + ph + 0.02 * z * k)
    return v


def wall_profile(x, Hw, kind, rng_mod, shared, lod):
    """The column at x: [(z, depth)] top lip (back on the ground) -> face -> buried foot. depth > 0 = into the rock."""
    nb = int(math.ceil(Hw / STRATA))
    D = shared["D"][:nb + 1]
    W = WALL_W
    ew = smoothstep(0.30 * W, 0.5 * W, abs(x))
    pts = []

    def depth(b, z):
        v_mod = _xvar(np.array([x]), z, shared["mod_ph"][b % len(shared["mod_ph"])], shared["mod_amp"], W)[0]
        v_edge = _xvar(np.array([x]), z, shared["edge_ph"][b % len(shared["edge_ph"])], shared["edge_amp"], W)[0]
        v = v_mod * (1 - ew) + v_edge * ew
        fl = shared["flute_d"] * (0.5 + 0.5 * math.cos(2 * math.pi * shared["flute_m"] * x / W + shared["flute_ph"]
                                                      + 0.04 * z)) ** 6 * (1 - ew)
        fl += 0.45 * shared["flute_d"] * (0.5 + 0.5 * math.cos(2 * math.pi * (2 * shared["flute_m"] + 1) * x / W
                                                               + 2.1 * shared["flute_ph"] - 0.03 * z)) ** 4 * (1 - ew)
        d = D[b] + v + fl - 0.04 * z                     # a slight batter: deeper toward the top
        if kind == "notch":
            bump = float(smoothstep(6.0, 2.5, abs(x)))
            d += 1.8 * bump
        if kind == "ledge" and b == 0:
            bump = float(smoothstep(12.0, 7.0, abs(x)))
            d += 8.0 * bump
        return d

    lip_drop = 0.0
    if kind == "notch":
        lip_drop = 5.0 * float(smoothstep(5.0, 1.5, abs(x)))
    z_top = -lip_drop
    d0 = depth(0, z_top)
    # the lip: ground strip 10 m back, a rounded edge
    pts += [(z_top, d0 + 10.0), (z_top, d0 + 1.6), (z_top - 0.25, d0 + 0.5), (z_top - 0.9, d0 + 0.05)]
    nin = 2 if lod == 0 else 1
    bev = 0.6
    for b in range(nb):
        zb_top = max(-STRATA * b, z_top - 1.0) if b == 0 else -STRATA * b
        zb_bot = -min(STRATA * (b + 1), Hw)
        if b == 0:
            zb_top = z_top - 1.0
        for i in range(1, nin + 1):
            z = zb_top + (zb_bot - zb_top) * i / (nin + 1)
            pts.append((z, depth(b, z)))
        if b < nb - 1:
            a, c = depth(b, zb_bot), depth(b + 1, zb_bot)
            if a >= c:      # the band below protrudes: a shelf
                bb = min(bev, (a - c) / 2 + 0.01)
                pts += [(zb_bot, a), (zb_bot, c + bb), (zb_bot - bb, c)]
            else:           # the band below sits back: an overhang
                bb = min(bev, (c - a) / 2 + 0.01)
                pts += [(zb_bot + bb, a), (zb_bot, a + bb), (zb_bot, c)]
    dl = depth(nb - 1, -Hw)
    pts += [(-Hw, dl), (-Hw - 4.0, dl + 0.3)]
    return pts


def cliff_wall(name, Hw, kind="straight", lod=0, seed=0):
    W = WALL_W
    rs = np.random.default_rng(5151)            # shared across modules
    shared = {
        "D": _shared_bands(16),
        "edge_ph": [rs.uniform(0, 6.283, 5) for _ in range(16)],
        "edge_amp": [0.9, 0.6, 0.45, 0.3, 0.2],
    }
    rm = np.random.default_rng(seed)
    shared["mod_ph"] = [rm.uniform(0, 6.283, 5) for _ in range(16)]
    shared["mod_amp"] = [1.4, 0.9, 0.6, 0.4, 0.3]
    shared["flute_m"] = int(rm.integers(5, 9))
    shared["flute_ph"] = rm.uniform(0, 6.283)
    shared["flute_d"] = 3.4
    ncol = 30 if lod == 0 else 11
    xs = np.linspace(-W / 2, W / 2, ncol + 1)
    curv = {"convex": 70.0, "concave": -70.0}.get(kind, 0.0)
    cols = []
    for x in xs:
        prof = wall_profile(x, Hw, kind, rm, shared, lod)
        col = []
        for z, d in prof:
            if curv:
                a = x / curv
                bx, by = curv * math.sin(a), curv * (1 - math.cos(a))
                nx, ny = -math.sin(a), math.cos(a)
                col.append((bx + nx * d, by + ny * d, z))
            else:
                col.append((x, d, z))
        cols.append(col)
    P = np.array(cols).transpose(1, 0, 2)     # (rows, cols, 3)
    b = Builder(name + ("_lod1" if lod else ""))
    V = b.grid(P, "rock_karst")
    if kind == "notch":
        for i in range(4, P.shape[0]):
            for j in range(P.shape[1]):
                V[i][j][b.wl] = float(smoothstep(4.0, 1.0, abs(xs[j])))
        b.seat("fall_lip", (0.0, P[1, ncol // 2, 1], P[1, ncol // 2, 2]), r=3.0)
    if kind == "ledge":
        j = ncol // 2
        rows = [i for i in range(P.shape[0] - 1) if abs(P[i, j, 2] - P[i + 1, j, 2]) < 0.05 and
                (P[i, j, 1] - P[i + 1, j, 1]) > 4.0]
        if rows:
            i = rows[0]
            m = (P[i, j] + P[i + 1, j]) / 2
            b.seat("house", m, r=6.0, shelf_w=round(float(P[i, j, 1] - P[i + 1, j, 1]), 1))
    for i in range(P.shape[0] - 1):
        j = ncol // 2
        if abs(P[i, j, 2] - P[i + 1, j, 2]) < 0.05 and 2.5 < (P[i, j, 1] - P[i + 1, j, 1]) <= 6.0 and i > 2:
            b.seat("pine", (P[i, j] + P[i + 1, j]) / 2 + np.array([12.0, 0, 0]), r=1.5)
    # shrub mounds (key 'moss') on the shelves and hanging over the top lip: the green bands of the sheets' gorge
    # walls. Kept off the last 3 m of each edge so chained modules meet on bare rock.
    rng = np.random.default_rng(seed * 31 + 7)
    cand = []
    for i in range(3, P.shape[0] - 1):
        for j in range(1, ncol, 2):
            w = float(P[i, j, 1] - P[i + 1, j, 1])
            if abs(P[i, j, 2] - P[i + 1, j, 2]) < 0.05 and w > 1.4 and abs(P[i, j, 0]) < W / 2 - 3.0:
                cand.append(((P[i, j] + P[i + 1, j]) / 2, float(np.clip(w * 0.8, 1.2, 4.0))))
    lip = [(P[2, j] + np.array([0, -0.6, 0.3]), rng.uniform(1.6, 3.4)) for j in range(1, ncol, 2)
           if abs(P[2, j, 0]) < W / 2 - 3.0]
    maxm = 20 if lod == 0 else 6
    pick = []
    for c, r in lip:
        if rng.random() < 0.45:
            pick.append((c, r))
    for c, r in cand:
        if rng.random() < 0.55:
            pick.append((c, r))
    if len(pick) > maxm:
        idx = rng.choice(len(pick), size=maxm, replace=False)
        pick = [pick[k] for k in sorted(idx)]
    for c, r in pick:
        mound(b, c, r, rng, flat=0.55, sub=1 if (lod == 0 and r > 2.2) else 0)
    ob = finish(b, ao_dist=15.0, ground=False, moss_faces=0.6, recalc=False, expect_front=(0, -1, 0), sharp_deg=34.0)
    return ob


WALLS = [("cliff_straight_60", 60, "straight", 1), ("cliff_convex_60", 60, "convex", 2),
         ("cliff_concave_75", 75, "concave", 3), ("cliff_notch_75", 75, "notch", 4),
         ("cliff_ledge_30", 30, "ledge", 5), ("cliff_straight_30", 30, "straight", 6),
         ("cliff_straight_75", 75, "straight", 7)]


# ------------------------------------------------------------------------------------------------ boulders, stones
def _deformed_sphere(b, bmsph, size, seed, cuts, flat_z, mat, pillow=True, noise=0.12):
    rng = np.random.default_rng(seed)
    sx, sy, sz = size
    planes = []
    for _ in range(cuts):
        a = rng.uniform(0, 2 * math.pi)
        el = rng.uniform(-0.1, 0.9)
        n = np.array([math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)])
        planes.append((n, rng.uniform(0.55, 0.8)))
    ph = rng.uniform(0, 6.283, 6)
    out = []
    for v in bmsph.verts:
        p = np.array(v.co)
        th = math.atan2(p[1], p[0])
        k = 1 + noise * (0.5 * math.sin(2 * th + ph[0] + 1.3 * p[2]) + 0.3 * math.sin(3 * th + ph[1]) +
                         0.2 * math.sin(5 * p[2] + ph[2]))
        p = p * k
        for n, d in planes:
            s = p @ n - d
            if s > 0:
                p = p - n * s * 0.92
        if pillow and p[2] > 0:
            p[2] *= 0.92
        out.append(p * np.array([sx, sy, sz]))
    out = np.array(out)
    zmin, zmax = out[:, 2].min(), out[:, 2].max()
    out[:, 2] -= zmin + flat_z * (zmax - zmin)
    m = {}
    for v, p in zip(bmsph.verts, out):
        m[v] = b.bm.verts.new(Vector(p))
    k = b.mi(mat)
    for f in bmsph.faces:
        nf = b.bm.faces.new([m[v] for v in f.verts])
        nf.material_index = k
    return out


def boulder(name, size, seed, lod=0, cuts=3):
    b = Builder(name + ("_lod1" if lod else ""))
    s = bmesh.new()
    bmesh.ops.create_icosphere(s, subdivisions=3 if lod == 0 else 2, radius=1.0)
    _deformed_sphere(b, s, size, seed, cuts, 0.2, "rock_boulder")
    s.free()
    return finish(b, ao_dist=max(size) * 0.6, moss_faces=0.72, moss_rule=(0.35, 0.8), sharp_deg=38)


BOULDERS = [("boulder_a", (0.6, 0.5, 0.45), 41, 2), ("boulder_b", (1.0, 0.8, 0.7), 42, 3),
            ("boulder_c", (1.5, 1.1, 0.9), 43, 3), ("boulder_d", (1.9, 1.5, 1.4), 44, 2),
            ("boulder_e", (2.6, 2.0, 1.6), 45, 3), ("boulder_f", (3.2, 2.6, 2.4), 46, 3)]


def white_stone(b, idx, lod, offset=(0, 0, 0)):
    rng = np.random.default_rng(600 + idx)
    L = [0.3, 0.4, 0.5, 0.65, 0.8, 1.0, 1.2, 1.5, 1.8, 2.2, 2.6, 3.0][idx]
    sx = L / 2
    sy = sx * rng.uniform(0.6, 0.9)
    sz = sx * rng.uniform(0.38, 0.62)
    s = bmesh.new()
    if lod == 0:
        bmesh.ops.create_uvsphere(s, u_segments=12, v_segments=7, radius=1.0)
    else:
        bmesh.ops.create_uvsphere(s, u_segments=6, v_segments=4, radius=1.0)
    egg = rng.uniform(-0.12, 0.12)
    for v in s.verts:
        v.co.x *= 1 + egg * v.co.x
        if v.co.z < -0.4:
            v.co.z = -0.4 - (v.co.z + 0.4) * 0.4
    pts = _deformed_sphere(b, s, (sx, sy, sz), 700 + idx, 0, 0.25, "stone_white", pillow=False, noise=0.05)
    s.free()
    return L


def white_stones(lod=0):
    """One object per stone (12 nodes in one GLB): returned as a list."""
    obs = []
    for i in range(12):
        b = Builder("white_stone_%02d%s" % (i, "_lod1" if lod else ""))
        L = white_stone(b, i, lod)
        obs.append(finish(b, ao_dist=max(L * 0.5, 0.3), moss_faces=None, moss_rule=(2, 3), sharp_deg=80))
    return obs


def cairn(name, seed, height):
    rng = np.random.default_rng(seed)
    b = Builder(name)
    z = 0.0
    n = int(rng.integers(5, 9))
    r0 = height * 0.38
    cx, cy = 0.0, 0.0
    for i in range(n):
        f = i / max(n - 1, 1)
        r = r0 * (1 - 0.62 * f) * rng.uniform(0.85, 1.1)
        hgt = r * rng.uniform(0.55, 0.8)
        s = bmesh.new()
        bmesh.ops.create_icosphere(s, subdivisions=1, radius=1.0)
        mat = "stone_white" if rng.random() < 0.55 else "rock_boulder"
        pts = _deformed_sphere(b, s, (r, r * rng.uniform(0.8, 1.0), hgt / 2), seed * 10 + i, 2, 0.0, mat)
        s.free()
        # move the stone just made to its place in the stack
        b.bm.verts.ensure_lookup_table()
        nv = len(b.bm.verts)
        for k in range(nv - len(pts), nv):
            v = b.bm.verts[k]
            v.co.x += cx
            v.co.y += cy
            v.co.z += z - (0.12 * hgt if i else 0.2 * hgt)
        z += hgt * 0.82
        cx += rng.uniform(-0.06, 0.06) * r0
        cy += rng.uniform(-0.06, 0.06) * r0
    b.seat("rag_tie", (cx, cy, z), r=0.3)
    return finish(b, ao_dist=0.8, moss_faces=None, moss_rule=(0.6, 0.95), moss_gain=0.6, sharp_deg=40)


CAIRNS = [("cairn_a", 81, 1.2), ("cairn_b", 82, 1.6), ("cairn_c", 83, 2.2), ("cairn_d", 84, 1.4), ("cairn_e", 85, 1.9)]


# ------------------------------------------------------------------------------------------------ needle, heads
NEEDLE = dict(H=62, R0=7.5, tiers=4, cols=1, lean=3, lean_dir=200, seed=71, step=(0.86, 0.93), crown=0.02,
              flat_top=0.9, crown_mounds=False, sides=(9, 6))
HEAD_N = dict(H=89, R0=32, tiers=3, cols=4, lean=4, lean_dir=100, seed=91, crown=0.05, flat_top=0.8,
              step=(0.76, 0.84), sub_h=(0.45, 0.85), crown_ring=(0.6, 0.9), sides=(11, 7))
HEAD_S = dict(H=77, R0=29, tiers=3, cols=4, lean=5, lean_dir=-80, seed=92, crown=0.05, flat_top=0.8,
              step=(0.76, 0.84), sub_h=(0.45, 0.85), crown_ring=(0.6, 0.9), sides=(11, 7))


def needle(lod=0):
    """R07: the white-limestone pillar under the rope bridge: its foot (origin) on the riverbed (~135), the flat cap
    62 m above it (~197, the rope bridge's mid platform); 6 m of buried foot below the origin."""
    b = Builder("bridge_needle" + ("_lod1" if lod else ""))
    top, r = add_tower(b, dict(NEEDLE), lod, mat="rock_pale", seats=(lod == 0))
    if lod == 0:
        b.seat("platform", top, r=2.5)
    return finish(b, ao_dist=8.0, moss_faces=0.6, sharp_deg=32.0)


def head(name, spec, lod=0):
    b = Builder(name + ("_lod1" if lod else ""))
    top, r = add_tower(b, dict(spec), lod, mat="rock_karst", seats=(lod == 0))
    if lod == 0:
        b.seat("gate_tower", top, r=6.0)
    return finish(b, ao_dist=15.0, moss_faces=0.62, sharp_deg=32.0)


# ------------------------------------------------------------------------------------------------ the Two Heights bridge
# Blender frame: X = Godot x (east: the deck's width and the torrent's flow), Y = -Godot z (north), Z up.
# Origin: the deck surface between the piers (Godot world (-832, 296, -462.5) per vista_spec D11).
PIER_Y = 17.5
DECK_HW = 4.5


def pier_ring(z, top_z=-1.2, base_z=-100.0):
    """A pier's plan at height z: chamfered rectangle (half X 7 -> 10, half Y 4.5 -> 6.5 from top to base) with
    cutwater noses on the +-X ends below z -60."""
    f = (top_z - z) / (top_z - base_z)
    hx, hy = 7.0 + 3.0 * f, 4.5 + 2.0 * f
    nose = 4.5 * float(smoothstep(-60.0, -80.0, z))
    c = 1.0
    pts = [(hx, -hy + c), (hx + nose, 0.0), (hx, hy - c), (hx - c, hy), (-hx + c, hy), (-hx, hy - c),
           (-hx - nose, 0.0), (-hx, -hy + c), (-hx + c, -hy), (hx - c, -hy)]
    return pts, hx, hy


PIER_ZS = [-104, -100, -80, -60.6, -60, -59.0, -30.6, -30, -29.0, -14, -2.4, -1.2]
PIER_GROW = {-60.0: 0.45, -59.0: 0.45, -30.0: 0.45, -29.0: 0.45}


def pier_face_x(z):
    """The pier's east (+X) face as built at height z: the rings' half X with their string-course growth, linearly
    between rings (what a sign or plate must stand proud of, or it z-fights the face)."""
    xs = []
    for zr in PIER_ZS:
        pts, hx, hy = pier_ring(zr)
        g = PIER_GROW.get(float(zr), 0.0)
        xs.append(hx + g * 1.4 * hx / math.hypot(hx, hy - 1.0))
    return float(np.interp(z, PIER_ZS, xs))


def add_pier(b, yc):
    zs = PIER_ZS
    grow = PIER_GROW
    rings = []
    for z in zs:
        pts, hx, hy = pier_ring(z)
        g = grow.get(float(z), 0.0)
        ring = []
        for (x, y) in pts:
            L = math.hypot(x, y)
            ring.append((x + g * x / max(L, 1e-6) * 1.4, yc + y + g * y / max(L, 1e-6) * 1.4, z))
        rings.append(ring)
    V = b.grid(np.array(rings), "ashlar", smooth=False, close_cols=True)
    b.bm.faces.new([V[-1][j] for j in range(len(rings[-1]))]).material_index = b.mi("ashlar")
    # turrets either side of the deck, standing on the pier's ends (outside the parapets)
    for sx in (-1, 1):
        x0 = sx * (DECK_HW + 1.25)
        b.box((x0, yc, 1.5), (2.5, 5.5, 5.4), "ashlar")
        b.box((x0, yc, 4.4), (3.0, 6.0, 0.4), "ashlar")
        # pyramid cap
        cx, cy, z0 = x0, yc, 4.6
        hx, hy = 1.5, 3.0
        apex = (cx, cy, z0 + 2.6)
        c4 = [(cx - hx, cy - hy, z0), (cx + hx, cy - hy, z0), (cx + hx, cy + hy, z0), (cx - hx, cy + hy, z0)]
        for i in range(4):
            b.face([c4[i], c4[(i + 1) % 4], apex], "ashlar")
        b.seat("banner", (x0 + sx * 1.3, yc, 2.0), r=0.5, face=[sx, 0, 0])


def arch_wall(b, y0, y1, zs, ztop, hw, segs=20, band=True):
    """A spandrel wall between y0 and y1 (X from -hw to hw), its semicircular opening springing at zs; the top at
    ztop. Front and back faces, soffit, top, ends; an arch band (extrados ring) proud of both faces."""
    yc = (y0 + y1) / 2
    r = (y1 - y0) / 2
    t = np.linspace(0, math.pi, segs + 1)
    intr = [(yc + r * math.cos(a), zs + r * math.sin(a)) for a in t]          # from y1 to y0 over the top
    for sx in (-hw, hw):
        for i in range(segs):
            (ya, za), (yb, zb) = intr[i], intr[i + 1]
            q = [(sx, ya, za), (sx, yb, zb), (sx, yb, ztop), (sx, ya, ztop)]
            b.face(q if sx > 0 else q[::-1], "ashlar")
        if band:
            for i in range(segs):
                a0, a1 = t[i], t[i + 1]
                r1, r2 = r, r + 1.3
                o = 0.35 * (1 if sx > 0 else -1)
                p = [(sx + o, yc + r1 * math.cos(a0), zs + r1 * math.sin(a0)),
                     (sx + o, yc + r1 * math.cos(a1), zs + r1 * math.sin(a1)),
                     (sx + o, yc + r2 * math.cos(a1), zs + r2 * math.sin(a1)),
                     (sx + o, yc + r2 * math.cos(a0), zs + r2 * math.sin(a0))]
                b.face(p if sx > 0 else p[::-1], "ashlar")
                # the band's outer edge
                e = [(sx, yc + r2 * math.cos(a0), zs + r2 * math.sin(a0)),
                     (sx + o, yc + r2 * math.cos(a0), zs + r2 * math.sin(a0)),
                     (sx + o, yc + r2 * math.cos(a1), zs + r2 * math.sin(a1)),
                     (sx, yc + r2 * math.cos(a1), zs + r2 * math.sin(a1))]
                b.face(e, "ashlar")
                ei = [(sx, yc + r1 * math.cos(a1), zs + r1 * math.sin(a1)),
                      (sx + o, yc + r1 * math.cos(a1), zs + r1 * math.sin(a1)),
                      (sx + o, yc + r1 * math.cos(a0), zs + r1 * math.sin(a0)),
                      (sx, yc + r1 * math.cos(a0), zs + r1 * math.sin(a0))]
                b.face(ei, "ashlar")
    for i in range(segs):
        (ya, za), (yb, zb) = intr[i], intr[i + 1]
        b.face([(-hw, ya, za), (hw, ya, za), (hw, yb, zb), (-hw, yb, zb)], "ashlar")


def tablet_sign_a(b, x, y, z, T=0.25):
    """Maker sign A (ours): 'the plumb and ring': a ring, a plumb line through it from a hanger bar, the bob below,
    on a round-topped tablet. Carved strokes are dark 'carve' faces just proud of the tablet (they read from afar)."""
    W, H = 3.6, 4.4
    # round-topped tablet: a box and a half disc on top, in the YZ plane, facing +X
    xs = x + T
    b.box((x + T / 2, y, z), (T, W, H - W / 2), "ashlar")
    n = 12
    zc = z + (H - W / 2) / 2
    for i in range(n):
        a0, a1 = math.pi * i / n, math.pi * (i + 1) / n
        p0 = (xs, y + W / 2 * math.cos(a0), zc + W / 2 * math.sin(a0))
        p1 = (xs, y + W / 2 * math.cos(a1), zc + W / 2 * math.sin(a1))
        b.face_out([(xs, y, zc), p0, p1], "ashlar", (1, 0, 0))
        b.face_out([(x, y, zc), (x, p1[1], p1[2]), (x, p0[1], p0[2])], "ashlar", (-1, 0, 0))
        b.face_out([(x, p0[1], p0[2]), (x, p1[1], p1[2]), p1, p0], "ashlar",
                   (0, math.cos((a0 + a1) / 2), math.sin((a0 + a1) / 2)))
    xc = xs + 0.03
    # ring
    rc, w = 0.85, 0.24
    cz = z + 0.35
    m = 20
    for i in range(m):
        a0, a1 = 2 * math.pi * i / m, 2 * math.pi * (i + 1) / m
        b.face_out([(xc, y + rc * math.cos(a0), cz + rc * math.sin(a0)), (xc, y + rc * math.cos(a1), cz + rc * math.sin(a1)),
                (xc, y + (rc - w) * math.cos(a1), cz + (rc - w) * math.sin(a1)),
                (xc, y + (rc - w) * math.cos(a0), cz + (rc - w) * math.sin(a0))][::-1], "carve", (1, 0, 0))
    # hanger bar, line, bob
    zt = zc + W / 2 - 0.45
    b.face_out([(xc, y - 0.7, zt), (xc, y + 0.7, zt), (xc, y + 0.7, zt - 0.2), (xc, y - 0.7, zt - 0.2)][::-1], "carve", (1, 0, 0))
    b.face_out([(xc, y - 0.09, zt - 0.2), (xc, y + 0.09, zt - 0.2), (xc, y + 0.09, z - 1.05), (xc, y - 0.09, z - 1.05)][::-1],
           "carve", (1, 0, 0))
    b.face_out([(xc, y - 0.42, z - 1.05), (xc, y + 0.42, z - 1.05), (xc, y, z - 1.75)][::-1], "carve", (1, 0, 0))


def tablet_sign_b(b, x, y, z, T=0.3):
    """Maker sign B (ours, a different hand): 'the square and three steps': a mason's square (an L), three stepped
    tallies climbing beside it and a sunk dot, on a square tablet of darker stone set proud of the pier. The marks
    are raised 'carve' slabs 8 cm proud so they catch the light from 300 m."""
    W = 3.6
    b.box((x + T / 2, y, z), (T, W, W), "stone_white")                     # a smooth white slab set in the ashlar
    b.box((x + T / 2, y, z), (T + 0.12, W + 0.3, 0.25), "stone_white")     # a lintel band across it (sign B's frame)
    xc = x + T + 0.04
    d = 0.08

    def mark(cy, cz, wy, wz):
        b.box((xc, cy, cz), (d, wy, wz), "carve")

    mark(y - 1.02, z + 0.05, 0.36, 2.3)          # the square's upright
    mark(y - 0.4, z - 1.08, 1.6, 0.34)           # the square's foot
    for k in range(3):                           # three steps climbing to the right
        mark(y - 0.05 + 0.5 * k, z - 0.4 + 0.55 * k, 0.6, 0.24)
    mark(y + 1.05, z + 1.15, 0.42, 0.42)          # the dot


def bolt_plate(b, x, y, z, rng):
    """An iron plate with four bolts on a pier's east face, a peg above it with frayed rag offerings."""
    b.box((x + 0.06, y, z), (0.12, 1.4, 1.4), "iron")
    for dy in (-0.45, 0.45):
        for dz in (-0.45, 0.45):
            b.box((x + 0.17, y + dy, z + dz), (0.12, 0.22, 0.22), "iron")
    b.box((x + 0.25, y, z + 1.15), (0.5, 0.12, 0.12), "iron")
    cols = ["cloth_madder", "cloth_bone", "cloth_indigo", "cloth_ochre", "cloth_madder"]
    for k in range(int(rng.integers(3, 6))):
        L = rng.uniform(0.45, 0.95)
        w = rng.uniform(0.09, 0.15)
        yy = y + rng.uniform(-0.18, 0.18)
        xx = x + 0.32 + rng.uniform(0, 0.15)
        lean = rng.uniform(-0.12, 0.12)
        z0 = z + 1.12
        q = [(xx, yy - w / 2, z0), (xx, yy + w / 2, z0), (xx + 0.05, yy + w / 2 + lean, z0 - L),
             (xx + 0.05, yy - w / 2 + lean + rng.uniform(-0.04, 0.04), z0 - L * rng.uniform(0.8, 0.95))]
        m = cols[k % len(cols)]
        b.face(q, m)
        b.face(q[::-1], m)                 # both sides (rags are seen from both)
    b.seat("rag_tie", (x + 0.3, y, z + 1.15), r=0.2)


def two_heights_bridge(lod=0):
    b = Builder("two_heights_bridge" + ("_lod1" if lod else ""))
    rng = np.random.default_rng(1765)
    for yc in (PIER_Y, -PIER_Y):
        add_pier(b, yc)
    # deck slab, cornice, parapets with coping; the south approach falls 7 m over its last 26 m
    ys = [62.0, 34.0, 22.0, 13.0, 0.0, -13.0, -22.0, -34.0, -47.0, -60.0]

    def zd(y):
        return 0.0 if y >= -34.0 else -7.0 * (-34.0 - y) / 26.0

    for y0, y1 in zip(ys[:-1], ys[1:]):
        za, zb = zd(y0), zd(y1)
        # road (top), underside, sides
        b.face([(-DECK_HW, y0, za), (-DECK_HW, y1, zb), (DECK_HW, y1, zb), (DECK_HW, y0, za)], "ashlar")
        b.face([(-DECK_HW, y0, za - 1.2), (DECK_HW, y0, za - 1.2), (DECK_HW, y1, zb - 1.2), (-DECK_HW, y1, zb - 1.2)],
               "ashlar")
        for sx in (-1, 1):
            xo = sx * DECK_HW
            # cornice band (proud 0.4 m) under the parapet
            xc = sx * (DECK_HW + 0.4)
            q = [(xo, y0, za - 1.2), (xo, y1, zb - 1.2), (xc, y1, zb - 1.0), (xc, y0, za - 1.0)]
            b.face(q if sx < 0 else q[::-1], "ashlar")
            q = [(xc, y0, za - 1.0), (xc, y1, zb - 1.0), (xc, y1, zb - 0.4), (xc, y0, za - 0.4)]
            b.face(q if sx < 0 else q[::-1], "ashlar")
            q = [(xc, y0, za - 0.4), (xc, y1, zb - 0.4), (xo, y1, zb - 0.4), (xo, y0, za - 0.4)]
            b.face(q if sx < 0 else q[::-1], "ashlar")
            # parapet: outer face, coping, inner face
            xi = sx * (DECK_HW - 0.6)
            q = [(xo, y0, za - 0.4), (xo, y1, zb - 0.4), (xo, y1, zb + 1.2), (xo, y0, za + 1.2)]
            b.face(q if sx < 0 else q[::-1], "ashlar")
            xk, xk2 = sx * (DECK_HW + 0.15), sx * (DECK_HW - 0.75)
            q = [(xk, y0, za + 1.2), (xk, y1, zb + 1.2), (xk, y1, zb + 1.45), (xk, y0, za + 1.45)]
            b.face(q if sx < 0 else q[::-1], "ashlar")
            q = [(xk, y0, za + 1.45), (xk, y1, zb + 1.45), (xk2, y1, zb + 1.45), (xk2, y0, za + 1.45)]
            b.face(q if sx < 0 else q[::-1], "ashlar")
            q = [(xk2, y0, za + 1.45), (xk2, y1, zb + 1.45), (xk2, y1, zb + 1.2), (xk2, y0, za + 1.2)]
            b.face(q if sx < 0 else q[::-1], "ashlar")
            q = [(xi, y0, za + 1.2), (xi, y1, zb + 1.2), (xi, y1, zb), (xi, y0, za)]
            b.face(q if sx < 0 else q[::-1], "ashlar")
            q = [(xk, y0, za + 1.2), (xk2, y0, za + 1.2), (xk2, y1, zb + 1.2), (xk, y1, zb + 1.2)]
            b.face(q if sx > 0 else q[::-1], "ashlar")
    # arches: the upper tier (centre bay and two side bays), and the lower tier in the centre bay
    def pier_hy(z):
        return pier_ring(z)[2]

    segs = 20 if lod == 0 else 10
    crown = -2.6
    pi_ = PIER_Y - pier_hy(-14.0)                         # the centre bay's half clear span at the springing
    arch_wall(b, -pi_, pi_, crown - pi_, -1.2, DECK_HW, segs)
    # side bays: pier face -> abutment face (|y| 34)
    po = PIER_Y + pier_hy(-8.0)
    rs = (34.0 - po) / 2
    arch_wall(b, po, 34.0, crown - rs, -1.2, DECK_HW, segs)
    arch_wall(b, -34.0, -po, crown - rs, -1.2, DECK_HW, segs)
    # the lower tier: a tie band and its arch between the piers at mid height
    pl = PIER_Y - pier_hy(-55.0)
    arch_wall(b, -pl, pl, -46.0 - pl, -42.5, DECK_HW + 0.5, segs)
    b.box((0, 0, -41.9), (2 * DECK_HW + 1.6, 2 * pl, 1.2), "ashlar")
    # abutments (sunk into the rims)
    for sgn, yy in ((1, 48.0), (-1, -47.0)):
        b.box((0, yy, -16.0 + (0 if sgn > 0 else -3.5)), (2 * DECK_HW + 3.0, 28.0, 30.0), "ashlar")
    # maker signs: TWO DIFFERENT marks on the NORTH pier's EAST face (+X end), about 20 m under the deck
    # the pier face leans back (batter): each tablet's back is sunk behind the face's lowest point and its front
    # stands 0.3 m proud of the face's highest, so it never floats or z-fights
    fx = [pier_face_x(z) for z in np.linspace(-23.5, -17.5, 7)]
    hx = max(fx) + 0.02
    xb, tt = min(fx) - 0.05, max(fx) - min(fx) + 0.35
    tablet_sign_a(b, xb, PIER_Y - 2.1, -20.5, T=tt)
    tablet_sign_b(b, xb, PIER_Y + 2.15, -21.1, T=tt)
    b.seat("maker_signs", (hx + 0.3, PIER_Y, -20.8), r=4.5, note="sign A plumb-and-ring, sign B square-and-steps")
    # bolt plates with frayed offerings, on both piers' east faces, under the signs and at the lower tier
    for yc, zz in ((PIER_Y - 2.2, -26.0), (PIER_Y + 2.2, -26.0), (-PIER_Y, -26.0), (PIER_Y, -40.0), (-PIER_Y, -40.0)):
        hx2 = max(pier_face_x(zz - 0.8), pier_face_x(zz + 1.3)) + 0.02
        bolt_plate(b, hx2 + 0.01, yc, zz, rng)
    # banners on the pier faces (east and west), under the deck
    for yc in (PIER_Y, -PIER_Y):
        for sx in (-1, 1):
            b.seat("banner", (sx * (pier_ring(-6.0)[1] + 0.3), yc, -5.0), r=1.5, face=[sx, 0, 0], drop_m=9.0)
    ob = finish(b, ao_dist=6.0, ground=False, moss_faces=None, moss_rule=(0.75, 0.98), moss_gain=0.5, sharp_deg=35)
    return ob


# ------------------------------------------------------------------------------------------------ the kit
def build_all(lods=True):
    """Every piece; returns {name: (lod0 object or list, lod1 object or list or None, group)}."""
    kit = {}
    for name, spec in HERO.items():
        kit[name] = (karst(name, spec, 0, HERO_DEF), karst(name, spec, 1, HERO_DEF) if lods else None, "R01")
    for name, spec in FAR.items():
        kit[name] = (karst(name, spec, 0, FAR_DEF), karst(name, spec, 1, FAR_DEF) if lods else None, "R02")
    for name, h, kind, seed in WALLS:
        kit[name] = (cliff_wall(name, h, kind, 0, seed), cliff_wall(name, h, kind, 1, seed) if lods else None, "R03")
    for name, size, seed, cuts in BOULDERS:
        kit[name] = (boulder(name, size, seed, 0, cuts), boulder(name, size, seed, 1, cuts) if lods else None, "R04")
    kit["white_stones"] = (white_stones(0), white_stones(1) if lods else None, "R05")
    kit["two_heights_bridge"] = (two_heights_bridge(0), decimated(two_heights_bridge(0), 1500, "two_heights_bridge_lod1")
                                 if lods else None,
                                 "R06")
    kit["two_heights_head_n"] = (head("two_heights_head_n", HEAD_N), head("two_heights_head_n", HEAD_N, 1)
                                 if lods else None, "R06")
    kit["two_heights_head_s"] = (head("two_heights_head_s", HEAD_S), head("two_heights_head_s", HEAD_S, 1)
                                 if lods else None, "R06")
    kit["bridge_needle"] = (needle(0), needle(1) if lods else None, "R07")
    for name, seed, h in CAIRNS:
        kit[name] = (cairn(name, seed, h), None, "R08")
    return kit


def decimated(ob, target, name):
    ob.name = name
    ob.data.name = name
    r = min(1.0, target / max(tris(ob), 1))
    if r < 1.0:
        m = ob.modifiers.new("lod", "DECIMATE")
        m.ratio = r
        bpy.context.view_layer.objects.active = ob
        with bpy.context.temp_override(object=ob, active_object=ob):
            bpy.ops.object.modifier_apply(modifier=m.name)
    return ob


def _gltf_kwargs():
    want = dict(export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
                export_animations=False, export_skins=False, export_morph=False, export_vertex_color="ACTIVE",
                export_all_vertex_colors=False, export_image_format="NONE", export_materials="EXPORT",
                export_normals=True, export_texcoords=True)
    have = set(bpy.ops.export_scene.gltf.get_rna_type().properties.keys())
    return {k: v for k, v in want.items() if k in have}


def export(obs, path):
    obs = obs if isinstance(obs, list) else [obs]
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.export_scene.gltf(filepath=path, **_gltf_kwargs())


def size_godot(obs):
    obs = obs if isinstance(obs, list) else [obs]
    P = np.array([v.co[:] for ob in obs for v in ob.data.vertices])
    mn, mx = P.min(0), P.max(0)
    return {"x": [round(float(mn[0]), 2), round(float(mx[0]), 2)], "y": [round(float(mn[2]), 2), round(float(mx[2]), 2)],
            "z": [round(float(-mx[1]), 2), round(float(-mn[1]), 2)]}


def export_all(kit, out):
    os.makedirs(out, exist_ok=True)
    meta = {"_about": "Thủy Vân ROCK kit (tools/thuyvan_art/rock/rock_kit.py). Godot frame: x east, y up, z south "
                      "(the piece's front faces +Z). Seats are in the piece's local Godot frame.",
            "materials": {k: {"texture": v[0], "tile_m": v[1], "tint": "#%02x%02x%02x" % tuple(int(round(c * 255)) for c in v[2])}
                          for k, v in MATS.items()},
            "pieces": {}}
    for name, (l0, l1, grp) in kit.items():
        export(l0, os.path.join(out, name + ".glb"))
        if l1 is not None:
            export(l1, os.path.join(out, name + "_lod1.glb"))
        l0s = l0 if isinstance(l0, list) else [l0]
        l1s = (l1 if isinstance(l1, list) else [l1]) if l1 is not None else []
        entry = {"group": grp, "glb": name + ".glb", "lod1": (name + "_lod1.glb") if l1 is not None else None,
                 "tris": sum(tris(o) for o in l0s), "tris_lod1": sum(tris(o) for o in l1s) if l1s else None,
                 "materials": sorted({m for o in l0s for m in json.loads(o["mats"])}),
                 "size": size_godot(l0s), "seats": [s for o in l0s for s in json.loads(o["seats"])]}
        if len(l0s) > 1:
            entry["nodes"] = [{"name": o.name, "tris": tris(o), "size": size_godot(o)} for o in l0s]
        meta["pieces"][name] = entry
        print("ROCK_KIT %-22s %-4s tris %6d lod1 %s mats %s seats %d" % (
            name, grp, entry["tris"], entry["tris_lod1"], entry["materials"], len(entry["seats"])))
    json.dump(meta, open(os.path.join(out, "rock_kit.json"), "w"), indent=1, ensure_ascii=False)
    return meta


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--blend", default="")
    a = ap.parse_args(argv)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit = build_all()
    export_all(kit, a.out)
    if a.blend:
        bpy.ops.wm.save_as_mainfile(filepath=a.blend)
    print("ROCK_KIT DONE")


if __name__ == "__main__":
    main()
