#!/usr/bin/env python3
"""Overlay clip-name resolver for the extracted player animation graph.

Read-only over /Users/kiwimango/Downloads/Player_Animation_Project.

Record model (20-byte remap record, stride 0x14 in the source modules):
    +0x00 from_id   32-bit symbol id (clip id, or state id when flags byte1 & 0x02)
    +0x04 to_id     32-bit symbol id of the replacement / added clip
    +0x08 raw_0x08  always 0 in all 10,382 records
    +0x0c raw_0x0c  optional pointer to a 24-byte parameter block (only ever set on
                    "layer" records plus 1 state-keyed record); contents not exported
    +0x10 flags     byte0 bit0 = LAYER (adds to_clip as an extra partial/additive
                    layer, key may repeat), byte0 bit1 = (3 records, random pick?),
                    byte1 bit1 (0x02) = key is a STATE id not a clip id,
                    byte1 bit3 (0x08) = unknown (3 records, additive aim-over)

Keys are matched by exact 32-bit id only (ids are hashes, so no wildcard / prefix
matching is possible).  Substitution keys are unique per set (verified).

Evidence summary (see measure*.py / order_test.py / fix_test.py / layer_test2.py):
  * ascending priority is required: lower-layer to_clips feed higher-layer from_clips
    1156 name-overlaps vs 194 reverse; e.g. relaxed-pistol-aim-idle -> crouch(9)
    base-crouch-p-aim -> weapon-base(13) tense-bow-crouch-aim-idle -> actor_b(37)
    actor_b-p-bow-aim-crouch-idle.  Descending makes move/crouch/weapon inert for Actor_B.
  * repeated passes are required: lower layers hold entries keyed on Actor_B names that
    only exist after actor_b(37) (backpack-off 6/6, hunting-on 2/2, sub-type
    pistol-actor_b, revolver 'actor_b-r-hand-gun', blizzard-on ...).
  * layer records keyed on Actor_A-side names are evaluated for Actor_B too: the actor_b
    set remaps 207 layer-only to_clips (81 of them to 'null').

Resolution algorithms (select with `algorithm=`):
    asc_fix   (default) repeat passes over active layers in ascending priority,
              one lookup per layer per pass, until the id stops changing.
    asc1      single ascending pass (lowest priority first).
    desc1     single descending pass (highest priority first).
    desc_fix  repeated descending passes until stable.
    asc_once  ascending, restart from lowest after each hit, each layer used once.
    desc_once descending, restart from highest after each hit, each layer used once.

Usage:
    python3 resolve_overlays.py idle --move run --weapon bow
    python3 resolve_overlays.py --measure         # writes measure_*.json/csv
"""
from __future__ import annotations

import argparse
import collections
import csv
import json
import os
import sys
from dataclasses import dataclass, field

PROJECT = __import__("_vendor_paths").PAP  # vendored path shim
GRAPH_JSON = os.path.join(PROJECT, "player_blending", "player_blending.json")
INDEX_CSV = os.path.join(PROJECT, "blender_animation_index.csv")
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

FLAG_LAYER = 0x01        # byte0 bit0
FLAG_RANDOM = 0x02       # byte0 bit1 (speculative, 3 records)
FLAG_STATE_KEY = 0x02    # byte1 bit1
FLAG_B1_0x08 = 0x08      # byte1 bit3 (unknown, 3 records)


def parse_flags(raw: str):
    b = [int(x, 16) for x in raw.split()]
    return b[0], b[1]


@dataclass
class Entry:
    set_name: str
    layer: str
    variant: str
    offset: str
    from_id: str
    to_id: str
    from_clip: str
    to_clip: str
    b0: int
    b1: int
    params_ptr: str

    @property
    def is_layer(self):
        return bool(self.b0 & FLAG_LAYER)

    @property
    def state_keyed(self):
        return bool(self.b1 & FLAG_STATE_KEY)


@dataclass
class Step:
    layer: str
    set_name: str
    offset: str
    from_clip: str
    to_clip: str


@dataclass
class Result:
    source_id: str
    source_name: str
    final_id: str
    final_name: str
    steps: list = field(default_factory=list)
    cycle: bool = False
    added_layers: list = field(default_factory=list)   # (Entry, resolved Result)


