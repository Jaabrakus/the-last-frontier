"""Linen shirt, costume bible §4.5 `shirt_*` / §2.6 `shirt_check`, `shirt_white`,
`shirt_flannel`: one garment whose fabric (linen or wool flannel), colour and pattern
(plain, blue-and-white check, stripe) are options, so the bible's white, check and flannel
shirts are one catalog item.

Cut: the legacy shirt of actor_b_body.glb (5 mm over the torso, sleeves 6 mm widening to
9.5 mm into a wristband at 93.5 % of elbow -> wrist, about 2.5 cm of linen showing below a
coat cuff) extended into long tails tucked into the breeches (hem at hip level), with a
short standing collar (the neck stock or kerchief goes over it).

Bible: "Linen of every grade, from fine white to coarse check and tow, plus wool shirts"
[M3]; "the collar was short and the wristbands narrow" [M2][M3]. Grade A.
"""

import numpy as np

from lib.sdf import Fn, Inter, Offset, Sub, SymUnion, Union, peval, smoothstep, zslab

from garments.militia import _militia as M

SPEC = M.spec(
    id="shirt_linen", name="Shirt, linen or flannel", slot="shirt", layer={"default": 10},
    zones=[M.MZone(0, "cloth", "LIN",
                   ["linen_white", "linen_unbleached", "tow", "check_blue", "madder_red", "slate_grey", "indigo_mid"],
                   "linen_unbleached", name="shirt", fabrics=["LIN", "HES", "WOOL"],
                   pattern={"options": ["none", "check", "stripe"], "default": "none",
                            "check": {"colors": ["check_blue", "linen_white"], "scale_m": 0.012},
                            "stripe": {"colors": ["check_blue", "linen_white"], "scale_m": 0.006}})],
    description="Full-cut shirt with a short standing collar and narrow wristbands; white, unbleached or checked "
                "linen, or wool flannel for winter.",
    history="Every man's shirt was linen, from fine white to coarse check and tow; wool shirts in winter. Short "
            "collar, narrow wristbands (Fort Ticonderoga guidelines, 1758-59).",
    sources=["M3", "M2", "M15"], budget=4600, tags=["frontier", "regulars", "women"],
    alt_slots=[], extra={"tucked": True})

SHIRT_END = 0.935          # wristband end (fraction of elbow -> wrist)
HEM_Z = 0.855
COLLAR_TOP = 1.336


def shirt_node(ctx):
    """The body offset 5 mm (the collar 5.5 mm), the sleeves 6 mm widening toward the
    wristband: offsets of the real body SDF, so the armpit and the neck base are covered
    exactly where the skin is (the body's own smooth unions). The collar ends at
    COLLAR_TOP round the neck; beside it the shirt covers the tops of the shoulders (the
    trapezius rises to 1.35 m next to the neck on this body). Cuts are rounded."""
    K = ctx.K
    tfs = [(s,) + M.forearm_t(K, s) for s in (1, -1)]

    def roff(X, Y, Z):
        r = 0.005 + 0.0005 * smoothstep(1.285, 1.295, Z)
        for s, t, E, fa, L in tfs:
            tt = t(X, Y, Z)
            q = np.stack(np.broadcast_arrays(X - E[0], Y - E[1], Z - E[2]), -1)
            along = tt * L
            d = np.sqrt(np.maximum((q ** 2).sum(-1) - along ** 2, 0.0))
            arm = (np.sign(X) == s) & (d < 0.075)
            ext = (0.0025 * smoothstep(0.35, 0.86, tt) - 0.0012 * smoothstep(0.86, 0.90, tt)
                   + 0.0016 * smoothstep(0.895, 0.905, tt) + 0.001 * smoothstep(-0.3, 0.0, tt))
            r = r + np.where(arm, ext, 0.0)
        return r
    node = Inter(Offset(M.body_f(ctx), roff, r_max=0.0095), zslab(HEM_Z, 1.362), k=0.003)
    collar_cut = Inter(zslab(COLLAR_TOP, 1.60), M.neck_column(K, lambda Z: np.full(np.shape(Z), 0.074)))
    node = Sub(node, collar_cut, k=0.003)
    return Inter(node, M.wrist_cut(K, SHIRT_END), k=0.003)


def build(ctx):
    K = ctx.K
    mats = M.zone_mats(SPEC)
    node = shirt_node(ctx)
    col_cut = M.neck_column(K, lambda Z: np.full(np.shape(Z), 0.074))

    def vis(P):
        L = np.where(P[:, 2] > 1.27, 0.0125, 0.024)
        for s in (1, -1):
            t, _, _, _ = M.forearm_t(K, s)
            tt = t(P[:, 0], P[:, 1], P[:, 2])
            arm = (np.sign(P[:, 0]) == s) & (np.abs(P[:, 0]) > 0.16)
            L = np.where(arm & (tt > -0.6), 0.020, L)                              # sleeves: round
            L = np.where(arm & (np.abs(tt) < 0.25), 0.017, L)                      # elbows bend
            L = np.where(arm & (tt > 0.8) & (np.abs(P[:, 0]) > 0.25), 0.0125, L)   # wristbands
        rim = np.minimum(np.where(peval(col_cut, P) < 0.01, np.abs(P[:, 2] - COLLAR_TOP), 1.0),
                         np.abs(P[:, 2] - HEM_Z))
        return np.minimum(L, M.rim_sizing([rim], 0.0085, 0.024))
    ob = M.sdf_part(ctx, SPEC.id, node, 0.0028, 1700, mats[0], visible=vis, hidden=0.04, feature_deg=35.0,
                    hidden_below=-0.0016, iters=30)
    M.strip_to_envelope(ctx, ob, "base")
    M.drop_small_islands(ob)
    M.with_mats(ob, mats)
    zones = np.zeros(len(ob.data.polygons), int)
    W = M.body_weights(ctx, ob, smooth=1)
    uv = M.garment_uvs(ctx, ob, "torso")
    # shading: a placket down the front from the collar, the collar's lower edge, wristbands
    V = M.mesh_arrays(ob)
    X, Y, Z = V[:, 0], V[:, 1], V[:, 2]
    col = np.ones(len(V))
    plk = (Y < -0.03) & (Z > 1.17)
    col[plk] *= 1 - 0.22 * np.exp(-(X[plk] / 0.0025) ** 2)
    col *= 1 - 0.18 * np.exp(-((Z - 1.29) / 0.0025) ** 2) * (np.abs(X) < 0.09)
    for s in (1, -1):
        t, _ = M.forearm_param_v(V, K, s)
        m = np.sign(X) == s
        col[m] *= 1 - 0.18 * np.exp(-((t[m] - 0.895) / 0.006) ** 2)
    hides = ["neck_lower", "chest_upper_front", "chest_upper_side", "chest_upper_back", "chest_front", "chest_side",
             "chest_back", "abdomen_front", "abdomen_side", "abdomen_back"]
    for sd in "lr":
        hides += ["upper_arm_" + sd, "forearm_a_" + sd, "forearm_b_" + sd, "forearm_c_" + sd]
    return M.finish(ctx, SPEC, ob, zones, W, uv, hide_candidates=hides, colors=M.rgba(col))
