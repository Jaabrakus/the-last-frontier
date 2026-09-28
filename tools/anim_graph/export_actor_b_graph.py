#!/usr/bin/env python3
"""Export the Actor_B player animation graph into Frontier's runtime tables.

    python3 tools/anim_graph/export_actor_b_graph.py [--pap <PAP>] [--out animations/actor_b_graph.json]
                                                     [--report animations/actor_b_graph_report.md]
                                                     [--fixture tools/anim_graph/fixtures/mini_graph.json] [--check]

Reads (never writes) the extracted graph in Player_Animation_Project (PAP):
  player_blending/player_blending.json, blender_animation_index.csv,
  graph_analysis/graph/{state_subgraph.json, movement_modes_actor_b.json, actor_b_library_dump.json}
plus tools/anim_graph/frontier_bindings.json and the Weapon.relaxed / Weapon.clips tables of
scripts/weapons/{bow,musket,pistol}.gd (for the report's Frontier comparison only).

Resolution follows the verified overlay semantics: 32-bit IDs only (never re-hashed from names),
ascending layer priority with repeated passes until the ID is stable (asc_fix, vendored
resolve_overlays.py), clip-keyed layer records on the source, every intermediate and the final ID,
state-keyed layer records chosen by flag (byte1 & 0x02), '00 02' state records treated as state-level
substitutions, layer weights from the raw_0x0c script lambda (vendored symvm.py).

Fidelity policy: graph-authored behaviour is the default everywhere; gameplay deviations are listed
in `gameplay_overrides` and are opt-in.

--check rebuilds everything in memory, runs the structural assertions and exits non-zero unless the
committed output files are byte-identical to the rebuild.

Python 3.9, standard library only.
"""
from __future__ import annotations

import argparse
import collections
import copy
import csv
import fnmatch
import hashlib
import json
import os
import re
import struct
import sys

sys.dont_write_bytecode = True  # keep vendor/ free of __pycache__ inside the Godot project tree

HERE = os.path.dirname(os.path.abspath(__file__))
FR_ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
VENDOR = os.path.join(HERE, "vendor")
DEFAULT_PAP = "/Users/kiwimango/Downloads/Player_Animation_Project"

GENERATOR = "tools/anim_graph/export_actor_b_graph.py"
SCHEMA_VERSION = 1
AUTHORIZATION = ("owner-stated; see Player_Animation_Project/ASSET_AUTHORIZATION.md; "
                 "granting party and terms not on file")
NULL_TARGETS = ("null", "null-add", "null-add-base", "bindpose-anim")
SCRIPT_GRID_NOTE = ("script blend grid (runtime clip array int32[info+300+12+i*12+4], weight f32@C8+16); "
                    "not used by Frontier (C8+16 = 0)")
CURVE_SAMPLES = 17
TUNING_STATUS = ("proposed", "approximation", "frontier")  # bindings.tuning_notes[k].status
HANDS_BONE_MAX = 42
LOOPS = ("asc_fix", "asc_once")  # overlay loops of the vendored resolve_overlays.py; bindings.resolver_policy picks one
KEYED_BONES = os.path.join(HERE, "actor_b_keyed_bones.json")
CROUCH_CHANGE_STATE = "crouch-change-idle^idle"
HAND_BONE_RE = re.compile(r"(palm|thumb|index|middle|ring|pinky|prop_attachment)")
ARM_BONE_RE = re.compile(r"(clavicle|scapula|shoulder|deltoid|elbow|wrist|trap|forarm)")
LEG_BONE_RE = re.compile(r"(pelvis|upper_leg|knee|ankle|heel|ball)")


class ExportError(Exception):
    pass


# --------------------------------------------------------------------------- small helpers
def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_bytes(b):
    return hashlib.sha256(b).hexdigest()


def rnd(v, nd=6):
    if v is None:
        return None
    r = round(float(v), nd)
    if r == 0:
        r = 0.0
    if r == int(r) and abs(r) < 1e15:
        return float(int(r))
    return r


def f32hex(h):
    return struct.unpack(">f", bytes.fromhex(h))[0]


def norm_floats(o):
    """Round every float to 6 decimals (deterministic output)."""
    if isinstance(o, float):
        return rnd(o)
    if isinstance(o, dict):
        return {k: norm_floats(v) for k, v in o.items()}
    if isinstance(o, (list, tuple)):
        return [norm_floats(v) for v in o]
    return o


def dumps(obj):
    return json.dumps(norm_floats(obj), sort_keys=True, indent=1, ensure_ascii=False) + "\n"


def glob_match(key, patterns):
    return any(fnmatch.fnmatchcase(key, p) for p in patterns)


