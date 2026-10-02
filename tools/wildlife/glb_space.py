"""glTF helpers for the wildlife tools (numpy only): a skinned mesh's vertices in scene space at rest (each joint's
rest world matrix times its inverse bind matrix; the mesh node's own transform is ignored for a skinned mesh, as
glTF says), node world matrices, joint names.
"""

import numpy as np


def _local(n):
    if "matrix" in n:
        return np.array(n["matrix"], float).reshape(4, 4).T
    t = np.array(n.get("translation", [0, 0, 0]), float)
    x, y, z, w = n.get("rotation", [0, 0, 0, 1])
    R = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                  [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                  [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    s = np.array(n.get("scale", [1, 1, 1]), float)
    M = np.eye(4)
    M[:3, :3] = R * s
    M[:3, 3] = t
    return M


def world_matrices(j):
    parent = {}
    for i, n in enumerate(j["nodes"]):
        for c in n.get("children", []):
            parent[c] = i
    W = {}

    def w(i):
        if i not in W:
            W[i] = (w(parent[i]) if i in parent else np.eye(4)) @ _local(j["nodes"][i])
        return W[i]
    for i in range(len(j["nodes"])):
        w(i)
    return W


def mesh_to_scene(j, accessor, b, node_i):
    """4x4 from the mesh's own space to scene space at rest (skinned: the first joint's world x inverse bind)."""
    W = world_matrices(j)
    n = j["nodes"][node_i]
    if "skin" in n:
        sk = j["skins"][n["skin"]]
        ib = accessor(j, b, sk["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
        return W[sk["joints"][0]] @ ib[0]
    return W[node_i]
