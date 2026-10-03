"""The thawb (cloth2 recipe type tunic: cloth2.dress.TUNIC): the long pull-over shirt of Arabia and Egypt, the neck
slit down the breast, very wide open sleeves, to the ankles; the slit and the cuffs worked with needlework. Its skirt
hangs round both legs as one (the closed-skirt panels, as the petticoat)."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["indigo_mid", "cotton_white", "stroud_blue", "undyed_brown", "linen_unbleached", "logwood_black", "indigo_pale"]
PATTERN = {"options": ["none", "stripe", "check"], "default": "none",
           "stripe": {"colors": ["indigo_mid", "cotton_white"], "scale_m": 0.020, "duty": 0.25},
           "check": {"colors": ["indigo_mid", "cotton_white"], "scale_m": 0.016},
           "note": "the Yemen highland shirt of linen checked blue and white"}

SPEC = Spec(
    id="thawb", name="Thawb (long shirt)", set="middle_east", slot="shirt",
    layer={"default": 10, "hips": 36, "thighs": 36},
    description="A long pull-over shirt to the ankles, the neck slit down the breast, very wide open sleeves, the "
                "slit and the cuffs worked with needlework.",
    history="The long shirt was the whole dress of the poorer Arabs and Egyptians, men and women: coarse cotton, "
            "indigo-dyed cotton or linen ('blue shirts and drawers'), brown wool for the herders; the neck slit down "
            "the breast, the sleeves wide and hanging open, to the feet in the towns and to mid-calf among herders, "
            "needlework at the slit and the cuffs [LAN][NIE][BUR].",
    zones=[Zone(0, "cotton", "cloth", "LIN", PAL, "indigo_mid", pattern=PATTERN),
           Zone(1, "needlework", "trim", "LIN", PAL + ["madder_red", "yellow", "crimson"], "madder_red")],
    sources=["LAN", "NIE", "BUR"], evidence="A",
    tags=["men", "women", "middle_east", "arab", "egyptian", "levantine"], budget=7000,
    extra={"presets": {"blue": {"0": "indigo_mid", "1": "madder_red"},
                       "white": {"0": "cotton_white", "1": "indigo_mid"},
                       "herder": {"0": "undyed_brown", "1": "undyed_brown"}},
           "recipe_note": "cloth2.dress.tunic: the shirt's shell, sleeves widening by 6 cm toward the wrist (about "
                          "0.6 m round), the skirt from the hips to 0.16 with the closed-skirt weights "
                          "(skirt.closed, hems_godot from the build).",
           "references": ["[LAN] Lane: https://archive.org/details/accountofmanners00lane",
                          "[NIE] Niebuhr: https://archive.org/details/b28773263_0001",
                          "[BUR] Burckhardt, Notes on the Bedouins: https://archive.org/details/notesonbedouins00burcgoog"]})

STYLE = dress._style(dress.TUNIC, {"hem": 0.16, "side_hem": 0.17, "flare": 0.13, "folds": 0.012, "steps": 14,
                                   "slit": {"z0": 1.17, "w": (0.0015, 0.015)},
                                   "sleeves": {"end": 0.955, "ease": (0.008, 0.018), "wide": 0.060, "from": 0.42}})


def build(g):
    recipes.tunic(g, STYLE)


build_and_export = G.runner(SPEC, build)