# --------------------------------------------------------------------------- exporter
class Exporter:
    def __init__(self, pap, bindings_path=None):
        self.pap = os.path.abspath(pap)
        self.ga = os.path.join(self.pap, "graph_analysis", "graph")
        self.paths = {
            "PAP/player_blending/player_blending.json": os.path.join(self.pap, "player_blending", "player_blending.json"),
            "PAP/blender_animation_index.csv": os.path.join(self.pap, "blender_animation_index.csv"),
            "PAP/graph_analysis/graph/state_subgraph.json": os.path.join(self.ga, "state_subgraph.json"),
            "PAP/graph_analysis/graph/movement_modes_actor_b.json": os.path.join(self.ga, "movement_modes_actor_b.json"),
            "PAP/graph_analysis/graph/actor_b_library_dump.json": os.path.join(self.ga, "actor_b_library_dump.json"),
            "FR/tools/anim_graph/frontier_bindings.json": bindings_path or os.path.join(HERE, "frontier_bindings.json"),
            "FR/tools/anim_graph/actor_b_keyed_bones.json": KEYED_BONES,
        }
        for k, p in self.paths.items():
            if not os.path.exists(p):
                raise ExportError(f"missing input {k}: {p}")
        self.warnings = []
        self.errors = []
        self._warned = set()
        self._load()

    # ------------------------------------------------------------------ loading
    throw_rows = None

    def warn(self, msg):
        if msg not in self._warned:
            self._warned.add(msg)
            self.warnings.append(msg)

    def _load(self):
        os.environ["ANIM_GRAPH_PAP"] = self.pap
        if VENDOR not in sys.path:
            sys.path.insert(0, VENDOR)
        import resolve_overlays  # noqa: E402  (vendored, path-shimmed)
        import symvm  # noqa: E402
        import decode_lambda  # noqa: E402
        self.symvm = symvm
        self.decode_lambda = decode_lambda
        self.db = resolve_overlays.OverlayDB(self.paths["PAP/player_blending/player_blending.json"],
                                             self.paths["PAP/blender_animation_index.csv"])
        d = self.db.d
        self.D = d
        self.N = d["nodes"]
        self.F = d["functions"]
        self.states_by_name = {}
        for s in d["states"]:
            self.states_by_name.setdefault(s["name"], s)
        self.entry_by_offset = {}
        for sn, s in self.db.sets.items():
            for r in s["remaps"]:
                self.entry_by_offset[(sn, r["offset"])] = r
        self.set_source = {sn: s["source"] for sn, s in self.db.sets.items()}
        with open(self.paths["FR/tools/anim_graph/frontier_bindings.json"]) as fh:
            self.B = json.load(fh)
        pol = self.B.get("resolver_policy") or {}
        self.resolver = pol.get("loop")
        self.resolver_compare = pol.get("compare")
        if self.resolver not in LOOPS or self.resolver_compare not in LOOPS or self.resolver == self.resolver_compare:
            raise ExportError(f"bindings.resolver_policy must name two different loops of {LOOPS}: "
                              f"loop={self.resolver!r} compare={self.resolver_compare!r}")
        with open(self.paths["PAP/graph_analysis/graph/state_subgraph.json"]) as fh:
            self.subgraph = json.load(fh)
        with open(self.paths["PAP/graph_analysis/graph/movement_modes_actor_b.json"]) as fh:
            self.mm = json.load(fh)
        with open(self.paths["PAP/graph_analysis/graph/actor_b_library_dump.json"]) as fh:
            dump = json.load(fh)
        self.lib = {x["name"]: x for x in dump}
        # alias table: graph name -> set(action names)
        self.index_rows = []
        with open(self.paths["PAP/blender_animation_index.csv"]) as fh:
            for row in csv.DictReader(fh):
                if row["character"] == "Actor_B":
                    self.index_rows.append(row)
        self.alias = collections.defaultdict(set)
        for row in self.index_rows:
            self.alias[row["original_name"]].add(row["action_name"])
        for name, x in self.lib.items():
            sn = (x.get("meta") or {}).get("source_names")
            if sn:
                for o in json.loads(sn):
                    self.alias[o].add(name)
        self.clips = {}
        self.clip_graph_names = collections.defaultdict(set)
        with open(self.paths["FR/tools/anim_graph/actor_b_keyed_bones.json"]) as fh:
            kb = json.load(fh)
        self.kb_bones = kb["bones"]
        self.kb_masks = kb["clips"]
        self.kb_library_sha = kb.get("library_sha256")
        self._kb_cache = {}
        self.resolver_disagreements = []
        self.resolver_exceptions = []
        self.prop_exempt_dynamic = {}
        self._choices_hit = set()
        self.slot_notes = {}

    # ------------------------------------------------------------------ keyed bones
    def keyed_bones(self, action):
        """Skeleton bones keyed by an actor_b clip (tools/anim_graph/actor_b_keyed_bones.json, from Godot)."""
        if action not in self._kb_cache:
            m = self.kb_masks.get(action)
            if m is None:
                raise ExportError(f"clip {action} not in actor_b_keyed_bones.json; rerun "
                                  "Godot --headless --path . -s tools/anim_graph/dump_keyed_bones.gd")
            out = set()
            for j, ch in enumerate(m):
                v = int(ch, 16)
                for k in range(4):
                    if (v >> k) & 1:
                        out.add(self.kb_bones[4 * j + k])
            self._kb_cache[action] = frozenset(out)
        return self._kb_cache[action]

    def check_slot(self, action, slot):
        """Validate the name/bone-count slot against the clip's real keyed bones. Returns a note or None."""
        kb = self.keyed_bones(action)
        hand = {b for b in kb if HAND_BONE_RE.search(b)}
        arm = {b for b in kb if ARM_BONE_RE.search(b) or b.endswith("_offset")}
        legs = {b for b in kb if LEG_BONE_RE.search(b)}
        note = None
        if slot == "hands":
            if kb - hand:
                self.errors.append(f"slot: {action} is 'hands' but keys {sorted(kb - hand)}")
        elif slot in ("arms", "other_partial"):
            if kb and kb <= hand:
                self.errors.append(f"slot: {action} is '{slot}' but keys only palm/finger/prop bones")
            extra = kb - hand - arm
            if slot == "arms" and extra:
                note = "also keys %s (outside the arm/hand bones)" % ", ".join(sorted(extra))
        elif slot == "full_body":
            if not legs:
                self.errors.append(f"slot: {action} is 'full_body' but keys no leg bone")
        if note:
            self.slot_notes[action] = note
        return note

    def prop_bones_keyed(self, action):
        return sorted(b for b in self.keyed_bones(action) if b.endswith("hand_prop_attachment"))

    # ------------------------------------------------------------------ names and clips
    def godot_action(self, graph_name):
        """Resolved graph name -> (action_name or None, alternatives list)."""
        acts = sorted(a for a in self.alias.get(graph_name, ()) if a in self.lib)
        if not acts:
            return None, []
        if len(acts) == 1:
            return acts[0], []
        pick = graph_name if graph_name in acts else acts[0]
        alts = [a for a in acts if a != pick]
        self.warn(f"alias: '{graph_name}' maps to {len(acts)} actions {acts}; picked '{pick}' "
                  f"(action_name == original_name first, else lexicographic)")
        return pick, alts

    def clip_ref(self, action, graph_name=None, alternatives=None):
        x = self.lib.get(action)
        if x is None:
            raise ExportError(f"clip {action} not in actor_b library dump")
        meta = x.get("meta") or {}
        if action not in self.clips:
            self.clips[action] = {
                "godot": "actor_b/" + action,
                "original_name": meta.get("original_name", action),
                "native_asset_id": meta.get("native_asset_id"),
                "source_library": meta.get("source_library"),
                "source_kind": meta.get("source_kind"),
                "length": rnd(x["length"]),
                "additive": bool(meta.get("additive_source", False)),
                "bone_count": x["bone_count"],
                "track_count": x["track_count"],
                "sample_rate": rnd(meta.get("sample_rate")) if meta.get("sample_rate") is not None else None,
                "sample_count": int(meta["sample_count"]) if meta.get("sample_count") is not None else None,
                "source_names": sorted(json.loads(meta["source_names"])) if meta.get("source_names") else [],
                "alternatives": [],
                "graph_names": [],
            }
        if alternatives:
            cur = set(self.clips[action]["alternatives"]) | set(alternatives)
            self.clips[action]["alternatives"] = sorted(cur)
        if graph_name and graph_name != action:
            self.clip_graph_names[action].add(graph_name)
        return action

    def is_additive(self, action):
        return bool((self.lib[action].get("meta") or {}).get("additive_source", False))

    def slot_of(self, action):
        """Layer slot from name, additive flag and bone count; check_slot() then validates it against the
        clip's real keyed bones (actor_b_keyed_bones.json)."""
        x = self.lib[action]
        add = self.is_additive(action)
        bc = x["bone_count"]
        n = action
        if not add and bc <= HANDS_BONE_MAX and re.search(r"(hands|fingers|-hand-)", n):
            return "hands"
        if add:
            if "spine" in n:
                return "spine_add"
            if re.search(r"(arm|hand-gun)", n):
                return "arms_add"
            return "other_add"
        if bc >= 90:
            return "full_body"
        if re.search(r"(arm|--part|-part|--bow|--rifle)", n):
            return "arms"
        return "other_partial"

    # ------------------------------------------------------------------ lambdas
    def fn_id(self, ptr, set_name=None):
        if not ptr or ptr == "0x00000000":
            return None
        cands = []
        if set_name:
            ns = self.set_source[set_name].replace(".bin", "")
            cands.append(ns + ":" + ptr)
        cands += ["player-overlays:" + ptr, "player-anim-settings:" + ptr, "anim-player:" + ptr]
        for c in cands:
            if c in self.F:
                return c
        return None

    def lambda_paths(self, fid):
        res, loads = self.symvm.run(fid)
        return [(conds, expr) for conds, expr in res], loads

    def ast_json(self, e):
        t = e[0]
        if t == "c":
            return {"const": rnd(e[1])}
        if t == "arg":
            return {"arg": e[1]}
        if t in ("+", "*"):
            return {"op": t, "args": [self.ast_json(e[1]), self.ast_json(e[2])]}
        if t == "call":
            return {"op": e[1], "args": [self.ast_json(a) for a in e[2]]}
        if t == "un":
            return {"op": e[1], "args": [self.ast_json(e[2])]}
        if t == "bin":
            return {"op": e[1], "args": [self.ast_json(e[2]), self.ast_json(e[3])]}
        return {"expr": self.symvm.fmt(e)}

    def ast_eval(self, e, x):
        t = e[0]
        if t == "c":
            return float(e[1])
        if t == "arg":
            if e[1] != 1:
                raise ExportError("weight lambda reads arg%d" % e[1])
            return x
        if t == "+":
            return self.ast_eval(e[1], x) + self.ast_eval(e[2], x)
        if t == "*":
            return self.ast_eval(e[1], x) * self.ast_eval(e[2], x)
        if t == "un" and e[1] == "neg":
            return -self.ast_eval(e[2], x)
        if t == "call":
            a = [self.ast_eval(v, x) for v in e[2]]
            if e[1] == "lerp-scale":
                lo, hi, o0, o1, v = a
                u = 0.0 if hi == lo else (v - lo) / (hi - lo)
                u = min(1.0, max(0.0, u))
                return o0 + (o1 - o0) * u
            if e[1] == "make-curve":
                v, k = a
                if int(k) != 4:
                    raise ExportError("make-curve kind %s not modelled" % k)
                v = min(1.0, max(0.0, v))
                return v * v * (3.0 - 2.0 * v)
            if e[1] == "minmax":
                v, lo, hi = a
                return min(hi, max(lo, v))
        raise ExportError("cannot evaluate lambda expression %s" % self.symvm.fmt(e))

    def weight_info(self, entry_ptr, set_name, ctx):
        fid = self.fn_id(entry_ptr, set_name)
        if fid is None:
            if entry_ptr and entry_ptr != "0x00000000":
                self.warn(f"layer weight lambda {entry_ptr} ({set_name}) not found; default 1.0")
            return {"weight": 1.0, "weight_source": "default (inferred: no lambda)", "weight_curve": None,
                    "weight_expr": None, "weight_tree": None, "lambda": None}
        paths, loads = self.lambda_paths(fid)
        if len(paths) != 1 or paths[0][0]:
            raise ExportError(f"branched layer weight lambda {fid}")
        expr = paths[0][1]
        text = self.symvm.fmt(expr)
        uses_arg = "arg1" in text
        if not uses_arg:
            w = self.ast_eval(expr, 0.0)
            src = "lambda const"
            if w > 1.0:
                self.warn(f"layer weight {w} from {fid} clamped to 1.0 ({ctx})")
                w = 1.0
                src = "lambda const (clamped from %s)" % rnd(self.ast_eval(expr, 0.0))
            return {"weight": w, "weight_source": src, "weight_curve": None, "weight_expr": text,
                    "weight_tree": self.ast_json(expr), "lambda": fid}
        curve = [self.ast_eval(expr, i / (CURVE_SAMPLES - 1.0)) for i in range(CURVE_SAMPLES)]
        mean = sum(curve) / len(curve)
        return {"weight": mean, "weight_source": "lambda curve of arg1 (phase 0..1); weight = curve mean; "
                                                  "make-curve 4 = smoothstep (INFERRED)",
                "weight_curve": curve, "weight_expr": text, "weight_tree": self.ast_json(expr), "lambda": fid}

    def lambda_text(self, fid):
        if not fid or fid not in self.F:
            return None
        paths, _ = self.lambda_paths(fid)
        out = []
        for conds, e in paths:
            c = " & ".join(conds)
            out.append(("IF %s => " % c if c else "") + self.symvm.fmt(e))
        return out

    # ------------------------------------------------------------------ selections
    def mode_record(self, mode_key):
        spec = self.B["modes"][mode_key]
        for m in self.D["movement_modes"]:
            if m["character"] == "Actor_B" and m["offset"] == spec["mode_record"]:
                if m["name"] != spec["mode"]:
                    raise ExportError(f"mode record {spec['mode_record']} is '{m['name']}', expected '{spec['mode']}'")
                raw = {x["relative_offset"]: x for x in m["raw"]}
                ov = raw["0x00000040"]
                return {
                    "name": m["name"], "record": m["offset"], "source": m["source"],
                    "overlay": m["overlay"], "overlay_id": ov["hex"],
                    "crouch": int(raw["0x00000080"]["hex"], 16) == 1,
                    "sprint": int(raw["0x00000084"]["hex"], 16) == 1,
                    "speed_0x10": f32hex(raw["0x00000010"]["hex"]),
                    "speed_0x0c": f32hex(raw["0x0000000c"]["hex"]),
                    "transition_set": m.get("transition_set"),
                }
        raise ExportError(f"mode record {spec['mode_record']} not found")

    def selection(self, weapon, mode_key, extra=None):
        mr = self.mode_record(mode_key)
        sel = {"actor_b": self.B["actor_b_overlay"]}
        if mr["overlay"] in self.db.sets:
            sel["move"] = mr["overlay"]
        else:
            self.warn(f"mode {mode_key}: move overlay {mr['overlay']} not extracted")
        if mr["crouch"]:
            sel["crouch"] = self.B["crouch_overlay"]
        prof = self.B["profiles"][weapon]
        for layer in ("weapon-base", "weapon-sub-type", "weapon-draw-holster"):
            if prof.get(layer):
                sel[layer] = prof[layer]
        for layer, sn in (extra or {}).items():
            sel[layer] = sn
        for layer, sn in sel.items():
            if sn not in self.db.sets:
                raise ExportError(f"overlay set {sn} missing")
            if self.db.set_layer[sn] != layer:
                raise ExportError(f"overlay set {sn} is layer {self.db.set_layer[sn]}, not {layer}")
        return sel

    def ordered(self, sel):
        return sorted(sel.items(), key=lambda kv: self.db.priority[kv[0]])

    # ------------------------------------------------------------------ graph states and trees
    def state(self, name):
        s = self.states_by_name.get(name)
        if s is None:
            raise ExportError(f"state {name} not in graph")
        return s

    def state_name_id(self, s):
        for x in s["raw"]:
            if x["interpretation"] == s["name"]:
                return x["hex"]
        return None

    def tree_leaves(self, nid, out=None):
        if out is None:
            out = []
        n = self.N.get(nid)
        if n is None:
            return out
        if n["type"] == "anim-node-animation":
            out.append(n)
        else:
            self.tree_leaves(n["left"], out)
            self.tree_leaves(n["right"], out)
        return out

    def find_leaf(self, state_name, leaf_name):
        s = self.state(state_name)
        hits = [n for n in self.tree_leaves(s["tree"]) if n["clip"] == leaf_name]
        if not hits:
            raise ExportError(f"leaf {leaf_name} not in state {state_name}")
        ids = {n["id"] for n in hits}
        if len(ids) > 1:
            raise ExportError(f"leaf {leaf_name} ambiguous in state {state_name}")
        return hits[0]

    def leaf_parent_weight(self, state_name, leaf_node):
        """Weight lambda of the blend node whose right child is this leaf (None for left-most)."""
        s = self.state(state_name)
        stack = [s["tree"]]
        while stack:
            nid = stack.pop()
            n = self.N.get(nid)
            if not n or n["type"] != "anim-node-blend":
                continue
            if n["right"] == leaf_node["id"]:
                wid = n.get("weight_callback")
                return {"node": nid, "lambda": wid, "expr": self.lambda_text(wid)}
            stack += [n["left"], n["right"]]
        return None

    def describe_tree(self, nid, out):
        n = self.N.get(nid)
        if n is None:
            out.append({"node": nid, "kind": "missing"})
            return
        if n["type"] == "anim-node-animation":
            leaf = {"node": nid, "kind": "clip", "clip": n["clip"], "clip_id": n["clip_id"]}
            if n.get("callback"):
                leaf["clip_callback"] = n["callback"]
                leaf["clip_callback_expr"] = self.lambda_text(n["callback"])
            pf = n.get("raw_flags")
            if pf and pf != "0x00000000":
                fid = "anim-player:" + pf
                leaf["phase_lambda"] = fid
                leaf["phase_expr"] = self.lambda_text(fid) if fid in self.F else None
            out.append(leaf)
            return
        mode = n["raw_mode_bytes"].split()[0]
        if int(mode, 16) & 0x40:
            out.append({"node": nid, "kind": "script_grid", "mode_byte": mode, "note": SCRIPT_GRID_NOTE})
            return
        wid = n.get("weight_callback")
        out.append({"node": nid, "kind": "blend", "mode_byte": mode, "raw_0x18": n["raw_0x18"],
                    "scalar_0x14": n["scalar_0x14"], "weight_lambda": wid,
                    "weight_expr": self.lambda_text(wid), "left": n["left"], "right": n["right"]})
        self.describe_tree(n["left"], out)
        self.describe_tree(n["right"], out)

    # condition / transition decoding (mirrors vendored build_subgraph.conds / godot_expr)
    def godot_expr(self, fid):
        s = self.decode_lambda.summarize(fid)
        rep = {'float32[(pointer32[arg0] + 120)]': 'move_speed', 'float32[(pointer32[arg0] + 124)]': 'turn_delta_deg',
               'int32[(pointer32[arg0] + 128)]': 'use_transition_anims', 'int32[(pointer32[arg0] + 132)]': 'loco_enabled',
               'int32[(pointer32[arg0] + 136)]': 'crouch_change_pending', 'int32[(pointer32[arg0] + 140)]': 'aim_flag_140',
               'float32[(pointer32[arg0] + 144)]': 'move_dir_deg', 'float32[(pointer32[arg0] + 148)]': 'cover_side',
               'float32[(pointer32[arg0] + 152)]': 'cover_f152', 'float32[(pointer32[arg0] + 160)]': 'idle_turn_deg'}
        for k, v in rep.items():
            s = s.replace(k, v)
        toks = re.findall(r'(AND|ORSKIP|RET)\[(.*?)\](?= AND| ORSKIP| RET|$)', s)
        if s.startswith('RET '):
            e = s[4:]
        elif toks:
            terms = []
            for kind, x in toks:
                if kind == 'AND':
                    terms.append(x)
                elif kind == 'ORSKIP':
                    if x.strip() == 'not(0)':
                        terms.append('true')
                        break
                elif kind == 'RET':
                    terms.append(x)
            e = ' and '.join(t for t in terms if t != 'true') or 'true'
        else:
            e = s
        e = e.replace('abs(', 'absf(').replace('not(', 'not (')
        return e

    def decode_conditions(self, t):
        out = []
        for i, c in enumerate(t["conditions"]):
            r = [x["hex"] for x in c["raw"]]
            k = int(r[0], 16)
            lo = f32hex(r[1])
            hi = f32hex(r[2])
            d = {"index": i, "record_offset": c["offset"], "type": c["type"], "mode": k,
                 "min": lo if k & 2 else None, "max": hi if k & 1 else None}
            vals = [v for v in (d["min"], d["max"]) if v is not None]
            over_one = any(abs(v) > 1.0 for v in vals)
            if len(r) > 3:
                # graph_understanding.json correction 9: thresholds of 10/20/40 occur with lambda flags 0x1 and
                # without any selector word, so the upper half of the flags word does not select the variable or
                # unit. The unit follows the value (first condition > 1 -> frames), as for 3-word conditions;
                # only selector 6 (the L/R 180-turn pick, value 0.5) keeps its own reading.
                d["flags_word"] = r[3]
                sel = int(r[3], 16) >> 16
                if sel == 6:
                    d["variable"] = "unknown selector 6 (picks L vs R 180 turn)"
                elif i == 0 and over_one:
                    d["variable"] = "frames? (first condition, value > 1; INFERRED)"
                    if sel != 1:
                        d["variable_alternative"] = (
                            "phase (flags word %s read as selector %d): phase >= %g could never fire, so the "
                            "record would be dead; not used (graph_understanding correction 9)" % (r[3], sel, vals[0]))
                elif i == 0:
                    d["variable"] = "phase (normalized 0..1)"
                else:
                    d["variable"] = "secondary variable (INFERRED: e.g. move-direction degrees on land->run)"
            else:
                d["variable"] = ("phase (normalized 0..1)" if i == 0 and not over_one
                                 else ("frames? (first condition, value > 1; INFERRED)" if i == 0 else
                                       "secondary variable (INFERRED: e.g. move-direction degrees on land->run)"))
            if c.get("callback"):
                d["lambda"] = c["callback"]
                d["expr"] = self.godot_expr(c["callback"])
            out.append(d)
        return out

    def condition_text(self, conds):
        parts = []
        for c in conds:
            p = []
            if c["min"] is not None:
                p.append(">= %g" % rnd(c["min"], 4))
            if c["max"] is not None:
                p.append("<= %g" % rnd(c["max"], 4))
            if p:
                parts.append("%s %s" % (c["variable"].split(" (")[0], " & ".join(p)))
            if c.get("expr"):
                parts.append(c["expr"])
        return " AND ".join(parts) if parts else "always"

    def decode_transition(self, t, order):
        rw = [x["hex"] for x in t["raw"]]
        conds = self.decode_conditions(t)
        return {
            "record": t["offset"], "order": order, "request": t["request"], "target": t["target"],
            "fade_s": t["scalar_0x1c"], "scalar_0x20": t["scalar_0x20"],
            "start_phase_0x24": f32hex(rw[9]) if rw[9] != "00000000" else None,
            "flags_0x04": rw[1], "byte_0x28": rw[10][:2], "conditions": conds,
            "condition_text": self.condition_text(conds),
        }

    def record_use(self, t):
        """Numeric runtime values of one transition record: its fade and the thresholds of its conditions.
        first condition <= 1 -> phase: gate_phase (min > 0 only); first condition > 1 -> frames, whatever the flags
        word says (graph_understanding correction 9): gate_frames and gate_s = frames / fps (INFERRED unit);
        selector 6 -> selector6_*; later conditions -> secondary_*."""
        fps = self.B["gates"]["land_move_gate"]["fps"]
        use = {"fade_s": t["fade_s"]}
        for c in t["conditions"]:
            var = c["variable"]
            lo, hi = c["min"], c["max"]
            if var.startswith("phase"):
                if lo is not None and lo > 0:
                    use["gate_phase"] = lo
                if hi is not None:
                    use["gate_phase_max"] = hi
            elif var.startswith("frames"):
                if lo is not None:
                    use["gate_frames"] = lo
                    use["gate_s"] = lo / fps
                    use["gate_basis"] = ("first condition, value > 1 (flags word %s; correction 9: the flags word "
                                         "does not select the unit); frames at %g Hz INFERRED" % (c["flags_word"], fps)
                                         if c.get("flags_word") else
                                         "first condition, value > 1, no selector word; frames at %g Hz INFERRED" % fps)
                if hi is not None:
                    use["gate_frames_max"] = hi
                if c.get("variable_alternative"):
                    use["gate_alternative"] = c["variable_alternative"]
            elif var.startswith("unknown selector 6"):
                if lo is not None:
                    use["selector6_min"] = lo
                if hi is not None:
                    use["selector6_max"] = hi
            else:
                if lo is not None:
                    use["secondary_min"] = lo
                if hi is not None:
                    use["secondary_max"] = hi
        return use

    def graph_state(self, name, group):
        s = self.state(name)
        cb = {}
        for k, v in sorted(s["callbacks"].items()):
            role = {"0x00000024": "start_phase_cb", "0x00000028": "phase_update_cb", "0x0000002c": "int_flag_cb"}.get(k, k)
            cb[role] = {"id": v, "expr": self.lambda_text(v)}
        nodes = []
        if s.get("tree"):
            self.describe_tree(s["tree"], nodes)
        trans = [self.decode_transition(t, i) for i, t in enumerate(s["transitions"])]
        incoming = sum(1 for x in self.D["states"] for t in x["transitions"] if t["target"] == name and x["name"] != name)
        loop = any(t["request"] == "auto" and t["target"] == name and t["fade_s"] == 0.0 and
                   len(t["conditions"]) == 1 and t["conditions"][0]["min"] is not None and
                   abs(t["conditions"][0]["min"] - 1.0) < 1e-6 and t["conditions"][0]["max"] is None and
                   not t["conditions"][0].get("lambda") for t in trans)
        return {"state_offset": s["offset"], "state_name_id": self.state_name_id(s), "record_kind": s["record_kind"],
                "tree": s.get("tree"), "reference_clip": s.get("reference_clip"), "category": s.get("category"),
                "group": group, "callbacks": cb, "tree_nodes": nodes, "transitions": trans,
                "incoming_total": incoming, "loop": loop,
                "entered_by": "graph" if incoming else "code (no incoming transition record in the whole graph)"}

    # ------------------------------------------------------------------ resolution
    def resolve(self, leaf_id, sel, algorithm=None):
        r = self.db.resolve_id(leaf_id, sel, algorithm or self.resolver)
        if r.cycle:
            raise ExportError(f"resolver cycle on {leaf_id}")
        chain = []
        for st in r.steps:
            e = self.entry_by_offset[(st.set_name, st.offset)]
            chain.append({"layer": st.layer, "set": st.set_name, "record_offset": st.offset,
                          "from_id": e["from_id"], "to_id": e["to_id"], "from": e["from_clip"], "to": e["to_clip"]})
        return r, chain

    def compare_resolvers(self, leaf_id, sel, where):
        """Informational comparison for secondary lookups that do not build a role."""
        a = self.db.resolve_id(leaf_id, sel, self.resolver)
        b = self.db.resolve_id(leaf_id, sel, self.resolver_compare)
        if a.final_id != b.final_id:
            self.warn(f"resolver: {where} resolves to {a.final_name} under {self.resolver} but {b.final_name} under "
                      f"{self.resolver_compare} (not exported as a role; {self.resolver} used)")

    def other_resolver(self, algorithm):
        return self.resolver_compare if algorithm == self.resolver else self.resolver

    def layer_entry(self, e, key, sel, ctx, algorithm=None):
        algorithm = algorithm or self.resolver
        sub, subchain = self.resolve(e.to_id, sel, algorithm)
        target = sub.final_name
        info = self.weight_info(e.params_ptr, e.set_name, ctx)
        rec = {"set": e.set_name, "layer": e.layer, "record_offset": e.offset, "from_id": e.from_id, "to_id": e.to_id,
               "from": e.from_clip, "to": e.to_clip, "key": key,
               "flags": self.entry_by_offset[(e.set_name, e.offset)]["raw_flags"],
               "target_chain": subchain, "target": target}
        rec.update(info)
        alt = self.db.resolve_id(e.to_id, sel, self.other_resolver(algorithm))
        if alt.final_id != sub.final_id:
            rec["resolver_alternatives"] = {self.other_resolver(algorithm): alt.final_name}
            self.warn(f"resolver: layer target {e.to_clip} ({e.set_name} {e.offset}) resolves to {target} under "
                      f"{algorithm} but {alt.final_name} under {self.other_resolver(algorithm)} ({ctx})")
        if e.b0 & 0x02:
            rec["random_variant"] = True
        if e.b1 & 0x08:
            rec["flag_b1_0x08"] = True
        return rec

    def collect_layers(self, r, chain, state_name, sel, ctx, algorithm=None):
        algorithm = algorithm or self.resolver
        keys = [] if r is None else [(r.source_id, "source")] + [(c["to_id"], "intermediate") for c in chain]
        raw = []
        seen = set()
        for layer, sn in self.ordered(sel):
            for k, _ in keys:
                for e in self.db.layers[sn].get(k, []):
                    if (sn, e.offset) in seen:
                        continue
                    seen.add((sn, e.offset))
                    key = "final" if k == r.final_id else ("source" if k == r.source_id else "intermediate")
                    raw.append(self.layer_entry(e, key, sel, ctx, algorithm))
        # state-keyed records (byte1 & 0x02), chosen by flag, keyed on the state's name id
        s = self.state(state_name) if state_name else None
        sid = self.state_name_id(s) if s else None
        state_subs = []
        if sid:
            for layer, sn in self.ordered(sel):
                for e in self.db.state_e[sn].get(sid, []):
                    if e.b0 & 0x01:
                        raw.append(self.layer_entry(e, "state", sel, ctx, algorithm))
                    else:
                        state_subs.append({"set": sn, "record_offset": e.offset, "from": e.from_clip, "to": e.to_clip,
                                           "flags": self.entry_by_offset[(sn, e.offset)]["raw_flags"]})
        return raw, state_subs

    def normalise_layers(self, raw, ctx):
        """Drop null targets, dedupe by final target (max weight), classify kind/slot."""
        prio = self.db.priority
        raw = sorted(raw, key=lambda x: (prio[x["layer"]], int(x["record_offset"], 16)))
        out = collections.OrderedDict()
        nulls = []
        for rec in raw:
            tgt = rec["target"]
            if tgt in NULL_TARGETS:
                nulls.append({"set": rec["set"], "record_offset": rec["record_offset"], "to": rec["to"], "target": tgt, "key": rec["key"]})
                continue
            action, alts = self.godot_action(tgt)
            src = {k: rec[k] for k in ("set", "layer", "record_offset", "from_id", "to_id", "from", "to", "key", "flags",
                                       "weight", "weight_source", "lambda", "target_chain")}
            if rec.get("random_variant"):
                src["random_variant"] = True
            if action is None:
                self.warn(f"layer target {tgt} has no Actor_B action ({ctx})")
                keyname = "#missing:" + tgt
                if keyname not in out:
                    out[keyname] = {"slot": None, "kind": None, "clip": None, "graph_clip": tgt, "status": "missing",
                                    "sources": []}
                    for k in ("weight", "weight_source", "weight_curve", "weight_expr", "weight_tree", "lambda", "key",
                              "set", "layer", "record_offset", "flags"):
                        out[keyname][k] = rec[k]
                out[keyname]["sources"].append(src)
                continue
            self.clip_ref(action, tgt, alts)
            if action not in out:
                add = self.is_additive(action)
                slot = self.slot_of(action)
                out[action] = {"slot": slot, "kind": "additive" if add else "partial", "clip": action,
                               "graph_clip": tgt, "status": "resolved", "sources": [],
                               "keyed_bone_count": len(self.keyed_bones(action)),
                               "prop_bones_keyed": self.prop_bones_keyed(action)}
                note = self.check_slot(action, slot)
                if note:
                    out[action]["slot_note"] = note
                for k in ("weight", "weight_source", "weight_curve", "weight_expr", "weight_tree", "lambda", "key",
                          "set", "layer", "record_offset", "flags"):
                    out[action][k] = rec[k]
                if rec.get("resolver_alternatives"):
                    out[action]["resolver_alternatives"] = rec["resolver_alternatives"]
                if rec.get("random_variant"):
                    out[action]["excluded"] = "random-variant record (byte0 bit1)"
            else:
                cur = out[action]
                if rec["weight"] > cur["weight"] + 1e-9:
                    for k in ("weight", "weight_source", "weight_curve", "weight_expr", "weight_tree", "lambda", "key",
                              "set", "layer", "record_offset", "flags"):
                        cur[k] = rec[k]
            out[action]["sources"].append(src)
        layers = []
        for v in out.values():
            if v["slot"] == "full_body":
                v["excluded"] = "full-body non-additive layer target (not used)"
            v["superseded_by"] = "hands" if v["slot"] == "hands" else None
            layers.append(v)
        return layers, nulls

    def build_role(self, state_name, leaf_name, sel, where):
        """`where` is the role's output path (e.g. 'roles.bow/run/fw'); it keys bindings.resolver_choices."""
        leaf = self.find_leaf(state_name, leaf_name)
        return self.build_role_from_id(state_name, leaf_name, leaf["clip_id"], sel, where, leaf)

    def build_runtime_role(self, state_name, graph_name, sel, ctx):
        """Role for a clip supplied at runtime (leaf callback): resolve its own ID and collect the layer
        records keyed on it (plus the state's state-keyed records)."""
        sid = self.db.name_id.get(graph_name)
        if sid is None:
            action, alts = self.godot_action(graph_name)
            if action is None:
                raise ExportError(f"runtime clip {graph_name} unknown")
            self.clip_ref(action, graph_name, alts)
            s = self.state(state_name) if state_name else None
            raw, subs = ([], []) if not s else self.collect_layers(None, [], state_name, sel, ctx)
            layers, nulls = self.normalise_layers(raw, ctx)
            return {"state": state_name, "state_offset": s["offset"] if s else None, "leaf": None, "leaf_id": None,
                    "final_id": None, "graph_clip": graph_name, "chain": [], "layers": layers, "null_layers": nulls,
                    "state_substitutions": subs, "clip": action, "status": "direct", "additive": self.is_additive(action),
                    "alternatives": alts, "loop": False,
                    "reason": "runtime clip without a symbol id in the graph: only state-keyed layers apply"}
        role = self.build_role_from_id(state_name, graph_name, sid, sel, ctx, None)
        role["status_resolution"] = role["status"]
        role["status"] = "direct" if role["clip"] else "missing"
        role["reason"] = "clip supplied at runtime by the state's leaf callback; layers keyed on this clip id"
        return role

    def build_role_from_id(self, state_name, leaf_name, leaf_id, sel, where, leaf=None):
        """Resolve a leaf with the export loop (bindings.resolver_policy.loop) and the comparison loop. Where they
        disagree the role is marked 'ambiguous' and keeps the other result in resolver_alternatives. The export loop
        is used unless an enabled bindings.resolver_choices[where] names the other loop; such a choice must declare
        basis 'frontier_requirement' (it keeps a Frontier behaviour; it is not a claim about the game's loop)."""
        a = self.db.resolve_id(leaf_id, sel, self.resolver)
        b = self.db.resolve_id(leaf_id, sel, self.resolver_compare)
        if a.final_id == b.final_id:
            return self._build_role_algo(state_name, leaf_name, leaf_id, sel, where, leaf, self.resolver)
        choice = (self.B.get("resolver_choices") or {}).get(where)
        if choice is not None:
            self._choices_hit.add(where)
            if choice.get("use") not in LOOPS:
                raise ExportError(f"resolver_choices[{where}].use = {choice.get('use')!r}")
            if choice["use"] == self.resolver:
                self.errors.append(f"bindings.resolver_choices[{where}] repeats the export loop {self.resolver} "
                                   f"(redundant choice)")
            elif choice.get("basis") != "frontier_requirement" or not choice.get("requirement"):
                self.errors.append(f"bindings.resolver_choices[{where}] leaves the export loop {self.resolver} without "
                                   f"basis 'frontier_requirement' and a 'requirement' (the loop is one for every leaf)")
        active = choice is not None and choice.get("enabled", True)
        algo = choice["use"] if active else self.resolver
        role = self._build_role_algo(state_name, leaf_name, leaf_id, sel, where, leaf, algo)
        other = self.other_resolver(algo)
        alt = self._build_role_algo(state_name, leaf_name, leaf_id, sel, where + " (alternative)", leaf, other)
        if active:
            why = choice.get("why", "")
            basis = choice.get("basis", "undeclared")
        elif choice is not None:
            why = f"bindings.resolver_choices entry disabled: the export loop {self.resolver} is used ({choice['why']})"
            basis = "resolver_policy"
            for pat in choice.get("prop_exempt_when_disabled", []):
                self.prop_exempt_dynamic[pat] = (
                    f"bindings.resolver_choices[{where}] is disabled, so the graph result "
                    f"({role['graph_clip']}, status {role['status']}) is exported; see its 'why'")
        else:
            why = f"export loop {self.resolver} (bindings.resolver_policy)"
            basis = "resolver_policy"
        role["resolution"] = "ambiguous"
        role["resolver"] = algo
        role["resolver_basis"] = basis
        role["resolver_choice_why"] = why
        role["resolver_alternatives"] = {other: {
            "clip": alt["clip"], "graph_clip": alt["graph_clip"], "final_id": alt["final_id"], "status": alt["status"],
            "chain": alt["chain"],
            "layers": [[l["clip"] or ("MISSING " + l["graph_clip"]), l["weight"], l["slot"]] for l in alt["layers"]],
            "null_layers": [n["to"] + " -> " + n["target"] for n in alt["null_layers"]]}}
        res = {"asc_fix": a.final_name if self.resolver == "asc_fix" else b.final_name,
               "asc_once": a.final_name if self.resolver == "asc_once" else b.final_name}
        self.resolver_disagreements.append({
            "where": where, "state": state_name, "leaf": leaf_name, "leaf_id": leaf_id,
            "asc_fix": {"graph_clip": res["asc_fix"], "clip": role["clip"] if algo == "asc_fix" else alt["clip"]},
            "asc_once": {"graph_clip": res["asc_once"], "clip": role["clip"] if algo == "asc_once" else alt["clip"]},
            "chosen": algo, "basis": basis, "why": why})
        if active:
            self.resolver_exceptions.append({
                "where": where, "use": algo, "export_loop": self.resolver, "basis": basis,
                "requirement": choice.get("requirement", ""), "enabled": True,
                "graph_result": {"clip": alt["clip"], "graph_clip": alt["graph_clip"], "status": alt["status"]},
                "used_result": {"clip": role["clip"], "graph_clip": role["graph_clip"], "status": role["status"]},
                "prop_exempt_when_disabled": choice.get("prop_exempt_when_disabled", []), "why": why})
        self.warn(f"resolver: {where} leaf {leaf_name} resolves to {res['asc_fix']} under asc_fix but "
                  f"{res['asc_once']} under asc_once; using {algo} "
                  f"({'bindings.resolver_choices, ' + basis if active else 'export loop'})")
        return role

    def _build_role_algo(self, state_name, leaf_name, leaf_id, sel, ctx, leaf, algorithm):
        r, chain = self.resolve(leaf_id, sel, algorithm)
        raw, state_subs = self.collect_layers(r, chain, state_name, sel, ctx, algorithm)
        layers, nulls = self.normalise_layers(raw, ctx)
        s = self.state(state_name) if state_name else None
        action, alts = self.godot_action(r.final_name)
        role = {"state": state_name, "state_offset": s["offset"] if s else None, "tree": s.get("tree") if s else None,
                "leaf": leaf_name, "leaf_node": leaf["id"] if leaf else None, "leaf_id": leaf_id, "final_id": r.final_id,
                "graph_clip": r.final_name, "chain": chain, "layers": layers, "null_layers": nulls,
                "state_substitutions": state_subs, "loop": self.gstate_loop(state_name) if state_name else False}
        leaf = leaf or {}
        if leaf.get("callback"):
            role["clip_callback"] = leaf["callback"]
            role["clip_callback_expr"] = self.lambda_text(leaf["callback"])
        pf = leaf.get("raw_flags")
        if pf and pf != "0x00000000":
            fid = "anim-player:" + pf
            txt = self.lambda_text(fid) if fid in self.F else None
            role["phase_lambda"] = fid
            role["phase_expr"] = txt
            try:
                paths, _ = self.lambda_paths(fid)
                if len(paths) == 1 and not paths[0][0] and paths[0][1][0] == "c":
                    role["phase"] = float(paths[0][1][1])
            except Exception:  # noqa: BLE001 - informational only
                pass
        if r.final_name in NULL_TARGETS:
            role.update({"clip": None, "status": "disabled", "additive": None, "alternatives": [],
                         "reason": f"resolves to '{r.final_name}': the overlay chain disables this leaf (nothing plays)"})
        elif action is not None:
            self.clip_ref(action, r.final_name, alts)
            role.update({"clip": action, "status": "resolved", "additive": self.is_additive(action),
                         "alternatives": alts})
        else:
            role.update({"clip": None, "status": "missing", "additive": None, "alternatives": [],
                         "reason": f"'{r.final_name}' has no Actor_B action"})
        return role

    def gstate_loop(self, name):
        if name not in self._gstate_cache:
            self._gstate_cache[name] = self.graph_state(name, "role")
        return self._gstate_cache[name]["loop"]

    # ------------------------------------------------------------------ build
    def build(self):
        B = self.B
        self._gstate_cache = {}
        out = collections.OrderedDict()
        weapons = list(B["profiles"])
        modes = list(B["modes"])
        stances = ["stand", "crouch"]

        # modes and selections
        modes_out = {}
        selections = {}
        for m in modes:
            mr = self.mode_record(m)
            modes_out[m] = {"mode": B["modes"][m]["mode"], "mode_record": mr["record"], "record_source": mr["source"],
                            "move_overlay": mr["overlay"], "move_overlay_id": mr["overlay_id"], "crouch": mr["crouch"],
                            "sprint": mr["sprint"], "mode_speed": mr["speed_0x10"], "mode_speed_0x0c": mr["speed_0x0c"],
                            "transition_set": mr["transition_set"], "stance": B["stance_of_mode"][m],
                            "overlays": [], "mode_speed_note": "+0x10 speed (informational; clip speeds come from metrics)"}
            for w in weapons:
                sel = self.selection(w, m)
                selections[f"{w}/{m}"] = {layer: sn for layer, sn in self.ordered(sel)}
            modes_out[m]["overlays"] = [sn for layer, sn in self.ordered(self.selection(weapons[0], m))
                                        if layer in ("move", "crouch")]
        profiles_out = copy.deepcopy(B["profiles"])
        for w in weapons:
            profiles_out[w]["priorities"] = {layer: self.db.priority[layer]
                                             for layer in ("actor_b", "move", "crouch", "weapon-base", "weapon-sub-type",
                                                           "weapon-draw-holster", "crouch-change")}

        # lower roles
        roles = {}
        for w in weapons:
            for m in modes:
                sel = self.selection(w, m)
                for rk, spec in B["lower_roles"].items():
                    key = f"{w}/{m}/{rk}"
                    role = self.build_role(spec["state"], spec["leaf"], sel, "roles." + key)
                    if spec.get("begin_state"):
                        role["begin_state"] = spec["begin_state"]
                        bs = self.state(spec["begin_state"])
                        role["begin_state_offset"] = bs["offset"]
                        if bs.get("tree") != role["tree"]:
                            raise ExportError(f"{key}: begin state {spec['begin_state']} does not share the tree")
                    if role["status"] == "missing":
                        note = B.get("missing_notes", {}).get(rk)
                        if note:
                            role["reason"] = note
                    roles[key] = role
        # Frontier carry compositions of thrown weapons (bindings.carry_overrides, THROW2)
        carry_overrides = self.apply_carry_overrides(roles, weapons, modes)
        # runtime-clip leaves are 'direct'
        for key, role in roles.items():
            rk = key.split("/")[2]
            if rk in ("hit_full", "hit_add"):
                w, m = key.split("/")[:2]
                role["status_graph_leaf"] = role["status"]
                role["status"] = "direct"
                role["graph_leaf"] = {
                    "clip": role["clip"], "graph_clip": role["graph_clip"], "additive": role["additive"],
                    "layers": [[l["clip"] or ("MISSING " + l["graph_clip"]), l["weight"], l["slot"]] for l in role["layers"]],
                    "note": "placeholder resolution of the graph leaf; the state plays the clip its leaf callback "
                            "supplies, so this clip and these layers are NOT used"}
                role["clip"] = None
                role["additive"] = None
                role["layers"] = []
                role["null_layers"] = []
                role["use_runtime_roles"] = f"runtime_roles.{rk}.{w}/{m}/<fw|bw|lt|rt>"
                role["reason"] = ("clip supplied at runtime by the leaf callback: play runtime_roles.%s.%s/%s/<dir> "
                                  "(its clip and the layers keyed on it), never this role's graph leaf" % (rk, w, m))

        # aim trees and aimed movement
        aim_trees = {}
        aim_move = {}
        hand_states = {}
        stand_check = {}
        for w in weapons:
            for st in stances:
                mk = B["stance_selection_mode"][st]
                sel = self.selection(w, mk)
                tree = {}
                for slot, leaf in B["aim_roles"]["slots"].items():
                    role = self.build_role(B["aim_roles"]["state"], leaf, sel, f"aim_trees.{w}/{st}.{slot}")
                    lf = self.find_leaf(B["aim_roles"]["state"], leaf)
                    role["blend_weight"] = self.leaf_parent_weight(B["aim_roles"]["state"], lf)
                    tree[slot] = role
                hands = [l for l in tree["base"]["layers"] if l["slot"] == "hands"]
                tree["hands"] = ({"clip": hands[0]["clip"], "status": "resolved", "layer": hands[0]}
                                 if hands else {"clip": None, "status": "missing", "layer": None})
                aim_trees[f"{w}/{st}"] = tree
                am = {}
                for rk, spec in B["aim_move_roles"].items():
                    role = self.build_role(spec["state"], spec["leaf"], sel, f"aim_move.{w}/{st}.{rk}")
                    lf = self.find_leaf(spec["state"], spec["leaf"])
                    role["blend_weight"] = self.leaf_parent_weight(spec["state"], lf)
                    am[rk] = role
                aim_move[f"{w}/{st}"] = am
                hs = {}
                for rk, spec in B["hand_states"].items():
                    hs[rk] = self.build_role(spec["state"], spec["leaf"], sel, f"hand_states.{w}/{st}.{rk}")
                hand_states[f"{w}/{st}"] = hs
                if st == "stand":
                    for m2 in modes:
                        if B["stance_of_mode"][m2] != "stand" or m2 == mk:
                            continue
                        sel2 = self.selection(w, m2)
                        for slot, leaf in B["aim_roles"]["slots"].items():
                            lf = self.find_leaf(B["aim_roles"]["state"], leaf)
                            r2, _ = self.resolve(lf["clip_id"], sel2)
                            self.compare_resolvers(lf["clip_id"], sel2, f"aim_trees.{w}/stand.{slot} under mode {m2}")
                            if r2.final_name != tree[slot]["graph_clip"]:
                                stand_check.setdefault(f"{w}/{m2}/{slot}", r2.final_name)
        for k, v in sorted(stand_check.items()):
            self.warn(f"aim tree {k} resolves to {v} (differs from the stand selection)")

        # crouch change
        cc = {}
        ccb = B["crouch_change"]
        for w in weapons:
            for dname, dspec in ccb["directions"].items():
                sel = self.selection(w, dspec["mode"], {"crouch-change": dspec["overlay"]})
                full = self.build_role(ccb["full"]["state"], ccb["full"]["leaf"], sel, f"crouch_change.{w}/{dname}.full")
                if full["status"] == "missing" and dspec.get("full_substitute"):
                    sub = dspec["full_substitute"]
                    action, alts = self.godot_action(sub)
                    if action is None:
                        raise ExportError(f"substitute {sub} missing")
                    self.clip_ref(action, sub, alts)
                    full.update({"clip": action, "status": "substitute", "additive": self.is_additive(action),
                                 "reason": ccb["why_substitute"]})
                add = self.build_role(ccb["add"]["state"], ccb["add"]["leaf"], sel, f"crouch_change.{w}/{dname}.add")
                cc[f"{w}/{dname}"] = {"full": full, "add": add, "overlay": dspec["overlay"], "mode": dspec["mode"]}

        # grips
        grips = {}
        for w in weapons:
            g = B["grips"][w]
            carry = None
            src = {}
            if g["carry"].startswith("layer:hands@"):
                rk = g["carry"].split("@", 1)[1]
                role = roles[f"{w}/{rk}"]
                hands = [l for l in role["layers"] if l["slot"] == "hands"]
                if not hands:
                    raise ExportError(f"grip {w}: no hands layer on {rk}")
                # the weapon's own grip layer: its weapon-base hands layer, or the Frontier grip pose that replaces it
                # (bindings.carry_overrides, THROW2)
                own = hands[-1] if len(hands) == 1 else [l for l in hands
                                                         if l["layer"].startswith("weapon") or l["layer"] == "frontier"][0]
                carry = own["clip"]
                src["carry"] = {"from": f"roles.{w}/{rk}.layers[slot=hands]", "graph_clip": [l["graph_clip"] for l in hands]}
                if own.get("sample_s") is not None:
                    src["carry"]["frontier"] = own.get("frontier")
            elif g["carry"].startswith("hand_state:"):
                hk = g["carry"].split(":", 1)[1]
                hr = hand_states[f"{w}/stand"][hk]
                carry = hr["clip"]
                src["carry"] = {"from": f"hand_states.{w}/stand.{hk}", "state": hr["state"], "chain": hr["chain"]}
            grips[w] = {"carry": carry, "aim_stand": aim_trees[f"{w}/stand"]["hands"]["clip"],
                        "aim_crouch": aim_trees[f"{w}/crouch"]["hands"]["clip"], "sources": src, "why": g["why"]}
            if g["carry"].startswith("layer:hands@") and own.get("sample_s") is not None:
                # a pose sampled from the clip (TreeBuilder bakes it on the bone mask)
                grips[w]["carry_sample_s"] = own["sample_s"]
                grips[w]["carry_bones"] = list(own["bones"])

        # actions
        actions = {}
        for w in weapons:
            for st in stances:
                mk = B["stance_selection_mode"][st]
                sel = self.selection(w, mk)
                for ak, spec in B["actions"].items():
                    if ak in (B["profiles"][w].get("actions_skip") or []):
                        continue  # the profile never plays this action (bindings.profiles.<w>.actions_skip)
                    key = f"{w}/{st}/{ak}"
                    part_state = self.state(spec["state"])
                    leaves = self.tree_leaves(part_state["tree"])
                    if len(leaves) != 1:
                        raise ExportError(f"action state {spec['state']} has {len(leaves)} leaves")
                    prole = self.build_role(spec["state"], leaves[0]["clip"], sel, f"actions.{key}.partial")
                    twin_state = self.state(spec["twin"])
                    tl = self.tree_leaves(twin_state["tree"])
                    trole = self.build_role(spec["twin"], tl[0]["clip"], sel, f"actions.{key}.twin")
                    by_mode = {}
                    if st == "stand":
                        for m2 in modes:
                            if B["stance_of_mode"][m2] != "stand":
                                continue
                            sel2 = self.selection(w, m2)
                            r2, _ = self.resolve(leaves[0]["clip_id"], sel2)
                            self.compare_resolvers(leaves[0]["clip_id"], sel2, f"actions.{key}.by_mode.{m2}.partial")
                            a2, _ = self.godot_action(r2.final_name)
                            t2, _ = self.resolve(tl[0]["clip_id"], sel2)
                            self.compare_resolvers(tl[0]["clip_id"], sel2, f"actions.{key}.by_mode.{m2}.twin")
                            ta2, _ = self.godot_action(t2.final_name)
                            by_mode[m2] = {"partial": a2, "twin": ta2, "graph_partial": r2.final_name, "graph_twin": t2.final_name}
                            if a2:
                                self.clip_ref(a2, r2.final_name)
                            if ta2:
                                self.clip_ref(ta2, t2.final_name)
                    gs = self.graph_state(spec["state"], "weapon")
                    a = {"state": spec["state"], "state_offset": part_state["offset"], "twin_state": spec["twin"],
                         "twin_state_offset": twin_state["offset"], "partial": prole["clip"], "twin": trole["clip"],
                         "status": prole["status"], "loop": gs["loop"], "frontier_key": spec.get("frontier_key"),
                         "partial_role": prole, "twin_role": trole,
                         "rate_callback": gs["callbacks"].get("phase_update_cb"),
                         "start_phase_callback": gs["callbacks"].get("start_phase_cb"),
                         "selection_mode": mk}
                    spc = gs["callbacks"].get("start_phase_cb")
                    if spc and spc["expr"] and len(spc["expr"]) == 1 and re.fullmatch(r"-?\d+(\.\d+)?", spc["expr"][0]):
                        a["start_phase"] = float(spc["expr"][0])
                    if by_mode and len({(v["partial"], v["twin"]) for v in by_mode.values()}) > 1:
                        a["by_mode"] = by_mode
                    if prole["status"] == "missing":
                        a["reason"] = B.get("missing_notes", {}).get(ak, prole.get("reason"))
                    if trole["status"] == "missing":
                        a["twin_reason"] = f"twin '{trole['graph_clip']}' has no Actor_B action"
                    actions[key] = a

        # Frontier clip substitutions of graph action states (bindings.action_overrides, THROW2); before the pinned rows,
        # which copy them
        action_overrides = self.apply_action_overrides(actions)

        # pinned Frontier action rows (bindings.pinned_actions): a Frontier key with no graph state, pinned to a
        # resolved graph action whose clips, records and asset ids are copied
        for key, spec in sorted(((B.get("pinned_actions") or {}).get("rows") or {}).items()):
            src = actions.get(spec["same_as"])
            if src is None or src["status"] not in ("resolved", "frontier_substitute"):
                self.errors.append(f"pinned action {key}: source {spec['same_as']} is not a resolved action")
                continue
            if key.split("/")[0] not in weapons:
                self.errors.append(f"pinned action {key}: unknown profile")
                continue
            a = copy.deepcopy(src)
            a.update({"frontier_key": spec["frontier_key"], "status": "frontier_pinned", "pinned_from": spec["same_as"],
                      "why": spec["why"]})
            a.pop("by_mode", None)
            actions[key] = a

        # thrown weapons (bindings.throw): the throw-object-* states per profile and stance
        throw = self.build_throw(weapons, stances)

        # runtime clips
        runtime = {}
        for group, spec in B["runtime_clips"].items():
            if group == "why":
                continue
            clips = {}
            evidence = {}
            for k, name in spec["clips"].items():
                action, alts = self.godot_action(name)
                if action is None:
                    raise ExportError(f"runtime clip {name} missing")
                self.clip_ref(action, name, alts)
                clips[k] = action
                names = set([name, action]) | set(self.clips[action]["source_names"])
                ev = []
                for sn in sorted(self.db.sets):
                    for r in self.db.sets[sn]["remaps"]:
                        if r["to_clip"] in names or r["from_clip"] in names:
                            ev.append({"set": sn, "record_offset": r["offset"], "from": r["from_clip"], "to": r["to_clip"],
                                       "flags": r["raw_flags"]})
                evidence[action] = ev[:8]
                if len(ev) > 8:
                    evidence[action].append({"more": len(ev) - 8})
            runtime[group] = {"clips": clips, "source_state": spec.get("source_state"), "callback": spec.get("callback"),
                              "evidence": evidence}
        runtime_roles = {"hit_full": {}, "hit_add": {}, "death": {}, "fire": {}}
        rc_names = B["runtime_clips"]
        for w in weapons:
            for m in modes:
                st = B["stance_of_mode"][m]
                sel = self.selection(w, m)
                for dk in ("fw", "bw", "lt", "rt"):
                    runtime_roles["hit_full"][f"{w}/{m}/{dk}"] = self.build_runtime_role(
                        rc_names["hit_full"]["source_state"], rc_names["hit_full"]["clips"][f"{st}/{dk}"], sel, f"runtime_roles.hit_full.{w}/{m}/{dk}")
                    runtime_roles["hit_add"][f"{w}/{m}/{dk}"] = self.build_runtime_role(
                        rc_names["hit_add"]["source_state"], rc_names["hit_add"]["clips"][f"{st}/{dk}"], sel, f"runtime_roles.hit_add.{w}/{m}/{dk}")
                for vk, name in sorted(rc_names["death"]["clips"].items()):
                    runtime_roles["death"][f"{w}/{m}/{vk}"] = self.build_runtime_role(
                        rc_names["death"]["source_state"], name, sel, f"runtime_roles.death.{w}/{m}/{vk}")
            for st in stances:
                if f"{w}/{st}" not in rc_names["fire"]["clips"]:
                    continue  # no fire clip: a thrown weapon's release is part of its throw (bindings.throw)
                sel = self.selection(w, B["stance_selection_mode"][st])
                runtime_roles["fire"][f"{w}/{st}"] = self.build_runtime_role(
                    rc_names["fire"]["source_state"], rc_names["fire"]["clips"][f"{w}/{st}"], sel, f"runtime_roles.fire.{w}/{st}")
        runtime_clips = {
            "fire": runtime["fire"]["clips"],
            "hit_full": runtime["hit_full"]["clips"],
            "hit_add": {k.split("/")[1]: v for k, v in runtime["hit_add"]["clips"].items() if k.startswith("stand/")},
            "hit_add_by_stance": runtime["hit_add"]["clips"],
            "death": runtime["death"]["clips"],
            "charge": runtime["charge"]["clips"],
            "sources": {g: {"source_state": v["source_state"], "callback": v["callback"], "evidence": v["evidence"]}
                        for g, v in runtime.items()},
            "why": B["runtime_clips"]["why"],
        }

        # weapon partial slot (weapon-out fingers) and prop-bone coverage
        weapon_layers = self.weapon_layers(hand_states, weapons, stances)
        for key, role in roles.items():
            w, m, rk = key.split("/")
            role["prop"] = self.prop_info(role, w, B["stance_of_mode"][m], weapon_layers, "roles." + key)
        for grp in ("hit_full", "death"):
            for key, role in runtime_roles[grp].items():
                w, m = key.split("/")[:2]
                role["prop"] = self.prop_info(role, w, B["stance_of_mode"][m], weapon_layers,
                                              f"runtime_roles.{grp}.{key}")
        # what each requirement-2 resolver exception holds up: roles whose only full-weight prop driver it supplies
        static_exempt = list(B.get("prop_exempt") or {})
        for exc in self.resolver_exceptions:
            pats = exc["prop_exempt_when_disabled"]
            held = []
            for grp, rows in (("roles", roles), ("runtime_roles.hit_full", runtime_roles["hit_full"]),
                              ("runtime_roles.death", runtime_roles["death"])):
                for key, role in sorted(rows.items()):
                    where = f"{grp}.{key}"
                    if not any(fnmatch.fnmatchcase(where, p) for p in pats):
                        continue
                    if role["status"] == "missing" or any(fnmatch.fnmatchcase(where, p) for p in static_exempt):
                        continue  # exempt from (g) for another reason
                    full = [d for d in role["prop"]["drivers"] if d["min_weight"] >= 1.0 - 1e-6]
                    if full and all(d["source"] == "weapon_out" for d in full):
                        held.append(where)
            exc["prop_full_weight_only_via_this_choice"] = {"count": len(held), "roles": held}

        # graph states (every state any role/action/transition refers to)
        gnames = set()
        for sg in self.subgraph["states"]:
            gnames.add(sg["name"])
        for spec in B["actions"].values():
            gnames.add(spec["state"])
            gnames.add(spec["twin"])
        for spec in B["hand_states"].values():
            gnames.add(spec["state"])
        for spec in ((B.get("throw") or {}).get("states") or {}).values():
            gnames.add(spec["state"])
        if B.get("throw"):
            gnames |= {B["aim_roles"]["state"]} | {spec["state"] for spec in B["aim_move_roles"].values()}
        # every lower-role state (the subgraph omits e.g. the medium and backward landings)
        role_states = set()
        for spec in B["lower_roles"].values():
            role_states.add(spec["state"])
            if spec.get("begin_state"):
                role_states.add(spec["begin_state"])
        gnames |= role_states
        groups = {sg["name"]: sg["group"] for sg in self.subgraph["states"]}

        def group_of(n):
            if n in groups:
                return groups[n]
            if "part" in n or "add" in n:
                return "weapon"
            if n in role_states and ("land" in n or "fall" in n or "jump" in n):
                return "air"
            return "other"
        graph_states = {}
        for n in sorted(gnames):
            graph_states[n] = self.graph_state(n, group_of(n))

        # transitions table
        transitions, thresholds = self.build_transitions(graph_states)

        # clips
        for a in list(self.clips):
            self.clips[a]["graph_names"] = sorted(self.clip_graph_names.get(a, ()))

        # coverage, structural assertions
        coverage = self.coverage(roles, weapons, modes)
        self.assertions(roles, aim_trees, actions, weapons, modes, graph_states, transitions)

        frontier = self.frontier_diff(roles, aim_trees, aim_move, actions, runtime_clips, grips)

        # alias audit (every ambiguous Actor_B original name)
        amb = sorted(k for k, v in self.alias.items() if len([a for a in v if a in self.lib]) > 1)
        for k in amb:
            acts = sorted(a for a in self.alias[k] if a in self.lib)
            if len({r["action_name"] for r in self.index_rows if r["original_name"] == k}) > 1:
                used = [a for a in acts if a in self.clips]
                self.warn(f"alias audit: original_name '{k}' has {len(acts)} actions {acts}; "
                          + (f"exported clip(s) {used}" if used else "not used as a clip by this export"))

        for where in sorted(set((B.get("resolver_choices") or {})) - self._choices_hit):
            self.errors.append(f"bindings.resolver_choices[{where}] matches no resolver disagreement (stale choice)")
        meta = {
            "schema": SCHEMA_VERSION, "generator": GENERATOR, "resolver": self.resolver,
            "resolver_compare": self.resolver_compare,
            "resolver_note": ("One overlay loop, %s, resolves every leaf and layer target (bindings.resolver_policy, "
                              "with the graph evidence in resolver_policy). The engine's loop is not in the data: "
                              "asc_fix repeats ascending passes until stable, asc_once restarts from the lowest layer "
                              "after each hit. The two agree on every exported leaf except the ones in "
                              "resolver_disagreements; those roles are marked resolution 'ambiguous' and keep the "
                              "other result in resolver_alternatives. resolver_exceptions lists the leaves that use "
                              "the other loop anyway. Each one keeps a behaviour Frontier has today (user requirement "
                              "2); it is not a claim about the game's loop, and the graph result stays exported "
                              "beside it." % self.resolver),
            "resolver_policy": {"loop": self.resolver, "compare": self.resolver_compare,
                                "why": self.B["resolver_policy"]["why"],
                                "evidence": list(self.B["resolver_policy"].get("evidence", []))},
            "resolver_exceptions": sorted(self.resolver_exceptions, key=lambda d: d["where"]),
            "resolver_disagreements": sorted(self.resolver_disagreements, key=lambda d: d["where"]),
            "keyed_bones": {"file": "tools/anim_graph/actor_b_keyed_bones.json",
                            "generator": "tools/anim_graph/dump_keyed_bones.gd",
                            "library_sha256": self.kb_library_sha},
            "slot_notes": dict(sorted(self.slot_notes.items())),
            "authorization": AUTHORIZATION,
            "fidelity_policy": "graph-authored behaviour is the default; gameplay deviations are opt-in flags "
                               "(gameplay_overrides, all default false). The only default-on deviations keep a "
                               "behaviour Frontier has today (user requirement 2) and are listed in "
                               "resolver_exceptions, each with the graph result exported beside it",
            "generated_from": self.input_hashes(),
            "vendored": self.vendor_hashes(),
            "warnings": sorted(self.warnings),
            "coverage": coverage,
            "slot_basis": "name + additive flag + bone-count heuristic, checked against every layer clip's keyed "
                          "bones (actor_b_keyed_bones.json): 'hands' must key only palm/finger/prop bones, "
                          "'arms'/'other_partial' must key more than hand bones ('arms' clips that also key bones "
                          "outside the arm/hand set are listed in slot_notes), 'full_body' must key leg bones; "
                          f"hands = finger/palm/prop-only clips (<= {HANDS_BONE_MAX} bones)",
            "units": {"fade_s": "transition scalar +0x1c, seconds (INFERRED)",
                      "phase": "normalized clip phase 0..1", "weight": "layer weight 0..1 from raw_0x0c lambda"},
            "layer_order": "layers are listed by first occurrence in ascending overlay priority, then record offset "
                           "(application order INFERRED); duplicates of one target keep the maximum weight",
            "superseded_by": "'hands' marks finger/palm/prop layers. Default (graph): they apply at their graph weight "
                             "in listed order; on the lower-body roles the weapon-out finger partial "
                             "(weapon_layers.weapon_out, options.weapon_out_fingers) then plays over them at weight 1 "
                             "for the weapons it applies to (weapon_out.clips[*].applies: musket, pistol). "
                             "Only with gameplay_overrides.override_exact_hands_grip does the runtime grip node "
                             "(grips.<w>) replace all of them at weight 1",
            "prop_coverage": "every lower-body role and runtime hit/death role carries 'prop': the clips that key the "
                             "weapon's prop bone (weapon_layers.prop_bones) under the default options; the build "
                             "fails (g) unless one of them has full weight, except for bindings.prop_exempt",
        }
        out["meta"] = meta
        out["profiles"] = profiles_out
        out["selections"] = selections
        out["modes"] = modes_out
        out["clips"] = self.clips
        out["roles"] = roles
        out["bank_roles"] = B["bank_roles"]
        out["aim_trees"] = aim_trees
        out["aim_move"] = aim_move
        out["hand_states"] = hand_states
        out["weapon_layers"] = weapon_layers
        out["crouch_change"] = cc
        out["grips"] = grips
        out["actions"] = actions
        out["throw"] = throw
        out["carry_overrides"] = carry_overrides
        out["action_overrides"] = action_overrides
        out["runtime_clips"] = runtime_clips
        out["runtime_roles"] = runtime_roles
        out["transitions"] = transitions
        out["gates"] = self.gates()
        out["graph_states"] = graph_states
        out["thresholds"] = thresholds
        out["landing"] = self.landing_out(thresholds, roles)
        out["tuning"] = B["tuning"]
        out["tuning_notes"] = B.get("tuning_notes", {})
        for k in sorted(B["tuning"]):
            note = out["tuning_notes"].get(k)
            if not isinstance(note, dict) or note.get("status") not in TUNING_STATUS or not note.get("why"):
                self.errors.append("tuning.%s has no tuning_notes entry with a status in %s and a why" % (k, sorted(TUNING_STATUS)))
        out["options"] = B["options"]
        out["options_notes"] = B["options_notes"]
        out["gameplay_overrides"] = B["gameplay_overrides"]
        out["allowed_missing"] = B["allowed_missing"]
        out["frontier"] = frontier
        if self.errors:
            raise ExportError("structural assertions failed:\n  " + "\n  ".join(self.errors))
        return norm_floats(out)

    # ------------------------------------------------------------------ Frontier carry / action overrides (THROW2)
    def quiet(self, fn, *args):
        """Runs fn(*args) without adding warnings or resolver disagreements: a secondary lookup (another profile's
        layers for a carry override) whose role is not exported; what it contributes is recorded where it is used."""
        state = (list(self.warnings), set(self._warned), list(self.resolver_disagreements))
        try:
            return fn(*args)
        finally:
            self.warnings, self._warned, self.resolver_disagreements = state[0], state[1], state[2]

    def pose_layer(self, name, weight, ctx):
        """bindings.carry_overrides.poses[name] as a carry layer: an Actor_B clip sampled at one key time
        (sample_s) on a bone mask, status 'frontier' (no graph record)."""
        spec = (self.B.get("carry_overrides") or {}).get("poses", {}).get(name)
        if spec is None:
            raise ExportError(f"carry_overrides: unknown pose {name} ({ctx})")
        if not 0.0 <= float(weight) <= 1.0:
            self.errors.append(f"carry_overrides: pose {name} weight {weight} outside [0, 1] ({ctx})")
        cache = self.__dict__.setdefault("_pose_cache", {})
        if name in cache:
            out = copy.deepcopy(cache[name])
            out["weight"] = float(weight)
            return out
        action, alts = self.godot_action(spec["clip"])
        if action is None:
            raise ExportError(f"carry_overrides.poses.{name}: {spec['clip']} has no Actor_B action")
        self.clip_ref(action, spec["clip"], alts)
        keyed = self.keyed_bones(action)
        lost = [b for b in spec["bones"] if b not in keyed]
        if lost:
            self.errors.append(f"carry_overrides.poses.{name}: {action} does not key {lost}")
        bones = [b for b in spec["bones"] if b in keyed]
        length = float(self.lib[action]["length"])
        t = float(spec["sample_s"])
        if t < 0.0 or t > length + 1e-6:
            self.errors.append(f"carry_overrides.poses.{name}: sample_s {t} outside {action} (0..{length})")
        slot = spec["slot"]
        hand = {b for b in bones if HAND_BONE_RE.search(b)}
        if slot == "hands" and set(bones) - hand:
            self.errors.append(f"carry_overrides.poses.{name}: slot hands but masks {sorted(set(bones) - hand)}")
        meta = self.lib[action].get("meta") or {}
        layer = {"slot": slot, "kind": "partial", "clip": action, "graph_clip": spec["clip"], "status": "frontier",
                "sample_s": rnd(t), "bones": bones, "keyed_bone_count": len(bones),
                "prop_bones_keyed": sorted(b for b in bones if b.endswith("hand_prop_attachment")),
                "weight": float(weight), "weight_source": "frontier (proposed, THROW2 user playtest 2026-09-25)",
                "weight_curve": None, "weight_expr": None, "weight_tree": None, "lambda": None, "key": "frontier",
                "set": None, "layer": "frontier", "record_offset": None, "flags": None,
                "superseded_by": "hands" if slot == "hands" else None, "sources": [],
                "frontier": {"pose": name, "source_state": spec.get("source_state"), "native_asset_id": meta.get("native_asset_id"),
                             "why": spec["why"]}}
        cache[name] = copy.deepcopy(layer)
        return layer

    def carry_profile_layers(self, w, m, rk, row, ctx):
        """The weapon-base layers of row['replace'] slots that row['from_profile'] resolves on role rk in mode m (its
        idle role's when it has none there), missing targets replaced by row['substitute'] (status 'substitute')."""
        prof = dict(self.B["profiles"][w])
        prof.update(row["from_profile"])
        key = "_carry_" + w
        self.B["profiles"][key] = {k: prof.get(k) for k in ("weapon-base", "weapon-sub-type", "weapon-draw-holster")}
        try:
            sel = self.selection(key, m)
            subs = row.get("substitute") or {}
            base = prof["weapon-base"]

            def pick(role_key):
                spec = self.B["lower_roles"][role_key]
                role = self.quiet(self.build_role, spec["state"], spec["leaf"], sel, f"carry_overrides.{w}/{m}/{role_key}")
                out = []
                for l in role["layers"]:
                    if l.get("set") != base or l.get("excluded"):
                        continue
                    if l["status"] == "resolved" and l["slot"] in row["replace"]:
                        out.append(copy.deepcopy(l))
                    elif l["status"] == "missing" and l["graph_clip"] in subs:
                        action, alts = self.godot_action(subs[l["graph_clip"]])
                        if action is None:
                            raise ExportError(f"carry_overrides {w}: substitute {subs[l['graph_clip']]} missing")
                        self.clip_ref(action, subs[l["graph_clip"]], alts)
                        slot = self.slot_of(action)
                        if slot not in row["replace"]:
                            continue
                        x = copy.deepcopy(l)
                        x.update({"clip": action, "status": "substitute", "slot": slot, "kind": "additive" if self.is_additive(action) else "partial",
                                  "keyed_bone_count": len(self.keyed_bones(action)), "prop_bones_keyed": self.prop_bones_keyed(action),
                                  "superseded_by": "hands" if slot == "hands" else None,
                                  "reason": f"'{l['graph_clip']}' has no Actor_B action; {action} (carry_overrides substitute)"})
                        out.append(x)
                return out
            got = pick(rk)
            src = rk
            if not got and rk != "idle":
                got = pick("idle")
                src = "idle"
                for l in got:
                    l["status"] = "substitute"
                    l["reason"] = (f"{base.replace('anim-overlay-player-', '')} has no record on this state; "
                                   f"its idle role's layer (carry_overrides)") + (("; " + l["reason"]) if l.get("reason") else "")
            for l in got:
                l["carry_profile"] = {"weapon-base": base, "role": src}
            return got
        finally:
            self.B["profiles"].pop(key, None)

    def apply_carry_overrides(self, roles, weapons, modes):
        """bindings.carry_overrides (THROW2): see its 'about'. Returns the summary exported as carry_overrides."""
        co = self.B.get("carry_overrides") or {}
        summary = {"about": co.get("about", ""), "poses": {}, "rows": {}}
        for name, spec in sorted((co.get("poses") or {}).items()):
            action, _ = self.godot_action(spec["clip"])
            meta = (self.lib.get(action) or {}).get("meta") or {}
            summary["poses"][name] = {"clip": action, "graph_clip": spec["clip"], "sample_s": rnd(spec["sample_s"]),
                                      "slot": spec["slot"], "bones": list(spec["bones"]), "source_state": spec.get("source_state"),
                                      "native_asset_id": meta.get("native_asset_id"), "why": spec["why"]}
        for w, rows in sorted((co.get("rows") or {}).items()):
            if w not in weapons:
                self.errors.append(f"carry_overrides: unknown profile {w}")
                continue
            wb = self.B["profiles"][w]["weapon-base"]
            out_rows = []
            for i, row in enumerate(rows):
                touched = []
                for m in row["modes"]:
                    if m not in modes:
                        self.errors.append(f"carry_overrides.{w}[{i}]: unknown mode {m}")
                        continue
                    for rk in self.B["lower_roles"]:
                        if rk in row.get("roles_except", []):
                            continue
                        if row.get("roles_only") is not None and rk not in row["roles_only"]:
                            continue
                        key = f"{w}/{m}/{rk}"
                        role = roles[key]
                        layers = role["layers"]
                        idx = [j for j, l in enumerate(layers)
                               if l.get("slot") in row["replace"] and (l.get("set") == wb or l.get("carry_row") is not None)]
                        if not idx:
                            continue
                        new = []
                        if row.get("from_profile"):
                            new += self.carry_profile_layers(w, m, rk, row, "carry_overrides." + key)
                        for pose, weight in row.get("poses", []):
                            new.append(self.pose_layer(pose, weight, "carry_overrides." + key))
                        for l in new:
                            l["carry_row"] = f"{w}[{i}]"
                        replaced = [layers[j] for j in idx]
                        role["layers"] = layers[:idx[0]] + new + [l for j, l in enumerate(layers) if j >= idx[0] and j not in idx]
                        role.setdefault("carry_override", []).append({
                            "row": f"{w}[{i}]", "slots": list(row["replace"]),
                            "replaced": [{"clip": l.get("clip"), "graph_clip": l.get("graph_clip"), "weight": l.get("weight"),
                                          "set": l.get("set"), "record_offset": l.get("record_offset"), "status": l.get("status"),
                                          "carry_row": l.get("carry_row")} for l in replaced],
                            "why": row["why"]})
                        touched.append(key)
                out_rows.append({"row": f"{w}[{i}]", "modes": list(row["modes"]), "replace": list(row["replace"]),
                                 "roles_except": list(row.get("roles_except", [])), "roles_only": row.get("roles_only"),
                                 "from_profile": row.get("from_profile"),
                                 "substitute": row.get("substitute") or {}, "poses": [list(x) for x in row.get("poses", [])],
                                 "roles": len(touched), "why": row["why"]})
                if not touched:
                    self.errors.append(f"carry_overrides.{w}[{i}] replaced nothing")
            summary["rows"][w] = out_rows
        return summary

    def resolve_graph_name(self, graph_name, sel, ctx):
        """A graph clip name resolved through an overlay selection (its 32-bit id, never re-hashed) -> (action, chain)."""
        gid = self.db.name_id.get(graph_name)
        if gid is None:
            raise ExportError(f"{ctx}: graph name {graph_name} has no symbol id")
        r, chain = self.resolve(gid, sel)
        action, alts = self.godot_action(r.final_name)
        if action is None:
            raise ExportError(f"{ctx}: {graph_name} resolves to {r.final_name}, which has no Actor_B action")
        self.clip_ref(action, r.final_name, alts)
        return action, chain, gid

    def apply_action_overrides(self, actions):
        """bindings.action_overrides (THROW2): see its 'about'. Returns the summary exported as action_overrides."""
        ao = self.B.get("action_overrides") or {}
        summary = {"about": ao.get("about", ""), "rows": {}}
        for key, spec in sorted((ao.get("rows") or {}).items()):
            a = actions.get(key)
            if a is None or a["status"] != "resolved":
                self.errors.append(f"action_overrides {key}: not a resolved graph action")
                continue
            w, st = key.split("/")[:2]
            sel = self.selection(w, self.B["stance_selection_mode"][st])
            rep = {"partial": a["partial"], "twin": a["twin"], "partial_graph": a["partial_role"].get("graph_clip"),
                   "twin_graph": a["twin_role"].get("graph_clip")}
            ev = {}
            for part in ("partial", "twin"):
                if not spec.get(part):
                    continue
                action, chain, gid = self.resolve_graph_name(spec[part], sel, f"action_overrides.{key}.{part}")
                a[part] = action
                ev[part] = {"graph_clip": spec[part], "graph_id": gid, "chain": chain, "clip": action,
                            "native_asset_id": (self.lib[action].get("meta") or {}).get("native_asset_id")}
            a.pop("by_mode", None)
            a["status"] = "frontier_substitute"
            a["replaced"] = rep
            a["substitute"] = ev
            a["why"] = spec["why"]
            summary["rows"][key] = {"state": a["state"], "partial": a["partial"], "twin": a["twin"], "replaced": rep,
                                    "evidence": ev, "why": spec["why"]}
        return summary

    # ------------------------------------------------------------------ thrown weapons
    def build_throw(self, weapons, stances):
        """bindings.throw: the graph's aimed throw chain (throw-object-aim / -start / -end / ^idle / ^aim) resolved
        per thrown-weapon profile and stance, like the other roles (one leaf per state), with the release frame the
        game supplies. Profiles that share bindings.profiles.<w>.clip_set list the other members."""
        B = self.B
        TB = B.get("throw") or {}
        self.throw_rows = {}
        if not TB:
            return {}
        rows = {}
        for w in TB["profiles"]:
            if w not in weapons:
                self.errors.append(f"throw: profile {w} is not in bindings.profiles")
                continue
            for st in stances:
                mk = B["stance_selection_mode"][st]
                sel = self.selection(w, mk)
                parts = {}
                for pk, spec in TB["states"].items():
                    s = self.state(spec["state"])
                    leaves = self.tree_leaves(s["tree"])
                    if len(leaves) != 1 or leaves[0]["clip"] != spec["leaf"]:
                        raise ExportError(f"throw state {spec['state']}: expected the single leaf {spec['leaf']}, "
                                          f"found {[l['clip'] for l in leaves]}")
                    role = self.build_role(spec["state"], spec["leaf"], sel, f"throw.{w}/{st}.{pk}")
                    gs = self.graph_state(spec["state"], "throw")
                    role["int_flag_callback"] = gs["callbacks"].get("int_flag_cb")
                    if role["status"] == "missing":
                        role["reason"] = (TB.get("missing_notes") or {}).get(pk, role.get("reason"))
                    parts[pk] = role
                rows[f"{w}/{st}"] = {"parts": parts, "selection_mode": mk}
        self.throw_rows = rows
        sets = {}
        for w in TB["profiles"]:
            cs = B["profiles"].get(w, {}).get("clip_set")
            if cs:
                sets.setdefault(cs, []).append(w)
        return {"about": TB["about"], "profiles": list(TB["profiles"]), "states": TB["states"],
                "allowed_missing": TB.get("allowed_missing", []), "missing_notes": TB.get("missing_notes", {}),
                "release": TB["release"], "clip_sets": sets, "rows": rows}

    # ------------------------------------------------------------------ weapon partial slot and prop bones
    def weapon_layers(self, hand_states, weapons, stances):
        B = self.B
        spec = B["weapon_layers"]
        wspec = spec["weapon_out"]
        hspec = B["hand_states"]["weapon_out"]
        st = self.state(hspec["state"])
        gs = self.graph_state(st["name"], "weapon")
        leaf = self.find_leaf(hspec["state"], hspec["leaf"])
        if wspec.get("apply_rule") != "weapon_base_remaps_leaf":
            raise ExportError(f"weapon_layers.weapon_out.apply_rule {wspec.get('apply_rule')!r} is not supported")
        force = wspec.get("force") or {}
        applies = {}
        for w in weapons:
            wb = B["profiles"][w]["weapon-base"]
            recs = [r["offset"] for r in self.db.sets[wb]["remaps"]
                    if r["from_id"] == leaf["clip_id"] and not int(r["raw_flags"].split()[0], 16) & 0x01
                    and not int(r["raw_flags"].split()[1], 16) & 0x02]
            if w in force:
                applies[w] = (bool(force[w]), recs, "weapon_layers.weapon_out.force.%s = %s (WP5 decision)" % (
                    w, str(bool(force[w])).lower()))
            elif recs:
                applies[w] = (True, recs, "%s remaps %s (%s)" % (wb.replace("anim-overlay-player-", ""), hspec["leaf"],
                                                                 ", ".join(recs)))
            else:
                applies[w] = (False, recs, "%s has no %s remap: the leaf falls through to actor_b's generic finger "
                                           "clip, which would hide the weapon's own hands layers (apply_rule)" % (
                                               wb.replace("anim-overlay-player-", ""), hspec["leaf"]))
        clips = {}
        for w in weapons:
            for s_ in stances:
                r = hand_states[f"{w}/{s_}"]["weapon_out"]
                clips[f"{w}/{s_}"] = {"clip": r["clip"], "graph_clip": r["graph_clip"], "status": r["status"],
                                      "applies": applies[w][0], "applies_why": applies[w][2],
                                      "weapon_base_records": applies[w][1],
                                      "prop_bones_keyed": self.prop_bones_keyed(r["clip"]) if r["clip"] else [],
                                      "keyed_bone_count": len(self.keyed_bones(r["clip"])) if r["clip"] else 0,
                                      "resolution": r.get("resolution", "unique")}
                if r.get("resolution"):
                    clips[f"{w}/{s_}"]["resolver"] = r["resolver"]
                    clips[f"{w}/{s_}"]["resolver_basis"] = r["resolver_basis"]
        wo = {"state": st["name"], "state_offset": st["offset"], "entered_by": gs["entered_by"], "loop": gs["loop"],
              "leaf": hspec["leaf"], "leaf_id": leaf["clip_id"],
              "role_source": "hand_states.<w>/<stance>.weapon_out", "option": "options.weapon_out_fingers",
              "default_on": bool(B["options"].get("weapon_out_fingers")),
              "weight": wspec["weight"], "weight_source": wspec["weight_source"],
              "applies_to": wspec["applies_to"], "apply_rule": wspec["apply_rule"],
              "apply_rule_why": wspec["apply_rule_why"], "force": dict(force), "clips": clips}
        return {"order": spec["order"], "weapon_out": wo, "prop_bones": B["prop_bones"], "notes": spec["notes"]}

    def prop_info(self, role, w, stance, wl, where):
        """Which clips drive the weapon's prop bone for this role under the default options, and at what weight."""
        bone = self.B["prop_bones"][w]
        drivers = []
        if role.get("clip") and not role.get("additive") and bone in self.keyed_bones(role["clip"]):
            drivers.append({"clip": role["clip"], "weight": 1.0, "min_weight": 1.0, "source": "role clip"})
        for l in role["layers"]:
            keyed = set(l["bones"]) if l.get("bones") is not None else (self.keyed_bones(l["clip"]) if l["clip"] else set())
            if l["clip"] and l["kind"] == "partial" and not l.get("excluded") and bone in keyed:
                mw = min(l["weight_curve"]) if l.get("weight_curve") else l["weight"]
                drivers.append({"clip": l["clip"], "weight": l["weight"], "min_weight": mw, "source": "layer",
                                "slot": l["slot"]})
        wo = wl["weapon_out"]
        if wo["default_on"]:
            c = wo["clips"][f"{w}/{stance}"]
            if c["applies"] and c["clip"] and bone in self.keyed_bones(c["clip"]):
                drivers.append({"clip": c["clip"], "weight": wo["weight"], "min_weight": wo["weight"],
                                "source": "weapon_out"})
        full = any(d["min_weight"] >= 1.0 - 1e-6 for d in drivers)
        info = {"bone": bone, "drivers": drivers, "full_weight": full}
        if full:
            return info
        exempt = None
        if role["status"] == "missing":
            exempt = "role missing (no clip to play)"
        else:
            pats = sorted((self.B.get("prop_exempt") or {}).items()) + sorted(self.prop_exempt_dynamic.items())
            for pat, why in pats:
                if fnmatch.fnmatchcase(where, pat):
                    exempt = why
                    break
        if exempt:
            info["exempt"] = exempt
        else:
            self.errors.append(f"(g) {where}: nothing keys {bone} at full weight under the default options "
                               f"(drivers {[(d['clip'], d['min_weight'], d['source']) for d in drivers]})")
        return info

    # ------------------------------------------------------------------ transitions
    def gates(self):
        g = {}
        for k, v in self.B["gates"].items():
            g[k] = dict(v)
            g[k]["use_s"] = v["frames"] / v["fps"]
        return g

    def build_transitions(self, graph_states):
        B = self.B
        gates = self.gates()
        over_by_key = collections.defaultdict(list)
        for flag, ov in B["gameplay_overrides"].items():
            for tk, vals in (ov.get("transitions") or {}).items():
                o = {"flag": flag, "rule": ov["rule"], "why": ov["why"]}
                o.update(vals)
                over_by_key[tk].append(o)
        out = {}
        for key, spec in B["transitions"].items():
            recs = []
            for st, off in spec.get("records", []):
                gs = graph_states.get(st)
                if gs is None:
                    self.errors.append(f"(e) transition {key}: state {st} not exported")
                    continue
                hit = [dict(t, source=st) for t in gs["transitions"] if t["record"] == off]
                if not hit:
                    self.errors.append(f"(e) transition {key}: record {off} not in state {st}")
                    continue
                recs.append(hit[0])
            row = {"from": spec["from"], "to": spec["to"], "when": spec["when"], "status": spec["status"]}
            if spec.get("why"):
                row["why"] = spec["why"]
            gname = spec.get("gate")
            variants = []
            for t in recs:
                vu = self.record_use(t)
                if gname and vu.get("gate_frames") is not None and abs(vu["gate_frames"] - gates[gname]["frames"]) < 1e-6:
                    vu["gate"] = gname
                v = {k: t[k] for k in ("record", "source", "target", "request", "fade_s", "byte_0x28", "flags_0x04",
                                       "scalar_0x20", "start_phase_0x24", "order", "condition_text")}
                v["conditions"] = [c["expr"] if c.get("expr") else None for c in t["conditions"]]
                v["use"] = vu
                variants.append(v)
            # full-body crouch change: its records need options.crouch_change_full_body; the change-move-mode
            # records of the same source state are the fallback when that option is off
            cc_sources = {v["source"] for v in variants if v["target"] == CROUCH_CHANGE_STATE}
            for v in variants:
                if v["target"] == CROUCH_CHANGE_STATE:
                    v["requires_option"] = "crouch_change_full_body"
                elif v["source"] in cc_sources and v["request"] == "change-move-mode":
                    v["when_option_off"] = "crouch_change_full_body"
            if recs:
                p = recs[0]
                row["graph"] = {k: p[k] for k in ("record", "source", "target", "request", "fade_s", "byte_0x28",
                                                  "flags_0x04", "scalar_0x20", "start_phase_0x24", "order")}
                row["graph"]["conditions"] = [c["expr"] if c.get("expr") else None for c in p["conditions"]]
                row["graph"]["condition_text"] = p["condition_text"]
            else:
                row["graph"] = None
            row["graph_variants"] = variants
            if spec["status"] == "graph":
                if not recs:
                    self.errors.append(f"(e) transition {key}: status graph without records")
                    use = {}
                else:
                    use = dict(variants[0]["use"])
                    if spec.get("row_use_keys"):
                        use = {k: v for k, v in use.items() if k in spec["row_use_keys"]}
                    if gname and use.get("gate") != gname:
                        self.errors.append(f"transition {key}: primary record {recs[0]['record']} has no "
                                           f"{gname} ({gates[gname]['frames']} frames) condition")
                    row["use_basis"] = ("primary record %s (%s) only; every record's own fade and gate are in "
                                        "graph_variants[].use" % (recs[0]["record"], recs[0]["source"]))
                    if spec.get("row_use_keys"):
                        row["use_basis"] += "; row use keeps only %s (%s)" % (", ".join(spec["row_use_keys"]),
                                                                             spec.get("row_use_why", ""))
                if spec.get("use"):
                    for k, v in spec["use"].items():
                        if k in use and abs(float(use[k]) - float(v)) > 1e-6:
                            self.errors.append(f"transition {key}: bindings use.{k}={v} but graph says {use[k]} "
                                               f"(graph rows must not restate a different value)")
                row["use"] = use
            else:
                if not spec.get("use"):
                    self.errors.append(f"transition {key}: status {spec['status']} needs a 'use' block")
                row["use"] = dict(spec.get("use", {}))
            row["overrides"] = sorted(over_by_key.get(key, []), key=lambda o: o["flag"])
            out[key] = row
        for tk in over_by_key:
            if tk not in out:
                self.errors.append(f"gameplay override refers to unknown transition key {tk}")

        # thresholds, derived from the records
        def num(expr, pattern):
            m = re.search(pattern, expr or "")
            return float(eval(m.group(1), {"__builtins__": {}})) if m else None  # noqa: S307 - digits only

        def rec(st, off):
            return [t for t in graph_states[st]["transitions"] if t["record"] == off][0]

        th = {}
        th["hemi_enter_deg"] = num(rec("idle", "0x0003f2c0")["conditions"][0]["expr"], r"absf\(move_dir_deg\) <= ([\d.]+)")
        th["hemi_to_bw_deg"] = num(rec("run-fw", "0x0002a880")["conditions"][0]["expr"], r"absf\(move_dir_deg\) > \(([\d.]+ \+ [\d.]+)\)")
        th["hemi_to_fw_deg"] = num(rec("run-bkwd", "0x00025230")["conditions"][0]["expr"], r"absf\(move_dir_deg\) < \(([\d.]+ - [\d.]+)\)")
        th["idle_turn_enter_deg"] = num(rec("idle", "0x0003f560")["conditions"][0]["expr"], r"idle_turn_deg > float\(([\d.]+)\)")
        th["idle_turn_exit_deg"] = num(rec("idle-turn-l", "0x00024c40")["conditions"][0]["expr"], r"idle_turn_deg < float\(([\d.]+)\)")
        th["turn_180_deg"] = num(rec("idle", "0x0003f260")["conditions"][0]["expr"], r"turn_delta_deg\) > float\(([\d.]+)\)")
        for k, v in B["expect_thresholds"].items():
            if th.get(k) is None or abs(th[k] - v) > 1e-6:
                self.errors.append(f"threshold {k}: derived {th.get(k)} != expected {v}")
        th["land_idle_exit_phase"] = {"soft": rec("fall-land-soft-idle", "0x00039910")["conditions"][0]["min"],
                                      "medium": rec("fall-land-medium-idle", "0x0002c200")["conditions"][0]["min"],
                                      "hard": rec("fall-land-hard-idle", "0x0002c200")["conditions"][0]["min"],
                                      "jump": rec("jump-long-land-idle", "0x0002fec0")["conditions"][0]["min"],
                                      "jump_med": rec("jump-long-land-idle-med", "0x0002fec0")["conditions"][0]["min"],
                                      "damage": rec("fall-land-damage-idle", "0x0003af30")["conditions"][0]["min"],
                                      "death": rec("fall-land-death", "0x00028590")["conditions"][0]["min"]}
        th["land_run_exit_phase"] = rec("fall-land-soft-run", "0x0003b680")["conditions"][0]["min"]
        th["land_run_bw_exit_phase"] = rec("fall-land-soft-run-bw", "0x0002dee0")["conditions"][0]["min"]
        bw = rec("fall-land-soft-run-bw", "0x0002de80")["conditions"]
        th["land_run_bw_early_exit_dir_deg"] = [bw[1]["min"], bw[1]["max"]]
        th["land_jump_run_exit_phase"] = rec("jump-long-land-run", "0x0003f730")["conditions"][0]["min"]
        early = rec("fall-land-soft-run", "0x0003b620")["conditions"]
        th["land_run_early_exit_dir_deg"] = early[1]["min"]
        th["land_move_gate"] = {"graph": gates["land_move_gate"]["graph_condition"],
                                "graph_value": rec("fall-land-soft-idle", "0x00039970")["conditions"][0]["min"],
                                "unit": gates["land_move_gate"]["unit"], "use_s": gates["land_move_gate"]["use_s"],
                                "override_s": 0.0, "override_flag": "override_immediate_land_move"}
        th["hit_full_exit_phase"] = rec("hit-reaction-full-body", "0x00040be0")["conditions"][0]["min"]
        th["hit_full_mode_change_gate"] = rec("hit-reaction-full-body", "0x00040bb0")["conditions"][0]["min"]
        th["hit_par_exit_phase"] = rec("hit-reaction-par", "0x000323b0")["conditions"][0]["min"]
        th["start_stop_min_phase"] = rec("idle^run-fwd", "0x0003beb0")["conditions"][0]["min"]
        th["reversal_begin_phase"] = rec("run-fw^run-bkwd-begin", "0x000301d0")["conditions"][0]["min"]
        th["turn_180_exit_phase"] = rec("idle-turn-l-180", "0x00029590")["conditions"][0]["min"]
        th["quick_turn_180_exit_phase"] = rec("quick-turn-180-r", "0x000408c0")["conditions"][0]["min"]
        th["crouch_change_exit_phase"] = {"moving": rec("crouch-change-idle^idle", "0x0003d180")["conditions"][0]["min"],
                                          "idle": rec("crouch-change-idle^idle", "0x0003d1b0")["conditions"][0]["min"]}
        th["reload_mid_finish_phase"] = rec("idle-shotgun-reload-mid-part", "0x000320f0")["conditions"][0]["min"]
        th["prefall_exit_phase"] = rec("pre-fall", "0x000209a0")["conditions"][0]["min"]
        th["jump_land_phase"] = rec("jump-long", "0x000256a0")["conditions"][0]["min"]
        th["sources"] = {"hemi_enter_deg": "idle 0x0003f2c0", "hemi_to_bw_deg": "run-fw 0x0002a880",
                         "hemi_to_fw_deg": "run-bkwd 0x00025230", "idle_turn_enter_deg": "idle 0x0003f560",
                         "idle_turn_exit_deg": "idle-turn-l 0x00024c40", "turn_180_deg": "idle 0x0003f260"}
        return out, th

    # ------------------------------------------------------------------ landing rule (proposed; code-chosen states)
    LANDING_STATE_RE = re.compile(r"^(fall-land-|jump-long-land-)|(-land|\^land)$")

    def landing_out(self, thresholds, roles):
        """bindings.landing plus checks: every role it names exists, every landing lower role is either selectable
        or listed as never selected, a missing role has a fallback, and every graph landing state is either
        exported as a lower role or listed in not_exported with a reason."""
        L = copy.deepcopy(self.B["landing"])
        E = self.errors
        lr = self.B["lower_roles"]
        bands, dirs = L.get("bands", {}), L.get("directions", {})
        selected = set()
        for kind, by_band in L.get("select", {}).items():
            for band, by_dir in by_band.items():
                if band not in bands:
                    E.append(f"landing.select.{kind}.{band}: unknown band")
                for d, rk in by_dir.items():
                    if d not in dirs:
                        E.append(f"landing.select.{kind}.{band}.{d}: unknown direction")
                    if rk not in lr:
                        E.append(f"landing.select.{kind}.{band}.{d}: unknown lower role {rk}")
                    selected.add(rk)
        fallback = L.get("fallback", {})
        never = L.get("never_selected", {})
        for rk in list(fallback) + list(fallback.values()) + list(never):
            if rk not in lr:
                E.append(f"landing: unknown lower role {rk}")
        land_roles = {rk for rk, spec in lr.items() if self.LANDING_STATE_RE.search(spec["state"])}
        for rk in sorted(land_roles - selected - set(never)):
            E.append(f"(f) landing role {rk} is neither selected by landing.select nor listed in landing.never_selected")
        for rk in sorted(selected):
            miss = sorted(k for k, r in roles.items() if k.split("/")[2] == rk and r["status"] == "missing")
            if miss and rk not in fallback:
                E.append(f"(f) landing role {rk} is missing ({miss[0]} ...) and has no landing.fallback")
        role_states = {spec["state"] for spec in lr.values()}
        graph_land = sorted({x["name"] for x in self.D["states"] if self.LANDING_STATE_RE.search(x["name"])})
        for st in graph_land:
            if st not in role_states and st not in L.get("not_exported", {}):
                E.append(f"(f) graph landing state {st} is neither a lower role nor in landing.not_exported")
        for st in L.get("not_exported", {}):
            if st not in self.states_by_name:
                E.append(f"landing.not_exported: {st} is not a graph state")
            elif st in role_states:
                E.append(f"landing.not_exported: {st} is exported as a lower role")
        g = 9.8
        L["derived"] = {"backward_deg": thresholds["hemi_enter_deg"], "backward_deg_source": "thresholds.hemi_enter_deg",
                        "jump_land_phase": thresholds["jump_land_phase"],
                        "jump_land_phase_source": "thresholds.jump_land_phase (jump-long 0x000256a0)",
                        "medium_drop_m": L["medium_impact_mps"] ** 2 / (2 * g),
                        "hard_drop_m": L["hard_impact_mps"] ** 2 / (2 * g), "drop_basis": "v^2 / (2 * 9.8 m/s^2)",
                        "graph_landing_states": graph_land}
        return L

    # ------------------------------------------------------------------ checks
    def coverage(self, roles, weapons, modes):
        cov = {}
        for w in weapons:
            for m in modes:
                c = {"resolved": 0, "substitute": [], "missing": [], "direct": []}
                for key, r in roles.items():
                    if not key.startswith(f"{w}/{m}/"):
                        continue
                    rk = key.split("/")[2]
                    if r["status"] == "resolved":
                        c["resolved"] += 1
                    else:
                        c.setdefault(r["status"], []).append(rk)
                for k in ("substitute", "missing", "direct"):
                    c[k] = sorted(c[k])
                cov[f"{w}/{m}"] = c
        return cov

    def carry_sig(self, role):
        return tuple((l["clip"], round(l["weight"], 6)) for l in role["layers"] if l["slot"] != "hands")

    def assertions(self, roles, aim_trees, actions, weapons, modes, graph_states, transitions):
        B = self.B
        E = self.errors
        # (a) bank leaves share one carry-layer set
        for w in weapons:
            for m in modes:
                for bank in ("move_fw", "move_bw"):
                    sigs = {self.carry_sig(roles[f"{w}/{m}/{rk}"]) for rk in B["bank_roles"][bank]}
                    if len(sigs) > 1:
                        E.append(f"(a) {w}/{m} bank {bank}: direction leaves carry different layers {sigs}")
                allsig = {self.carry_sig(roles[f"{w}/{m}/{rk}"]) for rk in B["bank_roles"]["move_fw"] + B["bank_roles"]["move_bw"]}
                if len(allsig) > 1:
                    E.append(f"(a) {w}/{m}: fw and bw banks carry different layers")
                for bank in ("start_fw", "start_bw", "stop_fw", "stop_bw", "rev_fw_bw", "rev_bw_fw"):
                    sigs = {self.carry_sig(roles[f"{w}/{m}/{rk}"]) for rk in B["bank_roles"][bank]}
                    if len(sigs) > 1:
                        self.warn(f"(a') {w}/{m} bank {bank}: the direction leaves carry different carry layers "
                                  f"(graph data; a runtime bank for this state needs per-leaf layer stacks)")
        # (b) idle layers identical for walk/run/sprint
        for w in weapons:
            sigs = {tuple((l["clip"], round(l["weight"], 6)) for l in roles[f"{w}/{m}/idle"]["layers"])
                    for m in ("walk", "run", "sprint")}
            if len(sigs) > 1:
                E.append(f"(b) {w}: idle layers differ across walk/run/sprint")
        # (c) leaf additive kind invariant across selections
        kinds = collections.defaultdict(set)
        for key, r in roles.items():
            if r["clip"]:
                kinds[key.split("/")[2]].add(r["additive"])
        for key, t in aim_trees.items():
            for slot, r in t.items():
                if slot != "hands" and r["clip"]:
                    kinds["aim." + slot].add(r["additive"])
        for rk, v in kinds.items():
            if len(v) > 1:
                E.append(f"(c) role {rk}: additive kind varies across selections")
        # (d) every clip exists in the dump
        for a in self.clips:
            if a not in self.lib:
                E.append(f"(d) clip {a} not in library dump")
        # (f) only allowed roles missing
        allowed = B["allowed_missing"]
        for key, r in roles.items():
            if r["status"] == "missing" and not glob_match(key, allowed):
                E.append(f"(f) role {key} missing ('{r['graph_clip']}') and not in allowed_missing")
        for key, t in aim_trees.items():
            for slot, r in t.items():
                if r["status"] == "missing":
                    E.append(f"(f) aim_trees {key}.{slot} missing")
        for key, a in actions.items():
            if a["status"] == "missing" and not glob_match(key, allowed):
                E.append(f"(f) action {key} missing and not in allowed_missing")
        tb = B.get("throw") or {}
        for ctx, row in (self.throw_rows or {}).items():
            for part, r in row["parts"].items():
                if r["status"] == "missing" and part not in tb.get("allowed_missing", []):
                    E.append(f"(f) throw {ctx}.{part} missing and not in throw.allowed_missing")
        # state-level substitutions ('00 02') must not touch kept states
        for key, r in roles.items():
            if r["state_substitutions"]:
                E.append(f"'00 02' state substitution applies to {key}: {r['state_substitutions']}")
        # override rows must not claim graph status without a record
        for key, row in transitions.items():
            if row["status"] == "graph" and not row["graph"]:
                E.append(f"transition {key} labelled graph without a record")

    # ------------------------------------------------------------------ frontier comparison
    def parse_weapon_tables(self):
        wdir = os.path.join(FR_ROOT, "scripts", "weapons")
        tables = {}
        for w in ("bow", "musket", "pistol"):
            p = os.path.join(wdir, w + ".gd")
            if not os.path.exists(p):
                continue
            with open(p, encoding="utf-8") as fh:
                txt = fh.read()
            t = {"relaxed": {}, "clips": {}}
            m = re.search(r"\brelaxed\s*=\s*\{(.*?)\n\s*\}", txt, re.S)
            if m:
                for k, c, wv in re.findall(r'"(\w+)"\s*:\s*\[\s*"([^"]+)"\s*,\s*([\d.]+)\s*\]', m.group(1)):
                    t["relaxed"][k] = [c, float(wv)]
            m = re.search(r"\bclips\s*=\s*\{(.*?)\n\s*\}", txt, re.S)
            if m:
                for k, c in re.findall(r'"(\w+)"\s*:\s*"([^"]+)"', m.group(1)):
                    t["clips"][k] = c
            tables[w] = t
        return tables

    def frontier_diff(self, roles, aim_trees, aim_move, actions, runtime_clips, grips):
        tables = self.parse_weapon_tables()
        self.frontier_tables_sha = sha256_bytes(json.dumps(tables, sort_keys=True).encode())
        bands = {"idle": ("run", "idle"), "walk": ("walk", "fw"), "run": ("run", "fw"), "sprint": ("sprint", "fw"),
                 "crouch_idle": ("crouch", "idle"), "crouch_walk": ("crouch", "fw")}
        relaxed = []
        for w, t in sorted(tables.items()):
            for band, (m, rk) in bands.items():
                role = roles.get(f"{w}/{m}/{rk}")
                if role is None:
                    continue
                graph = [[l["clip"], l["weight"], l["slot"], l["kind"]] for l in role["layers"]
                         if l["slot"] not in ("hands",) and not l.get("excluded")]
                fr = t["relaxed"].get(band)
                same = bool(fr) and any(g[0] == fr[0] and abs(g[1] - fr[1]) < 1e-6 for g in graph) and \
                    len([g for g in graph if g[2] in ("arms", "other_partial")]) <= 1
                relaxed.append({"weapon": w, "band": band, "role": f"{w}/{m}/{rk}", "frontier": fr, "graph": graph,
                                "match": same})
        clipdiff = []
        for w, t in sorted(tables.items()):
            for k, c in sorted(t["clips"].items()):
                st = "crouch" if k.endswith("_crouch") else "stand"
                base = k[:-len("_crouch")] if k.endswith("_crouch") else k
                g = None
                where = None
                grole = None
                at = aim_trees.get(f"{w}/{st}", {})
                if base in ("aim", "up", "down", "hands"):
                    slot = {"aim": "base"}.get(base, base)
                    g = at.get(slot, {}).get("clip")
                    grole = at.get(slot) if slot != "hands" else None
                    where = f"aim_trees.{w}/{st}.{slot}"
                elif base == "fire":
                    g = runtime_clips["fire"].get(f"{w}/{st}")
                    where = f"runtime_clips.fire.{w}/{st}"
                elif base == "charge":
                    g = runtime_clips["charge"].get(f"{w}/{st}")
                    where = f"runtime_clips.charge.{w}/{st}"
                elif base in ("reload_begin", "reload_mid", "reload_end", "equip", "nock"):
                    a = actions.get(f"{w}/{st}/{base}")
                    g = a["partial"] if a else None
                    grole = a["partial_role"] if a else None
                    where = f"actions.{w}/{st}/{base}"
                elif base == "grab":
                    a = actions.get(f"{w}/{st}/nock")
                    g = a["partial"] if a else None
                    grole = a["partial_role"] if a else None
                    where = f"actions.{w}/{st}/nock (Frontier 'grab' = arrow take)"
                elif base == "aim_walk":
                    am = aim_move.get(f"{w}/{st}", {})
                    g = am.get("fw", {}).get("clip")
                    where = f"aim_move.{w}/{st}.fw (prefix)"
                    clipdiff.append({"weapon": w, "key": k, "frontier": c, "graph": g, "where": where,
                                     "match": bool(g) and g.startswith(c)})
                    continue
                row = {"weapon": w, "key": k, "frontier": c, "graph": g, "where": where, "match": g == c}
                if grole is not None and grole.get("chain"):
                    row["graph_chain"] = ["%s %s: %s -> %s" % (x["set"].replace("anim-overlay-player-", ""),
                                                              x["record_offset"], x["from"], x["to"]) for x in grole["chain"]]
                if grole is not None and grole.get("resolution") == "ambiguous":
                    row["resolution"] = "ambiguous"
                    row["resolver"] = grole["resolver"]
                    row["resolver_alternatives"] = {k2: v2["clip"] for k2, v2 in grole["resolver_alternatives"].items()}
                if g != c:
                    row["frontier_clip_evidence"] = self.remap_evidence(c, 4)
                clipdiff.append(row)
        return {"relaxed_table_diff": relaxed, "clip_table_diff": clipdiff,
                "weapon_tables_sha256": self.frontier_tables_sha,
                "note": "Frontier's Weapon.relaxed / Weapon.clips tables are not used by the graph-driven PlayerAnim; "
                        "this compares them with the graph-resolved clips. relaxed_table_diff.match is true when "
                        "Frontier's single [clip, weight] equals the graph's only partial arms layer (graph additives "
                        "are listed). clip_table_diff.frontier_clip_evidence lists the overlay records that produce "
                        "Frontier's clip where it differs from the graph's choice for that state."}

    def remap_evidence(self, action, limit):
        """Overlay records whose target is this clip, each with the records that produce its source ('via',
        one level back), so the whole authored chain is visible."""
        names = {action}
        if action in self.lib:
            sn = (self.lib[action].get("meta") or {}).get("source_names")
            if sn:
                names |= set(json.loads(sn))
        ev = []
        for setname in sorted(self.db.sets):
            for r in self.db.sets[setname]["remaps"]:
                if r["to_clip"] in names:
                    via = []
                    for sn2 in sorted(self.db.sets):
                        for p in self.db.sets[sn2]["remaps"]:
                            if p["to_id"] == r["from_id"] and p["from_id"] != p["to_id"]:
                                via.append({"set": sn2, "record_offset": p["offset"], "from": p["from_clip"],
                                            "to": p["to_clip"], "flags": p["raw_flags"]})
                    ev.append({"set": setname, "record_offset": r["offset"], "from": r["from_clip"], "to": r["to_clip"],
                               "flags": r["raw_flags"], "via": via[:4]})
        return ev[:limit]

    # ------------------------------------------------------------------ provenance
    def input_hashes(self):
        h = {k: sha256_file(p) for k, p in self.paths.items()}
        h["FR/scripts/weapons/{bow,musket,pistol}.gd#relaxed+clips tables (canonical JSON)"] = getattr(
            self, "frontier_tables_sha", None) or sha256_bytes(json.dumps(self.parse_weapon_tables(), sort_keys=True).encode())
        return h

    def vendor_hashes(self):
        out = {}
        for f in sorted(os.listdir(VENDOR)):
            if f.endswith(".py"):
                out[f] = sha256_file(os.path.join(VENDOR, f))
        return out


