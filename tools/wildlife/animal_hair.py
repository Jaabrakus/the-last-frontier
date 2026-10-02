"""Hair on the smoothed animals (user 2026-10-02: "lets add hairs likes our hair for the humans", and "for the mammoth we
need eyes"): strand cards as the human hair styles are made (thin strips textured with the project's strand atlas,
assets/character/hair/tex/hair_atlas.png, tools/character/hair_atlas.py: root at v 0, tip at v 1, eight styles across),
grown on each animal's skin and written into its glTF as one more skinned mesh ("Hair", material "animal_hair"). Each
card is rooted on the skin, leans out and back along the coat and droops; it takes the colour of the skin at its root
(vertex colour, material colour, texture), so the markings run on into the hair, and the weights of the skin there,
so it moves with the body. Where and how long the hair grows is the animal's rule (RULES: the bison's woolly head,
hump, beard and chaps; the mammoth's long shag; the wolf's ruff; the fox's brush; the deer's short coat). The mammoth
gets eyes ("Eyes", material "animal_eye", on its head bone). scripts/wildlife/animal_hair.gd puts the hair shader on
the "animal_hair" surfaces (assets/wildlife/materials/animal_hair.gdshader).

    python3 tools/wildlife/animal_hair.py [name ...]      (after tools/wildlife/smooth_models.py)

The smoothed copies in assets/wildlife/smooth/ are written over (the hair added to their own mesh data, any earlier
hair replaced); the bison is read from assets/wildlife/bison/bison.glb (tools/wildlife/bison_rig.py) and written to
assets/wildlife/smooth/bison.glb.
"""

import io
import math
import zlib
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import glb_io as IO           # noqa: E402
import glb_space as GS        # noqa: E402

PROJECT = os.path.normpath(os.path.join(HERE, "..", ".."))
SMOOTH = os.path.join(PROJECT, "assets", "wildlife", "smooth")
ATLAS_SLOTS = 8
SEGMENTS = 3


def _bison(fx, fy, fz, ny):
    """(length m, droop 0..1, density 0..1) of the bison's hair at a root, or None."""
    if fz > 0.92 and fy < 0.80:
        return None                                         # the face and muzzle bare (the eyes, the nose)
    if fz > 0.80 and fy < 0.50 and ny < 0.35:
        return 0.30, 1.0, 1.0                               # the beard
    if fz > 0.82:
        return 0.15, 0.55, 1.0                              # the woolly forehead and poll
    if fz > 0.45 and fy > 0.42:
        return 0.10 + 0.12 * fy, 0.6, 1.0                   # the cape over the hump and shoulders
    if 0.50 < fz < 0.80 and 0.17 < fy <= 0.42:
        return 0.16, 1.0, 1.0                               # the chaps on the fore legs
    if fz < 0.06 and 0.25 < fy < 0.65:
        return 0.12, 1.0, 1.0                               # the tail's tuft
    if fy > 0.38:
        return 0.045, 0.3, 0.45                             # the short coat behind the cape
    return None


def _mammoth(fx, fy, fz, ny):
    if fy < 0.10:
        return None
    if fz > 0.80 and fy < 0.62:
        return 0.08, 0.6, 0.6                               # the trunk
    if fy > 0.86:
        return 0.22, 0.7, 1.0                               # the topknot and hump
    return 0.28 + 0.40 * (1.0 - fy), 1.0, 1.0               # the long shag, longest on the flanks' skirt


def _wolf(fx, fy, fz, ny):
    if fy < 0.22:
        return 0.02, 0.2, 0.5                               # the legs
    if 0.62 < fz < 0.86 and fy > 0.40:
        return 0.085, 0.45, 1.0                             # the ruff round the neck and shoulders
    if fz < 0.22 and fy > 0.28:
        return 0.07, 0.35, 1.0                              # the tail
    return 0.045, 0.35, 0.9


def _fox(fx, fy, fz, ny):
    if fy < 0.22:
        return None
    if fz < 0.30 and fy > 0.2:
        return 0.05, 0.3, 1.0                               # the brush
    if 0.62 < fz < 0.84 and fy > 0.40:
        return 0.035, 0.4, 1.0                              # the ruff
    return 0.022, 0.3, 0.8


