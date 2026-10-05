"""Light ring shoes (cloth2.feet.SockTube): soft cloth shoes to below the ankle on a thin leather sole, a bound top
edge and a strap over the instep; light for the deck. The earth, fire and air sides wear them in their own colours."""

from cloth2 import garment as G
from cloth2.mesh import REF
from cloth2.spec import Spec, Zone

from ring_garments import _common as C
from ring_garments import _feet as F

UPPER = ["ring_felt", "ring_umber", "ring_char", "ring_rust", "ring_olive_dark", "ring_navy", "ring_cream"]
TOP = 0.098

SPEC = Spec(
    id="ring_shoes", name="Ring shoes", set=C.SET, slot="feet", layer={"default": 40},
    description="Soft cloth shoes to below the ankle on a thin leather sole, a bound top edge and an instep strap.",
    history=C.HISTORY,
    zones=[Zone(0, "upper", "cloth", "WOOL", UPPER, "ring_felt"),
           Zone(1, "sole", "leather", "LEA", ["ring_sole", "leather_brown", "leather_black"], "ring_sole"),
           Zone(2, "binding and strap", "trim", "FLAT", UPPER + ["ring_ochre", "ring_gold", "ring_saffron"],
                "ring_umber")],
    evidence="C", tags=C.tags("earth", "fire", "air"), budget=3200,
    extra={"presets": {"earth": {"0": "ring_umber", "1": "ring_sole", "2": "ring_ochre"},
                       "fire": {"0": "ring_char", "1": "ring_sole", "2": "ring_gold"},
                       "air": {"0": "ring_rust", "1": "ring_sole", "2": "ring_saffron"}},
           "recipe_note": "feet.SockTube 4.6 mm off the skin cut at 0.098, the sole below 1.3 cm, the top bound."})


def build(g):
    F.tube(g, TOP, 0.0046)
    F.sole(g, 1)
    g.edge_zone(2, 0.010, select=lambda P: P[:, 2] > TOP - 0.02, h=0.0015)
    F.strap(g, 2)
    g.fits.clear(g.m, 0.002)
    g.hem = lambda m: m.boundary()[1] & (m.V[REF][:, 2] > TOP - 0.02)
    F.uv(g)


build_and_export = G.runner(SPEC, build)
