"""Peoples: face, skin, eye and hair variation for the customizer and (later) NPCs.

    python3 tools/character/body/peoples.py        # writes assets/character/body/peoples.json
    (build_character.sh --body writes it too)

A *people* is a distribution, not a face: the mean weights of the face features (the
`face_*` shape keys of body.glb, lib/face.py), a within-group spread, and ranges or
frequencies for skin (melanin along "Tone 1-12", undertone, haemoglobin), eye colour, hair
colour, hair texture and period hair styles. Presets are example individuals drawn from
it (two women, two men per people): mean + an individual offset, so no preset is "the"
face of a people, and neighbouring peoples overlap as real populations do.

Grounding. The feature tendencies follow published craniofacial anthropometry (e.g.
L. G. Farkas et al., "International anthropometric study of facial morphology in various
ethnic groups/races", J. Craniofac. Surg. 16 (2005) 615-646; Farkas, "Anthropometry of
the Head and Face", 2nd ed., 1994): nasal breadth, nasal root height and tip projection,
lip (vermilion) height, intercanthal width, palpebral fissure and canthal tilt, upper
lid crease and epicanthus, bizygomatic and bigonial breadth, lower face height and chin
projection. Within-group variation is larger than most between-group differences, so the
means are moderate (|w| <= 0.9 of a feature whose full weight is a few millimetres) and
every feature varies inside each people. Nothing is exaggerated past the measured range:
no caricature (costume bible 1.2).

Names are the peoples' own or neutral geographic names. Colonial context (1750-1765,
Mohawk valley and the wider Atlantic world) is noted per people in `note`.
"""

import json
import math
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "character", "body", "peoples.json"))

# ---------------------------------------------------------------------------
# Features (face_* shape keys) as the UI shows them: key, label, group, sd (within a people)
# ---------------------------------------------------------------------------
FEATURES = [
    ("breadth", "Face breadth (cheekbones)", "Face shape", 0.35),
    ("length", "Lower face height", "Face shape", 0.35),
    ("cheekbones", "Cheekbone projection", "Face shape", 0.35),
    ("midface", "Midface projection", "Face shape", 0.30),
    ("cheek_fullness", "Cheek fullness", "Face shape", 0.40),
    ("prognathism", "Mouth projection", "Face shape", 0.30),
    ("jaw_width", "Jaw breadth", "Jaw and chin", 0.35),
    ("jaw_angle", "Jaw angle", "Jaw and chin", 0.40),
    ("chin_projection", "Chin projection", "Jaw and chin", 0.35),
    ("chin_width", "Chin breadth", "Jaw and chin", 0.35),
    ("chin_height", "Chin height", "Jaw and chin", 0.35),
    ("brow_ridge", "Brow ridge", "Eyes", 0.35),
    ("eye_depth", "Eye depth", "Eyes", 0.30),
    ("eye_tilt", "Canthal tilt", "Eyes", 0.30),
    ("eye_height", "Eye opening", "Eyes", 0.30),
    ("lid_crease", "Upper-lid crease height", "Eyes", 0.30),
    ("lid_fold", "Upper-lid fullness", "Eyes", 0.30),
    ("epicanthus", "Epicanthic fold", "Eyes", 0.25),
    ("under_eye", "Under-eye fullness", "Eyes", 0.30),
    ("nasal_root", "Nasal root height", "Nose", 0.35),
    ("nose_bridge", "Nose bridge", "Nose", 0.35),
    ("nose_hump", "Nose profile (straight / convex)", "Nose", 0.35),
    ("nose_width", "Nose width", "Nose", 0.30),
    ("nose_length", "Nose length", "Nose", 0.35),
    ("nose_tip", "Tip projection", "Nose", 0.35),
    ("nose_upturn", "Tip angle", "Nose", 0.35),
    ("lips_upper", "Upper lip", "Mouth", 0.30),
    ("lips_lower", "Lower lip", "Mouth", 0.30),
    ("mouth_width", "Mouth width", "Mouth", 0.35),
    ("ears", "Ears", "Ears", 0.40),
]
FEATURE_KEYS = ["face_" + f[0] for f in FEATURES]


def feature_table():
    return [{"key": "face_" + k, "label": lab, "group": g, "sd": sd, "min": -1.0, "max": 1.0}
            for k, lab, g, sd in FEATURES]


# ---------------------------------------------------------------------------
# Regional tendencies (mean feature weights); peoples adjust them
# ---------------------------------------------------------------------------
REGION = {
    "europe": {"breadth": -0.25, "length": 0.2, "cheekbones": -0.1, "midface": 0.25, "prognathism": -0.3,
               "chin_projection": 0.3, "brow_ridge": 0.25, "eye_depth": 0.3, "lid_crease": 0.3, "nasal_root": 0.45,
               "nose_bridge": 0.3, "nose_width": -0.35, "nose_length": 0.25, "nose_tip": 0.35, "lips_upper": -0.25,
               "lips_lower": -0.15},
    "woodlands": {"breadth": 0.6, "length": 0.25, "cheekbones": 0.75, "midface": -0.1, "jaw_width": 0.4,
                  "brow_ridge": 0.05, "eye_tilt": 0.25, "eye_height": -0.2, "lid_crease": -0.3, "lid_fold": 0.35,
                  "epicanthus": 0.2, "nasal_root": 0.25, "nose_bridge": 0.35, "nose_hump": 0.35, "nose_width": 0.2,
                  "nose_length": 0.15, "lips_upper": 0.05, "lips_lower": 0.1},
    "africa": {"breadth": 0.1, "prognathism": 0.65, "chin_projection": -0.15, "cheekbones": 0.3, "midface": -0.1,
               "eye_height": 0.15, "eye_tilt": 0.15, "nasal_root": -0.55, "nose_bridge": -0.4, "nose_width": 0.85,
               "nose_length": -0.3, "nose_tip": -0.3, "nose_upturn": 0.15, "lips_upper": 0.8, "lips_lower": 0.85,
               "mouth_width": 0.35, "brow_ridge": 0.0},
    "east_asia": {"breadth": 0.5, "cheekbones": 0.45, "midface": -0.55, "prognathism": 0.25, "jaw_width": 0.25,
                  "chin_projection": -0.25, "brow_ridge": -0.4, "eye_depth": -0.5, "eye_tilt": 0.55,
                  "eye_height": -0.45, "lid_crease": -0.75, "lid_fold": 0.75, "epicanthus": 0.65, "under_eye": 0.25,
                  "nasal_root": -0.7, "nose_bridge": -0.45, "nose_width": 0.35, "nose_length": -0.15,
                  "nose_tip": -0.3, "nose_upturn": 0.2, "lips_upper": 0.15, "lips_lower": 0.25},
    "south_asia": {"breadth": -0.2, "length": 0.25, "eye_depth": 0.25, "brow_ridge": 0.15, "lid_crease": 0.15,
                   "nasal_root": 0.25, "nose_bridge": 0.2, "nose_width": 0.15, "nose_length": 0.3, "nose_tip": 0.1,
                   "lips_upper": 0.25, "lips_lower": 0.3, "chin_projection": 0.0, "prognathism": 0.1},
    "west_asia": {"breadth": -0.15, "length": 0.3, "brow_ridge": 0.35, "eye_depth": 0.35, "lid_crease": 0.1,
                  "nasal_root": 0.55, "nose_bridge": 0.5, "nose_hump": 0.45, "nose_length": 0.45, "nose_tip": 0.25,
                  "nose_upturn": -0.3, "nose_width": 0.0, "lips_upper": 0.0, "lips_lower": 0.1,
                  "chin_projection": 0.15},
    "southeast_asia": {"breadth": 0.4, "cheekbones": 0.4, "midface": -0.4, "prognathism": 0.4, "eye_tilt": 0.3,
                       "eye_height": -0.15, "lid_crease": -0.4, "lid_fold": 0.45, "epicanthus": 0.45,
                       "nasal_root": -0.6, "nose_bridge": -0.45, "nose_width": 0.65, "nose_length": -0.25,
                       "nose_tip": -0.3, "nose_upturn": 0.25, "lips_upper": 0.35, "lips_lower": 0.35},
}


def _mix(*parts):
    """Weighted sum of feature dicts: _mix((0.5, A), (0.5, B), {"x": 0.1})."""
    out = {}
    for p in parts:
        w, d = (1.0, p) if isinstance(p, dict) else p
        for k, v in d.items():
            out[k] = out.get(k, 0.0) + w * v
    return out


def _clean(d):
    return {("face_" + k if not k.startswith("face_") else k): round(max(-1.0, min(1.0, v)), 3)
            for k, v in d.items() if abs(v) > 1e-6}