def _deer(fx, fy, fz, ny):
    if fy < 0.30:
        return None
    if 0.6 < fz < 0.85 and fy > 0.45 and ny < 0.2:
        return 0.04, 0.6, 0.7                               # the throat's longer hair (a buck's mane)
    return 0.016, 0.3, 0.9


# name: source glb, game scale (scene units to metres), cards, card width (m), materials without hair, rule,
# strand styles (atlas slots and their shares), eyes (head joint, eye centre and radius as shares of the head's box)
ANIMALS = {
    "bison": dict(src="assets/wildlife/bison/bison.glb", gs=1.0, cards=2400, width=0.055, skip=(), rule=_bison,
                  slots=((1, 0.45), (3, 0.35), (2, 0.2))),
    "mammoth": dict(src="assets/wildlife/smooth/mammoth.glb", gs=1.2, cards=3200, width=0.09,
                    skip=("Tusk_L", "Tusk_R"), rule=_mammoth, slots=((1, 0.5), (3, 0.3), (7, 0.2)),
                    # (the game warms the model's near-black wool: StandInGiant.WOOL_COLOR, sRGB)
                    recolor={"Wool": (0.5, 0.34, 0.22), "Hide_L": (0.5, 0.34, 0.22), "Hide_R": (0.5, 0.34, 0.22)},
                    eyes=dict(joint="spine.011", at=(0.80, 0.36, 0.74), r=0.05, bare=5.0, lid="Hide_L")),
    # (the short coats denser, finer and close to the skin's colour: sparse cards read as speckles and flakes)
    "wolf": dict(src="assets/wildlife/smooth/wolf.glb", gs=0.43, cards=2600, width=0.022, vary=0.06,
                 skip=("Eyes_Black", "Nose"), rule=_wolf, slots=((1, 0.5), (2, 0.3), (6, 0.2))),
    "fox": dict(src="assets/wildlife/smooth/fox.glb", gs=0.2, cards=2000, width=0.013, vary=0.06,
                skip=("Eyes", "Black"), rule=_fox, slots=((1, 0.5), (2, 0.3), (6, 0.2))),
    # (no hair on the deer and the buck: a sleek summer coat, and short cards read as speckles on it; user
    # 2026-10-02's lineup: the smoothed bodies alone)
}


def _srgb_to_lin(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _texture(j, b, mat):
    t = mat.get("pbrMetallicRoughness", {}).get("baseColorTexture")
    if not t:
        return None
    im = j["images"][j["textures"][t["index"]]["source"]]
    bv = j["bufferViews"][im["bufferView"]]
    data = bytes(b[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]])
    return np.asarray(Image.open(io.BytesIO(data)).convert("RGB"), float) / 255.0


def skin_samples(j, b, mesh_node, skip, recolor=None):
    """The mesh's triangles (scene space) with what the hair needs at their corners: normals, colours (linear),
    joints and weights; and the mesh-to-scene matrix."""
    M = GS.mesh_to_scene(j, IO.accessor, b, mesh_node)
    mesh = j["meshes"][j["nodes"][mesh_node]["mesh"]]
    R = M[:3, :3]
    Rn = np.linalg.inv(R).T
    T, N, C, J, W = [], [], [], [], []
    for pr in mesh["primitives"]:
        mat = j["materials"][pr["material"]] if "material" in pr else {}
        if mat.get("name") in skip:
            continue
        at = pr["attributes"]
        P = IO.accessor(j, b, at["POSITION"]).astype(float)
        Nn = IO.accessor(j, b, at["NORMAL"]).astype(float)
        idx = IO.accessor(j, b, pr["indices"]).reshape(-1, 3)
        P = P @ R.T + M[:3, 3]
        Nn = Nn @ Rn.T
        Nn /= np.linalg.norm(Nn, axis=1)[:, None] + 1e-12
        col = np.ones((len(P), 3)) * np.asarray(mat.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1])[:3])
        if recolor and mat.get("name") in recolor:
            col = np.ones((len(P), 3)) * _srgb_to_lin(recolor[mat["name"]])
        if "COLOR_0" in at:
            col = col * IO.accessor(j, b, at["COLOR_0"])[:, :3]
        tex = _texture(j, b, mat)
        if tex is not None and "TEXCOORD_0" in at:
            uv = IO.accessor(j, b, at["TEXCOORD_0"])
            h, w = tex.shape[:2]
            px = tex[np.clip((uv[:, 1] % 1.0 * h).astype(int), 0, h - 1), np.clip((uv[:, 0] % 1.0 * w).astype(int), 0, w - 1)]
            col = col * _srgb_to_lin(px)
        Jj = IO.accessor(j, b, at["JOINTS_0"]).astype(int) if "JOINTS_0" in at else np.zeros((len(P), 4), int)
        Ww = IO.accessor(j, b, at["WEIGHTS_0"]).astype(float) if "WEIGHTS_0" in at else np.tile([1.0, 0, 0, 0], (len(P), 1))
        T.append(P[idx])
        N.append(Nn[idx])
        C.append(col[idx])
        J.append(Jj[idx])
        W.append(Ww[idx])
    return np.concatenate(T), np.concatenate(N), np.concatenate(C), np.concatenate(J), np.concatenate(W), M


