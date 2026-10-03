"""The skullcap (cloth2 recipe: recipes.soft_cap kind skullcap): a small close cap on the crown, of white cotton,
felt or red cloth; worn alone or as the core under a turban."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["cotton_white", "undyed_white_wool", "undyed_brown", "scarlet", "indigo_mid", "madder_red", "logwood_black"]

SPEC = Spec(
    id="skullcap", name="Skullcap", set="africa", slot="head", layer={"default": 80},
    description="A small close cap on the crown of the head, of white cotton, felt or red cloth.",
    history="A close cap was worn across West Africa (Moore's white cotton caps on the Gambia), in every Middle "
            "Eastern people (white or brown felt, the red cap of North Africa) and by Muslim Ethiopians, alone or "
            "under the turban [AF-A2][LAN][SHA].",
    zones=[Zone(0, "cap", "cloth", "LIN", PAL, "cotton_white")],
    hides_hair_zones=["crown"], sources=["AF-A2", "LAN", "SHA"], evidence="A",
    tags=["men", "women", "africa", "middle_east", "west_african", "ethiopian", "north_african", "kurdish", "arab",
          "egyptian", "levantine", "ottoman_turkish"], budget=1200,
    extra={"presets": {"white_cotton": {"0": "cotton_white"}, "felt": {"0": "undyed_white_wool"},
                       "red": {"0": "scarlet"}, "indigo": {"0": "indigo_mid"}},
           "status_note": "Feathers and goat-tail tufts on West African caps marked status: not offered as free "
                          "picks.",
           "fabric_note": "LIN for cotton (COT kit later); a felt preset reads with the WOOL kit's nap via the id "
                          "only for hats: the zone fabric stays LIN.",
           "references": ["[AF-A2] Moore: https://archive.org/details/travelsintoinlan00moor"]})


def build(g):
    recipes.soft_cap(g, "skullcap")
    dress.arc_uv(g)


build_and_export = G.runner(SPEC, build)
