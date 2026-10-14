"""A small numpy reader for the character glbs (no Blender, no Godot): a mesh primitive's attributes, its triangles and
its shape-key deltas, and the skin's joint names and node tree.

    from glb_read import Glb
    g = Glb("assets/character/body/body.glb")
    p = g.prim("Body")              # {"POSITION": (n, 3), "TEXCOORD_0": (n, 2), ..., "indices": (t, 3)}
    d = g.target("Body", "sex")     # (n, 3) POSITION delta of the shape key "sex"

The glb's space is Godot skeleton space (+Y up, the character faces +Z), as body.json says.
"""
import json
import struct

import numpy as np

_COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
_NUM = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Glb:
    def __init__(self, path):
        data = open(path, "rb").read()
        if data[:4] != b"glTF":
            raise ValueError("%s is not a glb" % path)
        jlen = struct.unpack("<I", data[12:16])[0]
        self.js = json.loads(data[20:20 + jlen])
        off = 20 + jlen
        blen = struct.unpack("<I", data[off:off + 4])[0]
        self.bin = data[off + 8:off + 8 + blen]

    def accessor(self, i):
        a = self.js["accessors"][i]
        bv = self.js["bufferViews"][a["bufferView"]]
        dt = np.dtype(_COMP[a["componentType"]])
        n = _NUM[a["type"]]
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", 0) or dt.itemsize * n
        raw = np.frombuffer(self.bin, dtype=np.uint8, count=stride * (a["count"] - 1) + dt.itemsize * n, offset=start)
        rows = np.lib.stride_tricks.as_strided(raw, shape=(a["count"], dt.itemsize * n), strides=(stride, 1))
        arr = np.ascontiguousarray(rows).view(dt).reshape(a["count"], n)
        if a.get("normalized"):
            arr = arr.astype(np.float32) / float(np.iinfo(dt).max)
        return arr if n > 1 else arr[:, 0]

    def mesh(self, name):
        for m in self.js["meshes"]:
            if m["name"] == name:
                return m
        raise KeyError(name)

    def prim(self, name, index=0):
        p = self.mesh(name)["primitives"][index]
        out = {k: self.accessor(v) for k, v in p["attributes"].items()}
        out["indices"] = self.accessor(p["indices"]).reshape(-1, 3).astype(np.int64)
        return out

    def target_names(self, name):
        return self.mesh(name).get("extras", {}).get("targetNames", [])

    def target(self, name, key, index=0):
        names = self.target_names(name)
        p = self.mesh(name)["primitives"][index]
        return self.accessor(p["targets"][names.index(key)]["POSITION"])

    def joint_names(self, skin=0):
        return [self.js["nodes"][j].get("name") for j in self.js["skins"][skin]["joints"]]
