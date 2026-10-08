"""Catalog entries (design §7.5): the spec a part module declares, the JSON fragment the
pipeline writes next to each glb, validation (schema, grade-X exclusions, respectful
terms) and the merge into assets/character/catalog.json.

    SPEC = GarmentSpec(id="ew_leggings_m", name="Wool leggings, ribbon-edged", set="woodlands",
                       slot="legs.over", layer={"default": 30}, zones=[Zone(0, "cloth", "WOOL", [...])],
                       weights="body", evidence="A", sources=["M1", "P1", "P3"], history="...")

Hair styles use the same class with kind="hair" and slot="hair" (zones: hair, ribbon or
wrap, metal). `id` is the save-file key: never rename it (keep old ids in `aliases`).
"""

import glob
import json
import os
import re
import time

from . import LIB_VERSION
from .helpers import helpers_json
from .materials import FABRICS, ROLES, TOKENS, token_hex
from .regions import HAIR_ZONES, REGIONS, regions_json
from .rig import FRONTIER, PROVENANCE_RIG

ASSETS = os.path.join(FRONTIER, "assets", "character")
CATALOG = os.path.join(ASSETS, "catalog.json")

SLOTS = ["head", "hair", "shirt", "vest", "outer", "legs.lower", "legs.over", "feet",
         "accessories.neck", "accessories.waist", "accessories.shoulder", "accessories.wrap",
         "accessories.arms", "accessories.ears_nose", "accessories.hands"]
SETS = {"frontier": "Frontiersman / trapper", "militia": "Colonial militia & provincials",
        "woodlands": "Eastern Woodlands (1750s)", "regulars": "British & French regulars", "common": "Common",
        "hair": "Hair", "colonial": "Classic clothing"}
SET_TOOLTIPS = {"woodlands": ("Clothing of the Native nations of the Northeast, such as the Haudenosaunee, Lenape, "
                              "Shawnee and Wabanaki, in the mid-1700s: wool and linen trade cloth, quillwork and "
                              "silverwork.")}
LAYERS = {"skin": 0, "base": 10, "mid": 20, "legwear": 30, "tails": 35, "outer": 40, "wrap": 50, "belts": 60,
          "hair": 70, "head": 80, "ornaments": 85}
EVIDENCE = ("A", "B", "C")

# Costume bible §3.6: grade-X items never enter the catalog, and these terms never appear
# in item, set or preset names and descriptions (UI copy). Word-boundary matches.
DENY_TERMS = [
    r"war ?bonnets?", r"gustoweh", r"kastowa", r"false ?faces?", r"medicine (?:mask|bundle)s?", r"eagles?",
    r"wampum", r"roach(?:es)?", r"pipes?", r"pipe[- ]tomahawks?", r"scalp\w*", r"war ?paint", r"squaws?",
    r"braves?", r"papooses?", r"chiefs?", r"savages?", r"redskins?", r"tribal", r"pocahontas",
    r"indian (?:costume|outfit|stockings|princess|maiden)", r"warrior outfit", r"dream ?catchers?",
]
DENY_RE = re.compile(r"\b(?:%s)\b" % "|".join(DENY_TERMS), re.IGNORECASE)


class Zone:
    def __init__(self, zone, role, fabric="FLAT", palette=None, default=None, pattern=None, bands=None, name=None):
        self.zone, self.role, self.fabric = int(zone), role, fabric
        self.palette = list(palette or [])
        self.default = default if default is not None else (self.palette[0] if self.palette else None)
        self.pattern, self.bands, self.name = pattern, bands, name or role

    def to_dict(self):
        d = {"zone": self.zone, "name": self.name, "role": self.role, "fabric": self.fabric, "palette": self.palette,
             "default": self.default, "pattern": self.pattern, "bands": self.bands}
        hexes = {}
        for t in self.palette + ([self.default] if self.default else []):
            if isinstance(t, str) and (t.startswith("#") or t in TOKENS):
                hexes[t] = token_hex(t)
        d["palette_hex"] = hexes
        return d


