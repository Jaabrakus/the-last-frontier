"""Full-skin player body for the customizer: assets/character/body/body.glb (+ body.json).

Built by tools/character/build_character.sh --body (Blender, on a copy of the rig).

Meshes (both skinned to the 291-joint Actor_B armature, rest = null-add):
  Body   the whole skin, one surface "skin", split into the 38 hide regions of
         lib/regions.py with clean planar borders. The head is the v2 anatomical head
         (lib/face.py: eyelids with margins and pockets, nose with alae and nostrils, lips
         with a mouth seam, ears), polygonised on a 1 mm grid and stitched to the body
         (3 mm grid) below the jaw; its broad skin is smoothed (lib/face.taubin).
         Shape keys: `sex` (0 female .. 1 male fit, design 3), `sex_head` (the head part of
         `sex` only, for outfits built on the female body), `blink`, and the face features
         `face_*` (lib/face.FACE_FEATURES projected, FACE_WARPS as lid warps).
         Attributes: UVMap (skin detail, metres), Region (UV2.x = region id), COLOR_0
         (r: blood / flush, g: mucosa (vermilion, inner lid rims), b: cavity occlusion,
         a: beard mask for stubble).
  Face   the eyes and the face hair: surface "eye" (sclera, iris under a corneal bulge;
         UV = metres in the eye's front plane) and "face_hair" (zone 0 brows, zone 1
         lashes: cards, UV = 0..1 across / along, drawn by face_hair.gdshader). Brows follow
         the face shapes by wrap transfer, lashes follow the lid margins (warps, blink).
         Rigid on headb.

The male fit is the same topology and the same weights: the base (female) vertices
projected onto the male SDF. Stature (height) is not a shape: it is the uniform scale of
the Actor_B instance at runtime (design 3.3).

Also writes tools/character/cache/body_v<lib>.npz (BodyData) for the garment and hair
generators (weights transfer, regions, wrap transfer of the shape keys), and
assets/character/body/peoples.json (tools/character/body/peoples.py: presets per people).
"""

import json
import math
import os
import time

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from lib import LIB_VERSION
from lib import face as FC
from lib import paint as PT
from lib import regions as RG
from lib import stylize as ST
from lib import uv as UV
from lib.body_shapes import body_groups, body_node, body_sizing, face_params
from lib.context import ASSETS, BodyData
from lib.helpers import driver_reference, helpers_json
from lib.remesh import check_manifold, isotropic_remesh, material, mesh_arrays, mesh_object, sdf_object, tri_count
from lib.rig import PROVENANCE_RIG, export_glb, godot_xf, xf12
from lib.sdf import Fn, Inter, log, nrm, peval, sdf_normal, smoothstep, v3
from lib.shapes import add_shape_keys, project_shape, relax_folds, shape_stats
from lib.weights import body_weights, helper_weights, limit_normalize, mesh_adjacency, smooth_weights, write_groups
from lib.wrap import Surface

OUT_DIR = os.path.join(ASSETS, "body")
GLB = os.path.join(OUT_DIR, "body.glb")

# Skin: a continuous melanin value 0..1 along 12 anchors (linear interpolation in linear
# light), an undertone offset in Oklab a/b, and haemoglobin (blood under the skin, seen
# through the epidermis). UI labels "Tone 1-12" (never named after an ancestry; design
# 10.1, bible 1.2). The shader (assets/character/shaders/skin.gdshader) holds the same table.
# the dark end less saturated and a little yellower (2026-09-28: it read maroon), the deepest two
# darker (the deepest complexions); the Monk skin tone scale (Google, CC-BY 4.0) was the reference
SKIN_TONES = ["#f2d6c4", "#e9c3a9", "#dfb193", "#d19e7c", "#c08966", "#ac7754",
              "#966546", "#7e543b", "#684632", "#553929", "#3e2a1f", "#2d1f17"]
UNDERTONES = {"cool": [0.010, -0.012], "neutral": [0.0, 0.0], "warm": [0.004, 0.014], "olive": [-0.010, 0.010]}
EYE_IRIS = {"dark_brown": "#2a190f", "brown": "#4a2e1a", "light_brown": "#6a4322", "hazel": "#6b5a2c",
            "amber": "#8a5a22", "green": "#4f6a3a", "grey": "#6f7880", "blue_grey": "#5f7384", "blue": "#4d6f94"}

TRUNK_SMOOTH = 12         # extra weight smoothing iterations over the trunk (see build())
NAPE_SMOOTH = 16          # extra passes over the neck below the rigid head (see build())
HEAD_SMOOTH = 40          # Taubin iterations over the head's broad skin (lib/face.smooth_weights)
MATERIALS = {"skin": ("#c89478", 0.55), "eye": ("#d8d0c4", 0.2), "face_hair": ("#2a1d14", 0.7)}
# Neck seam between the coarse body and the fine head: the plane z = CUT_Z + CUT_SLOPE * y
# (lower at the throat, higher at the nape, clear of the jaw and of the shoulder tops),
# body kept below CUT_Z - CUT_GAP, head above CUT_Z + CUT_GAP, the gap bridged.
CUT_Z, CUT_SLOPE, CUT_GAP = 1.362, 0.35, 0.005
NECK_Y = 0.004            # neck axis (y) below the jaw


def _mats():
    return {k: material(k, h, r) for k, (h, r) in MATERIALS.items()}


