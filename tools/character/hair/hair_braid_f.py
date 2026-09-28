"""Long hair in a single braid, tied at the end.

Costume bible 6: "Long single braid, tied" - Native women and habitantes (grade B).

Hair v3 recipe (hair/_recipe.py): parted in the middle and drawn back to the nape, plaited in a
single braid down the back on the pendulum, tied near its end with the loose ends below.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_braid_f", name="Long braid, tied", slot="hair", set="hair", kind="hair",
    description="Long hair parted in the middle and worn in a single braid down the back, tied at the end.",
    zones=[Zone(0, "hair", name="hair"),
           Zone(1, "ribbon", "FLAT", ["stroud_red", "ribbon_red", "ribbon_blue", "leather_brown", "logwood_black"],
                "stroud_red", name="tie")],
    surfaces={"main": "hair_braid_f", "strands": "hair_braid_f_tex"},
    hair_zones=["crown", "sides", "back", "queue"], evidence="B", sources=["R1", "R2"], budget={"tris_max": 12000},
    tags=["women", "woodlands", "habitant"],
    history="A single long braid, tied: worn by Native women and by habitant women (grade B).",
    extra={"hair": {"queue": True, "pendulum_root_godot": [0.0, 1.428, -0.072], "texture": "straight", "part": "centre"}},
)

RECIPE = {
    "flow": ("parted_back", "nape"),
    "layers": ("combed", {"length": 0.30}),
    "tail": {"path": ("back", [1.36, 1.30, 1.24, 1.18, 1.13], 0.030),
             "radii": [0.0165, 0.0160, 0.0150, 0.0138, 0.0122, 0.0105], "count": 5, "slot": "braid", "tuft": 0.045},
    "accents": [("band", {"at": 4, "t": 0.82, "len": 0.010, "thick": 0.0018})],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
