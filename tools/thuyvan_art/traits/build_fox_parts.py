"""Hồ Tinh fox ears and tails, built as body attachments in the format of the creator's garments and hair (a skinned glb
on the Actor_B rig plus a catalog-style json), run inside Blender through the shared lock wrapper:

    zsh tools/thuyvan/bin/blender_run.sh -b --python-exit-code 1 --python tools/thuyvan_art/traits/build_fox_parts.py

-> assets/thuyvan/character/fox/ho_tinh_ears_{pointed,rounded,tufted}.glb + .json
   assets/thuyvan/character/fox/ho_tinh_tails_{1,3,9}.glb + .json
   data/thuyvan_art/fox_features.json (the tail bones, springs, pose layer, ear shape keys and the fur colours)

Design (peoples_design 2.8, bodies_design 2.1): the ears are rigid on `headb`, about 10 cm tall, set high on the
head's sides; three shape keys (`ear_back`, `ear_flat`, `ear_perk`), and a hat that hides the hair crown sets
`ear_flat`. The tails hang from the sacrum on their OWN bones (extension bones, `fox_tail_<k>_<jj>`, five per tail,
parented to `pelvis`); clips never key them, so every Actor_B clip plays unchanged; BodyExtensions adds them and drives
them as spring chains with a pose layer (lead's lane). Tail count 1-9 is a free cosmetic, never a stat.

Paint lives in COLOR_0, not the hue, so every fur colour is a material choice (as hair: value + a colour model):
  R the painted value (0.5 average; the tufts' ridges lighter, their valleys and the underside darker)
  G the tip (the tail's pale or dark tip; the ear's tip)
  B the ear's inner skin (1) and its inner tuft (0.55); 0 elsewhere
Everything is our own procedural shape: no sheet pixels, no other game's forms.
"""
import json
import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bscene as B  # noqa: E402

ROOT = B.ROOT
OUT = os.path.join(ROOT, "assets", "thuyvan", "character", "fox")
DATA = os.path.join(ROOT, "data", "thuyvan_art", "fox_features.json")
TAIL_BONES = 5
TAIL_LEN = 1.02          # metres, root to tip (the lineup's tails reach the ground and fan wider than the body)


