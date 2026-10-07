"""Shared data of the Thủy Vân garments (sets tv_highland, tv_stone, tv_delta, tv_river, tv_courts, tv_halls,
tv_common; peoples_design.md sections 2.9 and 3). Not a garment (the build skips modules starting with _).

The dyes are the `tv_*` entries of cloth2/palette.json (peoples_dyes.json's `mid`; their 4-stop ramps are in
assets/thuyvan/dress/dress_paint.json's source, peoples_dyes.json). Each garment's `extra` carries:
  "tv_paint":  {zone: painted value map} (assets/thuyvan/dress/paint/<kit>.png: weave, hemp, felt, leather, fur,
               straw, cord, metal, bone): the hand-painted cloth the zone's dye ramp is laid over
  "tv_motif":  {zone: {"motif": name, "threads": [dye, dye, dye], "scale_m": [u, v]}} a woven band
               (assets/thuyvan/dress/motifs/<name>.png: RGB = the three thread dyes over the zone's own dye)
  "presets":   named dye sets (clan dyes are proposals: Stone-Ridge, Cloud-Pass, High-Pine)
These are data for the Thủy Vân cloth material (the lead's lane); the cloth shader of the frontier ignores them.

Anyone may wear any garment: a set orders the Outfit tab and sets NPC defaults, it never locks dress to a people.
"""

HIGHLAND = ["tv_indigo_black", "tv_madder", "tv_hemp", "tv_bone", "tv_pine_black", "tv_ochre", "tv_jade_cloth",
            "tv_walnut", "tv_fur_grey"]
STONE = ["tv_charcoal", "tv_dust_buff", "tv_leather", "tv_ochre_banner", "tv_quarry_white", "tv_kiln_brick", "tv_jade",
         "tv_slate_plate", "tv_walnut", "tv_hemp"]
DELTA = ["tv_dock_indigo", "tv_salt_white", "tv_estuary_teal", "tv_deep_navy", "tv_sea_glass", "tv_pearl",
         "tv_lacquer_red", "tv_gold", "tv_straw", "tv_rope", "tv_walnut"]
METALS = ["tv_bronze", "tv_gold", "tv_bone", "tv_jade"]

# the Mountain Folk clans' dyes (proposals, owner question 5): ground, bands
CLANS = {"stone_ridge": ("tv_indigo_black", "tv_madder"),
         "cloud_pass": ("tv_bone", "tv_jade_cloth"),
         "high_pine": ("tv_pine_black", "tv_ochre")}

BAND = {"motif": "band_motif", "threads": ["tv_bone", "tv_indigo_black", "tv_ochre"], "scale_m": [0.12, 0.12]}
HOUSE = {"motif": "house_mark", "threads": ["tv_quarry_white", "tv_charcoal", "tv_charcoal"], "scale_m": [0.16, 0.06]}
QUILT = {"motif": "quilting", "threads": ["tv_lacquer_black", "tv_bone", "tv_bone"], "scale_m": [0.12, 0.12]}
TIDE = {"motif": "tide_scroll", "threads": ["tv_sea_glass", "tv_pearl", "tv_pearl"], "scale_m": [0.10, 0.10]}

DESIGN_SOURCE = ("Design: Thủy Vân peoples_design.md (2026-10-06), after the owner's concept sheets; shapes and colours "
                 "only, no sheet pixels; our own marks (straight cuts, at most one ring).")


def clan_presets(zones=("0", "1")):
    """The three clan dye presets on a garment's ground and band zones."""
    return {k: {zones[0]: g, zones[1]: b} for k, (g, b) in CLANS.items()}


def extra(paint, motif=None, presets=None, note="", **kw):
    """A tv garment's `extra`: the painted value map per zone, the woven motifs, the dye presets, the recipe note."""
    out = {"tv_paint": {str(k): v for k, v in paint.items()}, "design_source": DESIGN_SOURCE}
    if motif:
        out["tv_motif"] = {str(k): v for k, v in motif.items()}
    if presets:
        out["presets"] = presets
    if note:
        out["recipe_note"] = note
    out.update(kw)
    return out