# --------------------------------------------------------------------------- fixture
def make_fixture(full, weapon="musket", modes=("run", "crouch")):
    fx = copy.deepcopy(full)
    stances = sorted({full["modes"][m]["stance"] for m in modes})
    keep = lambda k, n: k.split("/")[0] == weapon and (n < 2 or k.split("/")[1] in modes)  # noqa: E731
    fx["profiles"] = {weapon: full["profiles"][weapon]}
    fx["modes"] = {m: full["modes"][m] for m in modes}
    fx["selections"] = {k: v for k, v in full["selections"].items() if keep(k, 2)}
    fx["roles"] = {k: v for k, v in full["roles"].items() if keep(k, 2)}
    fx["aim_trees"] = {k: v for k, v in full["aim_trees"].items() if keep(k, 1) and k.split("/")[1] in stances}
    fx["aim_move"] = {k: v for k, v in full["aim_move"].items() if keep(k, 1) and k.split("/")[1] in stances}
    fx["hand_states"] = {k: v for k, v in full["hand_states"].items() if keep(k, 1) and k.split("/")[1] in stances}
    fx["crouch_change"] = {k: v for k, v in full["crouch_change"].items() if keep(k, 1)}
    fx["grips"] = {weapon: full["grips"][weapon]}
    wl = fx["weapon_layers"]
    wl["weapon_out"]["clips"] = {k: v for k, v in wl["weapon_out"]["clips"].items()
                                 if k.split("/")[0] == weapon and k.split("/")[1] in stances}
    wl["prop_bones"] = {weapon: wl["prop_bones"][weapon]}
    fx["actions"] = {k: v for k, v in full["actions"].items() if keep(k, 1) and k.split("/")[1] in stances}
    fx["runtime_roles"] = {g: {k: v for k, v in rr.items() if keep(k, 2 if k.count("/") == 2 else 1)
                               and (k.count("/") == 2 or k.split("/")[1] in stances)}
                           for g, rr in full["runtime_roles"].items()}
    rc = fx["runtime_clips"]
    rc["fire"] = {k: v for k, v in rc["fire"].items() if k.startswith(weapon + "/")}
    rc["charge"] = {k: v for k, v in rc["charge"].items() if k.startswith(weapon + "/")}
    fx["frontier"] = {"relaxed_table_diff": [r for r in full["frontier"]["relaxed_table_diff"] if r["weapon"] == weapon],
                      "clip_table_diff": [r for r in full["frontier"]["clip_table_diff"] if r["weapon"] == weapon],
                      "weapon_tables_sha256": full["frontier"]["weapon_tables_sha256"], "note": full["frontier"]["note"]}
    # clips: only the referenced ones
    txt = json.dumps({k: v for k, v in fx.items() if k != "clips"})
    fx["clips"] = {k: v for k, v in full["clips"].items() if ('"%s"' % k) in txt}
    cov = full["meta"]["coverage"]
    fx["meta"] = dict(full["meta"])
    fx["meta"]["coverage"] = {k: v for k, v in cov.items() if keep(k, 2)}
    fx["meta"]["resolver_disagreements"] = [d for d in full["meta"]["resolver_disagreements"]
                                            if (".%s/" % weapon) in d["where"]]
    fx["meta"]["fixture"] = {"of": "animations/actor_b_graph.json", "weapons": [weapon], "modes": list(modes),
                             "note": "day-1 contract fixture: 1 weapon x 2 modes, same schema as the full export"}
    return norm_floats(fx)


