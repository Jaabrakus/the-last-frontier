"""Set catalog of the Frontiersman / trapper garments (plain Python, not Blender).

    python3 tools/character/garments/frontier/_set_catalog.py

Collects the catalog fragments the generators wrote (assets/character/garments/frontier/
<id>.json, design §7.5 schema) into assets/character/garments/frontier/catalog.json, with
the set's outfit presets (save format §11.2: slot -> {id, colors: {zone name: token}},
accessories) and validation of every preset against the fragments. The merged runtime
catalog (assets/character/catalog.json) is written by lib/catalog.py merge_catalog; this
file has no top-level "id" / "slot", so the merge and the glb checks skip it.

Presets never change body, skin, face or hair (costume bible §3.6). Items of the bible's
set A that other workstreams or later passes provide (shirt_check, breechclout_cloth,
round_hat, fur_mantle, sash_fingerwoven, mittens_wool, ...) are listed per preset under
"suggested" and are not equipped, so every preset loads with the items that exist.
"""

import json
import os
import time

HERE = os.path.dirname(os.path.abspath(__file__))
FRONTIER = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
GDIR = os.path.join(FRONTIER, "assets", "character", "garments", "frontier")

PRESETS = [
    {"id": "frontier_winter_trapper", "name": "Winter trapper", "season": "winter",
     "outfit": {"outer": {"id": "capot_blanket", "colors": {"blanket": "#E3DED0", "ties": "ribbon_red"},
                          "bands": {"blanket": {"rows": 2, "color": "stroud_blue"}}},
                "head": {"id": "fur_cap", "colors": {"fur": "fur_beaver"}},
                "legs.over": {"id": "leggings_buckskin", "colors": {"buckskin": "buckskin_smoked", "garters": "madder_red"}},
                "feet": {"id": "moccasins_puckered", "colors": {"deerskin": "buckskin_smoked"}}},
     "accessories": [{"id": "horn_and_pouch", "variant": "env40"}],
     "suggested": ["fur_mantle (bear)", "sash_fingerwoven", "leggings_wool", "mittens_wool", "shirt_flannel"],
     "note": "Costume bible §2.6 'Winter trapper': capot, fur cap, mantle, sash, wool leggings, moccasins, mittens."},
    {"id": "frontier_fur_coat", "name": "Fur coat (artistic licence)", "season": "winter",
     "outfit": {"outer": {"id": "fur_coat_tailored", "colors": {"fur": "fur_black_bear", "hide lining": "buckskin_smoked"}},
                "head": {"id": "fur_cap", "colors": {"fur": "fur_raccoon"}},
                "legs.over": {"id": "leggings_buckskin"},
                "feet": {"id": "moccasins_puckered"}},
     "accessories": [{"id": "horn_and_pouch", "variant": "env50"}],
     "suggested": ["shirt_flannel", "breeches_buckskin", "mittens_wool"],
     "note": "The tailored fur coat is grade C (bible §2.4); bear, beaver, wolf and raccoon colourings."},
    {"id": "frontier_backcountry_hunter", "name": "Backcountry hunter, summer", "season": "summer",
     "outfit": {"outer": {"id": "hunting_shirt_tow", "colors": {"cloth": "tow", "fringe": "linen_unbleached"}},
                "legs.over": {"id": "leggings_buckskin", "colors": {"buckskin": "buckskin_pale"}},
                "feet": {"id": "moccasins_puckered"}},
     "accessories": [{"id": "horn_and_pouch", "variant": "env40"}],
     "suggested": ["shirt_check", "breechclout_cloth", "leggings_long_wool", "round_hat", "belt_tied_behind"],
     "note": "Costume bible §2.6 'Backcountry hunter (summer)'."},
    {"id": "frontier_hunter_autumn", "name": "Hunter, autumn", "season": "autumn",
     "outfit": {"outer": {"id": "hunting_shirt_tow", "colors": {"cloth": "walnut_brown", "fringe": "ribbon_red"}},
                "head": {"id": "fur_cap", "colors": {"fur": "fur_red_fox"}},
                "legs.over": {"id": "leggings_buckskin"},
                "feet": {"id": "moccasins_puckered"}},
     "accessories": [{"id": "powder_horn", "variant": "env40"}],
     "suggested": ["shirt_white", "breeches_wool", "shot_pouch"],
     "note": "A dyed hunting shirt with a contrasting fringe (bible §2.2, Doddridge)."},
]


def load_fragments():
    items = {}
    for f in sorted(os.listdir(GDIR)):
        if not f.endswith(".json") or f in ("catalog.json",):
            continue
        with open(os.path.join(GDIR, f)) as fh:
            d = json.load(fh)
        if isinstance(d, dict) and "id" in d and "slot" in d:
            items[d["id"]] = d
    return items


def validate_preset(p, items):
    probs = []
    used = list(p["outfit"].items()) + [(i.get("slot", "accessories"), i) for i in p.get("accessories", [])]
    for slot, it in used:
        e = items.get(it["id"])
        if e is None:
            probs.append("%s: unknown item %s" % (p["id"], it["id"]))
            continue
        if slot in p["outfit"] and slot not in [e["slot"]] + e.get("alt_slots", []):
            probs.append("%s: %s is not a %s item" % (p["id"], it["id"], slot))
        names = {z["name"]: z for z in e["zones"]}
        for zn, tok in it.get("colors", {}).items():
            if zn not in names:
                probs.append("%s: %s has no zone %s" % (p["id"], it["id"], zn))
            elif tok not in names[zn]["palette"] and not tok.startswith("#"):
                probs.append("%s: %s zone %s: %s not in its palette" % (p["id"], it["id"], zn, tok))
        var = it.get("variant")
        if var and var not in (e.get("variants") or {}):
            probs.append("%s: %s has no variant %s" % (p["id"], it["id"], var))
    return probs


def main():
    items = load_fragments()
    probs = []
    for p in PRESETS:
        probs += validate_preset(p, items)
    cat = {"format": "frontier-set-catalog", "version": 1, "set": "frontier", "set_name": "Frontiersman / trapper",
           "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "note": ("Generated by tools/character/garments/frontier/_set_catalog.py from the fragments next to it; "
                    "never edit by hand. Colours in presets are keyed by zone name."),
           "items": items, "presets": PRESETS, "problems": probs}
    path = os.path.join(GDIR, "catalog.json")
    with open(path, "w") as fh:
        json.dump(cat, fh, indent=1)
    print("%d items, %d presets -> %s" % (len(items), len(PRESETS), path))
    for q in probs:
        print("PROBLEM", q)
    return 0 if not probs else 1


if __name__ == "__main__":
    raise SystemExit(main())
