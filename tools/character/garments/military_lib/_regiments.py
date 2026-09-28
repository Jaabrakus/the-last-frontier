"""Regimental distinctions for the coats' colour zones (costume bible §5.1-5.3 tables).

British regiments that served in the northeast, 1755-1763: facing colour, lace (white
worsted tape with coloured stripes: `stripes` = [token, position across 0..1, width 0..1])
and button metal. Where the bible records no lace pattern the tape is plain white
(marked "lace_recorded": False). French troupes de terre: cuff / veste colours and button
metal. Palette tokens are the bible's §0.4 (lib.materials.TOKENS).

These are data for the customizer's colour zones and presets; the geometry is the same
coat for every regiment.
"""

BRITISH_FACINGS = ["yellow", "pale_yellow", "deep_yellow", "buff", "pale_buff", "white_facing", "orange",
                   "full_green", "deep_green", "royal_blue", "logwood_black", "madder_red"]


def _r(num, facing, lace=None, buttons="pewter", note="", src=("P5",), grade="A"):
    return {"id": "foot_%s" % num, "name": "%s Foot" % num, "facing": facing,
            "lace": {"base": "linen_white", "stripes": lace or []}, "lace_recorded": lace is not None,
            "buttons": buttons, "note": note, "sources": list(src), "evidence": grade}


BRITISH_REGIMENTS = [
    _r("15th", "yellow", [["ribbon_black", 0.30, 0.14], ["ribbon_yellow", 0.62, 0.14]], "pewter",
       "Lace black and yellow.", ("P5", "M5")),
    _r("17th", "white_facing", note="Greyish-white facings."),
    _r("22nd", "buff"),
    _r("27th", "buff", note="Inniskilling: castle badge."),
    _r("28th", "yellow", [["ribbon_yellow", 0.25, 0.10], ["ribbon_black", 0.50, 0.10], ["ribbon_yellow", 0.75, 0.10]],
       "pewter", "Lace with yellow and black lines and black spots (spots not drawn).", ("P5", "M5")),
    _r("35th", "orange", [["ribbon_black", 0.28, 0.14], ["orange", 0.62, 0.18]], "pewter",
       "Lace black and orange with an orange zigzag (drawn as a stripe).", ("P5", "M5")),
    _r("40th", "buff"),
    _r("42nd", "buff", note="Highland regiment: buff facings, blue after it became Royal in July 1758 "
                            "(Highland jacket and plaid are separate items).", src=("P5", "R6")),
    _r("43rd", "white_facing", [["ribbon_red", 0.30, 0.12], ["ribbon_blue", 0.62, 0.12]], "pewter",
       "Lace with red lines and blue devices (devices drawn as a stripe).", ("P5", "M5")),
    _r("44th", "yellow", note="With the 48th in Braddock's army, 1755."),
    _r("45th", "deep_green"),
    _r("46th", "yellow"),
    _r("47th", "white_facing", note="In 1759 wore the 50th and 51st's clothing after its own was captured.",
       src=("P5", "M5")),
    _r("48th", "buff", [["ribbon_green", 0.30, 0.13], ["ribbon_yellow", 0.62, 0.13]], "pewter",
       "Lace green and yellow.", ("P5", "M5")),
    _r("58th", "logwood_black", [["ribbon_yellow", 0.5, 0.35]], "brass", "Yellow lace, brass buttons.", ("M5",)),
    _r("60th", "royal_blue", [], "pewter", "Royal American Regiment: no lace for the men.", ("R23",), "A"),
]
BRITISH_REGIMENTS[-1]["lace_recorded"] = True
BRITISH_REGIMENTS[-1]["lace"] = None                   # no lace: the loops take the coat colour

FRENCH_TERRE = [
    {"id": "la_reine", "name": "La Reine", "cuffs": "madder_red", "veste": "madder_red", "breeches": "grey_white",
     "buttons": "silver"},
    {"id": "guyenne", "name": "Guyenne", "cuffs": "madder_red", "veste": "madder_red", "breeches": "grey_white",
     "buttons": "brass"},
    {"id": "berry", "name": "Berry", "cuffs": "madder_red", "veste": "madder_red", "breeches": "grey_white",
     "buttons": "brass", "note": "Five cuff buttons; double vertical pockets (not modelled)."},
    {"id": "bearn", "name": "Béarn", "cuffs": "royal_blue", "veste": "royal_blue", "breeches": "grey_white",
     "buttons": "silver", "note": "Vertical pockets (not modelled)."},
    {"id": "la_sarre", "name": "La Sarre", "cuffs": "royal_blue", "veste": "madder_red", "breeches": "grey_white",
     "buttons": "brass"},
    {"id": "royal_roussillon", "name": "Royal-Roussillon", "cuffs": "royal_blue", "veste": "royal_blue",
     "breeches": "grey_white", "buttons": "brass", "note": "Six cuff buttons."},
    {"id": "languedoc", "name": "Languedoc", "cuffs": "royal_blue", "veste": "royal_blue", "breeches": "grey_white",
     "buttons": "brass"},
]
for _e in FRENCH_TERRE:
    _e.update({"coat": "grey_white", "sources": ["M5", "M4", "R9"], "evidence": "A"})