# Hair styles by sex (ids of assets/character/hair/*.glb). Styles are period-plausible for the
# people; every style stays available to everyone in the customizer.
HAIR = {
    "europe_m": ["hair_queue_ribbon", "hair_club_ribbon", "hair_loose_tied", "hair_cropped_1758"],
    "europe_f": ["hair_pinned_capped", "hair_bun_low", "hair_braid_f"],
    "woodlands_m": ["hair_crown_lock_braided", "hair_crown_lock_silver", "hair_loose_tied", "hair_long_loose"],
    "woodlands_f": ["hair_club_wrapped_f", "hair_braid_f", "hair_long_loose"],
    "africa_m": ["hair_natural_short", "hair_coily_rounded", "hair_cornrows", "hair_cropped_1758"],
    "africa_f": ["hair_cornrows", "hair_coily_rounded", "hair_natural_short"],
    # per people (2026-09-28, the hair push): Chinese men wore the Qing queue (the front shaved, one braid;
    # required from 1645), the women a bun or a braid; Japanese men the chonmage over a shaved pate, the
    # women the dressed shimada or a low knot; Korean men the sangtu topknot, married women the low
    # chignon with a long pin (jjok), girls a long braid
    "chinese_m": ["hair_qing_queue"],
    "chinese_f": ["hair_bun_low", "hair_braid_f"],
    "japanese_m": ["hair_chonmage"],
    "japanese_f": ["hair_shimada_f", "hair_bun_low"],
    "korean_m": ["hair_topknot"],
    "korean_f": ["hair_jjok_f", "hair_braid_f"],
    # many Hindu men shaved the head but for the crown tuft (shikha); others (Sikhs among them) kept the
    # hair long, knotted on the crown under the turban
    "south_asia_m": ["hair_shikha", "hair_topknot", "hair_loose_tied"],
    "south_asia_f": ["hair_braid_f", "hair_bun_low", "hair_long_loose"],
    "west_asia_m": ["hair_shaved", "hair_cropped_1758", "hair_loose_tied"],
    "west_asia_f": ["hair_braid_f", "hair_bun_low", "hair_long_loose"],
    "southeast_asia_m": ["hair_topknot", "hair_loose_tied", "hair_cropped_1758"],
    "southeast_asia_f": ["hair_bun_low", "hair_long_loose", "hair_braid_f"],
    # per people (2026-09-26): Vietnamese men and women wore the hair long, tied in a bun (the
    # men's on the crown); Siamese men and women wore it short (the men's cropped close at the sides,
    # the women's combed up and cut round); Malay men and women knotted long hair (the men's under
    # a headcloth, left out here), the women's in a low bun
    "vietnamese_m": ["hair_topknot", "hair_loose_tied", "hair_long_loose"],
    "vietnamese_f": ["hair_bun_low", "hair_long_loose"],
    "thai_m": ["hair_siamese_crop", "hair_cropped_1758"],
    "thai_f": ["hair_siamese_short_f", "hair_bun_low"],
    "malay_m": ["hair_topknot", "hair_loose_tied", "hair_cropped_1758"],
    "malay_f": ["hair_bun_low", "hair_long_loose"],
    # Pacific Islanders (2026-09-27): the voyages of the 1760s-70s describe Tahitian men with the hair
    # long, tied up in a knot on the crown or worn loose, and many women with it cut short (others long
    # and loose); the same among the other islands with local variety
    "pacific_islander_m": ["hair_topknot", "hair_long_loose", "hair_loose_tied"],
    "pacific_islander_f": ["hair_natural_short", "hair_long_loose", "hair_bun_low"],
    # Middle East and North Africa (2026-09-27; the hair push 2026-09-28): Ottoman, Persian, Egyptian
    # and Moorish townsmen shaved the head under a turban or cap (hair_shaved); Bedouin Arab and Kurdish men often kept the hair long, Arab men
    # in braids; Armenian merchants abroad took up the European queue; the women of all of them wore
    # it long, braided or loose under a veil or headcloth
    "arab_m": ["hair_bedouin_braids", "hair_shaved", "hair_long_loose"],
    "arab_f": ["hair_braid_f", "hair_long_loose", "hair_bun_low"],
    "kurdish_m": ["hair_cropped_1758", "hair_long_loose", "hair_loose_tied"],
    "kurdish_f": ["hair_braid_f", "hair_long_loose", "hair_bun_low"],
    "armenian_m": ["hair_cropped_1758", "hair_loose_tied", "hair_queue_ribbon"],
    "armenian_f": ["hair_braid_f", "hair_bun_low", "hair_long_loose"],
    # Ethiopian highlanders: men's hair natural, short or grown out; women's plaited in rows close to
    # the head (shuruba) or in a long braid
    "ethiopian_m": ["hair_natural_short", "hair_coily_rounded", "hair_cropped_1758"],
    "ethiopian_f": ["hair_shuruba_f", "hair_braid_f", "hair_coily_rounded"],
}

EYES_LIGHT = {"blue": 0.25, "blue_grey": 0.15, "grey": 0.1, "green": 0.1, "hazel": 0.12, "light_brown": 0.13,
              "brown": 0.15}
EYES_DARK = {"dark_brown": 0.7, "brown": 0.3}
EYES_MID = {"dark_brown": 0.45, "brown": 0.35, "light_brown": 0.1, "hazel": 0.07, "green": 0.03}
HAIR_DARK = {"black": 0.55, "blue_black": 0.4, "dark_brown": 0.05}
HAIR_EUROPE = {"dark_brown": 0.3, "mid_brown": 0.25, "chestnut": 0.12, "fair": 0.12, "flaxen": 0.06, "auburn": 0.06,
               "red": 0.04, "black": 0.05}

