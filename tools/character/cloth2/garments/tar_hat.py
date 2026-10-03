"""The tar hat (cloth2: recipes.rigid_hat, a hats.ROUND_HAT style, the Drift crews' set): a low round hat of felt
blacked with tar, the brim turned down all round, a tarred cord for a band with a lanyard eye. The seaman's
'tarpaulin'."""

import numpy as np

from cloth2 import drift as D
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import hats as HT
from cloth2 import recipes
from cloth2.spec import Spec, Zone

STYLE = dict(HT.ROUND_HAT, crown_h=0.064, brim_r=0.138, droop=0.027, band_h=0.011, tilt=-4.0, rings=4, lower=0.006)

SPEC = Spec(
    id="tar_hat", name="Tar hat", set="drift", slot="head", layer={"default": 80},
    description="A low round hat of tarred black felt with a narrow brim turned down all round and a tarred cord band "
                "with a lanyard eye.",
    history="By the 1770s the seaman's usual hat was low-crowned, flat-topped and narrow-brimmed, of black felt or "
            "tarred canvas; cocked hats, higher crowns and knitted caps were worn too [D1]. A hat tarred against the "
            "wet gave the seaman his nickname, a 'tarpaulin' (to be checked against period use).",
    zones=[Zone(0, "tarred felt", "cloth", "WOOL", ["tar_black", "logwood_black", "slate_grey"], "tar_black"),
           Zone(1, "cord band", "band", "TWILL", ["tar_black", "hemp", "linen_unbleached"], "tar_black"),
           Zone(3, "lanyard eye", "metal", "MET", ["brass", "pewter"], "brass", metal=True)],
    hides_hair_zones=["crown"], sources=["D1"], evidence="B", tags=["drift", "sailor"], budget=1700,
    extra={"references": ["[D1] HMS Richmond, Sailor's Dress of 1775: https://hmsrichmond.org/sailordress.htm"],
           "felt_note": "Felt uses the WOOL kit with a soft nap (ClothMaterials FELT_WORDS: the id has 'hat')."})


def build(g):
    recipes.rigid_hat(g, STYLE)
    C, R, st = g._hat
    # the lanyard eye: a small brass ring on the band at the back left, lying on the crown wall
    th = np.radians(150.0)
    p = np.array([st["crown_a"] * np.sin(th) * 1.02, -st["crown_b"] * np.cos(th) * 1.02, st["band_h"] * 0.5])
    n = np.array([np.sin(th) / st["crown_a"], -np.cos(th) / st["crown_b"], 0.0])
    n = n / np.linalg.norm(n)
    D.head_rigid(g, HW.ring(0.0055, 0.0014, 10, 4, z0=0.0012), C + p @ R.T, n @ R.T, 3, part=6)


build_and_export = G.runner(SPEC, build)
