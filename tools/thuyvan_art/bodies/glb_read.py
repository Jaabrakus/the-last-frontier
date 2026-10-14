"""Minimal glb reader (plain numpy, no Blender): the meshes, skins and morph targets of a character part, in Blender
space (z up, facing -y), so kit shapes can be drafted on the human body outside the shared Blender lock.

    m = read_glb("assets/character/body/body.glb")
    m["V"], m["F"], m["joints"] (n, 4), m["weights"] (n, 4), m["bones"] (skin joint names), m["morphs"] {name: (n, 3)}
"""

import json
import struct

import numpy as np

_CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
_NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def _y2z(a):
    """glTF (y up, +z forward) -> Blender (z up, -y forward): (x, y, z) -> (x, -z, y)."""
    return np.stack([a[:, 0], -a[:, 2], a[:, 1]], 1)


def read_glb(path):
    data = open(path, "rb").read()
    magic, ver, length = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67, "not a glb"
    off = 12
    js, binc = None, None
    while off < length:
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk)
        elif ctype == 0x004E4942:
            binc = chunk
        off += 8 + clen

    def view(bvi, dt, count, extra=0):
        bv = js["bufferViews"][bvi]
        return np.frombuffer(binc, dt, count=count, offset=bv.get("byteOffset", 0) + extra)

    def acc(i):
        a = js["accessors"][i]
        dt = _CT[a["componentType"]]
        n = _NC[a["type"]]
        if "bufferView" not in a:
            arr = np.zeros((a["count"], n), dt)
            sp = a.get("sparse")
            if sp:
                ii = view(sp["indices"]["bufferView"], _CT[sp["indices"]["componentType"]], sp["count"],
                          sp["indices"].get("byteOffset", 0)).astype(np.int64)
                vv = view(sp["values"]["bufferView"], dt, sp["count"] * n, sp["values"].get("byteOffset", 0))
                arr[ii] = vv.reshape(-1, n)
            return arr
        bv = js["bufferViews"][a["bufferView"]]
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", 0)
        isz = np.dtype(dt).itemsize
        if stride and stride != n * isz:
            raw = np.frombuffer(binc, np.uint8, count=stride * a["count"], offset=start).reshape(a["count"], stride)
            arr = raw[:, :n * isz].copy().view(dt).reshape(a["count"], n)
        else:
            arr = np.frombuffer(binc, dt, count=a["count"] * n, offset=start).reshape(a["count"], n)
        if a.get("normalized"):
            arr = arr.astype(np.float32) / np.iinfo(dt).max
        return arr

    out = {"meshes": []}
    skin_bones = None
    if js.get("skins"):
        sk = js["skins"][0]
        skin_bones = [js["nodes"][j]["name"] for j in sk["joints"]]
    out["bones"] = skin_bones
    for node in js["nodes"]:
        if "mesh" not in node:
            continue
        mesh = js["meshes"][node["mesh"]]
        names = (mesh.get("extras") or {}).get("targetNames", [])
        for prim in mesh["primitives"]:
            at = prim["attributes"]
            V = _y2z(acc(at["POSITION"]).astype(float))
            F = acc(prim["indices"]).reshape(-1, 3).astype(np.int64)
            rec = {"name": node.get("name", mesh.get("name")), "V": V, "F": F,
                   "material": js["materials"][prim["material"]]["name"] if "material" in prim else None}
            if "JOINTS_0" in at:
                rec["joints"] = acc(at["JOINTS_0"]).astype(int)
                rec["weights"] = acc(at["WEIGHTS_0"]).astype(float)
            if "TEXCOORD_1" in at:
                rec["uv2"] = acc(at["TEXCOORD_1"]).astype(float)
            if "COLOR_0" in at:
                rec["color"] = acc(at["COLOR_0"]).astype(float)
            rec["morphs"] = {}
            for k, t in enumerate(prim.get("targets", [])):
                nm = names[k] if k < len(names) else "target_%d" % k
                rec["morphs"][nm] = _y2z(acc(t["POSITION"]).astype(float))
            out["meshes"].append(rec)
    return out


def merged(m):
    """All primitives as one mesh: V, F, joints, weights, morphs (only targets every primitive has), prim id per
    vertex."""
    Vs, Fs, Js, Ws, pid = [], [], [], [], []
    base = 0
    names = None
    for i, r in enumerate(m["meshes"]):
        n = set(r["morphs"])
        names = n if names is None else names & n
    for i, r in enumerate(m["meshes"]):
        Vs.append(r["V"])
        Fs.append(r["F"] + base)
        Js.append(r.get("joints", np.zeros((len(r["V"]), 4), int)))
        Ws.append(r.get("weights", np.zeros((len(r["V"]), 4))))
        pid.append(np.full(len(r["V"]), i))
        base += len(r["V"])
    morphs = {k: np.concatenate([r["morphs"][k] for r in m["meshes"]]) for k in sorted(names or [])}
    return np.concatenate(Vs), np.concatenate(Fs), np.concatenate(Js), np.concatenate(Ws), morphs, np.concatenate(pid)