def grow(spec, T, N, C, J, W, rng, bare=()):
    """The cards: vertices (scene space), normals, uv, uv2 (region 0, across 0..1), colours, joints, weights, tris."""
    gs = spec["gs"]
    lo = T.reshape(-1, 3).min(0)
    hi = T.reshape(-1, 3).max(0)
    span = hi - lo
    area = 0.5 * np.linalg.norm(np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0]), axis=1)
    pick = rng.choice(len(T), size=spec["cards"] * 4, p=area / area.sum())
    slots, shares = zip(*spec["slots"])
    shares = np.asarray(shares) / sum(shares)
    V, NO, UV, UV2, CO, JO, WO, TR = [], [], [], [], [], [], [], []
    made = 0
    for ti in pick:
        if made >= spec["cards"]:
            break
        a, bb = rng.random(), rng.random()
        if a + bb > 1:
            a, bb = 1 - a, 1 - bb
        bary = np.array([1 - a - bb, a, bb])
        p = bary @ T[ti]
        if any(np.linalg.norm(p - c) < r for c, r in bare):
            continue
        n = bary @ N[ti]
        n /= np.linalg.norm(n) + 1e-12
        f = (p - lo) / span
        fx, fy, fz = abs(f[0] - 0.5) * 2.0, f[1], f[2]
        r = spec["rule"](fx, fy, fz, n[1])
        if r is None:
            continue
        length, droop, dens = r
        if rng.random() > dens:
            continue
        length = length * (0.75 + 0.5 * rng.random()) / gs
        width = spec["width"] * (0.75 + 0.5 * rng.random()) / gs
        k = int(np.argmax(bary))
        col = bary @ C[ti] * (1.0 + spec.get("vary", 0.12) * (rng.random() - 0.5))
        # the comb: back toward the tail and down, in the skin's plane; out from the skin at the root
        comb = np.array([0.0, -0.8, -0.6]) + rng.normal(0, 0.25, 3)
        comb -= (comb @ n) * n
        comb /= np.linalg.norm(comb) + 1e-12
        d = 0.55 * n + comb
        d /= np.linalg.norm(d)
        side = np.cross(d, n)
        if np.linalg.norm(side) < 1e-6:
            side = np.cross(d, [0.0, 1.0, 0.0])
        side /= np.linalg.norm(side)
        pts = [p - n * 0.15 * width]
        for s in range(SEGMENTS):
            d = d + np.array([0.0, -1.0, 0.0]) * droop * 0.45 * (s + 1) / SEGMENTS
            d /= np.linalg.norm(d)
            pts.append(pts[-1] + d * length / SEGMENTS)
        slot = int(rng.choice(slots, p=shares))
        u0, u1 = slot / ATLAS_SLOTS + 0.004, (slot + 1) / ATLAS_SLOTS - 0.004
        base = len(V)
        for s, q in enumerate(pts):
            w = width * (1.0 - 0.35 * s / SEGMENTS) * 0.5
            for e, sg in ((0, -1.0), (1, 1.0)):
                V.append(q + side * w * sg)
                NO.append(n)
                UV.append((u0 if e == 0 else u1, s / SEGMENTS))
                UV2.append((0.0, float(e)))
                CO.append((col[0], col[1], col[2], 1.0))
                JO.append(J[ti][k])
                WO.append(W[ti][k])
        for s in range(SEGMENTS):
            i0 = base + 2 * s
            TR += [(i0, i0 + 1, i0 + 3), (i0, i0 + 3, i0 + 2)]
        made += 1
    return (np.array(V), np.array(NO), np.array(UV), np.array(UV2), np.array(CO), np.array(JO), np.array(WO),
            np.array(TR, np.uint32), made)


