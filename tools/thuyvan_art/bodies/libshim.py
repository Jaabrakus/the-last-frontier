"""Import tools/character/lib from plain python3 (outside Blender) for the numpy-only parts: sdf, body_shapes, face,
weights.deform_segments / smooth_weights / limit_normalize / chain_weights, helpers' tables.

Inside Blender the real bpy / bmesh / mathutils are used. Outside, stub modules stand in for them so the lib's
module-level imports succeed; any function that really needs Blender fails loudly when called. The lib itself is
imported unchanged (it is the body workstream's; generators import it and never edit it).
"""

import os
import sys
import types

HERE = os.path.dirname(os.path.abspath(__file__))
CHARACTER_TOOLS = os.path.normpath(os.path.join(HERE, "..", "..", "character"))
if CHARACTER_TOOLS not in sys.path:
    sys.path.insert(0, CHARACTER_TOOLS)
if HERE not in sys.path:
    sys.path.insert(0, HERE)

try:
    import bpy  # noqa: F401
    IN_BLENDER = True
except ImportError:
    IN_BLENDER = False


class _Missing:
    def __init__(self, name):
        self._name = name

    def __getattr__(self, k):
        return _Missing(self._name + "." + k)

    def __call__(self, *a, **kw):
        raise RuntimeError("%s needs Blender" % self._name)


def _stub(name):
    m = types.ModuleType(name)
    m.__getattr__ = lambda k, _n=name: _Missing(_n + "." + k)
    sys.modules[name] = m
    return m


if not IN_BLENDER:
    for _n in ("bpy", "bmesh", "mathutils", "mathutils.bvhtree", "mathutils.kdtree"):
        if _n not in sys.modules:
            _stub(_n)
    sys.modules["mathutils"].bvhtree = sys.modules["mathutils.bvhtree"]
    sys.modules["mathutils"].kdtree = sys.modules["mathutils.kdtree"]
