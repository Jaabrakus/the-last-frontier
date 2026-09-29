"""Exporter contract tests (WP1): schema, determinism, goldens, provenance, structural assertions.

Run: python3 -m unittest discover tests/source_checks   (from the Frontier root)
"""
import ast
import copy
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
FR = os.path.normpath(os.path.join(TOOL, "..", ".."))
SOURCE_ROOT = os.environ.get("ANIMATION_SOURCE_ROOT", "")
HAVE_SOURCE_ROOT = bool(SOURCE_ROOT) and os.path.exists(os.path.join(SOURCE_ROOT, "player_blending", "player_blending.json"))
SCHEMA = os.path.join(TOOL, "schema", "actor_b_graph.schema.json")
FIXTURE = os.path.join(TOOL, "fixtures", "mini_graph.json")
OUT = os.path.join(FR, "animations", "actor_b_graph.json")
REPORT = os.path.join(FR, "animations", "actor_b_graph_report.md")
EXPORTER = os.path.join(TOOL, "export_actor_b_graph.py")

sys.path.insert(0, TOOL)


# --------------------------------------------------------------------------- minimal JSON-schema validator
class SchemaError(Exception):
    pass


_TYPES = {"object": dict, "array": list, "string": str, "boolean": bool, "null": type(None)}


def _is_type(v, t):
    if t == "number":
        return isinstance(v, (int, float)) and not isinstance(v, bool)
    if t == "integer":
        return isinstance(v, int) and not isinstance(v, bool)
    return isinstance(v, _TYPES[t])


def validate(v, s, root, path="$", errors=None, limit=50):
    if errors is None:
        errors = []
    if len(errors) >= limit:
        return errors
    if "$ref" in s:
        ref = s["$ref"]
        assert ref.startswith("#/definitions/"), ref
        return validate(v, root["definitions"][ref.split("/")[-1]], root, path, errors, limit)
    if "const" in s and v != s["const"]:
        errors.append(f"{path}: {v!r} != const {s['const']!r}")
    if "enum" in s and v not in s["enum"]:
        errors.append(f"{path}: {v!r} not in {s['enum']}")
    if "type" in s:
        ts = s["type"] if isinstance(s["type"], list) else [s["type"]]
        if not any(_is_type(v, t) for t in ts):
            errors.append(f"{path}: type {type(v).__name__} not in {ts}")
            return errors
    if isinstance(v, str) and "pattern" in s and not re.search(s["pattern"], v):
        errors.append(f"{path}: {v!r} !~ /{s['pattern']}/")
    if isinstance(v, (int, float)) and not isinstance(v, bool):
        if "minimum" in s and v < s["minimum"]:
            errors.append(f"{path}: {v} < {s['minimum']}")
        if "maximum" in s and v > s["maximum"]:
            errors.append(f"{path}: {v} > {s['maximum']}")
    if isinstance(v, list):
        if "minItems" in s and len(v) < s["minItems"]:
            errors.append(f"{path}: fewer than {s['minItems']} items")
        if "items" in s:
            for i, x in enumerate(v):
                validate(x, s["items"], root, f"{path}[{i}]", errors, limit)
    if isinstance(v, dict):
        for k in s.get("required", []):
            if k not in v:
                errors.append(f"{path}: missing required '{k}'")
        props = s.get("properties", {})
        pats = s.get("patternProperties", {})
        for k, x in v.items():
            matched = False
            if k in props:
                matched = True
                validate(x, props[k], root, f"{path}.{k}", errors, limit)
            for pat, ps in pats.items():
                if re.search(pat, k):
                    matched = True
                    validate(x, ps, root, f"{path}.{k}", errors, limit)
            if not matched:
                ap = s.get("additionalProperties", True)
                if ap is False:
                    errors.append(f"{path}: unexpected key '{k}'")
                elif isinstance(ap, dict):
                    validate(x, ap, root, f"{path}.{k}", errors, limit)
    return errors


