"""Step 2 of the grey-box build (Blender, on a COPY of the Actor_B rig library, through the shared lock wrapper):

    ANIMATION_SOURCE_ROOT=<scratch>/src BLENDER_TIMEOUT=1000 \
    zsh tools/thuyvan/bin/blender_run.sh -b <scratch>/work/actor_b_rig_copy.blend --python-exit-code 1 \
        -P tools/thuyvan_art/bodies/build_greybox.py -- --kit floodborn --npz DIR --save OUT.blend [--glb DIR]

For each figure of the kit (variants A, B, C at the female base; A's male fit): QEM-decimate the polygonized meshes
(prepare_greybox.py) to the LOD0 budget, weight them on the lib's rules (kit_weights.py), build an armature with the
291 Actor_B bones in rig order at null-add plus the kit's extension bones in table order, bind, bake the painted AO
(COLOR_0) and the rest attributes, and save one .blend for render_bodies.py. With --glb, variant A is also exported
(291 + kit bones, `sex` morph) as the grey-box glb the Godot lane will attach.

Also a human of the same height for scale (assets/character/body/body.glb, the creator's body; female base, and the
male fit at stature 1.07).
"""

import argparse
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.dont_write_bytecode = True
import libshim  # noqa: E402,F401

import bpy  # noqa: E402
import numpy as np  # noqa: E402

from lib.context import BuildContext  # noqa: E402
from lib.remesh import tri_count  # noqa: E402
from lib.sdf import log, set_log_tag  # noqa: E402
from lib import rig as RIG  # noqa: E402

import blender_kit as BK  # noqa: E402
import kit_weights as KW  # noqa: E402
import pose as PO  # noqa: E402
from glb_read import read_glb  # noqa: E402
from skeleton import Joints, floodborn_bones, moc_tinh_bones, FRONTIER  # noqa: E402

BODY_GLB = os.path.join(FRONTIER, "assets", "character", "body", "body.glb")

# LOD0 grey-box budgets (design 3.4: Floodborn ~26k = body 16k + head 6k + tail 3k + claws/teeth 1k)
FB_BUDGET = {"body": 25000, "teeth": 1000, "eyes": 400, "crest": 4500}
MT_BUDGET = {"bark": 16000, "spurs": 600, "roots": 1500, "crown_branches": 1500, "crown_leaves": 5000, "vines": 1500,
             "vine_leaves": 1600, "moss": 4000}


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--kit", required=True)
    ap.add_argument("--npz", required=True)
    ap.add_argument("--save", required=True)
    ap.add_argument("--glb", default="")
    ap.add_argument("--variants", default="A0,B0,C0,A1")
    return ap.parse_args(argv)


def collection(name):
    c = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if c.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(c)
    return c


def to_collection(objs, col):
    for o in objs:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        col.objects.link(o)


def stats(fig, objs):
    return {o.name: tri_count(o) for o in objs if o.type == "MESH"}


# ===========================================================================
# Human (scale)
# ===========================================================================
def human(J, sex, mats):
    m = read_glb(BODY_GLB)
    bones = m["bones"]
    objs = []
    name = "human_%d" % int(sex)
    rig = BK.make_armature(name, J)
    for k, r in enumerate(m["meshes"]):
        V = r["V"] + (r["morphs"]["sex"] if sex and "sex" in r["morphs"] else 0)
        V = V + r["morphs"].get("genital_small", 0)          # a review marker: the creator's smallest shape
        W = np.zeros((len(V), len(bones)))
        for c in range(4):
            np.add.at(W, (np.arange(len(V)), r["joints"][:, c]), r["weights"][:, c])
        ob = BK.mesh("%s_%s" % (name, r["name"]), V, r["F"], mats["human"] if k == 0 else mats["human_eye"])
        BK.set_weights(ob, W, bones)
        BK.bind(ob, rig)
        objs.append(ob)
    BK.paint_ao(objs, rays=10)
    rig["figure"] = name
    rig["stature"] = 1.07 if sex else 1.0
    return rig, objs


