"""Full-skin player body with the v3 head (2026-09-27): assets/character/body/body.glb (+ body.json).

Built by tools/character/build_character.sh --body. As body.py (the v2 build: the SDF body, its
regions, weights, helpers, UVs and export), except the head: the MakeHuman head of body/mh.py
replaces the v2 anatomical head above the neck seam, bridged to the SDF body there.

  Body   surface "skin". Shape keys: `sex` (the SDF body's male projection below the seam, the
         MakeHuman male fit above it, the two joined over the 2 cm above the seam), `sex_head`,
         `blink` and the 30 face features `face_*` (MakeHuman targets, body/mh.py). No stylized
         shapes: the creator is realistic only (the user, 2026-09-27).
  Face   the eyes (at MakeHuman's eye centres, sized to its lids; the shapes move them as they move
         its eye helpers), the brows (ray-cast onto the head, wrap-transferred shapes) and the
         lashes (along MakeHuman's lid rows; each follows its root, and turns with it in the blink).
"""

import json
import os
import time

import bmesh
import bpy
import numpy as np
from mathutils.bvhtree import BVHTree

from body import body as B
from body import mh as MH
from lib import LIB_VERSION
from lib import regions as RG
from lib import uv as UV
from lib.body_shapes import body_groups, body_node, body_sizing
from lib.context import BodyData
from lib.helpers import driver_reference, helpers_json
from lib.remesh import check_manifold, mesh_arrays, mesh_object, sdf_object, tri_count
from lib.rig import PROVENANCE_RIG, export_glb, godot_xf, xf12
from lib.sdf import log, smoothstep
from lib.shapes import add_shape_keys, project_shape, shape_stats
from lib.weights import body_weights, helper_weights, limit_normalize, mesh_adjacency, smooth_weights, write_groups
from lib.wrap import Surface

GLB = B.GLB
OUT_DIR = B.OUT_DIR
BLEND = 0.05              # the head's cut ring pulled onto the body's, blended over this height (m)
SEX_SEAM = 0.02           # the head's sex shape joins the body's over this height above the seam


def _angle(P, c):
    return np.arctan2(P[:, 0] - c[0], -(P[:, 1] - c[1]))


def _interp_ring(a_src, vals, a):
    """Values of a closed ring (angle about the neck) at angles a."""
    o = np.argsort(a_src)
    a_s, v_s = a_src[o], vals[o]
    ae = np.concatenate([a_s - 2 * np.pi, a_s, a_s + 2 * np.pi])
    ve = np.vstack([v_s, v_s, v_s])
    return np.stack([np.interp(a, ae, ve[:, j]) for j in range(vals.shape[1])], 1)


def _loop_verts(ob):
    """Vertex indices on boundary edges."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    idx = sorted({v.index for e in bm.edges if len(e.link_faces) == 1 for v in e.verts})
    bm.free()
    return np.array(idx, int)


# The v2 head's landmarks in face coordinates (face_detail.gdshaderinc: u = arc length about the
# head's axis at 0.08 m, h = height): the facial hair regions, marks and paint were drawn on them.
# h: menton, lower lip border, stomion, upper lip border, subnasale, eye centre, brow, forehead;
# |u|: mouth corner, cheek centre, ear front, far side.
FACE_H_V2 = [1.3733, 1.4113, 1.42045, 1.4296, 1.442, 1.4838, 1.5238, 1.5838]
FACE_U_V2 = [0.0206, 0.032, 0.105, 0.25]


def _detail_rect():
    """The head detail map's rectangle in MakeHuman UV image space (tools/character/mh_skin_detail.py)."""
    p = os.path.join(MH.MH_DIR, "head_uv_rect.json")
    return json.load(open(p))["rect"] if os.path.exists(p) else None


def face_coords(P, K):
    """(u, h) of the head UVs (lib/uv.py body_parts "head": a cylinder about the vertical axis
    through headb, radius 0.08 m; u = 0 at the face front, + toward the character's left)."""
    hb = K["headb"]
    return np.arctan2(P[:, 0], -(P[:, 1] - hb[1])) * 0.08, P[:, 2]


