#!/usr/bin/env python3
"""Traversal clip catalogue for Frontier's free-running work (step 1 of the clip survey).

Lists every Actor_B traversal clip in the Godot library (vault, climb-up / jump-up to a ledge,
ledge hang, wall shimmy, edge warnings, ladder, drop / climb-down, balance beam, crouch-under,
squeeze, gap jumps), parses the name hints, pairs weapon / hand variants with their base clip, and
links every clip to the decoded animation-graph states that play it (overlay resolution with the
vendored resolver, `asc_once` like tools/anim_graph). It also lists the traversal graph states whose
leaves resolve to no Actor_B clip (the gaps the free-running design has to fill).

    python3 tools/traversal/build_traversal_catalog.py            # writes data/traversal/traversal_catalog.json
    python3 tools/traversal/build_traversal_catalog.py --check    # exit 1 when the committed file is stale

Inputs (read-only): tools/anim_graph/actor_b_keyed_bones.json (the library's clip list),
animations/actor_b_graph.json (the 12 exported weapon x mode overlay selections),
PAP/player_blending/player_blending.json and PAP/blender_animation_index.csv (through the vendored
resolver in tools/anim_graph/vendor). Standard library only, Python 3.9.

Provenance: numeric asset IDs and 32-bit symbol IDs are copied, never recomputed from names.
"""
from __future__ import annotations

import argparse
import collections
import csv
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
VENDOR = os.path.join(ROOT, "tools", "anim_graph", "vendor")
DEFAULT_PAP = os.environ.get("ANIM_GRAPH_PAP", "/Users/kiwimango/Downloads/Player_Animation_Project")
KEYED = os.path.join(ROOT, "tools", "anim_graph", "actor_b_keyed_bones.json")
GRAPH_EXPORT = os.path.join(ROOT, "animations", "actor_b_graph.json")
OUT = os.path.join(ROOT, "data", "traversal", "traversal_catalog.json")
GENERATOR = "tools/traversal/build_traversal_catalog.py"
SCHEMA = 1
RESOLVER_LOOP = "asc_once"   # tools/anim_graph/frontier_bindings.json resolver_policy.loop

AUTHORIZATION = ("owner-stated; see Player_Animation_Project/ASSET_AUTHORIZATION.md; "
                 "granting party and terms not on file")

# ------------------------------------------------------------------------------------------
# Families. First match wins, on the clip name without its "actor_b-" prefix.
# ------------------------------------------------------------------------------------------
FAMILIES = [
    # (family, regex, description)
    ("exclude", r"horse|pickup-shimmy", "horse traversal and ground pick-ups (not player traversal)"),
    ("ladder", r"ladder", "ladder mount / climb loops / dismounts (also played by the graph's ledge-climb states under the ledge-ladder overlay)"),
    ("vault", r"vault", "vaults over waist-to-chest obstacles: player sprint / run / idle vaults, and the ambient enter-loop-exit vault-over sets"),
    ("beam", r"balance-beam", "balance beam enter / loop / exits"),
    ("crouch_under", r"crouch-under", "crouch-under start / loop / end"),
    ("wall_shimmy", r"(^|-)p-ledge-(idle|walk|crouch-idle)", "standing sidle along a narrow ledge facing the wall (graph wall-shimmy-* states)"),
    ("edge_warn", r"ledge-warn", "stop-at-edge warnings (graph ledge-stop-* states)"),
    ("ledge_hang", r"ledge-hang|jump-up-3m|fall-ledge-grab|ledge-fail|jump-2o75-grab",
     "hanging from a ledge: jump up to hang, hang climb-up, fall catch, failed grabs"),
    ("climb_up", r"jump-up|climb-on-[0-9-]+m-up|ledge-grab|ledge-knee|ledge-chest|ledge-land",
     "climb-ups: jump up to a knee- / chest-high ledge, climb onto 0.5-3 m, knee / chest climb-up exits"),
    ("drop", r"climb-on-[0-9-]+m-down|drop-down|jump-down", "drops and climb-downs off ledges"),
    ("gap_jump", r"(^|-)p-(run\^|idle\^)?jump-(long|lfoot|rfoot|1-5m)|jump-across|p-idle\^jump-1-5m",
     "running / standing jumps across gaps"),
]
# Cinematic (IGC) clips that show a traversal move; kept as references, not graph-driven.
IGC = {
    "out4-actor_b-squeeze-through--actor_b": "squeeze",
    "out4-actor_b-jump-gap--actor_b": "gap_jump",
    "out1-ladder-see-soldiers--actor_b": "ladder",
    "out4b-actor_b-drops-ladder--actor_b": "ladder",
    "out2a-7-stairwell-sidle--actor_b": "wall_shimmy",
    "out2a-adult-ally-boost-pull-up-1--actor_b": "climb_up",
    "lak2-actor_b-boost-1--actor_b": "climb_up",
    "lak2-actor_b-boost-3--actor_b": "climb_up",
    "lak2-actor_b-boost-fail-1--actor_b": "climb_up",
    "lak2-actor_b-boost-fail-2--actor_b": "climb_up",
    "hun4-hotel-vator-boost-n-fall--actor_b": "climb_up",
}
FAMILY_ORDER = ["vault", "climb_up", "ledge_hang", "wall_shimmy", "edge_warn", "ladder", "drop",
                "gap_jump", "beam", "crouch_under", "squeeze"]