# ===========================================================================
# Floodborn
# ===========================================================================
def floodborn(ctx, J, var, sex, npz, mats, glb_dir=""):
    import floodborn_shapes as FS
    P = FS.variant(var, sex)
    d = np.load(os.path.join(npz, "floodborn_%s_%d.npz" % (var, sex)))
    N = FS.build_nodes(J, P)
    kb = floodborn_bones(P.tail_scale, None, None)
    st, jt = FS.snout_tip(J, P), FS.jaw_tip(J, P)
    kb = [(n, p, (st if n == "snout_tip" else jt if n == "jaw_tip" else h),
           ((st if n == "snout_tip" else jt if n == "jaw_tip" else h) + (t - h)) if n in ("snout_tip", "jaw_tip") else t, df)
          for n, p, h, t, df in kb]
    Jk = PO.extend(J, kb)
    name = "floodborn_%s_%d" % (var, sex)
    bones = KW.weight_bones(Jk, Jk.deform_kit, ("jaw",))
    rig = BK.make_armature(name, Jk, [b[0] for b in kb])
    body = BK.reduce(BK.mesh(name + "_body", d["body_V"], d["body_F"], mats["fb_body"]), FB_BUDGET["body"])
    V = np.array([v.co for v in body.data.vertices])
    F = BK.tris_of(body)
    W, lab, labels = KW.floodborn_weights(V, F, Jk, N["groups"], N["curve"], P, bones, jt)
    BK.set_weights(body, W, bones)
    # extension parts mask (the tail on its bones) for the review sheets' mid grey
    tail_cols = [bones.index(n) for n in bones if n.startswith("tail_")]
    BK.set_attr(body, "ext", np.clip(W[:, tail_cols].sum(1) * 1.4, 0, 1))
    # belly (ventral) mask for the painted hide, from the rest normals and the regions
    objs = [body]
    parts = {}
    for k in ("eyes", "teeth", "crest"):
        if k + "_V" not in d:
            continue
        ob = BK.reduce(BK.mesh("%s_%s" % (name, k), d[k + "_V"], d[k + "_F"], mats["fb_" + k]), FB_BUDGET[k])
        Vp = np.array([v.co for v in ob.data.vertices])
        Wp = np.zeros((len(Vp), len(bones)))
        if k == "eyes":
            Wp[:, bones.index("headb")] = 1
        elif k == "teeth":
            up = Vp[:, 2] > 1.4655
            Wp[up, bones.index("headb")] = 1
            Wp[~up, bones.index("jaw")] = 1
        else:
            Wp = KW.limit_normalize(KW.nearest_transfer(V, W, Vp, k=6))
        BK.set_weights(ob, Wp, bones)
        BK.set_attr(ob, "ext", np.ones(len(Vp)) if k == "crest" else np.zeros(len(Vp)))
        parts[k] = ob
        objs.append(ob)
    for ob in objs:
        BK.bind(ob, rig)
    BK.paint_ao(objs)
    # paint masks: belly (ventral cream), claws (bone with dark tips), the region labels
    Nrm = BK.vertex_normals(body)
    lab_name = np.array(labels)[lab]
    belly = np.zeros(len(V))
    front = np.clip((-Nrm[:, 1] - 0.15) / 0.5, 0, 1)
    tors = np.isin(lab_name, ["torso", "neck", "jaw"])
    narrow = np.clip((0.15 - np.abs(V[:, 0])) / 0.05, 0, 1)
    belly[tors] = (front * narrow)[tors] * (V[tors, 2] < 1.47) * np.clip((V[tors, 2] - 0.80) / 0.08, 0, 1)
    belly[lab_name == "jaw"] = np.maximum(belly[lab_name == "jaw"], np.clip((-Nrm[lab_name == "jaw", 2] + 0.2) / 0.5, 0, 1))
    for sd, s in (("l", 1), ("r", -1)):
        for g in ("arm_", "leg_"):
            m = lab_name == g + sd
            inner = np.clip((-s * Nrm[m, 0] - 0.1) / 0.5, 0, 1) * (np.clip((-Nrm[m, 1]) + 0.6, 0, 1))
            belly[m] = inner * (0.85 if g == "arm_" else 0.3)
    tm = lab_name == "tail"
    belly[tm] = np.clip((-Nrm[tm, 2] - 0.1) / 0.5, 0, 1)
    BK.set_attr(body, "belly", belly)
    from lib.sdf import peval
    claws = np.zeros(len(V))
    for s in (1, -1):
        cd = peval(FS.claws_hand(J, s, P), V)
        claws = np.maximum(claws, np.clip(1 - cd / 0.004, 0, 1))
    # foot claws: forward of the toe tips
    for sd in "lr":
        fm = lab_name == "foot_" + sd
        ytip = V[fm, 1].min()
        claws[fm] = np.maximum(claws[fm], np.clip((-(V[fm, 1] - (ytip + 0.035))) / 0.02, 0, 1) * (V[fm, 2] < 0.04))
    BK.set_attr(body, "claw", claws)
    BK.set_attr(body, "region_head", np.isin(lab_name, ["head", "jaw"]).astype(float))
    # eyes: the slit pupil mask
    if "eyes" in parts:
        ob = parts["eyes"]
        Ve = np.array([v.co for v in ob.data.vertices])
        pup = np.zeros(len(Ve))
        for s in (1, -1):
            c = FS.eyeball_center(J, s)
            out_dir = np.array([s * 0.75, -0.55, 0.35])
            out_dir /= np.linalg.norm(out_dir)
            dv = Ve - c
            dn = dv / np.maximum(np.linalg.norm(dv, axis=1, keepdims=True), 1e-9)
            side = (Ve[:, 0] * s) > 0
            fac = (dn @ out_dir > 0.55)
            hor = np.cross(out_dir, [0, 0, 1])
            hor /= np.linalg.norm(hor)
            slit = np.abs(dn @ hor) < 0.12
            pup[side & fac & slit] = 1
        BK.set_attr(ob, "pupil", pup)
    rig["figure"] = name
    rig["stature"] = 1.07 if sex else 1.0
    rig["variant"] = var
    rig["kit"] = "floodborn"
    tri = stats(name, objs)
    log("%s tris %s" % (name, tri))
    rig["tris"] = json.dumps(tri)
    if glb_dir and sex == 0 and var == "A":
        export_floodborn(J, P, rig, body, objs, glb_dir, name)
    return rig, objs


