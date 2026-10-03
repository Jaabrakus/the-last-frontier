"""Cut hose (cloth2 recipe: stockings with gartering, cloth2.dress.hose): Highland hose of cloth cut on the bias,
in a red-and-white dicing, from the toes to below the knee, the top turned down into a cuff and a garter tape tied
under it with its ends hanging at the outer side. Part of the Highland dress (a set any character may wear)."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["madder_red", "linen_white", "stroud_blue", "full_green", "logwood_black", "slate_grey", "deep_green"]
DICING = {"options": ["none", "check", "plaid"], "default": "check",
          "check": {"colors": ["madder_red", "linen_white"], "scale_m": 0.036, "angle": 45.0},
          "plaid": {"sett": "madder_red", "scale_m": 0.12, "angle": 45.0},
          "note": "dicing: a check cut on the bias (45 deg); or the plaid's own sett"}

SPEC = Spec(
    id="scots_hose_cut", name="Cut hose (Highland)", set="highland", slot="legs.over", layer={"default": 10},
    description="Hose of woollen cloth cut on the bias in a red-and-white dicing, from the toes to below the knee, "
                "the top turned down into a cuff and a garter tied under it, its ends hanging at the outer side.",
    history="With the philabeg and the plaid Highlanders wore short hose of tartan or diced cloth cut on the bias "
            "and sewn, reaching to below the knee and gartered there, the top turned down (the NMS kilt suit's hose; "
            "Burt describes the dress in the 1720s-30s) [EU-H2][EU-H5b]. Highland dress was banned in Scotland 'for "
            "man or boy' from 1747 to 1782 (soldiers exempt; the Act did not run in America) [EU-H1].",
    zones=[Zone(0, "cloth", "cloth", "WOOL", PAL, "madder_red", pattern=DICING),
           Zone(1, "garter", "ribbon", "WOOL", ["madder_red", "linen_white", "logwood_black", "stroud_blue",
                                                "ribbon_red"], "madder_red")],
    sources=["EU-H2", "EU-H5b", "EU-H1"], evidence="A", tags=["men", "women", "highland"], budget=4000,
    extra={"presets": {"dicing": {"0": "madder_red", "1": "madder_red"},
                       "sett": {"0": "madder_red", "1": "linen_white", "pattern": "plaid"},
                       "plain": {"0": "stroud_blue", "1": "madder_red", "pattern": "none"}},
           "set_note": "The Highland dress is a clothing set (the owner, 2026-10-03), not a people: offered to everyone.",
           "law_note": "Dress Act 1747-82 (Scotland only; soldiers exempt): historical context, never enforced.",
           "recipe_note": "cloth2.dress.hose: SockTube to 0.46, the top 4 cm raised 2.4 mm (the turned-down cuff), "
                          "a garter band at 0.414-0.428 raised 3.2 mm with two ends of 6 / 4.8 cm hanging at the outer "
                          "side.",
           "references": ["[EU-H2] Burt via https://en.wikipedia.org/wiki/Arisaid",
                          "[EU-H5b] NMS kilt suit: https://nms.ac.uk/explore-our-collections/stories/scottish-history-and-archaeology/highland-style/highland-style-sub-pages/kilt-suit-c1790-1800",
                          "[EU-H1] The Dress Act: https://historyofparliament.com/2020/11/17/banning-scottish-highland-dress-in-the-aftermath-of-culloden/"]})


def build(g):
    recipes.hose(g, dress.HOSE)
    dress.arc_uv(g)


build_and_export = G.runner(SPEC, build)
