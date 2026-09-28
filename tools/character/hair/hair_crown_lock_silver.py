"""Plucked head with a crown lock set with silver plates.

Costume bible §3.2, §3.4, §6: the crown lock "stuck full of silver brooches" (James Smith
[P1]); silver hair plates or tubes [R2]. Grade A.

Hair v3 recipe (hair/_recipe.py): hair only on the crown patch, drawn to the lock's root; the lock
lies down the back of the skull (on the head), tied at its root, set with three silver plates.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_crown_lock_silver", name="Crown lock, silver plates", slot="hair", set="hair", kind="hair",
    description="Head plucked except a small patch on the crown; the long crown lock is set with silver plates.",
    zones=[Zone(0, "hair", name="hair"), Zone(1, "wrap", "KNIT", ["madder_red", "stroud_blue", "logwood_black"],
                                              "logwood_black", name="tie"),
           Zone(2, "metal", "MET", ["silver"], "silver", name="silver")],
    surfaces={"main": "hair_crown_lock_silver", "strands": "hair_crown_lock_silver_tex"},
    hair_zones=["crown", "lock"], evidence="A", sources=["P1", "R2"], budget={"tris_max": 8000},
    tags=["men", "woodlands"],
    history="A crown lock set with silver brooches or hair plates (James Smith, 1755; Shawnee, 1773).",
    extra={"hair": {"queue": False, "texture": "straight", "plucked": True}},
)

RECIPE = {
    "domain": {"patch": "crown"},
    "flow": ("back", "crown"),
    "layers": ("combed", {"length": 0.10, "density": 0.55}),
    "hairline": {"n": 40, "len": 0.08},
    "tail": {"path": ("back", [1.565, 1.53, 1.495, 1.462, 1.435], 0.0095),
             "radii": [0.0095, 0.0092, 0.0088, 0.0082, 0.0074, 0.0066], "count": 7, "slot": "tail", "tuft": 0.022,
             "rigid": True},
    "accents": [("band", {"at": 0, "t": 0.75, "len": 0.008}),
                ("band", {"at": 1, "t": 0.5, "len": 0.012, "zone": 2}),
                ("band", {"at": 2, "t": 0.5, "len": 0.012, "zone": 2}),
                ("band", {"at": 3, "t": 0.5, "len": 0.012, "zone": 2})],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