def _cut(dz):
    n = nrm(v3(0, -CUT_SLOPE, 1.0))
    return v3(0, 0, CUT_Z + dz), n


def _above(P, dz):
    p, n = _cut(dz)
    return (np.asarray(P) - p) @ n > 0


def _head_box():
    """Head polygonisation region: above the seam plane, the neck column only below the jaw."""
    p, n = _cut(CUT_GAP - 0.008)

    def f(X, Y, Z):
        d = -((Y - p[1]) * n[1] + (Z - p[2]) * n[2])
        col = np.minimum(1.40 - Z, np.abs(X) - 0.075)          # no shoulder tops
        box = np.maximum(np.abs(X) - 0.115, np.maximum(-0.20 - Y, Y - 0.16))
        return np.maximum(np.maximum(d, col), box)
    return Fn(f, (-0.115, -0.20, 1.325), (0.115, 0.16, 1.64))


def _boundary_loops(bm):
    edges = [e for e in bm.edges if len(e.link_faces) == 1]
    seen, loops = set(), []
    for e in edges:
        if e in seen:
            continue
        stack, comp = [e], []
        while stack:
            x = stack.pop()
            if x in seen:
                continue
            seen.add(x)
            comp.append(x)
            for v in x.verts:
                for y in v.link_edges:
                    if y not in seen and len(y.link_faces) == 1:
                        stack.append(y)
        loops.append(comp)
    return loops


def _cut_piece(ob, dz, keep_above, near=None):
    """Bisects `ob` at the seam plane (+dz) and deletes the side not kept (only faces for
    which near(C) holds, when given). Returns the number of boundary loops left."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    p, n = _cut(dz)
    faces = bm.faces[:]
    if near is not None:
        C = np.array([f.calc_center_median() for f in faces], float)
        faces = [f for f, k in zip(faces, near(C)) if k]
    geom = list({v for f in faces for v in f.verts}) + list({e for f in faces for e in f.edges}) + faces
    bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=tuple(p), plane_no=tuple(n))
    bm.faces.ensure_lookup_table()
    C = np.array([f.calc_center_median() for f in bm.faces], float)
    side = (C - p) @ n > 0
    drop = ~side if keep_above else side
    if near is not None:
        drop &= near(C)
    bmesh.ops.delete(bm, geom=[f for f, k in zip(bm.faces, drop) if k], context="FACES")
    # loose islands (a sliver past the cut) go too
    bm.verts.ensure_lookup_table()
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    loops = _boundary_loops(bm)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return len(loops)


def build_skin(ctx, node, F, M):
    """The Body mesh: coarse body + fine head, stitched below the jaw, remeshed at the seam."""
    K = ctx.K
    body = sdf_object("Body", node, 0.003, 14000, M["skin"], sizing=body_sizing(K, max_edge=0.020))
    head = sdf_object("Head", Inter(node, _head_box()), 0.0010, 12000, M["skin"], sizing=FC.head_sizing(K, F),
                      iters=12, symmetric=True)

    def neckish(C):
        # everything of the head and neck above the seam; the shoulder tops (|x| > 0.075 below
        # the ears) are left alone
        return ~((np.abs(C[:, 0]) > 0.075) & (C[:, 2] < 1.40)) & (C[:, 2] > 1.28)
    nb = _cut_piece(body, -CUT_GAP, keep_above=False, near=neckish)
    nh = _cut_piece(head, +CUT_GAP, keep_above=True)
    log("  seam: body %d boundary loop(s), head %d" % (nb, nh))
    if nb != 1 or nh != 1:
        raise SystemExit("neck seam: expected one boundary loop per piece (body %d, head %d)" % (nb, nh))
    # join and bridge
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    head.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    ob = body
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    edges = [e for e in bm.edges if len(e.link_faces) == 1]
    bmesh.ops.bridge_loops(bm, edges=edges)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    bs = body_sizing(K, max_edge=0.020)
    hs = FC.head_sizing(K, F)

    def sizing(P):
        t = smoothstep(-0.006, 0.010, ((np.asarray(P) - _cut(0)[0]) @ _cut(0)[1]))
        return bs(P) * (1 - t) + hs(P) * t
    isotropic_remesh(ob, node, sizing, iters=4)
    V = mesh_arrays(ob)
    hv = V[:, 2] > 1.36
    off = np.abs(peval(node, V[hv]))
    log("  head vertices off the surface: max %.4f m, %d over 1 mm" % (float(off.max()), int((off > 0.001).sum())))
    if (off > 0.002).sum() > 5:
        raise SystemExit("head mesh does not lie on the head SDF (%d vertices over 2 mm)" % int((off > 0.002).sum()))
    nm = check_manifold(ob)
    log("  body + head: %d tris, non-manifold edges %d" % (tri_count(ob), nm))
    if nm:
        raise SystemExit("body mesh not manifold after the seam (%d edges)" % nm)
    return ob


def _sdf_ao(node, V, N, steps=4, delta=0.0012):
    """Cavity occlusion from the SDF (the classic distance-sampling estimate), over the
    first 5 mm only: creases, nostrils, the mouth seam, lid pockets and ears, not the broad
    hollows of the face (the renderer's own SSAO handles those)."""
    occ = np.zeros(len(V))
    w = 1.0
    for i in range(1, steps + 1):
        h = delta * i
        d = peval(node, V + N * h)
        occ += w * np.clip(h - d, 0.0, None) / h
        w *= 0.55
    return np.clip(1.0 - 0.75 * occ, 0.0, 1.0)


def _body_colors(V, N, K, F, head_node, vlab):
    """COLOR_0 of the skin: r = blood / flush, g = mucosa, b = cavity occlusion, a = beard."""
    hb = K["headb"]
    X, Y, Z = V[:, 0], V[:, 1], V[:, 2]
    flush = np.zeros(len(V))
    for s in (1, -1):
        c = v3(s * 0.040, -0.104, 1.452)
        flush = np.maximum(flush, 0.85 * np.exp(-np.sum(((V - c) / v3(1.2, 1, 1)) ** 2, 1) / (2 * 0.014 ** 2)))
        ear = v3(s * 0.073, hb[1] + 0.004, hb[2] + 0.016)
        flush = np.maximum(flush, 0.75 * np.exp(-np.sum((V - ear) ** 2, 1) / (2 * 0.016 ** 2)))
        for j, amt, r in (("knee", 0.35, 0.05), ("elbow", 0.3, 0.035)):
            p = K.side(j, s) + (v3(0, -0.04, 0) if j == "knee" else v3(0, 0.03, 0))
            flush = np.maximum(flush, amt * np.exp(-np.sum((V - p) ** 2, 1) / (2 * r ** 2)))
        kn = np.mean([K.side(n, s) for n in ("indexb", "middleb", "ringb")], 0)
        flush = np.maximum(flush, 0.35 * np.exp(-np.sum((V - kn) ** 2, 1) / (2 * 0.03 ** 2)))
        ec = FC.eye_center(K, s)
        # lids a little redder
        flush = np.maximum(flush, 0.45 * np.exp(-np.sum((V - ec) ** 2, 1) / (2 * 0.013 ** 2)))
    tip = v3(0, -0.132, 1.451)
    flush = np.maximum(flush, 0.7 * np.exp(-np.sum((V - tip) ** 2, 1) / (2 * 0.011 ** 2)))
    head = np.isin(vlab, ["head", "neck"]) & (Z > 1.30)
    muc = np.zeros(len(V))
    ao = np.ones(len(V))
    if head.any():
        Vh = V[head]
        lips = peval(FC.lips_node(K, F), Vh)
        m = smoothstep(0.0010, 0.0002, lips)
        for s in (1, -1):
            c = FC.eye_center(K, s)
            r = np.linalg.norm(Vh - c, axis=1)
            m = np.maximum(m, smoothstep(FC.EYE_R + FC.LID_GAP + 0.0009, FC.EYE_R + FC.LID_GAP + 0.0002, r))
        muc[head] = m
        ao[head] = _sdf_ao(head_node, Vh, N[head])
    # beard: jaw, chin, upper lip and under the jaw; not on the lips or high cheeks
    sto = FC.mouth_landmarks(K, F)["stomion"]
    front = smoothstep(hb[1] + 0.015, hb[1] - 0.030, Y)
    below_cheek = smoothstep(1.452, 1.436, Z)
    above_neck = smoothstep(1.335, 1.365, Z)
    not_lips = 1.0 - muc
    not_lips *= smoothstep(0.0100, 0.0140, np.sqrt(((X - sto[0]) / 1.4) ** 2 + (Z - sto[2]) ** 2)) * 0.6 + 0.4
    not_nose = np.clip(smoothstep(1.444, 1.438, Z) + (np.abs(X) > 0.026), 0, 1)
    beard = front * below_cheek * above_neck * not_lips * not_nose
    return np.stack([flush, muc, ao, beard], 1)


def _set_colors(ob, rgba):
    me = ob.data
    attr = me.color_attributes.get("Color") or me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.asarray(rgba, np.float32).ravel())
    me.color_attributes.active_color = attr