class OverlayDB:
    def __init__(self, graph_json=GRAPH_JSON, index_csv=INDEX_CSV):
        with open(graph_json) as fh:
            self.d = json.load(fh)
        self.sym = self.d["symbol_candidates"]
        self.priority = {p["layer"]: p["priority"] for p in self.d["overlay_priorities"]}
        self.maps = {m["name"]: {e["key"]: e["value"] for e in m["entries"]} for m in self.d["overlay_maps"]}
        self.sets = {}
        self.set_layer = {}
        self.subs = {}      # set -> {from_id: Entry}          (clip-keyed substitutions)
        self.layers = {}    # set -> {from_id: [Entry]}        (clip-keyed layer adds)
        self.state_e = {}   # set -> {from_id(state): [Entry]} (state-keyed records)
        self.id_name = {}
        for s in self.d["overlay_sets"]:
            n = s["name"]
            self.sets[n] = s
            self.set_layer[n] = s["layer"]
            sub, lay, st = {}, collections.defaultdict(list), collections.defaultdict(list)
            for r in s["remaps"]:
                b0, b1 = parse_flags(r["raw_flags"])
                e = Entry(n, s["layer"], s["variant"], r["offset"], r["from_id"], r["to_id"],
                          r["from_clip"], r["to_clip"], b0, b1, r["raw_0x0c"])
                self.id_name.setdefault(r["from_id"], r["from_clip"])
                self.id_name.setdefault(r["to_id"], r["to_clip"])
                if e.state_keyed:
                    st[e.from_id].append(e)
                elif e.is_layer:
                    lay[e.from_id].append(e)
                else:
                    assert e.from_id not in sub, (n, r["offset"])  # verified unique
                    sub[e.from_id] = e
            self.subs[n], self.layers[n], self.state_e[n] = sub, dict(lay), dict(st)
        # graph leaves
        self.leaves = [v for v in self.d["nodes"].values() if v["type"] == "anim-node-animation"]
        for v in self.leaves:
            self.id_name.setdefault(v["clip_id"], v["clip"])
        # movement modes: (character, name) -> overlay set name
        self.move_modes = {}
        for m in self.d["movement_modes"]:
            self.move_modes.setdefault((m["character"], m["name"]), m["overlay"])
        # blender index
        self.index = collections.defaultdict(dict)  # character -> original_name -> row
        with open(index_csv) as fh:
            for row in csv.DictReader(fh):
                self.index[row["character"]].setdefault(row["original_name"], row)
        self.name_id = {}
        for i, names in self.sym.items():
            for nm in names:
                self.name_id.setdefault(nm, i)

    # ------------------------------------------------------------------ names
    def name(self, sid):
        if sid in self.id_name:
            return self.id_name[sid]
        c = self.sym.get(sid)
        return c[0] if c else "#" + sid

    def to_id(self, clip):
        if clip.startswith("#"):
            return clip[1:]
        if clip in self.name_id:
            return self.name_id[clip]
        for v in self.leaves:
            if v["clip"] == clip:
                return v["clip_id"]
        raise KeyError(f"no id known for clip name {clip!r} (ids are not recomputed from names)")

    # -------------------------------------------------------------- selection
    def make_selection(self, actor_b="actor_b", move=None, weapon=None, sub_type=None,
                       draw_holster=None, tweaks=None, character="Actor_B", extra=None):
        """Return {layer: set_name}. Values are map keys (variants) or full set names."""
        sel = {}

        def put(layer, map_name, key):
            if key is None:
                return
            if key in self.sets:
                sel[layer] = key
                return
            m = self.maps[map_name]
            if key not in m:
                raise KeyError(f"{key!r} not a key of {map_name}: {sorted(m)}")
            sel[layer] = m[key]

        if actor_b:
            put("actor_b", "anim-overlay-player-actor_b", actor_b)
        if move:
            ov = self.move_modes.get((character, move)) or self.move_modes.get(("actor_a/base", move))
            if ov is None:
                put("move", "anim-overlay-player-move", move)
            elif ov in self.sets:
                sel["move"] = ov
            # else: the mode references an overlay id with no exported set -> no move overlay
        put("weapon-base", "anim-overlay-player-weapon-base", weapon)
        put("weapon-sub-type", "anim-overlay-player-weapon-sub-type", sub_type)
        put("weapon-draw-holster", "anim-overlay-player-weapon-draw-holster", draw_holster)
        put("weapon-tweaks", "anim-overlay-player-weapon-tweaks", tweaks)
        for layer, key in (extra or {}).items():
            put(layer, "anim-overlay-player-" + layer, key)
        return sel

    def _ordered(self, sel, descending=False):
        return sorted(sel.items(), key=lambda kv: self.priority[kv[0]], reverse=descending)

    # ---------------------------------------------------------------- resolve
    def resolve_id(self, sid, sel, algorithm="asc_fix", max_passes=16):
        res = Result(sid, self.name(sid), sid, self.name(sid))
        cur = sid
        desc = algorithm.startswith("desc")
        order = self._ordered(sel, descending=desc)

        def hit(layer, set_name, cur):
            e = self.subs[set_name].get(cur)
            if e is None:
                return None
            res.steps.append(Step(layer, set_name, e.offset, e.from_clip, e.to_clip))
            return e.to_id

        if algorithm in ("asc1", "desc1"):
            for layer, sn in order:
                nxt = hit(layer, sn, cur)
                if nxt is not None:
                    cur = nxt
        elif algorithm in ("asc_fix", "desc_fix"):
            seen = {cur}
            for _ in range(max_passes):
                start = cur
                for layer, sn in order:
                    nxt = hit(layer, sn, cur)
                    if nxt is not None:
                        cur = nxt
                if cur == start:
                    break
                if cur in seen and cur != start:
                    res.cycle = True
                    break
                seen.add(cur)
            else:
                res.cycle = True
        elif algorithm in ("asc_once", "desc_once"):
            used = set()
            progress = True
            while progress:
                progress = False
                for layer, sn in order:
                    if layer in used:
                        continue
                    nxt = hit(layer, sn, cur)
                    if nxt is not None:
                        used.add(layer)
                        cur = nxt
                        progress = True
                        break
        else:
            raise ValueError(algorithm)
        res.final_id = cur
        res.final_name = self.name(cur)
        return res

    def resolve(self, clip, sel, algorithm="asc_fix", with_layers=True):
        sid = clip if (len(clip) == 8 and all(c in "0123456789abcdef" for c in clip)) else self.to_id(clip)
        res = self.resolve_id(sid, sel, algorithm)
        if with_layers:
            res.added_layers = self.layer_adds(res, sel, algorithm)
        return res

    def layer_adds(self, res, sel, algorithm="asc_fix"):
        """Layer records (byte0 bit0) keyed on the final id or any intermediate id.
        Each added clip is itself resolved through the substitution layers."""
        keys = [res.source_id] + [self.name_id.get(s.to_clip, s.to_clip.lstrip('#')) for s in res.steps]
        keys.append(res.final_id)
        out, seen = [], set()
        for layer, sn in self._ordered(sel):
            for k in keys:
                for e in self.layers[sn].get(k, []):
                    if (sn, e.offset) in seen:
                        continue
                    seen.add((sn, e.offset))
                    sub = self.resolve_id(e.to_id, sel, algorithm)
                    out.append((e, sub, "final" if k == res.final_id else "intermediate"))
        return out

    def state_adds(self, state_name, sel, algorithm="asc_fix"):
        """State-keyed records (byte1 bit1) for a state name."""
        sid = None
        for s in self.d["states"]:
            if s["name"] == state_name:
                for x in s["raw"]:
                    if x["interpretation"] == state_name:
                        sid = x["hex"]
                        break
        out = []
        for layer, sn in self._ordered(sel):
            for e in self.state_e[sn].get(sid, []):
                out.append((e, self.resolve_id(e.to_id, sel, algorithm)))
        return out

    # ---------------------------------------------------------------- lookup
    def exists(self, name, character="Actor_B"):
        return name in self.index[character]

    def godot_name(self, name, character="Actor_B"):
        row = self.index[character].get(name)
        return None if row is None else f"{character.lower()}/{row['action_name']}"


