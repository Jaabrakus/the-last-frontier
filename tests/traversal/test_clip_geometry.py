#!/usr/bin/env python3
"""Contract and sanity tests for the traversal clip survey outputs.

    python3 -m unittest discover -s tests/traversal -p 'test_*.py'          # from the Frontier root
    TRAVERSAL_RUN_GODOT=1 python3 -m unittest discover -s tests/traversal    # also re-measure in Godot (check mode, ~15 s)

Covers data/traversal/traversal_catalog.json (tools/traversal/build_traversal_catalog.py),
data/traversal/clip_geometry.json (tools/traversal/measure_traversal_clips.gd) and the survey
source/graph_analysis/traversal/clip_survey.md (tools/traversal/write_clip_survey.py).
The sanity bounds are deliberately loose: they pin the measured behaviour of the motion (a ladder
climb rises, a beam walk keeps the feet on one line), not exact reconstructed values.
"""
import json
import os
import subprocess
import sys
import unittest

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SOURCE_ROOT = os.environ.get("ANIMATION_SOURCE_ROOT", "")
CATALOG = os.path.join(ROOT, "data", "traversal", "traversal_catalog.json")
GEOMETRY = os.path.join(ROOT, "data", "traversal", "clip_geometry.json")
GODOT = os.environ.get("GODOT_BIN", "/Applications/Godot_mono.app/Contents/MacOS/Godot")
FAMILIES = ["vault", "climb_up", "ledge_hang", "wall_shimmy", "edge_warn", "ladder", "drop", "gap_jump", "beam",
            "crouch_under", "squeeze"]


def load(path):
    with open(path) as fh:
        return json.load(fh)


class ClipGeometryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cat = load(CATALOG)
        cls.geo = load(GEOMETRY)
        cls.C = cls.geo["clips"]

    # --- contract -------------------------------------------------------------------------------
    def test_meta_provenance(self):
        self.assertEqual(self.geo["meta"]["catalog"]["path"], "data/traversal/traversal_catalog.json")

    def test_every_catalogue_clip_measured(self):
        self.assertEqual(set(self.cat["clips"]), set(self.C))
        for n, c in self.C.items():
            self.assertEqual(c["family"], self.cat["clips"][n]["family"], n)
        for f in FAMILIES:
            self.assertGreater(self.cat["families"][f]["count"], 0, f)

    def test_asset_ids_preserved(self):
        """native_asset_id from the Godot library equals the index asset_id of that clip."""
        checked = 0
        for n, c in self.C.items():
            ids = {r["asset_id"] for r in self.cat["clips"][n]["index"]}
            if not ids:
                continue
            self.assertIn(c["native_asset_id"], ids, n)
            checked += 1
        self.assertGreater(checked, 300)

    def test_full_body_records(self):
        keys = ["root_motion", "odometry", "travel", "entry", "exit", "contacts", "implied", "series"]
        n_full = 0
        for n, c in self.C.items():
            if c["keyed"]["slot"] != "full_body":
                continue
            n_full += 1
            for k in keys:
                self.assertIn(k, c, "%s lacks %s" % (n, k))
            s = c["series"]
            self.assertEqual(len(s["t"]), len(s["align_fwd"]), n)
            self.assertEqual(len(s["t"]), len(s["pelvis_up"]), n)
            self.assertIn(c["odometry"]["confidence"], ("high", "medium", "low"), n)
            for side in ("entry", "exit"):
                self.assertIn(c[side]["gait"], ("idle", "walk", "run", "sprint"), n)
            for h in c["contacts"]["hands"]:
                self.assertLessEqual(h["t0"], h["t1"])
                self.assertIn(h["hand"], ("l", "r"))
        self.assertGreater(n_full, 250)

    def test_no_ground_root_motion(self):
        """No ground-level root bone and no align channel: world travel is reconstructed; only a few clips move the hips
        themselves through skeleton space."""
        insk = []
        for n, c in self.C.items():
            if "root_motion" in c:
                self.assertFalse(c["root_motion"]["ground_root_bone"], n)
                self.assertEqual(c["root_motion"]["align_channel"], "not exported")
                if c["root_motion"]["in_skeleton"]:
                    insk.append(n)
        self.assertLess(len(insk), 15)
        self.assertIn("actor_b-p-vault-end^sprint", insk)

    def test_weapon_layers_key_only_arms(self):
        parts = [n for n, c in self.C.items() if c["variant"]["kind"] == "part"]
        self.assertGreaterEqual(len(parts), 40)
        for n in parts:
            c = self.C[n]
            g = c["keyed"]["groups"]
            self.assertEqual(g.get("legs", 0), 0, n)
            self.assertGreater(g.get("l_arm", 0) + g.get("r_arm", 0), 0, n)
            self.assertIn("part", c, n)
            if c["part"].get("base_clip"):
                self.assertIn("composite_hand_contacts", c["part"], n)

    # --- graph links ------------------------------------------------------------------------------
    def test_ladder_reuses_ledge_climb_states(self):
        g = self.cat["clips"]["actor_b-p-ladder-climb-up"]["graph"]
        states = {x["state"] for x in g}
        self.assertIn("climb-up-rh", states)
        self.assertTrue(all(x["extras"] == ["ledge:ladder"] for x in g if x["state"] == "climb-up-rh"))

    def test_hang_navigation_is_a_gap(self):
        gaps = {g["state"] for g in self.cat["graph_gaps"]}
        for st in ("ledge-shimmy-left", "ledge-shimmy-right", "climb-up-rt-rh", "climb-far-rt-rh", "ledge-grab-look-left"):
            self.assertIn(st, gaps)
        # The hang idle and the straight climbs reach Actor_B only as a ladder.
        for st in ("ledge-grab", "climb-up-rh", "climb-down-lh"):
            self.assertEqual(self.cat["graph_states"][st]["only_with_extras"], ["ledge:ladder"], st)

    def test_sprint_vault_graph_parts(self):
        for i, st in enumerate(["run^test-vault-begin", "test-vault-mid", "test-vault^test-vault-end-run", "test-vault-end^run"]):
            states = {x["state"] for x in self.cat["clips"]["actor_b-p-sprint-vault-%d" % (i + 1)]["graph"]}
            self.assertIn(st, states)

    # --- measured behaviour ------------------------------------------------------------------------
    def chain(self, head):
        for ch in self.geo["chains"]:
            if ch["parts"][0] == head:
                return ch
        self.fail("no chain starting at " + head)

    def test_sprint_vault_chain(self):
        ch = self.chain("actor_b-p-sprint-vault-1")
        self.assertEqual(ch["parts"], ["actor_b-p-sprint-vault-%d" % i for i in range(1, 5)])
        self.assertGreater(ch["pelvis_travel"]["fwd"], 1.5)
        self.assertLess(abs(ch["pelvis_travel"]["up"]), 0.5)
        top = self.C["actor_b-p-sprint-vault-1"]["implied"].get("hand_top_h_median")
        self.assertIsNotNone(top)
        self.assertTrue(0.6 < top < 1.3, top)

    def test_player_1m_vault_heights(self):
        for n in ("actor_b-p-idle^vault-over-1m", "actor_b-p-crouch-run^vault-over-1m", "actor_b-p-sprint^vault-over-1m"):
            top = self.C[n]["implied"].get("hand_top_h_median")
            self.assertIsNotNone(top, n)
            self.assertTrue(0.6 < top < 1.4, (n, top))

    def test_long_jump_moves_forward(self):
        ch = self.chain("actor_b-p-run^jump-long")
        self.assertGreater(ch["pelvis_travel"]["fwd"], 1.5)

    def test_ladder_fast_climbs(self):
        for n in ("actor_b-p-ladder-climb-up-fast--a", "actor_b-p-ladder-climb-up-fast--b"):
            self.assertGreater(self.C[n]["travel"]["up_net"], 0.3, n)
        for n in ("actor_b-p-ladder-climb-down-fast--a", "actor_b-p-ladder-climb-down-fast--b"):
            self.assertLess(self.C[n]["travel"]["up_net"], -0.3, n)
        idle = self.C["actor_b-p-ladder-idle"]["travel"]
        self.assertLess(abs(idle["up_net"]) + abs(idle["fwd"]), 0.05)

    def test_balance_beam_loop(self):
        c = self.C["actor_b-balance-beam-loop"]
        self.assertGreater(c["travel"]["fwd"], 0.8)
        self.assertLess(c["implied"]["foot_side_spread"], 0.15)

    def test_crouch_under_clearance(self):
        c = self.C["actor_b-crouch-under-loop"]
        self.assertLess(c["travel"]["head_top_max"], 1.2)
        self.assertGreater(c["travel"]["fwd"], 0.8)

    def test_wall_shimmy_moves_right(self):
        c = self.C["actor_b-p-ledge-walk-r-loop"]
        self.assertLess(c["travel"]["side"], -0.2)   # +X = left
        self.assertLess(abs(c["travel"]["fwd"]), 0.15)

    def test_hang_climb_uses_hands(self):
        c = self.C["actor_b-p-ledge-hang-climb-up^ledge-knee"]
        self.assertGreater(c["travel"]["align_up"], 0.8)
        self.assertTrue(any(h["supporting"] for h in c["contacts"]["hands"]))
        self.assertEqual(c["exit"]["pose"], "knee_on_ledge")

    # --- regeneration checks --------------------------------------------------------------------
    @unittest.skipUnless(bool(SOURCE_ROOT) and os.path.isdir(SOURCE_ROOT), "external animation source not found")
    def test_catalog_current(self):
        r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "traversal", "build_traversal_catalog.py"), "--check"],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    @unittest.skipUnless(bool(SOURCE_ROOT) and os.path.isdir(SOURCE_ROOT), "external animation source not found")
    def test_survey_current(self):
        r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "traversal", "write_clip_survey.py"), "--check"],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    @unittest.skipUnless(os.environ.get("TRAVERSAL_RUN_GODOT") == "1" and os.path.exists(GODOT),
                         "set TRAVERSAL_RUN_GODOT=1 to re-measure in Godot")
    def test_geometry_current(self):
        r = subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", "tools/traversal/measure_traversal_clips.gd", "--", "check"],
                           capture_output=True, text=True, timeout=300)
        self.assertIn("TRAVERSAL CLIPS OK", r.stdout, r.stdout[-3000:] + r.stderr[-3000:])


if __name__ == "__main__":
    unittest.main()