class GarmentSpec:
    """Declaration of a catalog part (garment, hair style, hat...)."""

    def __init__(self, id, name, slot, set="common", kind="garment", description="", layer=None, zones=(),
                 surfaces=None, weights="body", uv=None, occupies_regions=(), hides_regions=(), hides_hair_zones=(),
                 hair_zones=(), excludes=(), requires=(), alt_slots=(), variants=None, skirt=None, helpers=(),
                 face_shapes=False, evidence="A", licence_note=None, history="", sources=(), budget=None, aliases=(),
                 for_bodies=("female", "male"), tags=(), extra=None):
        self.id, self.name, self.slot, self.set, self.kind = id, name, slot, set, kind
        self.description = description
        self.layer = layer or {"default": LAYERS["hair"] if kind == "hair" else LAYERS["base"]}
        self.zones = list(zones)
        self.surfaces = surfaces or {"main": id}
        self.weights, self.uv = weights, uv
        self.occupies_regions, self.hides_regions = list(occupies_regions), list(hides_regions)
        self.hides_hair_zones, self.hair_zones = list(hides_hair_zones), list(hair_zones)
        self.excludes, self.requires, self.alt_slots = list(excludes), list(requires), list(alt_slots)
        self.variants, self.skirt, self.helpers = variants or {}, skirt, list(helpers)
        self.face_shapes = face_shapes
        self.evidence, self.licence_note, self.history, self.sources = evidence, licence_note, history, list(sources)
        self.budget = budget or {"tris_max": 6000}
        self.aliases, self.for_bodies, self.tags = list(aliases), list(for_bodies), list(tags)
        self.extra = extra or {}

    def glb_rel(self):
        if self.kind == "hair":
            return "hair/%s.glb" % self.id
        return "garments/%s/%s.glb" % (self.set, self.id)

    def entry(self, stats=None, checks=None, generator=""):
        glb = self.glb_rel()
        e = {
            "id": self.id, "name": self.name, "description": self.description, "kind": self.kind,
            "set": self.set, "slot": self.slot, "alt_slots": self.alt_slots, "layer": self.layer,
            "glb": "res://assets/character/" + glb, "mesh": self.id,
            "surfaces": [{"surface": k, "name": n} for k, n in self.surfaces.items()],
            "occupies_regions": self.occupies_regions, "hides_regions": self.hides_regions,
            "hides_hair_zones": self.hides_hair_zones, "hair_zones": self.hair_zones,
            "excludes": self.excludes, "requires": self.requires, "variants": self.variants, "skirt": self.skirt,
            "helpers": self.helpers, "body_fit": {"shapes": ["sex"] + (["face_*"] if self.face_shapes else []),
                                                  "female": "female" in self.for_bodies, "male": "male" in self.for_bodies},
            "zones": [z.to_dict() for z in self.zones], "stats": stats or {}, "budget": self.budget,
            "evidence": self.evidence, "licence_note": self.licence_note, "history": self.history,
            "sources": self.sources, "aliases": self.aliases, "tags": self.tags, "checks": checks or {},
            "generator": generator, "lib_version": LIB_VERSION,
            "provenance": (PROVENANCE_RIG + " Geometry generated procedurally by %s." % (generator or "tools/character")),
        }
        e.update(self.extra)
        return e


PartSpec = GarmentSpec