# ---------------------------------------------------------------------------
# Peoples
# ---------------------------------------------------------------------------
PEOPLES = [
    # Europe (settlers, soldiers and traders of the colonies)
    {"id": "english", "label": "English", "group": "Europe", "region": "europe",
     "note": "English colonists, provincial soldiers and regulars.",
     "face": _mix(REGION["europe"], {"length": 0.1, "nose_tip": 0.05}),
     "skin": {"melanin": [0.00, 0.22], "undertone": {"neutral": 0.4, "cool": 0.35, "warm": 0.25},
              "haemoglobin": [0.45, 0.75]},
     "eyes": EYES_LIGHT, "hair_colors": HAIR_EUROPE, "hair": "europe"},
    {"id": "scots_irish", "label": "Scots-Irish", "group": "Europe", "region": "europe",
     "note": "Ulster Scots settlers of the backcountry.",
     "face": _mix(REGION["europe"], {"breadth": 0.1, "cheekbones": 0.1, "nose_upturn": 0.15}),
     "skin": {"melanin": [0.00, 0.14], "undertone": {"cool": 0.45, "neutral": 0.4, "warm": 0.15},
              "haemoglobin": [0.55, 0.85], "freckles": [0.0, 0.8]},
     "eyes": {"blue": 0.35, "blue_grey": 0.2, "grey": 0.12, "green": 0.13, "hazel": 0.1, "light_brown": 0.1},
     "hair_colors": {"red": 0.14, "auburn": 0.14, "chestnut": 0.14, "fair": 0.14, "mid_brown": 0.22,
                     "dark_brown": 0.18, "black": 0.04},
     "hair": "europe"},
    {"id": "french", "label": "French", "group": "Europe", "region": "europe",
     "note": "Canadiens, habitants, troupes de la marine and coureurs de bois.",
     "face": _mix(REGION["europe"], {"nose_length": 0.1, "nose_hump": 0.15, "breadth": 0.05}),
     "skin": {"melanin": [0.04, 0.32], "undertone": {"neutral": 0.4, "warm": 0.3, "olive": 0.2, "cool": 0.1},
              "haemoglobin": [0.4, 0.7]},
     "eyes": {"brown": 0.3, "dark_brown": 0.15, "hazel": 0.15, "light_brown": 0.1, "green": 0.1, "blue": 0.12,
              "grey": 0.08},
     "hair_colors": {"dark_brown": 0.4, "black": 0.15, "mid_brown": 0.25, "chestnut": 0.12, "fair": 0.08},
     "hair": "europe"},
    {"id": "palatine", "label": "Palatine German", "group": "Europe", "region": "europe",
     "note": "German Palatine settlers of the Mohawk and Schoharie valleys (German Flatts, Stone Arabia).",
     "face": _mix(REGION["europe"], {"breadth": 0.15, "jaw_width": 0.15, "nose_width": 0.05}),
     "skin": {"melanin": [0.00, 0.20], "undertone": {"neutral": 0.45, "cool": 0.3, "warm": 0.25},
              "haemoglobin": [0.5, 0.8]},
     "eyes": EYES_LIGHT, "hair_colors": HAIR_EUROPE, "hair": "europe"},
    {"id": "dutch", "label": "Dutch (Albany)", "group": "Europe", "region": "europe",
     "note": "Dutch-descended families of Albany, Schenectady and the Hudson valley.",
     "face": _mix(REGION["europe"], {"length": 0.1, "chin_width": 0.1}),
     "skin": {"melanin": [0.00, 0.18], "undertone": {"neutral": 0.45, "cool": 0.35, "warm": 0.2},
              "haemoglobin": [0.5, 0.8]},
     "eyes": EYES_LIGHT, "hair_colors": HAIR_EUROPE, "hair": "europe"},
    # Spanish (2026-09-27, the user: "the spanish as well"): the European mean with the Iberian
    # tendencies of the surveys (a longer, more often convex nose, a slightly narrower face), skin
    # light to light olive, brown eyes most common, dark hair
    {"id": "spanish", "label": "Spanish", "group": "Europe", "region": "europe",
     "note": ("Spaniards of Florida (St. Augustine, Pensacola), New Spain and the Caribbean: soldiers, sailors, "
              "missionaries and traders of the Atlantic world."),
     "face": _mix(REGION["europe"], {"nose_hump": 0.15, "nose_length": 0.1, "breadth": -0.05, "brow_ridge": 0.05,
                                      "lips_upper": 0.05}),
     "skin": {"melanin": [0.04, 0.36], "undertone": {"neutral": 0.35, "olive": 0.35, "warm": 0.25, "cool": 0.05},
              "haemoglobin": [0.4, 0.7]},
     "eyes": {"brown": 0.35, "dark_brown": 0.25, "hazel": 0.12, "light_brown": 0.1, "green": 0.08, "blue": 0.06,
              "grey": 0.04},
     "hair_colors": {"dark_brown": 0.45, "black": 0.25, "mid_brown": 0.2, "chestnut": 0.07, "fair": 0.03},
     "hair": "europe"},
    # Eastern Woodlands
    {"id": "haudenosaunee", "label": "Haudenosaunee", "group": "Eastern Woodlands", "region": "woodlands",
     "note": ("The Six Nations: Mohawk (Kanien'keha:ka), Oneida, Onondaga, Cayuga, Seneca and Tuscarora; the "
              "Mohawk valley is Kanien'keha:ka country."),
     "face": _mix(REGION["woodlands"], {"nose_hump": 0.05, "length": 0.05}),
     "skin": {"melanin": [0.30, 0.58], "undertone": {"warm": 0.55, "neutral": 0.25, "olive": 0.2},
              "haemoglobin": [0.4, 0.65]},
     "eyes": EYES_DARK, "hair_colors": HAIR_DARK, "hair": "woodlands"},
    {"id": "lenape", "label": "Lenape", "group": "Eastern Woodlands", "region": "woodlands",
     "note": "The Lenape (Delaware), by the 1750s living on the Susquehanna and in the Ohio country.",
     "face": _mix(REGION["woodlands"], {"breadth": -0.1, "nose_hump": -0.05}),
     "skin": {"melanin": [0.30, 0.56], "undertone": {"warm": 0.55, "neutral": 0.25, "olive": 0.2},
              "haemoglobin": [0.4, 0.65]},
     "eyes": EYES_DARK, "hair_colors": HAIR_DARK, "hair": "woodlands"},
    {"id": "shawnee", "label": "Shawnee", "group": "Eastern Woodlands", "region": "woodlands",
     "note": "Shawnee towns of the Ohio country and the Susquehanna.",
     "face": _mix(REGION["woodlands"], {"cheekbones": 0.05, "nose_bridge": 0.05}),
     "skin": {"melanin": [0.32, 0.60], "undertone": {"warm": 0.55, "neutral": 0.2, "olive": 0.25},
              "haemoglobin": [0.4, 0.65]},
     "eyes": EYES_DARK, "hair_colors": HAIR_DARK, "hair": "woodlands"},
    {"id": "wabanaki", "label": "Wabanaki", "group": "Eastern Woodlands", "region": "woodlands",
     "note": "Abenaki, Penobscot, Maliseet, Mi'kmaq and Passamaquoddy of the northeast.",
     "face": _mix(REGION["woodlands"], {"breadth": 0.05, "epicanthus": 0.05}),
     "skin": {"melanin": [0.28, 0.54], "undertone": {"warm": 0.5, "neutral": 0.3, "olive": 0.2},
              "haemoglobin": [0.4, 0.65]},
     "eyes": EYES_DARK, "hair_colors": HAIR_DARK, "hair": "woodlands"},
    # Africa and the African diaspora
    {"id": "west_african", "label": "West African", "group": "Africa", "region": "africa",
     "note": ("Akan, Yoruba, Igbo, Mande, Wolof and other West African peoples; free and enslaved Africans lived "
              "in Albany, Schenectady and on the valley's estates."),
     "face": _mix(REGION["africa"], {}),
     "skin": {"melanin": [0.72, 1.00], "undertone": {"warm": 0.4, "neutral": 0.4, "cool": 0.2},
              "haemoglobin": [0.4, 0.6]},
     "eyes": {"dark_brown": 0.85, "brown": 0.15}, "hair_colors": {"black": 0.5, "blue_black": 0.5},
     "hair": "africa", "hair_texture": "coily"},
    {"id": "central_african", "label": "Central African", "group": "Africa", "region": "africa",
     "note": "Kongo, Mbundu and other peoples of West-Central Africa.",
     "face": _mix(REGION["africa"], {"nose_width": 0.1, "breadth": 0.05, "prognathism": -0.05}),
     "skin": {"melanin": [0.70, 1.00], "undertone": {"warm": 0.45, "neutral": 0.4, "cool": 0.15},
              "haemoglobin": [0.4, 0.6]},
     "eyes": {"dark_brown": 0.85, "brown": 0.15}, "hair_colors": {"black": 0.5, "blue_black": 0.5},
     "hair": "africa", "hair_texture": "coily"},
    {"id": "african_american", "label": "African American", "group": "Africa", "region": "africa",
     "note": "Colonial-born people of African descent, free and enslaved, often of mixed West and Central African "
             "(and sometimes European or Native) ancestry.",
     "face": _mix((0.8, REGION["africa"]), (0.2, REGION["europe"])),
     "skin": {"melanin": [0.48, 0.96], "undertone": {"warm": 0.5, "neutral": 0.35, "cool": 0.15},
              "haemoglobin": [0.4, 0.62]},
     "eyes": {"dark_brown": 0.7, "brown": 0.25, "light_brown": 0.05},
     "hair_colors": {"black": 0.55, "blue_black": 0.35, "dark_brown": 0.1}, "hair": "africa", "hair_texture": "coily"},
    # Ethiopian (2026-09-27, the user asked for them with the Middle Eastern peoples; placed in
    # Africa). Highland Ethiopian (Amhara, Tigrayan, Oromo) craniofacial surveys: between the African
    # and West Asian means, a long narrow face, a narrower, higher nose, little mouth projection; skin
    # medium to dark brown, dark eyes, curly to coily hair
    {"id": "ethiopian", "label": "Ethiopian", "group": "Africa", "region": "africa",
     "note": ("Amhara, Tigrayan and Oromo peoples of the Ethiopian highlands, the kingdom ruled from Gondar; the land "
              "where coffee first grew."),
     "face": _mix((0.6, REGION["africa"]), (0.4, REGION["west_asia"]),
                  {"breadth": -0.2, "length": 0.15, "nose_width": -0.1, "prognathism": -0.1}),
     "skin": {"melanin": [0.55, 0.92], "undertone": {"warm": 0.55, "neutral": 0.35, "cool": 0.1},
              "haemoglobin": [0.4, 0.6]},
     "eyes": {"dark_brown": 0.8, "brown": 0.2}, "hair_colors": {"black": 0.6, "blue_black": 0.35, "dark_brown": 0.05},
     "hair": "ethiopian", "hair_texture": "curly"},
    # East Asia
    {"id": "japanese", "label": "Japanese", "group": "East Asia", "region": "east_asia",
     "note": "People of Japan; castaways from Japanese ships reached the Pacific coast of North America.",
     "face": _mix(REGION["east_asia"], {"length": 0.15, "nose_bridge": 0.1, "nasal_root": 0.1}),
     "skin": {"melanin": [0.16, 0.42], "undertone": {"warm": 0.45, "neutral": 0.35, "olive": 0.2},
              "haemoglobin": [0.4, 0.65]},
     "eyes": EYES_DARK, "hair_colors": HAIR_DARK, "hair": "japanese"},
    {"id": "chinese", "label": "Chinese", "group": "East Asia", "region": "east_asia",
     "note": "People of Qing China; Chinese sailors and artisans were in the Manila and Atlantic trades.",
     "face": _mix(REGION["east_asia"], {"breadth": 0.05}),
     "skin": {"melanin": [0.16, 0.45], "undertone": {"warm": 0.45, "neutral": 0.35, "olive": 0.2},
              "haemoglobin": [0.4, 0.65]},
     "eyes": EYES_DARK, "hair_colors": HAIR_DARK, "hair": "chinese"},
    {"id": "korean", "label": "Korean", "group": "East Asia", "region": "east_asia",
     "note": "People of Joseon Korea.",
     "face": _mix(REGION["east_asia"], {"breadth": 0.1, "cheekbones": 0.1, "epicanthus": 0.05}),
     "skin": {"melanin": [0.14, 0.40], "undertone": {"neutral": 0.4, "warm": 0.4, "olive": 0.2},
              "haemoglobin": [0.4, 0.65]},
     "eyes": EYES_DARK, "hair_colors": HAIR_DARK, "hair": "korean"},
    # South and Southeast Asia, West Asia
    {"id": "south_asian", "label": "South Asian", "group": "South Asia", "region": "south_asia",
     "note": "People of Bengal, the Deccan, Gujarat and beyond; lascar sailors crewed East India ships.",
     "face": _mix(REGION["south_asia"], {}),
     "skin": {"melanin": [0.38, 0.86], "undertone": {"warm": 0.45, "olive": 0.3, "neutral": 0.25},
              "haemoglobin": [0.4, 0.6]},
     "eyes": EYES_MID, "hair_colors": {"black": 0.6, "blue_black": 0.2, "dark_brown": 0.2}, "hair": "south_asia",
     "hair_texture": "wavy"},
    {"id": "filipino", "label": "Filipino", "group": "Southeast Asia", "region": "southeast_asia",
     "note": "People of the Philippines; 'Manila men' sailed the galleon trade to the Americas.",
     "face": _mix(REGION["southeast_asia"], {}),
     "skin": {"melanin": [0.34, 0.66], "undertone": {"warm": 0.55, "olive": 0.25, "neutral": 0.2},
              "haemoglobin": [0.4, 0.6]},
     "eyes": EYES_DARK, "hair_colors": HAIR_DARK, "hair": "southeast_asia"},
    # Mainland and island Southeast Asia (2026-09-26). The Kinh (Vietnamese) and Central Thai
    # stand between the southern Chinese and the island Southeast Asian means in the craniofacial
    # surveys (a broad face and cheekbones, a low nasal root, a moderately broad nose, the
    # epicanthus and a low or absent upper-lid crease common); the Malay nearer the island
    # (Austronesian) mean, with the lid crease more often present. Skin: lighter in the north of
    # Dai Viet, darker toward the south and on the peninsula; within-group spread as everywhere.
    {"id": "vietnamese", "label": "Vietnamese", "group": "Southeast Asia", "region": "southeast_asia",
     "note": "People of Dai Viet, divided between the Trinh lords (north) and the Nguyen lords (south).",
     "face": _mix((0.55, REGION["east_asia"]), (0.45, REGION["southeast_asia"])),
     "skin": {"melanin": [0.20, 0.50], "undertone": {"warm": 0.5, "neutral": 0.3, "olive": 0.2},
              "haemoglobin": [0.4, 0.64]},
     "eyes": EYES_DARK, "hair_colors": HAIR_DARK, "hair": "vietnamese"},
    {"id": "thai", "label": "Thai (Siamese)", "group": "Southeast Asia", "region": "southeast_asia",
     "note": "Siamese of the kingdom of Ayutthaya, a trading port with Chinese, Malay, Portuguese and Dutch quarters.",
     "face": _mix((0.4, REGION["east_asia"]), (0.6, REGION["southeast_asia"]), {"nose_width": 0.05}),
     "skin": {"melanin": [0.24, 0.58], "undertone": {"warm": 0.55, "olive": 0.25, "neutral": 0.2},
              "haemoglobin": [0.4, 0.62]},
     "eyes": EYES_DARK, "hair_colors": HAIR_DARK, "hair": "thai"},
    {"id": "malay", "label": "Malay", "group": "Southeast Asia", "region": "southeast_asia",
     "note": ("Malays of the peninsula and Sumatra (Johor-Riau, Kedah, Dutch Malacca), traders and sailors of the "
              "Straits."),
     "face": _mix((0.15, REGION["east_asia"]), (0.85, REGION["southeast_asia"]),
                  {"lid_crease": 0.1, "lid_fold": -0.05, "nose_width": 0.05, "lips_lower": 0.05}),
     "skin": {"melanin": [0.30, 0.66], "undertone": {"warm": 0.55, "olive": 0.3, "neutral": 0.15},
              "haemoglobin": [0.4, 0.62]},
     "eyes": EYES_DARK, "hair_colors": HAIR_DARK, "hair": "malay"},
    # Pacific Islanders (2026-09-27, the user: "we forgot to add pacific islanders in the southeast
    # asia"; placed in that group as asked). Polynesian (Society Islands, Hawaii, Tonga, Samoa,
    # Aotearoa) craniofacial surveys: the island Southeast Asian (Austronesian) base with a longer,
    # more robust face (a broad strong jaw and chin, a heavier brow, deeper-set eyes), the upper-lid
    # crease usually present and the epicanthus seldom, a higher nasal bridge over a broad nose, full
    # lips. Skin light to medium brown, eyes dark, hair black or dark brown, straight to wavy.
    {"id": "pacific_islander", "label": "Pacific Islander", "group": "Southeast Asia", "region": "southeast_asia",
     "note": ("Peoples of the Pacific islands (Tahiti and the Society Islands, Hawaii, Tonga, Samoa, Aotearoa); Mai of "
              "Raiatea sailed to London in 1774."),
     "face": _mix(REGION["southeast_asia"], {"length": 0.3, "jaw_width": 0.45, "chin_projection": 0.3,
                                              "brow_ridge": 0.3, "eye_depth": 0.25, "lid_crease": 0.45,
                                              "lid_fold": -0.4, "epicanthus": -0.35, "nasal_root": 0.3,
                                              "nose_bridge": 0.35, "midface": 0.2, "eye_tilt": -0.15,
                                              "cheekbones": 0.1, "prognathism": -0.1}),
     "skin": {"melanin": [0.32, 0.64], "undertone": {"warm": 0.6, "olive": 0.2, "neutral": 0.2},
              "haemoglobin": [0.42, 0.64]},
     "eyes": EYES_DARK, "hair_colors": {"black": 0.55, "blue_black": 0.2, "dark_brown": 0.25},
     "hair": "pacific_islander", "hair_texture": "wavy"},
    # Middle East (2026-09-27, the user: "and middle eastern people"; "Ottoman Turkish, Persian, Arab,
    # Armenian" and "what ever else was during that time period": the Kurds). The West Asian mean,
    # each people nudged by its surveys: the Anatolian Turks toward the European and a little the
    # Central Asian mean (a broader face and cheekbones); the Iranians toward the South Asian; the
    # Arabs of the peninsula a narrower, longer face with a little East African admixture; the
    # Armenians the highest, most convex nose and the heaviest brow of the region; the Kurds toward
    # the European with a broader jaw. Men of all of them wore a moustache or a beard.
    {"id": "levantine", "label": "Levantine", "group": "Middle East", "region": "west_asia",
     "note": "People of the eastern Mediterranean (Syria, Lebanon, Palestine): traders and sailors.",
     "face": _mix(REGION["west_asia"], {}),
     "skin": {"melanin": [0.18, 0.50], "undertone": {"olive": 0.45, "warm": 0.35, "neutral": 0.2},
              "haemoglobin": [0.4, 0.65]},
     "eyes": EYES_MID, "hair_colors": {"black": 0.4, "dark_brown": 0.45, "mid_brown": 0.15}, "hair": "west_asia",
     "hair_texture": "wavy"},
    {"id": "ottoman_turkish", "label": "Ottoman Turkish", "group": "Middle East", "region": "west_asia",
     "note": ("Turks of Anatolia and Rumelia, subjects of the Ottoman sultan in Istanbul: soldiers, merchants and sailors "
              "of the Mediterranean."),
     "face": _mix((0.7, REGION["west_asia"]), (0.2, REGION["europe"]), (0.1, REGION["east_asia"]),
                  {"breadth": 0.1, "cheekbones": 0.1}),
     "skin": {"melanin": [0.10, 0.42], "undertone": {"olive": 0.4, "neutral": 0.35, "warm": 0.25},
              "haemoglobin": [0.4, 0.68]},
     "eyes": {"brown": 0.35, "dark_brown": 0.3, "hazel": 0.12, "light_brown": 0.1, "green": 0.07, "blue": 0.03,
              "grey": 0.03},
     "hair_colors": {"black": 0.35, "dark_brown": 0.5, "mid_brown": 0.15}, "hair": "west_asia", "hair_texture": "wavy",
     "facial_hair": ["moustache", "beard_short"]},
    {"id": "persian", "label": "Persian", "group": "Middle East", "region": "west_asia",
     "note": ("People of Iran after the Safavids (Nader Shah died in 1747; Karim Khan Zand ruled from Shiraz from 1751); "
              "Persian silk and carpet merchants reached Russia, India and Europe."),
     "face": _mix((0.85, REGION["west_asia"]), (0.15, REGION["south_asia"]), {"eye_depth": 0.05, "brow_ridge": 0.05}),
     "skin": {"melanin": [0.12, 0.48], "undertone": {"olive": 0.45, "warm": 0.35, "neutral": 0.2},
              "haemoglobin": [0.4, 0.65]},
     "eyes": {"dark_brown": 0.35, "brown": 0.35, "hazel": 0.12, "light_brown": 0.1, "green": 0.08},
     "hair_colors": {"black": 0.45, "dark_brown": 0.45, "mid_brown": 0.1}, "hair": "west_asia", "hair_texture": "wavy",
     "facial_hair": ["beard_short", "moustache"]},
    {"id": "arab", "label": "Arab", "group": "Middle East", "region": "west_asia",
     "note": ("Arabs of the Arabian peninsula and Iraq: Bedouin of the desert, townspeople of the Hejaz and Basra, and "
              "the merchants of Mocha, the coffee port of Yemen."),
     "face": _mix((0.9, REGION["west_asia"]), (0.1, REGION["africa"]), {"breadth": -0.1, "length": 0.05,
                                                                          "nose_hump": 0.05}),
     "skin": {"melanin": [0.22, 0.66], "undertone": {"warm": 0.45, "olive": 0.4, "neutral": 0.15},
              "haemoglobin": [0.4, 0.62]},
     "eyes": {"dark_brown": 0.55, "brown": 0.35, "light_brown": 0.07, "hazel": 0.03},
     "hair_colors": {"black": 0.6, "dark_brown": 0.35, "blue_black": 0.05}, "hair": "arab", "hair_texture": "wavy",
     "facial_hair": ["beard_short", "chin_beard"]},
    {"id": "armenian", "label": "Armenian", "group": "Middle East", "region": "west_asia",
     "note": ("Armenians of the Caucasus, Anatolia and New Julfa in Isfahan; their merchant houses traded from Amsterdam "
              "and London to Madras and Manila."),
     "face": _mix(REGION["west_asia"], {"nose_hump": 0.2, "nasal_root": 0.1, "brow_ridge": 0.1, "breadth": 0.05,
                                         "eye_depth": 0.05}),
     "skin": {"melanin": [0.06, 0.36], "undertone": {"olive": 0.4, "neutral": 0.35, "warm": 0.25},
              "haemoglobin": [0.42, 0.7]},
     "eyes": {"brown": 0.35, "dark_brown": 0.3, "hazel": 0.15, "light_brown": 0.1, "green": 0.06, "blue": 0.04},
     "hair_colors": {"black": 0.4, "dark_brown": 0.5, "mid_brown": 0.1}, "hair": "armenian", "hair_texture": "wavy",
     "facial_hair": ["moustache", "beard_short"]},
    {"id": "kurdish", "label": "Kurdish", "group": "Middle East", "region": "west_asia",
     "note": ("Kurds of the Zagros and Taurus mountains, between the Ottoman and Persian empires: herders, farmers and the "
              "horsemen of the emirates (Baban, Bohtan, Ardalan)."),
     "face": _mix((0.85, REGION["west_asia"]), (0.15, REGION["europe"]), {"jaw_width": 0.1}),
     "skin": {"melanin": [0.08, 0.42], "undertone": {"olive": 0.4, "neutral": 0.35, "warm": 0.25},
              "haemoglobin": [0.42, 0.7]},
     "eyes": {"brown": 0.3, "dark_brown": 0.25, "hazel": 0.15, "light_brown": 0.12, "green": 0.1, "blue": 0.05,
              "grey": 0.03},
     "hair_colors": {"black": 0.35, "dark_brown": 0.45, "mid_brown": 0.15, "chestnut": 0.05}, "hair": "kurdish",
     "hair_texture": "wavy", "facial_hair": ["moustache", "beard_short"]},
    # North Africa (2026-09-27): the Moors as their own people (the user's choice), North African now
    # the Amazigh; the Egyptians. Between the West Asian and African means, the Moors with a little of
    # the Iberian (Andalusi descent), the Egyptians nearer the African mean in the south of the valley.
    {"id": "north_african", "label": "North African", "group": "North Africa", "region": "west_asia",
     "note": "Amazigh (Berber) peoples of the Maghreb: the Rif, the Atlas, Kabylia and the Sahara's edge.",
     "face": _mix((0.75, REGION["west_asia"]), (0.25, REGION["africa"])),
     "skin": {"melanin": [0.25, 0.65], "undertone": {"olive": 0.4, "warm": 0.4, "neutral": 0.2},
              "haemoglobin": [0.4, 0.62]},
     "eyes": EYES_MID, "hair_colors": {"black": 0.45, "dark_brown": 0.45, "mid_brown": 0.1}, "hair": "west_asia",
     "hair_texture": "wavy"},
    {"id": "moorish", "label": "Moorish (Morocco)", "group": "North Africa", "region": "west_asia",
     "note": ("The Moors: Arabic-speaking townspeople of Morocco (Fez, Tetouan, Rabat-Sale), many of Andalusi descent "
              "after the expulsions from Spain (1609-1614); merchants, envoys and corsairs."),
     "face": _mix((0.7, REGION["west_asia"]), (0.2, REGION["africa"]), (0.1, REGION["europe"])),
     "skin": {"melanin": [0.22, 0.68], "undertone": {"warm": 0.45, "olive": 0.4, "neutral": 0.15},
              "haemoglobin": [0.4, 0.64]},
     "eyes": EYES_MID, "hair_colors": {"black": 0.5, "dark_brown": 0.45, "mid_brown": 0.05}, "hair": "west_asia",
     "hair_texture": "wavy", "facial_hair": ["beard_short", "chin_beard"]},
    {"id": "egyptian", "label": "Egyptian", "group": "North Africa", "region": "west_asia",
     "note": ("Egyptians of the Nile valley and delta, Muslim and Coptic, under Ottoman pashas and the Mamluk beys; "
              "Cairo and Alexandria traded coffee, cloth and grain."),
     "face": _mix((0.7, REGION["west_asia"]), (0.3, REGION["africa"]), {"nose_hump": -0.1}),
     "skin": {"melanin": [0.28, 0.72], "undertone": {"warm": 0.5, "olive": 0.35, "neutral": 0.15},
              "haemoglobin": [0.4, 0.62]},
     "eyes": {"dark_brown": 0.6, "brown": 0.33, "light_brown": 0.05, "hazel": 0.02},
     "hair_colors": {"black": 0.6, "dark_brown": 0.35, "blue_black": 0.05}, "hair": "west_asia", "hair_texture": "wavy",
     "facial_hair": ["beard_short", "moustache"]},
    # Mixed ancestry (the colonial northeast had many families of mixed descent)
    {"id": "metis", "label": "French and Native (Metis)", "group": "Mixed ancestry", "region": "woodlands",
     "note": "Families of French and Native descent, common in the fur trade and on the lakes.",
     "face": _mix((0.5, REGION["woodlands"]), (0.5, REGION["europe"])),
     "skin": {"melanin": [0.15, 0.48], "undertone": {"warm": 0.45, "neutral": 0.35, "olive": 0.2},
              "haemoglobin": [0.4, 0.7]},
     "eyes": {"dark_brown": 0.45, "brown": 0.35, "hazel": 0.1, "light_brown": 0.1},
     "hair_colors": {"black": 0.35, "dark_brown": 0.45, "mid_brown": 0.15, "blue_black": 0.05}, "hair": "woodlands"},
    {"id": "afro_native", "label": "African and Native", "group": "Mixed ancestry", "region": "africa",
     "note": "Families of African and Native descent, found in many northeastern communities.",
     "face": _mix((0.55, REGION["africa"]), (0.45, REGION["woodlands"])),
     "skin": {"melanin": [0.45, 0.88], "undertone": {"warm": 0.55, "neutral": 0.3, "olive": 0.15},
              "haemoglobin": [0.4, 0.62]},
     "eyes": EYES_DARK, "hair_colors": {"black": 0.6, "blue_black": 0.35, "dark_brown": 0.05}, "hair": "africa",
     "hair_texture": "curly"},
    {"id": "euro_african", "label": "European and African", "group": "Mixed ancestry", "region": "africa",
     "note": "People of European and African descent.",
     "face": _mix((0.5, REGION["africa"]), (0.5, REGION["europe"])),
     "skin": {"melanin": [0.30, 0.72], "undertone": {"warm": 0.5, "neutral": 0.35, "olive": 0.15},
              "haemoglobin": [0.45, 0.7]},
     "eyes": {"dark_brown": 0.45, "brown": 0.35, "light_brown": 0.1, "hazel": 0.07, "green": 0.03},
     "hair_colors": {"black": 0.4, "dark_brown": 0.45, "mid_brown": 0.1, "blue_black": 0.05}, "hair": "africa",
     "hair_texture": "curly"},
]

