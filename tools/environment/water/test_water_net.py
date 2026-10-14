#!/usr/bin/env python3
"""R1's water network: water.json (build_water_json.py) through water_net.py, the numpy twin of WaterNetwork.

    python3 -m unittest discover -s tools/environment/water -p 'test_water_net.py'     # from the Frontier root
    python3 tools/environment/water/test_water_net.py --write-fixture                    # rewrite the parity fixture

  source     water.json is what the builder makes of layout.json today (skipped while layout.json is not committed;
             TV_LAYOUT=<path> names another layout to check against)
  junction   the torrent's level meets the main channel's at its mouth: no step across the main channel's bank, none
             along the torrent's line into it
  reach      in S1 the Silent Reach's flow is 0 from z_from to z_to, eased back to 1 over ease_m past each end; S0 as ever
  pounds     each pound's water and bed flat over its polygon (from M2 for the M2 ones; none before)
  outside    NO_WATER past a channel's half width, past its ends and far from it
  current    along the centre line's tangent downstream, at the channel's speed; none on a pound
  falls      the main channel's surface never rises downstream; the torrent drops at its falls; the lock step from M2
  bed        the bed under the surface by its bed depth on the centre line, at the surface at the edge
  curve      the downstream pounds' level by days since the river stopped: flat before, falling, then levelling off
  block      as_world_river_block("main") read as WorldRiver would (x and level linear in z) gives the network's
             centre-line surface within 1 mm; the torrent has none
  fixture    tests/world/fixtures/water_parity.json is what this network gives today (the GDScript test's parity check)
"""
import json
import math
import os
import sys
import unittest

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_water_json  # noqa: E402
from water_net import NO_WATER, WATER, WaterNet, world_river_eval  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
LAYOUT = os.environ.get("TV_LAYOUT", build_water_json.LAYOUT)
FIXTURE = os.path.join(ROOT, "tests", "world", "fixtures", "water_parity.json")