# ------------------------------------------------------------------ measure
WEAPON_PROFILES = {
    # weapon-base key, sub-type key, draw-holster key
    "no-weapon": ("no-weapon", "none", "no-weapon"),
    "bow": ("bow", "none", "bow"),
    "long-gun": ("long-gun", "rifle-no-scope", "long-gun"),
    "pistol": ("pistol", "revolver", "pistol"),
}
ACTOR_B_MODES = ["walk", "run", "run-sprint", "walk-crouched", "crouch-sprint", "run-stealth", "walk-stealth"]
ALGORITHMS = ["asc_fix", "asc1", "desc1", "desc_fix", "asc_once", "desc_once"]


def classify(db, name):
    if db.exists(name, "Actor_B"):
        return "B"
    if name.startswith("#"):
        return "unnamed-hash"
    if db.exists(name, "Actor_A"):
        return "A-only"
    return "no-action"


def is_dynamic_leaf(db, v):
    """Leaf whose callback returns int32 (runtime-supplied clip id, e.g. the 68 'idle' slots)."""
    cb = v.get("callback")
    return bool(cb) and (db.d["functions"][cb].get("straight_line_return") or "").startswith("int32")


def measure(db):
    C = collections.Counter
    leaves = db.leaves
    report = {"n_leaves": len(leaves), "n_unique_leaf_ids": len({v["clip_id"] for v in leaves}), "runs": []}
    unresolved = collections.defaultdict(C)
    detail_rows = []
    for algo in ALGORITHMS:
        for ab in ("actor_b", None):
            for wname, (wb, st, dh) in WEAPON_PROFILES.items():
                for mode in ACTOR_B_MODES:
                    sel = db.make_selection(actor_b=ab, move=mode, weapon=wb, sub_type=st,
                                            draw_holster=dh, tweaks="normal",
                                            extra={"base": "default", "backpack": "on"})
                    cls = C()
                    cycles = 0
                    static_b = 0
                    for v in leaves:
                        r = db.resolve_id(v["clip_id"], sel, algo)
                        c = classify(db, r.final_name)
                        cls[c] += 1
                        cycles += r.cycle
                        static_b += (c == "B" and not is_dynamic_leaf(db, v))
                        if algo == "asc_fix" and c != "B":
                            unresolved[(ab or "no-actor_b", wname)][(r.final_name, c)] += 1
                        if algo == "asc_fix" and ab and mode == "run":
                            detail_rows.append((wname, v["id"], v["clip"], r.final_name, c,
                                                " > ".join(f"{s.layer}:{s.to_clip}" for s in r.steps),
                                                db.godot_name(r.final_name) or ""))
                    report["runs"].append({"algorithm": algo, "actor_b": ab, "weapon": wname, "move": mode,
                                           "B": cls["B"], "A_only": cls["A-only"],
                                           "unnamed_hash": cls["unnamed-hash"], "no_action": cls["no-action"],
                                           "cycles": cycles, "frac_B": round(cls["B"] / len(leaves), 4),
                                           "static_B": static_b})
    report["top_unresolved_asc_fix"] = {
        f"{k[0]}|{k[1]}": [[n, c, cnt] for (n, c), cnt in v.most_common(60)] for k, v in unresolved.items()}
    with open(os.path.join(OUT_DIR, "measure_overlays.json"), "w") as fh:
        json.dump(report, fh, indent=1)
    with open(os.path.join(OUT_DIR, "leaf_resolution_actor_b_run.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["weapon", "node_id", "graph_clip", "final_clip", "class", "chain", "godot_animation"])
        w.writerows(detail_rows)
    return report


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("clip", nargs="?")
    ap.add_argument("--actor-b", default="actor_b", help="actor_b map key or 'none'")
    ap.add_argument("--move")
    ap.add_argument("--weapon")
    ap.add_argument("--sub-type")
    ap.add_argument("--draw-holster")
    ap.add_argument("--tweaks")
    ap.add_argument("--algorithm", default="asc_fix", choices=ALGORITHMS)
    ap.add_argument("--measure", action="store_true")
    a = ap.parse_args()
    db = OverlayDB()
    if a.measure:
        rep = measure(db)
        for r in rep["runs"]:
            if r["move"] == "run":
                print(r)
        return
    if not a.clip:
        ap.error("clip name or id required")
    sel = db.make_selection(actor_b=None if a.actor_b == "none" else a.actor_b, move=a.move,
                            weapon=a.weapon, sub_type=a.sub_type, draw_holster=a.draw_holster,
                            tweaks=a.tweaks)
    r = db.resolve(a.clip, sel, a.algorithm)
    print("selection:", json.dumps(sel, indent=1))
    print(f"{r.source_name} [{r.source_id}] -> {r.final_name} [{r.final_id}]  cycle={r.cycle}")
    for s in r.steps:
        print(f"   {s.layer:<22} {s.set_name} @{s.offset}: {s.from_clip} -> {s.to_clip}")
    print("   exists for Actor_B:", db.exists(r.final_name), db.godot_name(r.final_name))
    for e, sub, where in r.added_layers:
        print(f"   + LAYER ({where}) {e.layer} @{e.offset} flags={e.b0:02x} {e.b1:02x} params={e.params_ptr}: "
              f"{e.from_clip} adds {e.to_clip} -> {sub.final_name} (B:{db.exists(sub.final_name)})")


if __name__ == "__main__":
    main()