# Individual offsets: presets of every people take two of these (scaled by the people's own
# spread), so presets differ from each other the same way inside every people.
INDIVIDUALS = [
    {"length": 0.5, "breadth": -0.35, "jaw_width": -0.3, "nose_length": 0.35, "chin_height": 0.3},
    {"breadth": 0.4, "cheek_fullness": 0.55, "jaw_angle": -0.3, "chin_projection": -0.2, "length": -0.3},
    {"jaw_angle": 0.6, "jaw_width": 0.35, "chin_width": 0.4, "brow_ridge": 0.25, "cheek_fullness": -0.35},
    {"nose_width": 0.35, "lips_upper": 0.3, "lips_lower": 0.35, "mouth_width": 0.25, "nose_tip": -0.25},
    {"nose_bridge": 0.35, "nose_hump": 0.4, "nasal_root": 0.25, "lips_upper": -0.25, "eye_depth": 0.25},
    {"eye_height": 0.35, "eye_tilt": 0.25, "cheekbones": 0.35, "midface": 0.2, "under_eye": -0.3, "ears": 0.4},
    {"chin_projection": 0.45, "prognathism": -0.25, "nose_upturn": 0.3, "cheekbones": -0.2, "ears": -0.3},
    {"lid_fold": 0.35, "lid_crease": -0.3, "length": 0.25, "mouth_width": -0.3, "chin_width": -0.25},
]
PRESET_PLAN = [("f", 0, "a"), ("f", 3, "b"), ("m", 2, "a"), ("m", 4, "b")]

