"""The air side's sash (ring_garments._sash): rust wound over the marigold tunic, saffron fringe."""

from ring_garments import _sash

SPEC, build, build_and_export = _sash.make(
    "ring_sash_air", "Air side sash", "air", ["ring_air_tunic", "ring_trousers_wide"],
    ["ring_rust", "ring_saffron", "ring_tangerine", "ring_marigold", "ring_cream"], "ring_rust", "ring_saffron",
    end_len=0.12)
