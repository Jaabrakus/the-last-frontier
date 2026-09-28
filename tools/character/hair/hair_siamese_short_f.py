"""Siamese women's short hair: cut short and round, combed up from the forehead, a long lock
at each temple tucked behind the ear.

The women of Ayutthaya (Siam) in the 1700s, like the men, wore the hair short: an inch or two
on the crown, combed up and back from the forehead, shorter round the ears and at the nape,
with a lock at each temple left long and tucked behind the ear. People from Siam were rare in
the colonial northeast: grade C, a customizer choice for the game's wider cast (2026-09-26).

Hair v3 recipe (hair/_recipe.py): short hair combed up and back, fuller on the crown; the temple
locks laid by hand over the ear's root and behind it to about the jaw.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_siamese_short_f", name="Short, combed up (Siamese)", slot="hair", set="hair", kind="hair",
    description=("Hair cut short and round, fuller on the crown and combed up and back from the forehead; a "
                 "long lock at each temple tucked behind the ear."),
    zones=[Zone(0, "hair", name="hair")], hair_zones=["crown", "sides", "back"], evidence="C",
    licence_note="Period style of Siam (Thailand); such travellers were rare in the 1750s northeast.",
    sources=[], budget={"tris_max": 10000}, tags=["women", "any"], surfaces={"strands": "hair_siamese_short_f_tex"},
    history=("Siamese women of the eighteenth century wore the hair short like the men, combed up from the "
             "forehead, a lock at each temple tucked behind the ear."),
    extra={"hair": {"queue": False, "texture": "straight"}},
)

RECIPE = {
    "flow": ("dir", (0.0, 1.0, 0.45)),
    "layers": ("combed", {"length": 0.075, "density": 1.6, "volume": 1.6}),
    "hairline": {"n": 110, "len": 0.06},
    # over the v3 head's ear (z 1.433-1.487, y -0.038..-0.008): from the temple over the ear's root and down
    # behind it to about the jaw; laid on the head, the ear left out
    "locks": [{"pts": [(0.068, -0.055, 1.500), (0.074, -0.035, 1.497), (0.074, -0.006, 1.494), (0.070, 0.008, 1.470),
                       (0.066, 0.010, 1.445), (0.062, 0.008, 1.420)], "w": 0.009, "n": 3, "slot": "clumps", "off": 0.004}],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