def export_floodborn(J, P, rig, body, objs, glb_dir, name):
    """The grey-box glb: 291 Actor_B bones in rig order then the kit bones, `sex` by projection onto the male fit."""
    import floodborn_shapes as FS
    from lib.shapes import project_shape, add_shape_keys
    PM = FS.variant(P.name, 1.0)
    NM = FS.build_nodes(J, PM)
    V = np.array([v.co for v in body.data.vertices])
    F = BK.tris_of(body)
    E = KW.edges(F)
    D = project_shape(V, NM["body"], E=E, step=0.008, iters=10, smooth=3)
    add_shape_keys(body, {"sex": D})
    os.makedirs(glb_dir, exist_ok=True)
    path = os.path.join(glb_dir, "floodborn_greybox.glb")
    RIG.export_glb(rig, objs, path, texcoords=False, morph=True)
    log("exported %s" % path)
    if body.data.shape_keys:
        body.shape_key_clear()


# ===========================================================================
# Mộc Tinh
# ===========================================================================
def moc_tinh(ctx, J, var, sex, npz, mats, glb_dir=""):
    import moc_tinh_shapes as MS
    P = MS.variant(var, sex)
    d = np.load(os.path.join(npz, "moc_tinh_%s_%d.npz" % (var, sex)))
    name = "moc_tinh_%s_%d" % (var, sex)
    off, lift = MS.joint_offsets(J, P)
    # the proportion's rest (PeopleProportion bone offsets), then the kit bones
    G2 = {}
    for n in J.order:
        g = J.G[n].copy()
        g[:3, 3] += off[n]
        G2[n] = g
    Jm = Joints(G2, dict(J.parent), list(J.order))
    kb = [(str(n), str(p), np.array(h), np.array(t), bool(df)) for n, p, h, t, df in
          zip(d["kit_names"], d["kit_parents"], d["kit_heads"], d["kit_tails"], d["kit_deform"])]
    vines = [(n, p, h + np.array([0, 0, lift]), t + np.array([0, 0, lift]), df) for n, p, h, t, df in moc_tinh_bones()
             if n.startswith("vine_")]
    kb = kb + vines
    Jk = PO.extend(Jm, kb)
    bones_glb = [str(b) for b in d["bones"]]
    bones = KW.weight_bones(Jk, Jk.deform_kit)
    bi = {b: i for i, b in enumerate(bones)}

    def remap(Wg):
        W = np.zeros((len(Wg), len(bones)))
        for j, b in enumerate(bones_glb):
            if b in bi:
                W[:, bi[b]] += Wg[:, j]
            else:   # a glb bone outside the weight columns (breast, spinea_muscle): to its nearest weighted parent
                p = J.parent.get(b)
                while p is not None and p not in bi:
                    p = J.parent.get(p)
                if p is not None:
                    W[:, bi[p]] += Wg[:, j]
        return W
    rig = BK.make_armature(name, Jk, [b[0] for b in kb])
    Wb = remap(d["body_W"].astype(float))
    body = BK.mesh(name + "_body", d["body_V"], d["body_F"], mats["mt_body"])
    BK.set_weights(body, Wb, bones)
    objs = [body]
    # the MakeHuman eyes and brows (the face is untouched; the proportion only lifts it)
    m = read_glb(BODY_GLB)
    for r in m["meshes"][1:]:
        Wg = np.zeros((len(r["V"]), len(m["bones"])))
        for c in range(4):
            np.add.at(Wg, (np.arange(len(r["V"])), r["joints"][:, c]), r["weights"][:, c])
        V = r["V"] + (r["morphs"]["sex"] if sex and "sex" in r["morphs"] else 0) + np.array([0, 0, lift])
        tag = r["material"] or r["name"]
        ob = BK.mesh("%s_%s" % (name, tag), V, r["F"], mats["mt_eye"] if tag == "eye" else mats["mt_brow"])
        W = np.zeros((len(V), len(bones)))
        W[:, bi["headb"]] = 1
        BK.set_weights(ob, W, bones)
        objs.append(ob)
    Vbody = d["body_V"]
    # bark shell: weights first (the decimation interpolates the groups), the crack field rides as a group too
    bark = BK.mesh(name + "_bark", d["bark_V"], d["bark_F"], mats["mt_bark"])
    BK.set_weights(bark, remap(d["bark_W"].astype(float)), bones)
    vg = bark.vertex_groups.new(name="_crack")
    for i, c in enumerate(d["bark_crack"]):
        vg.add([i], float(c), "REPLACE")
    BK.reduce(bark, MT_BUDGET["bark"])
    crack = np.zeros(len(bark.data.vertices))
    gi = bark.vertex_groups["_crack"].index
    for v in bark.data.vertices:
        for g in v.groups:
            if g.group == gi:
                crack[v.index] = g.weight
    bark.vertex_groups.remove(bark.vertex_groups["_crack"])
    BK.set_attr(bark, "crack", crack)
    objs.append(bark)
    head_top = float(d["head_top"])
    crown_bones = [b[0] for b in kb if b[0].startswith("crown_")]
    vine_chains = {}
    for b in vines:
        vine_chains.setdefault(b[0][:6], []).append(b[0])
    for k in ("spurs", "roots", "crown_branches", "crown_leaves", "vines", "vine_leaves", "moss"):
        if k + "_V" not in d:
            continue
        ob = BK.reduce(BK.mesh("%s_%s" % (name, k), d[k + "_V"], d[k + "_F"], mats["mt_" + k]), MT_BUDGET[k])
        Vp = np.array([v.co for v in ob.data.vertices])
        if k.startswith("crown"):
            Wp = KW.chain_rigid(Vp, crown_bones, bones, Jk)
            low = Vp[:, 2] < head_top - 0.005
            Wp[low] = 0
            Wp[low, bi["headb"]] = 1
        elif k in ("vines", "vine_leaves"):
            dist = np.array([np.linalg.norm(Vbody - p, axis=1).min() for p in Vp])
            Wp = KW.nearest_transfer(Vbody, Wb, Vp, k=6)
            # only the free ends hanging in front of the trunk ride the vine bones; the wound vines ride the body
            hang = (dist > 0.03) & (np.abs(Vp[:, 0]) < 0.2) & (Vp[:, 2] < 1.3)
            if hang.any():
                allv = [n for ch in vine_chains.values() for n in ch]
                Wp[hang] = KW.chain_rigid(Vp[hang], allv, bones, Jk)
        elif k == "moss":
            Wp = KW.nearest_transfer(Vbody, Wb, Vp, k=6, mask=Vbody[:, 2] > 1.0)
        else:
            Wp = KW.nearest_transfer(Vbody, Wb, Vp, k=6)
        BK.set_weights(ob, KW.limit_normalize(Wp), bones)
        objs.append(ob)
    # flowers (white five-petal cards on the crown and the shoulder vines)
    fl = d["flowers"]
    if len(fl):
        rng = np.random.RandomState(3)
        ob = BK.cards(name + "_flowers", fl[:, :3], fl[:, 3:], 0.045, mats["mt_flower"], rng, jitter=0.3)
        Vp = np.array([v.co for v in ob.data.vertices])
        Wp = KW.chain_rigid(Vp, crown_bones, bones, Jk)
        low = Vp[:, 2] < head_top - 0.005
        Wp[low] = 0
        Wp[low, bi["headb"]] = 1
        BK.set_weights(ob, KW.limit_normalize(Wp), bones)
        objs.append(ob)
    for ob in objs:
        BK.bind(ob, rig)
        BK.set_attr(ob, "ext", np.zeros(len(ob.data.vertices)) if ob.name.endswith(("_body", "_bark", "_spurs", "eye", "face_hair"))
                    else np.ones(len(ob.data.vertices)))
    BK.paint_ao([o for o in objs if not o.name.endswith("_flowers")])
    flo = [o for o in objs if o.name.endswith("_flowers")]
    for o in flo:
        n = len(o.data.vertices)
        BK.set_attr(o, "Color", np.tile([0.95, 0.95, 0.95, 1.0], (n, 1)), "FLOAT_COLOR")
    # the face region (finer, paler grain in the paint)
    bi_head = [bi[b] for b in ("headb", "heada") if b in bi]
    BK.set_attr(body, "face", np.clip(Wb[:, bi_head].sum(1) * 1.5, 0, 1))
    rig["figure"] = name
    rig["stature"] = 1.07 if sex else 1.0
    rig["variant"] = var
    rig["kit"] = "moc_tinh"
    rig["head_top"] = head_top
    tri = stats(name, objs)
    log("%s tris %s" % (name, tri))
    rig["tris"] = json.dumps(tri)
    if glb_dir and sex == 0 and var == "A":
        os.makedirs(glb_dir, exist_ok=True)
        path = os.path.join(glb_dir, "moc_tinh_greybox.glb")
        RIG.export_glb(rig, objs, path, texcoords=False, morph=False)
        log("exported %s" % path)
    return rig, objs