def validate_entry(e):
    """List of problems of one catalog entry (empty = valid)."""
    p = []
    for k in ("id", "name", "slot", "set", "glb", "zones", "evidence", "provenance"):
        if k not in e or e[k] in (None, ""):
            p.append("%s: missing %s" % (e.get("id", "?"), k))
    iid = e.get("id", "?")
    if not re.fullmatch(r"[a-z][a-z0-9_]*", iid):
        p.append("%s: id must be snake_case" % iid)
    if e.get("slot") not in SLOTS:
        p.append("%s: unknown slot %s" % (iid, e.get("slot")))
    for s in e.get("alt_slots", []):
        if s not in SLOTS:
            p.append("%s: unknown alt slot %s" % (iid, s))
    if e.get("set") not in SETS:
        p.append("%s: unknown set %s" % (iid, e.get("set")))
    if e.get("evidence") not in EVIDENCE:
        p.append("%s: evidence must be A, B or C (grade X items never enter the catalog)" % iid)
    if e.get("evidence") == "C" and not e.get("licence_note"):
        p.append("%s: grade C needs a licence_note" % iid)
    for key in ("occupies_regions", "hides_regions"):
        for r in e.get(key, []):
            if r not in REGIONS:
                p.append("%s: unknown region %s" % (iid, r))
    for z in e.get("hides_hair_zones", []) + e.get("hair_zones", []):
        if z not in HAIR_ZONES:
            p.append("%s: unknown hair zone %s" % (iid, z))
    zs = [z.get("zone") for z in e.get("zones", [])]
    if len(zs) != len(set(zs)) or any(z not in (0, 1, 2, 3) for z in zs):
        p.append("%s: zones must be unique ids 0..3" % iid)
    for z in e.get("zones", []):
        if z.get("role") not in ROLES:
            p.append("%s: zone %s unknown role %s" % (iid, z.get("zone"), z.get("role")))
        if z.get("fabric") not in FABRICS:
            p.append("%s: zone %s unknown fabric %s" % (iid, z.get("zone"), z.get("fabric")))
        for t in z.get("palette", []) + ([z["default"]] if z.get("default") else []):
            if not (t.startswith("#") or t in TOKENS):
                p.append("%s: zone %s unknown colour token %s" % (iid, z.get("zone"), t))
    text = " ".join(str(e.get(k, "")) for k in ("id", "name", "description"))
    m = DENY_RE.search(text.replace("_", " "))
    if m:
        p.append("%s: term not allowed in the catalog (costume bible 3.6): %r" % (iid, m.group(0)))
    budget = e.get("budget", {}).get("tris_max")
    tris = e.get("stats", {}).get("tris")
    if budget and tris and tris > budget:
        p.append("%s: %d tris over the budget %d" % (iid, tris, budget))
    glb = e.get("glb", "")
    if glb.startswith("res://") and not os.path.exists(os.path.join(FRONTIER, glb[len("res://"):])):
        p.append("%s: glb missing %s" % (iid, glb))
    return p


def fragment_path(spec):
    return os.path.join(ASSETS, os.path.splitext(spec.glb_rel())[0] + ".json")


def write_fragment(spec, stats, checks, generator):
    e = spec.entry(stats, checks, generator)
    path = fragment_path(spec)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(e, f, indent=1)
    return path, validate_entry(e)


def fragments():
    out = []
    for f in sorted(glob.glob(os.path.join(ASSETS, "hair", "*.json")) +
                    glob.glob(os.path.join(ASSETS, "garments", "**", "*.json"), recursive=True)):
        if os.path.basename(f).startswith("_"):
            continue
        with open(f) as fh:
            d = json.load(fh)
        if isinstance(d, dict) and "id" in d and "slot" in d:
            out.append(d)
    return out


def merge_catalog():
    """Merges every fragment into assets/character/catalog.json. Returns (path, n, problems)."""
    items, problems = {}, []
    for e in fragments():
        if e["id"] in items:
            problems.append("duplicate id %s" % e["id"])
        items[e["id"]] = e
        problems += validate_entry(e)
    aliases = {}
    for e in items.values():
        for a in e.get("aliases", []):
            if a in items or a in aliases:
                problems.append("alias %s clashes" % a)
            aliases[a] = e["id"]
    cat = {"format": "frontier-catalog", "version": 1, "lib_version": LIB_VERSION,
           "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "note": "Generated by tools/character (lib/catalog.py merge_catalog); never edit by hand.",
           "sets": SETS, "set_tooltips": SET_TOOLTIPS, "slots": SLOTS, "layers": LAYERS,
           "regions": regions_json(), "helpers": helpers_json(), "aliases": aliases,
           "items": {k: items[k] for k in sorted(items)}}
    with open(CATALOG, "w") as f:
        json.dump(cat, f, indent=1)
    return CATALOG, len(items), problems
