"""Writes assets/character/garments/militia/catalog.json: the set catalog of the colonial
militia & provincials (costume bible §4, set B): every garment's catalog fragment (as the
pipeline wrote it next to its glb), the set's outfit presets in the appearance save format
(design §11.2: slot -> {id, colors: {role: token}, fabric: {role: code}, pattern: {role:
option}}, neckwear in `accessories`), the palette tokens and fabric kits the entries use.

Plain Python 3 (no Blender): run after a build,

    python3 tools/character/garments/militia/_catalog.py

It validates the presets against the fragments (ids, slots, roles, palette tokens, fabric
choices) and exits non-zero on a problem. The file is generated; presets are edited here.
Outfit presets never set body, skin, face or hair colour (bible §3.6); `hair_hint` is only a
suggestion for the preview renders.
"""

import glob
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
FRONTIER = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
OUT_DIR = os.path.join(FRONTIER, "assets", "character", "garments", "militia")
LIB_MATERIALS = os.path.normpath(os.path.join(HERE, "..", "..", "lib", "materials.py"))


def _lib_tables():
    """FABRICS and TOKENS of lib/materials.py (literal tables; that module imports bpy, so
    they are read with ast instead of an import)."""
    import ast
    tree = ast.parse(open(LIB_MATERIALS).read())
    out = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            if node.targets[0].id in ("FABRICS", "TOKENS"):
                out[node.targets[0].id] = ast.literal_eval(node.value)
    return out["FABRICS"], out["TOKENS"]


FABRICS, TOKENS = _lib_tables()

SET_NAME = "Colonial militia & provincials"

