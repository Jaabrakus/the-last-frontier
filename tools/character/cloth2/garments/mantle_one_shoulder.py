"""The mantle over one shoulder (cloth2 recipe type drape, anchor one_shoulder: cloth2.dress.DRAPE): a large cloth
about 2.2 x 1.1 m across the back, over the right shoulder and down in front, passing under the left arm, which is
left bare; its upper edge runs from the right shoulder down across the breast to the left hip."""

from cloth2 import dress
from cloth2 import garment as G
from cloth2 import recipes
from cloth2.spec import Spec, Zone

PAL = ["indigo_mid", "cotton_white", "indigo_pale", "stroud_blue", "straw", "madder_red", "yellow", "logwood_black"]
PATTERN = {"options": ["none", "stripe", "check"], "default": "stripe",
           "stripe": {"colors": ["indigo_mid", "cotton_white", "indigo_pale"], "scale_m": 0.16},
           "check": {"colors": ["indigo_mid", "cotton_white", "yellow"], "scale_m": 0.08},
           "note": "strip cotton, or silk-and-cotton strip cloth for the better-off (no named Akan kente or adinkra "
                   "designs: plain strips and checks only)"}

SPEC = Spec(
    id="mantle_one_shoulder", name="Mantle (over one shoulder)", set="africa", slot="accessories.wrap",
    layer={"default": 50},
    description="A large cotton cloth across the back and over the right shoulder, passing under the left arm and "
                "across the breast, the left arm bare, hanging to above the knee.",
    history="Over the wrapper Gold Coast and Gambian men threw a large cloth across the back and over one shoulder, "
            "the other arm left free; the better-off wore a larger one of silk-and-cotton strips. Equiano remembered "
            "it 'somewhat in the form of a highland plaid ... usually dyed blue' [AF-A2][AF-A4][AF-C1].",
    zones=[Zone(0, "strip cotton", "cloth", "LIN", PAL, "indigo_mid", pattern=PATTERN)],
    sources=["AF-A2", "AF-A4", "AF-C1"], evidence="A",
    tags=["men", "women", "africa", "west_african", "central_african"], budget=5000,
    over=["shift_linen", "wrapper_knee"],
    extra={"presets": {"strip_indigo": {"0": "indigo_mid"}, "white": {"0": "cotton_white", "pattern": "none"},
                       "blue": {"0": "stroud_blue", "pattern": "none"}},
           "styles_note": "Styles from the same recipe: large (about 2.6 x 1.6 m, lower), plaid (wound round the body). "
                          "M-L for Kongo commoners.",
           "recipe_note": "cloth2.dress.drape anchor one_shoulder: the envelope over the shoulders (the right "
                          "shoulder's cap in it above 1.17, no arms below), cut to its outline; the rolled top edge raised 2.8 mm; "
                          "below 0.95 it swings with the skirt panels.",
           "animation_note": "The left arm is bare and free; the cloth over the right shoulder follows the right "
                             "shoulder and upper arm.",
           "references": ["[AF-A2] Moore: https://archive.org/details/travelsintoinlan00moor",
                          "[AF-A4] Equiano, Interesting Narrative: https://www.gutenberg.org/ebooks/15399",
                          "[AF-C1] Fromont 2017: https://revistas.usp.br/anaismp/article/view/139689"]})

# (over the right shoulder's cap only, then under the arm: from the elbow down the cloth stood out from the arm as a
# shelf in the bind pose)
STYLE = dress._style(dress.DRAPE, {"over": ("shift_linen", "wrapper_knee"), "arm_z": 1.17})


def build(g):
    recipes.drape(g, STYLE)


build_and_export = G.runner(SPEC, build)
