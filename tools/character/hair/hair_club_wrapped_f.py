"""Long hair parted in the middle and gathered behind into a flat club, wrapped.

Costume bible §3.4, §6 (Eastern Woodlands women, 1750s): the hair long, parted in the
middle and never cut, "gathered behind into a flat club shaped like a lobster's tail,
about 4 inches wide", covered with an eel skin dyed red (Pouchot, 1755-60) or wrapped in
ribbons or silver plates (Carver, 1766-68) [R1]. Grade A. The wrap colour options include
silver (a metal wrap).

Hair v3 recipe (hair/_recipe.py): parted and drawn back to the nape, the club a flat tail about
3.5 inches wide down the back on the pendulum, the wrap over most of its length.
"""

from lib.catalog import GarmentSpec, Zone

from hair import _recipe as R

SPEC = GarmentSpec(
    id="hair_club_wrapped_f", name="Parted, flat club wrapped", slot="hair", set="hair", kind="hair",
    description="Long hair parted in the middle and gathered behind into a flat club about four inches wide, "
                "wrapped with dyed skin, cloth, ribbon or silver.",
    zones=[Zone(0, "hair", name="hair"),
           Zone(1, "wrap", "SUEDE", ["stroud_red", "ribbon_red", "ribbon_blue", "logwood_black", "silver"],
                "stroud_red", name="wrap")],
    surfaces={"main": "hair_club_wrapped_f", "strands": "hair_club_wrapped_f_tex"},
    hair_zones=["crown", "sides", "back", "queue"], evidence="A", sources=["R1"], budget={"tris_max": 13000},
    tags=["women", "woodlands"],
    history="Parted in the middle and gathered into a flat club like a lobster's tail, wrapped with red-dyed skin "
            "(Pouchot) or ribbons and silver plates (Carver).",
    extra={"hair": {"queue": True, "pendulum_root_godot": [0.0, 1.428, -0.072], "texture": "straight", "part": "centre"}},
)

RECIPE = {
    "flow": ("parted_back", "nape"),
    "layers": ("combed", {"length": 0.30}),
    "tail": {"path": ("back", [1.33, 1.24], 0.028), "radii": [0.0115, 0.0125, 0.0110], "count": 12, "slot": "tail",
             "aspect": 3.3, "radius": 0.06, "tuft": 0.02},
    "accents": [("wrap", {"from": 0.2, "to": 0.97, "aspect": 3.3, "pad": 0.0022, "tris": 1000})],
}


def build(ctx):
    return R.build(ctx, SPEC, RECIPE)
