"""The sky galleon wrecked: Two Fires' burning ship down in the pines (docs/main_story.md, mission 11).

Built from the intact ship of tools/models/sky_galleon.py (imported, never changed: the same hull, rig, sails,
fans, keel-wings and keel crystal, the same atlas) and then broken:
  * the hull split just aft of the main mast on a raked, ragged break (planks torn out up to ~1.2 m back from it,
    longer planks left jutting into the gap), the after part sagged stern-down, yawed and rolled a little more, a
    hole stove in the starboard bow with planks spilled on the ground below it;
  * everything canted 25 deg to port and 4 deg bow-down, ploughed in 0.55 m: the keel and the port bilge in the
    earth, a mound of churned earth thrown up ahead of the bow and along the port side (Furrow);
  * both masts snapped (fore at 9.6 m, main at 11.8 m, splinters on both sides of each break): each top, with its
    yards, tops, fans and sails, fallen (the fore over the bow, the main over the port side), its truck in the
    ground; the stays and shrouds gone, a few slack lines hanging from the stumps; the jib-boom gone;
  * the sails torn and burned up from the foot, the bolt ropes burned away; the gaff mainsail a ragged strip on
    the boom;
  * the fans shattered (most of the membranes and a third of the ribs gone); the port keel-wing torn off under the
    hull, the starboard one holed;
  * the keel crystal torn out of its cradle and lying cracked in two on the ground beside the starboard bilge,
    glowing (its broken faces filled, the brightest part of the crystal cell), with a few shards round it;
  * a loose Spar (a 6 m yard, its own mesh and node, its origin at its middle, along its local X) lying on the
    starboard side, for the game to make a physics prop the player lifts with the first lock.

Run headless (factory scene), one Blender process at a time:
  Blender -b --factory-startup --python tools/models/sky_galleon_wreck.py -- \
      [--out assets/sky/sky_galleon_wreck.glb] [--renders DIR] [--blend FILE.blend]

Conventions (Godot / glTF axes, metres), the WRECK frame: the origin on the ground at the keel midships, the
ground the plane y = 0, the bow toward -Z (canted and broken: the bow forefoot ~1 m into the ground), starboard +X
(the side that faces up and out: the crystal, the starboard keel-wing overhead and the open ground are there).
Faces wholly more than 1.2 m below the ground are dropped (the rest is the skirt that hides a sloping terrain).

Top-level mesh nodes:
  Hull_Fore, Hull_Aft        the two parts of the hull (decks, rails, guns, stern...)
  HullFore_Col-convcolonly, HullAft_Col-convcolonly
                             convex hulls round each part (and its burning break), which Godot's importer makes
                             StaticBody3D colliders (built at import: nothing to build on the frame the ship lands)
  Rig                        the mast stumps, bowsprit, boom and what rigging is left, the slack lines
  Fallen_Fore, Fallen_Main   each fallen top: mast, tops, yards (and the main's gaff)
  WingSails                  the shattered fans and the starboard keel-wing (cast_shadow off in Godot, as the intact)
  Keelstone                  the two halves of the crystal, its bands, the shards (EtheriumGlow and Brass)
  Furrow                     the churned earth (material Earth)
  Spar                       the loose yard (its own node: the game makes it a RigidBody3D)
  Burn_*                     the parts that burn (the game sets its fire over each one's box and chars the timber
                             ones): Burn_BreakFore, Burn_BreakAft (the timbers along the break), Burn_Debris (the
                             planks spilled under the hole), Burn_SailsFore, Burn_SailsMain (the fallen tops'
                             canvas), Burn_Boom (the strip of mainsail on the boom)
Empties: KeelGlow (the crystal's centre: a light belongs ~1.2 m above it), Ithel (where the captain sits against
the hull bottom, on the ground, facing +X), Pinned (where the stranger lies under the spar, on the ground),
FallenFore_A/_B and FallenMain_A/_B (each fallen top's hinge and truck: a capsule collider), Deck (on the fore
part's deck), Bow, Stern.
Materials: Wood, Tar, Paint, Canvas, Brass, EtheriumGlow (as the intact, on a sooted copy of its atlas; the timber
ones double sided, so the broken hull shows its inside), and Earth (plain).
Every build prints the triangle counts (under 45k in all), the empties and the clearances checked for Ithel's seat
and the stranger's place.
"""

import argparse
import importlib.util
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, noise
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
_spec = importlib.util.spec_from_file_location("sky_galleon", os.path.join(HERE, "sky_galleon.py"))
sg = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sg)
V, G = sg.V, sg.G

# --------------------------------------------------------------------------
# How it lies and breaks (ship frame = the intact model's; wreck frame = on the ground)
# --------------------------------------------------------------------------
ROLL, PITCH, SINK = 25.0, -4.0, 0.55          # canted to port, bow down (deg), ploughed in (m)
BURY = -1.2                                   # faces wholly below this (wreck frame) are dropped
CUT_P, CUT_N = V(0.0, 0.4, 4.4), V(0.16, -0.10, 1.0).normalized()    # the break, raked
RAG = (0.25, 0.95)                            # planks torn out to RAG[0] + RAG[1] * noise from the break
BURN_BAND = 2.2                               # the timbers this near the break burn (Burn_Break*)
AFT_HINGE, AFT_OFF = V(0.0, 0.4, 4.4), V(0.35, -0.2, 0.9)
AFT_YAW, AFT_ROLL, AFT_DROP = 5.0, 6.0, 6.0   # the after part: yawed, rolled more, stern down (deg)
HOLE_C, HOLE_R = V(3.2, 2.0, -5.2), (0.95, 1.9)  # stove in on the starboard bow: centre, (y, z) half sizes
BREAK = {"fore": 9.6, "main": 11.8}           # mast snap heights (ship frame)
SNAP_N = V(0.25, 1.0, 0.15).normalized()      # ... on a slant
FALL = {  # fallen tops: horizontal heading in the wreck frame, twist about the fallen axis (deg)
    "fore": (V(-0.18, 0.0, -1.0).normalized(), 30.0),
    "main": (V(-1.0, 0.0, 0.35).normalized(), -20.0),
}
CRACK_P = sg.CRYSTAL_C + V(0.0, 0.0, 0.3)
CRACK_N = V(0.45, 0.30, 1.0).normalized()
KEEL_AT = V(4.6, 0.63, 0.9)                   # the crystal's centre on the ground (wreck frame)
KEEL_YAW, KEEL_ROLL = 18.0, 30.0              # lying along the hull, a facet down
SPAR_LEN, SPAR_R = 6.0, 0.17
PINNED_AT = V(6.3, 0.0, 5.0)                  # the stranger's place (wreck frame; the game lays the spar on him)
ITHEL_Z, ITHEL_Z_PREF = (-3.0, 3.5), -1.0    # where along the starboard side his seat is looked for (wreck z)
ITHEL_SHOULDER = 0.95                         # a seated man's shoulders over the ground
ITHEL_BACK = 0.40                             # the seat this far out from where his shoulders touch the hull
SOOT = dict(timber=0.55, tar=0.30, canvas=0.72)