def lids(c, r, sg, n=28, m=8):
    """The eyelids round an eye at c (radius r) on the head's side sg (+x / -x): a tube of skin along an almond
    opening (twice as long as it is high, pointed at the corners, as the horse's), lying over the ball's rim."""
    out = np.array([sg, 0.0, 0.0])
    fwd = np.array([0.0, 0.0, 1.0])
    up = np.array([0.0, 1.0, 0.0])
    tube = 0.26 * r
    rim = []
    for k in range(n):
        t = 2 * math.pi * k / n
        s_ = math.sin(t)
        rim.append(c + out * (0.62 * r) + fwd * (1.30 * r * math.cos(t)) + up * (0.72 * r * math.copysign(abs(s_) ** 0.75, s_)))
    rim = np.array(rim)
    V, N, F = [], [], []
    for k in range(n):
        tg = rim[(k + 1) % n] - rim[k - 1]
        tg /= np.linalg.norm(tg)
        a = out - (out @ tg) * tg
        a /= np.linalg.norm(a)
        bvec = np.cross(tg, a)
        for i in range(m):
            ph = 2 * math.pi * i / m
            d = a * math.cos(ph) + bvec * math.sin(ph)
            V.append(rim[k] + d * tube)
            N.append(d)
    for k in range(n):
        for i in range(m):
            a0 = k * m + i
            a1 = k * m + (i + 1) % m
            b0 = ((k + 1) % n) * m + i
            b1 = ((k + 1) % n) * m + (i + 1) % m
            F += [(a0, a1, b0), (a1, b1, b0)] if sg > 0 else [(a0, b0, a1), (a1, b0, b1)]
    return np.array(V), np.array(F, np.uint32), np.array(N)


def sphere(c, r, n_u=14, n_v=10):
    V, F = [], []
    for i in range(n_v + 1):
        th = math.pi * i / n_v
        for k in range(n_u):
            ph = 2 * math.pi * k / n_u
            V.append(c + r * np.array([math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph)]))
    for i in range(n_v):
        for k in range(n_u):
            a = i * n_u + k
            b2 = i * n_u + (k + 1) % n_u
            F += [(a, b2, a + n_u), (b2, b2 + n_u, a + n_u)]       # (wound outward: the front faces out)
    return np.array(V), np.array(F, np.uint32)


def add_mesh(j, b, name, parent_of, skin, arrays, material):
    """A skinned mesh node beside the body's (same parent, same skin)."""
    if not any(m.get("name") == material["name"] for m in j["materials"]):
        j["materials"].append(material)
    mi = next(i for i, m in enumerate(j["materials"]) if m.get("name") == material["name"])
    at = {}
    V, NO = arrays["POSITION"], arrays["NORMAL"]
    at["POSITION"] = IO.add_accessor(j, b, V, 5126, "VEC3", 34962, minmax=True)
    at["NORMAL"] = IO.add_accessor(j, b, NO, 5126, "VEC3", 34962)
    for nm, typ in (("TEXCOORD_0", "VEC2"), ("TEXCOORD_1", "VEC2"), ("COLOR_0", "VEC4")):
        if nm in arrays:
            at[nm] = IO.add_accessor(j, b, arrays[nm], 5126, typ, 34962)
    if skin is not None:
        at["JOINTS_0"] = IO.add_accessor(j, b, arrays["JOINTS_0"], 5123, "VEC4", 34962)
        at["WEIGHTS_0"] = IO.add_accessor(j, b, arrays["WEIGHTS_0"], 5126, "VEC4", 34962)
    ind = IO.add_accessor(j, b, arrays["indices"].reshape(-1, 1), 5125, "SCALAR", 34963)
    j["meshes"].append({"name": name, "primitives": [{"attributes": at, "indices": ind, "material": mi}]})
    node = {"name": name, "mesh": len(j["meshes"]) - 1}
    if skin is not None:
        node["skin"] = skin
    j["nodes"].append(node)
    ni = len(j["nodes"]) - 1
    if parent_of is None:
        for sc in j["scenes"]:
            sc["nodes"].append(ni)
    else:
        j["nodes"][parent_of].setdefault("children", []).append(ni)
    return ni


