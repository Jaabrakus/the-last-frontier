"""Build context shared by every generator (body, hair, garments), and the body cache.

    ctx = BuildContext()            # in Blender, on a COPY of Actor_B_001.blend
    ctx.K                           # joint positions at null-add (Skel)
    ctx.bones                       # weight columns: deform bones + driven helpers, rig order
    ctx.body_sdf(P)                 # body SDF for BodyParams P (default female base)
    ctx.body()                      # BodyData: the built full-skin body (cache), see below
    ctx.bind_rig()                  # the export armature (rest = null-add), built once

BodyData (tools/character/cache/body_v<LIB_VERSION>.npz, written by body/body.py):
    V (n, 3) base (female) vertices, F (m, 3) triangles, W (n, len(bones)) final weights
    (twist helpers included), bones, vlab (group label per vertex: torso, neck, head,
    arm_l, hand_l, leg_l, foot_l ...), freg (region id per triangle), shapes {name: (n, 3)}
    (sex, face_*).
"""

import os

import bpy
import numpy as np

from . import LIB_VERSION
from .body_shapes import BodyParams, body_groups, body_node
from .helpers import helper_bones
from .rig import BIND_ACTION, BIND_LIB, CHARACTER_TOOLS, FRONTIER, Skel, bind_pose, build_bind_rig, guard_source, load_actions
from .sdf import log
from .weights import deform_segments

CACHE_DIR = os.path.join(CHARACTER_TOOLS, "cache")
ASSETS = os.path.join(FRONTIER, "assets", "character")


def body_cache_path():
    return os.path.join(CACHE_DIR, "body_v%d.npz" % LIB_VERSION)


class BodyData:
    def __init__(self, V, F, W, bones, vlab, freg, shapes):
        self.V, self.F, self.W = np.asarray(V, float), np.asarray(F, int), np.asarray(W, float)
        self.bones = list(bones)
        self.vlab = np.asarray(vlab, dtype=object)
        self.freg = np.asarray(freg, int)
        self.shapes = {k: np.asarray(v, float) for k, v in shapes.items()}

    def save(self, path=None):
        path = path or body_cache_path()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        np.savez_compressed(path, V=self.V, F=self.F, W=self.W.astype(np.float32), bones=np.array(self.bones),
                            vlab=np.array(self.vlab, dtype=str), freg=self.freg,
                            shape_names=np.array(list(self.shapes)),
                            **{"shape_" + k: v.astype(np.float32) for k, v in self.shapes.items()})
        return path

    @staticmethod
    def load(path=None):
        path = path or body_cache_path()
        z = np.load(path, allow_pickle=False)
        shapes = {str(n): z["shape_" + str(n)] for n in z["shape_names"]}
        return BodyData(z["V"], z["F"], z["W"], [str(b) for b in z["bones"]], [str(s) for s in z["vlab"]],
                        z["freg"], shapes)

    def vertex_region(self):
        """Region id per vertex (from the triangles around it; border vertices take the
        smallest id)."""
        r = np.full(len(self.V), 255, int)
        for k in range(3):
            np.minimum.at(r, self.F[:, k], self.freg)
        return r


class BuildContext:
    def __init__(self, guard=True):
        if guard:
            guard_source()
        self.rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
        assert self.rig.matrix_world.is_identity, "rig object transform must be identity"
        missing = load_actions(BIND_LIB, [BIND_ACTION])
        if missing:
            raise SystemExit("bind action not found: %s" % missing)
        self.G, self.base = bind_pose(self.rig)
        self.K = Skel(self.G)
        self.order = [b.name for b in self.rig.data.bones]
        segs = deform_segments(self.K)
        helpers = set(helper_bones())
        missing = helpers - set(self.order)
        if missing:
            raise SystemExit("rig lacks helper bones %s" % sorted(missing))
        self.bones = [n for n in self.order if n in segs or n in helpers]
        self._bind_rig = None
        self._body = None
        self.P_female = BodyParams.female()
        self.P_male = BodyParams.male()
        log("bind pose %s: heada z=%.3f, %d weight bones" % (BIND_ACTION, self.K["heada"][2], len(self.bones)))

    def body_groups(self, P=None):
        return body_groups(self.K, P or self.P_female)

    def body_sdf(self, P=None):
        return body_node(self.body_groups(P))

    def bind_rig(self):
        if self._bind_rig is None:
            self._bind_rig, err, rot = build_bind_rig(self.rig, self.G)
            log("bind rig: %d bones, rest vs null-add max %.2e m / %.4f deg" % (len(self._bind_rig.data.bones), err, rot))
        return self._bind_rig

    def set_body(self, body):
        self._body = body

    def body(self):
        if self._body is None:
            p = body_cache_path()
            if not os.path.exists(p):
                raise SystemExit("no body cache %s: build the body first (build_character.sh --body)" % p)
            self._body = BodyData.load(p)
            if self._body.bones != self.bones:
                raise SystemExit("body cache bones differ from the rig: rebuild the body")
        return self._body