WM = {}          # the wreck's materials, by the intact's names
SINKS = {}
TM = []          # transforms (4x4, Godot coords), by id
_SRC_ID = [0]


# --------------------------------------------------------------------------
# Transforms (numpy 4x4 on Godot-space points)
# --------------------------------------------------------------------------
def m_rot(axis, deg):
    ax = axis if isinstance(axis, str) else Vector(axis).normalized()
    return np.array(Matrix.Rotation(math.radians(deg), 4, ax))


def m_tr(v):
    M = np.eye(4)
    M[:3, 3] = (v[0], v[1], v[2])
    return M


def apply(M, P):
    P = np.asarray(P, dtype=np.float64)
    if P.ndim == 1:
        return P @ M[:3, :3].T + M[:3, 3]
    return P @ M[:3, :3].T + M[:3, 3]


def vec(a):
    return Vector((float(a[0]), float(a[1]), float(a[2])))


def tid(M):
    TM.append(M)
    return len(TM) - 1


R0 = m_rot("X", PITCH) @ m_rot("Z", ROLL)
W = m_tr((0.0, -SINK, 0.0)) @ R0
H_AFT = m_tr(AFT_HINGE + AFT_OFF) @ m_rot("Y", AFT_YAW) @ m_rot("Z", AFT_ROLL) @ m_rot("X", AFT_DROP) @ m_tr(-AFT_HINGE)
W_AFT = W @ H_AFT
I4 = np.eye(4)


def fallen_matrix(key, pts):
    """The fallen top of mast `key`: hinged at its snap (dropped a little), its truck in the ground ahead of the
    fall's heading, twisted about its own axis."""
    m = sg.FORE if key == "fore" else sg.MAIN
    brk = BREAK[key]
    H = m.at(brk)
    tip = pts[key + "_truck"]
    Hw = vec(apply(W, H))
    A = vec(R0[:3, :3] @ np.array((m.at(brk + 1.0) - H).normalized()))
    L = (tip - H).length
    alpha = math.asin(min(max((Hw.y + 0.25) / L, 0.0), 0.95))
    hd, tw = FALL[key]
    D = (hd * math.cos(alpha) + V(0, -math.sin(alpha), 0)).normalized()
    q = A.rotation_difference(D).to_matrix().to_4x4()
    t = Matrix.Rotation(math.radians(tw), 4, D)
    drop = Vector((0.0, -0.35, 0.0))
    M = np.array(Matrix.Translation(Hw + drop) @ t @ q @ Matrix.Translation(-Hw)) @ W
    return M, Hw + drop, Hw + drop + D * L


# --------------------------------------------------------------------------
# Source meshes: the intact model's parts as arrays (Godot coords), their islands
# --------------------------------------------------------------------------
class Src:
    def __init__(self, obj):
        _SRC_ID[0] += 1
        self.id = _SRC_ID[0]
        self.name = obj.name
        me = obj.data
        nv, nf, nl = len(me.vertices), len(me.polygons), len(me.loops)
        co = np.empty(nv * 3, dtype=np.float32)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3).astype(np.float64)
        self.P = np.stack([co[:, 0], co[:, 2], -co[:, 1]], axis=1)
        self.ls = np.empty(nf, dtype=np.int32)
        self.lt = np.empty(nf, dtype=np.int32)
        self.mi = np.empty(nf, dtype=np.int32)
        me.polygons.foreach_get("loop_start", self.ls)
        me.polygons.foreach_get("loop_total", self.lt)
        me.polygons.foreach_get("material_index", self.mi)
        self.sm = [p.use_smooth for p in me.polygons]
        self.lv = np.empty(nl, dtype=np.int32)
        me.loops.foreach_get("vertex_index", self.lv)
        uv = np.empty(nl * 2, dtype=np.float32)
        me.uv_layers.active.data.foreach_get("uv", uv)
        self.uv = uv.reshape(-1, 2)
        self.mats = [m.name[2:] if m.name.startswith("W_") else m.name for m in me.materials]
        self.nf = nf
        order = np.argsort(self.ls)
        assert (order == np.arange(nf)).all(), "loops not in polygon order"
        self.fc = np.add.reduceat(self.P[self.lv], self.ls) / self.lt[:, None] if nf else np.zeros((0, 3))
        # islands (union-find over the faces' corners)
        parent = list(range(nv))

        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a
        for f in range(nf):
            s, n = int(self.ls[f]), int(self.lt[f])
            r0 = find(int(self.lv[s]))
            for k in range(1, n):
                r = find(int(self.lv[s + k]))
                if r != r0:
                    parent[r] = r0
        self.vi = np.array([find(v) for v in range(nv)], dtype=np.int64)
        self.fi = self.vi[self.lv[self.ls]] if nf else np.zeros(0, dtype=np.int64)
        self.bb = {}
        self.ic = {}
        self.nfi = {}
        for i in np.unique(self.vi):
            m = self.vi == i
            self.bb[int(i)] = (self.P[m].min(axis=0), self.P[m].max(axis=0))
            self.ic[int(i)] = self.P[m].mean(axis=0)
        for i, c in zip(*np.unique(self.fi, return_counts=True)):
            self.nfi[int(i)] = int(c)
        self.sink = [None] * nf
        self.t = [0] * nf

    def area(self, f):
        vv = self.lv[self.ls[f]:self.ls[f] + self.lt[f]]
        p = self.P[vv]
        a = np.zeros(3)
        for k in range(1, len(p) - 1):
            a += np.cross(p[k] - p[0], p[k + 1] - p[0])
        return 0.5 * float(np.linalg.norm(a))

    def mat(self, f):
        return self.mats[self.mi[f]]

    def emit(self):
        TP = {}
        kept = 0
        for f in range(self.nf):
            s = self.sink[f]
            if s is None:
                continue
            t = self.t[f]
            if t not in TP:
                TP[t] = apply(TM[t], self.P)
            vv = self.lv[self.ls[f]:self.ls[f] + self.lt[f]]
            pts = TP[t][vv]
            if pts[:, 1].max() < BURY:
                continue
            uvs = self.uv[self.ls[f]:self.ls[f] + self.lt[f]]
            sink(s).add([(self.id, t, int(v)) for v in vv], pts, uvs, self.mat(f), self.sm[f])
            kept += 1
        return kept


