"""The knee-length wrapper (cloth2 recipe type wrap_skirt: cloth2.dress.WRAP_SKIRT): a rectangle of cotton about
2.0 x 0.62 m wound one and a half times round the waist, its top rolled into a band, the overlap at the front open
from the hem to the band so that a stride parts it. The West African man's cloth; the Yemeni futa, the South Indian
lungi, the Malay kain sarong over the drawers (the waist slot)."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["indigo_mid", "cotton_white", "stroud_blue", "indigo_pale", "straw", "tukula_red", "madder_red", "check_blue"]
PATTERN = {"options": ["none", "stripe", "check"], "default": "stripe",
           "stripe": {"colors": ["indigo_mid", "cotton_white", "indigo_pale"], "scale_m": 0.16},
           "check": {"colors": ["madder_red", "indigo_mid", "cotton_white"], "scale_m": 0.05},
           "note": "hand-spun narrow-strip cotton: strips about 0.16 m wide sewn edge to edge, indigo and white "
                   "(strip_seams once the shader draws them); check and stripes; raffia panels for Kongo"}

SPEC = Spec(
    id="wrapper_knee", name="Wrapper (knee length)", set="africa", slot="legs.lower",
    layer={"default": 30, "hips": 35}, alt_slots=["accessories.waist"],
    description="A cotton cloth wound one and a half times round the waist, its top rolled into a band, hanging to "
                "the knee, the overlap open at the front.",
    history="On the Gambia and the Gold Coast men wore a cloth of narrow-strip cotton wrapped round the waist to the "
            "knee, often indigo and white, the better-off a longer and finer one; in Kongo raffia panels sewn side by "
            "side. The same plain rectangle, told apart by its cloth, was the Yemeni futa, the South Indian lungi and "
            "the Malay sarong worn over drawers [AF-A2][AF-C3][NIE][SA7][ML1].",
    zones=[Zone(0, "cotton", "cloth", "LIN", PAL, "indigo_mid", pattern=PATTERN),
           Zone(1, "rolled band", "trim", "LIN", PAL, "indigo_mid")],
    sources=["AF-A2", "AF-C3", "NIE", "SA7", "ML1"], evidence="A",
    tags=["men", "women", "africa", "west_african", "central_african", "arab", "south_asian", "malay"], budget=5000,
    over=["shift_linen", "shirt_linen"],
    extra={"presets": {"strip_indigo": {"0": "indigo_mid", "1": "indigo_mid"},
                       "white": {"0": "cotton_white", "1": "cotton_white", "pattern": "none"},
                       "raffia": {"0": "straw", "1": "straw", "pattern": "none"},
                       "futa_check": {"0": "madder_red", "1": "madder_red", "pattern": "check"}},
           "recipe_note": "cloth2.dress.wrap_skirt: the petticoat's shell from 1.035 (a 3.2 cm band rolled 6 mm proud), "
                          "hem 0.44, flare 0.05; the overlap's edge at -30 deg (the wearer's right front) split from "
                          "the hem to the band with a 4.5 cm fold raised on its outer side; the closed-skirt weights, "
                          "each side of the edge on its own leg's front panel (dress.slit_weights).",
           "references": ["[AF-A2] Moore, Travels into the Inland Parts of Africa: https://archive.org/details/travelsintoinlan00moor",
                          "[NIE] Niebuhr: https://archive.org/details/b28773263_0001"]})

STYLE = dress._style(dress.WRAP_SKIRT, {"hem": 0.44, "flare": 0.05, "folds": 0.010, "tail_gap": 0.032,
                                        "over": ("shift_linen", "shirt_linen")})


def build(g):
    recipes.wrap_skirt(g, STYLE)


build_and_export = G.runner(SPEC, build)
