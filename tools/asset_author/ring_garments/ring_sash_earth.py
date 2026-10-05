"""The earth side's sash (ring_garments._sash): dark umber wound over the ochre tunic, ochre fringe."""

from ring_garments import _sash

SPEC, build, build_and_export = _sash.make(
    "ring_sash_earth", "Earth side sash", "earth", ["ring_earth_tunic", "ring_trousers_wrapped"],
    ["ring_umber", "ring_moss", "ring_olive", "ring_ochre", "ring_khaki"], "ring_umber", "ring_ochre")