def load_json(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def read_text(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def read_bytes(path):
    with open(path, "rb") as fh:
        return fh.read()


def schema():
    return load_json(SCHEMA)


# --------------------------------------------------------------------------- shared build
_BUILD = {}


def build(bindings=None):
    import export_actor_b_graph as ex
    key = json.dumps(bindings, sort_keys=True) if bindings else None
    if key in _BUILD:
        return _BUILD[key]
    path = None
    if bindings is not None:
        fd, path = tempfile.mkstemp(suffix=".json")
        with os.fdopen(fd, "w") as fh:
            json.dump(bindings, fh)
    try:
        e = ex.Exporter(SOURCE_ROOT, path)
        g = e.build()
        res = (g, None)
    except ex.ExportError as err:
        res = (None, str(err))
    finally:
        if path:
            os.unlink(path)
    _BUILD[key] = res
    return res


def base_bindings():
    return load_json(os.path.join(TOOL, "frontier_bindings.json"))


def layer_map(role):
    return {l["clip"]: l for l in role["layers"] if l["clip"]}


@unittest.skipUnless(HAVE_SOURCE_ROOT, "external animation source not found; set ANIMATION_SOURCE_ROOT")
class TestExport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g, err = build()
        if err:
            raise AssertionError(err)
        cls.D = load_json(os.path.join(SOURCE_ROOT, "player_blending", "player_blending.json"))
        cls.remap = {}
        for s in cls.D["overlay_sets"]:
            for r in s["remaps"]:
                cls.remap[(s["name"], r["offset"])] = r

    # ------------------------------------------------------------------ schema / determinism / provenance
    def test_schema(self):
        errs = validate(self.g, schema(), schema())
        self.assertEqual(errs, [], "\n".join(errs[:20]))

    def test_fixture_validates_and_matches(self):
        import export_actor_b_graph as ex
        fx = load_json(FIXTURE)
        errs = validate(fx, schema(), schema())
        self.assertEqual(errs, [], "\n".join(errs[:20]))
        self.assertEqual(fx, ex.make_fixture(self.g))
        self.assertEqual(sorted(fx["profiles"]), ["musket"])
        self.assertEqual(sorted(fx["modes"]), ["crouch", "run"])
        # every clip the fixture references is in its clip table
        for key, r in fx["roles"].items():
            if r["clip"]:
                self.assertIn(r["clip"], fx["clips"], key)

    def test_committed_output_up_to_date(self):
        import export_actor_b_graph as ex
        self.assertTrue(os.path.exists(OUT), "run tools/anim_graph/export_actor_b_graph.py first")
        self.assertEqual(read_text(OUT), ex.dumps(self.g))
        self.assertEqual(read_text(REPORT), ex.make_report(self.g))

    def test_two_runs_byte_identical(self):
        outs = []
        for _ in range(2):
            td = tempfile.mkdtemp()
            o = [os.path.join(td, n) for n in ("g.json", "r.md", "f.json")]
            p = subprocess.run([sys.executable, "-B", EXPORTER, "--source-root", SOURCE_ROOT, "--out", o[0], "--report", o[1], "--fixture", o[2]],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=600)
            self.assertEqual(p.returncode, 0, p.stderr)
            outs.append([read_bytes(x) for x in o])
        self.assertEqual(outs[0], outs[1])

    def test_check_mode(self):
        p = subprocess.run([sys.executable, "-B", EXPORTER, "--source-root", SOURCE_ROOT, "--check"], stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE, universal_newlines=True, timeout=600)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn("CHECK OK", p.stdout)

    def test_provenance(self):
        m = self.g["meta"]
        self.assertIn("source/player_blending/player_blending.json", m["generated_from"])
        self.assertIn("resolve_overlays.py", m["vendored"])
        for name, c in self.g["clips"].items():
            self.assertRegex(c["native_asset_id"] or "", r"^(stream_)?[0-9a-f]{64}$", name)

    def test_stdlib_only(self):
        tree = ast.parse(read_text(EXPORTER))
        mods = set()
        for n in ast.walk(tree):
            if isinstance(n, ast.Import):
                mods |= {a.name.split(".")[0] for a in n.names}
            elif isinstance(n, ast.ImportFrom) and n.module:
                mods.add(n.module.split(".")[0])
        stdlib = {"__future__", "argparse", "collections", "copy", "csv", "fnmatch", "hashlib", "json", "os", "re",
                  "struct", "sys"}
        vendored = {"resolve_overlays", "symvm", "decode_lambda"}
        self.assertLessEqual(mods, stdlib | vendored, mods - stdlib - vendored)

    # ------------------------------------------------------------------ ids and records
    def test_chain_and_layer_records_byte_equal(self):
        n = 0

        def check_role(r, where):
            nonlocal n
            for c in r["chain"]:
                e = self.remap[(c["set"], c["record_offset"])]
                self.assertEqual((e["from_id"], e["to_id"], e["from_clip"], e["to_clip"]),
                                 (c["from_id"], c["to_id"], c["from"], c["to"]), where)
                self.assertRegex(c["from_id"], r"^[0-9a-f]{8}$")
                self.assertRegex(c["to_id"], r"^[0-9a-f]{8}$")
                n += 1
            for l in r["layers"]:
                for s in l["sources"]:
                    e = self.remap[(s["set"], s["record_offset"])]
                    self.assertEqual((e["from_id"], e["to_id"], e["raw_flags"]), (s["from_id"], s["to_id"], s["flags"]), where)
                    n += 1
            if r.get("leaf_node"):
                node = self.D["nodes"][r["leaf_node"]]
                self.assertEqual(node["clip_id"], r["leaf_id"], where)
        for k, r in self.g["roles"].items():
            check_role(r, k)
        for k, t in self.g["aim_trees"].items():
            for s, r in t.items():
                if s != "hands":
                    check_role(r, k + "." + s)
        for k, a in self.g["actions"].items():
            check_role(a["partial_role"], k)
            check_role(a["twin_role"], k + "/twin")
        for grp in self.g["runtime_roles"].values():
            for k, r in grp.items():
                check_role(r, k)
        self.assertGreater(n, 1000)

    def test_graph_state_transitions_match_subgraph(self):
        sub = load_json(os.path.join(SOURCE_ROOT, "graph_analysis", "graph", "state_subgraph.json"))
        gs = self.g["graph_states"]
        for t in sub["transitions"]:
            m = [x for x in gs[t["source"]]["transitions"] if x["record"] == t["record_offset"] and x["order"] == t["order_in_source"]]
            self.assertEqual(len(m), 1, (t["source"], t["record_offset"]))
            m = m[0]
            self.assertAlmostEqual(m["fade_s"], t["fade_s"], places=4)
            self.assertEqual((m["request"], m["target"], m["flags_0x04"], m["byte_0x28"]),
                             (t["request"], t["target"], t["flags_0x04"], t["byte_0x28"]))
            self.assertEqual(len(m["conditions"]), len(t["conditions"]))
            for a, b in zip(m["conditions"], t["conditions"]):
                self.assertEqual((a["record_offset"], a["mode"], a.get("expr")), (b["record_offset"], b["mode"], b.get("lambda_godot_expr")))
        for s in sub["states"]:
            self.assertEqual(gs[s["name"]]["state_offset"], s["state_offset"])

    def test_transition_rows(self):
        T = self.g["transitions"]
        for k, t in T.items():
            if t["status"] == "graph":
                self.assertIsNotNone(t["graph"], k)
                self.assertAlmostEqual(t["use"]["fade_s"], t["graph"]["fade_s"], places=6, msg=k)
            else:
                self.assertIsNone(t["graph"], k)
                self.assertIn("fade_s", t["use"], k)
            for o in t["overrides"]:
                self.assertIn(o["flag"], self.g["gameplay_overrides"])
        # graph-faithful defaults; the plan's gameplay choices are opt-in overrides
        self.assertEqual(T["hemi_fw_to_bw"]["use"]["fade_s"], 0.75)
        self.assertEqual(T["hemi_fw_to_bw"]["graph"]["record"], "0x0002a880")
        self.assertEqual([o["fade_s"] for o in T["hemi_fw_to_bw"]["overrides"]], [0.3])
        self.assertEqual(T["aimidle_to_move"]["use"]["fade_s"], 0.5)
        self.assertEqual(T["land_to_move"]["use"]["gate_s"], 0.333333)
        self.assertEqual(T["land_to_move"]["overrides"][0]["gate_s"], 0.0)
        self.assertEqual(T["idle_to_start"]["graph"]["record"], "0x0003f290")
        self.assertEqual(T["move_to_stop"]["graph"]["record"], "0x0002a8b0")
        self.assertEqual(T["idle_to_move"]["graph"]["record"], "0x0003f2c0")
        self.assertEqual(T["takeoff_to_jump"]["use"], {"fade_s": 0.0, "gate_phase": 1.0})
        self.assertEqual(T["land_idle_exit"]["use"]["gate_phase"], 0.6)
        self.assertTrue(self.g["options"]["use_transition_anims"])
        self.assertTrue(self.g["options"]["holster"])
        self.assertFalse(self.g["options"]["aim_walk"])
        for flag, o in self.g["gameplay_overrides"].items():
            self.assertIs(o["default"], False, flag)
        th = self.g["thresholds"]
        self.assertEqual((th["hemi_enter_deg"], th["hemi_to_bw_deg"], th["hemi_to_fw_deg"]), (90.0, 97.5, 82.5))
        self.assertEqual(th["land_idle_exit_phase"], {"soft": 0.6, "medium": 0.8, "hard": 0.8, "jump": 0.9, "jump_med": 0.9,
                                                      "damage": 0.8, "death": 0.8})
        self.assertEqual(th["land_run_bw_early_exit_dir_deg"], [90.0, 135.0])
        self.assertEqual(th["land_run_bw_exit_phase"], 1.0)

    def variant(self, key, record, source=None):
        vs = [v for v in self.g["transitions"][key]["graph_variants"]
              if v["record"] == record and (source is None or v["source"] == source)]
        self.assertEqual(len(vs), 1, (key, record, source))
        return vs[0]

    def test_transition_variant_use(self):
        """Each record carries its own fade and gate; the row-level use is the primary record's only."""
        D = self.g["graph_states"]
        for k, t in self.g["transitions"].items():
            for v in t["graph_variants"]:
                rec = [x for x in D[v["source"]]["transitions"] if x["record"] == v["record"]][0]
                self.assertAlmostEqual(v["use"]["fade_s"], rec["fade_s"], places=6, msg=(k, v["record"]))
                phase_mins = [c["min"] for c in rec["conditions"] if c["variable"].startswith("phase") and c["min"]]
                self.assertEqual(v["use"].get("gate_phase"), phase_mins[0] if phase_mins else None, (k, v["record"]))
                frames = [c for c in rec["conditions"] if c["variable"].startswith("frames")]
                self.assertEqual("gate_s" in v["use"], bool(frames), (k, v["record"]))
            if t["status"] == "graph":
                prim = dict(t["graph_variants"][0]["use"])
                self.assertTrue(set(t["use"].items()) <= set(prim.items()), k)
                self.assertIn("primary record %s" % t["graph"]["record"], t["use_basis"])
        # review goldens: jump landing has no frame gate and a 0.4 s fade; per-landing exits
        v = self.variant("land_to_move", "0x0002ff20", "jump-long-land-idle")
        self.assertEqual(v["use"], {"fade_s": 0.4})
        self.assertEqual(self.variant("land_to_move", "0x00039970", "fall-land-soft-idle")["use"]["gate_s"], 0.333333)
        self.assertEqual(self.variant("land_to_move", "0x00039970", "fall-land-soft-idle")["use"]["gate"], "land_move_gate")
        for src, recs in (("fall-land-soft-idle", ("0x00039820", "0x00039850", "0x00039880", "0x000398b0")),
                          ("fall-land-hard-idle", ("0x0002c110", "0x0002c140", "0x0002c170", "0x0002c1a0")),
                          ("fall-land-medium-idle", ("0x0002c110", "0x0002c140", "0x0002c170", "0x0002c1a0")),
                          ("jump-long-land-idle", ("0x0002fdd0", "0x0002fe00", "0x0002fe30", "0x0002fe60")),
                          ("jump-long-land-idle-med", ("0x0002fdd0", "0x0002fe00", "0x0002fe30", "0x0002fe60"))):
            for rec in recs:
                self.variant("land_to_move", rec, src)
        self.assertEqual(self.variant("land_to_move", "0x0002fdd0", "jump-long-land-idle")["use"], {"fade_s": 0.4})
        self.assertEqual(self.variant("land_idle_exit", "0x0002fec0", "jump-long-land-idle")["use"], {"fade_s": 0.4, "gate_phase": 0.9})
        self.assertEqual(self.variant("land_idle_exit", "0x0002c200", "fall-land-hard-idle")["use"], {"fade_s": 0.2, "gate_phase": 0.8})
        self.assertEqual(self.variant("crouch_change_exit", "0x0003d1b0")["use"], {"fade_s": 0.7, "gate_phase": 1.0})
        self.assertEqual(self.variant("crouch_change_exit", "0x0003d180")["use"], {"fade_s": 0.7, "gate_phase": 0.75})
        self.assertEqual(self.variant("land_run_exit", "0x0003f730", "jump-long-land-run")["use"], {"fade_s": 0.2, "gate_phase": 0.9})
        # correction 9: a first condition above 1 is frames whatever the flags word says (0x00045c30, flags 0x1)
        for rec, src in (("0x000398e0", "fall-land-soft-idle"), ("0x0002c1d0", "fall-land-hard-idle"),
                         ("0x0002c1d0", "fall-land-medium-idle")):
            u = self.variant("land_crouch_change", rec, src)["use"]
            self.assertEqual((u["gate_frames"], u["gate_s"], u["gate"], u["fade_s"]), (10.0, 0.333333, "land_move_gate", 0.5))
            self.assertNotIn("gate_phase", u)
            self.assertNotIn("gate_phase_unreachable", u)
            self.assertIn("phase >= 10 could never fire", u["gate_alternative"])
        c = [x for x in self.g["graph_states"]["fall-land-soft-idle"]["transitions"] if x["record"] == "0x000398e0"][0]
        self.assertEqual((c["conditions"][0]["flags_word"], c["conditions"][0]["variable"][:7]), ("00000001", "frames?"))
        for st in self.g["graph_states"].values():
            for t in st["transitions"]:
                for i, cd in enumerate(t["conditions"]):
                    vals = [x for x in (cd["min"], cd["max"]) if x is not None]
                    if i == 0 and vals and max(abs(x) for x in vals) > 1 and "selector 6" not in cd["variable"]:
                        self.assertTrue(cd["variable"].startswith("frames"), (t["record"], cd["record_offset"]))
        e = self.variant("land_run_early_exit", "0x0003b620", "fall-land-soft-run")["use"]
        self.assertEqual((e["gate_frames"], e["secondary_min"]), (10.0, 45.0))
        # backward run landings: exits into run-bkwd, 90..135 deg early exit, 0.3 s stop
        e = self.variant("land_run_early_exit", "0x0002de80", "fall-land-hard-run-bw")
        self.assertEqual((e["target"], e["use"]["gate_frames"], e["use"]["secondary_min"], e["use"]["secondary_max"]),
                         ("run-bkwd", 10.0, 90.0, 135.0))
        self.assertEqual(self.variant("land_run_exit", "0x0002dee0", "fall-land-soft-run-bw")["target"], "run-bkwd")
        self.assertEqual(self.variant("land_run_stop", "0x0002ddc0", "fall-land-medium-run-bw")["use"]["fade_s"], 0.3)
        self.assertEqual(self.variant("land_crouch_change", "0x0002de50", "fall-land-soft-run-bw")["target"], "run-bkwd")
        self.assertEqual(self.variant("land_run_to_move", "0x0002df70", "fall-land-hard-run-bw")["target"], "run-fw")
        self.assertEqual(self.variant("land_idle_exit", "0x0002fec0", "jump-long-land-idle-med")["use"],
                         {"fade_s": 0.4, "gate_phase": 0.9})
        self.assertEqual(self.variant("land_idle_exit", "0x0003af30", "fall-land-damage-idle")["use"],
                         {"fade_s": 0.4, "gate_phase": 0.8})
        # ground_to_fall: pre-fall's own phase gate stays on the variant, not on the row
        T = self.g["transitions"]
        self.assertEqual(T["ground_to_fall"]["use"], {"fade_s": 0.5})
        self.assertEqual(T["ground_to_fall"]["graph_variants"][0]["use"]["gate_phase"], 0.02)
        # crouch toggles: the graph's first-match record is primary; the fallback follows
        self.assertEqual(T["move_mode_change_crouch"]["graph"]["record"], "0x0002a940")
        self.assertEqual(T["move_mode_change_crouch"]["graph"]["target"], "crouch-change-idle^idle")
        self.assertEqual(T["idle_stance_change"]["graph"]["record"], "0x0003f3b0")
        self.assertEqual(T["stop_mode_change"]["graph"]["record"], "0x0003fc30")
        for k in ("move_mode_change_crouch", "idle_stance_change", "stop_mode_change", "transition_state_crouch_change"):
            self.assertEqual(T[k]["graph"]["target"], "crouch-change-idle^idle", k)
            self.assertIn("why", T[k], k)
        for v in T["move_mode_change_crouch"]["graph_variants"]:
            if v["target"] == "crouch-change-idle^idle":
                self.assertEqual(v["requires_option"], "crouch_change_full_body")
            else:
                self.assertEqual(v["when_option_off"], "crouch_change_full_body")
        self.assertTrue(self.g["options"]["crouch_change_full_body"])
        self.assertEqual(self.g["crouch_change"]["musket/stand_to_crouch"]["full"]["clip"], "actor_b-p-stand^crouch--base")

    def test_structural_assertions_hold(self):
        B = base_bindings()
        g = self.g
        # (a) move-bank leaves share one carry-layer set
        for w in g["profiles"]:
            for m in g["modes"]:
                sigs = set()
                for rk in B["bank_roles"]["move_fw"] + B["bank_roles"]["move_bw"]:
                    r = g["roles"][f"{w}/{m}/{rk}"]
                    sigs.add(tuple((l["clip"], l["weight"]) for l in r["layers"] if l["slot"] != "hands"))
                self.assertEqual(len(sigs), 1, f"{w}/{m}")
        # (b) idle layers identical for walk/run/sprint
        for w in g["profiles"]:
            sigs = {tuple((l["clip"], l["weight"], l["slot"], l["kind"], l["set"], l["record_offset"])
                          for l in g["roles"][f"{w}/{m}/idle"]["layers"]) for m in ("walk", "run", "sprint")}
            self.assertEqual(len(sigs), 1, w)
        # (c) additive kind invariant
        kinds = {}
        for k, r in g["roles"].items():
            if r["clip"]:
                kinds.setdefault(k.split("/")[2], set()).add(r["additive"])
        self.assertTrue(all(len(v) == 1 for v in kinds.values()))
        # (d) clips exist (dump) and carry library data
        dump = {x["name"] for x in load_json(os.path.join(SOURCE_ROOT, "graph_analysis", "graph", "actor_b_library_dump.json"))}
        self.assertLessEqual(set(g["clips"]), dump)
        # (f) only allowed roles missing
        import fnmatch
        for k, r in g["roles"].items():
            if r["status"] == "missing":
                self.assertTrue(any(fnmatch.fnmatchcase(k, p) for p in g["allowed_missing"]), k)

    def test_assertions_fail_loudly(self):
        B = base_bindings()
        B["allowed_missing"] = [p for p in B["allowed_missing"] if "pre_fall" not in p]
        g, err = build(B)
        self.assertIsNone(g)
        self.assertIn("(f) role", err)
        B = base_bindings()
        B["transitions"]["idle_loop"]["records"] = [["idle", "0x0000dead"]]
        g, err = build(B)
        self.assertIsNone(g)
        self.assertIn("(e) transition idle_loop", err)
        B = base_bindings()
        B["transitions"]["hemi_fw_to_bw"]["use"] = {"fade_s": 0.3}
        g, err = build(B)
        self.assertIsNone(g)
        self.assertIn("hemi_fw_to_bw", err)

    def test_warnings(self):
        w = "\n".join(self.g["meta"]["warnings"])
        for name in ("def-inf-v-actor_b-standing-struggle-save-reaction", "actor_b-facial-idle-ambi-02'",
                     "actor_b-facial-idle-ambi-02-add", "actor_b-facial-idle-caut-01", "actor_b-r-hand-gun'"):
            self.assertIn(name, w)

    # ------------------------------------------------------------------ goldens (plan section 5.3)
    def assertLayer(self, role, clip, weight, slot=None, kind=None):
        lm = layer_map(role)
        self.assertIn(clip, lm, [l["clip"] for l in role["layers"]])
        self.assertAlmostEqual(lm[clip]["weight"], weight, places=6, msg=clip)
        if slot:
            self.assertEqual(lm[clip]["slot"], slot, clip)
        if kind:
            self.assertEqual(lm[clip]["kind"], kind, clip)
        return lm[clip]

    def test_golden_rows(self):
        R = self.g["roles"]
        r = R["musket/run/fw"]
        self.assertEqual(r["clip"], "actor_b-p-run-fw")
        self.assertLayer(r, "actor_b-p-rifle-run-arms", 0.8, "arms", "partial")
        self.assertLayer(r, "actor_b-p-rifle-run-arms--add", 0.4, "arms_add", "additive")
        self.assertLayer(r, "actor_b-p-rifle-idle-spine--add", 0.2, "spine_add", "additive")
        h = self.assertLayer(r, "actor_b-p-rifle-crouch-idle--hands", 0.9, "hands", "partial")
        self.assertEqual(h["superseded_by"], "hands")
        self.assertEqual(h["graph_clip"], "actor_b-p-rifle-idle-hands")
        self.assertIn("actor_b-p-rifle-idle-hands", self.g["clips"]["actor_b-p-rifle-crouch-idle--hands"]["graph_names"])
        r = R["musket/sprint/fw"]
        self.assertEqual(r["clip"], "actor_b-p-sprint-fw")
        self.assertLayer(r, "actor_b-p-rifle-run-arms", 0.9)
        self.assertLayer(r, "actor_b-p-rifle-run-arms--add", 0.6)
        r = R["musket/walk/fw"]
        self.assertEqual(r["clip"], "actor_b-p-walk-fw")
        self.assertLayer(r, "actor_b-p-rifle-idle-arms", 0.8)
        self.assertLayer(r, "actor_b-p-rifle-idle-arms--add", 0.8)
        self.assertLayer(r, "actor_b-p-rifle-idle-spine--add", 0.5)
        r = R["musket/crouch/fw"]
        self.assertEqual(r["clip"], "actor_b-p-crouch-walk-fw")
        self.assertLayer(r, "actor_b-p-rifle-crouch-run-arms", 0.8)
        self.assertLayer(r, "actor_b-p-rifle-crouch-run-arms--add", 0.8)
        r = R["musket/run/idle"]
        self.assertEqual(r["clip"], "actor_b-p-relax-idle")
        self.assertLayer(r, "actor_b-p-rifle-run-arms", 1.0)
        self.assertLayer(r, "actor_b-p-rifle-idle-spine--add", 0.6)
        r = R["musket/run/fall"]
        self.assertEqual(r["clip"], "actor_b-p-fall")
        l = self.assertLayer(r, "actor_b-p-drop-down^fall--rifle", 1.0)
        self.assertTrue(l["weight_source"].startswith("default"))
        self.assertLayer(r, "actor_b-p-rifle-run-arms", 0.8)
        r = R["bow/walk/fw"]
        self.assertEqual(self.assertLayer(r, "actor_b-p-bow-move--arms", 0.75)["key"], "state")
        l = self.assertLayer(r, "actor_b-p-bow-hands", 1.0, "hands")
        self.assertTrue(l["weight_source"].startswith("default"))
        self.assertEqual(self.assertLayer(R["bow/sprint/fw"], "actor_b-p-bow-sprint--arms", 0.75)["key"], "state")
        self.assertLayer(R["bow/run/idle"], "actor_b-p-bow-move--arms", 0.85)
        self.assertLayer(R["pistol/run/fw"], "actor_b-r-arm-gun", 0.7)
        self.assertLayer(R["pistol/crouch/fw"], "actor_b-r-arm-gun-crouch-idle", 0.5)
        self.assertLayer(R["pistol/crouch/fw"], "actor_b-r-arm-gun-crouch-idle--add", 0.5)
        for w in self.g["profiles"]:
            self.assertEqual(R[f"{w}/crouch/idle"]["clip"], "actor_b-p-crouch-idle")
        self.assertEqual(R["musket/sprint/land_soft_run"]["clip"], "actor_b-p-land-soft^sprint")
        A = self.g["aim_trees"]
        self.assertEqual(A["bow/crouch"]["base"]["clip"], "actor_b-p-bow-aim-crouch-idle")
        self.assertEqual(A["bow/crouch"]["up"]["clip"], "actor_b-p-bow-crouch-aim-up--add")
        self.assertEqual(A["bow/crouch"]["down"]["clip"], "actor_b-p-bow-crouch-aim-down--add")
        self.assertEqual(A["bow/crouch"]["hands"]["clip"], "actor_b-p-bow-aim-crouch-hands-idle")
        self.assertEqual(A["musket/crouch"]["base"]["clip"], "actor_b-p-rifle-aim-crouch-idle")
        self.assertEqual(A["musket/crouch"]["up"]["clip"], "actor_b-p-rifle-idle-crouch-aim-up--add")
        self.assertEqual(A["musket/crouch"]["down"]["clip"], "actor_b-p-rifle-idle-crouch-aim-down--add")
        self.assertEqual(A["musket/stand"]["up"]["blend_weight"]["expr"], ["f32[C8+248]"])
        self.assertEqual(A["musket/stand"]["down"]["blend_weight"]["expr"], ["f32[C8+252]"])
        self.assertEqual(A["musket/stand"]["blocked"]["blend_weight"]["expr"], ["f32[C8+172]"])
        self.assertEqual(A["musket/stand"]["arms_relaxed"]["blend_weight"]["expr"], ["f32[C8+176]"])
        X = self.g["actions"]
        self.assertEqual(X["pistol/stand/reload_mid"]["partial"], "actor_b-p-pistol-rev-reload-mid--part")
        self.assertEqual(X["musket/stand/reload_mid"]["partial"], "actor_b-p-rifle-idle-aim-reload-mid--part")
        self.assertTrue(X["musket/stand/reload_mid"]["loop"])
        self.assertFalse(X["musket/stand/reload_begin"]["loop"])
        self.assertEqual(X["musket/stand/nock"]["status"], "missing")
        self.assertEqual(X["musket/stand/nock"]["partial_role"]["graph_clip"], "bolt-rifle--reload--arms")
        self.assertEqual(X["bow/stand/nock"]["partial"], "actor_b-p-bow-reload--part")
        self.assertEqual(X["bow/stand/nock"]["twin"], "actor_b-p-bow-reload--add")
        self.assertEqual(X["musket/stand/equip"]["partial"], "actor_b-lg-stealth-draw^idle--arm-r")
        self.assertEqual(X["musket/stand/equip"]["twin"], "actor_b-lg-stealth-draw^idle--add")
        self.assertEqual(X["bow/stand/equip"]["partial"], "actor_b-p-bow-draw-grab^idle--part")
        self.assertEqual(X["pistol/stand/equip"]["partial"], "actor_b-p-stealth-draw-p^idle--arm-r")
        self.assertEqual(X["musket/stand/holster"]["start_phase"], 1.0)
        G = self.g["grips"]
        self.assertEqual((G["musket"]["carry"], G["musket"]["aim_stand"], G["musket"]["aim_crouch"]),
                         ("actor_b-p-rifle-crouch-idle--hands", "actor_b-p-rifle-idle-aim--hands", "actor_b-p-rifle-aim-crouch-idle--hands"))
        self.assertEqual((G["bow"]["carry"], G["bow"]["aim_stand"], G["bow"]["aim_crouch"]),
                         ("actor_b-p-bow-hands", "actor_b-p-bow-aim-hands-idle", "actor_b-p-bow-aim-crouch-hands-idle"))
        self.assertEqual((G["pistol"]["carry"], G["pistol"]["aim_stand"]), ("actor_b-r-hand-revolver", "actor_b-r-hand-revolver-aim"))
        C = self.g["runtime_clips"]
        self.assertEqual(C["hit_add"]["fw"], "actor_b-p-hr-bliz-fw--add")
        self.assertEqual(C["hit_full"]["crouch/fw"], "actor_b-p-crouch-hr-fw")
        self.assertEqual(self.g["runtime_roles"]["hit_full"]["musket/crouch/fw"]["layers"][0]["clip"], "actor_b-p-crouch-hr-fw--rifle")

    def test_fidelity_states_present(self):
        R = self.g["roles"]
        expect = {"run/start_fw": "actor_b-p-idle^run-fw", "run/start_bw_lt": "actor_b-p-idle^run-bw-lt",
                  "run/stop_fw": "actor_b-p-run-fw^idle", "run/stop_bw_rt": "actor_b-p-run-bw-rt^idle",
                  "run/rev_fw_bw": "actor_b-p-quickstop^run-bw", "run/rev_bw_fw_lt": "actor_b-p-quickstop^run-fw-lt",
                  "sprint/stop_fw": "actor_b-p-stealth-run-fw^idle", "crouch/start_fw": "actor_b-p-crouch-idle^walk-fw",
                  "run/turn_l": "actor_b-p-relax-idle-turn-90-l", "crouch/turn_r": "actor_b-p-crouch-idle-turn-90-r",
                  "run/quick_turn_180": "actor_b-p-stealth-idle-turn-180", "walk/land_soft_run": "actor_b-p-land-soft^walk",
                  "crouch/land_hard_run": "actor_b-p-land-hard^crouch-walk", "run/land_jump_run": "actor_b-p-land-med^run",
                  "run/takeoff": "actor_b-p-run^jump-long", "run/jump": "actor_b-p-jump-long"}
        for w in self.g["profiles"]:
            for k, clip in expect.items():
                self.assertEqual(R[f"{w}/{k}"]["clip"], clip, f"{w}/{k}")
        self.assertEqual(R["bow/run/rev_fw_bw"]["begin_state"], "run-fw^run-bkwd-begin")
        self.assertTrue(R["bow/run/fw"]["loop"])
        self.assertTrue(R["bow/run/idle"]["loop"])
        self.assertTrue(R["bow/run/turn_l"]["loop"])
        self.assertFalse(R["bow/run/stop_fw"]["loop"])
        self.assertEqual(R["bow/run/turn_l_180"]["status"], "missing")
        cc = self.g["crouch_change"]
        self.assertEqual(cc["musket/stand_to_crouch"]["add"]["clip"], "actor_b-p-stand^crouch-rifle--add")
        self.assertEqual(cc["pistol/crouch_to_stand"]["add"]["clip"], "actor_b-p-crouch^stand-pistol--add")
        self.assertEqual(cc["bow/stand_to_crouch"]["full"]["status"], "substitute")
        # weapon draw / holster / grab states and their additive twins
        for w in self.g["profiles"]:
            for st in ("stand", "crouch"):
                for ak in ("grab", "equip", "holster", "holster_finish"):
                    a = self.g["actions"][f"{w}/{st}/{ak}"]
                    # THROW2: the tomahawk's draw states keep their graph state and records with substituted clips
                    self.assertEqual(a["status"], "frontier_substitute" if w == "tomahawk" else "resolved", f"{w}/{st}/{ak}")
                    self.assertEqual(a["state"], self.g["actions"][f"musket/{st}/{ak}"]["state"], f"{w}/{st}/{ak}")

    def test_landing_coverage(self):
        """Every authored landing the runtime can pick is exported: medium, backward-run, jump-med / run-hard, damage
        and death landings, with their exits bound to the landing rows."""
        R = self.g["roles"]
        expect = {"run/land_medium_idle": "actor_b-p-land-med^idle", "crouch/land_medium_idle": "actor_b-p-land-med^crouch-idle",
                  "run/land_medium_run": "actor_b-p-land-med^run", "crouch/land_medium_run": "actor_b-p-land-med^crouch-walk",
                  "walk/land_medium_run": "actor_b-p-land-med^walk",
                  "run/land_soft_run_bw": "actor_b-p-land-soft^run-bw", "crouch/land_soft_run_bw": "actor_b-p-land-soft^crouch-walk-bw",
                  "sprint/land_soft_run_bw": "actor_b-p-land-soft^sprint-bw", "walk/land_soft_run_bw": "actor_b-p-land-soft^walk-bw",
                  "run/land_medium_run_bw": "actor_b-p-land-med^run-bw", "crouch/land_medium_run_bw": "actor_b-p-land-med^crouch-walk-bw",
                  "run/land_hard_run_bw": "actor_b-p-land-hard^run-bw", "crouch/land_hard_run_bw": "actor_b-p-land-hard^crouch-walk-bw",
                  "run/land_jump_idle_med": "actor_b-p-land-med^idle", "crouch/land_jump_idle_med": "actor_b-p-land-med^crouch-idle",
                  "run/land_damage_idle": "actor_b-p-land-hard-damage^idle", "run/land_death": "actor_b-p-land-hard-damage^death"}
        for w in self.g["profiles"]:
            for k, clip in expect.items():
                self.assertEqual(R[f"{w}/{k}"]["clip"], clip, f"{w}/{k}")
            for m in self.g["modes"]:
                r = R[f"{w}/{m}/land_jump_run_hard"]
                self.assertEqual((r["status"], r["graph_clip"]), ("missing", "land-hard^run-stumble"))
        # graph states of every lower role are exported, and every record of a landing state is bound to a row
        GS = self.g["graph_states"]
        bound = {(v["source"], v["record"]) for t in self.g["transitions"].values() for v in t["graph_variants"]}
        L = self.g["landing"]
        for st in L["derived"]["graph_landing_states"]:
            if st in L["not_exported"]:
                self.assertNotIn(st, GS)
                continue
            self.assertIn(st, GS)
            self.assertEqual(GS[st]["group"], "air", st)
            for t in GS[st]["transitions"]:
                self.assertIn((st, t["record"]), bound, (st, t["record"]))
        # landing rule: medium band and backward direction, all names resolve to lower roles
        self.assertEqual((L["medium_impact_mps"], L["hard_impact_mps"], L["status"]), (6.0, 8.0, "proposed"))
        self.assertEqual(L["select"]["fall"]["medium"], {"idle": "land_medium_idle", "run": "land_medium_run",
                                                         "run_bw": "land_medium_run_bw"})
        self.assertEqual(L["select"]["jump"]["soft"]["idle"], "land_jump_idle")
        self.assertEqual(L["select"]["jump"]["soft"]["run_bw"], "land_soft_run_bw")
        self.assertEqual(L["fallback"], {"land_jump_run_hard": "land_jump_run"})
        self.assertEqual(L["derived"]["backward_deg"], 90.0)
        for kind in L["select"].values():
            for band in kind.values():
                for rk in band.values():
                    self.assertIn("musket/run/" + rk, R)
        for rk in ("land_damage_idle", "land_death"):
            self.assertIn(rk, L["never_selected"])
        # the build rejects an unknown role and a landing role that nothing selects
        B = base_bindings()
        B["landing"]["select"]["fall"]["medium"]["run_bw"] = "land_nope"
        g, err = build(B)
        self.assertIsNone(g)
        self.assertIn("unknown lower role land_nope", err)
        B = base_bindings()
        del B["landing"]["never_selected"]["land_death"]
        g, err = build(B)
        self.assertIsNone(g)
        self.assertIn("(f) landing role land_death", err)
        B = base_bindings()
        del B["landing"]["not_exported"]["fall-land-partial"]
        g, err = build(B)
        self.assertIsNone(g)
        self.assertIn("(f) graph landing state fall-land-partial", err)

    def test_resolver_disagreements(self):
        """One export loop (asc_once) for every leaf; the loops disagree on exactly three exported leaves, and the
        only leaf that uses the other loop is the requirement-2 musket crouch grip."""
        m = self.g["meta"]
        self.assertEqual((m["resolver"], m["resolver_compare"]), ("asc_once", "asc_fix"))
        self.assertEqual(m["resolver_policy"]["loop"], "asc_once")
        dis = {d["where"]: d for d in m["resolver_disagreements"]}
        self.assertEqual(sorted(dis), ["actions.bow/crouch/nock.partial", "actions.bow/crouch/nock.twin",
                                       "hand_states.musket/crouch.weapon_out"])
        self.assertEqual({k: (d["chosen"], d["basis"]) for k, d in dis.items()},
                         {"actions.bow/crouch/nock.partial": ("asc_once", "resolver_policy"),
                          "actions.bow/crouch/nock.twin": ("asc_once", "resolver_policy"),
                          "hand_states.musket/crouch.weapon_out": ("asc_fix", "frontier_requirement")})
        a = self.g["actions"]["bow/crouch/nock"]
        self.assertEqual((a["partial"], a["twin"]), ("actor_b-p-crouch-bow-reload--part", "actor_b-p-crouch-bow-reload--add"))
        pr = a["partial_role"]
        self.assertEqual((pr["resolution"], pr["resolver"], pr["resolver_basis"]), ("ambiguous", "asc_once", "resolver_policy"))
        self.assertEqual(pr["resolver_alternatives"]["asc_fix"]["clip"], "actor_b-p-bow-reload--part")
        self.assertEqual([c["record_offset"] for c in pr["chain"]], ["0x00004df8", "0x0001ba58", "0x00003e60"])
        self.assertEqual(a["twin_role"]["resolver_alternatives"]["asc_fix"]["clip"], "actor_b-p-bow-reload--add")
        self.assertEqual(self.g["actions"]["bow/stand/nock"]["partial"], "actor_b-p-bow-reload--part")
        self.assertNotIn("resolution", self.g["actions"]["bow/stand/nock"]["partial_role"])
        wo = self.g["hand_states"]["musket/crouch"]["weapon_out"]
        self.assertEqual((wo["clip"], wo["resolver"], wo["resolver_basis"]),
                         ("actor_b-p-rifle-crouch-idle--hands", "asc_fix", "frontier_requirement"))
        self.assertEqual(wo["resolver_alternatives"]["asc_once"]["status"], "disabled")
        self.assertEqual(wo["resolver_alternatives"]["asc_once"]["chain"][-1]["record_offset"], "0x00003974")
        ex = m["resolver_exceptions"]
        self.assertEqual([e["where"] for e in ex], ["hand_states.musket/crouch.weapon_out"])
        self.assertEqual(ex[0]["graph_result"]["status"], "disabled")
        self.assertIn("requirement 2", ex[0]["requirement"])
        held = ex[0]["prop_full_weight_only_via_this_choice"]
        self.assertEqual(held["count"], len(held["roles"]))
        self.assertGreater(held["count"], 30)
        self.assertIn("roles.musket/crouch/turn_l", held["roles"])
        self.assertIn("resolver_exceptions", m["resolver_note"])
        w = "\n".join(m["warnings"])
        for where in dis:
            self.assertIn("resolver: " + where, w)
        rows = {(r["weapon"], r["key"]): r for r in self.g["frontier"]["clip_table_diff"]}
        self.assertTrue(rows[("bow", "nock_crouch")]["match"])
        self.assertEqual(rows[("bow", "nock_crouch")]["resolution"], "ambiguous")
        # a stale or redundant choice fails; a choice that leaves the loop must declare a frontier requirement
        B = base_bindings()
        B["resolver_choices"]["roles.bow/run/fw"] = {"use": "asc_fix", "basis": "frontier_requirement",
                                                     "requirement": "test", "why": "test"}
        g, err = build(B)
        self.assertIsNone(g)
        self.assertIn("stale choice", err)
        B = base_bindings()
        B["resolver_choices"]["actions.bow/crouch/nock.partial"] = {"use": "asc_once", "why": "test"}
        g, err = build(B)
        self.assertIsNone(g)
        self.assertIn("redundant choice", err)
        B = base_bindings()
        B["resolver_choices"]["actions.bow/crouch/nock.partial"] = {"use": "asc_fix", "why": "test"}
        g, err = build(B)
        self.assertIsNone(g)
        self.assertIn("without basis 'frontier_requirement'", err)
        # the whole export follows the policy loop
        B = base_bindings()
        B["resolver_policy"]["loop"], B["resolver_policy"]["compare"] = "asc_fix", "asc_once"
        B["resolver_choices"] = {}
        g, err = build(B)
        self.assertIsNone(err)
        self.assertEqual(g["meta"]["resolver"], "asc_fix")
        self.assertEqual(g["actions"]["bow/crouch/nock"]["partial"], "actor_b-p-bow-reload--part")

    def test_resolver_policy_evidence(self):
        """The evidence behind resolver_policy: under asc_fix no state leaf and no layer target reaches the crouch
        bow-draw records in any of the 12 selections; under asc_once they are live (the bow's crouch reload)."""
        import export_actor_b_graph as exm
        e = exm.Exporter(SOURCE_ROOT)
        starts = {n["clip_id"] for n in e.N.values() if n.get("type") == "anim-node-animation" and n.get("clip_id")}
        for sn, st in e.db.sets.items():
            for r in st["remaps"]:
                if int(r["raw_flags"].split()[0], 16) & 0x01:
                    starts.add(r["to_id"])
        self.assertGreater(len(starts), 1000)
        targets = {"0x0001ba58", "0x0001ba6c", "0x00003e60", "0x00003e74"}
        used = {"asc_fix": set(), "asc_once": set()}
        for loop in used:
            for w in self.g["profiles"]:
                for mk in self.g["modes"]:
                    sel = e.selection(w, mk)
                    for i in starts:
                        used[loop] |= {s.offset for s in e.db.resolve_id(i, sel, loop).steps if s.offset in targets}
        self.assertEqual(used["asc_fix"], set())
        self.assertEqual(used["asc_once"], targets)

    def test_disabled_resolver_choice_exports_graph_result(self):
        B = base_bindings()
        B["resolver_choices"]["hand_states.musket/crouch.weapon_out"]["enabled"] = False
        g, err = build(B)
        self.assertIsNone(err)
        self.assertIsNone(g["hand_states"]["musket/crouch"]["weapon_out"]["clip"])
        self.assertEqual(g["hand_states"]["musket/crouch"]["weapon_out"]["resolver"], "asc_once")
        self.assertEqual(g["meta"]["resolver_exceptions"], [])
        self.assertIsNone(g["weapon_layers"]["weapon_out"]["clips"]["musket/crouch"]["clip"])
        ex = [k for k, r in g["roles"].items() if r["prop"].get("exempt", "").startswith("bindings.resolver_choices")]
        held = self.g["meta"]["resolver_exceptions"][0]["prop_full_weight_only_via_this_choice"]["roles"]
        self.assertEqual(sorted("roles." + k for k in ex), sorted(x for x in held if x.startswith("roles.")))
        self.assertTrue(all(k.startswith("musket/crouch/") for k in ex))
        # without the choice at all, (g) fails on the musket crouch roles
        B = base_bindings()
        del B["resolver_choices"]["hand_states.musket/crouch.weapon_out"]
        g, err = build(B)
        self.assertIsNone(g)
        self.assertIn("(g) roles.musket/crouch/", err)

    def test_weapon_out_and_prop_coverage(self):
        wl = self.g["weapon_layers"]
        self.assertTrue(self.g["options"]["weapon_out_fingers"])
        self.assertEqual(wl["weapon_out"]["state"], "idle-pistol-out-part")
        self.assertTrue(wl["weapon_out"]["loop"])
        self.assertEqual(wl["weapon_out"]["weight"], 1.0)
        self.assertEqual(wl["weapon_out"]["clips"]["pistol/stand"]["clip"], "actor_b-r-hand-revolver")
        self.assertEqual(wl["weapon_out"]["clips"]["pistol/stand"]["prop_bones_keyed"], ["r_hand_prop_attachment"])
        self.assertEqual(wl["prop_bones"], {"bow": "l_hand_prop_attachment", "musket": "r_hand_prop_attachment",
                                            "pistol": "r_hand_prop_attachment", "spear": "r_hand_prop_attachment",
                                            "tomahawk": "r_hand_prop_attachment", "atlatl": "r_hand_prop_attachment"})
        R = self.g["roles"]
        p = R["pistol/run/idle"]["prop"]
        self.assertTrue(p["full_weight"])
        self.assertEqual([(d["clip"], d["source"]) for d in p["drivers"]], [("actor_b-r-hand-revolver", "weapon_out")])
        self.assertTrue(R["musket/crouch/fw"]["prop"]["full_weight"])
        self.assertIn(("actor_b-p-bow-hands", "layer"), [(d["clip"], d["source"]) for d in R["bow/run/fw"]["prop"]["drivers"]])
        # the partial applies only where the weapon-base set remaps its leaf (1p-idle-fingers): musket and pistol
        C = wl["weapon_out"]["clips"]
        self.assertEqual({k: c["applies"] for k, c in C.items()},
                         {"bow/stand": False, "bow/crouch": False, "musket/stand": True, "musket/crouch": True,
                          "pistol/stand": True, "pistol/crouch": True,
                          # thrown weapons: weapon-base-pick-up has no 1p-idle-fingers record
                          "spear/stand": False, "spear/crouch": False, "tomahawk/stand": False,
                          "tomahawk/crouch": False, "atlatl/stand": False, "atlatl/crouch": False})
        self.assertEqual((C["musket/stand"]["weapon_base_records"], C["pistol/crouch"]["weapon_base_records"],
                          C["bow/stand"]["weapon_base_records"]), (["0x00009cac"], ["0x00019368"], []))
        self.assertEqual(wl["weapon_out"]["apply_rule"], "weapon_base_remaps_leaf")
        self.assertFalse(any(d["source"] == "weapon_out" for k, r in R.items() if k.startswith("bow/")
                             for d in r["prop"]["drivers"]))
        B = base_bindings()
        B["weapon_layers"]["weapon_out"]["force"] = {"bow": True}
        g, err = build(B)
        self.assertIsNone(err)
        self.assertTrue(g["weapon_layers"]["weapon_out"]["clips"]["bow/stand"]["applies"])
        self.assertIn("force.bow", g["weapon_layers"]["weapon_out"]["clips"]["bow/stand"]["applies_why"])
        # (g) holds for every role (or is exempt with a reason)
        for grp, rows in (("roles", R), ("hit_full", self.g["runtime_roles"]["hit_full"]),
                          ("death", self.g["runtime_roles"]["death"])):
            for k, r in rows.items():
                self.assertTrue(r["prop"]["full_weight"] or r["prop"].get("exempt"), (grp, k))
        self.assertIn("exempt", R["bow/run/death"]["prop"])
        self.assertIn("weapon-out finger partial", self.g["meta"]["superseded_by"])
        self.assertIn("weapon-out finger partial", self.g["gameplay_overrides"]["override_exact_hands_grip"]["why"])
        # the assertion fails loudly when the weapon-out partial is switched off (pistol props undriven)
        B = base_bindings()
        B["options"]["weapon_out_fingers"] = False
        g, err = build(B)
        self.assertIsNone(g)
        self.assertIn("(g) roles.pistol/run/idle", err)

    def test_slots_match_keyed_bones(self):
        kb = load_json(os.path.join(TOOL, "actor_b_keyed_bones.json"))
        bones = kb["bones"]

        def keyed(c):
            out = set()
            for j, ch in enumerate(kb["clips"][c]):
                v = int(ch, 16)
                out |= {bones[4 * j + k] for k in range(4) if (v >> k) & 1}
            return out
        hand = re.compile(r"(palm|thumb|index|middle|ring|pinky|prop_attachment)")
        self.assertLessEqual(set(self.g["clips"]), set(kb["clips"]))
        n = 0
        groups = [self.g["roles"]] + [self.g["runtime_roles"][x] for x in self.g["runtime_roles"]]
        groups.append({"%s.%s" % (k, s): r for k, t in self.g["aim_trees"].items() for s, r in t.items() if s != "hands"})
        groups.append({"%s.%s" % (k, s): r for k, t in self.g["aim_move"].items() for s, r in t.items()})
        groups.append({"%s.%s" % (k, s): a[s] for k, a in self.g["actions"].items() for s in ("partial_role", "twin_role")})
        for grp in groups:
            for k, r in grp.items():
                for l in r["layers"]:
                    if not l["clip"]:
                        continue
                    kbs = keyed(l["clip"])
                    if l.get("bones") is not None:
                        # a pose sampled on a bone mask (carry_overrides, THROW2): it keys its mask only
                        self.assertLessEqual(set(l["bones"]), kbs, (k, l["clip"]))
                        kbs = set(l["bones"])
                    self.assertEqual(l["keyed_bone_count"], len(kbs), l["clip"])
                    if l["slot"] == "hands":
                        self.assertTrue(all(hand.search(b) for b in kbs), (k, l["clip"]))
                    elif l["kind"] == "partial":
                        self.assertFalse(all(hand.search(b) for b in kbs), (k, l["clip"]))
                    n += 1
        self.assertGreater(n, 850)
        self.assertEqual(sorted(self.g["meta"]["slot_notes"]), ["actor_b-p-crouch-hr-fw--rifle"])
        self.assertIn("neck", self.g["meta"]["slot_notes"]["actor_b-p-crouch-hr-fw--rifle"])

    def test_direct_hit_roles_have_no_clip(self):
        for k, r in self.g["roles"].items():
            rk = k.split("/")[2]
            if rk in ("hit_full", "hit_add"):
                self.assertEqual(r["status"], "direct", k)
                self.assertIsNone(r["clip"], k)
                self.assertEqual(r["layers"], [], k)
                self.assertTrue(r["use_runtime_roles"].startswith("runtime_roles.%s.%s/" % (rk, "/".join(k.split("/")[:2]))), k)
        self.assertEqual(self.g["runtime_roles"]["hit_full"]["musket/crouch/fw"]["clip"], "actor_b-p-crouch-hr-fw")
        self.assertEqual(self.g["runtime_clips"]["hit_add_by_stance"]["crouch/fw"], "actor_b-p-bliz-crouch-hr-fw--add")

    def test_thrown_weapons(self):
        """THROW: spear / tomahawk / atlatl on the graph's pick-up weapon base (throwables_design.md 3.2-3.5)."""
        g = self.g
        for w in ("spear", "tomahawk", "atlatl"):
            p = g["profiles"][w]
            self.assertEqual(p["weapon-base"], "anim-overlay-player-weapon-base-pick-up", w)
            self.assertEqual(p["weapon-sub-type"], "anim-overlay-player-weapon-sub-type-brick", w)
            self.assertEqual(p["clip_set"], "throw", w)
            for st, base, up, down in (("stand", "actor_b-p-1h-aim-throw-idle", "actor_b-p-1h-aim-throw--add-up",
                                        "actor_b-p-1h-aim-throw--add-down"),
                                       ("crouch", "actor_b-p-1h-aim-crouch-throw-idle", "actor_b-p-1h-aim-throw-crouch--add-up",
                                        "actor_b-p-1h-aim-throw-crouch--add-down")):
                t = g["aim_trees"]["%s/%s" % (w, st)]
                self.assertEqual((t["base"]["clip"], t["up"]["clip"], t["down"]["clip"], t["hands"]["clip"]),
                                 (base, up, down, "actor_b-p-fingers-brick"), (w, st))
                am = g["aim_move"]["%s/%s" % (w, st)]
                prefix = "actor_b-p-1h-aim-walk-" if st == "stand" else "actor_b-p-1h-aim-crouch-walk-"
                self.assertEqual(am["fw"]["clip"], prefix + "fw", (w, st))
                self.assertEqual(am["up_fw"]["clip"], up, (w, st))   # brick sub-type: aim-run pitch = throw adds
                row = g["throw"]["rows"]["%s/%s" % (w, st)]["parts"]
                c = "" if st == "stand" else "crouch-"
                self.assertEqual(row["start"]["clip"], "actor_b-p-1h-aim-%sthrow-release-start" % c)
                self.assertEqual(row["end"]["clip"], "actor_b-p-1h-aim-%sthrow-release-end" % c)
                self.assertEqual(row["recover"]["clip"], "actor_b-p-1h-aim-%sthrow-release-end^idle" % c)
                self.assertEqual(row["raise"]["clip"], "actor_b-p-1h-aim-%sthrow^aim" % c)
                self.assertEqual(row["recover_aim"]["status"], "missing")
                self.assertIn("aim tree", row["recover_aim"]["reason"])
                self.assertNotIn("%s/%s" % (w, st), g["runtime_clips"]["fire"])
                for k in ("nock", "reload_begin", "reload_mid", "reload_end"):
                    self.assertNotIn("%s/%s/%s" % (w, st, k), g["actions"])
                d = g["actions"]["%s/%s/draw" % (w, st)]
                self.assertEqual((d["status"], d["frontier_key"]), ("frontier_pinned", "draw"))
                src = g["actions"][d["pinned_from"]]
                self.assertEqual((d["partial"], d["twin"]), (src["partial"], src["twin"]))
        # THROW2: the atlatl keeps the pick-up base's carry (the 1h carry arm, the brick grip); the spear and the
        # tomahawk carry their own (test_carry_overrides)
        self.assertEqual(g["grips"]["atlatl"]["carry"], "actor_b-p-fingers-brick")
        self.assertIn(("actor_b-p-1h-arm--part", 0.9), [(l["clip"], l["weight"]) for l in g["roles"]["atlatl/run/idle"]["layers"]])
        self.assertEqual(g["grips"]["spear"]["carry"], "actor_b-p-fingers-brick")
        self.assertEqual(g["actions"]["spear/stand/equip"]["partial"], "actor_b-lg-stealth-draw^idle--arm-r")
        self.assertEqual(g["actions"]["atlatl/stand/equip"]["partial"], "actor_b-p-stealth-draw-p^idle--arm-r")
        # The next one ("draw", a Frontier key) is each profile's own draw: the atlatl keeps its board in the right
        # hand (the bow's nock reach carried its prop bone to the bow hand; THROW review).
        for w in ("spear", "tomahawk", "atlatl"):
            for st in ("stand", "crouch"):
                self.assertEqual(g["actions"]["%s/%s/draw" % (w, st)]["pinned_from"], "%s/%s/equip" % (w, st))
        self.assertEqual(g["actions"]["atlatl/stand/draw"]["partial"], "actor_b-p-stealth-draw-p^idle--arm-r")
        # Graph-faithful wind-up by default (the aim-idle crossfade); the raise seeked by the charge is opt-in.
        self.assertIs(g["options"]["throw_windup_raise"], False)
        ov = g["gameplay_overrides"]["override_throw_windup_raise"]
        self.assertEqual((ov["default"], ov["sets_options"]), (False, {"throw_windup_raise": True}))
        self.assertEqual(g["throw"]["clip_sets"], {"throw": ["spear", "tomahawk", "atlatl"]})
        self.assertAlmostEqual(g["throw"]["release"]["clip_s"], 0.05)
        T = g["transitions"]
        for key, rec, fade, gate in (("throw_from_aimidle", "0x00037fb0", 0.2, None), ("throw_raise_to_start", "0x00038830", 0.0, 1.0),
                                     ("throw_start_to_end", "0x000386a0", 0.0, 1.0), ("throw_end_to_recover", "0x000220b0", 0.2, 0.8),
                                     ("throw_end_to_aim", "0x00022080", 0.2, 0.8), ("throw_end_auto_idle", "0x000221d0", 0.4, 0.9),
                                     ("throw_recover_auto_idle", "0x00032fa0", 0.4, 0.6), ("throw_recover_to_move", "0x00033000", 0.4, 0.1),
                                     ("throw_raise_from_aimrun", "0x000309f0", 0.6, None), ("throw_end_to_move", "0x00022230", 0.4, None)):
            self.assertEqual(T[key]["status"], "graph", key)
            self.assertEqual(T[key]["graph"]["record"], rec, key)
            self.assertAlmostEqual(T[key]["use"]["fade_s"], fade, 5, key)
            self.assertEqual(T[key]["use"].get("gate_phase") is not None and round(T[key]["use"]["gate_phase"], 5),
                             gate is not None and gate, key)

    def test_carry_overrides(self):
        """THROW2 (user playtest 2026-09-25): the spear's overhand javelin carry, the tomahawk's one-hand hatchet carry
        and its draw from the back of the belt (bindings.carry_overrides / action_overrides)."""
        g = self.g
        R = g["roles"]
        co = g["carry_overrides"]
        arm = ["r_clavicle", "r_scapula", "r_shoulder", "r_deltoid", "r_elbow", "r_wrist", "r_trap"]
        self.assertEqual({k: (p["clip"], p["sample_s"], p["slot"]) for k, p in co["poses"].items()},
                         {"javelin_carry": ("actor_b-p-1h-aim-throw^aim", 0.1, "arms"),
                          "javelin_carry_crouch": ("actor_b-p-1h-aim-throw^aim", 0.2, "arms"),
                          "knife_ready_arm": ("atk-actor_b-knife-v-thug-hit1-intro", 0.0, "arms"),
                          "melee_guard_arm": ("actor_b-p-melee-tell-idle--arms", 0.0, "arms"),
                          "melee_guard_crouch_fw_arm": ("actor_b-p-crouch-fw-melee-tell-idle--arms", 0.0, "arms"),
                          "knife_grip": ("atk-actor_b-knife-v-thug-hit1-intro", 0.0, "hands")})
        for p in co["poses"].values():
            self.assertRegex(p["native_asset_id"], r"^[0-9a-f]{64}$")
            self.assertEqual(p["native_asset_id"], g["clips"][p["clip"]]["native_asset_id"])

        def frontier(role, pose):
            return [l for l in role["layers"] if l["status"] == "frontier" and l["frontier"]["pose"] == pose]

        def arms(role):
            return [(l["clip"], l["weight"], l["status"]) for l in role["layers"] if l["slot"] == "arms"]
        # spear: the javelin carry replaces the 1h carry arm on every walk, run and crouch carry role and on the sprint
        # idle (the shared idle input); the sprint's moving roles keep the pick-up base's own sprint arm (graph layers,
        # no override: the port carry is the weapon's); air / landing roles keep no arm layer; the grip stays the brick
        # fingers
        for m in ("walk", "run", "sprint", "crouch"):
            for rk in ("idle", "fw", "bw_lt", "start_fw", "stop_bw", "rev_fw_bw"):
                role = R["spear/%s/%s" % (m, rk)]
                self.assertIn("actor_b-p-fingers-brick", [l["clip"] for l in role["layers"]], (m, rk))
                if m == "sprint" and rk != "idle":
                    self.assertEqual(arms(role), arms(R["atlatl/%s/%s" % (m, rk)]), (m, rk))
                    self.assertTrue(arms(role) and all(a[0] == "actor_b-p-1h-arm--part" and a[2] == "resolved" for a in arms(role)), (m, rk))
                    self.assertFalse(role.get("carry_override"), (m, rk))
                else:
                    self.assertNotIn("actor_b-p-1h-arm--part", [l["clip"] for l in role["layers"]], (m, rk))
                    pose = "javelin_carry_crouch" if m == "crouch" else "javelin_carry"
                    j = frontier(role, pose)
                    self.assertEqual(len(j), 1, (m, rk))
                    self.assertEqual(j[0]["bones"], arm)
                    self.assertEqual((j[0]["weight"], j[0]["sample_s"]), (1.0, 0.2) if m == "crouch" else (0.9, 0.1), (m, rk))
                    self.assertEqual((j[0]["set"], j[0]["record_offset"], j[0]["sources"]), (None, None, []))
                    self.assertTrue(role["carry_override"], (m, rk))
                    self.assertIn("actor_b-p-1h-arm--part", [x["clip"] for o in role["carry_override"] for x in o["replaced"]])
        for rk in ("fall", "jump", "land_soft_idle"):
            self.assertEqual(arms(R["spear/run/%s" % rk]), [])
        # tomahawk: the machete carry arm (graph records; relaxed walk / run targets substituted by the same arm) then
        # the knife ready arm at 0.6 (sprinting, but for the idle: 1.0); crouched the knife ready arm and the melee guard
        # arm at 0.6 (and, moving, the crouch-walk guard at 0.4); the knife grip in place of the brick fingers on every
        # role
        for m in ("walk", "run", "sprint", "crouch"):
            for rk, w_arm in (("idle", 0.7), ("fw", 0.6), ("bw", 0.6), ("start_fw", 0.6), ("stop_fw", 0.6), ("turn_l", 0.7)):
                if m == "sprint" and rk == "turn_l":
                    continue    # the sprint turns carry no weapon-base arm layer (graph): nothing to replace
                role = R["tomahawk/%s/%s" % (m, rk)]
                a = arms(role)
                if m == "crouch":
                    poses = [("atk-actor_b-knife-v-thug-hit1-intro", 0.6), ("actor_b-p-melee-tell-idle--arms", 0.6)]
                    if rk not in ("idle", "turn_l"):
                        poses.append(("actor_b-p-crouch-fw-melee-tell-idle--arms", 0.4))
                else:
                    poses = [("atk-actor_b-knife-v-thug-hit1-intro", 1.0 if m == "sprint" and rk != "idle" else 0.6)]
                self.assertEqual([x[:2] for x in a], [("actor_b-p-knife--arm", w_arm)] + poses, (m, rk))
                graph = m in ("sprint", "crouch") and rk != "turn_l"
                self.assertEqual(a[0][2], "resolved" if graph else "substitute", (m, rk))
                ml = [l for l in role["layers"] if l["slot"] == "arms"][0]
                self.assertIn(ml["record_offset"], ("0x00016380", "0x00016448", "0x00016434", "0x00016394", "0x0001640c"), (m, rk))
                self.assertEqual([l["clip"] for l in role["layers"] if l["slot"] == "hands" and l["status"] == "frontier"],
                                 ["atk-actor_b-knife-v-thug-hit1-intro"], (m, rk))
                self.assertNotIn("actor_b-p-fingers-brick", [l["clip"] for l in role["layers"]], (m, rk))
        for rk in ("fall", "land_soft_run", "takeoff"):
            role = R["tomahawk/run/%s" % rk]
            self.assertEqual([(l["clip"], l["status"]) for l in role["layers"] if l["slot"] == "hands"],
                             [("atk-actor_b-knife-v-thug-hit1-intro", "frontier")], rk)
        grip = g["grips"]["tomahawk"]
        self.assertEqual((grip["carry"], grip["carry_sample_s"], len(grip["carry_bones"])), ("atk-actor_b-knife-v-thug-hit1-intro", 0.0, 21))
        self.assertEqual((grip["aim_stand"], grip["aim_crouch"]), ("actor_b-p-fingers-brick", "actor_b-p-fingers-brick"))
        self.assertTrue(R["tomahawk/run/fw"]["prop"]["full_weight"])
        # the tomahawk's draw: the graph's one-hand thrown-object draw from the small of the back, not the pistol draw
        A = g["actions"]
        for st in ("stand", "crouch"):
            for key, part, twin in (("equip", "actor_b-p-molotov-draw^idle--part", "actor_b-p-molotov-draw^idle--add"),
                                    ("holster", "actor_b-p-molotov-draw^idle--part", "actor_b-p-molotov-draw^idle--add"),
                                    ("holster_finish", "actor_b-p-molotov-draw^idle--part", "actor_b-p-molotov-draw^idle--add"),
                                    ("grab", "actor_b-p-molotov-idle^draw--part", "actor_b-p-molotov-idle^draw--add")):
                a = A["tomahawk/%s/%s" % (st, key)]
                self.assertEqual((a["partial"], a["twin"], a["status"]), (part, twin, "frontier_substitute"), (st, key))
                self.assertIn(a["replaced"]["partial"], ("actor_b-p-stealth-draw-p^idle--arm-r", "actor_b-p-stealth-stow-p^idle--arm-r",
                                                         "actor_b-p-crouch-idle^p-grab--arm-r"), (st, key))
                ch = a["substitute"]["partial"]["chain"]
                self.assertEqual([(c["set"], c["record_offset"]) for c in ch][-1][0], "anim-overlay-player-actor_b-actor_b")
            self.assertEqual(A["tomahawk/%s/holster" % st]["start_phase"], 1.0)
            d = A["tomahawk/%s/draw" % st]
            self.assertEqual((d["status"], d["partial"], d["pinned_from"]), ("frontier_pinned", "actor_b-p-molotov-draw^idle--part",
                                                                             "tomahawk/%s/equip" % st))
        self.assertEqual(A["tomahawk/stand/equip"]["substitute"]["partial"]["chain"][-1]["record_offset"], "0x0000056c")
        # the throw chain, aim trees and the other weapons are untouched
        for w in ("spear", "tomahawk"):
            self.assertEqual(g["aim_trees"][w + "/stand"]["hands"]["clip"], "actor_b-p-fingers-brick")
            self.assertEqual(g["throw"]["rows"][w + "/stand"]["parts"]["recover"]["clip"], "actor_b-p-1h-aim-throw-release-end^idle")
        for w in ("bow", "musket", "pistol", "atlatl"):
            self.assertFalse(any(r.get("carry_override") for k, r in R.items() if k.startswith(w + "/")), w)
            self.assertFalse(any(l["status"] in ("frontier", "substitute") for k, r in R.items() if k.startswith(w + "/")
                                 for l in r["layers"]), w)
        rows = {r["row"]: r for r in co["rows"]["spear"]}
        self.assertEqual((rows["spear[1]"]["modes"], rows["spear[1]"]["roles_only"], rows["spear[1]"]["roles"]), (["sprint"], ["idle"], 1))
        self.assertIsNone(rows["spear[0]"]["roles_only"])
        rep = read_text(REPORT)
        self.assertIn("## Frontier carry overrides (THROW2)", rep)
        self.assertIn("sprint (only idle)", rep)
        self.assertIn("## Frontier action clip substitutions (THROW2)", rep)
        # a hands pose that masks a bone outside the hand, or a bone its clip does not key, fails the build (once)
        B = base_bindings()
        B["carry_overrides"]["poses"]["knife_grip"]["bones"] = B["carry_overrides"]["poses"]["knife_grip"]["bones"] + ["l_knee"]
        B["carry_overrides"]["poses"]["javelin_carry"]["bones"] = B["carry_overrides"]["poses"]["javelin_carry"]["bones"] + ["r_palm"]
        g2, err = build(B)
        self.assertIsNone(g2)
        self.assertEqual(err.count("carry_overrides.poses.knife_grip: slot hands but masks ['l_knee']"), 1, err[:400])
        self.assertIn("carry_overrides.poses.javelin_carry: actor_b-p-1h-aim-throw^aim does not key ['r_palm']", err)

    def test_report(self):
        rep = read_text(REPORT)
        for flag in self.g["gameplay_overrides"]:
            self.assertIn(flag, rep)
        for k, t in self.g["transitions"].items():
            if t["status"] != "graph":
                self.assertIn("`%s`" % k, rep)
        weapons = {r["weapon"] for r in self.g["frontier"]["relaxed_table_diff"]}
        self.assertEqual(weapons, {"bow", "musket", "pistol"})
        self.assertIn("Weapon.relaxed vs graph carry layers", rep)
        self.assertIn("## Resolver disagreements", rep)
        self.assertIn("crouch-crouch 0x0001ba58", rep)
        self.assertIn("## Transition variants (per record)", rep)
        self.assertIn("## Weapon layers and prop bones", rep)
        self.assertIn("## Landing selection (proposed)", rep)
        self.assertIn("land_medium_run_bw (fall-land-medium-run-bw: actor_b-p-land-med^run-bw)", rep)
        self.assertIn("Resolver exceptions", rep)
        self.assertIn("hand_states.musket/crouch.weapon_out", rep)
        self.assertNotIn("code-requested", rep)
        # every tuning value is listed with its status (none is a graph record)
        self.assertIn("## Tuning (no graph record)", rep)
        for k in self.g["tuning"]:
            n = self.g["tuning_notes"][k]
            self.assertIn(n["status"], ("proposed", "approximation", "frontier"), k)
            self.assertIn("- `%s` = " % k, rep)
        self.assertEqual(self.g["tuning_notes"]["carry_join_s"]["status"], "approximation")


if __name__ == "__main__":
    unittest.main()
