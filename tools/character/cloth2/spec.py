"""cloth2 garment spec: what the catalog says about a garment (the entry's fields, assets/character/catalog.json).

  SPEC = Spec(id="shirt_linen", name="Linen shirt", set="colonial", slot="shirt", layer={"default": 10},
              description="...", history="... [P1]", sources=["P1"], evidence="A", tags=["men", "women"],
              zones=[Zone(0, "linen", "cloth", "LIN", ["linen_white", "linen_unbleached"], "linen_white")])

The zone fields are what ClothMaterials.garment_materials reads: role (cloth, trim, leather, metal, button, fur,
ribbon, lining, band, fringe), fabric code (fabrics.json: LIN WOOL TWILL KNIT SUEDE LEA FUR HES FLAT, MET for metal),
the palette tokens (palette.json: token -> "#hex") and the default one; up to four zones per surface. New tokens
are added to palette.json (PALETTE_EXTRA below carries the ones the newer sets brought).

Glow (2026-10-02): Zone(..., glow=Glow(strength, pulse, life)) marks an emissive zone (the Drift crews' piping, the
mote belt's cells): the entry's zone gets "glow": {"strength", "pulse", "life", "color"} for ClothMaterials (the
cloth shader does not draw it yet: a zone flagged glow renders as its colour until it does). `over`: the catalog ids
the garment is fitted over (Garment.over clears their built meshes), recorded in the entry's "fit_over".
"""

import json
import os
from dataclasses import dataclass, field

HERE = os.path.dirname(os.path.abspath(__file__))
PALETTE = json.load(open(os.path.join(HERE, "palette.json")))
LAYERS = {"skin": 0, "base": 10, "mid": 20, "legwear": 30, "tails": 35, "outer": 40, "wrap": 50, "belts": 60,
          "hair": 70, "head": 80, "ornaments": 85}
BODY_SHAPES = ["sex", "breast_large", "breast_small"]


@dataclass
class Glow:
    strength: float = 1.0       # emission at night in the Drift (x the zone colour; 0 = off)
    pulse: float = 0.0          # slow pulse amplitude 0..1 (the galleon's glow: SkyTraffic._glow)
    life: float = 1.0           # 1 alive .. 0 spent (fades the colour toward `dead`: under our sky)
    color: str = "keel_glow"    # the glow's palette token (or "#hex")
    dead: str = "dead_stone"

    def entry(self):
        return {"strength": self.strength, "pulse": self.pulse, "life": self.life, "color": self.color,
                "dead": self.dead}


@dataclass
class Zone:
    idx: int
    name: str
    role: str
    fabric: str
    palette: list
    default: str
    pattern: dict = None
    bands: dict = None
    metal: bool = False
    glow: Glow = None

    def entry(self):
        hexes = {}
        for tok in self.palette:
            if tok not in PALETTE:
                raise KeyError("palette token %r is not in cloth2/palette.json" % tok)
            hexes[tok] = PALETTE[tok]
        d = {"zone": self.idx, "name": self.name, "role": self.role, "fabric": self.fabric, "palette": list(self.palette),
             "default": self.default, "pattern": self.pattern, "bands": self.bands, "palette_hex": hexes,
             "fabrics": [self.fabric]}
        d["metal"] = bool(self.metal or self.role == "metal")
        if self.glow is not None:
            d["glow"] = self.glow.entry()
        return d


@dataclass
class Spec:
    id: str
    name: str
    set: str
    slot: str
    layer: dict
    description: str
    history: str
    zones: list
    sources: list = field(default_factory=list)
    evidence: str = "B"
    tags: list = field(default_factory=list)
    budget: int = 4400
    alt_slots: list = field(default_factory=list)
    excludes: list = field(default_factory=list)
    requires: list = field(default_factory=list)
    hides_hair_zones: list = field(default_factory=list)
    hair_zones: list = field(default_factory=list)
    review: str = None
    hides_force: list = field(default_factory=list)   # body regions the garment certainly covers (the ray test cannot tell: the crotch)
    licence_note: str = None
    extra: dict = field(default_factory=dict)
    over: list = field(default_factory=list)          # catalog ids fitted over (Garment.over)

    def glb_rel(self):
        return "garments/%s/%s.glb" % (self.set, self.id)

    def entry(self, stats, occupies, hides, checks, generator, skirt=None):
        d = self._entry(stats, occupies, hides, checks, generator, skirt)
        if self.over:
            d["fit_over"] = list(self.over)
        if self.extra:
            d["extra"] = dict(self.extra)
        return d

    def _entry(self, stats, occupies, hides, checks, generator, skirt=None):
        return {
            "id": self.id, "name": self.name, "description": self.description, "kind": "garment", "set": self.set,
            "slot": self.slot, "alt_slots": list(self.alt_slots), "layer": dict(self.layer),
            "glb": "res://assets/character/" + self.glb_rel(), "mesh": self.id,
            "surfaces": [{"surface": "main", "name": self.id}],
            "occupies_regions": occupies, "hides_regions": hides, "hides_hair_zones": list(self.hides_hair_zones),
            "hair_zones": list(self.hair_zones), "excludes": list(self.excludes), "requires": list(self.requires),
            "variants": {}, "skirt": skirt, "helpers": [],
            "body_fit": {"shapes": list(BODY_SHAPES), "female": True, "male": True},
            "zones": [z.entry() for z in self.zones], "stats": stats, "budget": {"tris_max": self.budget},
            "evidence": self.evidence, "licence_note": self.licence_note, "history": self.history,
            "sources": list(self.sources), "aliases": [], "tags": list(self.tags), "checks": checks,
            "generator": generator, "lib_version": 2,
            "provenance": ("Skeleton, bone names and bind pose: Actor_B rig. Geometry "
                           "generated procedurally by " + generator + " (cloth2: grown from the MakeHuman body's surface)."),
            "fabric_note": ("Fabric: approved Poly Haven CC0 kit (assets/polyhaven/textures/clothing), luminance detail "
                            "tinted to the palette colour at runtime; UVs in metres along the grain."),
            "review": self.review,
        }
