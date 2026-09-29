"""Vendored graph-analysis tools: provenance and behaviour (WP1).

Run: python3 -m unittest discover tests/source_checks   (from the Frontier root)
Needs the external animation source tree (env ANIMATION_SOURCE_ROOT, explicitly configured); tests that need it
skip with a notice when it is absent.
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.normpath(os.path.join(HERE, "..", "..", "tools", "anim_graph"))
VENDOR = os.path.join(TOOL, "vendor")
SOURCE_ROOT = os.environ.get("ANIMATION_SOURCE_ROOT", "")
GA = os.path.join(SOURCE_ROOT, "graph_analysis", "graph")
HAVE_SOURCE_ROOT = bool(SOURCE_ROOT) and os.path.exists(os.path.join(SOURCE_ROOT, "player_blending", "player_blending.json"))


def read_bytes(path):
    with open(path, "rb") as fh:
        return fh.read()


def load_json(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def provenance():
    txt = read_bytes(os.path.join(VENDOR, "PROVENANCE.md")).decode("utf-8")
    m = re.search(r"```json\n(.*?)\n```", txt, re.S)
    return json.loads(m.group(1))


def sha(b):
    return hashlib.sha256(b).hexdigest()


_DB = None


def overlay_db():
    global _DB
    if _DB is None:
        os.environ["ANIMATION_SOURCE_ROOT"] = SOURCE_ROOT
        if VENDOR not in sys.path:
            sys.path.insert(0, VENDOR)
        import resolve_overlays
        _DB = resolve_overlays.OverlayDB(os.path.join(SOURCE_ROOT, "player_blending", "player_blending.json"),
                                         os.path.join(SOURCE_ROOT, "blender_animation_index.csv"))
    return _DB


class TestProvenance(unittest.TestCase):
    def test_vendored_and_upstream_hashes(self):
        rec = provenance()
        files = sorted(r["file"] for r in rec)
        self.assertEqual(files, sorted(["resolve_overlays.py", "symvm.py", "common.py", "build_subgraph.py", "lib.py",
                                        "decode_lambda.py", "resolve.py", "durations.py"]))
        for r in rec:
            data = read_bytes(os.path.join(VENDOR, r["file"]))
            self.assertEqual(sha(data), r["vendored_sha256"], r["file"] + ": vendored copy changed")
            if HAVE_SOURCE_ROOT:
                gp = os.path.join(GA, r["file"])
                if os.path.exists(gp):
                    self.assertEqual(sha(read_bytes(gp)), r["source_sha256"],
                                     r["file"] + ": upstream source changed since vendoring (re-vendor and update PROVENANCE.md)")

    def test_no_other_absolute_paths_in_code(self):
        # only string data (a docstring and one metadata string) may still mention the original paths
        allowed = {("resolve_overlays.py", 4), ("build_subgraph.py", 245)}
        for f in os.listdir(VENDOR):
            if not f.endswith(".py") or f == "_vendor_paths.py":
                continue
            for i, line in enumerate(read_bytes(os.path.join(VENDOR, f)).decode("utf-8").split("\n"), 1):
                if "/Users/" in line or "/private/tmp" in line:
                    self.assertIn((f, i), allowed, f"{f}:{i} hard-codes a path")


@unittest.skipUnless(HAVE_SOURCE_ROOT, "external animation source not found; set ANIMATION_SOURCE_ROOT")
class TestVendoredBehaviour(unittest.TestCase):
    def test_build_subgraph_regenerates_state_subgraph(self):
        with tempfile.TemporaryDirectory() as td:
            out = os.path.join(td, "state_subgraph.json")
            env = dict(os.environ, ANIMATION_SOURCE_ROOT=SOURCE_ROOT, ANIM_GRAPH_SUBGRAPH_OUT=out, PYTHONDONTWRITEBYTECODE="1")
            p = subprocess.run([sys.executable, "-B", "build_subgraph.py"], cwd=VENDOR, env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=300)
            self.assertEqual(p.returncode, 0, p.stderr)
            a = load_json(out)
            b = load_json(os.path.join(GA, "state_subgraph.json"))
            self.assertEqual(a, b)
            self.assertEqual(len(a["states"]), 48)
            self.assertEqual(len(a["transitions"]), 224)

    def test_resolver_goldens(self):
        db = overlay_db()
        sel = db.make_selection(move="run")
        self.assertEqual(db.resolve("base-walk-fwd", sel).final_name, "actor_b-p-run-fw")
        sel = db.make_selection(move="walk-crouched", extra={"crouch": "crouch"})
        self.assertEqual(db.resolve("base-walk-fwd", sel).final_name, "actor_b-p-crouch-walk-fw")
        sel = db.make_selection(move="walk-crouched", weapon="bow", draw_holster="bow", extra={"crouch": "crouch"})
        r = db.resolve("relaxed-pistol-aim-idle", sel)
        self.assertEqual(r.final_name, "actor_b-p-bow-aim-crouch-idle")
        self.assertEqual([s.layer for s in r.steps], ["crouch", "weapon-base", "actor_b"])

    def _fix_vs_single(self, sel):
        db = overlay_db()
        ids = set()
        for sn in db.sets:
            ids.update(db.subs[sn])
            ids.update(db.layers[sn])
        return sum(1 for i in sorted(ids)
                   if db.resolve_id(i, sel, "asc_fix").final_id != db.resolve_id(i, sel, "asc1").final_id)

    def test_fixpoint_vs_single_pass(self):
        db = overlay_db()
        # verified counts (graph_understanding.json, overlay verdict): 23 keys for pistol-actor_b, 5 for crouched bow
        sel = db.make_selection(move="run", weapon="pistol", sub_type="pistol-actor_b", draw_holster="pistol")
        self.assertEqual(self._fix_vs_single(sel), 23)
        sel = db.make_selection(move="walk-crouched", weapon="bow", draw_holster="bow", extra={"crouch": "crouch"})
        self.assertEqual(self._fix_vs_single(sel), 5)

    def test_revolver_grip_needs_second_pass(self):
        db = overlay_db()
        sel = db.make_selection(move="run", weapon="pistol", sub_type="revolver", draw_holster="pistol")
        fix = db.resolve("1p-idle-fingers", sel, "asc_fix", with_layers=False)
        one = db.resolve("1p-idle-fingers", sel, "asc1", with_layers=False)
        self.assertEqual(fix.final_name, "actor_b-r-hand-revolver")
        self.assertEqual(one.final_name, "actor_b-r-hand-gun")


if __name__ == "__main__":
    unittest.main()
