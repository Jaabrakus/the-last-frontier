"""The bag wig: powdered, a curl above each ear, the queue in a black silk bag with a bow.

Costume bible §1.3: gentlemen and officers of the 1750s wore a powdered wig or their own hair dressed
the same way, with side curls (buckles) above the ears and the queue enclosed in a black silk bag
tied with a bow at the nape (the bag wig): a mark of rank on the frontier, where the rank and file
wore their own hair queued or cropped. Grade A.

Hair v3 recipe (hair/_recipe.py): combed back to the nape; two rolled curls along each side above
the ear (following the head); the queue short, in the bag (a flat rounded box on the pendulum) under
a black bow. Powdered unless the look sets another powder.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_bag_wig", name="Bag wig, powdered", slot="hair", set="hair", kind="hair",
    description="Powdered hair with a rolled curl above each ear, the queue enclosed in a black silk bag with a bow.",
    zones=[Zone(0, "hair", name="hair"),
           Zone(1, "bag", "FLAT", ["logwood_black", "ribbon_black"], "logwood_black", name="bag")],
    surfaces={"main": "hair_bag_wig", "strands": "hair_bag_wig_tex"},
    hair_zones=["crown", "sides", "back", "queue"], evidence="A", sources=["M17"], budget={"tris_max": 15000},
    tags=["men", "regulars", "gentry"],
    history="The bag wig of officers and gentlemen: powdered, side curls, the queue in a black silk bag.",
    extra={"hair": {"queue": True, "pendulum_root_godot": [0.0, 1.428, -0.072], "texture": "straight", "powder": 0.9}},
)

ROLL = {"radii": [0.0085, 0.0100, 0.0105, 0.0100, 0.0080], "count": 9, "slot": "dense", "follow": "body", "mirror": True,
        "outer": {"slot": "clumps", "count": 7, "scale": 1.1, "jitter": 0.0008}}

RECIPE = {
    "flow": ("back", "nape"),
    "layers": ("combed", {"length": 0.28, "volume": 1.2}),
    "tail": {"path": ["nape", (0.0, 0.080, 1.400), (0.0, 0.084, 1.380)], "radii": [0.0140, 0.0130, 0.0110], "count": 8,
             "slot": "tail"},
    "tails": [dict(ROLL, path=("side", [(-0.038, 1.512), (-0.018, 1.516), (0.004, 1.516), (0.026, 1.512),
                                        (0.044, 1.504)], 0.010)),
              dict(ROLL, path=("side", [(-0.030, 1.537), (-0.010, 1.542), (0.012, 1.541), (0.032, 1.535),
                                        (0.048, 1.526)], 0.010))],
    "accents": [("box", {"c": (0.0, 0.012, -0.052), "half": (0.046, 0.0075, 0.050), "r": 0.008}),
                ("bow", {"at": 0})],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