class Sink:
    """An output mesh: faces copied in (Godot coords, each source vertex once per transform)."""
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uvl = self.bm.loops.layers.uv.new("UVMap")
        self.slots = []
        self.vmap = {}

    def add(self, keys, pts, uvs, mat, smooth):
        vs = []
        for k, p in zip(keys, pts):
            v = self.vmap.get(k)
            if v is None:
                v = self.bm.verts.new((float(p[0]), -float(p[2]), float(p[1])))
                self.vmap[k] = v
            vs.append(v)
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return
        if mat not in self.slots:
            self.slots.append(mat)
        f.material_index = self.slots.index(mat)
        f.smooth = bool(smooth)
        for lp, t in zip(f.loops, uvs):
            lp[self.uvl].uv = (float(t[0]), float(t[1]))

    def obj(self):
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        me.validate()
        for m in self.slots:
            me.materials.append(WM[m])
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def sink(name):
    if name not in SINKS:
        SINKS[name] = Sink(name)
    return SINKS[name]


def new_src(mb, sink_name, t):
    """New geometry built with the intact's MB helpers, sent whole to `sink_name` under transform `t`."""
    ob = mb.obj()
    s = Src(ob)
    for f in range(s.nf):
        s.sink[f], s.t[f] = sink_name, t
    s.emit()
    bpy.data.objects.remove(ob, do_unlink=True)


def nz(p, scale, off=(0.0, 0.0, 0.0)):
    return noise.noise(Vector((p[0] * scale + off[0], p[1] * scale + off[1], p[2] * scale + off[2])))


def h01(*a):
    """A repeatable 0..1 hash."""
    x = math.sin(sum(v * k for v, k in zip(a, (12.9898, 78.233, 37.719, 4.581)))) * 43758.5453
    return x - math.floor(x)