def drop_added(j):
    """An earlier run's hair and eyes taken out (their nodes and meshes), so a rerun replaces them."""
    gone = {i for i, n in enumerate(j["nodes"]) if n.get("name") in ("Hair", "Eyes", "Eyelids")}
    if not gone:
        return
    for n in j["nodes"]:
        if "children" in n:
            n["children"] = [c for c in n["children"] if c not in gone]
    for sc in j["scenes"]:
        sc["nodes"] = [c for c in sc["nodes"] if c not in gone]
    # (nodes are referenced by index everywhere: the dropped ones are left as empty nodes, harmless)
    for i in gone:
        j["nodes"][i] = {"name": "_dropped"}


def ray_x(T, o, d):
    """The x of each point where the ray o + t d meets one of the triangles T (Moller-Trumbore)."""
    e1 = T[:, 1] - T[:, 0]
    e2 = T[:, 2] - T[:, 0]
    pv = np.cross(d, e2)
    det = (e1 * pv).sum(1)
    ok = np.abs(det) > 1e-12
    inv = np.where(ok, 1.0 / np.where(ok, det, 1.0), 0.0)
    tv = o - T[:, 0]
    u = (tv * pv).sum(1) * inv
    qv = np.cross(tv, e1)
    v = (qv @ d) * inv
    t = (e2 * qv).sum(1) * inv
    hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0)
    return (o + t[hit, None] * d)[:, 0]


def place_eyes(j, spec, skin, T, J, W):
    """The eyes (scene space centres, and the joints and weights of the skin at each): on the head bone's part of the
    skin, at the spec's height and length shares of it, its front under the lids (the horse's: the ball set in, not bulging). They take the skin's
    own weights there (the head's skin is shared with the neck's bones: on the head bone alone they sank under the skin
    as the neck moved)."""
    ey = spec["eyes"]
    names = [j["nodes"][k]["name"] for k in j["skins"][skin]["joints"]]
    hj = names.index(ey["joint"])
    P = T.reshape(-1, 3)
    head = P[((J.reshape(-1, 4) == hj) & (W.reshape(-1, 4) > 0.5)).any(1)]
    hlo, hhi = head.min(0), head.max(0)
    y = hlo[1] + ey["at"][1] * (hhi[1] - hlo[1])
    z = hlo[2] + ey["at"][2] * (hhi[2] - hlo[2])
    r = ey["r"] / spec["gs"]
    out = []
    for sg in (1.0, -1.0):
        # the skin's side there: a ray in from outside along -x (+x on the right) to the outermost triangle it meets
        xs = ray_x(T, np.array([sg * 10.0, y, z]), np.array([-sg, 0.0, 0.0]))
        x = sg * (np.abs(xs).max() if len(xs) else ey["at"][0] * hhi[0]) - sg * r * 0.05
        c = np.array([x, y, z])
        k = int(np.argmin(np.linalg.norm(P - c, axis=1)))
        out.append((c, J.reshape(-1, 4)[k], W.reshape(-1, 4)[k]))
    return out


