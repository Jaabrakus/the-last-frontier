#!/usr/bin/env python3
"""R1's region bake (bake_region.py over squares.json, carved through water_net.py): the checks T4 owes.

    python3 -m unittest discover -s tools/environment/terrain/regions -p 'test_regions.py'     # from the Frontier root

Bakes every square once into a temporary folder (about 45 s), then:

  layout       squares.json has the layout's twelve cells with the layout's types; every type has bounds and a status
  seed         a rebake of C1 and B2 in a fresh process is bit-identical (every .bin)
  seams        the shared edges of neighbouring squares agree within 1 cm
  beds         along every channel's centre line the ground is under the water's surface by at least the bed depth
               (water.json's; a pound's own depth where the line crosses one), exactly as height_field() makes it and
               within 5 cm on the baked grid; no baked sample in the water stands over its surface
  flat         every pound's floor and every paddy step's floor (inside its bund) is flat within 2 cm on the baked grid
  bounds       every baked height lies within the bounds of the recipes that shape it there
  downstream   the main channel's bed on its centre line never rises downstream (it may drop sharply at the lock step)

TV_LAYOUT=<path> names the layout while data/world/maps/r1/layout.json is not committed (the tests skip without one).
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bake_region as br  # noqa: E402
from common import bilinear  # noqa: E402

TMP = None
REG = None
SEAM_TOL = 0.01
FLAT_TOL = 0.02


def setUpModule():
    global TMP, REG
    if not os.path.exists(br.LAYOUT):
        raise unittest.SkipTest("no layout at %s (T0 commits it; TV_LAYOUT=<path> names another)" % br.LAYOUT)
    REG = br.Region(br.LAYOUT)
    TMP = tempfile.mkdtemp(prefix="r1_bake_")
    for cid in sorted(REG.cells):
        br.bake_square(REG, cid, os.path.join(TMP, cid), previews=False, quiet=True)


def tearDownModule():
    if TMP:
        shutil.rmtree(TMP, ignore_errors=True)


def height(cid):
    return np.fromfile(os.path.join(TMP, cid, "height.bin"), "<f4").reshape(br.N, br.N).astype(np.float64)


def baked_at(x, z):
    """Bilinear heights off the baked squares at world points (each point read from the square that holds it)."""
    out = np.full(np.shape(x), np.nan)
    for cid, c in REG.cells.items():
        x0, z0 = c["cx"] - br.HALF, c["cz"] - br.HALF
        m = (x >= x0) & (x <= x0 + 2 * br.HALF) & (z >= z0) & (z <= z0 + 2 * br.HALF) & np.isnan(out)
        if m.any():
            out[m] = bilinear(height(cid), x[m], z[m], x0, z0)
    return out


def centre_line(cid, ds=1.0):
    ch = REG.net.by_id[cid]
    s = np.arange(0.0, float(ch.s[-1]), ds)
    return s, np.interp(s, ch.s, ch.x), np.interp(s, ch.s, ch.z), np.interp(s, ch.s, ch.bed_depth)


def pound_depth(x, z):
    """At each point inside a live pound, its depth (level - floor); nan elsewhere."""
    d = np.full(np.shape(x), np.nan)
    for p in REG.pounds:
        if not REG.net._live(p.get("milestone", "M1")):
            continue
        m = br.polygon_inside(p["polygon"], x, z)
        d[m] = float(p["level"]) - float(p["bed"])
    return d


class TestLayout(unittest.TestCase):
    def test_cells(self):
        cells = REG.layout["grid"]["cells"]
        self.assertEqual(sorted(REG.squares["cells"]), sorted(cells))
        for cid, typ in cells.items():
            self.assertEqual(REG.squares["cells"][cid]["type"], typ, cid)
            t = REG.squares["types"][typ]
            self.assertIn(t["status"], ("full", "placeholder"), typ)
            self.assertEqual(len(t["bounds_m"]), 2, typ)
        full = {t for t, v in REG.squares["types"].items() if v["status"] == "full"}
        self.assertTrue({"gorge", "terraced_slope", "middle_reach", "switchbacks", "rim"} <= full)


class TestSeed(unittest.TestCase):
    def test_rebake_bit_identical(self):
        tmp2 = tempfile.mkdtemp(prefix="r1_rebake_")
        try:
            env = dict(os.environ, TV_LAYOUT=br.LAYOUT)
            subprocess.run([sys.executable, "-W", "ignore", os.path.join(HERE, "bake_region.py"), "--cell", "C1,B2",
                            "--out", tmp2, "--no-previews"], check=True, env=env, stdout=subprocess.DEVNULL)
            for cid in ("C1", "B2"):
                names = sorted(n for n in os.listdir(os.path.join(TMP, cid)) if n.endswith(".bin"))
                self.assertGreaterEqual(len(names), 10)
                for n in names:
                    with open(os.path.join(TMP, cid, n), "rb") as a, open(os.path.join(tmp2, cid, n), "rb") as b:
                        self.assertEqual(a.read(), b.read(), "%s/%s differs on a rebake" % (cid, n))
        finally:
            shutil.rmtree(tmp2, ignore_errors=True)


class TestSeams(unittest.TestCase):
    def test_shared_edges(self):
        worst = 0.0
        for cid, c in REG.cells.items():
            for other, o in REG.cells.items():
                if o["col"] == c["col"] + 1 and o["row"] == c["row"]:
                    d = np.abs(height(cid)[:, -1] - height(other)[:, 0])
                elif o["row"] == c["row"] + 1 and o["col"] == c["col"]:
                    d = np.abs(height(cid)[-1, :] - height(other)[0, :])
                else:
                    continue
                worst = max(worst, float(d.max()))
                self.assertLessEqual(float(d.max()), SEAM_TOL, "%s|%s seam off by %.4f m" % (cid, other, d.max()))
        print("\n  seams: worst %.6f m" % worst)


class TestBeds(unittest.TestCase):
    def test_under_surface_by_bed_depth(self):
        for cid in REG.net.by_id:
            s, x, z, bd = centre_line(cid)
            surf = REG.net.surface_at(x, z)
            self.assertTrue(np.isfinite(surf).all(), cid)
            need = np.where(np.isfinite(pound_depth(x, z)), pound_depth(x, z), bd)
            H = br.height_field(REG, x, z)["H"]
            short = H - (surf - need)
            self.assertLessEqual(float(short.max()), 1e-6, "%s: bed %.3f m short of its depth at s=%.0f" % (
                cid, short.max(), s[int(np.argmax(short))]))
            Hb = baked_at(x, z)
            shortb = Hb - (surf - need)
            self.assertLessEqual(float(shortb.max()), 0.05, "%s (baked): bed %.3f m short at s=%.0f" % (
                cid, shortb.max(), s[int(np.argmax(shortb))]))
            print("\n  %s: depth under the surface on the centre line, least margin %.3f m (function), %.3f m (baked)"
                  % (cid, -short.max(), -shortb.max()))

    def test_no_dry_bed(self):
        for cid in sorted(REG.cells):
            X, Z = br.square_grid(REG, cid, margin=0)
            surf = REG.net.surface_at(X, Z)
            H = height(cid)
            wet = np.isfinite(surf)
            for p in REG.pounds:                  # a paddy's bund stands over its water, inside its edge
                if p.get("kind") == "paddy" and REG.net._live(p.get("milestone", "M1")):
                    ins = br.polygon_inside(p["polygon"], X, Z)
                    if ins.any():
                        bund = np.zeros_like(ins)
                        bund[ins] = br.polygon_edge_distance(p["polygon"], X[ins], Z[ins]) < REG.squares["paddy"]["bund_m"]
                        wet &= ~bund
            if wet.any():
                over = H[wet] - surf[wet]
                self.assertLessEqual(float(over.max()), 1e-3, "%s: ground %.3f m over the water" % (cid, over.max()))


class TestFlat(unittest.TestCase):
    def test_pounds_and_paddies(self):
        pp = REG.squares["paddy"]
        for p in REG.pounds:
            inset = pp["bund_m"] + 0.5 if p.get("kind") == "paddy" else 0.5
            for cid, c in REG.cells.items():
                X, Z = br.square_grid(REG, cid, margin=0)
                ins = br.polygon_inside(p["polygon"], X, Z)
                if not ins.any():
                    continue
                de = br.polygon_edge_distance(p["polygon"], X[ins], Z[ins])
                floor = height(cid)[ins][de >= inset]
                self.assertGreater(floor.size, 50, p["id"])
                spread = float(floor.max() - floor.min())
                self.assertLessEqual(spread, FLAT_TOL, "%s floor spread %.3f m" % (p["id"], spread))
                self.assertAlmostEqual(float(floor.mean()), float(p["bed"]), delta=FLAT_TOL, msg=p["id"])


class TestBounds(unittest.TestCase):
    def test_recipe_bounds(self):
        for cid in sorted(REG.cells):
            X, Z = br.square_grid(REG, cid, margin=0)
            W = br.cell_weights(REG, X.ravel(), Z.ravel())
            lo = np.full(X.size, np.inf)
            hi = np.full(X.size, -np.inf)
            for oc, w in W.items():
                b = REG.squares["types"][REG.cells[oc]["type"]]["bounds_m"]
                m = w > 0.0
                lo[m] = np.minimum(lo[m], b[0])
                hi[m] = np.maximum(hi[m], b[1])
            H = height(cid).ravel()
            self.assertTrue(np.isfinite(H).all(), cid)
            bad = (H < lo) | (H > hi)
            self.assertFalse(bad.any(), "%s: %d samples outside their recipes' bounds (%.1f..%.1f m)" % (
                cid, int(bad.sum()), H.min(), H.max()))


class TestDownstream(unittest.TestCase):
    def test_main_bed_never_rises(self):
        s, x, z, _ = centre_line("main", 0.5)
        H = br.height_field(REG, x, z)["H"]
        rise = np.diff(H)
        self.assertLessEqual(float(rise.max()), 1e-6, "main bed rises %.4f m at s=%.1f" % (
            rise.max(), s[int(np.argmax(rise))]))
        step = REG.net.by_id["main"].steps[0]
        drops = -rise
        k = int(np.argmax(drops))
        self.assertTrue(step["s_upper"] - 10.0 <= s[k] <= step["s_lower"] + 10.0,
                        "the sharpest drop (%.2f m at s=%.0f) is not at the lock step" % (drops[k], s[k]))
        Hb = baked_at(x, z)
        self.assertLessEqual(float(np.diff(Hb).max()), 0.05, "main bed rises on the baked grid")
        print("\n  main: bed falls %.2f m over %.0f m; sharpest drop %.2f m at s=%.0f (the lock); worst rise %.2e m"
              % (H[0] - H[-1], s[-1], drops[k], s[k], max(float(rise.max()), 0.0)))


if __name__ == "__main__":
    unittest.main()
