"""A closed skirt's hang and skin weights (plain python3 + numpy, on the built glb in place; no Blender):

    python3 tools/character/cloth2/skirt_hang.py assets/character/garments/colonial/petticoat.glb
    python3 tools/character/cloth_bake.py assets/character/garments/colonial/petticoat.glb
    then: Godot --headless --path . --import

Run it once on a freshly built glb (it reshapes what it finds). The user, 2026-09-29: "fix skirts from animations
glitch out of the skirt", "apply clothes weight", "the skirt is like a bell that flies and looks too stiff".

The hang: below the shift's hem the skirt flared out to a stiff bell; it is drawn in (NARROW at the hem, none from
TOP_Y up, where the shift under it needs the room) and gathered into FOLDS soft vertical folds that deepen toward the
hem (FOLD_M), the normals there recomputed.

The weights: the runtime drives a closed skirt's six panels round both legs (CharacterBodyMesh SKIRT_CLOSED_*:
l/r_upper_leg_front_helper, _thigh_helper, _rear_helper, at 40, 90 and 140 degrees round from the front). The build
weighted the skirt's lower part only about 70 % to them and the rest to the pelvis and spine, so a knee pushing a panel
moved the cloth there only part of the way and came through. Below the hips the cloth goes over to the panels (none at
HIP_Y, all at FULL_Y: SKIRT_CLOSED_SHARE_Y in CharacterBodyMesh), blended between the two nearest panels by the angle
round the body (half and half at the centre front and back), the rest keeping its own pelvis / spine weights. At most
four influences. Prints the hems (SKIRT_HEMS layout) for the catalog's skirt.hems_godot.
"""

import json
import math
import struct
import sys

import numpy as np

HIP_Y = 0.88
FULL_Y = 0.62
TOP_Y = 0.62
NARROW = 0.17
FOLDS = 16
FOLD_M = 0.018
PANELS = [(40.0, "l_upper_leg_front_helper"), (90.0, "l_upper_leg_thigh_helper"), (140.0, "l_upper_leg_rear_helper"),
          (220.0, "r_upper_leg_rear_helper"), (270.0, "r_upper_leg_thigh_helper"), (320.0, "r_upper_leg_front_helper")]


def _accessor(b, j, bin_off, ai, dtype, ncomp):
    a = j["accessors"][ai]
    bv = j["bufferViews"][a["bufferView"]]
    size = np.dtype(dtype).itemsize * ncomp
    assert bv.get("byteStride") in (None, size), "interleaved accessor"
    off = bin_off + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(bytes(b[off:off + a["count"] * size]), dtype).reshape(a["count"], ncomp).copy(), off


def _smooth(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


def _normals(P, F):
    """Smooth vertex normals over the welded mesh (seam duplicates share theirs)."""
    key = np.round(P * 1e5).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    N = np.zeros((inv.max() + 1, 3))
    fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    for k in range(3):
        np.add.at(N, inv[F[:, k]], fn)
    N = N[inv]
    return N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)


def hang(P, F, N):
    """The drawn-in, folded skirt: new positions and normals (glTF: +y up, +z the way the body faces)."""
    low = P[:, 1] < 0.3
    cx, cz = float(P[low, 0].mean()), float(P[low, 2].mean())
    s = _smooth((TOP_Y - P[:, 1]) / (TOP_Y - float(P[:, 1].min())))
    dx, dz = P[:, 0] - cx, P[:, 2] - cz
    r = np.hypot(dx, dz)
    az = np.arctan2(dx, dz)
    r2 = r * (1.0 - NARROW * s) + FOLD_M * s ** 1.3 * np.cos(FOLDS * az)
    k = np.where(r > 1e-6, r2 / np.maximum(r, 1e-6), 1.0)
    Q = P.copy()
    Q[:, 0] = cx + dx * k
    Q[:, 2] = cz + dz * k
    Nn = _normals(Q, F)
    t = _smooth((TOP_Y + 0.05 - P[:, 1]) / 0.06)[:, None]
    N2 = N * (1.0 - t) + Nn * t
    return Q, N2 / np.maximum(np.linalg.norm(N2, axis=1, keepdims=True), 1e-12), (cx, cz)


