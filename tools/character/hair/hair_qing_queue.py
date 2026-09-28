"""The Qing queue: the front of the head shaved, the rest grown long in one braid down the back.

From 1645 the Qing required the men of China to shave the head above the temples and wear the rest
of the hair in a single long braid (the queue, bianzi); by the 1750s it was universal among Chinese
men at home and abroad. Chinese travellers were rare in the colonial northeast: a customizer choice
for the game's wider cast (grade B: the style itself is well documented).

Hair v3 recipe (hair/_recipe.py): hair only behind a line from ear to ear over the crown, combed back
to the nape; the braid on the pendulum to the small of the back, a silk cord and tassel at its end.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_qing_queue", name="Queue, shaved front (Qing)", slot="hair", set="hair", kind="hair",
    description="The front of the head shaved above the temples; the rest grown long and plaited in one braid down "
                "the back, finished with a silk cord.",
    zones=[Zone(0, "hair", name="hair"),
           Zone(1, "cord", "FLAT", ["logwood_black", "ribbon_red", "ribbon_blue"], "logwood_black", name="cord")],
    surfaces={"main": "hair_qing_queue", "strands": "hair_qing_queue_tex"},
    hair_zones=["crown", "sides", "back", "queue"], evidence="B",
    licence_note="Period style of Qing China; Chinese travellers were rare in the 1750s northeast.",
    sources=[], budget={"tris_max": 12000}, tags=["men", "any"],
    history="Required of Chinese men under the Qing from 1645: the front shaved, the rest in one long braid.",
    extra={"hair": {"queue": True, "pendulum_root_godot": [0.0, 1.428, -0.072], "texture": "straight"}},
)

RECIPE = {
    "domain": {"patch": "qing"},
    "flow": ("back", "nape"),
    "layers": ("combed", {"length": 0.25}),
    "hairline": {"n": 70, "len": 0.2},
    "tail": {"path": ("back", [1.36, 1.29, 1.21, 1.13, 1.05, 0.98], 0.028),
             "radii": [0.0125, 0.0120, 0.0112, 0.0104, 0.0095, 0.0085, 0.0075], "count": 5, "slot": "braid", "tuft": 0.06,
             "lie": (0.12, 0.35, 0.35)},
    "accents": [("band", {"at": 5, "t": 0.85, "len": 0.012})],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