# --------------------------------------------------------------------------
# Cutting the intact meshes (bmesh, in place)
# --------------------------------------------------------------------------
def bisect(obj, co, no, keep=None, fill_mat=None, fill_uv=None):
    """Splits `obj`'s faces (those `keep(centroid_godot)` passes, or all) on the plane through `co` with normal
    `no` (Godot) and pulls the two sides apart at the cut (split edges). Optionally fills the holes the cut leaves
    in faces of material `fill_mat` (a glowing broken face). Returns the cut's points (Godot)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    faces = list(bm.faces)
    if keep is not None:
        def gc(f):
            c = f.calc_center_median()
            return (c.x, c.z, -c.y)
        faces = [f for f in faces if keep(gc(f))]
    verts = list({v for f in faces for v in f.verts})
    edges = list({e for f in faces for e in f.edges})
    res = bmesh.ops.bisect_plane(bm, geom=verts + edges + faces, dist=1e-5, plane_co=G(co), plane_no=G(no))
    cut_e = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    cut_v = [v for v in res["geom_cut"] if isinstance(v, bmesh.types.BMVert)]
    pts = [V(v.co.x, v.co.z, -v.co.y) for v in cut_v]
    bmesh.ops.split_edges(bm, edges=cut_e)
    if fill_mat is not None:
        names = [m.name for m in obj.data.materials]
        if fill_mat in names:
            k = names.index(fill_mat)
            pl, pn = G(co), G(no)
            bound = [e for e in bm.edges if len(e.link_faces) == 1 and e.link_faces[0].material_index == k
                     and all(abs((v.co - pl).dot(pn)) < 1e-3 for v in e.verts)]
            made = bmesh.ops.holes_fill(bm, edges=bound, sides=0)
            uvl = bm.loops.layers.uv.active
            for f in made["faces"]:
                f.material_index = k
                f.smooth = False
                for lp in f.loops:
                    lp[uvl].uv = fill_uv
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return pts


# --------------------------------------------------------------------------
# Materials: the intact's on a sooted copy of its atlas
# --------------------------------------------------------------------------
def soot_atlas():
    src = bpy.data.images["galleon_atlas"]
    H = W_ = sg.ATLAS
    px = np.empty(H * W_ * 4, dtype=np.float32)
    src.pixels.foreach_get(px)
    img = px.reshape(H, W_, 4)
    blot = 0.65 * sg.wnoise(H, W_, 24, 48, 9001) + 0.35 * sg.wnoise(H, W_, 6, 12, 9002)
    blot = np.clip((blot - 0.35) / 0.5, 0.0, 1.0)
    fine = sg.wnoise(H, W_, 2, 4, 9003)
    for band, (v0, v1) in sg.BAND.items():
        r0, r1 = int(round(v0 * H)), int(round(v1 * H))
        amt = SOOT["canvas"] if band == "canvas" else (SOOT["tar"] if band == "tar" else SOOT["timber"])
        b = blot[r0:r1] * (0.75 + 0.25 * fine[r0:r1])
        mult = 1.0 - amt * b
        img[r0:r1, :, :3] *= mult[..., None]
        if band == "canvas":
            # scorched brown at the edge of the soot, cloth darkened all over
            ring = np.clip(1.0 - np.abs(b - 0.45) / 0.25, 0.0, 1.0)
            img[r0:r1, :, 0] = img[r0:r1, :, 0] * (1 - 0.35 * ring) + 0.30 * ring * 0.55
            img[r0:r1, :, 1] = img[r0:r1, :, 1] * (1 - 0.35 * ring) + 0.17 * ring * 0.55
            img[r0:r1, :, 2] = img[r0:r1, :, 2] * (1 - 0.35 * ring) + 0.07 * ring * 0.55
            img[r0:r1, :, :3] *= 0.58
        else:
            img[r0:r1, :, :3] *= 0.9
    # the brass cell tarnished and smoked
    k = sg.CELLS.index("brass")
    c0 = int(round(sg.CELL_V[0] * H))
    cw = W_ // 8
    img[c0:H, k * cw:(k + 1) * cw, :3] *= 0.7
    im = bpy.data.images.new("wreck_atlas", W_, H, alpha=True)
    im.pixels.foreach_set(np.clip(img, 0, 1).reshape(-1))
    im.update()
    im.pack()
    return im


def make_wreck_materials():
    atlas = soot_atlas()
    emit = bpy.data.images["galleon_emission"]
    mk = sg.make_material
    WM["Wood"] = mk("W_Wood", atlas, 0.82, cull=False, emit_img=emit, emit_strength=1.2)
    WM["Tar"] = mk("W_Tar", atlas, 0.85, cull=False)
    WM["Paint"] = mk("W_Paint", atlas, 0.7, cull=False)
    WM["Canvas"] = mk("W_Canvas", atlas, 0.92, cull=False)
    WM["Brass"] = mk("W_Brass", atlas, 0.45, metal=1.0)
    WM["EtheriumGlow"] = mk("W_EtheriumGlow", atlas, 0.55, cull=False, alpha=True, emit_img=emit,
                            emit_strength=3.0, spec=0.15)
    e = bpy.data.materials.new("W_Earth")
    try:
        e.use_nodes = True
    except AttributeError:
        pass
    bsdf = next(n for n in e.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.055, 0.042, 0.032, 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    WM["Earth"] = e
    sg.MATS["Earth"] = e


# --------------------------------------------------------------------------
# The breaking
# --------------------------------------------------------------------------
def classify_hull(h, t_fore, t_aft, t_ka, t_kb):
    lost = {"rag": 0, "hole": 0, "pylon": 0}
    for f in range(h.nf):
        c = h.fc[f]
        bmin, bmax = h.bb[int(h.fi[f])]
        if bmax[1] < 0.25:                       # the keel crystal and its cradle
            if bmax[1] > -0.32:                  # the pylons and the shoe, torn off with the keel
                lost["pylon"] += 1
                continue
            side = float(np.dot(c - np.array(CRACK_P), np.array(CRACK_N)))
            h.sink[f], h.t[f] = "Keelstone", (t_kb if side > 0 else t_ka)
            continue
        if c[0] > 2.2:
            e = ((c[1] - HOLE_C.y) / HOLE_R[0]) ** 2 + ((c[2] - HOLE_C.z) / HOLE_R[1]) ** 2
            if e < 1.0 + 0.45 * nz(c, 1.3, (5, 1, 2)):
                lost["hole"] += 1
                continue
        d = float(np.dot(c - np.array(CUT_P), np.array(CUT_N)))
        if abs(d) < RAG[0] + RAG[1] * max(nz(c, 0.8, (11, 3, 7)) * 1.6, 0.0):
            lost["rag"] += 1
            continue
        fore = d < 0
        band = abs(d) < BURN_BAND
        h.sink[f] = ("Burn_BreakFore" if band else "Hull_Fore") if fore else ("Burn_BreakAft" if band else "Hull_Aft")
        h.t[f] = t_fore if fore else t_aft
    print("WRECK hull faces lost:", lost)


def region(c):
    return "fore" if c[2] < -2.7 else "main"


def classify_rig(r, t_hull, t_fall):
    jb = sg.bowsprit_geo()
    n = {"lower": 0, "upper": 0, "gone": 0}
    for f in range(r.nf):
        i = int(r.fi[f])
        bmin, bmax = r.bb[i]
        c = r.ic[i]
        if bmin[2] < (jb["jb1"].z + 0.6):        # the jib-boom, snapped off
            n["gone"] += 1
            continue
        key = region(c)
        brk = BREAK[key]
        spans_both = bmin[2] < -2.7 < bmax[2] and bmax[1] > 8.0
        if bmax[1] <= brk + 0.45:
            r.sink[f], r.t[f] = "Rig", t_hull
            n["lower"] += 1
        elif bmin[1] >= brk - 0.45 and not spans_both:
            r.sink[f], r.t[f] = ("Fallen_Fore" if key == "fore" else "Fallen_Main"), t_fall[key]
            n["upper"] += 1
        else:
            n["gone"] += 1
    print("WRECK rig faces:", n)


def classify_sails(s, t_hull, t_fall):
    n = {"rope": 0, "torn": 0, "kept": 0, "gone": 0}
    rope = {}
    for i in s.nfi:
        fs = np.nonzero(s.fi == i)[0]
        a = np.mean([s.area(int(f)) for f in fs[:12]])
        rope[i] = a < 0.06
    for f in range(s.nf):
        i = int(s.fi[f])
        if rope[i]:
            n["rope"] += 1
            continue
        bmin, bmax = s.bb[i]
        c = s.fc[f]
        key = region(s.ic[i])
        brk = BREAK[key]
        hrel = (c[1] - bmin[1]) / max(bmax[1] - bmin[1], 0.1)
        hole = nz(c, 0.45, (3.3, 7.7, 1.1)) > 0.22
        foot = hrel < 0.20 + 0.28 * (nz(c, 0.9, (8, 2, 5)) + 1.0) * 0.5
        if bmin[1] >= brk - 4.2 and bmax[1] > brk:
            if hole or foot:
                n["torn"] += 1
                continue
            s.sink[f], s.t[f] = ("Burn_SailsFore" if key == "fore" else "Burn_SailsMain"), t_fall[key]
            n["kept"] += 1
        elif key == "main" and c[1] < brk - 3.0 and not (hole or nz(c, 1.4, (1, 9, 4)) > 0.15):
            s.sink[f], s.t[f] = "Burn_Boom", t_hull       # a ragged strip of the mainsail left on the boom
            n["kept"] += 1
        else:
            n["gone"] += 1
    print("WRECK sail faces:", n)


def classify_wings(w, t_hull, t_fall):
    n = {"membrane": 0, "parts": 0, "port_wing": 0, "kept": 0}
    hubs = [sg.fan_hub(k, sd) for k in sg.FANS for sd in (1, -1)]
    for f in range(w.nf):
        i = int(w.fi[f])
        bmin, bmax = w.bb[i]
        c = w.fc[f]
        ic = w.ic[i]
        membrane = w.mat(f) == "EtheriumGlow" and w.nfi[i] >= 18
        if bmax[1] < 3.6:                            # the keel-wings
            if ic[0] < 0.0:
                n["port_wing"] += 1
                continue
            if membrane and nz(c, 0.55, (2, 4, 6)) > -0.02:
                n["membrane"] += 1
                continue
            w.sink[f], w.t[f] = "WingSails", t_hull
            n["kept"] += 1
            continue
        key = "fore" if ic[2] < -2.7 else "main"
        if membrane:
            if nz(c, 0.42, (7, 1, 3)) > -0.18:
                n["membrane"] += 1
                continue
        else:
            near_hub = min((Vector(ic) - hb).length for hb in hubs) < 0.8
            if not near_hub and nz(ic, 0.3, (4, 4, 9)) > 0.12:
                n["parts"] += 1
                continue
        w.sink[f], w.t[f] = "WingSails", t_fall[key]
        n["kept"] += 1
    print("WRECK wing faces:", n)


# --------------------------------------------------------------------------
# New pieces: splinters, slack lines, the spar, spilled planks, shards, the furrow
# --------------------------------------------------------------------------
def splinters_break(cut_pts, rng):
    """Planks jutting from each side of the hull's break (they start back in the part that is left, past where
    the others tore out)."""
    oak = sg.UB("oak", 4.0)
    out = {}
    pts = [p for p in cut_pts if (abs(p.x) > 1.6 or p.y > 3.0) and p.y > 0.6]
    rng.shuffle(pts)
    for side, sign in (("fore", -1.0), ("aft", 1.0)):
        mb = sg.MB("Splinters_" + side)
        for p in pts[:22] if side == "fore" else pts[22:44]:
            radial = V(p.x, p.y - 2.2, 0.0)
            up = radial.normalized() if radial.length > 0.1 else V(0, 1, 0)
            L = 0.9 + 1.4 * rng.random()
            a = p + CUT_N * (sign * 1.05)
            dirn = (-CUT_N * sign + up * (0.25 * (rng.random() - 0.3)) + V(0, 0, 0)).normalized()
            b = a + dirn * L
            mb.beam(a, b, 0.18 + 0.12 * rng.random(), 0.07, up, "Wood", oak)
            # its split end
            tip = b + dirn * (0.25 + 0.3 * rng.random()) + up.cross(dirn) * (0.06 * (rng.random() - 0.5))
            mb.tube([b - dirn * 0.02, tip], [0.06, 0.0], "Wood", oak, sides=4, cap0=False)
        out[side] = mb
    return out


def mast_spikes(key, up_side, rng):
    """Splinters round a mast's snap: on the stump pointing up (up_side) or on the fallen top pointing down."""
    m = sg.FORE if key == "fore" else sg.MAIN
    brk = BREAK[key]
    c = m.at(brk)
    r = sg.SPEC[key]["r"][0] * 0.9
    grain = sg.UB("grain", 4.0)
    mb = sg.MB("Spikes_%s_%d" % (key, up_side))
    sgn = 1.0 if up_side else -1.0
    for k in range(9):
        a = 2 * math.pi * (k + 0.3 * rng.random()) / 9
        rad = V(math.cos(a), 0.0, math.sin(a))
        # on the slanted snap plane
        base = c + rad * (r * (0.35 + 0.6 * rng.random()))
        base.y -= (SNAP_N.x * (base.x - c.x) + SNAP_N.z * (base.z - c.z)) / SNAP_N.y
        tip = base + V(0, sgn * (0.25 + 0.7 * rng.random()), 0) + rad * (0.05 * rng.random())
        mb.tube([base - V(0, sgn * 0.15, 0), tip], [0.05 + 0.04 * rng.random(), 0.0], "Wood", grain, sides=4,
                cap0=True)
    return mb