def face_landmarks(V, muc, piece, K):
    """The v3 head's landmarks: face-coordinate knots matching FACE_H_V2 / FACE_U_V2 (the warp
    the shaders and FaceExtras put the v2 regions on the new face with), and the jewellery places
    (Godot space: ear lobes and rims, septum, left nostril)."""
    u, h = face_coords(V, K)
    X, Y, Z = V[:, 0], V[:, 1], V[:, 2]
    mid = np.abs(X) < 0.003
    front = Y < -0.06
    menton = float(Z[mid & front].min())
    lips = (np.abs(X) < 0.008) & (muc > 0.5) & (Y < -0.09)
    if not lips.any():
        raise SystemExit("face landmarks: no lip vermilion near the midline")
    lip_lo, lip_hi = float(Z[lips].min()), float(Z[lips].max())
    tip_i = np.nonzero(mid)[0][np.argmin(Y[mid])]
    tip = V[tip_i]
    col = mid & (Z > lip_hi) & (Z < tip[2]) & front
    sub = V[np.nonzero(col)[0][np.argmax(Y[col])]]
    eye = float(piece["eyes"][1][2])
    kh = [menton, lip_lo, (lip_lo + lip_hi) / 2, lip_hi, float(sub[2]), eye, eye + 0.04, eye + 0.10]
    for i in range(1, len(kh)):
        kh[i] = max(kh[i], kh[i - 1] + 1e-4)
    corner = float(np.mean(np.abs(face_coords(piece["marks"]["mouth_corners"], K)[0])))
    cheek = float(np.mean([abs(face_coords(c[None], K)[0][0]) for c in piece["marks"]["cheeks"]]))
    ear_front = float(np.percentile(np.abs(face_coords(piece["marks"]["ear_pts"], K)[0]), 5))
    ku = [corner, cheek, ear_front, 0.25]
    for i in range(1, len(ku)):
        ku[i] = max(ku[i], ku[i - 1] + 1e-4)
    g = lambda p: [round(float(p[0]), 5), round(float(p[2]), 5), round(float(-p[1]), 5)]
    lm = {}
    for s, sd in ((1, "l"), (-1, "r")):
        e = piece["marks"]["ears"][0 if s > 0 else 1]
        reg = (np.linalg.norm(V - e, axis=1) < 0.035) & (X * s > 0.055)
        lobe = V[np.nonzero(reg)[0][np.argmin(Z[reg])]]
        lm["ear_" + sd] = g(lobe)
        for k in (1, 2):
            band = reg & (np.abs(Z - (lobe[2] + 0.009 * k)) < 0.0025)
            if band.any():
                sc = X[band] * s - 0.25 * np.abs(Y[band] - lobe[1])
                lm["rim_%s%d" % (sd, k)] = g(V[np.nonzero(band)[0][np.argmax(sc)]])
    colm = mid & (Z > sub[2] + 0.0015) & (Z < sub[2] + 0.0045) & front
    lm["septum"] = g(V[np.nonzero(colm)[0][np.argmin(Y[colm])]]) if colm.any() else g(sub)
    ala = (X > 0.004) & (X < 0.03) & (Z > sub[2] + 0.001) & (Z < sub[2] + 0.008) & (Y < tip[1] + 0.03) & (Y > tip[1] + 0.004)
    lm["nostril_l"] = g(V[np.nonzero(ala)[0][np.argmax(X[ala])]]) if ala.any() else g(sub + np.array([0.015, 0.01, 0.004]))
    return {"h": [round(x, 5) for x in kh], "h_v2": FACE_H_V2, "u": [round(x, 5) for x in ku], "u_v2": FACE_U_V2}, lm