def _vertex_normals(V, Fc):
    N = np.zeros_like(V)
    fn = np.cross(V[Fc[:, 1]] - V[Fc[:, 0]], V[Fc[:, 2]] - V[Fc[:, 0]])
    for k in range(3):
        np.add.at(N, Fc[:, k], fn)
    return N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)


# ---------------------------------------------------------------------------
# Face mesh: eyes, brows, lashes
# ---------------------------------------------------------------------------
EYE_RINGS = [0, 4, 8, 12, 16, 20, 24, 27, 29.5, 32, 37, 45, 58, 75, 95, 120, 150, 180]
EYE_SEGS = 24


def _eyeball(c):
    """Sclera sphere with the corneal bulge (vertices pushed out onto the cornea)."""
    V, Fq = [], []
    V.append(c + v3(0, -1, 0) * 0.0)
    rows = []
    fwd = v3(0, -1, 0)
    for a in EYE_RINGS[1:-1]:
        th = math.radians(a)
        row = []
        for j in range(EYE_SEGS):
            ph = 2 * math.pi * j / EYE_SEGS
            d = v3(math.sin(th) * math.cos(ph), -math.cos(th), math.sin(th) * math.sin(ph))
            row.append(len(V))
            V.append(d)
        rows.append(row)
    V.append(v3(0, 1, 0))
    D = np.array(V[1:], float)
    D = np.vstack([fwd[None], D])
    # radius along each direction: max(sclera, cornea)
    Dc = FC.CORNEA_D
    cos = D @ fwd
    t = Dc * cos + np.sqrt(np.maximum(FC.CORNEA_R ** 2 - Dc * Dc * (1 - cos * cos), 0.0))
    r = np.maximum(FC.EYE_R, np.where(cos > 0.5, t, 0.0))
    P = c + D * r[:, None]
    n = len(P)
    tip, bot = 0, n - 1
    for j in range(EYE_SEGS):
        Fq.append((tip, rows[0][(j + 1) % EYE_SEGS], rows[0][j]))
    for i in range(len(rows) - 1):
        for j in range(EYE_SEGS):
            a, b = rows[i][j], rows[i][(j + 1) % EYE_SEGS]
            cc, d = rows[i + 1][(j + 1) % EYE_SEGS], rows[i + 1][j]
            Fq.append((a, b, cc, d))
    for j in range(EYE_SEGS):
        Fq.append((bot, rows[-1][j], rows[-1][(j + 1) % EYE_SEGS]))
    # every face wound outward (the eye shader culls back faces)
    out = []
    for f in Fq:
        q = P[list(f)]
        n = np.cross(q[1] - q[0], q[2] - q[0])
        out.append(f if n @ (q.mean(0) - c) > 0 else tuple(reversed(f)))
    return P, out