def smooth(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def h1(i, seed=0):
    x = math.sin(i * 127.1 + seed * 311.7) * 43758.5453
    return x - math.floor(x)


# ----------------------------------------------------------------------------------------------------------- the ears
EAR_SHAPES = {
    # height, base width, depth (cup), width profile exponent, tip roundness, tuft at the tip
    "pointed": dict(h=0.105, w=0.062, d=0.024, k=0.95, round=0.0, tuft=0.0),
    "rounded": dict(h=0.088, w=0.068, d=0.026, k=0.55, round=1.0, tuft=0.0),
    "tufted": dict(h=0.110, w=0.058, d=0.023, k=1.05, round=0.0, tuft=0.028),
}


def ear_points(shape, frame):
    """A closed crescent section stacked from the base to the tip: the convex back, the cupped front, a thick rim.
    Returns verts, faces, per-vertex (value, tip, inner)."""
    S = EAR_SHAPES[shape]
    base, U, F, Sx = frame
    K = 14                      # points per arc
    T = 22                      # sections
    verts, cols, faces = [], [], []
    for it in range(T + 1):
        t = it / T
        if S["round"] > 0:
            wt = S["w"] * math.sqrt(max(0.0, 1.0 - t ** 2.4)) * (1.0 - 0.25 * t)
        else:
            wt = S["w"] * (1.0 - t) ** S["k"]
        wt = max(wt, 0.0012)
        dt = S["d"] * (1.0 - 0.7 * t)
        lean = 0.012 * t * t                       # the tip bends a little back
        ring = []
        for side in (0, 1):                        # 0 the back arc, 1 the front (inner) arc, back again
            for ik in range(K + 1):
                s = -1.0 + 2.0 * ik / K
                if side == 1:
                    s = -s
                if side == 1 and (ik == 0 or ik == K):
                    continue
                prof = (1.0 - s * s) ** 0.6
                if side == 0:
                    depth = -dt * prof - 0.004 * (1 - s * s)
                    inner = 0.0
                else:
                    depth = -dt * prof * 0.45 + 0.002
                    inner = smooth(0.95, 0.55, abs(s)) * smooth(0.98, 0.7, t)
                p = base + U * (S["h"] * t) + Sx * (s * wt * 0.5) + F * (depth - lean)
                v = 0.5 + 0.12 * t - 0.10 * (1 - t) * (1 - abs(s)) * (side == 1)
                tip = smooth(0.70, 0.92, t)
                ring.append(len(verts))
                verts.append(p)
                cols.append((v, tip, inner))
        n = len(ring)
        if it > 0:
            prev = list(range(ring[0] - n, ring[0]))
            for a in range(n):
                b = (a + 1) % n
                faces.append((prev[a], prev[b], ring[b], ring[a]))
    # close the tip
    tip_i = len(verts)
    verts.append(base + U * (S["h"] * 1.02) + F * (-0.012))
    cols.append((0.62, 1.0, 0.0))
    last = list(range(tip_i - n, tip_i))
    for a in range(n):
        faces.append((last[a], last[(a + 1) % n], tip_i))
    # the inner tuft: four flat flame-shaped wedges rising from the inner base
    for j in range(4):
        s0 = -0.55 + 0.37 * j
        root = base + Sx * (s0 * S["w"] * 0.4) + F * (0.002) + U * 0.006
        tipv = root + U * (S["h"] * (0.38 + 0.12 * h1(j, 3))) + Sx * (s0 * 0.018) + F * 0.012
        wv = Sx * 0.006
        i0 = len(verts)
        verts += [root - wv, root + wv, (root + tipv) * 0.5 + F * 0.004, tipv]
        cols += [(0.55, 0.0, 0.55)] * 4
        faces += [(i0, i0 + 1, i0 + 2), (i0 + 1, i0 + 3, i0 + 2), (i0, i0 + 2, i0 + 3)]
    if S["tuft"] > 0:
        tp = base + U * S["h"]
        i0 = len(verts)
        verts += [tp - Sx * 0.004 + F * -0.01, tp + Sx * 0.004 + F * -0.01, tp + U * S["tuft"] + F * -0.016]
        cols += [(0.35, 1.0, 0.0)] * 3
        faces += [(i0, i0 + 1, i0 + 2)]
    return verts, faces, cols


def head_anchor(body, sgn):
    """Where an ear sits: the head's skin point facing up and out on this side (high on the head, behind the brow),
    lifted 12 mm over the hair."""
    me = body.data
    best, bp, bn = -9, None, None
    d = Vector((0.55 * sgn, 0.12, 0.83)).normalized()        # Blender: up = +Z, back = +Y
    for v in me.vertices:
        co = v.co
        if co.z < 1.50:
            continue
        sc = v.normal.dot(d) + 2.0 * (co.normalized().dot(d) * 0)
        if sc > best:
            best, bp, bn = sc, co.copy(), v.normal.copy()
    return bp + bn * 0.012, bn


def build_ears(arm, body, shape):
    allv, allf, allc = [], [], []
    keys = {"ear_back": [], "ear_flat": [], "ear_perk": []}
    for sgn in (1.0, -1.0):
        base, n = head_anchor(body, sgn)
        U = (n + Vector((0, 0, 0.9))).normalized()
        U = (U + Vector((0.0, 0.06, 0.0))).normalized()
        F = Vector((0.30 * sgn, -1.0, 0.0))
        F = (F - U * F.dot(U)).normalized()
        Sx = U.cross(F).normalized() * (1 if sgn > 0 else -1)
        v, f, c = ear_points(shape, (base, U, F, Sx))
        off = len(allv)
        allv += v
        allf += [tuple(i + off for i in ff) for ff in f]
        allc += c
        hinge = Sx.normalized()
        for key, ang, out in (("ear_back", -38.0, 0.0), ("ear_flat", -72.0, 0.15), ("ear_perk", 12.0, -0.05)):
            R = Matrix.Rotation(math.radians(ang) * (1 if sgn > 0 else -1) * -1, 3, hinge)
            if key == "ear_flat":
                R = Matrix.Rotation(math.radians(18.0 * sgn), 3, Vector((0, 1, 0))) @ R
            keys[key] += [base + R @ (p - base) for p in v]
    me = bpy.data.meshes.new("ho_tinh_ears_" + shape)
    me.from_pydata([tuple(p) for p in allv], [], allf)
    me.update()
    ob = bpy.data.objects.new("ho_tinh_ears_" + shape, me)
    bpy.context.scene.collection.objects.link(ob)
    ca = me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    for i, c in enumerate(allc):
        ca.data[i].color = (c[0], c[1], c[2], 1.0)
    for p in me.polygons:
        p.use_smooth = True
    ob.shape_key_add(name="Basis")
    for key, pts in keys.items():
        sk = ob.shape_key_add(name=key)
        for i, p in enumerate(pts):
            sk.data[i].co = p
    vg = ob.vertex_groups.new(name="headb")
    vg.add(list(range(len(allv))), 1.0, "REPLACE")
    ob.parent = arm
    md = ob.modifiers.new("Armature", "ARMATURE")
    md.object = arm
    return ob


# ----------------------------------------------------------------------------------------------------------- the tails
def sacrum(body):
    """The skin's back point at the sacrum (Blender: the most +Y point near x 0, z 0.93)."""
    best, bp = -9, None
    for v in body.data.vertices:
        co = v.co
        if abs(co.x) < 0.02 and abs(co.z - 0.93) < 0.02 and co.y > best:
            best, bp = co.y, co.copy()
    return bp


def tail_layout(n):
    """Per tail: (root offset across the sacrum, spread angle, droop): a 1 is straight back and down; 3 and 9 fan."""
    if n == 1:
        return [(0.0, 0.0, 0.0)]
    out = []
    for k in range(n):
        u = (k / (n - 1)) * 2 - 1                        # -1..1
        out.append((u * (0.022 if n == 3 else 0.045), u * (24.0 if n == 3 else 42.0), abs(u) * 6.0))
    return out


def centreline(root, spread_deg, droop_deg, length):
    """The bind-pose centre line: back and down 38 deg below horizontal at the root, curving up a little toward the tip
    (an easy curve to skin), turned out by the spread."""
    pts = []
    N = 60
    for i in range(N + 1):
        t = i / N
        pitch = math.radians(-38.0 - droop_deg + 30.0 * t * t)
        pts.append((t, pitch))
    yaw = math.radians(spread_deg)
    p = root.copy()
    out = [p.copy()]
    step = length / N
    for i in range(1, N + 1):
        t, pitch = pts[i]
        d = Vector((math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
        p = p + d * step
        out.append(p.copy())
    return out


def tail_radius(t, big):
    r = big * (0.28 + 0.72 * smooth(0.0, 0.42, t)) * (1.0 - smooth(0.55, 1.0, t) ** 1.6)
    return max(r, 0.0015 if t < 0.999 else 0.0)


def build_tail(arm, line, k, sides, rings, big, seed):
    """A tube on the centre line with painted fur lobes: the radius swells into 7-8 flame-like ridges that sweep
    toward the tip and break the tip into tufts; COLOR_0 carries the painted value and the tip."""
    verts, cols, faces, wts = [], [], [], []
    L = len(line) - 1
    # parallel-transport frames
    tang = [(line[min(i + 1, L)] - line[max(i - 1, 0)]).normalized() for i in range(L + 1)]
    up = Vector((0, 0, 1))
    n0 = (up - tang[0] * up.dot(tang[0])).normalized()
    frames = []
    nrm = n0
    for i in range(L + 1):
        nrm = (nrm - tang[i] * nrm.dot(tang[i])).normalized()
        frames.append((nrm.copy(), tang[i].cross(nrm).normalized()))
    lobes = 7 + (seed % 2)
    for ir in range(rings + 1):
        t = ir / rings
        fi = t * L
        i0 = int(math.floor(fi))
        i1 = min(i0 + 1, L)
        a = fi - i0
        c = line[i0].lerp(line[i1], a)
        nn, bb = frames[i0]
        r0 = tail_radius(t, big)
        for js in range(sides):
            th = 2 * math.pi * js / sides
            ph = lobes * th + 7.5 * t + 1.7 * h1(seed, 2) + 0.6 * math.sin(3.0 * t + h1(js, seed))
            lobe = max(0.0, math.cos(ph)) ** 2.2
            flick = smooth(0.62, 0.98, t) * (0.5 + 0.5 * math.cos(ph * 0.5 + 1.3)) * 0.35
            r = r0 * (0.86 + 0.32 * lobe + flick)
            # a little flattened (wider than tall), the underside fuller near the root
            off = nn * (math.cos(th) * r * 0.9) + bb * (math.sin(th) * r * 1.08)
            verts.append(c + off)
            topness = math.cos(th)            # nn ~ up at the root
            v = 0.5 + 0.20 * (lobe - 0.45) + 0.08 * topness - 0.10 * (1.0 - smooth(0.0, 0.18, t))
            edge = 0.80 + 0.05 * math.cos(lobes * th + 2.0) + 0.04 * h1(js + 7, seed)
            tip = smooth(edge - 0.05, edge + 0.05, t)
            cols.append((min(max(v, 0.0), 1.0), tip, 0.0))
            sfi = t * TAIL_BONES
            w = []
            for j in range(TAIL_BONES):
                cj = j + 0.5
                w.append(max(0.0, 1.0 - abs(sfi - cj)))
            if sfi < 0.5:
                w = [1.0] + [0.0] * (TAIL_BONES - 1)
            if sfi > TAIL_BONES - 0.5:
                w = [0.0] * (TAIL_BONES - 1) + [1.0]
            s = sum(w)
            wts.append([x / s for x in w])
    for ir in range(rings):
        for js in range(sides):
            a = ir * sides + js
            b = ir * sides + (js + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    # root cap
    rc = len(verts)
    verts.append(line[0] - tang[0] * 0.01)
    cols.append((0.4, 0.0, 0.0))
    wts.append([1.0] + [0.0] * (TAIL_BONES - 1))
    for js in range(sides):
        faces.append((rc, (js + 1) % sides, js))
    me = bpy.data.meshes.new("fox_tail_%d" % k)
    me.from_pydata([tuple(p) for p in verts], [], faces)
    me.update()
    ob = bpy.data.objects.new("fox_tail_%d" % k, me)
    bpy.context.scene.collection.objects.link(ob)
    ca = me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    for i, cc in enumerate(cols):
        ca.data[i].color = (cc[0], cc[1], cc[2], 1.0)
    for p in me.polygons:
        p.use_smooth = True
    groups = [ob.vertex_groups.new(name="fox_tail_%d_%02d" % (k, j + 1)) for j in range(TAIL_BONES)]
    for i, w in enumerate(wts):
        for j, x in enumerate(w):
            if x > 1e-4:
                groups[j].add([i], x, "REPLACE")
    ob.parent = arm
    md = ob.modifiers.new("Armature", "ARMATURE")
    md.object = arm
    return ob


def add_tail_bones(arm, lines):
    """Edit bones along each tail's centre line, five per tail, the first parented to pelvis. Returns the bone table
    in Godot space (bodies_design 2.2's format: name, parent, head, len)."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    table = []
    for k, line in enumerate(lines, start=1):
        L = len(line) - 1
        parent = eb["pelvis"]
        for j in range(TAIL_BONES):
            a = line[round(j * L / TAIL_BONES)]
            b = line[round((j + 1) * L / TAIL_BONES)]
            bn = eb.new("fox_tail_%d_%02d" % (k, j + 1))
            bn.head, bn.tail = a, b
            bn.roll = 0.0
            bn.parent = parent
            bn.use_connect = j > 0
            bn.use_deform = True
            parent = bn
            g = (round(a.x, 4), round(a.z, 4), round(-a.y, 4))
            table.append({"name": bn.name, "parent": bn.parent.name, "head": list(g), "len": round((b - a).length, 4)})
    bpy.ops.object.mode_set(mode="OBJECT")
    return table


def export(objs, arm, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_skins=True, export_morph=True,
              export_apply=False, export_yup=True, export_animations=False)
    for extra in (dict(export_vertex_color="ACTIVE"), dict(export_colors=True), {}):
        try:
            bpy.ops.export_scene.gltf(**kw, **extra)
            return
        except TypeError:
            continue


def catalog(path, id_, name, slot, desc, surfaces, zones, tris, extra):
    d = {"id": id_, "name": name, "description": desc, "kind": "feature", "set": "tv_features", "slot": slot,
         "alt_slots": [], "layer": {"default": 72 if slot == "features.ears" else 12},
         "glb": "res://assets/thuyvan/character/fox/%s.glb" % id_, "mesh": id_,
         "surfaces": surfaces, "occupies_regions": [], "hides_regions": [], "hides_hair_zones": [], "hair_zones": [],
         "excludes": [], "requires": [], "variants": {}, "skirt": None, "helpers": [],
         "body_fit": {"shapes": [], "female": True, "male": True}, "zones": zones,
         "stats": {"tris": tris}, "status": "proposal"}
    d.update(extra)
    json.dump(d, open(path, "w"), indent=1, ensure_ascii=False)


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


FUR = {"cream": ("#f2dcc8", "#fbf5ec"), "russet": ("#b94420", "#f6efe6"), "silver_white": ("#dfe2e4", "#ffffff"),
       "ash": ("#8f8a86", "#d9d6d2"), "black_tipped": ("#b94420", "#1e1a18")}


def main():
    os.makedirs(OUT, exist_ok=True)
    data = {"format": "thuyvan.fox_features", "version": 1,
            "note": "Hồ Tinh features shown (the Condition row Features hidden / shown): fox ears rigid on headb with three shape "
                    "keys, and 1, 3 or 9 tails on their own extension bones (BodyExtensions adds them before the Skin is built; "
                    "clips never key them). Tail count and fur colour are free cosmetics, never a stat. Visual only: no speed, "
                    "aim, capsule or camera change. Status: proposal.",
            "ears": {}, "tails": {}, "fur_colors": {k: {"base": v[0], "tip": v[1]} for k, v in FUR.items()},
            "inner_ear": "#f2dcc8", "inner_tuft": "#fbf3e8",
            "color_model": "COLOR_0: R painted value (0.5 avg) -> ramp(base*0.55, base, mix(base, white, 0.35)); G tip -> the tip colour; B inner ear (1) / inner tuft (0.55)",
            "hat_rule": "a head garment that hides the hair crown (hides_hair_zones has 'crown') sets ear_flat 1.0; a hood sets ear_back 1.0",
            "garment_rule": "with tails shown, the lower garments open the tail_root hide region (tail_slit: a back slit at 180 deg up to 0.95 m); the tails root 2 cm off the skin at the sacrum, above the trouser band"}
    B.reset()
    objs = B.import_glb(os.path.join(B.CHAR, "body", "body.glb"))
    arm = [o for o in objs if o.type == "ARMATURE"][0]
    body = [o for o in objs if o.type == "MESH" and o.name.startswith("Body")][0]
    for shape in EAR_SHAPES:
        ob = build_ears(arm, body, shape)
        p = os.path.join(OUT, "ho_tinh_ears_%s.glb" % shape)
        export([ob], arm, p)
        tris = tri_count(ob)
        catalog(p[:-4] + ".json", "ho_tinh_ears_" + shape, "Fox ears, " + shape, "features.ears",
                "Fox ears of the Fox-Blooded, %s; fur over a pale inner ear with a tuft; rigid on the head." % shape,
                [{"surface": "fur", "name": "ho_tinh_ears_" + shape}],
                [{"zone": 0, "name": "fur", "role": "fur", "fabric": "FUR", "palette": list(FUR), "default": "cream"}],
                tris, {"bone": "headb", "shape_keys": ["ear_back", "ear_flat", "ear_perk"]})
        data["ears"][shape] = {"glb": "res://assets/thuyvan/character/fox/ho_tinh_ears_%s.glb" % shape, "tris": tris,
                               "bone": "headb", "shape": EAR_SHAPES[shape]}
        print("FOX_EARS", shape, tris)
        bpy.data.objects.remove(ob, do_unlink=True)
    root = sacrum(body) + Vector((0, 0.02, 0))
    for n, (sides, rings, big) in ((1, (28, 60, 0.105)), (3, (24, 52, 0.095)), (9, (20, 44, 0.082))):
        B.reset()
        objs = B.import_glb(os.path.join(B.CHAR, "body", "body.glb"))
        arm = [o for o in objs if o.type == "ARMATURE"][0]
        body = [o for o in objs if o.type == "MESH" and o.name.startswith("Body")][0]
        lines = []
        for k, (dx, spread, droop) in enumerate(tail_layout(n), start=1):
            r = root + Vector((dx, 0.0, -abs(dx) * 0.3))
            lines.append(centreline(r, spread, droop, TAIL_LEN * (1.0 - 0.08 * abs(spread) / 42.0)))
        table = add_tail_bones(arm, lines)
        tails = [build_tail(arm, line, k, sides, rings, big, seed=k * 13 + n) for k, line in enumerate(lines, start=1)]
        for o in objs:
            if o.type == "MESH":
                bpy.data.objects.remove(o, do_unlink=True)
        p = os.path.join(OUT, "ho_tinh_tails_%d.glb" % n)
        export(tails, arm, p)
        tris = sum(tri_count(t) for t in tails)
        catalog(p[:-4] + ".json", "ho_tinh_tails_%d" % n, "Fox tails, %d" % n, "features.tail",
                "%d fox tail%s on their own bones, cream by default with a pale tip; any count 1-9 is a free choice." % (n, "" if n == 1 else "s"),
                [{"surface": "fur", "name": t.name} for t in tails],
                [{"zone": 0, "name": "fur", "role": "fur", "fabric": "FUR", "palette": list(FUR), "default": "cream"}],
                tris, {"extension_bones": table, "opens_regions": ["tail_root"]})
        springs = {"fox_tail_%d" % k: {"bones": ["fox_tail_%d_%02d" % (k, j + 1) for j in range(TAIL_BONES)],
                                        "stiffness": [55, 12], "damping": [8, 3], "gravity": 0.35}
                   for k in range(1, n + 1)}
        # the pose layer: per state, each tail's target lift (deg above the bind's droop) and its fan spread
        lay = tail_layout(n)
        pose = {st: [{"tail": k + 1, "lift_deg": lift + 6.0 * (1 - abs(lay[k][1]) / 42.0 if n > 1 else 1.0),
                      "spread_deg": lay[k][1] * fan} for k in range(n)]
                for st, lift, fan in (("idle", 38.0, 1.35), ("walk", 30.0, 1.15), ("run", 12.0, 0.6), ("crouch", 8.0, 1.6),
                                      ("sit", -20.0, 1.9), ("lie", -35.0, 1.2), ("climb", 25.0, 0.7), ("swim", 0.0, 0.4))}
        data["tails"][str(n)] = {"glb": "res://assets/thuyvan/character/fox/ho_tinh_tails_%d.glb" % n, "tris": tris,
                                 "bones": table, "springs": springs, "pose_layer": pose,
                                 "clearance": {"tail_near_camera_fade_m": 0.9}}
        print("FOX_TAILS", n, tris, len(table))
    json.dump(data, open(DATA, "w"), indent=1, ensure_ascii=False)
    print("FOX_DONE")


if __name__ == "__main__":
    main()
