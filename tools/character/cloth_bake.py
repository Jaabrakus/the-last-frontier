"""Cloth attributes for the cloth shader (assets/character/shaders/cloth.gdshader), written into
the character glbs after they are built (plain python3 + numpy; no Blender):

    python3 tools/character/cloth_bake.py legacy      # assets/character/actor_b_body.glb
    python3 tools/character/cloth_bake.py garments    # every assets/character/garments/*/*.glb
    python3 tools/character/cloth_bake.py all
    then: Godot --headless --path . --import

build_body.sh and build_character.sh run it after Blender. It is idempotent: the attributes it
writes are recomputed from the geometry every time.

Legacy outfit (actor_b_body.glb: Clothes, Gear, Hat; the Body, Face and Hair meshes the
customizer head replaces are left alone). It was built without UVs; this adds, per vertex:
  TEXCOORD_0 -> UV       grain-aligned metres (customizer design 8.4): the torso and coat
                         skirt around the body's vertical axis (seam at the centre back),
                         sleeves around the shoulder -> wrist axis (seam under the arm),
                         breeches, leggings and garters around the leg (breeches: seams at the
                         centre front and back; leggings: on the outside, where the flap is),
                         shoes, brass, pouch, horn, straps and the hat by a box projection per
                         face. Vertices on a seam are split (positions, weights and colours
                         are copied: the geometry and the skinning do not change).
  TEXCOORD_1 -> UV2      x = legacy piece code (LEGACY_PIECES; the shader's hide_mask hides
                         pieces an equipped garment replaces: the coat and its buttons under a
                         fur coat, the shoes and buckles in moccasins), y = 1.
  TEXCOORD_2 -> CUSTOM0.xy  distance (m) along the surface to the nearest open edge (hem, cuff,
                         front opening, collar), twice (the garments' d_hem, d_open).
  TANGENT (Gear only)    for the rigid pieces (pouch, horn): the direction the piece moves out
                         when a thicker coat is worn under it (skinned with the piece).
Every character garment glb (and the legacy outfit) also gets:
  TEXCOORD_3 -> CUSTOM0.zw  (dirt, wear): ground dirt rising from the feet, mud on low hems,
                         kneeling dirt on the knees, grime on cuffs; wear on the elbows, knees,
                         seat, the shoulders under straps and along every open edge.
  TEXCOORD_4 -> CUSTOM1.xy  (sweat, push class): sweat at the armpits, the collar, between the
                         shoulder blades, under the belt and in the hat band; push class for the
                         legacy Gear (0 none, 1..2 belt -> strap blend along the strap, 3 rigid:
                         along TANGENT), 0 for garments.
  TEXCOORD_5 -> CUSTOM1.zw  (seam distance m, 0): distance to the sewn seams; 0.2 = none. Legacy:
                         signed (legacy_seam_field: a smooth line); garments: geodesic from their
                         UV seams, which the lib places where the garments are sewn.
  TEXCOORD_6 -> CUSTOM2.xy  (cavity, folds): signed curvature (-1 ridge .. +1 fold valley; the
                         shader shades valleys and wears ridges) and where compression folds form
                         (elbows, knees, armpits, cuffs, ankles, the waist under the belt).
Garments without TEXCOORD_2 get the open-edge distance there too.

All masks are functions of the bind position, normal and the Actor_B joints at the bind pose
(from the glb skin's inverse binds), so they are the same for both body fits and never swim.
Joint positions and the glb conventions: glTF space = Godot skeleton space (+Y up, the
character faces +Z, its left is +X).
"""

import glob
import heapq
import json
import os
import struct
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
LEGACY = os.path.join(ROOT, "assets", "character", "actor_b_body.glb")
GARMENTS = os.path.join(ROOT, "assets", "character", "garments")

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
CT_OF = {np.dtype(v): k for k, v in CT.items()}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
TYPE_OF = {1: "SCALAR", 2: "VEC2", 3: "VEC3", 4: "VEC4", 16: "MAT4"}

# Legacy piece codes (UV2.x). Brass fittings take 16 + the code of the piece they sit on.
LEGACY_PIECES = {
    "coat": 1, "waistcoat": 2, "linen_stock": 3, "linen_cuffs": 4, "breeches": 5, "leggings": 6, "garter": 7,
    "shoe": 8, "belt": 40, "strap": 41, "pouch": 42, "horn": 43, "gear_brass": 44, "wood": 45, "horn_tip": 46,
    "felt": 50, "hat_tape": 51, "hat_brass": 52,
}
BRASS_BASE = 16
LEGACY_MESHES = ("Clothes", "Gear", "Hat")
# surfaces whose UV seams are sewn seams (box-projected pieces split everywhere: no seam lines)
SEAMED = ("coat", "waistcoat", "linen", "breeches", "leggings")
SEAMED_SLOTS = ("outer", "vest", "shirt", "legs.lower", "legs.over", "accessories.wrap")


