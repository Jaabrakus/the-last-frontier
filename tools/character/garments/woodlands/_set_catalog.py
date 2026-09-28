"""Set catalog of the Eastern Woodlands garments (pure Python 3, no Blender):

    python3 tools/character/garments/woodlands/_set_catalog.py [--check]

1. Updates each fragment's "deform_limits" from _limits.py (the scan-based limits, so they
   can be refreshed without rebuilding the glbs; the generators write the same values).
2. Writes assets/character/garments/woodlands/catalog.json: the set's items (the catalog
   fragments, unchanged otherwise), the outfit presets named by occasion (costume bible
   §3.6, §3.8) and the set's name, tooltip and review note.
3. Validates: every preset item exists and sits in its slot, colours are in the zone's
   palette, and no UI text uses the bible's deny-list terms (lib/catalog.py DENY_TERMS, read
   from the source so this runs outside Blender).

Presets change the outfit only: never body, skin, face, eyes or hair (bible §3.6, design §13.3).
Colour keys are zone names (unique within an item).
"""

import ast
import glob
import json
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
FRONTIER = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
OUT_DIR = os.path.join(FRONTIER, "assets", "character", "garments", "woodlands")
sys.path.insert(0, HERE)
from _limits import SCANS, limits_for  # noqa: E402

SET_NAME = "Eastern Woodlands (1750s)"
TOOLTIP = ("Clothing of the Native nations of the Northeast, such as the Haudenosaunee, Lenape, Shawnee and Wabanaki, "
           "in the mid-1700s: wool and linen trade cloth, quillwork and silverwork.")
REVIEW = ("This set shows the dress of living nations. It follows the costume bible (sections 3.1-3.8) and has not been "
          "reviewed by the nations concerned; paid review of meshes, names and lore by their cultural or "
          "historic-preservation offices is needed before public release, and consultants should be credited.")

RIB = {"flap": ["ribbon_red", "bead_white"]}

