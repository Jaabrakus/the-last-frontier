"""Wide trousers, the men's salvar (cloth2 recipe type trousers, kind wide: cloth2.dress.TROUSERS): gathered on a
rolled drawstring at the waist, the crotch hanging low, the legs very full at the knee and narrowing into an ankle
band. Tag pants."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["undyed_brown", "slate_grey", "indigo_mid", "logwood_black", "scarlet", "stroud_blue", "cotton_white",
       "linen_unbleached"]

SPEC = Spec(
    id="salvar_mens", name="Salvar (wide trousers)", set="middle_east", slot="legs.lower", layer={"default": 30},
    description="Wide woollen trousers gathered on a rolled drawstring at the waist, the crotch hanging low, the legs "
                "very full at the knee and narrowing into an ankle band.",
    history="The Ottoman, Levantine, Armenian and Egyptian men's trousers were cut very wide, of wool broadcloth or "
            "a coarse woollen (red broadcloth for the better-off, camlet in summer), drawn on a cord at the waist, the "
            "seat hanging low and the legs gathered into a band at the ankle; the Persian and Kurdish kind were "
            "narrower, 'loose ... without any tight ligaments' [NIE][RUS][HAN][CHE].",
    zones=[Zone(0, "wool", "cloth", "WOOL", PAL, "undyed_brown"),
           Zone(1, "drawstring band and ankle bands", "trim", "WOOL", PAL, "undyed_brown")],
    hides_force=["pelvis_center", "pelvis_side", "abdomen_front", "abdomen_side", "abdomen_back", "thigh_upper_l",
                 "thigh_upper_r"],
    sources=["NIE", "RUS", "HAN", "CHE"], evidence="A",
    tags=["men", "women", "pants", "middle_east", "ottoman_turkish", "levantine", "armenian", "egyptian", "arab",
          "moorish", "persian", "kurdish"],
    budget=7000, over=["shirt_collarless"],
    extra={"presets": {"brown": {"0": "undyed_brown", "1": "undyed_brown"},
                       "indigo": {"0": "indigo_mid", "1": "indigo_mid"},
                       "red_broadcloth": {"0": "scarlet", "1": "scarlet"}},
           "shirt_note": "Over the shirt's body at the waist; the collarless shirt's tails hang outside over the "
                         "legs (under the entari), or wear a tucked shirt.",
           "styles_note": "Styles to build from the same recipe: narrow (Persian, drop ~0.10, hem open at 0.08), knee "
                          "(Moroccan linen, hem 0.40), cakshir (to 0.06, sewn to yellow leather socks).",
           "recipe_note": "cloth2.dress.trousers kind wide: the legs eased up to 7 cm more at the knee and meeting at "
                          "the midline down to it (the low-hanging crotch's look; the crotch itself lowered 3 cm and "
                          "bridged as the slops'), soft folds round each leg, the rolled band 1.025-1.06, the ankle "
                          "bands gathered.",
           "references": ["[NIE] Niebuhr: https://archive.org/details/b28773263_0001",
                          "[RUS] Russell: https://archive.org/details/naturalhistoryof01russ",
                          "[HAN] Hanway: https://archive.org/details/b30414702_0001",
                          "[CHE] Chenier: https://archive.org/details/b28771515_0001"]})

# (fitted over the shirt's body above the hips only: a long shirt's tails hang outside over the legs, or a tucked
# shirt ends inside the band; pushed over the tails, the crotch tore out through them)
STYLE = dress._style(dress.TROUSERS, {"over": ("shirt_collarless",), "over_above": 0.88, "seat": 0.010,
                                      "flare": [(0.18, 0.0), (0.32, 0.032), (0.50, 0.070), (0.70, 0.058),
                                                (0.84, 0.022), (0.92, 0.0)]})


def build(g):
    recipes.trousers(g, STYLE)


build_and_export = G.runner(SPEC, build)