def slack_lines(rng):
    """A few lines hanging slack from each stump, down over the side and onto the deck."""
    mb = sg.MB("SlackLines")
    tar = sg.UB("tar", 2.0)
    for key in ("fore", "main"):
        m = sg.FORE if key == "fore" else sg.MAIN
        top = m.at(BREAK[key] - 0.4)
        for k in range(5):
            side = -1.0 if k % 2 == 0 else 1.0
            a = top + V(side * 0.3, -0.2 * k, 0.15 * (k - 2))
            b = V(side * (3.0 + 0.9 * rng.random()), 4.3 + 0.8 * rng.random(), m.z0 + (rng.random() - 0.5) * 3.0)
            if k == 4:
                b = V(-4.6, 1.6, m.z0 + 1.0)            # down over the port rail
            sag = 1.2 + 1.6 * rng.random()
            path = []
            for j in range(9):
                t = j / 8
                p = sg.lerp(a, b, t)
                p.y -= sag * 4 * t * (1 - t)
                path.append(p)
            mb.tube(path, 0.028, "Tar", tar, sides=4)
    return mb


def spar_mesh(rng):
    """The loose yard: 6 m, tapered to its arms, iron bands, one end broken off; local X along it, centred."""
    mb = sg.MB("SparMesh")
    grain = sg.UB("grain", 4.0)
    tar = sg.UB("tar", 2.0)
    h = SPAR_LEN * 0.5
    xs = [-h, -h + 0.25, -0.55 * h, 0.0, 0.55 * h, h - 0.1]
    rs = [SPAR_R * 0.42, SPAR_R * 0.5, SPAR_R * 0.85, SPAR_R, SPAR_R * 0.86, SPAR_R * 0.62]
    mb.tube([V(x, 0, 0) for x in xs], rs, "Wood", grain, sides=10, cap0=True, cap1=True)
    for x in (-0.65, 0.65):
        mb.tube([V(x - 0.07, 0, 0), V(x + 0.07, 0, 0)], SPAR_R * 1.07, "Tar", tar, sides=10, cap0=True, cap1=True)
    for k in range(7):                             # the broken end
        a = 2 * math.pi * (k + 0.4 * rng.random()) / 7
        rad = V(0, math.cos(a), math.sin(a)) * (SPAR_R * 0.62 * (0.3 + 0.6 * rng.random()))
        b = V(h - 0.16, 0, 0) + rad
        mb.tube([b, b + V(0.25 + 0.4 * rng.random(), 0, 0) + rad * 0.2], [0.035 + 0.025 * rng.random(), 0.0],
                "Wood", grain, sides=4, cap0=True)
    return mb


def spilled_planks(rng):
    """Planks spilled on the ground under the hole (wreck frame)."""
    mb = sg.MB("Planks")
    oak = sg.UB("oak", 4.0)
    deck = sg.UB("deck", 4.0)
    centre = V(4.6, 0.0, -5.6)
    for k in range(13):
        a = rng.random() * math.pi
        d = V(math.cos(a), 0.12 * (rng.random() - 0.5), math.sin(a)).normalized()
        L = 1.6 + 1.8 * rng.random()
        c = centre + V((rng.random() - 0.5) * 3.6, 0.04 + 0.09 * (k % 3), (rng.random() - 0.5) * 3.2)
        up = V(0.15 * (rng.random() - 0.5), 1.0, 0.15 * (rng.random() - 0.5)).normalized()
        mb.beam(c - d * L * 0.5, c + d * L * 0.5, 0.22 + 0.08 * rng.random(), 0.07, up, "Wood", oak if k % 2 else deck)
    return mb


def keel_shards(rng):
    """Splinters of the crystal round it (wreck frame)."""
    mb = sg.MB("Shards")
    cu = sg.UC("crystal", 1.0)
    for k in range(7):
        a = rng.random() * 2 * math.pi
        rr = 1.4 + 1.6 * rng.random()
        c = KEEL_AT + V(math.cos(a) * rr, -KEEL_AT.y + 0.05, math.sin(a) * rr * 1.3)
        s = 0.12 + 0.2 * rng.random()
        ax = V(rng.random() - 0.5, 0.6 * rng.random() - 0.1, rng.random() - 0.5).normalized()
        sg.lathe(mb, c - ax * (s * 1.4), ax, [(0, 0.0), (s * 0.9, s * 0.45), (s * 1.9, s * 0.4), (s * 2.8, 0.0)],
                 "EtheriumGlow", cu, sides=6, cap0=False, cap1=False, smooth=False)
    return mb


