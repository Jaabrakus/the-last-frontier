"""Fabric codes, bible palette tokens, zone roles and Blender preview materials.

The runtime look comes from the shaders in assets/character/shaders (cloth, skin, eye,
hair, fur); Blender materials only name the surfaces (the glb material name is the
surface name the runtime and the checks use) and colour the Workbench previews.

TOKENS: the costume bible §0.4 palette (hex values are the bible's estimates chosen by
eye, not colourimetry). assets/character/palettes.json (fabric workstream) is the
runtime source once it exists; this table lets generators write default hex colours
into catalog fragments and colour previews.
"""

from .remesh import material

# Bible texture codes -> approved Poly Haven kit (assets/polyhaven/textures/clothing/) and
# its physical tile size in metres (design §2.4).
FABRICS = {
    "LIN": ("rough_linen", 0.271), "WOOL": ("caban", 0.274), "TWILL": ("poly_wool_herringbone", 0.270),
    "KNIT": ("knitted_fleece", 0.266), "SUEDE": ("scuba_suede", 0.285), "LEA": ("brown_leather", 0.400),
    "FUR": ("curly_teddy_natural", 0.336), "HES": ("hessian_230", 0.269), "MET": (None, 0.0), "FLAT": (None, 0.0),
}

TOKENS = {
    "linen_unbleached": "#C8BA9A", "linen_white": "#E8E3D3", "tow": "#A99570", "check_blue": "#2F4166",
    "madder_red": "#8E2B21", "scarlet": "#A8161E", "stroud_red": "#8A1C1F", "stroud_blue": "#1E2B4A",
    "indigo_mid": "#34507A", "royal_blue": "#233C78", "ranger_green": "#3B4A2E", "full_green": "#2E5134",
    "deep_green": "#213A2A", "buff": "#D2B98A", "pale_buff": "#DCCAA0", "yellow": "#D0A93A", "pale_yellow": "#D8C675",
    "deep_yellow": "#C38E26", "orange": "#C0632A", "white_facing": "#E4DECC", "grey_white": "#D4D0C3",
    "drab": "#8B7A5C", "walnut_brown": "#5A3F2C", "butternut": "#957549", "snuff": "#6E4B2E",
    "logwood_black": "#1C1B20", "slate_grey": "#6B6A66", "buckskin_smoked": "#A07E55", "buckskin_pale": "#C8AA7C",
    "leather_black": "#1D1B19", "leather_brown": "#5B3D26", "white_buff": "#E6E0D0", "silver": "#C8CACC",
    "brass": "#B58F4A", "pewter": "#9A9C9A", "gold_lace": "#C9A54B", "silver_lace": "#CFD2D4", "false_gold": "#B89445",
    "ribbon_red": "#B2202C", "ribbon_green": "#2E6B40", "ribbon_yellow": "#D8B23A", "ribbon_blue": "#2D4F8C",
    "ribbon_white": "#ECE8DE", "ribbon_black": "#151417", "quill_red": "#A8262A", "quill_orange": "#C8672A",
    "quill_yellow": "#D2AE3C", "quill_black": "#1A1918", "quill_white": "#E7E2D2", "bead_white": "#EEEBE3",
    "bead_blue": "#3B5E9E", "vermilion": "#D0342C", "fur_black_bear": "#1F1A16", "fur_brown_bear": "#4B3526",
    "fur_beaver": "#5A3B25", "fur_wolf": "#7F776B", "fur_raccoon": "#6A6259", "fur_red_fox": "#A5532B",
}
METALS = {"silver", "brass", "pewter", "gold_lace", "silver_lace", "false_gold"}

# Zone roles the shaders understand (catalog "role").
ROLES = ["cloth", "lining", "trim", "band", "button", "metal", "leather", "fur", "fringe", "hair", "ribbon",
         "wrap", "skin", "quill", "bead"]


def token_hex(tok):
    if tok.startswith("#"):
        return tok
    return TOKENS[tok]


def preview_material(name, token_or_hex, rough=0.8):
    tok = token_or_hex
    return material(name, token_hex(tok), rough, 1.0 if tok in METALS else 0.0)