def _grid_faces(nu, nv, base):
    Fq = []
    for i in range(nu - 1):
        for j in range(nv - 1):
            a = base + i * nv + j
            Fq.append((a, a + nv, a + nv + 1, a + 1))
    return Fq


def _ray_front(bvh, x, z, y0=-0.25):
    hit = bvh.ray_cast(Vector((x, y0, z)), Vector((0, 1, 0)), 0.5)
    return None if hit[0] is None else (np.array(hit[0]), np.array(hit[1]))


def _brows(K, bvh, F):
    """Brow cards (u along the brow from the inner end, v across it), 0.35 mm off the skin."""
    V, UVs = [], []
    Fq = []
    nu, nv = 15, 5
    for s in (1, -1):
        base = len(V)
        for i in range(nu):
            u = i / (nu - 1)
            x = 0.0135 + 0.0370 * u
            zc = 1.5015 + 0.0045 * math.sin(math.pi * min(u / 0.72, 1.0) * 0.5) - 0.0070 * smoothstep(0.70, 1.0, u)
            hgt = 0.0120 - 0.0050 * u
            for j in range(nv):
                v = j / (nv - 1)
                z = zc + (v - 0.5) * hgt
                hit = _ray_front(bvh, s * x, z)
                if hit is None:
                    raise SystemExit("brow card: no skin at (%.3f, %.3f)" % (s * x, z))
                p, nrm_ = hit
                V.append(p + nrm_ * 0.00035)
                UVs.append((u, v))
        Fq += _grid_faces(nu, nv, base) if s > 0 else [tuple(reversed(f)) for f in _grid_faces(nu, nv, base)]
    return np.array(V), Fq, np.array(UVs)


def _lashes(K, F):
    """Lash cards along the lid margins: (V, quads, UV, root point per vertex, lower-lid flag per
    vertex)."""
    V, Fq, UVs, R, LO = [], [], [], [], []
    for s in (1, -1):
        c = FC.eye_center(K, s)
        for which, length, n_col, lift in (("up", 0.0085, 16, 1.0), ("lo", 0.0042, 12, -1.0)):
            P, t = FC.margin_points(K, s, F, which, n=n_col, grow=-0.0004)
            base = len(V)
            for i, (p, tt) in enumerate(zip(P, t)):
                radial = nrm(p - c)
                up = v3(0, 0, 1) * lift
                taper = 0.55 + 0.45 * math.sin(math.pi * (tt + 1) / 2) ** 0.6
                L = length * taper * (1.0 if tt > -0.6 else 0.75)
                pts = [p, p + nrm(radial * 0.9 + up * 0.35) * L * 0.5, p + nrm(radial * 0.45 + up * 0.9) * L]
                for j, q in enumerate(pts):
                    V.append(q)
                    UVs.append(((tt + 1) * 0.5, j / 2.0))
                    R.append(p)
                    LO.append(which == "lo")
            fq = _grid_faces(n_col, 3, base)
            Fq += fq if s > 0 else [tuple(reversed(f)) for f in fq]
    return np.array(V), Fq, np.array(UVs), np.array(R), np.array(LO)


def build_face(K, F, Vs, Fb, M):
    """Face mesh: eyes (surface 'eye'), brows and lashes (surface 'face_hair'). Returns
    (object, zone per polygon, kind per vertex: 0 eye, 1 brow, 2 lash, lash roots, lower-lash flag
    per vertex)."""
    bvh = BVHTree.FromPolygons([tuple(v) for v in Vs], [tuple(t) for t in Fb], all_triangles=True)
    parts_V, parts_F, zones, kinds, uvs = [], [], [], [], []
    for s in (1, -1):
        P, Fq = _eyeball(FC.eye_center(K, s))
        off = sum(len(v) for v in parts_V)
        parts_V.append(P)
        parts_F += [tuple(i + off for i in f) for f in Fq]
        zones += [(0, 0)] * len(Fq)
        kinds += [0] * len(P)
        c = FC.eye_center(K, s)
        uvs.append(np.stack([P[:, 0] - c[0], P[:, 2] - c[2]], 1))
    Vb, Fbq, UVb = _brows(K, bvh, F)
    off = sum(len(v) for v in parts_V)
    parts_V.append(Vb)
    parts_F += [tuple(i + off for i in f) for f in Fbq]
    zones += [(1, 0)] * len(Fbq)
    kinds += [1] * len(Vb)
    uvs.append(UVb)
    Vl, Flq, UVl, roots, lower = _lashes(K, F)
    off = sum(len(v) for v in parts_V)
    parts_V.append(Vl)
    parts_F += [tuple(i + off for i in f) for f in Flq]
    zones += [(1, 1)] * len(Flq)
    kinds += [2] * len(Vl)
    uvs.append(UVl)
    V = np.vstack(parts_V)
    ob = mesh_object("Face", V, parts_F, M["eye"])
    ob.data.materials.append(M["face_hair"])
    for p, (slot, z) in zip(ob.data.polygons, zones):
        p.material_index = slot
        p.use_smooth = True
    UV.ensure_layers(ob, ("UVMap", "Region"))
    lv, lp = UV.loop_topology(ob)
    UV.write(ob, "UVMap", np.vstack(uvs)[lv])
    RG.write_region_uv(ob, np.array([RG.encode("head", z) for _, z in zones]), "Region")
    Rr = np.zeros_like(V)
    Rr[np.array(kinds) == 2] = roots
    Lo = np.zeros(len(V), bool)
    Lo[np.array(kinds) == 2] = lower
    return ob, np.array([z for _, z in zones]), np.array(kinds), Rr, Lo


