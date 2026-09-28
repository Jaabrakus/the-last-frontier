"""Hair pinned up at the back of the head (worn under a linen cap).

Costume bible §1.3, §4.3, §6: colonial women's hair was pinned up under a linen cap,
never loose in public [R13][M16]; sets A, B and D. Grade A. The cap itself is a head
item (cap_linen) that hides the crown and back zones.

Hair v3 recipe (hair/_recipe.py): parted in the middle, drawn back smoothly and wound into a knot
high at the back of the head.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_pinned_capped", name="Pinned up", slot="hair", set="hair", kind="hair",
    description="Long hair parted in the middle, drawn back and pinned up at the back of the head, "
                "to be worn under a linen cap.",
    zones=[Zone(0, "hair", name="hair")], hair_zones=["crown", "sides", "back"], evidence="A",
    sources=["R13", "M16"], budget={"tris_max": 13500}, tags=["women", "militia", "frontier", "regulars"],
    surfaces={"strands": "hair_pinned_capped_tex"},
    history="Colonial women pinned their hair up under a linen cap; a hat went over the cap outdoors.",
    extra={"hair": {"queue": False, "texture": "straight", "part": "centre"}},
)

RECIPE = {
    "flow": ("parted_back", "bun_high"),
    "layers": ("combed", {"length": 0.30, "density": 0.8}),
    "bun": {"radii": (0.034, 0.024, 0.029), "rings": 12},
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