# ---------------------------------------------------------------------------
# Stylized faces (the character creator's default Face style, 2026-09-26)
# ---------------------------------------------------------------------------
# Example individuals made for the stylized, painted look: attractive, well-proportioned and a
# little heroic. The SAME offsets for every people (added to the people's mean, as INDIVIDUALS),
# and only on the features every face shares: jaw, chin, cheekbones and cheek fullness, face
# length and breadth, brow, eye opening and the under-eye, lips and mouth width. None of them moves
# a feature that tells peoples apart (the nose, the upper lid, lid crease and epicanthus, the
# midface, mouth projection): those keep the people's mean, so no people is pushed toward
# another's look and nothing is exaggerated (tests/customizer/test_stylized.gd checks both).
STYLIZED_SHARED = {"breadth", "length", "cheekbones", "cheek_fullness", "jaw_width", "jaw_angle", "chin_projection",
                   "chin_width", "chin_height", "brow_ridge", "eye_depth", "eye_height", "eye_tilt", "under_eye",
                   "lips_upper", "lips_lower", "mouth_width"}
STYLIZED = {
    "m": [
        # a clean, square hero: strong jaw and chin, clear cheekbones, lean cheeks
        {"jaw_angle": 0.5, "jaw_width": 0.2, "chin_projection": 0.4, "chin_width": 0.25, "cheekbones": 0.3,
         "cheek_fullness": -0.1, "brow_ridge": 0.2, "under_eye": -0.35, "eye_height": 0.1, "lips_lower": 0.1},
        # finer and longer: high cheekbones, a firm narrower jaw
        {"length": 0.15, "breadth": -0.15, "cheekbones": 0.35, "cheek_fullness": -0.05, "chin_projection": 0.3,
         "jaw_angle": 0.3, "under_eye": -0.3, "eye_height": 0.2, "lips_upper": 0.1, "lips_lower": 0.1},
        # rugged: a heavier brow over deeper eyes, a broad jaw
        {"brow_ridge": 0.35, "eye_depth": 0.2, "jaw_width": 0.35, "jaw_angle": 0.45, "chin_width": 0.35,
         "chin_projection": 0.25, "cheek_fullness": -0.05, "length": 0.1},
        # young and open: a softer jaw, open eyes, fuller lips
        {"cheek_fullness": 0.05, "chin_projection": 0.25, "jaw_angle": 0.25, "eye_height": 0.25, "under_eye": -0.25,
         "lips_upper": 0.15, "lips_lower": 0.2, "mouth_width": 0.15, "breadth": -0.05},
    ],
    "f": [
        # high cheekbones over a tapering jaw, open eyes, full lips
        {"cheekbones": 0.35, "cheek_fullness": 0.05, "jaw_width": -0.25, "chin_width": -0.2, "chin_projection": 0.25,
         "eye_height": 0.25, "under_eye": -0.35, "lips_upper": 0.2, "lips_lower": 0.25, "length": -0.1},
        # longer and finer: a lifted outer eye, a full lower lip
        {"length": 0.1, "breadth": -0.1, "cheekbones": 0.3, "jaw_width": -0.15, "eye_tilt": 0.15, "eye_height": 0.2,
         "lips_lower": 0.3, "mouth_width": 0.1, "chin_projection": 0.2},
        # softer and rounder: full cheeks, wide-open eyes, full lips
        {"breadth": 0.1, "cheek_fullness": 0.15, "chin_projection": 0.15, "eye_height": 0.3, "under_eye": -0.3,
         "lips_upper": 0.25, "lips_lower": 0.3, "jaw_width": -0.15, "chin_width": -0.1},
        # sculpted: strong cheekbones, lean cheeks, a defined jaw angle
        {"cheekbones": 0.45, "cheek_fullness": 0.05, "jaw_angle": 0.15, "chin_projection": 0.3, "eye_height": 0.15,
         "lips_upper": 0.15, "lips_lower": 0.2, "jaw_width": -0.1},
    ],
}
# The East Asian and Southeast Asian peoples get the most care of the set (the user's request,
# 2026-09-26): two more faces per body type, tuned one by one for the painted look (the same
# shared features only: their noses, lids and midface stay the people's own), each dressed with a
# chosen hair style, colour and brows and a clean shave. The shared faces above are made the same
# way for every people and are never made plainer.
SHOWCASE = {
    # per people and body type: (shared-feature offsets, hair style, hair colour, (brow thickness,
    # arch)). Men: a longer, cleaner face, a strong forward chin over a clean jaw angle, clear
    # cheekbones and brow, smooth under the eyes, bold straight brows. Women: a longer, finer face
    # tapering to a neat chin, high cheekbones, open eyes, full lips, soft full brows.
    "japanese": {
        "m": [({"length": 0.15, "breadth": -0.15, "jaw_angle": 0.35, "jaw_width": -0.05, "chin_projection": 0.45,
                "chin_width": 0.15, "cheekbones": 0.3, "cheek_fullness": -0.05, "brow_ridge": 0.3, "eye_height": 0.25,
                "under_eye": -0.4, "lips_lower": 0.15}, "hair_topknot", "blue_black", (0.86, 0.2)),
              ({"length": 0.2, "breadth": -0.2, "cheekbones": 0.4, "cheek_fullness": -0.05, "jaw_angle": 0.3,
                "chin_projection": 0.4, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.1, "lips_lower": 0.15,
                "brow_ridge": 0.2}, "hair_loose_tied", "black", (0.8, 0.3))],
        "f": [({"length": 0.1, "breadth": -0.2, "cheekbones": 0.3, "cheek_fullness": 0.05, "jaw_width": -0.35,
                "chin_width": -0.25, "chin_projection": 0.35, "eye_height": 0.35, "under_eye": -0.4, "lips_upper": 0.2,
                "lips_lower": 0.3, "brow_ridge": 0.1}, "hair_long_loose", "blue_black", (0.58, 0.6)),
              ({"length": 0.15, "breadth": -0.2, "cheekbones": 0.35, "cheek_fullness": 0.05, "jaw_width": -0.3,
                "chin_width": -0.2, "eye_tilt": 0.1, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.15,
                "lips_lower": 0.3, "chin_projection": 0.3}, "hair_bun_low", "black", (0.55, 0.66))],
    },
    "chinese": {
        "m": [({"length": 0.15, "breadth": -0.15, "jaw_angle": 0.35, "jaw_width": -0.05, "chin_projection": 0.45,
                "chin_width": 0.2, "cheekbones": 0.3, "cheek_fullness": -0.05, "brow_ridge": 0.3, "eye_height": 0.25,
                "under_eye": -0.4, "lips_lower": 0.15}, "hair_queue_ribbon", "blue_black", (0.86, 0.22)),
              ({"length": 0.2, "breadth": -0.2, "cheekbones": 0.35, "cheek_fullness": -0.05, "jaw_angle": 0.3,
                "chin_projection": 0.4, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.1, "lips_lower": 0.15,
                "brow_ridge": 0.2}, "hair_topknot", "black", (0.8, 0.28))],
        "f": [({"length": 0.1, "breadth": -0.2, "cheekbones": 0.35, "cheek_fullness": 0.05, "jaw_width": -0.35,
                "chin_width": -0.25, "chin_projection": 0.35, "eye_height": 0.35, "under_eye": -0.4, "lips_upper": 0.2,
                "lips_lower": 0.3, "brow_ridge": 0.1}, "hair_braid_f", "blue_black", (0.58, 0.6)),
              ({"length": 0.15, "breadth": -0.15, "cheekbones": 0.3, "cheek_fullness": 0.05, "jaw_width": -0.3,
                "chin_width": -0.2, "eye_tilt": 0.1, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.15,
                "lips_lower": 0.3, "chin_projection": 0.3}, "hair_bun_low", "black", (0.55, 0.64))],
    },
    "korean": {
        "m": [({"length": 0.2, "breadth": -0.2, "jaw_angle": 0.3, "jaw_width": -0.1, "chin_projection": 0.45,
                "chin_width": 0.1, "cheekbones": 0.25, "cheek_fullness": -0.05, "brow_ridge": 0.25, "eye_height": 0.3,
                "under_eye": -0.4, "lips_lower": 0.15}, "hair_topknot", "blue_black", (0.82, 0.2)),
              ({"length": 0.15, "breadth": -0.2, "cheekbones": 0.35, "cheek_fullness": -0.05, "jaw_width": -0.05,
                "jaw_angle": 0.35, "chin_projection": 0.4, "eye_height": 0.25, "under_eye": -0.35, "lips_upper": 0.1,
                "lips_lower": 0.2, "brow_ridge": 0.2}, "hair_long_loose", "black", (0.78, 0.3))],
        "f": [({"length": 0.15, "breadth": -0.2, "cheekbones": 0.3, "cheek_fullness": 0.05, "jaw_width": -0.4,
                "chin_width": -0.25, "chin_projection": 0.4, "eye_height": 0.35, "under_eye": -0.4, "lips_upper": 0.2,
                "lips_lower": 0.25, "brow_ridge": 0.1}, "hair_braid_f", "blue_black", (0.56, 0.56)),
              ({"length": 0.1, "breadth": -0.2, "cheekbones": 0.35, "cheek_fullness": 0.05, "jaw_width": -0.3,
                "chin_width": -0.2, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.25, "lips_lower": 0.3,
                "chin_projection": 0.3}, "hair_bun_low", "black", (0.55, 0.6))],
    },
    "filipino": {
        "m": [({"length": 0.15, "breadth": -0.15, "jaw_angle": 0.35, "jaw_width": 0.0, "chin_projection": 0.45,
                "chin_width": 0.15, "cheekbones": 0.3, "cheek_fullness": -0.05, "brow_ridge": 0.25, "eye_height": 0.25,
                "under_eye": -0.4, "lips_lower": 0.1}, "hair_cropped_1758", "black", (0.86, 0.24)),
              ({"length": 0.15, "breadth": -0.15, "cheekbones": 0.4, "cheek_fullness": -0.05, "jaw_angle": 0.3,
                "chin_projection": 0.4, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.1, "lips_lower": 0.15,
                "brow_ridge": 0.2}, "hair_loose_tied", "blue_black", (0.8, 0.3))],
        "f": [({"length": 0.1, "breadth": -0.2, "cheekbones": 0.35, "cheek_fullness": 0.05, "jaw_width": -0.3,
                "chin_width": -0.2, "chin_projection": 0.35, "eye_height": 0.35, "under_eye": -0.4, "lips_upper": 0.2,
                "lips_lower": 0.25, "brow_ridge": 0.1}, "hair_long_loose", "blue_black", (0.58, 0.6)),
              ({"length": 0.1, "breadth": -0.15, "cheekbones": 0.35, "cheek_fullness": 0.05, "jaw_width": -0.25,
                "chin_width": -0.2, "eye_tilt": 0.1, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.25,
                "lips_lower": 0.3, "chin_projection": 0.3}, "hair_bun_low", "black", (0.55, 0.64))],
    },
    # 2026-09-26: the Vietnamese, Thai and Malay showcase faces, made the same way (shared features
    # only; each people's own nose, lids and midface), each with a period hair style of the people
    "vietnamese": {
        "m": [({"length": 0.2, "breadth": -0.2, "jaw_angle": 0.35, "jaw_width": -0.05, "chin_projection": 0.45,
                "chin_width": 0.15, "cheekbones": 0.3, "cheek_fullness": -0.05, "brow_ridge": 0.3, "eye_height": 0.3,
                "under_eye": -0.4, "lips_lower": 0.15}, "hair_topknot", "blue_black", (0.84, 0.2)),
              ({"length": 0.15, "breadth": -0.2, "cheekbones": 0.4, "cheek_fullness": -0.05, "jaw_angle": 0.3,
                "chin_projection": 0.4, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.1, "lips_lower": 0.15,
                "brow_ridge": 0.2}, "hair_topknot", "black", (0.8, 0.28))],
        "f": [({"length": 0.15, "breadth": -0.2, "cheekbones": 0.3, "cheek_fullness": 0.05, "jaw_width": -0.35,
                "chin_width": -0.25, "chin_projection": 0.35, "eye_height": 0.35, "under_eye": -0.4, "lips_upper": 0.2,
                "lips_lower": 0.3, "brow_ridge": 0.1}, "hair_bun_low", "blue_black", (0.56, 0.6)),
              ({"length": 0.1, "breadth": -0.2, "cheekbones": 0.35, "cheek_fullness": 0.05, "jaw_width": -0.3,
                "chin_width": -0.2, "eye_tilt": 0.1, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.2,
                "lips_lower": 0.3, "chin_projection": 0.3}, "hair_long_loose", "black", (0.55, 0.64))],
    },
    "thai": {
        "m": [({"length": 0.15, "breadth": -0.15, "jaw_angle": 0.35, "jaw_width": 0.0, "chin_projection": 0.45,
                "chin_width": 0.15, "cheekbones": 0.3, "cheek_fullness": -0.05, "brow_ridge": 0.3, "eye_height": 0.25,
                "under_eye": -0.4, "lips_lower": 0.15}, "hair_siamese_crop", "black", (0.86, 0.22)),
              ({"length": 0.2, "breadth": -0.2, "cheekbones": 0.35, "cheek_fullness": -0.05, "jaw_angle": 0.3,
                "chin_projection": 0.4, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.1, "lips_lower": 0.2,
                "brow_ridge": 0.2}, "hair_siamese_crop", "blue_black", (0.8, 0.3))],
        "f": [({"length": 0.1, "breadth": -0.2, "cheekbones": 0.35, "cheek_fullness": 0.05, "jaw_width": -0.3,
                "chin_width": -0.25, "chin_projection": 0.35, "eye_height": 0.35, "under_eye": -0.4, "lips_upper": 0.25,
                "lips_lower": 0.3, "brow_ridge": 0.1}, "hair_siamese_short_f", "blue_black", (0.58, 0.6)),
              ({"length": 0.15, "breadth": -0.15, "cheekbones": 0.3, "cheek_fullness": 0.05, "jaw_width": -0.3,
                "chin_width": -0.2, "eye_tilt": 0.1, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.2,
                "lips_lower": 0.3, "chin_projection": 0.3}, "hair_siamese_short_f", "black", (0.55, 0.62))],
    },
    "malay": {
        "m": [({"length": 0.15, "breadth": -0.15, "jaw_angle": 0.35, "jaw_width": 0.0, "chin_projection": 0.45,
                "chin_width": 0.2, "cheekbones": 0.3, "cheek_fullness": -0.05, "brow_ridge": 0.25, "eye_height": 0.25,
                "under_eye": -0.4, "lips_lower": 0.1}, "hair_topknot", "black", (0.86, 0.24)),
              ({"length": 0.15, "breadth": -0.15, "cheekbones": 0.4, "cheek_fullness": -0.05, "jaw_angle": 0.3,
                "chin_projection": 0.4, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.1, "lips_lower": 0.15,
                "brow_ridge": 0.2}, "hair_loose_tied", "blue_black", (0.8, 0.3))],
        "f": [({"length": 0.1, "breadth": -0.2, "cheekbones": 0.35, "cheek_fullness": 0.05, "jaw_width": -0.3,
                "chin_width": -0.2, "chin_projection": 0.35, "eye_height": 0.35, "under_eye": -0.4, "lips_upper": 0.2,
                "lips_lower": 0.25, "brow_ridge": 0.1}, "hair_bun_low", "black", (0.58, 0.6)),
              ({"length": 0.15, "breadth": -0.2, "cheekbones": 0.35, "cheek_fullness": 0.05, "jaw_width": -0.3,
                "chin_width": -0.2, "eye_tilt": 0.1, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.25,
                "lips_lower": 0.3, "chin_projection": 0.3}, "hair_long_loose", "blue_black", (0.55, 0.64))],
    },
    # Pacific Islanders (2026-09-27): as the Malay, a little longer and stronger in the jaw and chin
    "pacific_islander": {
        "m": [({"length": 0.15, "breadth": -0.1, "jaw_angle": 0.4, "jaw_width": 0.1, "chin_projection": 0.45,
                "chin_width": 0.25, "cheekbones": 0.3, "cheek_fullness": -0.05, "brow_ridge": 0.25, "eye_height": 0.2,
                "under_eye": -0.4, "lips_lower": 0.1}, "hair_topknot", "black", (0.86, 0.22)),
              ({"length": 0.15, "breadth": -0.1, "cheekbones": 0.35, "cheek_fullness": -0.05, "jaw_angle": 0.35,
                "chin_projection": 0.4, "eye_height": 0.25, "under_eye": -0.35, "lips_upper": 0.1, "lips_lower": 0.15,
                "brow_ridge": 0.2}, "hair_long_loose", "dark_brown", (0.8, 0.28))],
        "f": [({"length": 0.1, "breadth": -0.15, "cheekbones": 0.35, "cheek_fullness": 0.05, "jaw_width": -0.25,
                "chin_width": -0.15, "chin_projection": 0.35, "eye_height": 0.3, "under_eye": -0.4, "lips_upper": 0.2,
                "lips_lower": 0.25, "brow_ridge": 0.1}, "hair_natural_short", "black", (0.6, 0.58)),
              ({"length": 0.15, "breadth": -0.2, "cheekbones": 0.35, "cheek_fullness": 0.05, "jaw_width": -0.3,
                "chin_width": -0.2, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.25, "lips_lower": 0.3,
                "chin_projection": 0.3}, "hair_long_loose", "black", (0.56, 0.62))],
    },
}
# Realistic showcase faces (2026-09-26): the Vietnamese, Thai and Malay peoples also get six faces
# per body type in the Realistic face style (n07's head): these two, tuned one by one for the
# realistic head (no stylized shape: a little more length and chin than SHOWCASE, whose head
# already shortens the lower face and brings the chin forward; a narrower jaw and a softer jaw
# angle, since the realistic mandible is broader and a hollow cheek over it reads lumpy), then the
# people's presets A, B and two more individuals C, D (EXTRA_PLAN). The same rule as SHOWCASE: shared features only,
# an offset toward the people's own tendency shrinks with it. The other peoples keep n07's two
# presets per body type unchanged.
REALISTIC_SHOWCASE = {
    "vietnamese": {
        "m": [({"length": 0.25, "breadth": -0.2, "jaw_angle": 0.15, "jaw_width": -0.2, "chin_projection": 0.5,
                "chin_width": 0.1, "chin_height": 0.1, "cheekbones": 0.25, "cheek_fullness": 0.0, "brow_ridge": 0.25,
                "eye_height": 0.25, "under_eye": -0.35, "lips_lower": 0.1}, "hair_topknot", "blue_black", (0.82, 0.2)),
              ({"length": 0.2, "breadth": -0.2, "cheekbones": 0.35, "jaw_angle": 0.2, "jaw_width": -0.15,
                "chin_projection": 0.45, "eye_height": 0.25, "under_eye": -0.3, "lips_upper": 0.05, "lips_lower": 0.1,
                "brow_ridge": 0.2}, "hair_loose_tied", "black", (0.78, 0.28))],
        "f": [({"length": 0.15, "breadth": -0.25, "cheekbones": 0.3, "cheek_fullness": 0.1, "jaw_width": -0.5,
                "chin_width": -0.35, "chin_projection": 0.4, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.15,
                "lips_lower": 0.25, "brow_ridge": 0.05}, "hair_bun_low", "blue_black", (0.52, 0.6)),
              ({"length": 0.15, "breadth": -0.2, "cheekbones": 0.35, "cheek_fullness": 0.1, "jaw_width": -0.45,
                "chin_width": -0.3, "eye_tilt": 0.1, "eye_height": 0.3, "under_eye": -0.3, "lips_upper": 0.15,
                "lips_lower": 0.25, "chin_projection": 0.35}, "hair_long_loose", "black", (0.52, 0.64))],
    },
    "thai": {
        "m": [({"length": 0.2, "breadth": -0.2, "jaw_angle": 0.15, "jaw_width": -0.15, "chin_projection": 0.5,
                "chin_width": 0.1, "chin_height": 0.1, "cheekbones": 0.25, "cheek_fullness": 0.0, "brow_ridge": 0.25,
                "eye_height": 0.25, "under_eye": -0.35, "lips_lower": 0.1}, "hair_siamese_crop", "black", (0.84, 0.22)),
              ({"length": 0.25, "breadth": -0.2, "cheekbones": 0.3, "jaw_angle": 0.2, "jaw_width": -0.15,
                "chin_projection": 0.45, "eye_height": 0.25, "under_eye": -0.3, "lips_upper": 0.05, "lips_lower": 0.15,
                "brow_ridge": 0.2}, "hair_siamese_crop", "blue_black", (0.78, 0.3))],
        "f": [({"length": 0.15, "breadth": -0.25, "cheekbones": 0.3, "cheek_fullness": 0.1, "jaw_width": -0.45,
                "chin_width": -0.35, "chin_projection": 0.4, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.2,
                "lips_lower": 0.25, "brow_ridge": 0.05}, "hair_siamese_short_f", "blue_black", (0.54, 0.6)),
              ({"length": 0.2, "breadth": -0.2, "cheekbones": 0.3, "cheek_fullness": 0.1, "jaw_width": -0.45,
                "chin_width": -0.3, "eye_tilt": 0.1, "eye_height": 0.3, "under_eye": -0.3, "lips_upper": 0.15,
                "lips_lower": 0.25, "chin_projection": 0.35}, "hair_bun_low", "black", (0.52, 0.62))],
    },
    "malay": {
        "m": [({"length": 0.2, "breadth": -0.15, "jaw_angle": 0.15, "jaw_width": -0.15, "chin_projection": 0.5,
                "chin_width": 0.15, "chin_height": 0.1, "cheekbones": 0.25, "cheek_fullness": 0.0, "brow_ridge": 0.2,
                "eye_height": 0.2, "under_eye": -0.35, "lips_lower": 0.05}, "hair_topknot", "black", (0.84, 0.24)),
              ({"length": 0.2, "breadth": -0.15, "cheekbones": 0.35, "jaw_angle": 0.2, "jaw_width": -0.15,
                "chin_projection": 0.45, "eye_height": 0.25, "under_eye": -0.3, "lips_lower": 0.1, "brow_ridge": 0.2},
               "hair_loose_tied", "blue_black", (0.8, 0.3))],
        "f": [({"length": 0.15, "breadth": -0.2, "cheekbones": 0.35, "cheek_fullness": 0.1, "jaw_width": -0.45,
                "chin_width": -0.3, "chin_projection": 0.4, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.15,
                "lips_lower": 0.2, "brow_ridge": 0.05}, "hair_bun_low", "black", (0.56, 0.6)),
              ({"length": 0.15, "breadth": -0.25, "cheekbones": 0.3, "cheek_fullness": 0.1, "jaw_width": -0.45,
                "chin_width": -0.3, "eye_tilt": 0.1, "eye_height": 0.3, "under_eye": -0.3, "lips_upper": 0.2,
                "lips_lower": 0.25, "chin_projection": 0.35}, "hair_long_loose", "blue_black", (0.52, 0.64))],
    },
    # Pacific Islanders (2026-09-27): the realistic head's pair, as the Malay's with a stronger chin
    "pacific_islander": {
        "m": [({"length": 0.2, "breadth": -0.1, "jaw_angle": 0.2, "jaw_width": -0.05, "chin_projection": 0.5,
                "chin_width": 0.2, "chin_height": 0.1, "cheekbones": 0.25, "cheek_fullness": 0.0, "brow_ridge": 0.2,
                "eye_height": 0.2, "under_eye": -0.35, "lips_lower": 0.05}, "hair_topknot", "black", (0.84, 0.22)),
              ({"length": 0.2, "breadth": -0.1, "cheekbones": 0.35, "jaw_angle": 0.2, "jaw_width": -0.1,
                "chin_projection": 0.45, "eye_height": 0.25, "under_eye": -0.3, "lips_lower": 0.1, "brow_ridge": 0.2},
               "hair_long_loose", "dark_brown", (0.8, 0.28))],
        "f": [({"length": 0.15, "breadth": -0.15, "cheekbones": 0.35, "cheek_fullness": 0.1, "jaw_width": -0.4,
                "chin_width": -0.25, "chin_projection": 0.4, "eye_height": 0.3, "under_eye": -0.35, "lips_upper": 0.15,
                "lips_lower": 0.2, "brow_ridge": 0.05}, "hair_natural_short", "black", (0.58, 0.58)),
              ({"length": 0.15, "breadth": -0.2, "cheekbones": 0.3, "cheek_fullness": 0.1, "jaw_width": -0.45,
                "chin_width": -0.3, "eye_height": 0.3, "under_eye": -0.3, "lips_upper": 0.2,
                "lips_lower": 0.25, "chin_projection": 0.35}, "hair_long_loose", "black", (0.54, 0.62))],
    },
}
# Two more realistic individuals (C, D) per body type for the peoples with realistic showcase
# faces: the INDIVIDUALS not yet used by A and B (index (ind + idx) % 8 as PRESET_PLAN, idx 4-7).
EXTRA_PLAN = [("f", 1, "c"), ("f", 4, "d"), ("m", 4, "c"), ("m", 7, "d")]
PRESET_FRAC = [0.3, 0.7, 0.55, 0.15, 0.45, 0.85, 0.25, 0.6]
# East, South and Southeast Asian peoples: a choice for the game's wider cast (artistic licence)
LICENCE_GROUPS = {"East Asia", "South Asia", "Southeast Asia"}
LICENCE_NOTE = "rare in the 1750s northeast."      # shown as "Artistic licence: rare in ..."
EYE_ORDER =["dark_brown", "brown", "light_brown", "hazel", "amber", "green", "grey", "blue_grey", "blue"]
# ---------------------------------------------------------------------------
# Men's genital size, one number per people (men only; look "genital", body.glb genital_small /
# genital_large). -1.0 smallest, 0.0 the default, 1.0 largest. Every man of the people gets exactly this
# number (no random spread): the presets here and new individuals (scripts/customizer/peoples.gd
# random_look). Change a number, then run: python3 tools/character/body/peoples.py
# ---------------------------------------------------------------------------
GENITAL = {
    # Europe
    "english": 0.0,
    "scots_irish": 0.0,
    "french": 0.0,
    "palatine": 0.0,
    "dutch": 0.0,
    "spanish": 0.0,
    # Eastern Woodlands
    "haudenosaunee": 0.0,
    "lenape": 0.0,
    "shawnee": 0.0,
    "wabanaki": 0.0,
    # Africa
    "west_african": 0.0,
    "central_african": 0.0,
    "african_american": 0.0,
    "ethiopian": 0.0,
    # East Asia
    "japanese": 1.0,
    "chinese": 1.0,
    "korean": 1.0,
    # South Asia
    "south_asian": -1.0,
    # Southeast Asia
    "filipino": 1.0,
    "vietnamese": 1.0,
    "thai": 1.0,
    "malay": 1.0,
    "pacific_islander": 1.0,
    # Middle East
    "levantine": 0.0,
    "ottoman_turkish": 0.0,
    "persian": 0.0,
    "arab": 0.0,
    "armenian": 0.0,
    "kurdish": 0.0,
    # North Africa
    "north_african": 0.0,
    "moorish": 0.0,
    "egyptian": 0.0,
    # Mixed ancestry
    "metis": 0.0,
    "afro_native": 0.0,
    "euro_african": 0.0,
}
GENITAL_DEFAULT = 0.0      # a people missing from GENITAL