FAMILY_DESC = {f: d for f, _, d in FAMILIES}
FAMILY_DESC["squeeze"] = "squeezing through a narrow gap (only a cinematic clip exists)"

# Graph states that belong to the traversal families (for the gap report), by state name.
STATE_FAMILY_RX = [
    ("ladder", r"ladder"),
    ("vault", r"vault"),
    ("wall_shimmy", r"wall-shimmy"),
    ("edge_warn", r"^ledge-stop"),
    ("ledge_hang", r"^(ledge-grab|ledge-shimmy|swim-ledge-grab|fall-grab-edge|run-ledge|roll-ledge|climb-(up|down|lt|rt|far|in-90|out-90|dn)|chest-hang|1-hand-grab|2-hand-grab|against-wall-ledge|flinch-ledge|aim-flinch-ledge|arms-fm-ledge|climb-up-jump-3m|run-climb-up-jump-3m|climb-up-jump-fail)"),
    ("climb_up", r"climb|knee|chest|waist-grab|vault-grab"),
    ("drop", r"drop"),
    ("beam", r"beam|balance"),
    ("crouch_under", r"crouch-under"),
]
STATE_EXCLUDE_RX = r"^(carry|throw-grenade|swim-(drowning|surface-death|uw-death|exit)|base-swim|base-dive|push-)"

# Extra overlay layers the traversal states use (selection extras): layer -> overlay map.
EXTRA_LAYERS = ["ledge", "jump", "ladder-entry-exit", "crouch-under", "wall-shimmy"]

VARIANT_RX = [
    # (kind, weapon, regex on the stem end)
    ("part", "bow", r"-bow--part$|-bow-part$"),
    ("part", "rifle", r"-rifle--part$|-rifle-part$"),
    ("part", "bow", r"--bow$"),       # same kind of arm layer, older suffix form (keys arms, hands, props)
    ("part", "rifle", r"--rifle$"),
    ("hands", None, r"--hands$"),
    ("add", None, r"--add$"),
]


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def stem(name):
    return name[len("actor_b-"):] if name.startswith("actor_b-") else name


def family_of(name):
    if name in IGC:
        return IGC[name]
    s = stem(name)
    for fam, rx, _ in FAMILIES:
        if re.search(rx, s):
            return fam
    return None


def num(tok):
    """'1-5' -> 1.5, '2o75' -> 2.75, '3' -> 3.0."""
    if "o" in tok:
        a, b = tok.split("o", 1)
        return float(a) + float("0." + b)
    if "-" in tok:
        a, b = tok.split("-", 1)
        return float(a) + float("0." + b)
    return float(tok)


