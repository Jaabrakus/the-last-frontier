"""Skin deformation check of the exported horse (numpy only, no Blender, about 20 s).

Reads assets/horse/horse.glb (or --glb PATH), plays the clips the way the engine does (keys
interpolated linearly, rotations by normalised lerp), skins the HorseBody mesh with its own
weights (linear blend skinning, as Godot does) and measures, per anatomical region of the left
side and along the back line, how the skin deforms against the bind pose:

  stretch   edge length ratio posed / rest: the 1st and 99th percentile and the extremes
  area      triangle area ratio: the 1st percentile (collapse) and the 99th (tearing)
  crease    how much sharper the fold between neighbouring triangles gets than at rest (deg):
            the 99th percentile over the region's edges, and the share of edges over 45 deg
  folds     triangles turned more than 90 deg away from where their bones carry them
            (skin folded through itself), per mille
  volume    enclosed volume of the region's patch against its centroid, posed / rest

The regions are spheres round the joints of the left legs (from the skeleton's rest pose:
shoulder blade, point of shoulder, elbow and girth, forearm, knee, fore fetlock, hip,
flank, stifle, gaskin, hock, hind fetlock), the withers, the back line (top of the back
from the withers to the tail head) and the croup. Joints are found by bone name
(scapula_l, humerus_l, radius_l, cannon_l, pastern_l, femur_l, tibia_l, hcannon_l,
hpastern_l), which every rig revision keeps.

  python3 tools/horse/skin_check.py [--glb PATH] [--clips walk,trot] [--samples 24] [--json OUT]
  python3 tools/horse/skin_check.py --mesh DUMP.npz [--heat] ...   # before a build: build_horse.sh --dump-skin DUMP.npz
"""

import argparse
import json
import math
import os
import struct
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
DEFAULT_CLIPS = ["idle", "walk", "trot", "canter", "gallop", "sprint", "jump", "rear", "trot_tl", "canter_tr"]
_CT = {5126: ("<f4", 4), 5123: ("<u2", 2), 5125: ("<u4", 4), 5121: ("<u1", 1), 5122: ("<i2", 2), 5120: ("<i1", 1)}
_NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}


