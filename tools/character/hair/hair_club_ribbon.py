"""Long hair clubbed at the nape: the tail folded up on itself and tied with ribbon.

Costume bible §1.3, §6: "a club (the tail folded up and tied)" [M17]; men of the militia
and the regulars (B, D). Grade A.

Hair v3 recipe (hair/_recipe.py): combed back to the tie at the nape; the club a short, thick tail
folded up behind itself, on the pendulum, a black ribbon bow at the tie.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_club_ribbon", name="Club, black ribbon", slot="hair", set="hair", kind="hair",
    description="Long hair combed back, the tail folded up at the nape into a club and bound with ribbon.",
    zones=[Zone(0, "hair", name="hair"),
           Zone(1, "ribbon", "FLAT", ["logwood_black", "ribbon_black", "leather_brown"], "logwood_black", name="ribbon")],
    surfaces={"main": "hair_club_ribbon", "strands": "hair_club_ribbon_tex"},
    hair_zones=["crown", "sides", "back", "queue"], evidence="A", sources=["M17"], budget={"tris_max": 12000},
    tags=["men", "militia", "regulars"],
    history="A club: the queue folded up and tied, worn with the queue by men of every rank.",
    extra={"hair": {"queue": True, "pendulum_root_godot": [0.0, 1.428, -0.072], "texture": "straight"}},
)

RECIPE = {
    "flow": ("back", "nape"),
    "layers": ("combed", {"length": 0.30}),
    "tail": {"path": ["nape", (0.0, 0.088, 1.392), (0.0, 0.098, 1.352), (0.0, 0.097, 1.336)],
             "radii": [0.0160, 0.0190, 0.0185, 0.0095], "count": 11, "slot": "tail",
             "outer": {"slot": "clumps", "count": 8, "scale": 1.12, "jitter": 0.0015}, "fold": 0.004},
    "accents": [("bow", {"at": 0})],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