def materials():
    return {
        "human": BK.clay("clay_human", "#d2c3a6", 0.75), "human_eye": BK.clay("clay_human_eye", "#e8e4dc", 0.5),
        "fb_body": BK.clay("clay_fb_body", "#7d7a76", 0.8, mask_attr="ext", hex2="#a9adb3"),
        "fb_eyes": BK.clay("clay_fb_eyes", "#3a3631", 0.4), "fb_teeth": BK.clay("clay_fb_teeth", "#e6e1d3", 0.6),
        "fb_crest": BK.clay("clay_fb_crest", "#a9adb3", 0.8),
        "mt_body": BK.clay("clay_mt_body", "#7d7a76", 0.8), "mt_bark": BK.clay("clay_mt_bark", "#86827c", 0.85),
        "mt_eye": BK.clay("clay_mt_eye", "#3a3631", 0.4), "mt_brow": BK.clay("clay_mt_brow", "#5a5650", 0.8),
        "mt_spurs": BK.clay("clay_mt_spurs", "#86827c", 0.85), "mt_roots": BK.clay("clay_mt_roots", "#86827c", 0.85),
        "mt_crown_branches": BK.clay("clay_mt_crown_branches", "#a9adb3", 0.8),
        "mt_crown_leaves": BK.clay("clay_mt_crown_leaves", "#b9bdc3", 0.85),
        "mt_vines": BK.clay("clay_mt_vines", "#a9adb3", 0.8), "mt_vine_leaves": BK.clay("clay_mt_vine_leaves", "#b9bdc3", 0.85),
        "mt_moss": BK.clay("clay_mt_moss", "#b9bdc3", 0.9),
        "mt_flower": BK.flat_material("clay_mt_flower", "#f0ede4", 0.7),
    }