def name_hints(name, family):
    """Hints parsed from the clip name only; the measured values in clip_geometry.json are
    authoritative. Heights are in metres as the name states them."""
    s = stem(name)
    h = {}
    m = re.search(r"width-?(\d+(?:-\d+)?)m?", s)
    if m:
        h["width_m"] = num(m.group(1))
    s_nw = re.sub(r"width-?\d+(?:-\d+)?m?", "", s)
    m = re.search(r"-(\d+(?:-\d+)?)m-(\d+(?:-\d+)?)m", s_nw)
    if m:
        h["height_range_m"] = [num(m.group(1)), num(m.group(2))]
    else:
        m = re.search(r"(?<![a-z0-9])(\d+(?:[-o]\d+)?)m(?![a-z])", s_nw)
        if m:
            key = "gap_m" if "across" in s_nw else "height_m"
            h[key] = num(m.group(1))
        m = re.search(r"jump-2o75", s_nw)
        if m:
            h["height_m"] = 2.75
    if "^" in s:
        a, b = s.split("^", 1)
        h["from_token"] = a
        h["to_token"] = b
    for seg in ("begin", "mid", "end", "enter", "loop", "exit", "start"):
        if re.search(r"(^|[-^])%s($|[-^])" % seg, s):
            h.setdefault("segments", []).append(seg)
    m = re.search(r"sprint-vault-(\d)", s)
    if m:
        h["part_index"] = int(m.group(1))
    m = re.search(r"--(a|b)$", s)
    if m:
        h["alternate"] = m.group(1)
    m = re.search(r"grab-0(\d)--", s)
    if m:
        h["part_index"] = int(m.group(1))
    for side, rx in (("left", r"-(left|l|lt|lft)($|-)"), ("right", r"-(right|r|rt|rht)($|-)")):
        if re.search(rx, s.split("^")[-1]):
            h["side"] = side
    if "in-place" in s:
        h["in_place"] = True
    if re.search(r"crouch", s):
        h["mentions_crouch"] = True
    if re.search(r"-flip($|-)", s):
        h["flip"] = True
    if "actor_e" in s:
        h["with_actor_e"] = True
    if "fast" in s:
        h["fast"] = True
    if re.search(r"quarter|half|3-quarter", s):
        m = re.search(r"(3-quarters?|quarter|half)", s)
        h["fraction"] = {"quarter": 0.25, "half": 0.5, "3-quarter": 0.75, "3-quarters": 0.75}[m.group(1)]
    return h


def variant_of(name, lib):
    """(kind, weapon, base_clip) for weapon parts / hands / additive variants."""
    for kind, weapon, rx in VARIANT_RX:
        if re.search(rx, name):
            base = re.sub(rx, "", name)
            return kind, weapon, (base if base in lib else None), base
    return "base", None, None, None


# ------------------------------------------------------------------------------------------
# Graph linkage
# ------------------------------------------------------------------------------------------

def load_resolver(pap):
    os.environ["ANIM_GRAPH_PAP"] = pap
    sys.dont_write_bytecode = True   # read-only use of the vendored tools: no __pycache__ in tools/anim_graph/vendor
    sys.path.insert(0, VENDOR)
    import resolve_overlays  # noqa: E402  (vendored, unedited)
    import lib as glib       # noqa: E402
    return resolve_overlays, glib


def selections(db, graph_export):
    """The 12 exported weapon x mode selections plus a no-weapon run selection."""
    out = collections.OrderedDict()
    for key in sorted(graph_export.get("selections", {})):
        out[key] = dict(graph_export["selections"][key])
    out["none/run"] = {"actor_b": db.maps["anim-overlay-player-actor_b"]["actor_b"],
                       "move": db.maps["anim-overlay-player-move"]["run"]}
    return out


def extras(db):
    out = [("", {})]
    for layer in EXTRA_LAYERS:
        m = db.maps.get("anim-overlay-player-" + layer, {})
        for key in sorted(m):
            if m[key] in db.sets:
                out.append(("%s:%s" % (layer, key), {layer: m[key]}))
    return out


def tree_leaves(N, nid, out=None):
    if out is None:
        out = []
    n = N.get(nid)
    if n is None:
        return out
    if n["type"] == "anim-node-animation":
        out.append(n)
    else:
        tree_leaves(N, n["left"], out)
        tree_leaves(N, n["right"], out)
    return out