PRESETS = [
    {"id": "ew_everyday_summer_m", "name": "Everyday, summer", "occasion": "everyday", "season": "summer",
     "note": "Shirt worn loose over the breechcloth, leggings and moccasins [R3][P2].",
     "outfit": {"shirt": {"id": "ew_shirt_linen", "colors": {"linen": "linen_unbleached"}},
                "legs.lower": {"id": "ew_breechcloth", "colors": {"cloth": "stroud_blue"}},
                "legs.over": {"id": "ew_leggings_m", "colors": {"cloth": "stroud_blue", "flap": "stroud_blue",
                                                                "garters": "madder_red"},
                              "bands": {"flap": ["ribbon_red"]}},
                "feet": {"id": "ew_moccasins_m", "colors": {"leather": "buckskin_smoked", "seam quills": "quill_orange",
                                                            "cuffs": "buckskin_smoked"}}},
     "accessories": []},
    {"id": "ew_everyday_winter_m", "name": "Everyday, winter", "occasion": "everyday", "season": "winter",
     "note": "The summer dress with a blanket worn as a matchcoat [R3][P2].",
     "outfit": {"shirt": {"id": "ew_shirt_linen", "colors": {"linen": "linen_white"}, "pattern": {"linen": "check"}},
                "legs.lower": {"id": "ew_breechcloth", "colors": {"cloth": "stroud_blue"}},
                "legs.over": {"id": "ew_leggings_m", "colors": {"cloth": "stroud_blue", "flap": "stroud_blue",
                                                                "garters": "madder_red"}},
                "feet": {"id": "ew_moccasins_m", "colors": {"leather": "buckskin_smoked", "seam quills": "quill_black"}}},
     "accessories": [{"id": "ew_matchcoat", "colors": {"blanket": "stroud_blue", "belt": "leather_brown"}}]},
    {"id": "ew_formal_m", "name": "Formal / council dress", "occasion": "formal", "season": "any",
     "note": "Ruffled shirt, gorget, arm bands and brooches, ribbon-edged leggings and a finger-woven sash "
             "[P1][P2][M11]; the bible's list adds a blanket (see the winter variant: the sash and the blanket's "
             "own belt do not layer).",
     "outfit": {"shirt": {"id": "ew_shirt_ruffled", "colors": {"linen": "linen_white"}},
                "legs.lower": {"id": "ew_breechcloth", "colors": {"cloth": "stroud_red"}},
                "legs.over": {"id": "ew_leggings_m", "colors": {"cloth": "stroud_blue", "flap": "stroud_blue",
                                                                "garters": "madder_red"},
                              "bands": {"flap": ["ribbon_yellow", "bead_white"]}},
                "feet": {"id": "ew_moccasins_m", "colors": {"leather": "buckskin_smoked", "seam quills": "quill_orange",
                                                            "cuffs": "stroud_red"},
                         "bands": {"cuffs": ["bead_white", "quill_orange", "quill_black"]}}},
     "accessories": [{"id": "ew_gorget"}, {"id": "ew_armbands"}, {"id": "ew_brooches"},
                     {"id": "ew_sash", "colors": {"sash": "madder_red"}}]},
    {"id": "ew_formal_winter_m", "name": "Formal / council dress, winter", "occasion": "formal", "season": "winter",
     "note": "The formal dress with a ribbon-edged blanket in place of the sash [P2][R3].",
     "outfit": {"shirt": {"id": "ew_shirt_ruffled", "colors": {"linen": "linen_white"}},
                "legs.lower": {"id": "ew_breechcloth", "colors": {"cloth": "stroud_red"}},
                "legs.over": {"id": "ew_leggings_m", "colors": {"cloth": "stroud_blue", "flap": "stroud_blue",
                                                                "garters": "madder_red"},
                              "bands": {"flap": ["ribbon_yellow", "bead_white"]}},
                "feet": {"id": "ew_moccasins_m", "colors": {"leather": "buckskin_smoked", "seam quills": "quill_orange",
                                                            "cuffs": "stroud_red"},
                         "bands": {"cuffs": ["bead_white", "quill_orange", "quill_black"]}}},
     "accessories": [{"id": "ew_gorget"}, {"id": "ew_armbands"}, {"id": "ew_brooches"},
                     {"id": "ew_matchcoat", "colors": {"blanket": "stroud_blue"},
                      "bands": {"blanket": ["ribbon_red", "ribbon_yellow"]}}]},
    {"id": "ew_hunting_m", "name": "Hunting", "occasion": "hunting", "season": "summer",
     "note": "The shirt could be left off in fighting or hunting [R3].",
     "outfit": {"legs.lower": {"id": "ew_breechcloth", "colors": {"cloth": "stroud_blue"}},
                "legs.over": {"id": "ew_leggings_m", "colors": {"cloth": "ranger_green", "flap": "ranger_green",
                                                                "garters": "madder_red"}},
                "feet": {"id": "ew_moccasins_m", "colors": {"leather": "buckskin_smoked", "seam quills": "quill_black"}},
                "head": {"id": "ew_head_wrap", "colors": {"silk": "logwood_black"}}},
     "accessories": [{"id": "ew_sash", "colors": {"sash": "stroud_blue"}}]},
    {"id": "ew_everyday_f", "name": "Everyday (women)", "occasion": "everyday", "season": "any",
     "note": "Long shirt over the wrap skirt, knee-high leggings, moccasins and a blanket [R1][P4].",
     "outfit": {"shirt": {"id": "ew_shift_f", "colors": {"linen": "linen_unbleached"}},
                "legs.lower": {"id": "ew_wrap_skirt_f", "colors": {"cloth": "stroud_blue", "turned-down band": "stroud_blue"}},
                "legs.over": {"id": "ew_leggings_f", "colors": {"cloth": "stroud_blue", "flap": "stroud_blue"}},
                "feet": {"id": "ew_moccasins_f", "colors": {"leather": "buckskin_smoked", "cones": "brass"}}},
     "accessories": [{"id": "ew_matchcoat", "colors": {"blanket": "stroud_red"}}]},
    {"id": "ew_formal_f", "name": "Formal (women)", "occasion": "formal", "season": "any",
     "note": "Shirt with brooches and a red collar, ribbon-edged skirt and leggings, ear bobs and a ribbon-edged "
             "blanket [R1][P2][R2].",
     "outfit": {"shirt": {"id": "ew_shift_f", "colors": {"linen": "linen_white", "collar and wrist bands": "madder_red"}},
                "legs.lower": {"id": "ew_wrap_skirt_f", "colors": {"cloth": "stroud_blue", "turned-down band": "stroud_blue"},
                               "bands": {"cloth": ["ribbon_red", "ribbon_yellow", "ribbon_green"]}},
                "legs.over": {"id": "ew_leggings_f", "colors": {"cloth": "stroud_red", "flap": "stroud_red"},
                              "bands": {"cloth": ["ribbon_blue"], "flap": ["ribbon_yellow", "bead_white"]}},
                "feet": {"id": "ew_moccasins_f", "colors": {"leather": "buckskin_smoked", "cones": "silver"},
                         "bands": {"cuff": ["bead_white", "quill_white"]}}},
     "accessories": [{"id": "ew_brooches"}, {"id": "ew_earbobs"}, {"id": "ew_wristbands"},
                     {"id": "ew_matchcoat", "colors": {"blanket": "stroud_blue"},
                      "bands": {"blanket": ["ribbon_red", "ribbon_white"]}}]},
]


def deny_regex():
    src = open(os.path.join(FRONTIER, "tools", "character", "lib", "catalog.py")).read()
    tree = ast.parse(src)
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and any(getattr(t, "id", "") == "DENY_TERMS" for t in node.targets):
            terms = ast.literal_eval(node.value)
            return re.compile(r"\b(?:%s)\b" % "|".join(terms), re.IGNORECASE)
    raise SystemExit("DENY_TERMS not found in lib/catalog.py")