# --------------------------------------------------------------------------- report
def make_report(g):
    L = []
    a = L.append
    a("# Actor_B animation graph export report")
    a("")
    a("Generated by `%s` (schema %d, resolver `%s`). Do not edit by hand." % (g["meta"]["generator"], g["meta"]["schema"], g["meta"]["resolver"]))
    a("")
    a("**Authorization.** %s." % g["meta"]["authorization"])
    a("")
    a("**Fidelity policy.** %s." % g["meta"]["fidelity_policy"])
    a("")
    a("## Inputs")
    a("")
    a("| Input | sha256 |")
    a("|---|---|")
    for k, v in sorted(g["meta"]["generated_from"].items()):
        a("| `%s` | `%s` |" % (k, v))
    for k, v in sorted(g["meta"]["vendored"].items()):
        a("| vendored `%s` | `%s` |" % (k, v))
    a("")
    a("## Coverage (lower-body roles per weapon x mode)")
    a("")
    a("| weapon/mode | resolved | direct | substitute | missing |")
    a("|---|---|---|---|---|")
    for k, c in sorted(g["meta"]["coverage"].items()):
        a("| %s | %d | %s | %s | %s |" % (k, c["resolved"], ", ".join(c["direct"]) or "-", ", ".join(c["substitute"]) or "-",
                                         ", ".join(c["missing"]) or "-"))
    a("")
    a("Allowed missing: `%s`." % "`, `".join(g["allowed_missing"]))
    a("")
    a("## Lower-body roles (clip and carry layers)")
    a("")
    for w in sorted(g["profiles"]):
        a("### %s" % w)
        a("")
        a("| mode/role | state | clip | status | layers (clip@weight slot) |")
        a("|---|---|---|---|---|")
        for key in sorted(k for k in g["roles"] if k.startswith(w + "/")):
            r = g["roles"][key]
            lay = "; ".join("%s%s@%s %s%s%s" % (l["clip"] or ("MISSING " + l["graph_clip"]),
                                               "@%ss" % l["sample_s"] if l.get("sample_s") is not None else "", l["weight"], l["slot"],
                                               " (curve)" if l.get("weight_curve") else "",
                                               " [%s]" % l["status"] if l.get("status") in ("frontier", "substitute") else "")
                            for l in r["layers"])
            a("| %s | %s | %s | %s | %s |" % ("/".join(key.split("/")[1:]), r["state"], r["clip"] or ("`%s`" % r["graph_clip"]),
                                              r["status"], lay or "-"))
        a("")
    a("## Aim trees")
    a("")
    a("| weapon/stance | base | up | down | blocked | arms_relaxed | hands |")
    a("|---|---|---|---|---|---|---|")
    for k, t in sorted(g["aim_trees"].items()):
        a("| %s | %s |" % (k, " | ".join(str(t[s]["clip"]) for s in ("base", "up", "down", "blocked", "arms_relaxed", "hands"))))
    a("")
    a("## Grips")
    a("")
    a("| weapon | carry | aim stand | aim crouch |")
    a("|---|---|---|---|")
    for w, gr in sorted(g["grips"].items()):
        a("| %s | %s | %s | %s |" % (w, gr["carry"], gr["aim_stand"], gr["aim_crouch"]))
    a("")
    a("## Actions")
    a("")
    a("| key | state | partial | twin | loop | status |")
    a("|---|---|---|---|---|---|")
    for k, v in sorted(g["actions"].items()):
        extra = ""
        if v.get("by_mode"):
            extra = " (by mode: %s)" % ", ".join("%s=%s" % (m, x["partial"]) for m, x in sorted(v["by_mode"].items()))
        a("| %s | %s | %s%s | %s | %s | %s |" % (k, v["state"], v["partial"] or ("`%s`" % v["partial_role"]["graph_clip"]), extra,
                                                  v["twin"] or "-", v["loop"], v["status"]))
    a("")
    if g.get("throw"):
        th = g["throw"]
        a("## Thrown weapons (throw chain)")
        a("")
        a(th["about"])
        a("")
        a("Release frame: %s s into `%s` at 1x (%s)." % (th["release"]["clip_s"], th["release"]["part"], th["release"]["source"]))
        a("")
        a("| profile/stance | part | state | clip | status | layers | chain |")
        a("|---|---|---|---|---|---|---|")
        for ctx, row in sorted(th["rows"].items()):
            for part in ("raise", "start", "end", "recover", "recover_aim"):
                r = row["parts"].get(part)
                if r is None:
                    continue
                lay = "; ".join("%s@%s %s" % (l["clip"], l["weight"], l["slot"]) for l in r["layers"] if l["clip"])
                ch = ", ".join("%s %s" % (c["set"].replace("anim-overlay-player-", ""), c["record_offset"]) for c in r["chain"])
                a("| %s | %s | %s | %s | %s | %s | %s |" % (ctx, part, r["state"], r["clip"] or ("`%s`" % r["graph_clip"]),
                                                          r["status"], lay or "-", ch or "-"))
        a("")
        for part, note in sorted(th.get("missing_notes", {}).items()):
            a("- missing `%s`: %s" % (part, note))
        a("")
    if g.get("carry_overrides", {}).get("rows"):
        co = g["carry_overrides"]
        a("## Frontier carry overrides (THROW2)")
        a("")
        a(co["about"])
        a("")
        a("| pose | clip @ time | slot | bones | native_asset_id | why |")
        a("|---|---|---|---|---|---|")
        for name, p in sorted(co["poses"].items()):
            a("| %s | %s @ %s s | %s | %d | %s | %s |" % (name, p["clip"], p["sample_s"], p["slot"], len(p["bones"]),
                                                        p["native_asset_id"], p["why"]))
        a("")
        a("| row | modes | replaces | from profile | poses | roles | why |")
        a("|---|---|---|---|---|---|---|")
        for w, rows in sorted(co["rows"].items()):
            for r in rows:
                fp = (r["from_profile"] or {}).get("weapon-base", "-") if r["from_profile"] else "-"
                a("| %s | %s%s | %s | %s | %s | %d | %s |" % (
                    r["row"], ", ".join(r["modes"]), ((" (not %s)" % ", ".join(r["roles_except"])) if r["roles_except"] else "")
                    + ((" (only %s)" % ", ".join(r["roles_only"])) if r.get("roles_only") is not None else ""),
                    ", ".join(r["replace"]), fp.replace("anim-overlay-player-", ""),
                    ", ".join("%s@%s" % (x[0], x[1]) for x in r["poses"]) or "-", r["roles"], r["why"]))
        a("")
    if g.get("action_overrides", {}).get("rows"):
        ao = g["action_overrides"]
        a("## Frontier action clip substitutions (THROW2)")
        a("")
        a(ao["about"])
        a("")
        a("| action | state | partial | twin | replaced | evidence | why |")
        a("|---|---|---|---|---|---|---|")
        for k, r in sorted(ao["rows"].items()):
            ev = "; ".join("%s %s: %s" % (part, x["graph_clip"], ", ".join("%s %s" % (c["set"].replace("anim-overlay-player-", ""),
                                                                                      c["record_offset"]) for c in x["chain"]))
                           for part, x in sorted(r["evidence"].items()))
            a("| %s | %s | %s | %s | %s / %s | %s | %s |" % (k, r["state"], r["partial"], r["twin"], r["replaced"]["partial"],
                                                             r["replaced"]["twin"], ev, r["why"]))
        a("")
    a("## Crouch change")
    a("")
    a("Full body plays by default (`options.crouch_change_full_body` = %s): %s" % (
        str(g["options"]["crouch_change_full_body"]).lower(), g["options_notes"]["crouch_change_full_body"]))
    a("")
    for k, v in sorted(g["crouch_change"].items()):
        a("- %s: full body %s (%s), additive %s (%s)" % (k, v["full"]["clip"], v["full"]["status"], v["add"]["clip"], v["add"]["status"]))
    a("")
    a("## Resolver disagreements")
    a("")
    a(g["meta"]["resolver_note"])
    a("")
    pol = g["meta"]["resolver_policy"]
    a("Export loop `%s` (compared with `%s`): %s" % (pol["loop"], pol["compare"], pol["why"]))
    a("")
    for x in pol["evidence"]:
        a("- %s" % x)
    a("")
    a("| where | asc_fix | asc_once | used | basis | why |")
    a("|---|---|---|---|---|---|")
    for d in g["meta"]["resolver_disagreements"]:
        a("| %s | %s | %s | %s | %s | %s |" % (d["where"], d["asc_fix"]["clip"] or d["asc_fix"]["graph_clip"],
                                              d["asc_once"]["clip"] or d["asc_once"]["graph_clip"], d["chosen"],
                                              d["basis"], d["why"]))
    a("")
    a("Resolver exceptions (the other loop on purpose, to keep a behaviour Frontier has today):")
    a("")
    for e in g["meta"]["resolver_exceptions"]:
        a("- `%s` uses %s instead of the export loop %s (%s). Graph result: %s (%s); used: %s. Roles whose only "
          "full-weight prop driver this choice supplies: %d. Disable it in bindings.resolver_choices to export the graph "
          "result; (g) then exempts %s." % (
              e["where"], e["use"], e["export_loop"], e["requirement"], e["graph_result"]["clip"] or e["graph_result"]["graph_clip"],
              e["graph_result"]["status"], e["used_result"]["clip"], e["prop_full_weight_only_via_this_choice"]["count"],
              ", ".join("`%s`" % p for p in e["prop_exempt_when_disabled"]) or "nothing"))
    if not g["meta"]["resolver_exceptions"]:
        a("- none")
    a("")
    a("## Weapon layers and prop bones")
    a("")
    wl = g["weapon_layers"]
    for x in wl["order"]:
        a("- %s" % x)
    a("")
    wo = wl["weapon_out"]
    a("Weapon-out fingers (`%s`, state `%s` %s, entered by %s, default on: %s, weight %s: %s). %s" % (
        wo["option"], wo["state"], wo["state_offset"], wo["entered_by"], str(wo["default_on"]).lower(), wo["weight"],
        wo["weight_source"], wo["applies_to"]))
    a("")
    a("Applies when: %s" % wo["apply_rule_why"])
    a("")
    a("| weapon/stance | weapon-out clip | applies | why | keys prop bones | resolution |")
    a("|---|---|---|---|---|---|")
    for k, c in sorted(wo["clips"].items()):
        a("| %s | %s | %s | %s | %s | %s%s |" % (k, c["clip"], str(c["applies"]).lower(), c["applies_why"],
                                               ", ".join(c["prop_bones_keyed"]) or "-", c["resolution"],
                                               (" (%s, %s)" % (c["resolver"], c["resolver_basis"])) if c.get("resolver") else ""))
    a("")
    for x in wl["notes"]:
        a("- %s" % x)
    a("")
    a("Prop-bone coverage under the default options (roles whose weapon prop bone has a full-weight driver / exempt):")
    a("")
    a("| weapon/mode | full weight | exempt | drivers (example role fw) |")
    a("|---|---|---|---|")
    for w in sorted(g["profiles"]):
        for m in sorted(g["modes"]):
            rs = {k: r for k, r in g["roles"].items() if k.startswith("%s/%s/" % (w, m))}
            full = sum(1 for r in rs.values() if r["prop"]["full_weight"])
            ex = sorted(k.split("/")[2] for k, r in rs.items() if r["prop"].get("exempt"))
            fw = rs.get("%s/%s/fw" % (w, m))
            drv = "; ".join("%s@%s (%s)" % (d["clip"], d["min_weight"], d["source"]) for d in fw["prop"]["drivers"]) if fw else "-"
            a("| %s/%s | %d/%d | %s | %s |" % (w, m, full, len(rs), ", ".join(ex) or "-", drv))
    a("")
    a("## Landing selection (proposed)")
    a("")
    LD = g["landing"]
    a(LD["why"])
    a("")
    a("Bands: soft < %s m/s (%.2f m drop) <= medium < %s m/s (%.2f m) <= hard; jump window %s s after jump-long; "
      "backward when |move_dir_deg| > %s." % (LD["medium_impact_mps"], LD["derived"]["medium_drop_m"], LD["hard_impact_mps"],
                                              LD["derived"]["hard_drop_m"], LD["jump_land_window_s"], LD["derived"]["backward_deg"]))
    a("")
    a("| kind/band | idle | idle_early | run | run_bw |")
    a("|---|---|---|---|---|")
    for kind, by_band in sorted(LD["select"].items()):
        for band in ("soft", "medium", "hard"):
            if band not in by_band:
                continue
            d = by_band[band]
            cells = []
            for dk in ("idle", "idle_early", "run", "run_bw"):
                rk = d.get(dk)
                if not rk:
                    cells.append("-")
                    continue
                r = g["roles"].get("musket/run/" + rk)
                st = r["state"] if r else "?"
                clip = (r["clip"] or ("MISSING -> " + LD["fallback"].get(rk, "?"))) if r else "?"
                cells.append("%s (%s: %s)" % (rk, st, clip))
            a("| %s/%s | %s |" % (kind, band, " | ".join(cells)))
    a("")
    a("Clips shown for musket/run; every weapon x mode has its own resolved role. Fallbacks: %s. Never selected: %s." % (
        ", ".join("%s -> %s" % kv for kv in sorted(LD["fallback"].items())) or "-",
        "; ".join("%s (%s)" % kv for kv in sorted(LD["never_selected"].items())) or "-"))
    a("")
    for k, v in sorted(LD["select_why"].items()):
        a("- %s: %s" % (k, v))
    a("")
    a("Graph landing states not exported:")
    a("")
    for k, v in sorted(LD["not_exported"].items()):
        a("- `%s`: %s" % (k, v))
    a("")
    a("## Transitions")
    a("")
    a("Every runtime rule, with its graph record. `use` is the default (graph-faithful) value of the row's primary "
      "record only; each record's own values are listed under Transition variants. Overrides are opt-in flags.")
    a("")
    a("| key | from -> to | when | status | graph record (fade) | use | opt-in overrides |")
    a("|---|---|---|---|---|---|---|")
    for k, t in sorted(g["transitions"].items()):
        gr = "-" if not t["graph"] else "%s `%s` %s (%g)" % (t["graph"]["source"], t["graph"]["record"], t["graph"]["request"], t["graph"]["fade_s"])
        if len(t["graph_variants"]) > 1:
            gr += " +%d variants" % (len(t["graph_variants"]) - 1)
        use = ", ".join("%s=%s" % (kk, vv) for kk, vv in sorted(t["use"].items()))
        ov = "; ".join("%s (%s): %s" % (o["flag"], o["rule"], ", ".join("%s=%s" % (kk, vv) for kk, vv in sorted(o.items())
                                                                       if kk not in ("flag", "rule", "why")))
                       for o in t["overrides"]) or "-"
        a("| %s | %s -> %s | %s | %s | %s | %s | %s |" % (k, t["from"], t["to"], t["when"], t["status"], gr, use, ov))
    a("")
    a("## Transition variants (per record)")
    a("")
    a("| key | source | record | request -> target | condition | use |")
    a("|---|---|---|---|---|---|")
    for k, t in sorted(g["transitions"].items()):
        for v in t["graph_variants"]:
            a("| %s | %s | `%s` | %s -> %s | %s | %s |" % (k, v["source"], v["record"], v["request"], v["target"],
                                                          v["condition_text"],
                                                          ", ".join("%s=%s" % (kk, vv) for kk, vv in sorted(v["use"].items())
                                                                    if kk != "gate_basis")))
    a("")
    a("## Graph records not bound to a runtime row")
    a("")
    a("Records of the exported states that no `transitions` row lists (cover, peek, throw, vault and avoid-fall "
      "targets are outside Frontier's scope; the rest are code requests whose trigger is not in the data).")
    a("")
    bound = {(v["source"], v["record"]) for t in g["transitions"].values() for v in t["graph_variants"]}
    for n, st in sorted(g["graph_states"].items()):
        un = [t for t in st["transitions"] if (n, t["record"]) not in bound]
        if un:
            a("- %s: %s" % (n, "; ".join("`%s` %s -> %s (%g)%s" % (
                t["record"], t["request"], t["target"], t["fade_s"],
                " [out of scope]" if re.search(r"(cover|peek|throw|vault|avoid-fall)", t["target"]) else "") for t in un)))
    a("")
    a("## Gameplay overrides (all default off)")
    a("")
    for k, o in sorted(g["gameplay_overrides"].items()):
        a("- `%s` (%s, default %s): %s" % (k, o["rule"], str(o["default"]).lower(), o["why"]))
    a("")
    a("## Tuning (no graph record)")
    a("")
    a(g["tuning_notes"].get("_about", ""))
    a("")
    for k, v in sorted(g["tuning"].items()):
        n = g["tuning_notes"].get(k, {})
        a("- `%s` = %s (%s): %s" % (k, json.dumps(v, sort_keys=True), n.get("status", "?"), n.get("why", "")))
    a("")
    a("## Proposed values (no graph record)")
    a("")
    for k, t in sorted(g["transitions"].items()):
        if t["status"] != "graph":
            a("- `%s`: %s (%s)" % (k, ", ".join("%s=%s" % kv for kv in sorted(t["use"].items())), t.get("why", "")))
    a("- landing kind: %s" % g["landing"]["why"])
    a("")
    a("## Thresholds (derived from the records)")
    a("")
    for k, v in sorted(g["thresholds"].items()):
        if k != "sources":
            a("- `%s`: %s" % (k, json.dumps(v, sort_keys=True)))
    a("")
    a("## Frontier comparison: Weapon.relaxed vs graph carry layers")
    a("")
    a("| weapon | band | Frontier | graph (non-hands layers) | match |")
    a("|---|---|---|---|---|")
    for r in g["frontier"]["relaxed_table_diff"]:
        a("| %s | %s | %s | %s | %s |" % (r["weapon"], r["band"], r["frontier"],
                                          "; ".join("%s@%s %s" % (x[0], x[1], x[2]) for x in r["graph"]) or "(none)", r["match"]))
    a("")
    a("## Frontier comparison: Weapon.clips vs graph")
    a("")
    a("| weapon | key | Frontier | graph | where | match | notes |")
    a("|---|---|---|---|---|---|---|")
    for r in g["frontier"]["clip_table_diff"]:
        notes = []
        if r.get("resolution") == "ambiguous":
            notes.append("ambiguous resolution: %s used, alternatives %s; graph chain %s" % (
                r["resolver"], ", ".join("%s=%s" % kv for kv in sorted(r["resolver_alternatives"].items())),
                " / ".join(r.get("graph_chain", []))))
        if r.get("frontier_clip_evidence"):
            evs = []
            for e in r["frontier_clip_evidence"]:
                via = ", ".join("%s `%s`: %s -> %s" % (x["set"].replace("anim-overlay-player-", ""), x["record_offset"],
                                                       x["from"], x["to"]) for x in e.get("via", []))
                evs.append("%s `%s`: %s -> %s%s" % (e["set"].replace("anim-overlay-player-", ""), e["record_offset"],
                                                    e["from"], e["to"], (" (fed by %s)" % via) if via else ""))
            notes.append("Frontier's clip is produced by: " + "; ".join(evs))
        elif r["graph"] != r["frontier"] and r["key"] != "aim_walk" and not r["key"].startswith("aim_walk"):
            notes.append("no overlay record targets Frontier's clip (a Frontier choice, not a graph resolution)")
            if r.get("graph_chain"):
                notes.append("graph chain: " + " / ".join(r["graph_chain"]))
        a("| %s | %s | %s | %s | %s | %s | %s |" % (r["weapon"], r["key"], r["frontier"], r["graph"], r["where"], r["match"],
                                                   "; ".join(notes) or "-"))
    a("")
    a(g["frontier"]["note"])
    a("")
    a("## Warnings")
    a("")
    for w in g["meta"]["warnings"]:
        a("- %s" % w)
    a("")
    return "\n".join(L)