PRESETS = [
    {"id": "militia_backcountry", "name": "Backcountry militia", "season": "summer",
     "occasion": "The look the game shipped with: linen shirt and stock, red waistcoat, caped hunting frock of "
                 "green wool, buckskin breeches, wool leggings, buckled shoes and a cocked hat.",
     "sources": ["M3", "P3"],
     "outfit": {"shirt": {"id": "shirt_linen", "colors": {"cloth": "linen_unbleached"}},
                "vest": {"id": "waistcoat_sb", "colors": {"cloth": "madder_red", "lining": "linen_unbleached",
                                                          "button": "brass"}},
                "outer": {"id": "hunting_frock", "colors": {"cloth": "ranger_green", "lining": "linen_unbleached",
                                                            "trim": "ranger_green"},
                          "fabric": {"cloth": "WOOL", "trim": "WOOL"}},
                "legs.lower": {"id": "breeches_fall", "colors": {"cloth": "buckskin_smoked", "band": "buckskin_smoked",
                                                                 "metal": "brass"}},
                "legs.over": {"id": "leggings_wool", "colors": {"cloth": "ranger_green", "band": "madder_red"}},
                "feet": {"id": "shoes_buckled", "colors": {"leather": "leather_black", "metal": "brass"}},
                "head": {"id": "tricorn", "colors": {"cloth": "logwood_black", "trim": "logwood_black",
                                                     "ribbon": "ribbon_black", "button": "brass"}}},
     "accessories": [{"id": "stock_linen", "colors": {"cloth": "linen_white", "metal": "pewter"}},
                     {"id": "horn_and_pouch", "variant": "env40", "set": "frontier"}],
     "hair_hint": "hair_queue_ribbon",
     "note": "The powder horn and shot pouch on crossed straps are the frontier set's horn_and_pouch; the legacy "
             "leather belt is not rebuilt yet."},
    {"id": "militia_townsman", "name": "Townsman militia", "season": "summer",
     "occasion": "Turned out in his own clothes: brown frock coat, drab waistcoat, wool breeches, grey stockings, "
                 "buckled shoes and a cocked hat.",
     "sources": ["M3", "R20"],
     "outfit": {"shirt": {"id": "shirt_linen", "colors": {"cloth": "linen_white"}},
                "vest": {"id": "waistcoat_sb", "colors": {"cloth": "drab", "lining": "linen_unbleached",
                                                          "button": "brass"}},
                "outer": {"id": "frock_coat", "colors": {"cloth": "walnut_brown", "lining": "drab",
                                                         "trim": "walnut_brown", "button": "brass"}},
                "legs.lower": {"id": "breeches_fall", "colors": {"cloth": "walnut_brown", "band": "walnut_brown",
                                                                 "metal": "brass"},
                               "fabric": {"cloth": "WOOL", "band": "WOOL"}},
                "legs.over": {"id": "stockings", "colors": {"cloth": "slate_grey", "ribbon": "logwood_black"}},
                "feet": {"id": "shoes_buckled", "colors": {"leather": "leather_black", "metal": "brass"}},
                "head": {"id": "tricorn", "colors": {"cloth": "logwood_black", "trim": "linen_white",
                                                     "ribbon": "ribbon_black", "button": "brass"}}},
     "accessories": [{"id": "stock_linen", "colors": {"cloth": "linen_white", "metal": "pewter"}}],
     "hair_hint": "hair_club_ribbon"},
    {"id": "provincial_ma_1758", "name": "Massachusetts provincial, 1758", "season": "summer",
     "occasion": "Blue provincial coat faced red over a red double-breasted waistcoat, leather breeches, a checked "
                 "shirt, blue leggings and the hat cut down round for the woods.",
     "sources": ["M3", "M1"],
     "outfit": {"shirt": {"id": "shirt_linen", "colors": {"cloth": "linen_white"}, "pattern": {"cloth": "check"}},
                "vest": {"id": "waistcoat_db", "colors": {"cloth": "madder_red", "lining": "linen_unbleached",
                                                          "button": "pewter"}},
                "outer": {"id": "provincial_coat_ma", "colors": {"cloth": "indigo_mid", "lining": "madder_red",
                                                                 "trim": "madder_red", "button": "pewter"}},
                "legs.lower": {"id": "breeches_fall", "colors": {"cloth": "buckskin_pale", "band": "buckskin_pale",
                                                                 "metal": "pewter"}},
                "legs.over": {"id": "leggings_wool", "colors": {"cloth": "indigo_mid", "band": "indigo_mid"}},
                "feet": {"id": "shoes_buckled", "colors": {"leather": "leather_black", "metal": "pewter"}},
                "head": {"id": "round_hat_cut", "colors": {"cloth": "logwood_black", "ribbon": "ribbon_black"}}},
     "accessories": [{"id": "neckerchief", "colors": {"cloth": "logwood_black"}}],
     "hair_hint": "hair_cropped_1758"},
    {"id": "militia_fatigue", "name": "Shirtsleeves, summer", "season": "summer",
     "occasion": "Working dress in camp or in the field: checked shirt, linen waistcoat and breeches, stockings, "
                 "shoes and a knit cap.",
     "sources": ["M3", "M2", "R22"],
     "outfit": {"shirt": {"id": "shirt_linen", "colors": {"cloth": "linen_white"}, "pattern": {"cloth": "check"}},
                "vest": {"id": "waistcoat_sb", "colors": {"cloth": "linen_unbleached", "lining": "linen_unbleached",
                                                          "button": "pewter"},
                         "fabric": {"cloth": "LIN"}},
                "legs.lower": {"id": "breeches_fall", "colors": {"cloth": "linen_unbleached",
                                                                 "band": "linen_unbleached", "metal": "pewter"},
                               "fabric": {"cloth": "LIN", "band": "LIN"}},
                "legs.over": {"id": "stockings", "colors": {"cloth": "linen_white", "ribbon": "madder_red"}},
                "feet": {"id": "shoes_buckled", "colors": {"leather": "leather_brown", "metal": "pewter"}},
                "head": {"id": "monmouth_cap", "colors": {"cloth": "walnut_brown", "band": "walnut_brown",
                                                          "button": "walnut_brown"}}},
     "accessories": [{"id": "neckerchief", "colors": {"cloth": "madder_red"}}],
     "hair_hint": "hair_queue_ribbon"},
    {"id": "militia_winter", "name": "Winter militia", "season": "winter",
     "occasion": "Wool against the cold: grey frock coat over a brown wool waistcoat, black breeches, drab "
                 "leggings, a black silk kerchief and a knit cap.",
     "sources": ["M3", "R22", "M2"],
     "outfit": {"shirt": {"id": "shirt_linen", "colors": {"cloth": "slate_grey"}, "fabric": {"cloth": "WOOL"}},
                "vest": {"id": "waistcoat_db", "colors": {"cloth": "walnut_brown", "lining": "linen_unbleached",
                                                          "button": "brass"}},
                "outer": {"id": "frock_coat", "colors": {"cloth": "slate_grey", "lining": "walnut_brown",
                                                         "trim": "slate_grey", "button": "pewter"}},
                "legs.lower": {"id": "breeches_fall", "colors": {"cloth": "logwood_black", "band": "logwood_black",
                                                                 "metal": "pewter"},
                               "fabric": {"cloth": "WOOL", "band": "WOOL"}},
                "legs.over": {"id": "leggings_wool", "colors": {"cloth": "drab", "band": "drab"}},
                "feet": {"id": "shoes_buckled", "colors": {"leather": "leather_black", "metal": "pewter"}},
                "head": {"id": "monmouth_cap", "colors": {"cloth": "slate_grey", "band": "slate_grey",
                                                          "button": "slate_grey"}}},
     "accessories": [{"id": "neckerchief", "colors": {"cloth": "logwood_black"}}],
     "hair_hint": "hair_club_ribbon",
     "note": "The bible's winter militia wears a greatcoat and mittens; those are not built yet."},
]


