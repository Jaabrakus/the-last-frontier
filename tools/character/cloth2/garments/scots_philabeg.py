"""The philabeg (cloth2 recipe type wrap_skirt with pleats: cloth2.dress.WRAP_SKIRT): the Highland little kilt of
tartan worsted, wrapped round the waist and belted, two flat aprons in front (the right over the left), loose pleats
laid in from the hips round the back, to the knee. Part of the Highland dress (a set any character may wear)."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["madder_red", "deep_green", "stroud_blue", "full_green", "logwood_black", "indigo_mid", "deep_yellow", "drab"]
SETT = {"options": ["plaid", "none", "check"], "default": "plaid",
        "plaid": {"sett": "madder_red", "scale_m": 0.16},
        "check": {"colors": ["logwood_black", "linen_white"], "scale_m": 0.012},
        "note": "a 'hard tartan' worsted: our own setts (assets/character/fabrics/setts.json), not registered or "
                "clan tartans; its sett aligned with the plaid's (scots_plaid_shoulder)"}

SPEC = Spec(
    id="scots_philabeg", name="Philabeg (little kilt)", set="highland", slot="legs.lower",
    layer={"default": 30, "hips": 35},
    description="A tartan little kilt wrapped round the waist and belted, two flat aprons in front, the right over "
                "the left, loose pleats from the hips round the back, to the knee.",
    history="By the 1720s-40s many Highlanders wore the philabeg, the little kilt cut from the lower half of the "
            "belted plaid: two flat aprons wrapped over in front, the pleats laid in at the belt from the hips round "
            "the back, the hem at the knee, of 'hard tartan' worsted [EU-H2][EU-H3]. It was banned in Scotland with "
            "the rest of Highland dress from 1747 to 1782 [EU-H1].",
    zones=[Zone(0, "tartan", "cloth", "WOOL", PAL, "madder_red", pattern=SETT),
           Zone(1, "waistband", "trim", "WOOL", PAL, "madder_red")],
    sources=["EU-H2", "EU-H3", "EU-H1"], evidence="A", tags=["men", "women", "highland"], budget=6000,
    over=["shirt_linen", "shift_linen"],
    extra={"presets": {"red_sett": {"0": "madder_red", "1": "madder_red"},
                       "green_sett": {"0": "deep_green", "1": "deep_green", "sett": "hill_green"},
                       "hodden": {"0": "drab", "1": "drab", "sett": "drab_hodden"}},
           "set_note": "The Highland dress is a clothing set (the owner, 2026-10-03), not a people: offered to everyone.",
           "recipe_note": "cloth2.dress.wrap_skirt: top 1.04 (a 3 cm band), hem 0.53 front / 0.55 behind, the overlap "
                          "edge at -18 deg (the right apron over the left), pleats from 55 to 180 deg (14 folds 1.2 cm "
                          "deep, growing to the hem), little flare; the closed-skirt weights.",
           "references": ["[EU-H2] Burt via https://en.wikipedia.org/wiki/Arisaid",
                          "[EU-H3] Pennant 1769: https://www.dsl.ac.uk/entry/snd/tunag"]})

STYLE = dress._style(dress.WRAP_SKIRT, {"top": 1.04, "band": 0.030, "band_h": 0.003, "hem": 0.53, "side_hem": 0.545,
                                        "flare": 0.075, "folds": 0.003, "steps": 10, "tail_gap": 0.032,
                                        "pleats": [(117.5, 125.0, 14, 0.012)],
                                        "overlap": {"deg": -18.0, "outer": 1, "w": 0.05, "h": 0.0025, "split": True},
                                        "over": ("shirt_linen", "shift_linen")})


def build(g):
    recipes.wrap_skirt(g, STYLE)


build_and_export = G.runner(SPEC, build)