def main():
    a = parse()
    build(a.kit, a.npz, a.save, a.glb, a.variants)


def build(kit, npz, save, glb="", variants="A0,B0,C0,A1"):
    set_log_tag("build_greybox")
    t0 = time.time()
    ctx = BuildContext()
    J = Joints.from_rig(ctx.rig, ctx.G)
    for o in list(bpy.data.objects):        # the library's own meshes are not used
        if o is not ctx.rig:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.update()
    mats = materials()
    figs = []
    for tag in variants.split(","):
        var, sex = tag[0], int(tag[1])
        if kit == "floodborn":
            rig, objs = floodborn(ctx, J, var, sex, npz, mats, glb)
        else:
            rig, objs = moc_tinh(ctx, J, var, sex, npz, mats, glb)
        to_collection([rig] + objs, collection(rig.name))
        figs.append(rig.name)
        log("built %s (%.0fs)" % (rig.name, time.time() - t0))
    for sex in (0, 1):
        rig, objs = human(J, sex, mats)
        to_collection([rig] + objs, collection(rig.name))
    ctx.rig.hide_render = True
    ctx.rig.hide_viewport = True
    bpy.ops.wm.save_as_mainfile(filepath=save)
    log("saved %s in %.0fs" % (save, time.time() - t0))


if __name__ == "__main__":
    main()