def main():
    check_only = "--check" in sys.argv
    deny = deny_regex()
    items, problems = {}, []
    for f in sorted(glob.glob(os.path.join(OUT_DIR, "ew_*.json"))):
        e = json.load(open(f))
        if not isinstance(e, dict) or "id" not in e:
            continue
        lim = limits_for(e["id"])
        if e.get("deform_limits", {}).get(e["id"]) != lim:
            e.setdefault("deform_limits", {})[e["id"]] = lim
            if not check_only:
                with open(f, "w") as fh:
                    json.dump(e, fh, indent=1)
        if e["id"] in SCANS:
            e["deform_scan"] = {"worse_fit_percent_and_ratio": list(SCANS[e["id"]]),
                                "method": "check_body_deform.gd, 44 clips x 8 samples, sex 0 and 1; limits = +25 %"}
        items[e["id"]] = e
        for k in ("id", "name", "description"):
            m = deny.search(str(e.get(k, "")).replace("_", " "))
            if m:
                problems.append("%s: %s uses a deny-list term %r" % (e["id"], k, m.group(0)))
    for p in PRESETS:
        for k in ("name", "note"):
            m = deny.search(p.get(k, ""))
            if m:
                problems.append("preset %s: %s uses %r" % (p["id"], k, m.group(0)))
        entries = [(slot, v) for slot, v in p["outfit"].items()] + [(None, a) for a in p["accessories"]]
        ids = [v["id"] for _, v in entries]
        for _, v in entries:
            for x in items.get(v["id"], {}).get("excludes", []):
                if x in ids:
                    problems.append("preset %s: %s excludes %s" % (p["id"], v["id"], x))
        for slot, v in entries:
            it = items.get(v["id"])
            if it is None:
                problems.append("preset %s: unknown item %s" % (p["id"], v["id"]))
                continue
            if slot is not None and it["slot"] != slot and slot not in it.get("alt_slots", []):
                problems.append("preset %s: %s is %s, not %s" % (p["id"], v["id"], it["slot"], slot))
            if slot is None and not it["slot"].startswith("accessories"):
                problems.append("preset %s: %s is not an accessory" % (p["id"], v["id"]))
            zones = {z["name"]: z for z in it["zones"]}
            for zn, tok in v.get("colors", {}).items():
                if zn not in zones:
                    problems.append("preset %s: %s has no zone %r" % (p["id"], v["id"], zn))
                elif tok not in zones[zn]["palette"]:
                    problems.append("preset %s: %s zone %s: %s not in its palette" % (p["id"], v["id"], zn, tok))
            for zn, rows in v.get("bands", {}).items():
                z = zones.get(zn)
                pal = ((z or {}).get("bands") or {}).get("palette", [])
                for tok in rows:
                    if tok not in pal:
                        problems.append("preset %s: %s band %s: %s not in the band palette" % (p["id"], v["id"], zn, tok))
            for zn, pat in v.get("pattern", {}).items():
                z = zones.get(zn)
                if pat not in (((z or {}).get("pattern") or {}).get("options", [])):
                    problems.append("preset %s: %s zone %s: pattern %s not offered" % (p["id"], v["id"], zn, pat))
    cat = {"format": "frontier-catalog-set", "version": 1, "set": "woodlands", "name": SET_NAME, "tooltip": TOOLTIP,
           "review": REVIEW,
           "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "note": "Written by tools/character/garments/woodlands/_set_catalog.py from the catalog fragments "
                   "(ew_*.json, written by the generators); the merged assets/character/catalog.json is the runtime "
                   "source for items. Presets change the outfit only (never body, skin, face, eyes or hair); colour "
                   "keys are zone names.",
           "items": items, "presets": PRESETS,
           "not_built": {"ew_shirt_calico": "calico is a pattern option of the shirts (grade B, 1770s)",
                         "ew_fur_robe": "fur shells: the fur workstream (lib.fur)",
                         "ew_capot / ew_trade_coat": "coats: optional, shared with the frontier and regulars sets",
                         "ew_garters": "part of the leggings (zone 'garters')",
                         "ew_feather_tuft, ew_hair_plates, ew_hair_club_wrap_f": "hair attachments: the hair styles "
                                                                                 "hair_crown_lock_silver and "
                                                                                 "hair_club_wrapped_f carry them",
                         "ew_nose_jewel, ew_shot_pouch, ew_tumpline, ew_bedgown_f": "not built yet"},
           "problems": problems}
    if not check_only:
        with open(os.path.join(OUT_DIR, "catalog.json"), "w") as f:
            json.dump(cat, f, indent=1)
    print("woodlands set catalog: %d items, %d presets, %d problems" % (len(items), len(PRESETS), len(problems)))
    for p in problems:
        print("  PROBLEM", p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
