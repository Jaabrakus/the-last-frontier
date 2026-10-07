"""Bold A/B/C variants of the Thủy Vân garments, for the owner to choose by eye (peoples_design.md section 5: fringe
length, hip-panel layers, hat brim width, clan dyes). Each is a style patch on the garment module's STYLE (the module's
build(g, st) takes it); `A` is always the garment as built. Dye variants need no geometry: dress_render.py recolours.

    variant_build(mod, gid, key) -> build(g)
"""

import copy


def _patch(base, **kw):
    s = copy.deepcopy(base)
    for k, v in kw.items():
        if isinstance(v, dict) and isinstance(s.get(k), dict):
            s[k] = dict(s[k], **v)
        else:
            s[k] = v
    return s


VARIANTS = {
    "tv_mf_shoulder_mantle": {
        "B": lambda st: _patch(st, fringe={"len": (0.14, 0.24)}, hem=(1.14, 1.08)),
        "C": lambda st: _patch(st, tiers=2, tier2={"drop": 0.09, "len": (0.10, 0.18)}),
    },
    "tv_mf_hip_panels": {
        "B": lambda st: _patch(st, rims=[(0.86, 0.006)], hem=0.62),
        "C": lambda st: _patch(st, rims=[(0.94, 0.005), (0.85, 0.005), (0.76, 0.005)], hem=0.56),
    },
    "tv_conical_hat": {
        "B": lambda st: _patch(st, R=0.27, H=0.14),
        "C": lambda st: _patch(st, R=0.31, H=0.12),
    },
    "tv_sc_quarry_hat": {
        "B": lambda st: _patch(st, R=0.28, H=0.14),
        "C": lambda st: _patch(st, R=0.21, H=0.17),
    },
}


def variant_build(mod, gid, key):
    fn = VARIANTS[gid][key]
    st = fn(mod.STYLE)

    def build(g):
        mod.build(g, st)
    return build
