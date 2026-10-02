"""Reading and writing glTF binaries for the wildlife tools (numpy only): accessors in and out, the binary chunk
compacted to what is still referenced."""

import json
import struct

import numpy as np

CT = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8, 5122: np.int16, 5120: np.int8}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
NORM = {5121: 255.0, 5123: 65535.0}


def read_glb(path):
    f = open(path, "rb").read()
    n = struct.unpack("<I", f[12:16])[0]
    j = json.loads(f[20:20 + n])
    o = 20 + n
    bl = struct.unpack("<I", f[o:o + 4])[0]
    return j, bytearray(f[o + 8:o + 8 + bl])


def accessor(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    dt = np.dtype(CT[a["componentType"]])
    nc = NC[a["type"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 0) or dt.itemsize * nc
    raw = np.frombuffer(bytes(b[start:start + stride * (a["count"] - 1) + dt.itemsize * nc]), np.uint8)
    out = np.lib.stride_tricks.as_strided(raw, (a["count"], dt.itemsize * nc), (stride, 1)).copy()
    arr = out.view(dt).reshape(a["count"], nc)
    if a.get("normalized") and a["componentType"] in NORM:
        arr = arr.astype(np.float32) / NORM[a["componentType"]]
    return arr


def add_accessor(j, b, arr, ctype, typ, target=None, minmax=False):
    while len(b) % 4:
        b.append(0)
    data = np.ascontiguousarray(arr.astype(CT[ctype])).tobytes()
    bv = {"buffer": 0, "byteOffset": len(b), "byteLength": len(data)}
    if target:
        bv["target"] = target
    b.extend(data)
    j["bufferViews"].append(bv)
    a = {"bufferView": len(j["bufferViews"]) - 1, "componentType": ctype, "count": int(len(arr)), "type": typ}
    if minmax:
        a["min"] = [float(v) for v in arr.min(0)]
        a["max"] = [float(v) for v in arr.max(0)]
    j["accessors"].append(a)
    return len(j["accessors"]) - 1


def compact(j, b):
    """The binary chunk rebuilt from the buffer views still referenced (replaced data dropped)."""
    used = {a["bufferView"] for a in j["accessors"] if "bufferView" in a}
    used |= {im["bufferView"] for im in j.get("images", []) if "bufferView" in im}
    remap, nb, views = {}, bytearray(), []
    for i in sorted(used):
        bv = dict(j["bufferViews"][i])
        while len(nb) % 4:
            nb.append(0)
        s = bv.get("byteOffset", 0)
        data = b[s:s + bv["byteLength"]]
        bv["byteOffset"] = len(nb)
        nb.extend(data)
        remap[i] = len(views)
        views.append(bv)
    j["bufferViews"] = views
    for a in j["accessors"]:
        if "bufferView" in a:
            a["bufferView"] = remap[a["bufferView"]]
    for im in j.get("images", []):
        if "bufferView" in im:
            im["bufferView"] = remap[im["bufferView"]]
    j["buffers"][0]["byteLength"] = len(nb)
    return nb


def write_glb(path, j, b):
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    while len(b) % 4:
        b.append(0)
    total = 12 + 8 + len(js) + 8 + len(b)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<I", len(js)) + b"JSON" + js)
        f.write(struct.pack("<I", len(b)) + b"BIN\x00" + bytes(b))