def fragments(directory=OUT_DIR):
    out = {}
    for f in sorted(glob.glob(os.path.join(directory, "*.json"))):
        if os.path.basename(f) in ("catalog.json",) or os.path.basename(f).startswith("_"):
            continue
        with open(f) as fh:
            d = json.load(fh)
        if isinstance(d, dict) and "id" in d and "slot" in d:
            out[d["id"]] = d
    return out


def check_item_use(items, slot, use, problems, where):
    iid = use.get("id")
    if iid not in items:
        problems.append("%s: unknown item %s" % (where, iid))
        return
    e = items[iid]
    if use.get("variant") and use["variant"] not in (e.get("variants") or {}):
        problems.append("%s: %s has no variant %s" % (where, iid, use["variant"]))
    if slot is not None and e["slot"] != slot and slot not in e.get("alt_slots", []):
        problems.append("%s: %s is a %s item, not %s" % (where, iid, e["slot"], slot))
    roles = {z["role"]: z for z in e["zones"]}
    if len(roles) != len(e["zones"]) and (use.get("colors") or use.get("fabric")):
        problems.append("%s: %s has zones sharing a role; colours by role are ambiguous" % (where, iid))
    for role, tok in use.get("colors", {}).items():
        if role not in roles:
            problems.append("%s: %s has no zone role %s" % (where, iid, role))
        elif not (tok.startswith("#") or tok in TOKENS):
            problems.append("%s: unknown colour token %s" % (where, tok))
    for role, code in use.get("fabric", {}).items():
        if role not in roles:
            problems.append("%s: %s has no zone role %s" % (where, iid, role))
        elif code not in roles[role].get("fabrics", [roles[role]["fabric"]]):
            problems.append("%s: %s zone %s cannot take fabric %s" % (where, iid, role, code))
    for role, opt in use.get("pattern", {}).items():
        pat = (roles.get(role) or {}).get("pattern") or {}
        if opt not in pat.get("options", []):
            problems.append("%s: %s zone %s has no pattern %s" % (where, iid, role, opt))


def main():
    items = fragments()
    problems = []
    if not items:
        problems.append("no fragments in %s" % OUT_DIR)
    # items of other sets a preset may use (e.g. the frontier set's horn and pouch)
    others = {}
    for d in sorted(glob.glob(os.path.join(OUT_DIR, "..", "*"))):
        if os.path.isdir(d) and os.path.basename(d) != "militia":
            others.update(fragments(d))
    everything = dict(others)
    everything.update(items)
    cross = {}
    for p in PRESETS:
        for slot, use in p["outfit"].items():
            check_item_use(everything, slot, use, problems, p["id"] + "/" + slot)
        for use in p.get("accessories", []):
            check_item_use(everything, None, use, problems, p["id"] + "/accessories")
            if use["id"] in others:
                cross[use["id"]] = others[use["id"]]
    used = set()
    for e in items.values():
        for z in e["zones"]:
            used.update(t for t in z.get("palette", []) + [z.get("default")] if t)
    cat = {
        "format": "frontier-catalog-set", "version": 1, "set": "militia", "set_name": SET_NAME,
        "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "note": ("Generated by tools/character/garments/militia/_catalog.py from the garment fragments written by "
                 "build_character.sh --garments militia; merged into assets/character/catalog.json by "
                 "lib.catalog.merge_catalog (fragments), never edited by hand."),
        "items": {k: items[k] for k in sorted(items)},
        "presets": PRESETS,
        "cross_set_items": cross,
        "tokens": {t: TOKENS[t] for t in sorted(used) if t in TOKENS},
        "fabrics": {k: {"kit": v[0], "tile_m": v[1]} for k, v in FABRICS.items()},
        "provenance": ("Garment geometry generated procedurally by tools/character/garments/militia; skeleton and "
                       "bind pose from the Actor_B rig; fabric kits derived from Poly Haven CC0 scans."),
    }
    path = os.path.join(OUT_DIR, "catalog.json")
    with open(path, "w") as f:
        json.dump(cat, f, indent=1)
    print("wrote %s: %d items, %d presets" % (path, len(items), len(PRESETS)))
    for p in problems:
        print("PROBLEM:", p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