def one(name, spec, rng):
    j, b = IO.read_glb(os.path.join(PROJECT, spec["src"]))
    drop_added(j)
    # the body: the largest mesh (the stag's antlers are a mesh of their own)
    cands = [i for i, n in enumerate(j["nodes"]) if "mesh" in n and n.get("name") not in ("Hair", "Eyes", "Eyelids", "_dropped")]
    body = max(cands, key=lambda i: sum(j["accessors"][pr["attributes"]["POSITION"]]["count"]
                                        for pr in j["meshes"][j["nodes"][i]["mesh"]]["primitives"]))
    parent = next((i for i, n in enumerate(j["nodes"]) if body in n.get("children", [])), None)
    skin = j["nodes"][body].get("skin")
    T, N, C, J, W, M = skin_samples(j, b, body, spec["skip"], spec.get("recolor"))
    Mi = np.linalg.inv(M)
    Rt = M[:3, :3].T
    eyes = place_eyes(j, spec, skin, T, J, W) if spec.get("eyes") else []
    bare = [(c, spec["eyes"]["bare"] * spec["eyes"]["r"] / spec["gs"]) for c, _j, _w in eyes]
    V, NO, UV, UV2, CO, JO, WO, TR, made = grow(spec, T, N, C, J, W, rng, bare)
    arrays = {"POSITION": (V @ Mi[:3, :3].T + Mi[:3, 3]).astype(np.float32),
              "NORMAL": (lambda q: (q / np.linalg.norm(q, axis=1)[:, None]).astype(np.float32))(NO @ Rt.T),
              "TEXCOORD_0": UV.astype(np.float32), "TEXCOORD_1": UV2.astype(np.float32), "COLOR_0": CO.astype(np.float32),
              "JOINTS_0": JO.astype(np.uint16), "WEIGHTS_0": (WO / WO.sum(1)[:, None]).astype(np.float32), "indices": TR}
    add_mesh(j, b, "Hair", parent, skin, arrays,
             {"name": "animal_hair", "doubleSided": True, "alphaMode": "MASK", "alphaCutoff": 0.4,
              "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 0.85}})
    out = "%d cards, %d triangles" % (made, len(TR))
    if eyes:
        ey = spec["eyes"]
        Vs, Fs, Ns, Js, Ws, Us = [], [], [], [], [], []
        Lv, Lf, Ln, Lj, Lw = [], [], [], [], []
        r = ey["r"] / spec["gs"]
        for (c, ej, ew), sg in zip(eyes, (1.0, -1.0)):
            sv, sf = sphere(c, r)
            nn = (sv - c) / np.linalg.norm(sv - c, axis=1)[:, None]
            Fs.append(sf + sum(len(v) for v in Vs))
            Vs.append(sv)
            Ns.append(nn)
            # the eyeball's frame for animal_eye.gdshader: how far each point faces out of the head, its height
            Us.append(np.stack([nn[:, 0] * sg, nn[:, 1]], 1))
            Js.append(np.tile(ej, (len(sv), 1)))
            Ws.append(np.tile(ew / ew.sum(), (len(sv), 1)))
            lv, lf, ln = lids(c, r, sg)
            Lf.append(lf + sum(len(v) for v in Lv))
            Lv.append(lv)
            Ln.append(ln)
            Lj.append(np.tile(ej, (len(lv), 1)))
            Lw.append(np.tile(ew / ew.sum(), (len(lv), 1)))
        V = np.concatenate(Vs)
        NO = np.concatenate(Ns)
        arrays = {"POSITION": (V @ Mi[:3, :3].T + Mi[:3, 3]).astype(np.float32),
                  "NORMAL": (lambda q: (q / np.linalg.norm(q, axis=1)[:, None]).astype(np.float32))(NO @ Rt.T),
                  "TEXCOORD_0": np.concatenate(Us).astype(np.float32),
                  "JOINTS_0": np.concatenate(Js).astype(np.uint16),
                  "WEIGHTS_0": np.concatenate(Ws).astype(np.float32),
                  "indices": np.concatenate(Fs)}
        add_mesh(j, b, "Eyes", parent, skin, arrays,
                 {"name": "animal_eye", "pbrMetallicRoughness": {"baseColorFactor": [0.03, 0.02, 0.015, 1.0],
                                                                  "metallicFactor": 0.0, "roughnessFactor": 0.55}})
        V = np.concatenate(Lv)
        NO = np.concatenate(Ln)
        lid_mat = next(m for m in j["materials"] if m.get("name") == ey["lid"])
        arrays = {"POSITION": (V @ Mi[:3, :3].T + Mi[:3, 3]).astype(np.float32),
                  "NORMAL": (lambda q: (q / np.linalg.norm(q, axis=1)[:, None]).astype(np.float32))(NO @ Rt.T),
                  "JOINTS_0": np.concatenate(Lj).astype(np.uint16),
                  "WEIGHTS_0": np.concatenate(Lw).astype(np.float32),
                  "indices": np.concatenate(Lf)}
        add_mesh(j, b, "Eyelids", parent, skin, arrays, lid_mat)
        out += ", eyes on %s" % ey["joint"]
    nb = IO.compact(j, b)
    dst = os.path.join(SMOOTH, name + ".glb")
    IO.write_glb(dst, j, nb)
    print("HAIR %s: %s -> %s (%.2f MB)" % (name, out, os.path.relpath(dst, PROJECT), os.path.getsize(dst) / 1e6))


def main():
    only = set(sys.argv[1:])
    for name, spec in ANIMALS.items():
        if only and name not in only:
            continue
        one(name, spec, np.random.default_rng(zlib.crc32(name.encode())))


if __name__ == "__main__":
    main()
