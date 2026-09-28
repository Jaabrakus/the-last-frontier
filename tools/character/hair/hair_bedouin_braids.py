"""Long hair in two braids falling in front of the shoulders.

Bedouin Arab men wore the hair long and plaited, a braid (or more) falling at each side of the face
down onto the chest. Grade B: a customizer choice for the game's wider cast.

Hair v3 recipe (hair/_recipe.py): parted, each side combed down to a braid rooted in front of the
ear; the braids hang over the chest (following the body).
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_bedouin_braids", name="Two braids at the sides", slot="hair", set="hair", kind="hair",
    description="Long hair parted in the middle and plaited in a braid at each side, falling in front of the "
                "shoulders.",
    zones=[Zone(0, "hair", name="hair")], hair_zones=["crown", "sides", "back"], evidence="B",
    sources=[], budget={"tris_max": 13000}, tags=["men", "any"], surfaces={"strands": "hair_bedouin_braids_tex"},
    history="Bedouin Arab men wore the hair long, plaited in braids falling at the sides of the face.",
    extra={"hair": {"queue": False, "texture": "straight", "part": "centre"}},
)

ROOT = (0.074, -0.040, 1.442)

RECIPE = {
    "flow": ("nearest", [ROOT, (-ROOT[0], ROOT[1], ROOT[2])]),
    "layers": ("combed", {"length": 0.30}),
    "tails": [{"root": ROOT, "path": ("front", [1.40, 1.34, 1.28, 1.22, 1.16], 0.042, 0.090),
               "radii": [0.0110, 0.0105, 0.0100, 0.0094, 0.0086, 0.0078], "count": 4, "slot": "braid", "tuft": 0.03,
               "follow": "body", "mirror": True}],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
