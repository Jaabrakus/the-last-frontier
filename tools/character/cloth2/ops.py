"""cloth2 ops shared by the garments: region and limb selection, the standard finishing, the build wrapper."""

import numpy as np

from lib import regions as RG
from cloth2 import export as EX
from cloth2.fit import chain_param
from cloth2.mesh import REF, smoothstep

TORSO = ["neck_lower", "chest_upper_front", "chest_upper_side", "chest_upper_back", "chest_front", "chest_side",
         "chest_back", "abdomen_front", "abdomen_side", "abdomen_back", "pelvis_center", "pelvis_side"]
ARM = {"l": ["upper_arm_l", "forearm_a_l", "forearm_b_l", "forearm_c_l", "wrist_l"],
       "r": ["upper_arm_r", "forearm_a_r", "forearm_b_r", "forearm_c_r", "wrist_r"]}
LEG = {"l": ["thigh_upper_l", "thigh_lower_l", "shin_upper_l", "shin_lower_l", "ankle_l"],
       "r": ["thigh_upper_r", "thigh_lower_r", "shin_upper_r", "shin_lower_r", "ankle_r"]}


def region_mask(mesh, names):
    ids = [RG.REGIONS[n] for n in names]
    return np.isin(mesh.fa["region"], ids)


def limb(fits, mesh, side, kind="arm"):
    """(t along the limb 0..1, distance to its line, is-limb mask) per vertex of `mesh` (reference fit)."""
    chain = fits.arm(side) if kind == "arm" else fits.leg(side)
    t, d = chain_param(mesh.V[REF], chain)
    return t, d, (d < 0.10) & (t > 0.10)


def set_part(mesh, faces, pid):
    mesh.fa["part"][faces] = pid


def run(ctx, fits, spec, build, export=True):
    """build(fits) -> (mesh, uvparts, options for EX.finish); writes the glb and the entry."""
    mesh, uvparts, kw = build(fits)
    return EX.finish(ctx, fits, spec, mesh, uvparts, export=export, **kw)


def dbg(fits, m, label, fit="f"):
    """Diagnostics: how deep the mesh's vertices sit in the body of `fit` after a step (prints when CLOTH2_DEBUG=1)."""
    import os
    if os.environ.get("CLOTH2_DEBUG") != "1":
        return
    d, _, _ = fits.dist(fit, m.V[fit])
    print("DBG %-22s n=%5d faces=%5d  dist min %7.1f mm  <-5mm: %d" % (label, m.n, len(m.F), d.min() * 1000, int((d < -0.005).sum())))
