"""Long hair combed back and tied at the nape in a queue bound with black ribbon.

Costume bible 1.3, 6: the usual style of men of European and African descent in the colonies,
"the man's own hair, long, tied at the nape in a queue ... bound with black ribbon" [M17]. Grade A.

Hair v3 recipe (hair/_recipe.py): combed straight back from the hairline and the temples to the
tie at the nape, the queue a ring of strips on the pendulum, a black ribbon bow with two tails.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_queue_ribbon", name="Queue, black ribbon", slot="hair", set="hair", kind="hair",
    description="Long hair combed back and tied at the nape in a queue bound with ribbon.",
    zones=[Zone(0, "hair", name="hair"),
           Zone(1, "ribbon", "FLAT", ["logwood_black", "ribbon_black", "leather_brown", "ribbon_red", "ribbon_blue"],
                "logwood_black", name="ribbon")],
    surfaces={"main": "hair_queue_ribbon", "strands": "hair_queue_ribbon_tex"},
    hair_zones=["crown", "sides", "back", "queue"],
    evidence="A", sources=["M17", "M1"], budget={"tris_max": 12000}, tags=["men", "militia", "frontier", "regulars"],
    history="Own hair, long, tied at the nape in a queue with black ribbon: the usual style (Williamsburg wigmaker's accounts).",
    extra={"hair": {"queue": True, "pendulum_root_godot": [0.0, 1.428, -0.072], "texture": "straight"}},
)

RECIPE = {
    "flow": ("back", "nape"),
    "layers": ("combed", {"length": 0.30}),
    "tail": {"path": ["nape", (0.0, 0.093, 1.365), (0.0, 0.114, 1.304)], "radii": [0.0150, 0.0135, 0.0120],
             "count": 9, "slot": "tail"},
    "accents": [("bow", {"at": 0})],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
