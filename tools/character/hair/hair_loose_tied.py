"""Long hair tied at the nape, common on the frontier and among Native men [M17][P1]. Grade B.

Hair v3 recipe (hair/_recipe.py): combed back and tied at the nape with a leather thong, the tail
hanging loose down the back on the pendulum.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_loose_tied", name="Long, loosely tied", slot="hair", set="hair", kind="hair",
    description="Long hair combed back and tied at the nape.",
    zones=[Zone(0, "hair", name="hair"),
           Zone(1, "tie", "SUEDE", ["leather_brown", "logwood_black", "stroud_red"], "leather_brown", name="tie")],
    surfaces={"main": "hair_loose_tied", "strands": "hair_loose_tied_tex"},
    hair_zones=["crown", "sides", "back", "queue"], evidence="B", sources=["M17", "P1"], budget={"tris_max": 14000},
    tags=["men", "frontier", "woodlands"],
    history="Long hair tied at the nape, common on the frontier; long tied or loose hair also among Native men.",
    extra={"hair": {"queue": True, "pendulum_root_godot": [0.0, 1.428, -0.072], "texture": "straight"}},
)

RECIPE = {
    "flow": ("back", "nape"),
    "layers": ("combed", {"length": 0.30}),
    "tail": {"path": ("back", [1.37, 1.31, 1.25, 1.20], 0.034), "radii": [0.0150, 0.0175, 0.0180, 0.0165, 0.0120],
             "count": 10, "slot": "clumps", "jitter": 0.0015, "tuft": 0.03,
             "outer": {"slot": "fine", "count": 8, "scale": 1.2, "jitter": 0.004}},
    "accents": [("band", {"at": 0, "t": 0.12, "len": 0.008, "thick": 0.0014})],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