def furrow(hull_pts, rng):
    """Churned earth: a mound thrown up ahead of the bow and a ridge along the buried port bilge (wreck frame)."""
    mb = sg.MB("FurrowMesh")
    uvm = sg.UC("hemp", 1.0)
    low = hull_pts[(hull_pts[:, 1] > -0.4) & (hull_pts[:, 1] < 0.4)]
    bow_z = float(low[:, 2].min()) if len(low) else -13.0

    def mound(cx, cz, rx, rz, hgt, nu=14, nv=7, seed=0.0):
        P = []
        for i in range(nu + 1):
            a = 2 * math.pi * i / nu
            row = []
            for j in range(nv + 1):
                r = j / nv
                x, z = cx + math.cos(a) * rx * r, cz + math.sin(a) * rz * r
                y = hgt * (1.0 - r * r) ** 1.4 * (0.75 + 0.35 * nz((x, 0, z), 0.9, (seed, 2, 3))) - 0.08 * r
                row.append(V(x, y, z))
            P.append(row)
        mb.grid(P, lambda i, j, i0, j0: uvm(0.5, 0.5), lambda i, j: "Earth", smooth=True,
                out=lambda i, j, pts: V(0, 1, 0))
    mound(-0.6, bow_z - 1.2, 4.2, 2.6, 0.95, seed=1.0)
    # the ridge along the port side: the hull's ground line on that side, pushed out
    port = low[low[:, 0] < -1.0]
    zs = np.linspace(bow_z + 1.0, 7.5, 14)
    P = []
    for z in zs:
        near = port[np.abs(port[:, 2] - z) < 1.0]
        x0 = float(near[:, 0].min()) if len(near) else -3.2
        row = []
        for j, (dx, y) in enumerate(((0.35, 0.05), (-0.25, 0.42), (-0.9, 0.3), (-1.7, 0.08), (-2.6, -0.1))):
            yy = y * (0.7 + 0.4 * (nz((x0, 0, z), 0.7, (9, 9, 1)) + 1) * 0.5)
            row.append(V(x0 + dx, yy, z))
        P.append(row)
    mb.grid(P, lambda i, j, i0, j0: uvm(0.5, 0.5), lambda i, j: "Earth", smooth=True,
            out=lambda i, j, pts: V(0, 1, 0))
    return mb


# --------------------------------------------------------------------------
# Assembly
# --------------------------------------------------------------------------
def godot_matrix(B, o):
    """A Blender matrix_world for a node whose Godot basis is B (3x3 numpy) and origin o."""
    C = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]], dtype=np.float64)
    M = np.eye(4)
    M[:3, :3] = C @ B @ C.T
    M[:3, 3] = C @ np.array((o[0], o[1], o[2]))
    return Matrix([list(r) for r in M])


def build():
    rng = np.random.default_rng(1757)
    noise.seed_set(1757)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    sg.make_materials()
    make_wreck_materials()
    hull_mb, info = sg.build_hull("SrcHull", 0)
    rig_mb, pts = sg.build_rig("SrcRig", 0)
    sails_mb = sg.build_sails("SrcSails", 0)
    wings_mb = sg.build_wingsails("SrcWings", 0)
    hull, rig, sails, wings = hull_mb.obj(), rig_mb.obj(), sails_mb.obj(), wings_mb.obj()
    # the cuts
    cut = bisect(hull, CUT_P, CUT_N, keep=lambda c: c[1] > 0.25)
    cu = sg.UC("crystal", 1.0)
    bisect(hull, CRACK_P, CRACK_N, keep=lambda c: c[1] < 0.0 and abs(c[0]) < 1.4,
           fill_mat="EtheriumGlow", fill_uv=cu(0.5, 0.5))
    for key, m in (("fore", sg.FORE), ("main", sg.MAIN)):
        c0 = m.at(BREAK[key])
        bisect(rig, c0, SNAP_N, keep=lambda c, c0=c0: math.hypot(c[0] - c0.x, c[2] - c0.z) < 0.8
               and abs(c[1] - c0.y) < 2.5)
    # the transforms
    t_fore, t_aft = tid(W), tid(W_AFT)
    C = np.array(sg.CRYSTAL_C)
    Rk = m_rot("Y", KEEL_YAW) @ m_rot("Z", KEEL_ROLL)
    t_ka = tid(m_tr(KEEL_AT) @ Rk @ m_tr(-C))
    Rb = m_tr(np.array(CRACK_P)) @ m_rot("X", 8.0) @ m_rot("Y", -6.0) @ m_tr(-np.array(CRACK_P))
    t_kb = tid(m_tr(KEEL_AT) @ Rk @ m_tr(np.array(CRACK_N) * 0.34 + np.array((0.0, -0.06, 0.0))) @ m_tr(-C) @ Rb)
    falls = {}
    t_fall = {}
    for key in ("fore", "main"):
        M, a, b = fallen_matrix(key, pts)
        falls[key] = (a, b)
        t_fall[key] = tid(M)
    t_world = tid(I4)
    # classify and copy
    srcs = []
    h = Src(hull)
    classify_hull(h, t_fore, t_aft, t_ka, t_kb)
    srcs.append(h)
    r = Src(rig)
    classify_rig(r, t_fore, t_fall)
    srcs.append(r)
    s = Src(sails)
    classify_sails(s, t_fore, t_fall)
    srcs.append(s)
    w = Src(wings)
    classify_wings(w, t_fore, t_fall)
    srcs.append(w)
    for src in srcs:
        print("WRECK %-9s kept %d of %d faces" % (src.name, src.emit(), src.nf))
    # new pieces
    spl = splinters_break(cut, rng)
    new_src(spl["fore"], "Burn_BreakFore", t_fore)
    new_src(spl["aft"], "Burn_BreakAft", t_aft)
    for key in ("fore", "main"):
        new_src(mast_spikes(key, True, rng), "Rig", t_fore)
        new_src(mast_spikes(key, False, rng), "Fallen_Fore" if key == "fore" else "Fallen_Main", t_fall[key])
    new_src(slack_lines(rng), "Rig", t_fore)
    new_src(spilled_planks(rng), "Burn_Debris", t_world)
    new_src(keel_shards(rng), "Keelstone", t_world)
    hull_world = apply(W, h.P)
    new_src(furrow(hull_world, rng), "Furrow", t_world)
    t_id = tid(I4)
    new_src(spar_mesh(rng), "Spar", t_id)
    for o in (hull, rig, sails, wings):
        bpy.data.objects.remove(o, do_unlink=True)
    objs = {nm: sk.obj() for nm, sk in SINKS.items()}
    cols = [collider(objs, "HullFore_Col", ["Hull_Fore", "Burn_BreakFore"]),
            collider(objs, "HullAft_Col", ["Hull_Aft", "Burn_BreakAft"])]
    # the spar lies across the stranger's place: along X, one end on the ground, propped over him
    spar = objs["Spar"]
    yaw = math.radians(8.0)
    tilt = math.radians(4.0)
    B = np.array(Matrix.Rotation(yaw, 3, "Y") @ Matrix.Rotation(tilt, 3, "Z"))
    spar.matrix_world = godot_matrix(B, PINNED_AT + V(0.4, 0.34, 0.0))
    # Ithel's seat: his shoulders against the hull bottom, found by a ray from the open ground
    ithel, ithel_lean = seat_for_ithel(objs)
    empties = {
        "KeelGlow": KEEL_AT,
        "Ithel": ithel,
        "Pinned": PINNED_AT,
        "FallenFore_A": falls["fore"][0], "FallenFore_B": falls["fore"][1],
        "FallenMain_A": falls["main"][0], "FallenMain_B": falls["main"][1],
        "Deck": vec(apply(W, V(0, sg.deck_surface_y(sg.s_of_zn(-2.7), 0.0), -2.7))),
        "Bow": vec(apply(W, V(0, sg.sheer(0.0), sg.Z_BOW_TOP))),
        "Stern": vec(apply(W_AFT, V(0, sg.sheer(1.0) + sg.E_QD + 0.56, 13.2))),
    }
    em = [sg.add_empty(nm, p) for nm, p in empties.items()] + [c for c in cols if c is not None]
    # Ithel's empty carries his whole seat: facing +X (its -Z), leaned back toward the hull (its +Y)
    fwd = V(1, 0, 0)
    zb = -fwd
    l = math.radians(ithel_lean)
    up = (V(0, 1, 0) * math.cos(l) + zb * math.sin(l)).normalized()
    xb = up.cross(zb).normalized()
    zb = xb.cross(up).normalized()
    B = np.array([[xb.x, up.x, zb.x], [xb.y, up.y, zb.y], [xb.z, up.z, zb.z]])
    e_it = next(e for e in em if e.name == "Ithel")
    e_it.matrix_world = godot_matrix(B, ithel)
    check_clear(objs, empties)
    # the intact's own materials and atlas out; the wreck's take their names
    for m in list(bpy.data.materials):
        if not m.name.startswith("W_"):
            bpy.data.materials.remove(m)
    for m in list(bpy.data.materials):
        m.name = m.name[2:]
    if "galleon_atlas" in bpy.data.images:
        bpy.data.images.remove(bpy.data.images["galleon_atlas"])
    bpy.data.images["galleon_emission"].name = "wreck_emission"
    return objs, em, empties


