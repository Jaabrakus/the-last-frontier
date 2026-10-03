"""The apron (cloth2 recipe: recipes.apron): a working apron of linen gathered on a narrow band at the waist, tied
behind in a bow, wrapping the front of the petticoat to below the knee. It moves with the petticoat's closed-skirt
panels."""

import numpy as np

from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import settlers as ST
from cloth2.mesh import smoothstep
from cloth2.parts import closed_skirt_weights
from cloth2.spec import Spec, Zone

SPEC = Spec(
    id="apron", name="Apron", set="colonial", slot="accessories.waist", layer={"default": 35},
    description="A linen apron gathered on a narrow band round the waist and tied behind in a bow, covering the front "
                "of the petticoat to below the knee.",
    history="Women wore an apron over the petticoat for almost all work: white or checked linen, gathered to a band "
            "with ties, long enough to cover most of the petticoat's front (the Fort Ticonderoga guidelines discourage "
            "very short or narrow ones) [S6][S9]. Blue-and-white check linen was common in rural Pennsylvania German "
            "households [S9].",
    zones=[Zone(0, "apron", "cloth", "LIN", ["linen_white", "linen_unbleached", "check_blue", "tow"], "linen_white",
                pattern={"options": ["none", "check"],
                         "check": {"colors": ["check_blue", "linen_white"], "scale_m": 0.012,
                                   "note": "blue-and-white check linen"}}),
           Zone(1, "band and ties", "trim", "LIN", ["linen_white", "linen_unbleached", "check_blue", "tow"],
                "linen_white")],
    sources=["S6", "S9", "M2"], evidence="A", tags=["women", "colonial", "settlers"], budget=1600,
    over=["shift_linen", "stays_laced", "petticoat"],
    extra={"presets": {"margaretha": {"0": "check_blue", "1": "linen_white", "pattern": "check"},
                       "anna": {"0": "linen_white", "1": "linen_white"}},
           "pattern_note": "The check is stored on zone 0 (the cloth shader does not draw zone patterns yet: until it "
                           "does a check apron renders in its base colour).",
           "references": ["https://fortticonderoga.org/wp-content/uploads/2024/06/Zipped-1759-Siege-of-Carillon-French-Women-Guidelines.pdf",
                          "https://goschenhoppen.org/colonial-clothing/"]})

STYLE = recipes.style(recipes.APRON, over=tuple(SPEC.over), band=(1.004, 1.030), hem=0.34, edge_angle=72.0,
                      folds=0.008, steps=10)


def build(g):
    # recipes.apron's cut, its skirt hung from the band's lower edge only (the recipe's tails() would also take the
    # top edge of a band 3 cm tall: a second skirt folded down over the band, a zigzag under it)
    st = STYLE
    g.shell(G.TORSO)
    g.top(st["band"][1]).bottom(st["band"][0])
    g.seams(back=True, limbs=())
    g.fit(ease=st["ease"], gap=0.01)
    g.tails(hem=st["hem"], side_hem=st["hem"] + 0.02, flare=st["flare"], folds=st["folds"], steps=st["steps"],
            z_full=st["z_full"], gap=st["gap"], x_limit=0.5, edge_angle=st["edge_angle"], edge_z=st["band"][0] - 0.012)
    g.over(st["over"], st["over_gap"])
    g.zone(st["zones"]["band"], above=st["band"][0] + 0.002)
    # the ties: knotted in a bow at the centre back over the band, the ends hanging down the petticoat
    zc = (STYLE["band"][0] + STYLE["band"][1]) / 2.0
    P = g.around_points(zc, np.array([180.0]))
    if len(P):
        k = P[0]
        ST.bow(g, k, 1, size=0.032, up=(0.0, 0.0, 1.0), tails=0.0, lift=0.001)
        for dx, ln in ((0.012, 0.17), (-0.016, 0.14)):
            way = [k + np.array([dx, 0.0, -0.012]), k + np.array([dx * 1.6, 0.01, -ln * 0.5]),
                   k + np.array([dx * 2.0, 0.02, -ln])]
            g.strap(way, 0.016, 0.034, 1, step=0.012)
    # (more room over the petticoat's front just under the band: the thighs lift it there when the hips bend)
    g.over(SPEC.over, lambda P: 0.004 + 0.016 * smoothstep(0.66, 0.80, P[:, 2]) * (1.0 - smoothstep(0.965, 1.0, P[:, 2])) *
           (P[:, 1] < 0.0))
    # weighted like the petticoat under it (its own weights where the apron lies on it), then handed to the six
    # closed-skirt panels as skirt_hang.py hands the petticoat's
    ST.weights_from(g, "petticoat", lambda P: P[:, 2] < STYLE["band"][0] - 0.002)
    closed_skirt_weights(g.fits, g.m)
    g.uv(axis_top=1.05, axis_bottom=0.3, limbs=())


build_and_export = G.runner(SPEC, build)
