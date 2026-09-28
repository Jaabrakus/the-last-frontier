"""Plucked head with a braided crown lock, wrapped with a beaded garter at its root.

Costume bible §3.4, §6 (Eastern Woodlands men, 1750s): the head plucked or shaved except
a patch on the crown "about 3-4 inches square"; the crown hair grown long, braided or
wrapped - James Smith's locks were "wrapped with beaded garters", a third braided [P1];
Shawnee men in 1773 likewise [R2]. Grade A. No feathers here: the small dyed plume is a
separate accessory (ew_feather_tuft), never eagle.

Hair v3 recipe (hair/_recipe.py): hair only on the crown patch, drawn to the lock's root, the lock
a braid lying down the back of the skull (on the head, not the pendulum), a garter at its root and
a tie at its end.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_crown_lock_braided", name="Crown lock, braided", slot="hair", set="hair", kind="hair",
    description="Head plucked except a small patch on the crown, whose hair is grown long and braided; "
                "a beaded garter wraps the lock.",
    zones=[Zone(0, "hair", name="hair"),
           Zone(1, "wrap", "KNIT", ["madder_red", "stroud_blue", "logwood_black", "bead_white"], "madder_red",
                name="garter")],
    surfaces={"main": "hair_crown_lock_braided", "strands": "hair_crown_lock_braided_tex"},
    hair_zones=["crown", "lock"], evidence="A", sources=["P1", "R2", "P2"], budget={"tris_max": 7000},
    tags=["men", "woodlands"],
    history="Plucked head with a crown lock, braided or wrapped with beaded garters (James Smith, 1755).",
    extra={"hair": {"queue": False, "texture": "straight", "plucked": True}},
)

RECIPE = {
    "domain": {"patch": "crown"},
    "flow": ("back", "crown"),
    "layers": ("combed", {"length": 0.10, "density": 0.55}),
    "hairline": {"n": 40, "len": 0.08},
    "tail": {"path": ("back", [1.565, 1.53, 1.495, 1.462, 1.435], 0.0105),
             "radii": [0.0110, 0.0106, 0.0100, 0.0092, 0.0082, 0.0070], "count": 6, "slot": "braid", "tuft": 0.02,
             "rigid": True},
    "accents": [("band", {"at": 1, "t": 0.2, "len": 0.013, "thick": 0.0020}),
                ("band", {"at": 4, "t": 0.55, "len": 0.006, "thick": 0.0016})],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