def mh_uvs(ob, is_head, piece):
    """Per loop: the MakeHuman UV (the skin textures' layout; TEXCOORD_2 -> Godot CUSTOM0) on the
    head's polygons, (-1, 2) elsewhere (Godot reads (-1, -1): no head detail). Each loop is looked
    up a little inside its polygon, so a loop on a UV seam takes its own side's UV."""
    me = ob.data
    V = mesh_arrays(ob)
    out = np.tile(np.array([-1.0, 2.0]), (len(me.loops), 1))
    surf = Surface(piece["V_fit"], piece["F"])
    pts, loops = [], []
    for p in me.polygons:
        vs = list(p.vertices)
        if not is_head[vs].all():
            continue
        c = V[vs].mean(0)
        for li, vi in zip(range(p.loop_start, p.loop_start + p.loop_total), vs):
            pts.append(V[vi] * 0.97 + c * 0.03)
            loops.append(li)
    if pts:
        tri, bary, _, _ = surf.nearest(np.array(pts))
        uv = np.einsum("ij,ijk->ik", bary, piece["F_uv"][tri])
        out[np.array(loops)] = uv
    log("  MakeHuman UVs on %d head loops" % len(loops))
    return out


def build_skin(ctx, node, M, piece):
    """The Body mesh: the SDF body below the seam + the MakeHuman head above it, bridged."""
    K = ctx.K
    body = sdf_object("Body", node, 0.003, 14000, M["skin"], sizing=body_sizing(K, max_edge=0.020))

    def neckish(C):
        return ~((np.abs(C[:, 0]) > 0.075) & (C[:, 2] < 1.40)) & (C[:, 2] > 1.28)
    nb = B._cut_piece(body, -B.CUT_GAP, keep_above=False, near=neckish)
    if nb != 1:
        raise SystemExit("neck seam: expected one boundary loop on the body, got %d" % nb)
    ring_b = mesh_arrays(body)[_loop_verts(body)]
    # the head's ring (on the seam plane + CUT_GAP) takes the body ring's outline in the plane,
    # the pull fading upward over BLEND
    V = piece["V"].copy()
    head = mesh_object("Head", V, [tuple(f) for f in piece["F"]], M["skin"])
    ring_h_idx = _loop_verts(head)
    p, n = MH.seam_plane(B.CUT_GAP)
    c = ring_b.mean(0)
    ab = _angle(ring_b, c)
    target = _interp_ring(ab, ring_b, _angle(V[ring_h_idx], c))
    target = target + n * (((p - target) @ n)[:, None])          # onto the head's plane
    d_ring = target - V[ring_h_idx]
    D = _interp_ring(_angle(V[ring_h_idx], c), d_ring, _angle(V, c))
    w = 1.0 - smoothstep(0.0, BLEND, (V - p) @ n)
    V = V + D * w[:, None]
    V[ring_h_idx] = target
    head.data.vertices.foreach_set("co", V.astype(np.float32).ravel())
    head.data.update()
    log("  seam: head ring pulled onto the body's by up to %.1f mm" % (1000 * float(np.linalg.norm(d_ring, axis=1).max())))
    piece["V_fit"] = V
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
    nm = check_manifold(ob)
    log("  body + head v3: %d tris, non-manifold edges %d" % (tri_count(ob), nm))
    if nm:
        raise SystemExit("body mesh not manifold after the seam (%d edges)" % nm)
    return ob