# ---------------------------------------------------------------------------
# Shapes
# ---------------------------------------------------------------------------
WARP_KEYS = ("fissure_up", "fissure_lo", "canthus_med", "canthal_tilt", "epicanthus")


def _split_delta(dF):
    warp = {k: v for k, v in dF.items() if k in WARP_KEYS}
    proj = {k: v for k, v in dF.items() if k not in WARP_KEYS}
    return proj, warp


def build(ctx, previews=None, export=True):
    t0 = time.time()
    K = ctx.K
    M = _mats()
    Pf, Pm = ctx.P_female, ctx.P_male
    Ff = Pf.face
    groups = body_groups(K, Pf)
    node = body_node(groups)

    # ---- geometry: coarse body + fine head, clean region borders
    ob = build_skin(ctx, node, Ff, M)
    RG.cut_borders(ob, K, groups)
    for p in ob.data.polygons:
        p.use_smooth = True
    preg, plab = RG.face_regions(ob, K, groups)
    V0 = mesh_arrays(ob)
    Fc = np.array([tuple(p.vertices) for p in ob.data.polygons], int)
    assert Fc.shape[1] == 3
    E = mesh_adjacency(ob)
    log("body: %d tris %d verts, %d regions" % (len(Fc), len(V0), len(set(preg))))

    # ---- weights (female base; the shapes keep them)
    Wb, lab, labels = body_weights(ob, K, groups, ctx.bones)
    vlab = np.array(labels, dtype=object)[lab]
    trunk = np.isin(vlab, ["torso", "neck"]) | (np.char.startswith(vlab.astype(str), "leg") & (V0[:, 2] > 0.60))
    trunk &= ~((vlab == "neck") & (V0[:, 2] > 1.40))
    n_smooth = int(os.environ.get("BODY_SMOOTH", TRUNK_SMOOTH))
    if n_smooth:
        Wb = limit_normalize(smooth_weights(Wb, E, n_smooth, 0.5, lock=~trunk))
    # the v2 head meshes the neck below the jaw 2-3x finer than the body, so the passes above
    # blend headb into the neck over a shorter distance than on the v1 body: the nape
    # stretched in head pitches and the hair caps, which copy these weights, frayed there.
    # More passes over the neck and jaw line (the face and skull stay rigid, as in
    # body_weights) give back the v1 blend of about 4 cm at the nape.
    hb = K["headb"]
    rigid = (vlab == "head") & ((V0[:, 2] > 1.415) | (V0[:, 1] < hb[1] - 0.05))
    nape = np.isin(vlab, ["head", "neck"]) & (V0[:, 2] > 1.36) & ~rigid
    Wb = limit_normalize(smooth_weights(Wb, E, NAPE_SMOOTH, 0.5, lock=~nape))
    W = limit_normalize(helper_weights(V0, Wb, ctx.bones, K))

    # ---- soft tissue: smooth the head's broad skin (a linear operator S; shapes use it too)
    headish = np.isin(vlab, ["head", "neck"]) & (V0[:, 2] > 1.30)
    sw = FC.smooth_weights(V0, K, Ff) * headish * smoothstep(1.35, 1.38, V0[:, 2])
    n_hs = int(os.environ.get("HEAD_SMOOTH", HEAD_SMOOTH))

    def S(D):
        return FC.taubin(D, E, sw, n_hs) if n_hs else D
    Vs = S(V0)
    ob.data.vertices.foreach_set("co", Vs.astype(np.float32).ravel())
    ob.data.update()
    log("head smoothed (%d iters): max move %.4f" % (n_hs, float(np.linalg.norm(Vs - V0, axis=1).max())))

    # ---- shape keys
    t1 = time.time()
    lidm = FC.lid_mask(V0, K, Ff)
    head_fade = np.where(vlab == "head", 1.0, smoothstep(1.345, 1.372, V0[:, 2])) * headish

    def head_shape(Ptarget, dF_warp, sel=headish):
        node_t = body_node(body_groups(K, Ptarget))
        d = project_shape(V0, node_t, E, sel=sel, step=0.006, iters=8, smooth=2)
        d = S(d * lidm[:, None])
        if dF_warp:
            d = d + FC.eye_warp(Vs, K, Ff, dF_warp)
        return d
    deltas = {}
    male = body_node(body_groups(K, Pm))
    dsex = project_shape(V0, male, E, step=0.01, iters=10, smooth=3)
    dsex[headish] *= lidm[headish, None]
    _, mwarp = _split_delta(FC.FACE_MALE)
    dsex = S(dsex) + FC.eye_warp(Vs, K, Ff, mwarp)
    deltas["sex"] = dsex
    deltas["sex_head"] = dsex * head_fade[:, None]
    deltas["blink"] = FC.eye_warp(Vs, K, Ff, {}, blink=1.0)
    for f, dF in FC.FACE_FEATURES.items():
        if f == "prognathism":
            # a warp, not a projection (face.prognathism_warp: the projection folded the lips)
            deltas["face_" + f] = FC.prognathism_warp(Vs, K, Ff, FC.PROG_LIP_MOVE)
            continue
        proj, warp = _split_delta(dF)
        deltas["face_" + f] = head_shape(face_params(Pf, f), warp)
    for f, dF in FC.FACE_WARPS.items():
        deltas["face_" + f] = FC.eye_warp(Vs, K, Ff, dF)
    for f, dw in FC.MOUTH_WARP.items():
        deltas["face_" + f] = FC.mouth_warp(Vs, K, Ff, dw)
    # the stylized head (lib/stylize.py: the creator's default Face style): one fixed delta on top
    # of the features, and the blink's corrective for its larger eyes (blink_style = blink x style,
    # driven by FaceBlink): the lids of the scaled eye close over the scaled eyeball
    deltas["style"] = ST.style_delta(Vs, Fc, E, K, vlab, P=Pf)
    deltas["style_male"] = ST.style_male_delta(Vs, Fc, E, K, vlab, Pm, dsex, deltas["style"])
    deltas["blink_style"] = ST.blink_corrective(deltas["blink"], Vs, K)
    # folds: the projected shapes (and the male fit) can put vertices by the mouth seam, the
    # alar groove and the nostrils on the wrong surface; relax them locally over the face
    # front (not the lids, whose warps rotate the lid skin on purpose; not the hairline, so
    # the hair's wrap-transferred shapes still match)
    front = (np.abs(Vs[:, 0]) < 0.045) & (Vs[:, 1] < -0.07) & (Vs[:, 2] > 1.37) & (Vs[:, 2] < 1.462)
    warps = {"blink", "face_prognathism", "blink_style"} | {"face_" + f for f in list(FC.FACE_WARPS) + list(FC.MOUTH_WARP)}
    left = {}
    for n in deltas:
        if n not in warps:
            deltas[n], left[n] = relax_folds(Vs, Fc, deltas[n], E, front)
    log("shapes %s (%.1fs), folds left on the face front %s" % (shape_stats(deltas), time.time() - t1,
                                                               {n: k for n, k in left.items() if k}))

    # ---- attributes: UVMap (metres), Region, COLOR_0
    UV.ensure_layers(ob, ("UVMap", "Region"))
    parts, part = UV.body_parts(K, plab, preg)
    UV.write(ob, "UVMap", UV.segment_uvs(ob, parts, part))
    codes = np.array([RG.encode(r) for r in preg])
    RG.write_region_uv(ob, codes, "Region")
    Nv = _vertex_normals(Vs, Fc)
    # masks at the smoothed positions, the cavity occlusion from the SDF at the unsmoothed ones
    # (a smoothed point can sit a few mm inside the SDF and would read as occluded)
    cols = _body_colors(Vs, Nv, K, Ff, node, vlab)
    head = np.isin(vlab, ["head", "neck"]) & (V0[:, 2] > 1.30)
    cols[head, 2] = _sdf_ao(node, V0[head], _vertex_normals(V0, Fc)[head])
    _set_colors(ob, cols)
    # stylized paint (lib/paint.py): the head's painted maps in the head UV space, and the painted
    # value of the rest of the skin per vertex in the Region UV's v (Godot UV2.y = 1 - value)
    Vsty = Vs + deltas["style"]
    head_tris = np.array([r in ("head", "neck_upper") for r in preg])
    paint_head, paint_lines = PT.bake_maps(Vs, Vsty, Fc, K, cols[:, 1], head_tris)
    bval = PT.body_paint(Vsty, Fc, E)
    lv, _lp = UV.loop_topology(ob)
    RG.write_region_uv(ob, codes, "Region", bval[lv])
    PT.save_source(Vs, Vsty, Fc, cols[:, 1], head_tris, K)

    # ---- Face mesh (eyes, brows, lashes)
    face, fzone, fkind, froots, flower = build_face(K, Ff, Vs, Fc, M)
    Vf = mesh_arrays(face)
    head_tris = np.isin(np.array([vlab[Fc[i, 0]] for i in range(len(Fc))]), ["head"])
    surf = Surface(Vs, Fc, shapes=deltas, allowed=head_tris)
    brow = fkind == 1
    lash = fkind == 2
    fdeltas = {}
    bind = surf.bind(Vf[brow])
    for n in deltas:
        d = np.zeros_like(Vf)
        d[brow] = surf.shape_delta(bind, n)
        fdeltas[n] = d
    # lashes: the delta of their root on the margin (warps and blink move the margins)
    lash_keys = {"blink": ({}, 1.0), "sex": (mwarp, 0.0), "sex_head": (mwarp, 0.0)}
    for f, dF in list(FC.FACE_FEATURES.items()) + list(FC.FACE_WARPS.items()):
        lash_keys["face_" + f] = (_split_delta(dF)[1] if f in FC.FACE_FEATURES else dF, 0.0)
    for n, (dF, bl) in lash_keys.items():
        if dF or bl:
            fdeltas[n][lash] = FC.eye_warp(froots[lash], K, Ff, dF, blink=bl)
    # stylized: the eyeballs and lashes scale with the eye region (the brows took the skin's
    # `style` by the wrap transfer above); the lashes' blink corrective as the lids'
    eyes_lashes = ~brow
    fdeltas["style"][eyes_lashes] = ST.eye_scale_delta(Vf[eyes_lashes], K)
    fdeltas["blink_style"][lash] = ST.blink_corrective(fdeltas["blink"][lash], Vf[lash], K)
    # COLOR_0: g = 0 on the lower lashes (face_hair.gdshader's stylized lashes paint the upper ones)
    fcol = np.concatenate([np.ones((len(Vf), 3)), np.zeros((len(Vf), 1))], 1)
    fcol[flower, 1] = 0.0
    _set_colors(face, fcol)
    Wf = np.zeros((len(Vf), len(ctx.bones)))
    Wf[:, ctx.bones.index("headb")] = 1.0

    add_shape_keys(ob, deltas)
    add_shape_keys(face, fdeltas)

    # ---- skin, export
    rig = ctx.bind_rig()
    stats = {}
    used_all = set()
    for o, Wo in ((ob, W), (face, Wf)):
        used = write_groups(o, Wo, ctx.bones)
        used_all.update(used)
        o.parent = rig
        mod = o.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
        stats[o.name] = {"tris": tri_count(o), "verts": len(o.data.vertices), "materials": [m.name for m in o.data.materials],
                         "bones": used, "max_influences": int((Wo > 0).sum(1).max())}
    head_polys = np.array([r == "head" for r in preg])
    stats["Body"]["head_tris"] = int(head_polys.sum())
    for b in rig.data.bones:
        b.use_deform = b.name in used_all or b.use_deform
    reg_tris = {}
    for r in preg:
        reg_tris[r] = reg_tris.get(r, 0) + 1
    from body import peoples as PEOPLES
    if export:
        export_glb(rig, [ob, face], GLB, texcoords=True, morph=True)
        PT.write_png(os.path.join(OUT_DIR, "paint_head.png"), paint_head)
        PT.write_png(os.path.join(OUT_DIR, "paint_lines.png"), paint_lines)
        info = {
            "generator": "tools/character/body/body.py (build_character.sh --body)", "lib_version": LIB_VERSION,
            "blender": bpy.app.version_string, "glb": os.path.basename(GLB),
            "bind_clip": "actor_b/null-add",
            "bind_note": ("Armature rest in the glb == null-add pose evaluated on the Actor_B rig (unkeyed channels at rig "
                          "rest); glTF inverse binds are inverse(null-add global)."),
            "space": "Godot skeleton space: +Y up, character faces +Z (Blender (x, y, z) -> (x, z, -y)).",
            "objects": stats, "total_tris": sum(s["tris"] for s in stats.values() if isinstance(s, dict) and "tris" in s),
            "regions": RG.regions_json(), "region_tris": {r: reg_tris[r] for r in RG.REGION_LIST if r in reg_tris},
            "shapes": {"names": list(deltas), "max_delta_m": shape_stats(deltas),
                       "sex": "0 = female base, 1 = male fit (mesh only; the skeleton is unchanged)",
                       "sex_head": "the head part of `sex` only (for outfits built on the female body)",
                       "blink": "both eyes closed (lid warp); driven at runtime",
                       "style": ("the stylized head (lib/stylize.py): one fixed delta for every face, on top of "
                                 "the features; 1 in the Stylized face style"),
                       "style_male": ("the male fit's stylized head on top of `style` (a broad square jaw, a strong "
                                      "chin and brow): the look's sex weight x style"),
                       "blink_style": "blink corrective of the stylized eyes: FaceBlink drives it at blink x style",
                       "stature": {"female": 1.00, "male": 1.07, "min": 0.95, "max": 1.10,
                                   "note": "uniform scale of the Actor_B instance at runtime (design 3.3)"}},
            # legacy preset names of the v1 head (older tools and previews), now peoples presets
            "face_presets": {k: PEOPLES.preset_face(v) for k, v in PEOPLES.LEGACY_PRESETS.items()},
            "face": {"model": "lib/face.py head v2", "features": PEOPLES.feature_table(),
                     "params_female": Ff, "params_male": Pm.face},
            "skin": {"tones": SKIN_TONES, "undertones": UNDERTONES, "labels": ["Tone %d" % (i + 1) for i in range(12)],
                     "note": ("melanin 0..1 maps linearly onto the 12 anchors (linear light); undertone = Oklab a/b "
                              "offset; haemoglobin 0..1 (0.5 average) = blood seen through the epidermis")},
            "eyes": EYE_IRIS,
            "paint": {"maps": ["paint_head.png", "paint_lines.png"], "u": [PT.U0, PT.U1], "h": [PT.H0, PT.H1],
                      "note": ("stylized skin (lib/paint.py): head maps in the head UV space (R value, G warm, B "
                               "cool, A highlight; lines R dark, G lit edge); the body's painted value per vertex "
                               "in UV2 (Godot UV2.y = 1 - value)")},
            "surfaces": {"Body": [{"name": "skin", "shader": "skin", "zones": ["skin"]}],
                         "Face": [{"name": "eye", "shader": "eye", "zones": ["eye"]},
                                  {"name": "face_hair", "shader": "face_hair", "zones": ["brows", "lashes"]}]},
            "params": {"female": {k: v for k, v in Pf.to_dict().items() if k != "face"},
                       "male": {k: v for k, v in Pm.to_dict().items() if k != "face"}},
            "deform_bones": [b for b in ctx.order if b in used_all],
            "helpers": helpers_json(),
            "driver_reference": driver_reference(ctx.rig, ctx.base, ctx.G),
            "inverse_bind_godot": {b: xf12(np.linalg.inv(godot_xf(ctx.G[b]))) for b in ctx.order if b in used_all},
            "transform_format": "12 floats: basis x, y, z columns, then origin",
            "provenance": PROVENANCE_RIG + " Mesh geometry generated procedurally by tools/character/body/body.py "
                                           "and lib/face.py.",
        }
        with open(os.path.splitext(GLB)[0] + ".json", "w") as f:
            json.dump(info, f, indent=1)
        PEOPLES.write()
        log("exported %s (%.0f KB)" % (GLB, os.path.getsize(GLB) / 1024))
    freg = np.array([RG.REGIONS[r] for r in preg])
    body = BodyData(Vs, Fc, W, ctx.bones, vlab, freg, deltas)
    body.save()
    ctx.set_body(body)
    log("body built in %.1fs: %s" % (time.time() - t0, {k: v["tris"] for k, v in stats.items()}))
    if previews:
        _previews(ctx, ob, face, preg, previews)
    return {"Body": ob, "Face": face}


