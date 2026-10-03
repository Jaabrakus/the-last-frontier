"""Sea boots (cloth2, the Drift crews' set): greased-leather boots to below the knee, a round toe and a low heel, the
tops turned down to show the flesh side, a strap over the instep with a brass buckle. Grown round the body's own leg
and foot (cloth2.drift.boot: the covered cloth surface stops at the ankle)."""

import numpy as np

from cloth2 import drift as D
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2.mesh import REF, BIG_FIELD, smoothstep
from cloth2.spec import Spec, Zone

TOP = 0.45                     # the turned-down top's fold (below the knee joint, 0.468)
TURN = 0.36                    # the turned-down top's lower edge
ROWS = [TOP, 0.42, 0.39, TURN, 0.33, 0.29, 0.25, 0.21, 0.175, 0.145, 0.12, 0.101, 0.085, 0.071, 0.058, 0.046,
        0.035, 0.026, 0.017, 0.010, 0.0045]

SPEC = Spec(
    id="sea_boots", name="Sea boots", set="drift", slot="feet", layer={"default": 40},
    description="Greased-leather boots to below the knee with a round toe and a low heel, the tops turned down, a "
                "strap and brass buckle over the instep.",
    history="Common seamen mostly went barefoot aboard or wore the square-toed shoes of the day ashore and in "
            "foul weather [D1]; leather sea boots were the fisherman's and the officer's. In the Drift, where the "
            "decks are cold above the clouds, the crews that can afford them wear them (artistic licence, evidence "
            "C): the deckhand and rigger still go barefoot for the rigging.",
    zones=[Zone(0, "leather", "leather", "LEA", ["leather_black", "leather_brown", "tar_black"], "leather_black"),
           Zone(1, "turned-down top", "leather", "SUEDE", ["leather_brown", "buff", "buckskin_smoked", "leather_black"],
                "leather_brown"),
           Zone(2, "buckles", "metal", "MET", ["brass", "pewter"], "brass", metal=True),
           Zone(3, "sole and heel", "leather", "LEA", ["leather_brown", "leather_black", "walnut_brown"], "walnut_brown")],
    sources=["D1"], evidence="C", tags=["drift", "sailor"], budget=3200, over=["breeches"],
    extra={"presets": {"black": {"0": "leather_black", "1": "leather_brown"},
                       "rook_brown": {"0": "leather_brown", "1": "buckskin_smoked", "3": "walnut_brown"}},
           "references": ["[D1] HMS Richmond, Sailor's Dress of 1775: https://hmsrichmond.org/sailordress.htm"],
           "fit_note": "Fitted over the breeches' knee band; under the slops' wide hem.",
           "budget_note": "3,200 (2,800 planned): the turned-down tops' rims and the instep straps."})


def ease(z):
    # the foot close, the shaft a little looser up the calf, the top over the breeches' knee band
    return 0.0045 + 0.0035 * smoothstep(0.10, 0.30, z) + 0.0018 * (1.0 - smoothstep(0.0, 0.035, z))


def build(g):
    from cloth2.garment import built
    obs = [built(g.fits, "breeches")[0]]
    pieces = [D.boot(g, s, ROWS, cols=20, ease=ease, obstacles=obs, part=10 + i) for i, s in enumerate("lr")]
    g.m = None
    for p in pieces:
        g.add(p)
    g.fits.clear(g.m, 0.003)
    g.over(SPEC.over, 0.004)
    # the turned-down top: the band from TURN to the top, raised, with a rim at its lower edge
    g.raised(lambda P: np.maximum(TURN - P[:, 2], -1.0) * 3.0, 0.0035, 1)
    # the sole edge and the heel: the bottom of the wall and the sole itself
    J = g.fits.J
    def heel(P):
        hy = np.where(P[:, 0] > 0, J["l_heel"][1], J["r_heel"][1])
        return np.minimum(P[:, 2] - 0.010, np.maximum(P[:, 2] - 0.026, (hy - 0.065) - P[:, 1]))
    g.zone(3, below=0.010)
    sel = g.select(heel)
    g.m.fa["zone"][sel] = 3
    g.m.fa["zone"][(g.m.fa["part"] == 12) | (g.m.fa["part"] == 13)] = 3
    # the instep strap (a band over the instep, slanting down and back) and its buckle on the outer side
    for s, sg in (("l", 1.0), ("r", -1.0)):
        A = J[s + "_ankle"]
        c = np.array([A[0], A[1] - 0.040, 0.070])
        n = np.array([0.0, 0.55, 0.835])
        g.raised(lambda P, c=c, n=n: np.abs((P - c) @ n) - 0.0095 + BIG_FIELD * smoothstep(0.075, 0.09, np.abs(P[:, 0] - c[0])) +
                 BIG_FIELD * (1.0 - smoothstep(0.014, 0.02, P[:, 2])) + BIG_FIELD * smoothstep(0.12, 0.13, P[:, 2]),
                 0.0022, 0)
        O = np.array([[A[0] + sg * 0.15, A[1] - 0.035, 0.068]])
        hit, ok = HW.ray_points(g.m, O, [[-sg, 0.0, 0.0]], 0.2)
        if ok[0]:
            g.hardware(hit[:1], HW.frame(0.024, 0.021, 0.0035, 0.0028), 2, up=(0.0, -0.55, 0.835), lift=0.0022)
    g.hem_below(0.02)
    g.uv(limbs=())
    J0 = g.fits.J
    for i, s in enumerate("lr"):
        g.uvparts[10 + i] = ("cyl", J0[s + "_knee"], J0[s + "_ankle"], [0.0, -1.0, 0.0])
        g.uvparts[12 + i] = ("planar", J0[s + "_ankle"], [1.0, 0.0, 0.0], [0.0, 1.0, 0.0])


build_and_export = G.runner(SPEC, build)