# --------------------------------------------------------------------------- main
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--pap", default=os.environ.get("ANIM_GRAPH_PAP", DEFAULT_PAP))
    ap.add_argument("--out", default=os.path.join(FR_ROOT, "animations", "actor_b_graph.json"))
    ap.add_argument("--report", default=os.path.join(FR_ROOT, "animations", "actor_b_graph_report.md"))
    ap.add_argument("--fixture", default=os.path.join(HERE, "fixtures", "mini_graph.json"))
    ap.add_argument("--bindings", default=None)
    ap.add_argument("--check", action="store_true", help="rebuild in memory; fail unless outputs are up to date")
    a = ap.parse_args(argv)
    try:
        ex = Exporter(a.pap, a.bindings)
        g = ex.build()
    except ExportError as e:
        print("EXPORT FAILED: %s" % e, file=sys.stderr)
        return 1
    files = {a.out: dumps(g), a.report: make_report(g), a.fixture: dumps(make_fixture(g))}
    if a.check:
        bad = []
        for p, txt in files.items():
            cur = None
            if os.path.exists(p):
                with open(p, encoding="utf-8") as fh:
                    cur = fh.read()
            if cur != txt:
                bad.append(p)
        if bad:
            print("CHECK FAILED: out of date: %s" % ", ".join(bad), file=sys.stderr)
            return 2
        print("CHECK OK: %d roles, %d clips, %d transitions, %d warnings; outputs up to date"
              % (len(g["roles"]), len(g["clips"]), len(g["transitions"]), len(g["meta"]["warnings"])))
        return 0
    for p, txt in files.items():
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as fh:
            fh.write(txt)
    print("wrote %s (%d roles, %d clips, %d transitions, %d warnings)" % (a.out, len(g["roles"]), len(g["clips"]),
                                                                         len(g["transitions"]), len(g["meta"]["warnings"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