def collider(objs, name, parts, cell=0.6):
    """A convex hull round `parts` above the ground's skirt, from one vertex per `cell` m (the extremes kept well
    enough), named for Godot's importer to make it a StaticBody3D with a convex shape (suffix -convcolonly): the
    shape is built at import, never on the frame the ship lands."""
    pts = []
    for nm in parts:
        ob = objs.get(nm)
        if ob is None:
            continue
        for v in ob.data.vertices:
            if v.co.z > -0.9:                     # (Blender z = Godot y: above most of the buried skirt)
                pts.append(Vector(v.co))
    if len(pts) < 8:
        return None
    seen = {}
    for p in pts:
        k = (round(p.x / cell), round(p.y / cell), round(p.z / cell))
        q = seen.get(k)
        if q is None:
            seen[k] = p
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in seen.values()]
    res = bmesh.ops.convex_hull(bm, input=vs)
    drop = list({g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)})
    if drop:
        bmesh.ops.delete(bm, geom=drop, context="VERTS")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name + "-convcolonly", me)
    bpy.context.scene.collection.objects.link(ob)
    print("WRECK collider %-13s %d points, %d faces" % (name, len(me.vertices), len(me.polygons)))
    return ob


def ray(objs, names, o, d, far=30.0):
    best = None
    for nm in names:
        ob = objs.get(nm)
        if ob is None:
            continue
        bvh = BVHTree.FromObject(ob, bpy.context.evaluated_depsgraph_get())
        hit = bvh.ray_cast(G(o), G(d).normalized(), far)
        if hit[0] is not None:
            dist = hit[3]
            if best is None or dist < best[1]:
                best = (V(hit[0].x, hit[0].z, -hit[0].y), dist, nm)
    return best


def seat_for_ithel(objs):
    """Where along the starboard side (ITHEL_Z) the hull bottom stands steepest at a seated man's back (rays at
    hip and shoulder height from the open ground), with headroom over the seat: his seat ITHEL_BACK out from where
    his shoulders touch, facing +X, and the lean back (deg) that lays his back along the planking."""
    names = ["Hull_Fore", "Burn_BreakFore", "Hull_Aft", "Burn_BreakAft"]
    best = None
    for z in np.arange(ITHEL_Z[0], ITHEL_Z[1] + 0.01, 0.5):
        lo = ray(objs, names, V(9.0, 0.25, z), V(-1, 0, 0))
        hi = ray(objs, names, V(9.0, ITHEL_SHOULDER, z), V(-1, 0, 0))
        if lo is None or hi is None:
            continue
        dx = hi[0].x - lo[0].x
        seat = V(hi[0].x + ITHEL_BACK, 0.0, z)
        up = ray(objs, [n for n in objs if n not in ("Spar", "Furrow")], seat + V(0, 0.05, 0), V(0, 1, 0), 40.0)
        room = up[1] if up else 99.0
        lean = math.degrees(math.atan2(max(dx, 0.0), ITHEL_SHOULDER - 0.25))
        score = dx + (0.0 if room >= 1.2 else 3.0) + 0.05 * abs(z - ITHEL_Z_PREF)
        if best is None or score < best[0]:
            best = (score, seat, lean, room, z)
    if best is None:
        print("WRECK Ithel: no hull found; seat on the open ground")
        return V(3.0, 0.0, -1.4), 0.0
    _, seat, lean, room, z = best
    lean = min(max(lean - 20.0, 0.0), 25.0)
    print("WRECK Ithel: seat (%.2f, 0, %.2f), hull %.1f deg from upright there, lean back %.1f deg, headroom %.2f m"
          % (seat.x, seat.z, lean + 20.0, lean, room))
    return seat, lean


def check_clear(objs, empties):
    every = [n for n in objs if n not in ("Spar", "Furrow")]
    for nm, need in (("Ithel", 1.25), ("Pinned", 1.2), ("KeelGlow", 0.9)):
        p = empties[nm]
        up = ray(objs, every, p + V(0, 0.05, 0), V(0, 1, 0), 40.0)
        print("WRECK clear over %-8s %s" % (nm, ("%.2f m (%s)" % (up[1], up[2])) if up else "open sky"),
              "" if (up is None or up[1] >= need) else "  << LOW")


