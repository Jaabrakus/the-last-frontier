"""Checks of the Thủy Vân trait maps and data (python3 only, no Blender, no Godot):

    python3 tools/thuyvan_art/traits/test_trait_maps.py

- the maps exist at 2048 RGBA, and rebuild bit for bit from trait_maps.py (fixed seeds)
- the lips are never scaled or plated; the palms never plated; the gills only on the neck and head
- the data files are valid JSON, carry no stat, and lock nothing to a people
"""
import json
import os
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import trait_maps as TM  # noqa: E402

ROOT = TM.ROOT
MAPS = os.path.join(ROOT, "assets", "thuyvan", "character", "traits")
DATA = os.path.join(ROOT, "data", "thuyvan_art")
STAT_WORDS = ("speed", "aim", "damage", "armor", "armour", "health", "stamina_bonus", "bonus")


class TraitMaps(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.body = TM.Body()
        cls.R = TM.raster(cls.body, TM.GAME_N, os.environ.get("TRAITS_CACHE"))
        cls.A = TM.Anatomy(cls.body, cls.R)

    def test_maps_exist(self):
        for f in ("trait_order_tv.png", "trait_detail_tv.png", "ash_marks_tv.png"):
            im = Image.open(os.path.join(MAPS, f))
            self.assertEqual(im.size, (TM.GAME_N, TM.GAME_N), f)
            self.assertEqual(im.mode, "RGBA", f)

    def test_rebuild_is_identical(self):
        with tempfile.TemporaryDirectory() as d:
            TM.write_maps(d, cache=os.environ.get("TRAITS_CACHE"))
            for f in ("trait_order_tv.png", "trait_detail_tv.png", "ash_marks_tv.png"):
                a = np.asarray(Image.open(os.path.join(d, f)))
                b = np.asarray(Image.open(os.path.join(MAPS, f)))
                self.assertTrue(np.array_equal(a, b), f + " differs from a rebuild")

    def test_lips_never_marked(self):
        lips = self.A.is_("head") & (self.R["col"][:, 1] > 0.3) & self.R["inside"]
        self.assertGreater(lips.sum(), 100)
        self.assertTrue(np.all(TM.order_scales(self.A)[lips] > 1.0))
        self.assertTrue(np.all(TM.order_plates(self.A)[lips] > 1.0))

    def test_palms_never_plated(self):
        palm = self.A.is_("hand") & self.A.palm() & self.R["inside"]
        self.assertGreater(palm.sum(), 100)
        self.assertTrue(np.all(TM.order_plates(self.A)[palm] > 1.0))

    def test_gills_on_the_neck_only(self):
        g = TM.gills(self.A)
        on = g > 0.5
        self.assertGreater(on.sum(), 50, "no gill slits drawn")
        self.assertTrue(np.all(self.A.is_("neck_upper", "head")[on]))
        # both sides
        self.assertGreater((self.A.P[on, 0] > 0).sum(), 10)
        self.assertGreater((self.A.P[on, 0] < 0).sum(), 10)

    def test_scale_order_spreads_in_design_order(self):
        o = TM.order_scales(self.A)
        ins = self.R["inside"]
        wr = np.median(o[ins & self.A.is_("wrist")])
        th = o[ins & self.A.is_("thigh")]
        self.assertLess(wr, 0.35)
        self.assertGreater(np.median(th[th < 1.5]) if (th < 1.5).any() else 2.0, 0.6)

    def test_hash_is_the_shaders(self):
        # hash12 of skin_common.gdshaderinc at a known point (computed by hand from the GLSL)
        x, y = np.array([3.0]), np.array([-2.0])
        p3 = np.array([3.0 * 0.1031, -2.0 * 0.1031, 3.0 * 0.1031])
        p3 = p3 - np.floor(p3)
        p3 = p3 + np.dot(p3, p3[[1, 2, 0]] + 33.33)
        v = (p3[0] + p3[1]) * p3[2]
        self.assertAlmostEqual(float(TM.hash2(x, y)[0]), v - np.floor(v), places=9)


class TraitData(unittest.TestCase):
    def _walk(self, d, path=""):
        if isinstance(d, dict):
            for k, v in d.items():
                for w in STAT_WORDS:
                    self.assertNotIn(w, k.lower(), "stat-like key %s%s" % (path, k))
                self._walk(v, path + k + ".")
        elif isinstance(d, list):
            for v in d:
                self._walk(v, path)

    def test_json_valid_and_no_stats(self):
        for f in ("traits.json", "fox_features.json"):
            p = os.path.join(DATA, f)
            if not os.path.exists(p):
                continue
            d = json.load(open(p))
            self._walk(d)
        json.load(open(os.path.join(MAPS, "traits_maps.json")))

    def test_every_people_listed_and_nothing_locked(self):
        d = json.load(open(os.path.join(DATA, "traits.json")))
        self.assertEqual(set(d["peoples"]), {"dragon_sea", "mountain_folk", "stone_children", "riverborn", "ho_tinh",
                                             "ancestor_bound"})
        for k, m in d["markings"].items():
            self.assertIn("anyone may wear", m["note"], k)
        txt = json.dumps(d).lower()
        for banned in ("faces_only", "exclude_faces", "skin_only", "hollow tide", "ninth river", "convergence"):
            self.assertNotIn(banned, txt)


if __name__ == "__main__":
    unittest.main()
