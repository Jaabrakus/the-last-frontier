"""Structural tests of data/traversal/graph_traversal.json (tools/traversal/extract_graph_traversal.py).

    python3 -m unittest discover tools/traversal/tests

Read-only over Player_Animation_Project.
"""
import csv
import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.normpath(os.path.join(HERE, ".."))
FR = os.path.normpath(os.path.join(TOOL, "..", ".."))
PAP = os.environ.get("ANIM_GRAPH_PAP", "/Users/kiwimango/Downloads/Player_Animation_Project")
OUT = os.path.join(FR, "data", "traversal", "graph_traversal.json")
sys.path.insert(0, TOOL)


def load():
    with open(OUT, encoding="utf-8") as fh:
        return json.load(fh)


class GraphTraversalTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = load()
        with open(os.path.join(PAP, "player_blending", "player_blending.json")) as fh:
            d = json.load(fh)
        cls.src = {}
        for s in d["states"]:
            cls.src.setdefault(s["name"], s)
        cls.actions_b = {}
        with open(os.path.join(PAP, "blender_animation_index.csv")) as fh:
            for row in csv.DictReader(fh):
                if row["character"] == "Actor_B":
                    cls.actions_b[row["action_name"]] = row

    def test_outputs_current(self):
        import extract_graph_traversal as E
        self.assertEqual(E.main(["--check"]), 0, "outputs stale: rerun tools/traversal/extract_graph_traversal.py")

    def test_ids_copied_from_source(self):
        for name, st in self.g["states"].items():
            s = self.src[name]
            self.assertEqual(st["state_offset"], s["offset"], name)
            self.assertEqual(st["tree"], s.get("tree"), name)
            self.assertEqual(len(st["transitions"]), len(s["transitions"]), name)
            for t, r in zip(st["transitions"], s["transitions"]):
                self.assertEqual((t["record"], t["request"], t["target"]), (r["offset"], r["request"], r["target"]))
                self.assertAlmostEqual(t["fade_s"], r["scalar_0x1c"], places=5)
            ids = [x["hex"] for x in s["raw"] if x["interpretation"] == name]
            self.assertEqual(st["state_name_id"], ids[0] if ids else None, name)

    def test_record_layout_matches_locobrain(self):
        # LocoBrain._eval_records / _conditions_ok read these keys (same decoder as actor_b_graph.json)
        for name, st in self.g["states"].items():
            for t in st["transitions"]:
                for k in ("request", "target", "record", "conditions", "condition_text", "use", "fade_s"):
                    self.assertIn(k, t, (name, t.get("record")))
                self.assertIn("fade_s", t["use"])
                for c in t["conditions"]:
                    for k in ("mode", "min", "max", "variable"):
                        self.assertIn(k, c)
                    self.assertFalse(c["variable"].startswith("secondary") and "ledge_free_hang" in c["variable"])

    def test_entered_by_matches_incoming(self):
        for name, st in self.g["states"].items():
            self.assertEqual(st["entered_by"].startswith("code"), not st["incoming"], name)
        entered = {n for n, st in self.g["states"].items() if st["entered_by"].startswith("code")}
        self.assertEqual(sum(len(f["coverage"]["code_entered"]) for f in self.g["families"].values()), len(entered))

    def test_every_state_in_one_family(self):
        seen = {}
        for f, fd in self.g["families"].items():
            for n in fd["states"]:
                self.assertNotIn(n, seen, "%s in %s and %s" % (n, f, seen.get(n)))
                seen[n] = f
                self.assertEqual(self.g["states"][n]["family"], f)
        self.assertEqual(set(seen), set(self.g["states"]))

    def test_resolved_clips_exist_for_actor_b(self):
        for name, st in self.g["states"].items():
            for l in st["leaves"]:
                for r in l["resolutions"] + l.get("overlay_variants", []):
                    if r["status"] == "resolved":
                        self.assertIn(r["clip"], self.actions_b, (name, r["clip"]))
                        self.assertIn(r["clip"], self.g["clips"])
                    for lay in r.get("layers", []):
                        if lay["clip"]:
                            self.assertIn(lay["clip"], self.actions_b, (name, lay["clip"]))
        for act, c in self.g["clips"].items():
            self.assertTrue(c["native_asset_id"], act)
            self.assertEqual(c["godot"], "actor_b/" + act)

    def _res(self, state, sel, leaf_idx=0, variant_set=None):
        l = self.g["states"][state]["leaves"][leaf_idx]
        pool = l.get("overlay_variants", []) if variant_set else l["resolutions"]
        for r in pool:
            if sel in r["selections"] and (variant_set is None or r["set"] == variant_set):
                return r
        return None

    def test_sprint_vault(self):
        r = self._res("run^test-vault-begin", "musket/sprint")
        self.assertEqual(r["clip"], "actor_b-p-sprint-vault-1")
        self.assertIn("actor_b-p-sprint-vault-1-rifle--part", [x["clip"] for x in r["layers"]])
        self.assertEqual(self._res("test-vault-mid", "bow/sprint")["clip"], "actor_b-p-sprint-vault-2")
        self.assertEqual(self._res("run^test-vault-begin", "pistol/run")["clip"], "actor_b-p-run^vault-over-1m")

    def test_ladder_is_the_ledge_network_under_ledge_ladder(self):
        lad = "anim-overlay-player-ledge-ladder"
        self.assertIsNone(self._res("ledge-grab", "musket/run")["clip"])
        self.assertEqual(self._res("ledge-grab", "musket/run", variant_set=lad)["clip"], "actor_b-p-ladder-idle")
        self.assertEqual(self._res("climb-up-rh", "musket/run", variant_set=lad)["clip"], "actor_b-p-ladder-climb-up")
        self.assertEqual(self._res("climb-up-rh^lh", "musket/run", variant_set=lad)["clip"],
                         "actor_b-p-ladder-climb-up-fast--a")
        self.assertEqual(self._res("ladder-auto-climb", "musket/run")["clip"], "actor_b-p-ladder-mount-bottom-start")

    def test_mirror_flags(self):
        st = self.g["states"]
        self.assertIs(st["ledge-shimmy-left"]["mirrored"], True)
        self.assertIs(st["ledge-shimmy-right"]["mirrored"], False)
        self.assertIs(st["wall-shimmy-idle-left"]["mirrored"], True)
        self.assertTrue(str(st["idle^vault"]["mirrored"]).startswith("runtime"))
        self.assertGreaterEqual(self.g["meta"]["evidence"]["mirror_pair_count"], 70)

    def test_no_height_or_distance_field(self):
        named = {k for k, v in self.g["runtime_fields"].items() if v["name"]}
        self.assertEqual(named, set(self.g["runtime_fields"]), "unnamed runtime field read by a traversal lambda")
        for fid, lam in self.g["lambdas"].items():
            if "condition" in lam["used_as"]:
                for rd in lam["reads"]:
                    self.assertTrue(rd.startswith("f32[C0+") or rd.startswith("i32[C0+"), (fid, rd))

    def test_free_hang_second_condition(self):
        ev = self.g["meta"]["evidence"]["ledge_chain_second_condition"]
        self.assertEqual(ev["ge_0_5"].get("fast", 0), 0)
        self.assertGreater(ev["le_0_5"].get("fast", 0), 0)
        t = self.g["states"]["climb-up-rh^idle"]["transitions"][1]
        self.assertEqual(t["conditions"][1]["variable_key"], "ledge_free_hang")

    def test_chains_end_outside_or_wait(self):
        for n, ch in self.g["chains"].items():
            for steps in ch["paths"].values():
                self.assertEqual(steps[0]["state"], n)
                self.assertIn("end", steps[-1], n)

    def test_provenance(self):
        m = self.g["meta"]
        self.assertIn("owner-stated", m["authorization"])
        self.assertEqual(len(m["inputs_sha256"]), 7)


if __name__ == "__main__":
    unittest.main()