def load_json(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def along(net, cid, s, offset=0.0):
    """(x, z) `offset` m to the right (looking downstream) of channel cid's centre line, `s` m along."""
    ch = net.by_id[cid]
    s = float(s)
    i = int(min(max(np.searchsorted(ch.s, s, side="right") - 1, 0), len(ch.s) - 2))
    t = (s - ch.s[i]) / (ch.s[i + 1] - ch.s[i])
    x = ch.x[i] + t * (ch.x[i + 1] - ch.x[i])
    z = ch.z[i] + t * (ch.z[i + 1] - ch.z[i])
    dx, dz = ch.x[i + 1] - ch.x[i], ch.z[i + 1] - ch.z[i]
    L = math.hypot(dx, dz)
    return x + offset * (-dz / L), z + offset * (dx / L)


def hw_at(net, cid, s):
    ch = net.by_id[cid]
    return float(np.interp(s, ch.s, ch.hw))


class WaterNetTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = load_json(WATER)

    def net(self, state="S0", milestone="M1", day=0.0):
        n = WaterNet(self.data)
        n.set_state(state)
        n.set_milestone(milestone)
        n.set_day(day)
        return n

    # --- source ----------------------------------------------------------------------------------------------------

    def test_source(self):
        if not os.path.exists(LAYOUT):
            self.skipTest("no layout.json at %s (T0 commits it)" % LAYOUT)
        lay, sha = build_water_json.load_layout(LAYOUT)
        built = build_water_json.dumps(build_water_json.build(lay, sha))
        with open(WATER, encoding="utf-8") as fh:
            self.assertEqual(fh.read(), built, "water.json is stale: rerun build_water_json.py")
        # the layout's nodes lie on the centre lines at their levels
        net = self.net()
        for c in lay["channels"]:
            ch = net.by_id[c["id"]]
            for k, (x, z, hw, lv, _) in enumerate(c["nodes"]):
                d = np.hypot(ch.x - x, ch.z - z)
                i = int(np.argmin(d))
                self.assertLess(d[i], 1e-3, "%s node %d off its centre line" % (c["id"], k))
                self.assertAlmostEqual(ch.hw[i], hw, places=3)
                if k < len(c["nodes"]) - 1 or not c.get("joins"):
                    self.assertAlmostEqual(ch.level[i], lv, places=3)

    def test_builder_deterministic(self):
        if not os.path.exists(LAYOUT):
            self.skipTest("no layout.json")
        a = build_water_json.dumps(build_water_json.build(*build_water_json.load_layout(LAYOUT)))
        b = build_water_json.dumps(build_water_json.build(*build_water_json.load_layout(LAYOUT)))
        self.assertEqual(a, b)

    def test_main_z_monotonic(self):
        z = self.net().by_id["main"].z
        self.assertTrue(np.all(np.diff(z) > 0.0))

    # --- junction --------------------------------------------------------------------------------------------------

    def test_junction_continuous(self):
        net = self.net()
        j = self.data["junctions"][0]
        main = net.by_id["main"]
        tor = net.by_id["torrent"]
        # along the torrent's line, from 80 m upstream of its end into the main channel: no jump beyond its slope
        s = np.linspace(tor.s[-1] - 80.0, tor.s[-1], 801)
        x, z = np.array([along(net, "torrent", v) for v in s]).T
        lv = net.surface_at(x, z)
        self.assertTrue(np.all(np.isfinite(lv)))
        jump = np.max(np.abs(np.diff(lv)))
        self.assertLess(jump, 0.01, "a step along the torrent into the main channel: %.4f m" % jump)
        # across the main channel's bank inside the torrent's mouth: the two sides' levels within 5 mm
        worst = 0.0
        pairs = 0
        for off in np.linspace(-0.9, 0.9, 19):
            for side in (-1.0, 1.0):
                sm = j["s_into"] + off * hw_at(net, "torrent", tor.s[-1])
                hw = hw_at(net, "main", sm)
                xi, zi = along(net, "main", sm, side * (hw - 0.02))
                xo, zo = along(net, "main", sm, side * (hw + 0.02))
                a, b = net.surface_at(xi, zi), net.surface_at(xo, zo)
                ca, cb = net.channel_at(xi, zi)["channel"], net.channel_at(xo, zo)["channel"]
                if ca == "main" and cb == "torrent":
                    worst = max(worst, abs(float(a) - float(b)))
                    pairs += 1
                    self.assertTrue(np.isfinite(a) and np.isfinite(b))
        self.assertGreater(pairs, 10)
        self.assertLess(worst, 0.005, "the torrent's mouth steps %.4f m at the main channel's bank" % worst)
        # the main channel wins where the two overlap
        self.assertEqual(net.channel_at(j["at"][0], j["at"][1])["channel"], "main")

    # --- reach -----------------------------------------------------------------------------------------------------

    def test_silent_reach(self):
        r = self.data["channels"][0]["reaches"][0]
        s0, s1, ease = r["s_from"], r["s_to"], r["ease_m"]
        still = self.net("S1")
        run = self.net("S0")
        inside = np.linspace(s0, s1, 200)
        x, z = np.array([along(still, "main", v) for v in inside]).T
        self.assertTrue(np.all(still.flow_scale_at(x, z) == 0.0))
        cx, cz = still.current_at(x, z)
        self.assertTrue(np.all(np.hypot(cx, cz) == 0.0))
        self.assertTrue(np.all(run.flow_scale_at(x, z) == 1.0))
        # eased: rising from 0 at each end to 1 at ease_m past it, half way at ease_m / 2, 1 beyond
        for end, sign in ((s0, -1.0), (s1, 1.0)):
            d = np.linspace(0.0, ease + 30.0, 141)
            x, z = np.array([along(still, "main", end + sign * v) for v in d]).T
            f = still.flow_scale_at(x, z)
            self.assertTrue(np.all(np.diff(f) >= -1e-12), "the ease is not monotonic")
            self.assertAlmostEqual(float(f[0]), 0.0, places=9)
            mid = still.flow_scale_at(*along(still, "main", end + sign * ease * 0.5))
            self.assertAlmostEqual(float(mid), 0.5, places=6)
            self.assertTrue(np.all(f[d >= ease] == 1.0))
        # z_from / z_to on the centre line
        self.assertLess(abs(along(still, "main", s0)[1] - r["z_from"]), 1e-3)
        self.assertLess(abs(along(still, "main", s1)[1] - r["z_to"]), 1e-3)
        # by hand
        still.set_reach_flow("silent_reach", 0.5)
        self.assertAlmostEqual(float(still.flow_scale_at(*along(still, "main", (s0 + s1) / 2))), 0.5)

    # --- pounds ----------------------------------------------------------------------------------------------------

    def test_pounds_flat(self):
        m2 = self.net(milestone="M2")
        m1 = self.net(milestone="M1")
        for p in self.data["pounds"]:
            poly = np.asarray(p["polygon"])
            x0, z0 = poly.min(axis=0) + 0.5
            x1, z1 = poly.max(axis=0) - 0.5
            xs, zs = np.meshgrid(np.linspace(x0, x1, 15), np.linspace(z0, z1, 15))
            surf = m2.surface_at(xs, zs)
            bed = m2.bed_at(xs, zs)
            self.assertTrue(np.all(surf == p["level"]), p["id"])
            self.assertTrue(np.all(bed == p["bed"]), p["id"])
            self.assertTrue(np.all(m2.current_at(xs, zs)[0] == 0.0), p["id"])
            if p["milestone"] == "M2":
                # not built at M1: only a channel's water there, or none
                wet = np.isfinite(m1.surface_at(xs, zs))
                self.assertTrue(np.all(m1.channel_at(xs, zs)["channel"][wet] != ""), p["id"])
                if p["kind"] == "paddy":
                    self.assertFalse(np.any(wet), p["id"])

    def test_pound_curve(self):
        net = self.net(milestone="M2")
        for pid in ("lock_chamber", "barge_basin"):
            p = net.pound_by_id[pid]
            self.assertEqual(p.get("curve"), "downstream_drop")
            days = np.arange(0, 31)
            lv = net.pound_level_at(pid, days)
            self.assertEqual(float(lv[0]), p["level"])
            self.assertEqual(net.pound_level_at(pid, -5.0), p["level"])
            self.assertTrue(np.all(np.diff(lv) < 0.0))
            self.assertTrue(1.0 < p["level"] - lv[-1] < 2.0)
            net.set_day(30.0)
            cx, cz = np.asarray(p["polygon"]).mean(axis=0)
            self.assertAlmostEqual(float(net.surface_at(cx, cz)), float(lv[-1]))
            net.set_day(0.0)
        for p in self.data["pounds"]:
            if p["kind"] == "paddy":
                self.assertNotIn("curve", p)

    # --- outside ---------------------------------------------------------------------------------------------------

    def test_outside(self):
        net = self.net()
        for cid in ("main", "torrent"):
            ch = net.by_id[cid]
            for s in np.linspace(20.0, ch.s[-1] - 60.0, 40):
                hw = hw_at(net, cid, s)
                for side in (-1.0, 1.0):
                    x, z = along(net, cid, s, side * (hw + 0.05))
                    if net.channel_at(x, z)["channel"] == "":
                        self.assertEqual(net.surface_at(x, z), NO_WATER)
                        self.assertEqual(net.depth_at(x, z, lambda a, b: np.zeros_like(a)), 0.0)
                    x, z = along(net, cid, s, side * (hw - 0.05))
                    self.assertTrue(np.isfinite(net.surface_at(x, z)), "%s s %.0f" % (cid, s))
        # past the main channel's ends, and far away
        self.assertEqual(net.surface_at(900.0, -1670.0), NO_WATER)
        self.assertEqual(net.surface_at(900.0, 1670.0), NO_WATER)
        self.assertEqual(net.surface_at(-1255.0, -520.0), NO_WATER)
        self.assertEqual(net.surface_at(0.0, 0.0), NO_WATER)
        self.assertEqual(net.surface_at(-800.0, 1200.0), NO_WATER)
        self.assertFalse(bool(net.is_under_water(0.0, -1000.0, 0.0)))
        x, z = along(net, "main", 1000.0)
        self.assertTrue(bool(net.is_under_water(x, float(net.surface_at(x, z)) - 0.1, z)))
        self.assertFalse(bool(net.is_under_water(x, float(net.surface_at(x, z)) + 0.1, z)))
        # the torrent is not built before M1
        m0 = self.net(milestone="M0")
        self.assertEqual(m0.surface_at(*along(m0, "torrent", 500.0)), NO_WATER)

    # --- current ---------------------------------------------------------------------------------------------------

    def test_current_tangent(self):
        net = self.net()
        for cid in ("main", "torrent"):
            ch = net.by_id[cid]
            for s in np.linspace(10.0, ch.s[-1] - 40.0, 60):
                x, z = along(net, cid, s)
                a, b = np.array(along(net, cid, s - 1.0)), np.array(along(net, cid, s + 1.0))
                tan = (b - a) / np.linalg.norm(b - a)
                cx, cz = net.current_at(x, z)
                v = math.hypot(float(cx), float(cz))
                if net.channel_at(x, z)["channel"] != cid:
                    continue
                self.assertGreater(v, 0.1, "%s s %.0f" % (cid, s))
                self.assertGreater((float(cx) * tan[0] + float(cz) * tan[1]) / v, 0.999, "%s s %.0f" % (cid, s))
                # the speed on the centre line is the channel's at s
                self.assertAlmostEqual(v, float(np.interp(s, ch.s, ch.speed)), places=6)
        # the main channel runs south
        self.assertGreater(float(net.current_at(*along(net, "main", 1500.0))[1]), 0.0)
        # the torrent runs east
        self.assertGreater(float(net.current_at(*along(net, "torrent", 500.0))[0]), 0.0)

    # --- levels ----------------------------------------------------------------------------------------------------

    def test_levels(self):
        net = self.net()
        ch = net.by_id["main"]
        s = np.linspace(0.0, ch.s[-1], 3000)
        lv = np.array([float(net.surface_at(*along(net, "main", v))) for v in s])
        self.assertTrue(np.all(np.isfinite(lv)))
        self.assertTrue(np.all(np.diff(lv) <= 1e-9), "the main channel rises downstream")
        tor = net.by_id["torrent"]
        for f in self.data["channels"][1]["falls"]:
            a = float(net.surface_at(*along(net, "torrent", f["s_from"] - 0.5)))
            b = float(net.surface_at(*along(net, "torrent", f["s_to"] + 0.5)))
            self.assertGreater(a - b, f["drop"] * 0.95)
        self.assertTrue(np.all(np.diff(tor.level) <= 1e-9))
        # the lock step: from M2 held at its upper level down to the lower gate, then the lower level
        st = self.data["channels"][0]["steps"][0]
        m2 = self.net(milestone="M2")
        # off the chamber (beside it, in the channel) so the pound does not answer
        hw = hw_at(m2, "main", (st["s_upper"] + st["s_lower"]) / 2)
        for off in (-0.8, 0.8):
            mid = along(m2, "main", (st["s_upper"] + st["s_lower"]) / 2, off * hw)
            if m2.channel_at(*mid)["channel"] == "main" and not np.isclose(m2.surface_at(*mid), 104.0):
                self.assertAlmostEqual(float(m2.surface_at(*mid)), st["level_upper"])
        below = along(m2, "main", st["s_lower"] + 0.5, 0.8 * hw)
        self.assertLess(float(m2.surface_at(*below)), st["level_lower"] + 0.1)
        self.assertEqual(m2.level_at_s("main", st["s_lower"] - 0.5), st["level_upper"])
        m1 = self.net()
        self.assertLess(float(m1.level_at_s("main", st["s_lower"] - 0.5)), st["level_upper"] - 3.0)

    def test_bed(self):
        net = self.net(milestone="M2")
        for cid in ("main", "torrent"):
            ch = net.by_id[cid]
            for s in np.linspace(5.0, ch.s[-1] - 80.0, 50):
                x, z = along(net, cid, s)
                if net.channel_at(x, z)["channel"] != cid or net._resolve(x, z)[3] >= 0:
                    continue
                surf = float(net.surface_at(x, z))
                bed = float(net.bed_at(x, z))
                self.assertAlmostEqual(surf - bed, float(np.interp(s, ch.s, ch.bed_depth)), places=6)
                hw = hw_at(net, cid, s)
                xe, ze = along(net, cid, s, hw * 0.999)
                self.assertLess(float(net.surface_at(xe, ze)) - float(net.bed_at(xe, ze)), 0.05)
        xs, zs = np.meshgrid(np.arange(-1248.0, 1248.0, 4.0), np.arange(-1664.0, 1664.0, 4.0))
        surf, bed = net.surface_at(xs, zs), net.bed_at(xs, zs)
        wet = np.isfinite(surf)
        self.assertTrue(np.all(bed[wet] <= surf[wet] + 1e-9))
        self.assertTrue(np.all(np.isnan(bed[~wet])))

    # --- WorldRiver block ------------------------------------------------------------------------------------------

    def test_world_river_block(self):
        net = self.net()
        blk = net.as_world_river_block("main")
        self.assertEqual(net.as_world_river_block("torrent"), {})
        self.assertEqual(blk["reaches"][0]["id"], "silent_reach")
        z = np.linspace(-1663.5, 1663.5, 2001)
        x, lv = world_river_eval(blk, z)
        got = net.surface_at(x, z)
        err = np.max(np.abs(got - lv))
        self.assertLess(err, 1e-3, "the block's centre line is %.5f m off the network's" % err)
        off = np.abs(net.channel_at(x, z)["offset"])
        self.assertLess(float(np.max(off)), 1e-3)
        # across the width the network's cross-sections are square to the channel and WorldRiver's lie along x: a few
        # cm apart at 0.9 of the half width (6 cm at most), 20 cm on the lock's rapid (4 m over 80 m, z 380-460)
        hw = np.interp(z, np.asarray(blk["nodes"])[:, 0], np.asarray(blk["nodes"])[:, 3])
        rapid = (z > 370.0) & (z < 470.0)
        for k in (-0.9, 0.9):
            g = net.surface_at(x + k * hw, z)
            m = np.isfinite(g)
            self.assertLess(float(np.max(np.abs(g[m & ~rapid] - lv[m & ~rapid]))), 0.06)
            self.assertLess(float(np.max(np.abs(g[m] - lv[m]))), 0.25)

    # --- parity fixture --------------------------------------------------------------------------------------------

    def test_fixture_current(self):
        self.assertEqual(load_json(FIXTURE), parity_points(self.data), "rerun with --write-fixture")


def _r(v, n=6):
    return None if (v is None or not math.isfinite(v)) else round(float(v), n)


def parity_points(data):
    """About 200 points with what the network gives there, for tests/world/test_water_network.gd."""
    base = WaterNet(data)
    pts = []
    for s in np.linspace(3.0, base.by_id["main"].s[-1] - 3.0, 40):
        pts.append(("S0", "M1", 0.0) + along(base, "main", s))
    for s in np.linspace(60.0, base.by_id["main"].s[-1] - 60.0, 12):
        hw = hw_at(base, "main", s)
        for k in (-1.05, -0.95, -0.5, 0.5, 0.95, 1.05):
            pts.append(("S0", "M1", 0.0) + along(base, "main", s, k * hw))
    r = data["channels"][0]["reaches"][0]
    for s in np.linspace(r["s_from"] - 60.0, r["s_to"] + 60.0, 16):
        pts.append(("S1", "M1", 0.0) + along(base, "main", s, 2.0))
    for s in np.linspace(3.0, base.by_id["torrent"].s[-1] - 3.0, 24):
        pts.append(("S0", "M1", 0.0) + along(base, "torrent", s))
    for f in data["channels"][1]["falls"]:
        for d in (-2.0, 0.5, 3.0, 5.5, 8.0):
            pts.append(("S0", "M1", 0.0) + along(base, "torrent", f["s_from"] + d, 1.0))
    j = data["junctions"][0]
    tor_end = base.by_id["torrent"].s[-1]
    for d in (40.0, 30.0, 24.0, 18.0, 12.0, 8.0, 4.0, 2.0):
        for k in (-0.6, 0.0, 0.6):
            sd = tor_end - d
            pts.append(("S0", "M1", 0.0) + along(base, "torrent", sd, k * hw_at(base, "torrent", sd)))
    pts.append(("S0", "M1", 0.0) + tuple(j["at"]))
    for p in data["pounds"]:
        cx, cz = np.asarray(p["polygon"]).mean(axis=0)
        for day in ((0.0, 10.0, 30.0) if p.get("curve") else (0.0,)):
            pts.append(("S0", "M2", day, float(cx), float(cz)))
    st = data["channels"][0]["steps"][0]
    for s in np.linspace(st["s_upper"] - 20.0, st["s_lower"] + 20.0, 8):
        pts.append(("S0", "M2", 0.0) + along(base, "main", s, 0.8 * hw_at(base, "main", s)))
    for xz in ((0.0, 0.0), (-800.0, 1200.0), (900.0, -1670.0), (900.0, 1670.0), (-1255.0, -520.0)):
        pts.append(("S0", "M1", 0.0) + xz)
    out = []
    for state, ms, day, x, z in pts:
        x, z = _r(x), _r(z)          # evaluated where the fixture says, to the digit
        net = WaterNet(data)
        net.set_state(state)
        net.set_milestone(ms)
        net.set_day(day)
        ca = net.channel_at(x, z)
        cx, cz = net.current_at(x, z)
        out.append({
            "x": x, "z": z, "state": state, "milestone": ms, "day": day,
            "surface": _r(float(net.surface_at(x, z))),
            "channel": str(ca["channel"]), "s": _r(float(ca["s"])) if ca["channel"] else None,
            "offset": _r(float(ca["offset"])) if ca["channel"] else None,
            "half_width": _r(float(ca["half_width"])) if ca["channel"] else None,
            "current": [_r(float(cx)), _r(float(cz))], "flow_scale": _r(float(net.flow_scale_at(x, z))),
        })
    return {"_doc": "WaterNetwork parity points, written by tools/environment/water/test_water_net.py --write-fixture "
                    "from data/world/maps/r1/water.json (surface null: NO_WATER; channel \"\": none). "
                    "tests/world/test_water_network.gd checks the GDScript class against them within 1e-3.",
            "points": out}


def write_fixture():
    d = parity_points(load_json(WATER))
    txt = json.dumps(d, indent=1)
    import re
    txt = re.sub(r"\{\s+(\"x\".*?)\s+\}", lambda m: "{" + re.sub(r"\s*\n\s*", " ", m.group(1)) + "}", txt, flags=re.S)
    os.makedirs(os.path.dirname(FIXTURE), exist_ok=True)
    with open(FIXTURE, "w", encoding="utf-8") as fh:
        fh.write(txt + "\n")
    print("wrote %s (%d points)" % (os.path.relpath(FIXTURE, ROOT), len(d["points"])))


if __name__ == "__main__":
    if "--write-fixture" in sys.argv:
        write_fixture()
    else:
        unittest.main()
