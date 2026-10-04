"""The Actor_B skeleton as a text record (actor_b_skeleton.json), read from the body glb.

The body build needs the rig library (Actor_B_001.blend + the null-add bind clip) only for the
skeleton: bone names, parents and the bind pose. body.glb carries all of it (export_def_bones off:
all 291 bones; export_rest_position_armature: the rest IS null-add), so the skeleton is kept here
and make_rig_blend.py rebuilds the rig from it (user 2026-10-03: "can we build a exact identical rig?").
Same skeleton, same lineage as before: lib/rig.py PROVENANCE_RIG.

    python3 tools/character/rig/extract_skeleton.py [body.glb] [out.json]
"""

import json
import os
import struct
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
FRONTIER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
GLB = os.path.join(FRONTIER, "assets", "character", "body", "body.glb")
# the build's record of the rig's own bone order (deform_bones: the rig's bones the body is weighted to, in rig order);
# the glb's joints are in the exporter's order (roots by name), and the build processes the bones in the rig's
RECORD = os.path.join(FRONTIER, "assets", "character", "body", "body.json")
OUT = os.path.join(HERE, "actor_b_skeleton.json")


def trs(node):
    x, y, z, w = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    R = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                  [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                  [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    m = np.eye(4)
    m[:3, :3] = R * np.array(node.get("scale", [1.0, 1.0, 1.0]))
    m[:3, 3] = node.get("translation", [0.0, 0.0, 0.0])
    return m


def rig_order(nodes, joints, parent, record=RECORD):
    """The joints depth first, parents first, with the roots and each bone's children ordered so the bones in the
    record's deform_bones come in its order (a subtree by the first of them it holds; the others after, as they were)."""
    rank = {n: i for i, n in enumerate(json.load(open(record))["deform_bones"])} if os.path.exists(record) else {}
    jset = set(joints)
    kids = {}
    for i in joints:
        p = parent.get(i)
        kids.setdefault(p if p in jset else None, []).append(i)
    first = {}

    def lead(i):
        if i not in first:
            first[i] = min([rank.get(nodes[i]["name"], len(rank) + 1)] + [lead(c) for c in kids.get(i, [])])
        return first[i]

    out = []

    def walk(i):
        out.append(i)
        for c in sorted(kids.get(i, []), key=lambda c: (lead(c), joints.index(c))):
            walk(c)

    for r in sorted(kids[None], key=lambda c: (lead(c), joints.index(c))):
        walk(r)
    seen = [nodes[i]["name"] for i in out if nodes[i]["name"] in rank]
    assert seen == sorted(seen, key=rank.get), "deform_bones is not a depth-first order of the skeleton"
    return out


def main(glb=GLB, out=OUT):
    d = open(glb, "rb").read()
    n = struct.unpack("<I", d[12:16])[0]
    g = json.loads(d[20:20 + n])
    nodes = g["nodes"]
    joints = g["skins"][0]["joints"]       # the rig's bone order (parents first, depth first)
    parent = {c: i for i, nd in enumerate(nodes) for c in nd.get("children", [])}
    rig_node = next(i for i in g["scenes"][0]["nodes"] if "skin" not in nodes[i] and "children" in nodes[i])
    assert np.allclose(trs(nodes[rig_node]), np.eye(4)), "the armature node must be at the origin"
    glob = {}

    def world(i):
        if i not in glob:
            p = parent.get(i)
            glob[i] = trs(nodes[i]) if p is None or p == rig_node else world(p) @ trs(nodes[i])
        return glob[i]

    jset = set(joints)
    joints = rig_order(nodes, joints, parent)
    bones = []
    for i in joints:
        p = parent.get(i)
        bones.append({"name": nodes[i]["name"],
                      "parent": nodes[p]["name"] if p in jset else None,
                      # global rest, Godot / glTF space (Y up), row-major 4x4; the rows' last 0 0 0 1 left out
                      "rest": [round(float(v), 9) for v in world(i)[:3].reshape(-1)]})
    rec = {"source": os.path.relpath(glb, FRONTIER),
           "note": "Actor_B skeleton (names, parents, bind pose null-add as the rest), read from the body glb by "
                   "extract_skeleton.py; make_rig_blend.py builds the rig .blend the character generators run on.",
           "provenance": "Skeleton, bone names and bind pose: Actor_B rig (lib/rig.py PROVENANCE_RIG).",
           "armature": nodes[rig_node]["name"], "space": "godot", "bones": bones}
    with open(out, "w") as f:
        json.dump(rec, f, indent=0)
    print("%d bones -> %s" % (len(bones), out))


if __name__ == "__main__":
    main(*sys.argv[1:3])