def _genital(p, sex):
    """A man's genital size: his people's GENITAL number (women: none)."""
    if sex != "m":
        return {}
    return {"genital": round(max(-1.0, min(1.0, float(GENITAL.get(p["id"], GENITAL_DEFAULT)))), 3)}


def _pick(dist, rng):
    items = sorted(dist.items())
    r = rng.random() * sum(v for _, v in items)
    for k, v in items:
        r -= v
        if r <= 0:
            return k
    return items[-1][0]


def _facial_hair(p, sex, idx):
    """The peoples whose men wore a moustache or a beard as the custom ("facial_hair": creator.json
    ids) give their men's presets one of them in turn; the others keep the stubble alone."""
    styles = p.get("facial_hair", [])
    return {"facial_hair": styles[idx % len(styles)]} if sex == "m" and styles else {}


def _preset(p, sex, ind, tag, idx):
    rng = random.Random("%s-%s-%s" % (p["id"], sex, tag))
    offs = INDIVIDUALS[(ind + idx) % len(INDIVIDUALS)]
    face = dict(p["face"])
    for k, v in offs.items():
        face[k] = face.get(k, 0.0) + 1.0 * v
    lo, hi = p["skin"]["melanin"]
    frac = PRESET_FRAC[idx]
    hb = p["skin"]["haemoglobin"]
    hair_styles = HAIR[p["hair"] + "_" + sex]
    style = hair_styles[idx % len(hair_styles) if sex == "f" else (idx - 2) % len(hair_styles)]
    return {
        "id": "%s_%s_%s" % (p["id"], sex, tag),
        "people": p["id"],
        "label": "%s %s %s" % (p["label"], "woman" if sex == "f" else "man", tag.upper()),
        "sex": 0.0 if sex == "f" else 1.0,
        "face": _clean(face),
        "melanin": round(lo + (hi - lo) * frac, 3),
        "undertone": _pick(p["skin"]["undertone"], rng),
        "haemoglobin": round(hb[0] + (hb[1] - hb[0]) * rng.random(), 3),
        "freckles": round(p["skin"].get("freckles", [0, 0])[1] * rng.random(), 3),
        "iris": _pick(p["eyes"], rng),
        "hair": {"style": style, "color": _pick(p["hair_colors"], rng)},
        "brows": {"thickness": round((0.55 + 0.35 * rng.random()) if sex == "m" else (0.35 + 0.25 * rng.random()), 3),
                  "arch": round((0.55 if sex == "f" else 0.25) + 0.3 * (rng.random() - 0.5), 3)},
        "stubble": round(0.15 + 0.35 * rng.random(), 3) if sex == "m" else 0.0,
        "stature": round((1.07 if sex == "m" else 1.0) + 0.03 * (rng.random() - 0.5), 3),
    } | _facial_hair(p, sex, idx) | _genital(p, sex)