def build(ctx, previews=None, export=True):
    t0 = time.time()
    K = ctx.K
    M = B._mats()
    Pf, Pm = ctx.P_female, ctx.P_male
    Ff = Pf.face
    groups = body_groups(K, Pf)
    node = body_node(groups)
    node_m = body_node(body_groups(K, Pm))
    mh = MH.MakeHuman()
    piece = MH.head_piece(mh, K, node, node_m)

    # ---- geometry: the SDF body + the MakeHuman head, clean region borders
    ob = build_skin(ctx, node, M, piece)
    RG.cut_borders(ob, K, groups)
    for pp in ob.data.polygons:
        pp.use_smooth = True
    preg, plab = RG.face_regions(ob, K, groups)
    V0 = mesh_arrays(ob)
    Fc = np.array([tuple(pp.vertices) for pp in ob.data.polygons], int)
    assert Fc.shape[1] == 3
    E = mesh_adjacency(ob)
    log("body: %d tris %d verts, %d regions" % (len(Fc), len(V0), len(set(preg))))

    # ---- the head's vertices: on the fitted piece and above the seam
    surf_h = Surface(piece["V_fit"], piece["F"], shapes=piece["shapes"])
    bind = surf_h.bind(V0)
    p, n = MH.seam_plane(B.CUT_GAP)
    is_head = (bind.dist < 2e-5) & ((V0 - p) @ n > -1e-4)
    log("  head v3 vertices in the body: %d" % int(is_head.sum()))

    # ---- weights (female base; the shapes keep them), as v2
    Wb, lab, labels = body_weights(ob, K, groups, ctx.bones)
    vlab = np.array(labels, dtype=object)[lab]
    trunk = np.isin(vlab, ["torso", "neck"]) | (np.char.startswith(vlab.astype(str), "leg") & (V0[:, 2] > 0.60))
    trunk &= ~((vlab == "neck") & (V0[:, 2] > 1.40))
    Wb = limit_normalize(smooth_weights(Wb, E, B.TRUNK_SMOOTH, 0.5, lock=~trunk))
    hb = K["headb"]
    rigid = (vlab == "head") & ((V0[:, 2] > 1.415) | (V0[:, 1] < hb[1] - 0.05))
    nape = np.isin(vlab, ["head", "neck"]) & (V0[:, 2] > 1.36) & ~rigid
    Wb = limit_normalize(smooth_weights(Wb, E, B.NAPE_SMOOTH, 0.5, lock=~nape))
    W = limit_normalize(helper_weights(V0, Wb, ctx.bones, K))
    Vs = V0

    # ---- shape keys
    t1 = time.time()
    headish = np.isin(vlab, ["head", "neck"]) & (V0[:, 2] > 1.30)
    head_fade = np.where(vlab == "head", 1.0, smoothstep(1.345, 1.372, V0[:, 2])) * headish
    hb_idx = np.nonzero(is_head)[0]
    sub = type(bind)(bind.tri[hb_idx], bind.bary[hb_idx], bind.local[hb_idx], bind.dist[hb_idx])
    deltas = {}
    dsex = project_shape(V0, node_m, E, sel=~is_head, step=0.01, iters=10, smooth=3)
    dsex[is_head] = surf_h.shape_delta(sub, "sex")
    # the seam: the head's sex shape joins the body ring's over SEX_SEAM
    cross = is_head[E[:, 0]] != is_head[E[:, 1]]
    ring_b = np.unique(np.where(is_head[E[cross, 0]], E[cross, 1], E[cross, 0]))
    c = V0[ring_b].mean(0)
    near = is_head & ((V0 - p) @ n < SEX_SEAM)
    wv = 1.0 - smoothstep(0.0, SEX_SEAM, (V0[near] - p) @ n)
    ring_sex = _interp_ring(_angle(V0[ring_b], c), dsex[ring_b], _angle(V0[near], c))
    dsex[near] = dsex[near] * (1 - wv[:, None]) + ring_sex * wv[:, None]
    deltas["sex"] = dsex
    deltas["sex_head"] = dsex * head_fade[:, None]
    for nm in ["blink"] + ["face_" + f for f in MH.MAP]:
        d = np.zeros_like(V0)
        d[is_head] = surf_h.shape_delta(sub, nm)
        deltas[nm] = d
    log("shapes %s (%.1fs)" % (shape_stats(deltas), time.time() - t1))

    # ---- attributes: UVMap (metres), Region, MHUV, COLOR_0
    UV.ensure_layers(ob, ("UVMap", "Region", "MHUV"))
    parts, part = UV.body_parts(K, plab, preg)
    UV.write(ob, "UVMap", UV.segment_uvs(ob, parts, part))
    codes = np.array([RG.encode(r) for r in preg])
    RG.write_region_uv(ob, codes, "Region")
    UV.write(ob, "MHUV", mh_uvs(ob, is_head, piece))
    Nv = B._vertex_normals(Vs, Fc)
    cols = B._body_colors(Vs, Nv, K, Ff, node, vlab)
    bvh = BVHTree.FromPolygons([tuple(v) for v in Vs], [tuple(t) for t in Fc], all_triangles=True)
    cols[is_head] = MH.head_colors(Vs[is_head], Nv[is_head], piece, K, bvh)
    B._set_colors(ob, cols)
    fwarp, flm = face_landmarks(Vs[is_head], cols[is_head, 1], piece, K)
    log("face warp h %s (v2 %s), u %s (v2 %s); landmarks %s" % (fwarp["h"], FACE_H_V2, fwarp["u"], FACE_U_V2, sorted(flm)))

    # ---- Face mesh (eyes, brows, lashes)
    face, fzone, fkind, fside, lash_roots, lash_lower = build_face(K, piece, bvh, M)
    Vf = mesh_arrays(face)
    head_tris = np.isin(np.array([vlab[Fc[i, 0]] for i in range(len(Fc))]), ["head"])
    surf = Surface(Vs, Fc, shapes=deltas, allowed=head_tris)
    brow = fkind == 1
    lash = fkind == 2
    eye = fkind == 0
    fdeltas = {nm: np.zeros_like(Vf) for nm in deltas}
    bb = surf.bind(Vf[brow])
    br = surf.bind(lash_roots[lash])
    for nm in deltas:
        fdeltas[nm][brow] = surf.shape_delta(bb, nm)
        fdeltas[nm][lash] = surf.shape_delta(br, nm)
        key = "sex" if nm == "sex_head" else nm     # the head-only male fit moves the eyes as the full one
        for s in (1, -1):
            if key in piece["eye_shapes"]:
                sel = eye & (fside == s)
                fdeltas[nm][sel] = piece["eye_shapes"][key][s]
                # the male fit is a smaller MakeHuman head scaled up less: the eyeball shrinks with it
                k = piece["eye_scale"].get(key, 1.0)
                fdeltas[nm][sel] += (Vf[sel] - piece["eyes"][s]) * (k - 1.0)
    # the blink: each lash turns about its eye's lateral axis with its root
    for s in (1, -1):
        sel = lash & (fside == s)
        _, dphi = MH.lid_blink(lash_roots[sel], piece["eyes"][s], s, piece["rows"][s], piece["eye_r"][s])
        cc = piece["eyes"][s]
        P = Vf[sel]
        Fw = -(P[:, 1] - cc[1])
        U = P[:, 2] - cc[2]
        rho = np.sqrt(Fw * Fw + U * U)
        ang = np.arctan2(U, Fw) + dphi
        Q = P.copy()
        Q[:, 1] = cc[1] - rho * np.cos(ang)
        Q[:, 2] = cc[2] + rho * np.sin(ang)
        fdeltas["blink"][sel] = Q - P
    fcol = np.concatenate([np.ones((len(Vf), 3)), np.zeros((len(Vf), 1))], 1)
    fcol[lash_lower, 1] = 0.0
    B._set_colors(face, fcol)
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
    stats["Body"]["head_tris"] = int(np.array([r == "head" for r in preg]).sum())
    for bo in rig.data.bones:
        bo.use_deform = bo.name in used_all or bo.use_deform
    reg_tris = {}
    for r in preg:
        reg_tris[r] = reg_tris.get(r, 0) + 1
    from body import peoples as PEOPLES
    if export:
        export_glb(rig, [ob, face], GLB, texcoords=True, morph=True)
        info = {
            "generator": "tools/character/body/body_v3.py (build_character.sh --body)", "lib_version": LIB_VERSION,
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
                       "blink": "both eyes closed (lids rotated about the eye centres); driven at runtime",
                       "stature": {"female": 1.00, "male": 1.07, "min": 0.95, "max": 1.10,
                                   "note": "uniform scale of the Actor_B instance at runtime (design 3.3)"}},
            "face_presets": {k: PEOPLES.preset_face(v) for k, v in PEOPLES.LEGACY_PRESETS.items()},
            "face": {"model": "head v3: the MakeHuman base head (CC0, tools/character/makehuman) with the 30 creator "
                              "features mapped onto its targets (body/mh.py)", "features": PEOPLES.feature_table(),
                     "calibration": MH.CALIB, "male_features": MH.male_features(), "fit": piece["fit"],
                     "detail_rect": _detail_rect(),
                     "warp": dict(fwarp, note=("face coordinates (u = arc length about the head's axis at 0.08 m, h = "
                                               "height) of the v3 head's landmarks and the v2 head's: the facial hair "
                                               "regions, marks and paint (face_detail.gdshaderinc, FaceExtras) were "
                                               "drawn on the v2 head and are warped piecewise-linearly onto this one")),
                     "landmarks": dict(flm, note="Godot space: the jewellery places (FaceExtras.landmark_data)")},
            "skin": {"tones": B.SKIN_TONES, "undertones": B.UNDERTONES, "labels": ["Tone %d" % (i + 1) for i in range(12)],
                     "note": ("melanin 0..1 maps linearly onto the 12 anchors (linear light); undertone = Oklab a/b "
                              "offset; haemoglobin 0..1 (0.5 average) = blood seen through the epidermis")},
            "eyes": B.EYE_IRIS,
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
            "provenance": PROVENANCE_RIG + " Body geometry generated procedurally by tools/character/body/body_v3.py; "
                                           "the head from the MakeHuman base mesh and targets (CC0, MakeHuman Community; "
                                           "MPFB 2.0.17 data, tools/character/makehuman/README.md).",
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
    return {"Body": ob, "Face": face}