# ---------------------------------------------------------------------------------------------
# glb in / out
# ---------------------------------------------------------------------------------------------
class Glb:
    """A glb whose accessors are numpy arrays; write() re-serializes every accessor."""

    def __init__(self, path):
        self.path = path
        b = open(path, "rb").read()
        assert b[:4] == b"glTF", path
        jl = struct.unpack("<I", b[12:16])[0]
        self.j = json.loads(b[20:20 + jl])
        o = 20 + jl
        bl = struct.unpack("<I", b[o:o + 4])[0]
        binary = b[o + 8:o + 8 + bl]
        assert not self.j.get("images"), "glbs with images are not supported"
        self.arrays = []
        for a in self.j["accessors"]:
            dt = np.dtype(CT[a["componentType"]])
            n = NC[a["type"]]
            if "bufferView" in a:
                arr = self._view(binary, a["bufferView"], a.get("byteOffset", 0), dt, n, a["count"])
            else:
                arr = np.zeros((a["count"], n), dt)
            sp = a.pop("sparse", None)
            if sp:
                # sparse (Blender writes morph target deltas this way): made dense
                idt = np.dtype(CT[sp["indices"]["componentType"]])
                idx = self._view(binary, sp["indices"]["bufferView"], sp["indices"].get("byteOffset", 0), idt, 1,
                                 sp["count"]).ravel()
                val = self._view(binary, sp["values"]["bufferView"], sp["values"].get("byteOffset", 0), dt, n, sp["count"])
                arr[idx.astype(np.int64)] = val
            self.arrays.append(arr)

    def _view(self, binary, v, extra_off, dt, n, count):
        bv = self.j["bufferViews"][v]
        off = bv.get("byteOffset", 0) + extra_off
        stride = bv.get("byteStride", 0)
        if stride and stride != dt.itemsize * n:
            raw = np.frombuffer(binary, np.uint8, count=stride * count, offset=off).reshape(count, stride)
            return raw[:, :dt.itemsize * n].copy().view(dt).reshape(count, n)
        return np.frombuffer(binary, dt, count=count * n, offset=off).reshape(count, n).copy()

    def get(self, i):
        """Accessor i as float64 (normalized integers mapped to 0..1)."""
        a = self.j["accessors"][i]
        arr = self.arrays[i]
        if a.get("normalized") and arr.dtype != np.float32:
            return arr.astype(np.float64) / float(np.iinfo(arr.dtype).max)
        return arr.astype(np.float64)

    def set(self, i, arr):
        self.arrays[i] = arr
        self.j["accessors"][i]["count"] = int(arr.shape[0])

    def add(self, arr, normalized=False):
        """Appends an accessor (float32 or an integer array) and returns its index."""
        arr = np.ascontiguousarray(arr)
        if arr.ndim == 1:
            arr = arr[:, None]
        acc = {"bufferView": 0, "componentType": CT_OF[arr.dtype], "count": int(arr.shape[0]),
               "type": TYPE_OF[arr.shape[1]]}
        if normalized:
            acc["normalized"] = True
        self.j["accessors"].append(acc)
        self.arrays.append(arr)
        return len(self.j["accessors"]) - 1

    def write(self, path=None):
        path = path or self.path
        chunks, views = [], []
        off = 0
        index_accs = set()
        for m in self.j["meshes"]:
            for pr in m["primitives"]:
                if "indices" in pr:
                    index_accs.add(pr["indices"])
        for i, (a, arr) in enumerate(zip(self.j["accessors"], self.arrays)):
            data = np.ascontiguousarray(arr).tobytes()
            view = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
            if i in index_accs:
                view["target"] = 34963
            elif a["type"] != "MAT4":
                view["target"] = 34962
            views.append(view)
            a["bufferView"] = i
            a.pop("byteOffset", None)
            a["count"] = int(arr.shape[0])
            pad = (-len(data)) % 4
            chunks.append(data + b"\0" * pad)
            off += len(data) + pad
        self.j["bufferViews"] = views
        self.j["buffers"] = [{"byteLength": off}]
        # POSITION accessors need min / max
        for m in self.j["meshes"]:
            for pr in m["primitives"]:
                for key in [pr["attributes"].get("POSITION")] + [t.get("POSITION") for t in pr.get("targets", [])]:
                    if key is not None:
                        P = self.arrays[key]
                        self.j["accessors"][key]["min"] = [float(x) for x in P.min(0)]
                        self.j["accessors"][key]["max"] = [float(x) for x in P.max(0)]
        # drop accessors nothing references any more
        self._compact()
        js = json.dumps(self.j, separators=(",", ":")).encode()
        js += b" " * ((-len(js)) % 4)
        binary = b"".join(chunks)
        total = 12 + 8 + len(js) + 8 + len(binary)
        with open(path, "wb") as f:
            f.write(struct.pack("<4sII", b"glTF", 2, total))
            f.write(struct.pack("<II", len(js), 0x4E4F534A))
            f.write(js)
            f.write(struct.pack("<II", len(binary), 0x004E4942))
            f.write(binary)

    def _compact(self):
        used = set()
        for m in self.j["meshes"]:
            for pr in m["primitives"]:
                used.update(pr["attributes"].values())
                if "indices" in pr:
                    used.add(pr["indices"])
                for t in pr.get("targets", []):
                    used.update(t.values())
        for s in self.j.get("skins", []):
            if "inverseBindMatrices" in s:
                used.add(s["inverseBindMatrices"])
        for an in self.j.get("animations", []):
            for smp in an["samplers"]:
                used.update([smp["input"], smp["output"]])
        if len(used) == len(self.j["accessors"]):
            return
        # rebuild with only the used accessors (and rewrite; bufferViews are 1:1 with accessors)
        order = sorted(used)
        remap = {old: new for new, old in enumerate(order)}
        self.j["accessors"] = [self.j["accessors"][i] for i in order]
        self.arrays = [self.arrays[i] for i in order]
        self.j["bufferViews"] = [self.j["bufferViews"][i] for i in order]
        for new, a in enumerate(self.j["accessors"]):
            a["bufferView"] = new
        for m in self.j["meshes"]:
            for pr in m["primitives"]:
                pr["attributes"] = {k: remap[v] for k, v in pr["attributes"].items()}
                if "indices" in pr:
                    pr["indices"] = remap[pr["indices"]]
                pr["targets"] = [{k: remap[v] for k, v in t.items()} for t in pr.get("targets", [])]
                if not pr["targets"]:
                    pr.pop("targets")
        for s in self.j.get("skins", []):
            if "inverseBindMatrices" in s:
                s["inverseBindMatrices"] = remap[s["inverseBindMatrices"]]
        for an in self.j.get("animations", []):
            for smp in an["samplers"]:
                smp["input"], smp["output"] = remap[smp["input"]], remap[smp["output"]]
        # the byte offsets changed: serialize again from the arrays
        off = 0
        for v, arr in zip(self.j["bufferViews"], self.arrays):
            n = len(np.ascontiguousarray(arr).tobytes())
            v["byteOffset"] = off
            v["byteLength"] = n
            off += n + ((-n) % 4)
        self.j["buffers"] = [{"byteLength": off}]

    def joints(self):
        """{joint name: bind position (glb space)} of the first skin."""
        sk = self.j["skins"][0]
        M = self.get(sk["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
        out = {}
        for n, m in zip(sk["joints"], M):
            out[self.j["nodes"][n]["name"]] = np.linalg.inv(m)[:3, 3]
        return out

    def joint_names(self):
        sk = self.j["skins"][0]
        return [self.j["nodes"][n]["name"] for n in sk["joints"]]

    def material_name(self, pr):
        return self.j["materials"][pr["material"]]["name"] if "material" in pr else ""


# ---------------------------------------------------------------------------------------------
# geometry helpers
# ---------------------------------------------------------------------------------------------
def smoothstep(a, b, x):
    t = np.clip((np.asarray(x, float) - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def nrm(v):
    v = np.asarray(v, float)
    return v / max(np.linalg.norm(v), 1e-12)


def weld_ids(P, tol=1e-5):
    """Welded vertex id per vertex (same position within tol)."""
    key = np.round(P / tol).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    return inv.ravel()


def _graph(P, T):
    """Position-welded mesh: (welded id per vertex, welded positions, unique edges, edge use count,
    adjacency lists)."""
    wid = weld_ids(P)
    nw = wid.max() + 1 if len(wid) else 0
    Pw = np.zeros((nw, 3))
    Pw[wid] = P
    Tw = wid[T]
    E = np.sort(np.concatenate([Tw[:, [0, 1]], Tw[:, [1, 2]], Tw[:, [2, 0]]]), axis=1)
    E = E[E[:, 0] != E[:, 1]]
    ue, cnt = np.unique(E, axis=0, return_counts=True)
    adj = [[] for _ in range(nw)]
    L = np.linalg.norm(Pw[ue[:, 0]] - Pw[ue[:, 1]], axis=1)
    for (a, b), l in zip(ue, L):
        adj[a].append((b, l))
        adj[b].append((a, l))
    return wid, Pw, ue, cnt, adj


def _dijkstra(adj, sources, cap):
    d = np.full(len(adj), cap)
    h = []
    for v in sources:
        d[v] = 0.0
        h.append((0.0, int(v)))
    heapq.heapify(h)
    while h:
        dv, v = heapq.heappop(h)
        if dv > d[v]:
            continue
        for u, l in adj[v]:
            nd = dv + l
            if nd < d[u]:
                d[u] = nd
                heapq.heappush(h, (nd, u))
    return d


def edge_distance(P, T, cap=0.4):
    """Geodesic (along mesh edges) distance of every vertex to the nearest open edge (an edge of
    one triangle only, on the position-welded mesh: seams and normal splits are not edges)."""
    wid, Pw, ue, cnt, adj = _graph(P, T)
    open_v = np.unique(ue[cnt == 1].ravel())
    return _dijkstra(adj, open_v, cap)[wid]


def seam_distance(P, T, UV, extra=None, cap=0.2):
    """Geodesic distance to the construction seams: where one position carries two UVs (the UV
    seams are placed where garments are sewn: centre back, underarm, armhole, inseam, the
    leggings' outside seam), plus `extra` (bool per vertex, e.g. the coat's side seams)."""
    wid, Pw, ue, cnt, adj = _graph(P, T)
    key = np.round(UV, 5)
    first = {}
    seam = np.zeros(len(adj), bool)
    for v, w in enumerate(wid):
        k = (key[v, 0], key[v, 1])
        if w in first:
            if first[w] != k:
                seam[w] = True
        else:
            first[w] = k
    if extra is not None:
        seam[wid[extra]] = True
    src = np.flatnonzero(seam)
    if len(src) == 0:
        return np.full(len(P), cap)
    return _dijkstra(adj, src, cap)[wid]


def islands(P, T):
    """Connected component id per vertex (position-welded)."""
    wid = weld_ids(P)
    parent = np.arange(wid.max() + 1)

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    for t in wid[T]:
        a = find(t[0])
        for b in t[1:]:
            b = find(b)
            if a != b:
                parent[b] = a
    root = np.array([find(x) for x in range(len(parent))])
    _, comp = np.unique(root, return_inverse=True)
    return comp[wid]


# ---------------------------------------------------------------------------------------------
# masks: dirt, wear, sweat (0..1 per vertex)
# ---------------------------------------------------------------------------------------------
def gauss(P, c, r):
    return np.exp(-((np.linalg.norm(P - c, axis=1) / r) ** 2))


def masks(P, N, K, d_edge, kind):
    """(dirt, wear, sweat) per vertex. kind: 'cloth', 'leather', 'hat', 'metal', 'fur'."""
    y = P[:, 1]
    n = len(P)
    dirt = np.zeros(n)
    wear = np.zeros(n)
    sweat = np.zeros(n)
    edge = 1.0 - smoothstep(0.0, 0.018, d_edge)
    # ground: dust and mud rise from the feet (strong on shoes, fading by the knee)
    ground = (1.0 - smoothstep(0.02, 0.42, y)) ** 1.6
    dirt += 0.8 * ground
    # mud on low hems (skirts, legging bottoms), a little on every low edge
    dirt += 0.45 * (1.0 - smoothstep(0.0, 0.05, d_edge)) * (1.0 - smoothstep(0.30, 0.75, y))
    for s in "lr":
        knee, hip, elb, wri, sho = (K.get(s + "_knee"), K.get(s + "_upper_leg"), K.get(s + "_elbow"),
                                    K.get(s + "_wrist"), K.get(s + "_shoulder"))
        if knee is not None:
            front = np.clip(N[:, 2] * 1.6, 0.0, 1.0)
            kf = gauss(P, knee + np.array([0.0, 0.0, 0.07]), 0.075)
            dirt += 0.4 * kf * front                       # kneeling
            wear += 0.75 * gauss(P, knee + np.array([0.0, 0.02, 0.06]), 0.065) * front
        if elb is not None:
            back = np.clip(-N[:, 2] * 1.4 + 0.2, 0.0, 1.0)
            wear += 0.85 * gauss(P, elb + np.array([0.0, 0.0, -0.045]), 0.06) * back
        if wri is not None:
            dirt += 0.45 * gauss(P, wri, 0.07)             # grime at the cuffs
            wear += 0.25 * gauss(P, wri, 0.05)
        if sho is not None:
            top = np.clip(N[:, 1] * 1.5, 0.0, 1.0)
            wear += 0.45 * gauss(P, sho + np.array([-0.02 if s == "l" else 0.02, 0.06, 0.0]), 0.07) * top
            pit = sho + np.array([(-0.02 if s == "l" else 0.02), -0.085, -0.005])
            sweat += 0.85 * gauss(P, pit, 0.065)          # armpits
        if hip is not None:
            seat = np.clip(-N[:, 2] * 1.5, 0.0, 1.0)
            c = hip + np.array([0.0, -0.01, -0.10])
            wear += 0.4 * gauss(P, c, 0.09) * seat
            dirt += 0.3 * gauss(P, c + np.array([0.0, -0.05, 0.0]), 0.08) * seat
    neck = K.get("neck")
    if neck is not None:
        r = np.hypot(P[:, 0] - neck[0], P[:, 2] - neck[2])
        sweat += 0.7 * np.exp(-((y - (neck[1] + 0.02)) / 0.03) ** 2) * (1.0 - smoothstep(0.07, 0.095, r))
    spd = K.get("spined")
    if spd is not None:
        sweat += 0.25 * gauss(P, spd + np.array([0.0, 0.02, -0.13]), 0.075)
    spa = K.get("spinea")
    if spa is not None:
        sweat += 0.2 * np.exp(-((y - spa[1] - 0.005) / 0.035) ** 2)   # under the belt
    wear += 0.8 * edge
    if kind == "hat":
        head = K.get("headb")
        if head is not None:
            r = np.linalg.norm(P - head, axis=1)
            sweat = 0.7 * np.exp(-((y - (head[1] + 0.10)) / 0.03) ** 2) * (r < 0.14)
        dirt = 0.15 * edge
        wear = 0.9 * edge
    if kind == "metal":
        sweat[:] = 0.0
    if kind == "fur":
        sweat[:] = 0.0
        wear *= 0.5
    return np.clip(dirt, 0, 1), np.clip(wear, 0, 1), np.clip(sweat, 0, 1)


def cavity(P, N, T, smooth=3):
    """Signed curvature per vertex (-1 ridge .. +1 fold valley) from the umbrella Laplacian on the
    position-welded mesh along the vertex normal, scaled by the local edge length and smoothed."""
    wid, Pw, ue, cnt, adj = _graph(P, T)
    nw = len(adj)
    Nw = np.zeros((nw, 3))
    np.add.at(Nw, wid, N)
    Nw /= np.maximum(np.linalg.norm(Nw, axis=1, keepdims=True), 1e-9)
    c = np.zeros(nw)
    for v in range(nw):
        if not adj[v]:
            continue
        nb = np.array([u for u, _ in adj[v]])
        el = np.mean([l for _, l in adj[v]])
        lap = Pw[nb].mean(0) - Pw[v]
        c[v] = (lap @ Nw[v]) / max(el, 1e-4)
    def relax(x, n):
        for _ in range(n):
            x2 = x.copy()
            for v in range(nw):
                if adj[v]:
                    x2[v] = 0.5 * x[v] + 0.5 * np.mean([x[u] for u, _ in adj[v]])
            x = x2
        return x
    c = relax(c, smooth)
    # local folds and ridges only: the limb's own roundness (large-scale convexity) is removed
    c = c - relax(c, 30)
    open_v = np.unique(ue[cnt == 1].ravel())
    c[open_v] *= 0.3                              # open edges read as ridges: keep them neutral
    sd = np.std(c) if len(c) else 1.0
    return np.clip(c / max(2.0 * sd, 1e-6), -1.0, 1.0)[wid]


def folds(P, N, K, kind):
    """Where cloth bunches into compression folds (0..1): the crook of the elbow and the forearm
    above the cuff, the armpit, behind and over the knee, the ankle, the waist under the belt and
    the front of the hip."""
    if kind not in ("cloth", "fur"):
        return np.zeros(len(P))
    f = np.zeros(len(P))
    for s in "lr":
        elb, wri, sho, knee, ank, hip = (K.get(s + "_elbow"), K.get(s + "_wrist"), K.get(s + "_shoulder"),
                                         K.get(s + "_knee"), K.get(s + "_ankle"), K.get(s + "_upper_leg"))
        if elb is not None:
            f += 0.9 * gauss(P, elb, 0.075)
        if wri is not None and elb is not None:
            f += 0.6 * gauss(P, elb + (wri - elb) * 0.75, 0.06)
        if sho is not None:
            f += 0.5 * gauss(P, sho + np.array([(-0.02 if s == "l" else 0.02), -0.09, 0.0]), 0.06)
        if knee is not None:
            f += 0.9 * gauss(P, knee, 0.085)
        if ank is not None:
            f += 0.5 * gauss(P, ank + np.array([0.0, 0.07, 0.0]), 0.06)
        if hip is not None:
            f += 0.4 * gauss(P, hip + np.array([0.0, 0.0, 0.08]), 0.07)
    spa = K.get("spinea")
    if spa is not None:
        f += 0.6 * np.exp(-((P[:, 1] - spa[1] - 0.01) / 0.04) ** 2) * (np.hypot(P[:, 0], P[:, 2] - spa[2]) < 0.25)
    return np.clip(f, 0.0, 1.0)


# ---------------------------------------------------------------------------------------------
# legacy UVs
# ---------------------------------------------------------------------------------------------
ARM_BONES = ("shoulder", "elbow", "wrist", "palm", "forarm_twist", "shoulder_twist", "hand", "finger", "thumb",
             "index", "middle", "ring", "pinky")
LEG_BONES = ("upper_leg", "knee", "ankle", "heel", "ball", "toe")
SKIRT_HELPERS = ("upper_leg_front_helper", "upper_leg_thigh_helper", "upper_leg_rear_helper")


def limb_share(names, J, W, side, kind):
    bones = ARM_BONES if kind == "arm" else LEG_BONES
    sel = np.zeros(len(names), bool)
    for i, nm in enumerate(names):
        if not nm.startswith(side + "_"):
            continue
        rest = nm[2:]
        if any(rest.startswith(h) for h in SKIRT_HELPERS):
            continue
        if kind == "arm" and rest.startswith("clavicle"):
            continue
        if any(rest.startswith(b) for b in bones):
            sel[i] = True
    return (W * sel[J]).sum(1)


class Cyl:
    """Cylindrical grain UV around an axis a -> b: u = angle x ring radius (m, 0 at the seam
    direction), v = distance along the axis (m)."""

    def __init__(self, a, b, seam_dir, radius=None):
        self.a = np.asarray(a, float)
        self.ax = nrm(np.asarray(b, float) - self.a)
        s = np.asarray(seam_dir, float)
        s = s - self.ax * (s @ self.ax)
        self.e1 = nrm(s)
        self.e2 = np.cross(self.ax, self.e1)
        self.radius = radius

    def angle_v_r(self, P):
        d = P - self.a
        v = d @ self.ax
        x, y = d @ self.e1, d @ self.e2
        ang = np.arctan2(y, x) % (2 * np.pi)          # 0 at the seam
        return ang, v, np.hypot(x, y)


def ring_radius(v, r, bins=0.02, smooth=4):
    """Median radius of the rings along the axis, smoothed and interpolated per vertex: u = angle
    x this keeps the grain straight along the axis where the garment flares. It must be smooth
    in v: a step between rings skews the UVs of the triangles across it (and with them the
    normal map's frame: the cloth showed banded blotches)."""
    k = np.floor(v / bins).astype(int)
    ks = np.arange(k.min(), k.max() + 1)
    med = np.full(len(ks), np.nan)
    for i, kk in enumerate(ks):
        m = k == kk
        if m.any():
            med[i] = np.median(r[m])
    ok = ~np.isnan(med)
    med = np.interp(np.arange(len(ks)), np.flatnonzero(ok), med[ok])
    ker = np.ones(2 * smooth + 1) / (2 * smooth + 1)
    med = np.convolve(np.pad(med, smooth, mode="edge"), ker, mode="valid")
    return np.interp(v, (ks + 0.5) * bins, med)


def box_uv(P, Nt):
    """Box projection by the dominant axis of the triangle normal (one per corner)."""
    ax = np.argmax(np.abs(Nt), axis=1)
    sg = np.sign(Nt[np.arange(len(Nt)), ax])
    uv = np.zeros((len(P), 2))
    m = ax == 0
    uv[m] = np.stack([P[m, 2] * sg[m], P[m, 1]], 1)
    m = ax == 1
    uv[m] = np.stack([P[m, 0], P[m, 2] * sg[m]], 1)
    m = ax == 2
    uv[m] = np.stack([-P[m, 0] * sg[m], P[m, 1]], 1)
    return uv


def legacy_cylinders(K, mat):
    pelvis, neck = K["pelvis"], K["neck"]
    torso = Cyl((0.0, pelvis[1], pelvis[2]), (0.0, neck[1], neck[2]), (0.0, 0.0, -1.0))   # seam at the centre back
    cyls = {"torso": torso}
    for s, sx in (("l", 1.0), ("r", -1.0)):
        sho, wri = K[s + "_shoulder"], K[s + "_wrist"]
        # sleeve seam under the arm: toward the body and down
        cyls["arm_" + s] = Cyl(sho, wri, (-sx, -0.6, 0.0))
        hip, knee, ank = K[s + "_upper_leg"], K[s + "_knee"], K[s + "_ankle"]
        if mat == "breeches":
            cyls["leg_" + s] = Cyl(hip, knee, (-sx, 0.0, 0.0))     # inseam side (the centre seams split too)
        else:
            cyls["leg_" + s] = Cyl(hip, ank, (sx, 0.0, 0.0))       # leggings: seam and flap outside
    return cyls


def legacy_seam_field(P, J, W, names, K, mat):
    """Signed distance (m) to the nearest sewn seam of a legacy surface, per vertex: its zero set
    is a smooth line through the triangles (the UV split itself follows the triangle edges), so
    the shader draws abs() of the interpolated value. Seams: the cylinders' seam lines (centre
    back, underarm, inseam, the leggings' outside seam), the armholes (where the arm's share of
    the weights crosses one half), the coat's side seams and the breeches' centre seams."""
    cyls = legacy_cylinders(K, mat)
    big = np.full(len(P), 0.2)
    best = big.copy()

    def take(sv, valid):
        nonlocal best
        sv = np.where(valid, sv, 0.2)
        best = np.where(np.abs(sv) < np.abs(best), sv, best)

    def arc(cyl, Q):
        ang, _, r = cyl.angle_v_r(Q)
        return r * (np.mod(ang + np.pi, 2 * np.pi) - np.pi)
    if mat in ("breeches", "leggings", "garter"):
        left = P[:, 0] >= 0.0
        take(arc(cyls["leg_l"], P), left)
        take(arc(cyls["leg_r"], P), ~left)
        if mat == "breeches":
            take(P[:, 0], np.ones(len(P), bool))
        return best
    arm_l, arm_r = limb_share(names, J, W, "l", "arm"), limb_share(names, J, W, "r", "arm")
    arm = np.maximum(arm_l, arm_r)
    on_torso = arm <= 0.5
    take(arc(cyls["torso"], P), on_torso)
    take(P[:, 2] - (K["spinea"][2] - 0.01), on_torso & (np.abs(P[:, 0]) > 0.07))
    take(arc(cyls["arm_l"], P), (arm_l > 0.5))
    take(arc(cyls["arm_r"], P), (arm_r > 0.5))
    take((arm - 0.5) * 0.06, np.ones(len(P), bool))
    return best


def legacy_uvs(P, N, T, J, W, names, K, mat):
    """Per-corner UVs (len(T), 3, 2) for one legacy surface."""
    tri_P = P[T]
    Nt = np.cross(tri_P[:, 1] - tri_P[:, 0], tri_P[:, 2] - tri_P[:, 0])
    Nt /= np.maximum(np.linalg.norm(Nt, axis=1, keepdims=True), 1e-12)
    corner_P = tri_P.reshape(-1, 3)
    if mat in ("shoe", "brass", "pouch", "horn", "wood", "horn_tip", "strap", "felt", "hat_tape"):
        return box_uv(corner_P, np.repeat(Nt, 3, 0)).reshape(-1, 3, 2)
    cyls = legacy_cylinders(K, mat)
    # part per vertex
    arm_l, arm_r = limb_share(names, J, W, "l", "arm"), limb_share(names, J, W, "r", "arm")
    part = np.full(len(P), "torso", dtype=object)
    if mat in ("breeches", "leggings", "garter"):
        part[:] = np.where(P[:, 0] >= 0.0, "leg_l", "leg_r")
    else:
        part[arm_l > 0.5] = "arm_l"
        part[arm_r > 0.5] = "arm_r"
    # part per triangle (majority; the centroid side for the legs)
    tri_part = []
    for t, tp in zip(T, tri_P):
        if mat in ("breeches", "leggings", "garter"):
            tri_part.append("leg_l" if tp[:, 0].mean() >= 0 else "leg_r")
        else:
            ps = list(part[t])
            tri_part.append(max(set(ps), key=ps.count))
    tri_part = np.array(tri_part, dtype=object)
    uv = np.zeros((len(T), 3, 2))
    for name, cyl in cyls.items():
        m = tri_part == name
        if not m.any():
            continue
        # ring radius from all the vertices of this part
        vid = np.unique(T[m])
        ang_v, v_v, r_v = cyl.angle_v_r(P[vid])
        rr = ring_radius(v_v, r_v)
        rr_of = dict(zip(vid, rr))
        Q = tri_P[m].reshape(-1, 3)
        ang, v, _ = cyl.angle_v_r(Q)
        ang = ang.reshape(-1, 3)
        # a triangle across the seam: unwrap its small angles
        span = ang.max(1) - ang.min(1)
        wrap = span > np.pi
        ang[wrap] = np.where(ang[wrap] < np.pi, ang[wrap] + 2 * np.pi, ang[wrap])
        R = np.vectorize(rr_of.get)(T[m])
        uv[m, :, 0] = ang * R
        uv[m, :, 1] = v.reshape(-1, 3)
    return uv


def split_by_corner_uv(T, uv):
    """New vertices where corners of one vertex have different UVs: (remap old index per new
    vertex, new triangles, uv per new vertex)."""
    key = np.concatenate([T.reshape(-1, 1).astype(np.float64), np.round(uv.reshape(-1, 2), 6)], 1)
    uniq, inv = np.unique(key, axis=0, return_inverse=True)
    remap = uniq[:, 0].astype(np.int64)
    return remap, inv.reshape(-1, 3), uniq[:, 1:]


def legacy_brass_owner(Pb, Tb, others):
    """Piece code of the surface each brass island sits on (nearest other-surface vertex)."""
    comp = islands(Pb, Tb)
    code = np.zeros(len(Pb), int)
    for c in np.unique(comp):
        m = comp == c
        cen = Pb[m].mean(0)
        if cen[1] < 0.2:                        # the shoe buckles (the legging bottoms are as close)
            code[m] = BRASS_BASE + LEGACY_PIECES["shoe"]
            continue
        best, owner = 1e9, 0
        for oc, Po in others:
            if oc in (LEGACY_PIECES["breeches"], LEGACY_PIECES["leggings"]) and cen[1] > 0.9:
                continue                        # waistcoat buttons above the breeches' waistband
            d = np.min(np.linalg.norm(Po - cen, axis=1))
            if d < best:
                best, owner = d, oc
        code[m] = BRASS_BASE + owner
    return code


def bake_legacy(path=LEGACY):
    g = Glb(path)
    K = g.joints()
    names = g.joint_names()
    report = {}
    # first pass: positions of the non-brass Clothes surfaces (brass owners)
    others = []
    for m in g.j["meshes"]:
        if m["name"] != "Clothes":
            continue
        for pr in m["primitives"]:
            mat = g.material_name(pr)
            if mat in LEGACY_PIECES:
                others.append((LEGACY_PIECES[mat], g.get(pr["attributes"]["POSITION"])))
    for m in g.j["meshes"]:
        if m["name"] not in LEGACY_MESHES:
            continue
        for pr in m["primitives"]:
            mat = g.material_name(pr)
            at = pr["attributes"]
            P = g.get(at["POSITION"])
            N = g.get(at["NORMAL"])
            J = g.arrays[at["JOINTS_0"]].astype(np.int64)
            W = g.get(at["WEIGHTS_0"])
            T = g.arrays[pr["indices"]].reshape(-1, 3).astype(np.int64)
            assert len(set(at.values())) == len(at), "shared accessors"
            # drop attributes this tool wrote before (idempotent)
            for k in ("TEXCOORD_0", "TEXCOORD_1", "TEXCOORD_2", "TEXCOORD_3", "TEXCOORD_4", "TEXCOORD_5", "TEXCOORD_6",
                      "TANGENT"):
                at.pop(k, None)
            uv_c = legacy_uvs(P, N, T, J, W, names, K, mat)
            remap, T2, uv = split_by_corner_uv(T, uv_c)
            for k, ai in list(at.items()):
                g.set(ai, g.arrays[ai][remap])
            idx_dt = np.uint16 if len(remap) < 65535 else np.uint32
            g.set(pr["indices"], T2.reshape(-1, 1).astype(idx_dt))
            g.j["accessors"][pr["indices"]]["componentType"] = CT_OF[np.dtype(idx_dt)]
            P, N, J, W = P[remap], N[remap], J[remap], W[remap]
            d_edge = edge_distance(P, T2)
            d_seam = np.full(len(P), 0.2)
            if mat in SEAMED:
                d_seam = legacy_seam_field(P, J, W, names, K, mat)
            # piece codes
            if mat == "linen":
                arm = limb_share(names, J, W, "l", "arm") + limb_share(names, J, W, "r", "arm")
                code = np.where(arm > 0.5, LEGACY_PIECES["linen_cuffs"], LEGACY_PIECES["linen_stock"])
            elif mat == "brass" and m["name"] == "Clothes":
                code = legacy_brass_owner(P, T2, others)
            elif mat == "brass":
                code = np.full(len(P), LEGACY_PIECES["gear_brass" if m["name"] == "Gear" else "hat_brass"])
            else:
                code = np.full(len(P), LEGACY_PIECES.get(mat, 63))
            kind = "cloth"
            if m["name"] == "Gear" or mat == "shoe":
                kind = "leather"
            if mat == "brass":
                kind = "metal"
            if m["name"] == "Hat":
                kind = "hat"
            dirt, wear, sweat = masks(P, N, K, d_edge, kind)
            push = np.zeros(len(P))
            tangent = None
            if m["name"] == "Gear":
                if mat in ("belt", "brass"):
                    push[:] = 1.0
                elif mat == "strap":
                    push[:] = 1.0 + smoothstep(0.99, 1.10, P[:, 1])
                else:
                    push[:] = 3.0
                # TANGENT: rigid pieces move out horizontally from the body axis (per island)
                comp = islands(P, T2)
                tangent = np.zeros((len(P), 4), np.float32)
                tangent[:, 3] = 1.0
                for c in np.unique(comp):
                    sel = comp == c
                    cen = P[sel].mean(0)
                    d = np.array([cen[0], 0.0, cen[2] - K["pelvis"][2]])
                    tangent[sel, :3] = nrm(d) if np.linalg.norm(d) > 1e-6 else (1.0, 0.0, 0.0)
                # a valid tangent (orthogonal to the normal) is not needed by the cloth shader
                # (its normal map uses a derivative frame); only the direction is read
            at["TEXCOORD_0"] = g.add(uv.astype(np.float32))
            at["TEXCOORD_1"] = g.add(np.stack([code.astype(np.float32), np.ones(len(P), np.float32)], 1))
            at["TEXCOORD_2"] = g.add(np.stack([d_edge, d_edge], 1).astype(np.float32))
            at["TEXCOORD_3"] = g.add(np.stack([dirt, wear], 1).astype(np.float32))
            at["TEXCOORD_4"] = g.add(np.stack([sweat, push], 1).astype(np.float32))
            at["TEXCOORD_5"] = g.add(np.stack([d_seam, np.zeros(len(P))], 1).astype(np.float32))
            fk = kind if (mat in SEAMED or mat == "garter") else "hard"
            at["TEXCOORD_6"] = g.add(np.stack([cavity(P, N, T2), folds(P, N, K, fk)], 1).astype(np.float32))
            if tangent is not None:
                at["TANGENT"] = g.add(tangent)
            report["%s/%s" % (m["name"], mat)] = {
                "verts": int(len(P)), "split_added": int(len(P) - len(np.unique(remap))),
                "tris": int(len(T2)), "uv_range_m": [float(np.ptp(uv[:, 0])), float(np.ptp(uv[:, 1]))],
                "dirt_mean": round(float(dirt.mean()), 3), "wear_mean": round(float(wear.mean()), 3),
                "sweat_mean": round(float(sweat.mean()), 3), "codes": sorted(set(int(c) for c in code))}
    g.write(path)
    return report


# ---------------------------------------------------------------------------------------------
# garments: masks only (their UVs, regions and edge distances come from the Blender pipeline)
# ---------------------------------------------------------------------------------------------
def garment_kind(g, pr, slot):
    if g.material_name(pr).endswith("_fur"):
        return "fur"
    if slot == "head":
        return "hat"
    return "cloth"


def bake_garment(path):
    g = Glb(path)
    K = g.joints()
    side = os.path.splitext(path)[0] + ".json"
    slot = json.load(open(side)).get("slot", "") if os.path.exists(side) else ""
    out = {}
    for m in g.j["meshes"]:
        for pr in m["primitives"]:
            at = pr["attributes"]
            P = g.get(at["POSITION"])
            N = g.get(at["NORMAL"])
            T = g.arrays[pr["indices"]].reshape(-1, 3).astype(np.int64)
            for k in ("TEXCOORD_3", "TEXCOORD_4", "TEXCOORD_5", "TEXCOORD_6"):
                at.pop(k, None)
            if "TEXCOORD_2" in at:
                E = g.get(at["TEXCOORD_2"])
                d_edge = np.minimum(E[:, 0], E[:, 1])
                if garment_kind(g, pr, slot) == "fur" or not np.isfinite(d_edge).all() or d_edge.max() <= 0.0:
                    d_edge = edge_distance(P, T)
            else:
                d_edge = edge_distance(P, T)
                at["TEXCOORD_2"] = g.add(np.stack([d_edge, d_edge], 1).astype(np.float32))
            if "TEXCOORD_0" not in at or "TEXCOORD_1" not in at:
                raise SystemExit("%s: %s has no TEXCOORD_0/1" % (path, g.material_name(pr)))
            dirt, wear, sweat = masks(P, N, K, d_edge, garment_kind(g, pr, slot))
            at["TEXCOORD_3"] = g.add(np.stack([dirt, wear], 1).astype(np.float32))
            at["TEXCOORD_4"] = g.add(np.stack([sweat, np.zeros(len(P))], 1).astype(np.float32))
            d_seam = np.full(len(P), 0.2)
            if slot in SEAMED_SLOTS and garment_kind(g, pr, slot) == "cloth" and not g.material_name(pr).endswith("_fringe"):
                d_seam = seam_distance(P, T, g.get(at["TEXCOORD_0"]))
            at["TEXCOORD_5"] = g.add(np.stack([d_seam, np.zeros(len(P))], 1).astype(np.float32))
            fk = garment_kind(g, pr, slot) if slot in SEAMED_SLOTS else "hard"
            cav = cavity(P, N, T) if garment_kind(g, pr, slot) != "fur" else np.zeros(len(P))
            at["TEXCOORD_6"] = g.add(np.stack([cav, folds(P, N, K, fk)], 1).astype(np.float32))
            out[g.material_name(pr)] = {"dirt": round(float(dirt.mean()), 3), "wear": round(float(wear.mean()), 3),
                                        "sweat": round(float(sweat.mean()), 3)}
    g.write(path)
    return out


def main(argv):
    what = argv[1] if len(argv) > 1 else "all"
    rep = {}
    if what in ("legacy", "all"):
        rep["legacy"] = bake_legacy()
    if what in ("garments", "all") or what.endswith(".glb"):
        paths = [what] if what.endswith(".glb") else sorted(glob.glob(os.path.join(GARMENTS, "*", "*.glb")))
        for p in paths:
            rep[os.path.relpath(p, ROOT)] = bake_garment(p)
    print(json.dumps(rep, indent=1))


if __name__ == "__main__":
    main(sys.argv)
