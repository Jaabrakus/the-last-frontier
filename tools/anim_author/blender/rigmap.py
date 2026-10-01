"""Godot <-> Blender bone-rotation conversion for the Actor_B armature (assets/character/actor_b_body.glb imported by Blender).

The glb's node rest rotations R_rest[i] are the Godot skeleton's local frames; Blender's importer turns each node into a bone whose
axes are the node's rotated by a constant B[i] (Y-up -> Z-up C, bone pointed at its tail). With E[i] the bone's rest orientation in
armature space (Blender) and G_rest[i] the node's global rest rotation:   E[i] = C * G_rest[i] * B[i].   A pose rotation R (Godot local,
absolute) is then Blender's pose-bone quaternion   Basis = B^-1 * R_rest^-1 * R * B   and back   R = R_rest * B * Basis * B^-1.
"""
import json, struct, math
import bpy
from mathutils import Matrix, Quaternion, Vector

GLB = "/Users/kiwimango/Downloads/Frontier/assets/character/actor_b_body.glb"
C = Matrix.Rotation(math.pi / 2, 3, 'X')          # glTF (Y up) -> Blender (Z up)


def read_glb_json(path=GLB):
    with open(path, "rb") as f:
        f.read(12)
        ln, typ = struct.unpack("<II", f.read(8))
        return json.loads(f.read(ln))


class RigMap:
    def __init__(self, arm):
        self.arm = arm
        g = read_glb_json()
        nodes = g["nodes"]
        self.parent = {}
        for i, n in enumerate(nodes):
            for c in n.get("children", []):
                self.parent[c] = i
        self.rest_q = {}
        self.rest_t = {}
        for i, n in enumerate(nodes):
            r = n.get("rotation", [0, 0, 0, 1])
            self.rest_q[n["name"]] = Quaternion((r[3], r[0], r[1], r[2]))
            self.rest_t[n["name"]] = Vector(n.get("translation", [0, 0, 0]))
        self.grest = {}
        for i, n in enumerate(nodes):
            chain = []
            j = i
            while j is not None:
                chain.append(nodes[j]["name"])
                j = self.parent.get(j)
            q = Quaternion()
            for nm in reversed(chain):
                q = q @ self.rest_q[nm]
            self.grest[n["name"]] = q
        self.B = {}
        for b in arm.data.bones:
            if b.name not in self.grest:
                continue
            E = b.matrix_local.to_3x3().to_quaternion()
            Cq = C.to_quaternion()
            self.B[b.name] = (Cq @ self.grest[b.name]).inverted() @ E

    def to_basis(self, name, q_godot):
        """Godot local rotation (x, y, z, w) -> Blender pose-bone quaternion."""
        R = Quaternion((q_godot[3], q_godot[0], q_godot[1], q_godot[2]))
        B = self.B[name]
        return B.inverted() @ self.rest_q[name].inverted() @ R @ B

    def to_godot(self, name, basis):
        B = self.B[name]
        R = self.rest_q[name] @ B @ basis @ B.inverted()
        return [R.x, R.y, R.z, R.w]

    def to_godot_pos(self, p):
        """Blender armature-space point -> Godot skeleton space."""
        return C.inverted() @ Vector(p)