# --------------------------------------------------------------------------
# Previews (Eevee, 960 x 540): night by the fire, and day from above
# --------------------------------------------------------------------------
def render(out_dir, objs, empties, more=False):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.eevee.taa_render_samples = 16
    sc.render.resolution_x, sc.render.resolution_y = 960, 540
    sc.view_settings.view_transform = "AgX"
    for o in objs.values():
        if o.name == "WingSails":
            o.visible_shadow = False
    # ground, a few pines for scale, stand-ins for the two men
    gm = bpy.data.materials.new("PrevGround")
    gm.use_nodes = True
    gb = next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    gb.inputs["Base Color"].default_value = (0.07, 0.075, 0.05, 1)
    gb.inputs["Roughness"].default_value = 1.0
    bpy.ops.mesh.primitive_plane_add(size=160, location=(0, 0, 0))
    bpy.context.active_object.data.materials.append(gm)
    pm = bpy.data.materials.new("PrevPine")
    pm.use_nodes = True
    pb = next(n for n in pm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    pb.inputs["Base Color"].default_value = (0.03, 0.06, 0.035, 1)
    rng = np.random.default_rng(3)
    for k in range(34):
        a = rng.random() * 2 * math.pi
        rr = 18 + 30 * rng.random()
        x, z = math.cos(a) * rr, math.sin(a) * rr * 1.2
        if z > 8 and abs(x) < 9:
            continue                    # the swath it came down through
        h = 14 + 8 * rng.random()
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=2.2 + rng.random(), depth=h, location=G(V(x, h * 0.5, z)))
        bpy.context.active_object.data.materials.append(pm)
    sm = bpy.data.materials.new("PrevMan")
    sm.use_nodes = True
    sb = next(n for n in sm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    sb.inputs["Base Color"].default_value = (0.25, 0.2, 0.16, 1)
    it = empties["Ithel"]
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.22, depth=0.95, location=G(it + V(-0.12, 0.5, 0)))
    bpy.context.active_object.rotation_euler = (0, math.radians(-18), 0)
    bpy.context.active_object.data.materials.append(sm)
    pn = empties["Pinned"]
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.2, depth=1.75, location=G(pn + V(0, 0.17, 0)),
                                        rotation=(0, 0, 0))
    bpy.context.active_object.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.active_object.data.materials.append(sm)
    night = sg.make_world("Night", [(0.0, (0.004, 0.005, 0.008)), (0.5, (0.02, 0.025, 0.045)),
                                    (1.0, (0.008, 0.012, 0.03))], 0.6)
    day = sg.make_world("Day", [(0.0, (0.16, 0.22, 0.13)), (0.5, (0.70, 0.80, 0.92)), (1.0, (0.10, 0.24, 0.62))], 1.0)
    sun_d = bpy.data.lights.new("Sun", "SUN")
    sun = bpy.data.objects.new("Sun", sun_d)
    sc.collection.objects.link(sun)
    lights = []

    def point(nm, p, col, e, r=0.5):
        ld = bpy.data.lights.new(nm, "POINT")
        ld.color, ld.energy, ld.shadow_soft_size = col, e, r
        lo = bpy.data.objects.new(nm, ld)
        lo.location = G(p)
        sc.collection.objects.link(lo)
        lights.append(lo)
    point("Keel", empties["KeelGlow"] + V(0, 1.2, 0), (1.0, 0.62, 0.22), 1800.0, 0.6)
    for nm in ("Burn_BreakFore", "Burn_BreakAft", "Burn_Debris", "Burn_SailsFore", "Burn_SailsMain"):
        ob = objs.get(nm)
        if ob is None:
            continue
        bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
        c = sum(bb, Vector()) / 8.0
        point("Fire_" + nm, V(c.x, c.z, -c.y), (1.0, 0.5, 0.2), 900.0, 1.2)
    cd = bpy.data.cameras.new("Cam")
    cd.clip_start, cd.clip_end = 0.1, 600.0
    cam = bpy.data.objects.new("Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    shots = [
        # name, camera, target, lens, world, night
        ("wreck_starboard_night", V(17.0, 3.4, -6.5), V(3.2, 1.8, 0.8), 28, night, True),
        ("wreck_bow3q_night", V(-20.0, 8.5, -34.0), V(-2.0, 3.5, -4.0), 30, night, True),
        ("wreck_above_day", V(34.0, 48.0, 30.0), V(-2.0, 0.0, -2.0), 30, day, False),
    ]
    if more:
        shots += [
            ("wreck_aft_day", V(16.0, 9.0, 30.0), V(-1.0, 3.0, 3.0), 30, day, False),
            ("wreck_port_day", V(-38.0, 14.0, 4.0), V(-6.0, 3.0, -2.0), 30, day, False),
            ("wreck_keel_day", V(10.0, 2.2, -4.5), V(3.5, 0.9, 1.5), 30, day, False),
        ]
    for name, loc, tgt, lens, world, is_night in shots:
        sc.world = world
        cd.lens = lens
        sg.look(cam, loc, tgt)
        sdir = V(0.3, 0.8, -0.5) if not is_night else V(-0.4, 0.6, 0.6)
        sun.rotation_euler = (-G(sdir.normalized())).to_track_quat("-Z", "Y").to_euler()
        sun_d.energy = 3.0 if not is_night else 0.08
        sun_d.color = (1.0, 0.95, 0.88) if not is_night else (0.6, 0.7, 1.0)
        for lo in lights:
            lo.hide_render = not is_night
        sg.setup_compositor(sc, is_night)
        sc.render.filepath = os.path.join(out_dir, "%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDERED", sc.render.filepath)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(PROJECT, "assets", "sky", "sky_galleon_wreck.glb"))
    ap.add_argument("--renders", default=None)
    ap.add_argument("--blend", default=None)
    ap.add_argument("--more", action="store_true", help="three more check shots by day")
    args = ap.parse_args(argv)
    objs, empties, where = build()
    total = 0
    for nm, o in sorted(objs.items()):
        t = sg.tri_count(o)
        total += t
        B = np.array([v.co[:] for v in o.data.vertices]) if len(o.data.vertices) else np.zeros((1, 3))
        P = np.stack([B[:, 0], B[:, 2], -B[:, 1]], axis=1)
        print("WRECK %-15s tris=%6d mats=%-40s y %.1f..%.1f x %.1f..%.1f z %.1f..%.1f" % (
            nm, t, [m.name for m in o.data.materials], P[:, 1].min(), P[:, 1].max(), P[:, 0].min(), P[:, 0].max(),
            P[:, 2].min(), P[:, 2].max()))
    print("WRECK total tris", total, "(budget 45000)")
    for nm, p in where.items():
        print("WRECK empty %-12s godot=(%.3f, %.3f, %.3f)" % (nm, p.x, p.y, p.z))
    sg.export_glb(list(objs.values()) + empties, args.out)
    print("EXPORTED", args.out)
    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    if args.renders:
        render(args.renders, objs, where, args.more)


if __name__ == "__main__":
    main()