# ---------------------------------------------------------------------------
# glTF
# ---------------------------------------------------------------------------
class Glb:
    def __init__(self, path):
        raw = open(path, "rb").read()
        jl = struct.unpack("<I", raw[12:16])[0]
        self.js = json.loads(raw[20:20 + jl])
        bl = struct.unpack("<I", raw[20 + jl:24 + jl])[0]
        self.bin = raw[28 + jl:28 + jl + bl]
        self.nodes = self.js["nodes"]
        self.parent = {}
        for i, n in enumerate(self.nodes):
            for c in n.get("children", []):
                self.parent[c] = i
        self.by_name = {n.get("name"): i for i, n in enumerate(self.nodes)}

    def read(self, i):
        a = self.js["accessors"][i]
        bv = self.js["bufferViews"][a["bufferView"]]
        dt, sz = _CT[a["componentType"]]
        nc = _NC[a["type"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", sz * nc)
        if stride == sz * nc:
            out = np.frombuffer(self.bin, dt, a["count"] * nc, off).reshape(a["count"], nc).astype(float)
        else:
            out = np.array([np.frombuffer(self.bin, dt, nc, off + k * stride) for k in range(a["count"])], float)
        if a.get("normalized"):
            out = out / float(np.iinfo(np.dtype(dt)).max)
        return out

    def rest_trs(self, i):
        n = self.nodes[i]
        return (np.array(n.get("translation", [0, 0, 0]), float), np.array(n.get("rotation", [0, 0, 0, 1]), float),
                np.array(n.get("scale", [1, 1, 1]), float))


def trs_mat(t, q, s):
    x, y, z, w = q / np.linalg.norm(q)
    R = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                  [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                  [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    M = np.eye(4)
    M[:3, :3] = R * s[None, :]
    M[:3, 3] = t
    return M


class Clips:
    """Animation sampler: clip name -> {node: {path: (times, values)}}."""

    def __init__(self, g):
        self.g = g
        self.clips = {}
        for an in g.js.get("animations", []):
            ch = {}
            for c in an["channels"]:
                s = an["samplers"][c["sampler"]]
                ch.setdefault(c["target"]["node"], {})[c["target"]["path"]] = (g.read(s["input"])[:, 0], g.read(s["output"]))
            self.clips[an["name"]] = ch

    def length(self, name):
        return max(float(v[0][-1]) for d in self.clips[name].values() for v in d.values())

    def local(self, name, t):
        """node -> local 4x4 at time t (nodes without tracks keep their rest)."""
        out = {}
        ch = self.clips[name]
        for i in range(len(self.g.nodes)):
            tr, q, s = self.g.rest_trs(i)
            d = ch.get(i)
            if d:
                if "translation" in d:
                    tr = _lerp(*d["translation"], t)
                if "rotation" in d:
                    q = _nlerp(*d["rotation"], t)
                if "scale" in d:
                    s = _lerp(*d["scale"], t)
            out[i] = trs_mat(tr, q, s)
        return out


def _seg(times, t):
    t = min(max(t, times[0]), times[-1])
    k = int(np.searchsorted(times, t, side="right")) - 1
    k = min(max(k, 0), len(times) - 2) if len(times) > 1 else 0
    if len(times) == 1:
        return 0, 0, 0.0
    f = (t - times[k]) / max(times[k + 1] - times[k], 1e-9)
    return k, k + 1, float(min(max(f, 0.0), 1.0))


def _lerp(times, vals, t):
    a, b, f = _seg(times, t)
    return vals[a] * (1 - f) + vals[b] * f


def _nlerp(times, vals, t):
    a, b, f = _seg(times, t)
    qa, qb = vals[a], vals[b]
    if qa @ qb < 0:
        qb = -qb
    q = qa * (1 - f) + qb * f
    return q / np.linalg.norm(q)


def globals_of(g, local):
    out = {}

    def G(i):
        if i in out:
            return out[i]
        p = g.parent.get(i)
        out[i] = local[i] if p is None else G(p) @ local[i]
        return out[i]
    for i in local:
        G(i)
    return out


# ---------------------------------------------------------------------------
# Skinned body
# ---------------------------------------------------------------------------
class Body:
    """Skin mesh: rest vertices V, normals N, triangles F, per vertex joint indices J and
    weights W (into `names`), and the welded topology the metrics use."""

    def __init__(self, V, N, F, J, W, names):
        self.V, self.N, self.F, self.J, self.names = V, N, F, J, names
        self.W = W / np.maximum(W.sum(1, keepdims=True), 1e-9)
        self._topology()

    @classmethod
    def from_glb(cls, g, mesh_name="HorseBody"):
        mi = next(i for i, n in enumerate(g.nodes) if n.get("name") == mesh_name and "mesh" in n)
        node = g.nodes[mi]
        prim = g.js["meshes"][node["mesh"]]["primitives"][0]
        J = g.read(prim["attributes"]["JOINTS_0"]).astype(int)
        W = g.read(prim["attributes"]["WEIGHTS_0"])
        if "JOINTS_1" in prim["attributes"]:
            J = np.hstack([J, g.read(prim["attributes"]["JOINTS_1"]).astype(int)])
            W = np.hstack([W, g.read(prim["attributes"]["WEIGHTS_1"])])
        skin = g.js["skins"][node["skin"]]
        b = cls(g.read(prim["attributes"]["POSITION"]), g.read(prim["attributes"]["NORMAL"]),
                g.read(prim["indices"]).astype(int).reshape(-1, 3), J, W, [g.nodes[j].get("name") for j in skin["joints"]])
        b.joints = skin["joints"]
        b.ibm = g.read(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
        return b

    def _topology(self):
        # welded topology (surface nets meshes are welded, but UV seams split vertices)
        key = np.round(self.V * 1e5).astype(np.int64)
        _, self.weld, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
        self.wid = inv.ravel()
        Fw = self.wid[self.F]
        self.Fw = Fw[(Fw[:, 0] != Fw[:, 1]) & (Fw[:, 1] != Fw[:, 2]) & (Fw[:, 0] != Fw[:, 2])]
        self.Vw = self.V[self.weld]
        E = np.sort(np.concatenate([self.Fw[:, [0, 1]], self.Fw[:, [1, 2]], self.Fw[:, [2, 0]]]), 1)
        fid = np.tile(np.arange(len(self.Fw)), 3)
        order = np.lexsort((E[:, 1], E[:, 0]))
        E, fid = E[order], fid[order]
        same = np.all(E[1:] == E[:-1], 1)
        self.edges = np.unique(E, axis=0)
        # interior edges shared by exactly two faces: (face a, face b)
        self.adj = np.stack([fid[:-1][same], fid[1:][same]], 1)

    def skin(self, gl):
        """gl: node -> global matrix (glb bodies)."""
        return self.skin_mats(np.stack([gl[j] @ self.ibm[k] for k, j in enumerate(self.joints)]))

    def skin_mats(self, M):
        """M: (joints, 4, 4) skinning matrices (posed global x inverse bind)."""
        Vh = np.hstack([self.V, np.ones((len(self.V), 1))])
        P = np.zeros((len(self.V), 3))
        for c in range(self.J.shape[1]):
            P += self.W[:, c:c + 1] * np.einsum("nij,nj->ni", M[self.J[:, c]], Vh)[:, :3]
        # rigid expectation of each vertex's normal (its bones' rotations, blended)
        Nn = np.zeros_like(self.N)
        for c in range(self.J.shape[1]):
            Nn += self.W[:, c:c + 1] * np.einsum("nij,nj->ni", M[self.J[:, c], :3, :3], self.N)
        return P, Nn


def face_normals(P, F):
    n = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    a = np.linalg.norm(n, axis=1)
    return n / np.maximum(a, 1e-12)[:, None], 0.5 * a


JOINT_BONES = ("scapula_l", "humerus_l", "radius_l", "cannon_l", "pastern_l", "femur_l", "tibia_l", "hcannon_l",
               "hpastern_l")


def regions(g, body):
    """Region name -> welded-vertex mask of a glb body."""
    rest = globals_of(g, {i: trs_mat(*g.rest_trs(i)) for i in range(len(g.nodes))})
    return regions_at({k: rest[g.by_name[k]][:3, 3] for k in JOINT_BONES}, body)


def regions_at(J, body):
    """Region name -> welded-vertex mask (rest pose, glTF model space: +y up, +z forward,
    +x the horse's left). J: bone name -> rest head (JOINT_BONES)."""
    V = body.Vw
    left = V[:, 0] > 0.02

    def ball(c, r, side=True):
        m = np.linalg.norm(V - c, axis=1) < r
        return m & left if side else m
    scap = 0.5 * (J["scapula_l"] + J["humerus_l"])
    R = {
        "shoulder_blade": ball(scap, 0.17),
        "point_of_shoulder": ball(J["humerus_l"], 0.12),
        "elbow_girth": ball(J["radius_l"] + np.array([0.0, 0.03, -0.06]), 0.14),
        "forearm": ball(0.5 * (J["radius_l"] + J["cannon_l"]), 0.10),
        "knee": ball(J["cannon_l"], 0.07),
        "fore_fetlock": ball(J["pastern_l"], 0.07),
        "hip": ball(J["femur_l"], 0.18),
        "flank": ball(J["tibia_l"] + np.array([-0.06, 0.18, 0.12]), 0.14),
        "stifle": ball(J["tibia_l"], 0.13),
        "gaskin": ball(0.5 * (J["tibia_l"] + J["hcannon_l"]), 0.11),
        "hock": ball(J["hcannon_l"], 0.09),
        "hind_fetlock": ball(J["hpastern_l"], 0.07),
    }
    zw = scap[2]
    zc = J["femur_l"][2]
    top = np.zeros(len(V), bool)
    # the back line: the top 6 cm of the torso section from the withers to the tail head
    for z0 in np.arange(zc - 0.25, zw + 0.1, 0.04):
        sl = (np.abs(V[:, 2] - z0) < 0.02) & (np.abs(V[:, 0]) < 0.14)
        if sl.any():
            top |= sl & (V[:, 1] > V[sl, 1].max() - 0.06)
    R["back_line"] = top
    R["withers"] = top & (np.abs(V[:, 2] - zw) < 0.2)
    R["croup"] = top & (np.abs(V[:, 2] - zc) < 0.22)
    return R


def measure(body, P, Nn, reg, rest_cache):
    Pw = P[body.weld]
    Nw = Nn[body.weld]
    Fw = body.Fw
    n1, a1 = face_normals(Pw, Fw)
    n0, a0 = rest_cache["n"], rest_cache["a"]
    e = body.edges
    L1 = np.linalg.norm(Pw[e[:, 0]] - Pw[e[:, 1]], axis=1)
    L0 = rest_cache["L"]
    # expected face normal from the vertices' rigid normals
    ex = Nw[Fw].sum(1)
    ex /= np.maximum(np.linalg.norm(ex, axis=1), 1e-12)[:, None]
    fold = (n1 * ex).sum(1) < 0.0
    ad = body.adj
    dih1 = np.degrees(np.arccos(np.clip((n1[ad[:, 0]] * n1[ad[:, 1]]).sum(1), -1, 1)))
    dih0 = rest_cache["dih"]
    out = {}
    for name, m in reg.items():
        em = m[e[:, 0]] & m[e[:, 1]]
        fm = m[Fw].all(1)
        am = fm[ad[:, 0]] & fm[ad[:, 1]]
        if em.sum() < 10 or fm.sum() < 10:
            continue
        r = L1[em] / np.maximum(L0[em], 1e-9)
        ar = a1[fm] / np.maximum(a0[fm], 1e-12)
        dd = dih1[am] - dih0[am]
        # volume of the patch against its rest centroid (a closed-ish measure of bulk)
        c0 = rest_cache["c"][name]
        c1 = Pw[m].mean(0)
        v0 = np.abs(np.einsum("ij,ij->i", np.cross(body.Vw[Fw[fm, 0]] - c0, body.Vw[Fw[fm, 1]] - c0),
                              body.Vw[Fw[fm, 2]] - c0)).sum()
        v1 = np.abs(np.einsum("ij,ij->i", np.cross(Pw[Fw[fm, 0]] - c1, Pw[Fw[fm, 1]] - c1), Pw[Fw[fm, 2]] - c1)).sum()
        out[name] = dict(s_lo=r, s_hi=r, a=ar, crease=dd, fold=fold[fm], vol=v1 / max(v0, 1e-12))
    return out


def summarize(samples):
    """Per region over all samples of a clip."""
    res = {}
    for name in samples[0]:
        s = np.concatenate([x[name]["s_lo"] for x in samples if name in x])
        a = np.concatenate([x[name]["a"] for x in samples if name in x])
        c = np.concatenate([x[name]["crease"] for x in samples if name in x])
        f = np.concatenate([x[name]["fold"] for x in samples if name in x])
        v = np.array([x[name]["vol"] for x in samples if name in x])
        res[name] = dict(stretch_p1=float(np.percentile(s, 1)), stretch_p99=float(np.percentile(s, 99)),
                         stretch_min=float(s.min()), stretch_max=float(s.max()),
                         area_p1=float(np.percentile(a, 1)), area_p99=float(np.percentile(a, 99)),
                         crease_p99=float(np.percentile(c, 99)), crease45_pm=float(1000.0 * (c > 45.0).mean()),
                         folds_pm=float(1000.0 * f.mean()), vol_min=float(v.min()), vol_max=float(v.max()))
    return res


def rest_cache(body, reg, P0):
    Pw0 = P0[body.weld]
    n0, a0 = face_normals(Pw0, body.Fw)
    ad = body.adj
    rc = dict(n=n0, a=a0, L=np.linalg.norm(Pw0[body.edges[:, 0]] - Pw0[body.edges[:, 1]], axis=1),
              dih=np.degrees(np.arccos(np.clip((n0[ad[:, 0]] * n0[ad[:, 1]]).sum(1), -1, 1))),
              c={k: Pw0[m].mean(0) for k, m in reg.items() if m.any()})
    return rc


def run(glb, clips, samples):
    g = Glb(glb)
    body = Body.from_glb(g)
    cl = Clips(g)
    reg = regions(g, body)
    gl0 = globals_of(g, {i: trs_mat(*g.rest_trs(i)) for i in range(len(g.nodes))})
    rc = rest_cache(body, reg, body.skin(gl0)[0])
    out = {"glb": os.path.relpath(glb, PROJECT) if glb.startswith(PROJECT) else glb, "bones": len(body.joints),
           "vertices": int(len(body.Vw)), "regions": {k: int(m.sum()) for k, m in reg.items()}, "clips": {}}
    for c in clips:
        if c not in cl.clips:
            continue
        L = cl.length(c)
        smp = []
        for i in range(samples):
            t = L * (i + 0.5) / samples
            smp.append(measure(body, *body.skin(globals_of(g, cl.local(c, t))), reg, rc))
        out["clips"][c] = summarize(smp)
    return finish(out)


# Blender armature space (z up, the horse faces -y) -> glTF / Godot model space (y up, +z forward)
TO_GLTF = np.array([[1.0, 0, 0, 0], [0, 0, 1.0, 0], [0, -1.0, 0, 0], [0, 0, 0, 1.0]])


def run_mesh(dump, clips, samples, heat_only=False):
    """The same metrics without a glb: the skin and heat weights dumped by
    build_horse.sh --dump-skin, the weights from tools/horse/skinning.py (as the build makes
    them; heat_only: the plain heat weights, cut to four influences) and the poses from the
    gait solver (tools/horse/gaits.py), keys and all."""
    sys.path.insert(0, HERE)
    sys.dont_write_bytecode = True
    import anatomy as A
    import gait_check as GC
    import gaits as G
    import skinning as SK
    d = np.load(dump)
    bones = [str(b) for b in d["bones"]]
    H = d["H"]
    heat = [{bones[j]: float(H[i, j]) for j in np.nonzero(H[i] > 0)[0]} for i in range(len(H))]
    W = SK.limit(heat) if heat_only else SK.compute(d["V"], d["E"], heat)
    rest = GC.rest_matrices(A)
    names = list(rest)
    k = max(len(w) for w in W)
    Ji = np.zeros((len(W), k), int)
    Wi = np.zeros((len(W), k))
    for i, w in enumerate(W):
        for c, (b, x) in enumerate(w.items()):
            Ji[i, c] = names.index(b)
            Wi[i, c] = x
    C3 = TO_GLTF[:3, :3]
    body = Body(d["V"] @ C3.T, d["N"] @ C3.T, d["T"], Ji, Wi, names)
    reg = regions_at({b: C3 @ rest[b][:3, 3] for b in JOINT_BONES}, body)
    rc = rest_cache(body, reg, body.V)
    rig = G.Rig(rest)
    solver = G.Solver(rig, G.load_rider_curves())
    inv = {b: np.linalg.inv(rest[b]) for b in names}
    out = {"mesh": dump, "bones": len(names), "vertices": int(len(body.Vw)), "influences": k,
           "regions": {kk: int(m.sum()) for kk, m in reg.items()}, "clips": {}}
    for c in clips:
        if c not in G.GAITS:
            continue
        nf, L = G.clip_frames(c)
        smp = []
        for i in range(samples):
            pose = solver.pose_at(c, L * (i + 0.5) / samples, L, nf)
            M = np.stack([TO_GLTF @ pose[b] @ inv[b] @ TO_GLTF.T for b in names])
            smp.append(measure(body, *body.skin_mats(M), reg, rc))
        out["clips"][c] = summarize(smp)
    return finish(out)


def finish(out):
    # worst over the clips, per region
    worst = {}
    for c, d in out["clips"].items():
        for r, m in d.items():
            w = worst.setdefault(r, dict(m))
            for k, v in m.items():
                if k in ("stretch_p1", "stretch_min", "area_p1", "vol_min"):
                    w[k] = min(w[k], v)
                else:
                    w[k] = max(w[k], v)
    out["worst"] = worst
    return out


def table(res):
    lines = ["%-18s %7s %7s %7s %7s %8s %8s %7s %9s" % ("region (worst)", "str p1", "str p99", "area p1", "area99",
                                                          "crease99", "cr>45 pm", "fold pm", "volume")]
    for r, m in res["worst"].items():
        lines.append("%-18s %7.2f %7.2f %7.2f %7.2f %8.1f %8.2f %7.2f %4.2f-%4.2f" % (
            r, m["stretch_p1"], m["stretch_p99"], m["area_p1"], m["area_p99"], m["crease_p99"], m["crease45_pm"],
            m["folds_pm"], m["vol_min"], m["vol_max"]))
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--glb", default=os.path.join(PROJECT, "assets", "horse", "horse.glb"))
    ap.add_argument("--clips", default=",".join(DEFAULT_CLIPS))
    ap.add_argument("--samples", type=int, default=24)
    ap.add_argument("--mesh", help="a skin dump (build_horse.sh --dump-skin PATH): weights from skinning.py, "
                                   "poses from the gait solver, no glb")
    ap.add_argument("--heat", action="store_true", help="with --mesh: the plain heat weights (for comparison)")
    ap.add_argument("--json")
    a = ap.parse_args()
    if a.mesh:
        res = run_mesh(a.mesh, a.clips.split(","), a.samples, a.heat)
        print("%s: %d bones, %d skin vertices, %d influences" % (res["mesh"], res["bones"], res["vertices"],
                                                                  res["influences"]))
    else:
        res = run(a.glb, a.clips.split(","), a.samples)
        print("%s: %d bones, %d skin vertices" % (res["glb"], res["bones"], res["vertices"]))
    print(table(res))
    if a.json:
        json.dump(res, open(a.json, "w"), indent=1)
        print("wrote", a.json)


if __name__ == "__main__":
    sys.exit(main())
