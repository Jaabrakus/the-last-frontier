"""Siamese men's crop: the crown left short and upright, the sides and back cropped close.

The men of Ayutthaya (Siam) in the 1700s wore the hair short: a brush of about an inch on the
crown, the sides and back cut close. People from Siam were rare in the colonial northeast:
grade C, a customizer choice for the game's wider cast (2026-09-26).

Hair v3 recipe (hair/_recipe.py): on the crown short strips rising steeply off the scalp (a brush
standing up), the sides and back a close crop.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_siamese_crop", name="Siamese crop", slot="hair", set="hair", kind="hair",
    description="Hair about an inch long on the crown, standing up like a brush; the sides and back cropped close.",
    zones=[Zone(0, "hair", name="hair")], hair_zones=["crown", "sides", "back"], evidence="C",
    licence_note="Period style of Siam (Thailand); such travellers were rare in the 1750s northeast.",
    sources=[], budget={"tris_max": 9000}, tags=["men", "any"], surfaces={"strands": "hair_siamese_crop_tex"},
    history="The Siamese men's cut of the eighteenth century: short and upright on the crown, close at the sides.",
    extra={"hair": {"queue": False, "texture": "cropped"}},
)

BRUSH = ("crown", {"center": (0.0, -0.005), "half": (0.052, 0.07), "r": 0.03, "z0": 1.545})

RECIPE = {
    "flow": ("whorl",),
    "layers": [
        {"region": BRUSH, "n": 460, "slot": "crop", "w": 0.013, "len": 0.03, "off": (0.002, 0.022), "taper": 0.3,
         "step": 0.006, "root_len": 0.0},
        {"region": BRUSH, "n": 220, "slot": "crop", "w": 0.015, "len": 0.025, "off": (0.0015, 0.008), "taper": 0.3,
         "step": 0.006},
        {"region": ("rest",) + BRUSH[1:], "n": 560, "slot": "crop", "w": 0.014, "len": 0.018, "off": (0.001, 0.0035),
         "taper": 0.35, "step": 0.006},
    ],
    "hairline": {"n": 110, "slot": "crop", "w": 0.011, "len": 0.015, "off": (0.0008, 0.0025), "step": 0.006},
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
