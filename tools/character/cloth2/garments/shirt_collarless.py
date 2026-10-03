"""The collarless shirt (cloth2 recipe: recipes.shirt with the hem cuts of 2026-10-03): the long white shirt of the
Ottoman, Levantine, Arab and Maghrebi towns, a round collarless neck slit down the front, very wide straight sleeves
hanging open at the wrist, side slits from the hips; tucked into the trousers or worn hanging outside."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["linen_white", "cotton_white", "linen_unbleached", "indigo_pale", "undyed_white_wool"]
PATTERN = {"options": ["none", "stripe", "check"], "default": "none",
           "stripe": {"colors": ["cotton_white", "indigo_pale"], "scale_m": 0.012, "duty": 0.3},
           "check": {"colors": ["cotton_white", "indigo_pale"], "scale_m": 0.010}}

SPEC = Spec(
    id="shirt_collarless", name="Collarless shirt", set="middle_east", slot="shirt", layer={"default": 10},
    alt_slots=[],
    description="A long white shirt with a round collarless neck slit down the front, very wide straight sleeves "
                "hanging open at the wrist and side slits from the hips; tucked into the trousers or worn outside.",
    history="Under the robe the townsmen of the Ottoman lands, the Levant, Arabia, Egypt and Morocco wore a white "
            "linen or cotton shirt, collarless, the neck slit in front, with straight sleeves so wide at the wrist that "
            "they hung open; the better-off had it of silk gauze [NIE][SHA][LAN][CHE]. Women wore the same cut longer "
            "(thob_womens).",
    zones=[Zone(0, "linen or cotton", "cloth", "LIN", PAL, "linen_white", pattern=PATTERN),
           Zone(1, "neck binding", "trim", "LIN", PAL, "linen_white")],
    sources=["NIE", "SHA", "LAN", "CHE"], evidence="A",
    tags=["men", "women", "middle_east", "ottoman_turkish", "levantine", "arab", "armenian", "kurdish", "moorish",
          "egyptian"],
    budget=6000,
    extra={"presets": {"white": {"0": "linen_white", "1": "linen_white"},
                       "cotton": {"0": "cotton_white", "1": "cotton_white"},
                       "striped": {"0": "cotton_white", "1": "cotton_white", "pattern": "stripe"}},
           "worn_note": "Worn outside over the trousers, its tails hanging over them (salvar_mens is fitted over "
                        "its body at the waist only); a tucked shirt is shirt_tucked.",
           "recipe_note": "recipes.shirt with the 2026-10-03 options: hem 0.62 (side slits to 0.80), collar=False, "
                          "band_t=None (no wrist band), front_slit to 1.20, sleeve_wide 0.045 from arm parameter "
                          "0.42 (about 0.50 m round at the wrist).",
           "references": ["[NIE] Niebuhr, Travels through Arabia: https://archive.org/details/b28773263_0001",
                          "[SHA] Shaw, Travels: https://archive.org/details/travelsobservati00shaw",
                          "[LAN] Lane, Modern Egyptians: https://archive.org/details/accountofmanners00lane",
                          "[CHE] Chenier, Morocco: https://archive.org/details/b28771515_0001"]})


def build(g):
    recipes.shirt(g, hem=0.62, side_hem=0.64, sleeve_end=0.965, neck={"a": 0.085, "b": 0.078, "z0": 1.325, "tilt": 17.0},
                  collar=False, band_t=None, slits=[(84.0, 96.0, 0.80)], front_slit={"z0": 1.20, "w": (0.0015, 0.011)},
                  sleeve_wide=0.045, wide_from=0.42, sleeve_ease=(0.006, 0.015), ease=0.0055, flare=0.07,
                  tail_gap=0.030)
    g.collar_zone(1, 0.012)
    g.hem_below(0.70)
    dress.arc_uv(g)


build_and_export = G.runner(SPEC, build)