def build_face(K, piece, bvh, M):
    """Face mesh: eyes (surface 'eye'), brows and lashes (surface 'face_hair'). Returns (object,
    zone per polygon, kind per vertex (0 eye, 1 brow, 2 lash), eye side per vertex, lash root per
    vertex, lower-lash flag per vertex)."""
    parts_V, parts_F, zones, kinds, uvs, sides = [], [], [], [], [], []
    for s in (1, -1):
        c = piece["eyes"][s]
        r = piece["eye_r"][s]
        P, Fq = B._eyeball(c)
        P = c + (P - c) * (r / B.FC.EYE_R)
        off = sum(len(v) for v in parts_V)
        parts_V.append(P)
        parts_F += [tuple(i + off for i in f) for f in Fq]
        zones += [(0, 0)] * len(Fq)
        kinds += [0] * len(P)
        sides += [s] * len(P)
        uvs.append(np.stack([P[:, 0] - c[0], P[:, 2] - c[2]], 1) * (B.FC.EYE_R / r))
    Vb, Fbq, UVb = MH.brows(bvh, K, piece["eyes"])
    off = sum(len(v) for v in parts_V)
    parts_V.append(Vb)
    parts_F += [tuple(i + off for i in f) for f in Fbq]
    zones += [(1, 0)] * len(Fbq)
    kinds += [1] * len(Vb)
    sides += [0] * len(Vb)
    uvs.append(UVb)
    Vl, Flq, UVl, roots, lower, lside = MH.lashes(piece)
    off = sum(len(v) for v in parts_V)
    parts_V.append(Vl)
    parts_F += [tuple(i + off for i in f) for f in Flq]
    zones += [(1, 1)] * len(Flq)
    kinds += [2] * len(Vl)
    sides += list(lside)
    uvs.append(UVl)
    V = np.vstack(parts_V)
    ob = mesh_object("Face", V, parts_F, M["eye"])
    ob.data.materials.append(M["face_hair"])
    for pp, (slot, z) in zip(ob.data.polygons, zones):
        pp.material_index = slot
        pp.use_smooth = True
    UV.ensure_layers(ob, ("UVMap", "Region"))
    lv, _lp = UV.loop_topology(ob)
    UV.write(ob, "UVMap", np.vstack(uvs)[lv])
    RG.write_region_uv(ob, np.array([RG.encode("head", z) for _, z in zones]), "Region")
    kinds = np.array(kinds)
    R = np.zeros_like(V)
    R[kinds == 2] = roots
    Lo = np.zeros(len(V), bool)
    Lo[kinds == 2] = lower
    return ob, np.array([z for _, z in zones]), kinds, np.array(sides), R, Lo
