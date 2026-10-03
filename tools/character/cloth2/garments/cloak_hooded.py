"""The hooded cloak (cloth2: draped over the clothes by cloth2.drift.envelope, the hood from cloth2.hood): a woman's
wool cloak, most commonly red, gathered at the neck and closed there with ribbon ties, over the shoulders and hanging
behind the arms to the knee, its hood thrown back and lying on the shoulders."""

import numpy as np

from cloth2 import drift as D
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import hood as HD
from cloth2 import settlers as ST
from cloth2.spec import Spec, Zone

UNDER = ["shift_linen", "stays_laced", "petticoat", "apron", "kerchief_womens", "jacket_womens"]
SPEC = Spec(
    id="cloak_hooded", name="Hooded cloak", set="colonial", slot="accessories.wrap", layer={"default": 50},
    description="A wool cloak gathered at the neck and closed with ribbon ties, over the shoulders and hanging behind "
                "the arms to the knee, its hood thrown back.",
    history="Women's outerwear was a wool cloak, most commonly red, closed with ties (not metal clasps), from waist to "
            "mid-calf in length, often hooded (the Fort Ticonderoga guidelines) [S6][M2].",
    zones=[Zone(0, "cloak", "cloth", "WOOL", ["madder_red", "stroud_red", "slate_grey", "stroud_blue", "walnut_brown",
                                              "drab", "logwood_black"], "madder_red"),
           Zone(1, "ties", "ribbon", "FLAT", ["ribbon_black", "ribbon_red", "linen_white", "ribbon_white"],
                "ribbon_black")],
    sources=["S6", "M2"], evidence="B", tags=["women", "colonial", "settlers", "winter"], budget=3000, over=UNDER,
    extra={"presets": {"margaretha": {"0": "madder_red", "1": "ribbon_black"},
                       "anna": {"0": "slate_grey", "1": "ribbon_black"}},
           "references": ["https://fortticonderoga.org/wp-content/uploads/2024/06/Zipped-1759-Siege-of-Carillon-French-Women-Guidelines.pdf"],
           "male_body_note": "Built for every fit; on a man it is artistic licence."})

Z_C = 1.21
YOKE_E = 38.0                  # the front edge's angle round from the front over the shoulders (it closes at the neck)
ARM_Z = 1.11                   # the cloak over the arm ends here; below it hangs behind the arms
BODY_E = 110.0                 # the front edge below ARM_Z
HEM_EDGE, HEM_BACK = 0.64, 0.60
TIES_Z = 1.29


def build(g):
    from cloth2.garment import built
    fits = g.fits
    under = [built(fits, gid)[0] for gid in UNDER]
    with_arms = D.hit_bvhs(fits, arms=True, meshes=under)
    no_arms = D.hit_bvhs(fits, arms=False, meshes=under)
    z_level = [1.18, 1.15, 1.12] + list(np.arange(1.085, HEM_BACK - 0.04, -0.036))
    rows = D.cape_rows(z_c=Z_C, phi=(20.0, 90.0), n_polar=8, z_rows=z_level)
    arms = [True] * 8 + [z >= ARM_Z - 0.005 for z in z_level]
    hits_by_row = [with_arms if a else no_arms for a in arms]
    thetas = np.linspace(2.0, 358.0, 45)
    m, _ = D.envelope(g, rows, thetas, None, 0.010, smooth=3, hits_by_row=hits_by_row, drape=0.004,
                      folds=(0.014, 8.0, 1.0), flare=(0.04, 1.0), weight_arms=arms)
    g.m = m
    zr = np.array([z for z, _ in rows])
    e_row = np.where(zr >= ARM_Z - 0.005, YOKE_E, BODY_E)
    e_row[:8] = YOKE_E - (YOKE_E - 4.0) * (1.0 - np.linspace(0.0, 1.0, 8)) ** 1.5     # gathered round to the throat
    e_v = np.interp(g.m.A["_row"], np.arange(len(rows)), e_row)
    th = g.m.A["_th"]
    g.m = g.m.clip(np.minimum(th - e_v, 360.0 - e_v - th), 0.0)
    th = g.m.A["_th"]
    back = np.abs(th - 180.0) / (180.0 - BODY_E)
    hem = HEM_BACK + (HEM_EDGE - HEM_BACK) * np.clip(back, 0.0, 1.0) ** 1.5
    g.m = g.m.clip(g.P[:, 2] - hem, 0.0)
    D.hang_weights(fits, g.m, 0.95)
    D.drop_attrs(g.m)
    g.fits.clear(g.m, 0.003)
    g.over(UNDER, 0.005)
    # the hood thrown back, lying on the shoulders
    HD.hood_on_back(g, tip_z=0.98, half_w=0.155, h_max=0.038, h_neck=0.018, roll=0.008, zone=0)
    g.over(UNDER, 0.004)
    # the ties at the throat: a bow where the two fronts meet, and its ends
    P = g.P
    cand = np.nonzero(P[:, 1] < -0.02)[0]
    if len(cand):
        i = cand[np.argmin(np.abs(P[cand, 0]) + 0.6 * np.abs(P[cand, 2] - TIES_Z))]
        ST.bow(g, P[i], 1, size=0.03, up=(0.0, 0.0, 1.0), tails=0.08, tail_w=0.011, lift=0.002)
        # (its tails lie on the breast: kept clear of the jacket and kerchief under them)
        g.over(UNDER, 0.003, where=lambda Q: (Q[:, 1] < -0.02) & (Q[:, 2] > 1.12) & (np.abs(Q[:, 0]) < 0.08))
    ST.settle_gauge(g)
    g.hem_below(0.75)
    g.uv(axis_top=1.45, axis_bottom=0.5, limbs=())


build_and_export = G.runner(SPEC, build)
