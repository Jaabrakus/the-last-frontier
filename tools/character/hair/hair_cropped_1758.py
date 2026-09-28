"""Hair cropped to about an inch: "an Army of round Heads" (Huck, 1758). Costume bible 1.3, 6: in July 1758
Abercromby's army cropped its hair to about an inch [M1]. Grade A.

Hair v3 recipe (hair/_recipe.py): short strips of the cropped strands all over the head, lying
out from the crown whorl.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_cropped_1758", name="Cropped short (1758)", slot="hair", set="hair", kind="hair",
    description="Hair cropped to about an inch all over, as the army cut it on campaign in 1758.",
    zones=[Zone(0, "hair", name="hair")], hair_zones=["crown", "sides", "back"], evidence="A", sources=["M1"],
    budget={"tris_max": 9000}, tags=["men", "militia", "regulars", "frontier"], surfaces={"strands": "hair_cropped_1758_tex"},
    history="Abercromby's army cropped its hair to about an inch in 1758: 'an Army of round Heads'.",
    extra={"hair": {"queue": False, "texture": "cropped"}},
)

RECIPE = {
    "flow": ("whorl",),
    "layers": ("crop", {"length": 0.035}),
    "hairline": {"n": 120, "slot": "crop", "w": 0.012, "len": 0.03, "off": (0.001, 0.004), "step": 0.008},
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