# ---------------------------------------------------------------------------
# Blender previews (sanity; the reference renders are Godot's, body_preview.gd)
# ---------------------------------------------------------------------------
def _previews(ctx, ob, face, preg, outdir):
    from lib.preview import contact_sheet, posed_previews, render_view, setup_preview_scene
    import colorsys
    os.makedirs(outdir, exist_ok=True)
    ctx.rig.hide_render = True
    ctx.bind_rig().hide_render = True
    co = setup_preview_scene()
    shots = []
    for sex in (0.0, 1.0):
        for o in (ob, face):
            o.data.shape_keys.key_blocks["sex"].value = sex
        tag = "m" if sex else "f"
        for v in ("front", "side", "back", "front34"):
            shots.append(render_view(co, os.path.join(outdir, "body_%s_%s.png" % (tag, v)), v, center=(0, 0, 0.82), scale=1.8,
                                     res=(520, 900)))
    contact_sheet(shots, os.path.join(outdir, "body_sheet.png"), 8)
    # faces: a few peoples presets
    from body import peoples as PEOPLES
    fshots = []
    for pr in PEOPLES.build()["presets"][::11]:
        for o in (ob, face):
            kb = o.data.shape_keys.key_blocks
            for k in kb[1:]:
                k.value = 0.0
            kb["sex"].value = pr["sex"]
            for k, w in pr["face"].items():
                if k in kb:
                    kb[k].slider_min = -1.0
                    kb[k].value = w
        fshots.append(render_view(co, os.path.join(outdir, "face_%s.png" % pr["id"]), "front34",
                                  center=(0, -0.03, 1.46), scale=0.30, res=(420, 420)))
        fshots.append(render_view(co, os.path.join(outdir, "face_%s_side.png" % pr["id"]), "side",
                                  center=(0, -0.03, 1.46), scale=0.30, res=(420, 420)))
    contact_sheet(fshots, os.path.join(outdir, "face_sheet.png"), 4)
    for o in (ob, face):
        for k in o.data.shape_keys.key_blocks[1:]:
            k.value = 0.0
    # regions: a coloured copy
    cp = ob.copy()
    cp.data = ob.data.copy()
    bpy.context.scene.collection.objects.link(cp)
    ob.hide_render = True
    face.hide_render = True
    me = cp.data
    while len(me.materials):
        me.materials.pop()
    names = RG.REGION_LIST
    for i, n in enumerate(names):
        r, g, b = colorsys.hsv_to_rgb((i * 0.618034) % 1.0, 0.6, 0.95)
        me.materials.append(material("R_" + n, "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255)), 0.8))
    for p, n in zip(me.polygons, preg):
        p.material_index = names.index(n)
    rshots = [render_view(co, os.path.join(outdir, "regions_%s.png" % v), v, center=(0, 0, 0.82), scale=1.8, res=(520, 900))
              for v in ("front", "side", "back", "front34")]
    contact_sheet(rshots, os.path.join(outdir, "regions_sheet.png"), 4)
    bpy.data.objects.remove(cp)
    ob.hide_render = False
    face.hide_render = False
    ps = posed_previews(ctx.rig, ctx.bind_rig(), ctx.base, outdir, co, ctx.G, prefix="pose_f")
    for o in (ob, face):
        o.data.shape_keys.key_blocks["sex"].value = 1.0
    ps += posed_previews(ctx.rig, ctx.bind_rig(), ctx.base, outdir, co, ctx.G, prefix="pose_m")
    for o in (ob, face):
        o.data.shape_keys.key_blocks["sex"].value = 0.0
    contact_sheet(ps, os.path.join(outdir, "pose_sheet.png"), 6)
