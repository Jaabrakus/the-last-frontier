"""Shared bits of the Tidebreak ring dress (tools/asset_author/build_ring_garments.py; cloth2 recipes, set "ring").

Original sport dress for the four element sides of the ring, in the spirit of East and South Asian martial-arts
clothing, Arctic fur-trimmed coats and Himalayan monastic robes: no character's outfit, emblem or insignia copied.
Every garment is cloth2 (grown from the MakeHuman body: both body fits, the bust gauge), so it dresses the player
and the bots, men and women alike.

RING_PALETTE: the ring's own colour tokens (added to cloth2's palette for this build only: the catalog entries carry
their palette_hex, which is what the game reads).
"""

RING_PALETTE = {
    # earth: ochre and moss over deep olive
    "ring_ochre": "#B8893C", "ring_moss": "#5E7A3A", "ring_olive": "#4A5A2E", "ring_olive_dark": "#3E4A27",
    "ring_khaki": "#A89B72", "ring_umber": "#5A4127",
    # water: sea blue, ice, deep navy, snow fur
    "ring_sea": "#2F6DB3", "ring_ice": "#A8CDEB", "ring_deep": "#1E3F6B", "ring_navy": "#18345A",
    "ring_snow_fur": "#E6E1D6", "ring_seal": "#6B6157",
    # fire: flame red, ember, gold, char
    "ring_flame": "#B5302A", "ring_ember": "#6E1A16", "ring_gold": "#D9A441", "ring_char": "#2A1C1A",
    # air: saffron, marigold, cream, rust
    "ring_saffron": "#E39A3B", "ring_marigold": "#EFC44A", "ring_cream": "#EFE3A4", "ring_rust": "#B0602A",
    "ring_tangerine": "#D9762B",
    # shoes
    "ring_sole": "#3A2A1E", "ring_felt": "#2C2826",
}

ELEMENTS = ("earth", "water", "fire", "air")
SET = "ring"
SET_LABEL = "Tidebreak ring dress"
SET_TIP = ("The ring sport's competitors' dress: four sides, each in its element's colours. Our own cuts in the spirit "
           "of martial-arts clothing, Arctic fur-trimmed coats and mountain monasteries.")
HISTORY = ("Invented sport dress (Tidebreak, 2026-10-05): the owner asked for assets in the spirit of an elemental "
           "martial-arts cartoon, made our own. Cut from the cloth2 recipes; no outfit, emblem or insignia copied.")
TAGS = ["men", "women", "ring", "tidebreak"]


def tags(*more):
    return TAGS + list(more)


def install_palette():
    """Adds RING_PALETTE to cloth2's palette for this run (cloth2.spec.PALETTE: Zone.entry reads it)."""
    from cloth2 import spec as SP
    SP.PALETTE.update(RING_PALETTE)