def state_name_id(s):
    for x in s["raw"]:
        if x["interpretation"] == s["name"]:
            return x["hex"]
    return None


def state_adds(db, sid, sel):
    """OverlayDB.state_adds without its per-call scan of every state (same records, same order)."""
    out = []
    if sid is None:
        return out
    for layer, sn in db._ordered(sel):
        for e in db.state_e[sn].get(sid, []):
            out.append((e, db.resolve_id(e.to_id, sel, RESOLVER_LOOP)))
    return out


def state_family(name):
    if re.search(STATE_EXCLUDE_RX, name):
        return None
    for fam, rx in STATE_FAMILY_RX:
        if re.search(rx, name):
            return fam
    return None


def build(pap):
    ro, glib = load_resolver(pap)
    db = ro.OverlayDB()
    D = db.d
    N = D["nodes"]
    keyed = json.load(open(KEYED))
    lib = set(keyed["clips"])
    graph_export = json.load(open(GRAPH_EXPORT))
    idx_rows = collections.defaultdict(list)
    with open(os.path.join(pap, "blender_animation_index.csv")) as fh:
        for row in csv.DictReader(fh):
            if row["character"] == "Actor_B":
                idx_rows[row["action_name"]].append(row)

    # --- clip catalogue -----------------------------------------------------------------
    clips = {}
    warnings = []
    for name in sorted(lib):
        fam = family_of(name)
        if fam is None or fam == "exclude":
            continue
        rows = idx_rows.get(name, [])
        if not rows:
            warnings.append("no blender_animation_index.csv row for library clip " + name)
        kind, weapon, base, base_guess = variant_of(name, lib)
        c = {
            "family": fam,
            "igc": name in IGC,
            "variant": {"kind": kind, "weapon": weapon, "base_clip": base},
            "name_hints": name_hints(name, fam),
            "index": [{"original_name": r["original_name"], "asset_id": r["asset_id"],
                       "blend_file": r["blend_file"], "sample_rate": float(r["sample_rate"]),
                       "sample_count": int(r["sample_count"]), "kind": r["kind"]} for r in rows],
            "variants": [],
            "graph": [],
        }
        if kind != "base" and base is None:
            c["variant"]["base_missing"] = base_guess
        clips[name] = c
    for name, c in clips.items():
        b = c["variant"]["base_clip"]
        if b and b in clips:
            clips[b]["variants"].append(name)
    for c in clips.values():
        c["variants"].sort()

    # --- graph linkage ------------------------------------------------------------------
    sels = selections(db, graph_export)
    exs = extras(db)
    name_by_index = {}
    for action, rows in idx_rows.items():
        for r in rows:
            name_by_index.setdefault(r["original_name"], action)

    def godot(final_name):
        return name_by_index.get(final_name)

    link = collections.defaultdict(lambda: {"selections": set(), "extras": set()})
    state_info = {}
    incoming = collections.defaultdict(list)
    for s in D["states"]:
        for t in s.get("transitions", []):
            incoming[t["target"]].append({"source": s["name"], "request": t["request"],
                                          "fade_s": round(float(t["scalar_0x1c"]), 4),
                                          "cond": glib.short_cond(t), "record": t["offset"]})
    for s in D["states"]:
        if not s.get("tree"):
            continue
        leaves = tree_leaves(N, s["tree"])
        fam = state_family(s["name"])
        sid = state_name_id(s)
        resolved = collections.defaultdict(lambda: collections.defaultdict(set))  # leaf -> clip -> {labels}
        for sl, sel0 in sels.items():
            for el, ex in exs:
                sel = dict(sel0)
                sel.update(ex)
                label = sl + ("|" + el if el else "")
                for lf in leaves:
                    r = db.resolve_id(lf["clip_id"], sel, RESOLVER_LOOP)
                    g = godot(r.final_name)
                    if g:
                        resolved[lf["clip"]][g].add(label)
                        if g in clips:
                            k = (g, s["name"], lf["clip"], "leaf", "")
                            link[k]["selections"].add(sl)
                            link[k]["extras"].add(el)
                    for e, sub, where in db.layer_adds(r, sel, RESOLVER_LOOP):
                        g2 = godot(sub.final_name)
                        if g2 and g2 in clips:
                            k = (g2, s["name"], lf["clip"], "layer", e.layer)
                            link[k]["selections"].add(sl)
                            link[k]["extras"].add(el)
                for e, sub in state_adds(db, sid, sel):
                    g3 = godot(sub.final_name)
                    if g3 and g3 in clips:
                        k = (g3, s["name"], "", "state_layer", e.layer)
                        link[k]["selections"].add(sl)
                        link[k]["extras"].add(el)
        trav_clips = sorted({g for lf in resolved.values() for g in lf if g in clips})
        # Extra overlays without which no traversal clip is reached (e.g. ledge:ladder for the hang states).
        labs = [lab for lf in resolved.values() for g, ls in lf.items() if g in clips for lab in ls]
        ex_sets = {lab.split("|", 1)[1] if "|" in lab else "" for lab in labs}
        needs = sorted(ex_sets) if labs and "" not in ex_sets else []
        if fam is None and not trav_clips:
            continue
        state_info[s["name"]] = {
            "family": fam,
            "state_offset": s["offset"],
            "reference_clip": s.get("reference_clip"),
            "leaves": [{"clip": lf["clip"], "clip_id": lf["clip_id"],
                        "actor_b": {g: sorted(v)[:4] + (["..."] if len(v) > 4 else [])
                                    for g, v in sorted(resolved[lf["clip"]].items())}} for lf in leaves],
            "actor_b_traversal_clips": trav_clips,
            "only_with_extras": needs,
            "transitions": [{"request": t["request"], "target": t["target"],
                             "fade_s": round(float(t["scalar_0x1c"]), 4),
                             "scalar_0x20": round(float(t["scalar_0x20"]), 4),
                             "cond": glib.short_cond(t), "record": t["offset"]}
                            for t in s.get("transitions", [])],
            "incoming": sorted(incoming.get(s["name"], []), key=lambda x: (x["source"], x["record"])),
        }
    for (g, st, leaf, role, layer), v in sorted(link.items()):
        ex = sorted(v["extras"])
        clips[g]["graph"].append({"state": st, "leaf": leaf, "role": role, "layer": layer or None,
                                  "selections": sorted(v["selections"]),
                                  "extras": ["(none)" if e == "" else e for e in ex]})
    # Graph clip successions: state S playing X transitions to state T playing Y.
    succ = collections.defaultdict(dict)
    for st, info in state_info.items():
        for tr in info["transitions"]:
            tgt = state_info.get(tr["target"])
            if tgt is None or tr["target"] == st:
                continue
            for x in info["actor_b_traversal_clips"]:
                for y in tgt["actor_b_traversal_clips"]:
                    if x == y:
                        continue
                    rec = succ[x].setdefault(y, {"clip": y, "fade_s": tr["fade_s"], "via": []})
                    rec["fade_s"] = min(rec["fade_s"], tr["fade_s"])
                    rec["via"].append({"from_state": st, "to_state": tr["target"], "request": tr["request"],
                                       "fade_s": tr["fade_s"], "cond": tr["cond"]})
    for x, ys in succ.items():
        clips[x]["graph_next"] = []
        for y in sorted(ys):
            rec = ys[y]
            rec["via"] = sorted(rec["via"], key=lambda v: (v["from_state"], v["to_state"], v["request"]))[:4]
            clips[x]["graph_next"].append(rec)
            clips[y].setdefault("graph_prev", []).append({"clip": x, "fade_s": rec["fade_s"],
                                                           "via": rec["via"]})
    for c in clips.values():
        c.setdefault("graph_next", [])
        c.setdefault("graph_prev", [])
        c["graph_prev"].sort(key=lambda r: r["clip"])
    ALL_SEL = sorted(sels)
    ALL_EX = sorted("(none)" if e == "" else e for e, _ in exs)
    for c in clips.values():
        for g in c["graph"]:
            if g["selections"] == ALL_SEL:
                g["selections"] = ["(all)"]
            if g["extras"] == ALL_EX:
                g["extras"] = ["(any)"]
    gaps = []
    for st, info in sorted(state_info.items()):
        if info["family"] and not info["actor_b_traversal_clips"]:
            any_b = sorted({g for lf in info["leaves"] for g in lf["actor_b"]})
            gaps.append({"state": st, "family": info["family"],
                         "leaves": [lf["clip"] for lf in info["leaves"]],
                         "actor_b_non_traversal_clips": any_b,
                         "leaf_in_actor_a_library": [lf["clip"] for lf in info["leaves"]
                                                     if db.exists(lf["clip"], "Actor_A")]})
    fam_counts = collections.Counter(c["family"] for c in clips.values())
    doc = {
        "meta": {
            "schema": SCHEMA,
            "generator": GENERATOR,
            "authorization": AUTHORIZATION,
            "resolver": {"loop": RESOLVER_LOOP, "vendor": "tools/anim_graph/vendor (unedited graph-analysis tools)",
                         "selections": {k: v for k, v in sels.items()},
                         "extras": [e for e, _ in exs if e]},
            "inputs": {
                "keyed_bones": {"path": "tools/anim_graph/actor_b_keyed_bones.json", "sha256": sha256(KEYED),
                                "library_sha256": keyed.get("library_sha256")},
                "graph_export": {"path": "animations/actor_b_graph.json", "sha256": sha256(GRAPH_EXPORT)},
                "player_blending": {"path": "PAP/player_blending/player_blending.json",
                                    "sha256": sha256(os.path.join(pap, "player_blending", "player_blending.json"))},
                "index": {"path": "PAP/blender_animation_index.csv",
                          "sha256": sha256(os.path.join(pap, "blender_animation_index.csv"))},
            },
            "notes": [
                "family: first matching regex over the clip name (FAMILIES in the generator); IGC clips are listed by name",
                "variant.kind: part (-bow--part / -rifle--part / --bow / --rifle: arm + hand + prop-bone weapon layer over the base clip), hands (--hands: finger pose layer), add (--add), base",
                "name_hints are parsed from names only; measured geometry is in data/traversal/clip_geometry.json",
                "graph: every (state, leaf) whose leaf resolves to the clip under one of the selections x extras (role leaf), a layer record keyed on the leaf chain (role layer) or a state-keyed record (role state_layer)",
                "graph_gaps: traversal-family states none of whose leaves resolve to an Actor_B traversal clip under any selection",
                "graph_states[*].only_with_extras: the state reaches an Actor_B traversal clip only when one of these extra overlays is selected (e.g. the hang states only as a ladder, ledge:ladder); empty = also without extras",
                "graph_next / graph_prev: state S (playing this clip) has a transition record to state T playing the other clip; fade_s = the smallest record fade; via = up to 4 records (cond = condition summary as in graph_analysis/graph/lib.py short_cond)",
                "selections ['(all)'] = every selection in meta.resolver.selections; extras ['(any)'] = with and without every extra overlay",
            ],
            "warnings": warnings,
        },
        "families": {f: {"description": FAMILY_DESC[f], "count": fam_counts.get(f, 0),
                         "clips": sorted(n for n, c in clips.items() if c["family"] == f)}
                     for f in FAMILY_ORDER},
        "clips": clips,
        "graph_states": state_info,
        "graph_gaps": gaps,
    }
    return doc


def dumps(doc):
    return json.dumps(doc, indent=1, sort_keys=True, ensure_ascii=False) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--pap", default=DEFAULT_PAP)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    doc = build(a.pap)
    text = dumps(doc)
    if a.check:
        old = open(a.out).read() if os.path.exists(a.out) else ""
        if old != text:
            print("traversal catalog: %s is stale (rerun without --check)" % a.out)
            sys.exit(1)
        print("traversal catalog: %s is current" % a.out)
        return
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with open(a.out, "w") as fh:
        fh.write(text)
    fams = doc["families"]
    print("traversal catalog: wrote %s (%d clips: %s; %d graph states, %d gaps)" % (
        a.out, len(doc["clips"]), ", ".join("%s %d" % (f, fams[f]["count"]) for f in FAMILY_ORDER),
        len(doc["graph_states"]), len(doc["graph_gaps"])))
    for w in doc["meta"]["warnings"]:
        print("  warn " + w)


if __name__ == "__main__":
    main()