def _stylized_preset(p, sex, k, offs, tag, extra=None, realistic=False):
    """A stylized example individual of people p: the people's mean + offs (shared features only),
    skin, eyes and hair drawn like _preset; `extra` = (hair style, hair colour, (brow thickness, arch))
    chooses them (the showcase faces). realistic: a realistic showcase face (REALISTIC_SHOWCASE; no
    face_style, labelled "showcase")."""
    assert set(offs) <= STYLIZED_SHARED, sorted(set(offs) - STYLIZED_SHARED)
    rng = random.Random("%s-%s-%s-%s" % (p["id"], sex, "showcase" if realistic else "stylized", tag))
    face = dict(p["face"])
    for f, v in offs.items():
        m = face.get(f, 0.0)
        # an offset toward the people's own tendency shrinks with it: a feature a people already has
        # strongly is never pushed on toward the end of the range (no exaggeration)
        face[f] = m + v * (1.0 - max(0.0, m * math.copysign(1.0, v)))
    lo, hi = p["skin"]["melanin"]
    frac = [0.25, 0.55, 0.4, 0.7, 0.3, 0.6][k % 6]
    hb = p["skin"]["haemoglobin"]
    styles = HAIR[p["hair"] + "_" + sex]
    style = styles[k % len(styles)]
    color = _pick(p["hair_colors"], rng)
    brows = {"thickness": round((0.62 + 0.25 * rng.random()) if sex == "m" else (0.36 + 0.2 * rng.random()), 3),
             "arch": round((0.55 if sex == "f" else 0.25) + 0.2 * (rng.random() - 0.5), 3)}
    stubble = round(0.05 + 0.2 * rng.random(), 3) if sex == "m" else 0.0
    if k == 0 and p["region"] == "west_asia":
        # face 1 of the Middle Eastern and North African peoples in the people's commonest colour (the
        # user, 2026-09-27: a rare light brown read ginger on the first face)
        color = max(sorted(p["hair_colors"]), key=lambda c: p["hair_colors"][c])
    if extra:
        style, color, (bt, ba) = extra
        brows = {"thickness": bt, "arch": ba}
        stubble = 0.04 if sex == "m" else 0.0
    out = {
        "id": "%s_%s_%s" % (p["id"], sex, tag),
        "people": p["id"],
        "label": "%s %s, %s %s" % (p["label"], "woman" if sex == "f" else "man", "showcase" if realistic else "stylized",
                                   tag[1:]),
        "sex": 0.0 if sex == "f" else 1.0,
        "face_style": "stylized",
        "showcase": bool(extra),
        "face": _clean(face),
        "melanin": round(lo + (hi - lo) * frac, 3),
        "undertone": _pick(p["skin"]["undertone"], rng),
        "haemoglobin": round(hb[0] + (hb[1] - hb[0]) * (0.35 + 0.3 * rng.random()), 3),
        "freckles": round(p["skin"].get("freckles", [0, 0])[1] * 0.5 * rng.random(), 3),
        "iris": _pick(p["eyes"], rng),
        "hair": {"style": style, "color": color},
        "brows": brows,
        "stubble": stubble,
        "stature": round((1.07 if sex == "m" else 1.0) + 0.02 * (rng.random() - 0.3), 3),
    }
    if not extra:
        out |= _facial_hair(p, sex, k)
    out |= _genital(p, sex)
    if realistic:
        del out["face_style"]
    return out


