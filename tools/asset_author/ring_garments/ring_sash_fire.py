"""The fire side's sash (ring_garments._sash): gold wound over the red top, a narrow band (the top is short)."""

from ring_garments import _sash

SPEC, build, build_and_export = _sash.make(
    "ring_sash_fire", "Fire side sash", "fire", ["ring_fire_top", "ring_trousers_fitted"],
    ["ring_gold", "ring_char", "ring_ember", "ring_flame"], "ring_char", "ring_gold", z=(0.96, 1.06),
    height=0.058, end_len=0.24)