def weights(P, J, W, names):
    panel_idx = [names.index(n) for _, n in PANELS]
    share = _smooth((HIP_Y - P[:, 1]) / (HIP_Y - FULL_Y))
    az = np.degrees(np.arctan2(P[:, 0], P[:, 2])) % 360.0
    newJ = J.copy()
    newW = W.copy()
    for i in np.nonzero(share > 0.0)[0]:
        a = az[i]
        pan = {}
        for k in range(len(PANELS)):
            a0 = PANELS[k][0]
            a1 = PANELS[(k + 1) % len(PANELS)][0] + (360.0 if k == len(PANELS) - 1 else 0.0)
            aa = a + 360.0 if a < a0 else a
            if a0 <= aa <= a1:
                f = (aa - a0) / (a1 - a0)
                pan = {panel_idx[k]: 1.0 - f}
                nb = panel_idx[(k + 1) % len(PANELS)]
                pan[nb] = pan.get(nb, 0.0) + f
                break
        own = {}
        for c in range(4):
            if W[i, c] > 0.0 and int(J[i, c]) not in panel_idx:
                own[int(J[i, c])] = own.get(int(J[i, c]), 0.0) + float(W[i, c])
        if not own:
            own = {names.index("pelvis"): 1.0}
        tot = sum(own.values())
        inf = {bone: w * share[i] for bone, w in pan.items() if w > 0.0}
        for bone, w in sorted(own.items(), key=lambda kv: -kv[1])[:4 - len(inf)]:
            inf[bone] = inf.get(bone, 0.0) + w / tot * (1.0 - share[i])
        items = sorted(inf.items(), key=lambda kv: -kv[1])[:4]
        tw = sum(w for _, w in items)
        newJ[i] = 0
        newW[i] = 0.0
        for c, (bone, w) in enumerate(items):
            newJ[i, c] = bone
            newW[i, c] = w / tw
    return newJ, newW, int((share > 0.0).sum())


def main(path):
    b = bytearray(open(path, "rb").read())
    jl = struct.unpack_from("<I", b, 12)[0]
    j = json.loads(bytes(b[20:20 + jl]))
    bin_off = 20 + jl + 8
    names = [j["nodes"][n]["name"] for n in j["skins"][0]["joints"]]
    pr = j["meshes"][0]["primitives"][0]
    at = pr["attributes"]
    P, poff = _accessor(b, j, bin_off, at["POSITION"], np.float32, 3)
    N, noff = _accessor(b, j, bin_off, at["NORMAL"], np.float32, 3)
    ia = j["accessors"][pr["indices"]]
    F, _ = _accessor(b, j, bin_off, pr["indices"], {5125: np.uint32, 5123: np.uint16}[ia["componentType"]], 1)
    F = F.reshape(-1, 3).astype(np.int64)
    Q, N2, (cx, cz) = hang(P.astype(float), F, N.astype(float))
    b[poff:poff + P.nbytes] = Q.astype(np.float32).tobytes()
    b[noff:noff + N.nbytes] = N2.astype(np.float32).tobytes()
    jt = {5121: np.uint8, 5123: np.uint16}[j["accessors"][at["JOINTS_0"]]["componentType"]]
    assert j["accessors"][at["WEIGHTS_0"]]["componentType"] == 5126, "weights not float"
    J, joff = _accessor(b, j, bin_off, at["JOINTS_0"], jt, 4)
    W, woff = _accessor(b, j, bin_off, at["WEIGHTS_0"], np.float32, 4)
    J2, W2, moved = weights(Q, J, W, names)
    b[joff:joff + J.nbytes] = J2.astype(jt).tobytes()
    b[woff:woff + W.nbytes] = W2.astype(np.float32).tobytes()
    a = j["accessors"][at["POSITION"]]
    a["min"] = Q.min(0).tolist()
    a["max"] = Q.max(0).tolist()
    js = json.dumps(j, separators=(",", ":")).encode()
    assert len(js) <= jl, "json grew"
    b[20:20 + jl] = js + b" " * (jl - len(js))
    open(path, "wb").write(bytes(b))
    # the hems at the panels' places (left leg; the lowest ring, less the folds)
    ylo = float(Q[:, 1].min())
    ring = Q[Q[:, 1] < ylo + 0.01]
    rr = np.hypot(ring[:, 0] - cx, ring[:, 2] - cz).mean()
    hems = [[round(rr * math.sin(math.radians(d)) + cx, 3), round(ylo, 3), round(rr * math.cos(math.radians(d)) + cz, 3)]
            for d in (40.0, 90.0, 140.0)]
    print("%s: drawn in to a hem of %.3f m, %d vertices weighted to the skirt panels; hems_godot %s" % (
        path.split("/")[-1], rr, moved, json.dumps(hems)))


if __name__ == "__main__":
    for p in sys.argv[1:]:
        main(p)