def presets(p):
    """The people's realistic example individuals: n07's A and B per body type; for the peoples
    with realistic showcase faces (REALISTIC_SHOWCASE) per body type the two showcase faces first,
    then A, B and two more individuals C, D (EXTRA_PLAN)."""
    base = [_preset(p, sex, ind, tag, i) for i, (sex, ind, tag) in enumerate(PRESET_PLAN)]
    show = REALISTIC_SHOWCASE.get(p["id"])
    if not show:
        return base
    extra = [_preset(p, sex, ind, tag, 4 + i) for i, (sex, ind, tag) in enumerate(EXTRA_PLAN)]
    out = []
    for sex in ("f", "m"):
        for i, (offs, style, color, brows) in enumerate(show.get(sex, [])):
            out.append(_stylized_preset(p, sex, i, offs, "r%d" % (i + 1), (style, color, brows), realistic=True))
        out += [pr for pr in base + extra if pr["id"].startswith("%s_%s_" % (p["id"], sex))]
    return out


def stylized_presets(p):
    """The people's stylized faces: the showcase faces first (East and Southeast Asian peoples),
    then the shared ones; per body type."""
    out = []
    for sex in ("f", "m"):
        n = 0
        for i, (offs, style, color, brows) in enumerate(SHOWCASE.get(p["id"], {}).get(sex, [])):
            n += 1
            out.append(_stylized_preset(p, sex, n - 1, offs, "s%d" % n, (style, color, brows)))
        for offs in STYLIZED[sex]:
            n += 1
            out.append(_stylized_preset(p, sex, n - 1, offs, "s%d" % n))
    return out


def build():
    out = {"format": "frontier-peoples", "version": 1,
           "note": ("Generated by tools/character/body/peoples.py; edit that file. A people is a distribution (mean "
                    "face-feature weights, a within-group spread, skin / eye / hair frequencies); presets are example "
                    "individuals. No preset is the face of a people."),
           "features": feature_table(), "eye_colors_order": EYE_ORDER, "hair_styles": HAIR,
           "groups": [], "peoples": [], "presets": [], "stylized_presets": [],
           "stylized_shared": sorted("face_" + f for f in STYLIZED_SHARED)}
    for p in PEOPLES:
        if p["group"] not in out["groups"]:
            out["groups"].append(p["group"])
        sd = {"face_" + f[0]: f[3] for f in FEATURES}
        out["peoples"].append({
            "id": p["id"], "label": p["label"], "group": p["group"], "note": p["note"],
            "face_mean": _clean(p["face"]), "face_sd": sd, "skin": p["skin"], "eyes": p["eyes"],
            "hair_colors": p["hair_colors"], "hair_styles": {"f": HAIR[p["hair"] + "_f"], "m": HAIR[p["hair"] + "_m"]},
            "hair_texture": p.get("hair_texture", "straight"),
            "genital": GENITAL.get(p["id"], GENITAL_DEFAULT),
        })
        if p["group"] in LICENCE_GROUPS:
            out["peoples"][-1]["licence_note"] = LICENCE_NOTE
        out["presets"] += presets(p)
        out["stylized_presets"] += stylized_presets(p)
    return out


# v1 face preset names -> peoples presets (body.json "face_presets", for older tools).
LEGACY_PRESETS = {"f_face_1": "english_f_a", "f_face_2": "haudenosaunee_f_a", "f_face_3": "west_african_f_a",
                  "m_face_1": "english_m_a", "m_face_2": "haudenosaunee_m_a", "m_face_3": "west_african_m_a"}


def preset_face(preset_id):
    for pr in build()["presets"]:
        if pr["id"] == preset_id:
            return pr["face"]
    return {}


def write(path=OUT):
    d = build()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(d, f, indent=1)
    return path


if __name__ == "__main__":
    print(write(), len(build()["presets"]), "presets")
