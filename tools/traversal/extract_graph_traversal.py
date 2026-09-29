#!/usr/bin/env python3
"""Traversal extract of the decoded player animation graph: vault, step-up, jump-up to a ledge, ledge catch,
ledge hang / shimmy / hand-over-hand climb, corners, drops, ladder, narrow-ledge shimmy, gap jumps, edge stops.

Offline only; nothing here runs in the game. Python 3.9, standard library only.

Reads (read-only):
  source/player_blending/player_blending.json            decoded graph (states, trees, transitions, overlays, lambdas)
  source/blender_animation_index.csv                     clip index (Actor_A / Actor_B names)
  FR/tools/anim_graph/export_actor_b_graph.py         WP1 exporter, used as a library: its vendored, unmodified
                                                      resolve_overlays.py (overlay resolver), symvm.py and
                                                      decode_lambda.py (lambda decoders), its condition / transition /
                                                      tree decoding and its Actor_B clip lookup
  FR/tools/anim_graph/frontier_bindings.json          weapon profiles, mode records, resolver policy (via the exporter)

Writes:
  FR/data/traversal/graph_traversal.json
  source/graph_analysis/traversal/graph_traversal.md

Usage:
  python3 tools/traversal/extract_graph_traversal.py            # regenerate both outputs
  python3 tools/traversal/extract_graph_traversal.py --check    # rebuild in memory; exit 2 if the outputs are stale

Provenance: numeric IDs (state name IDs, clip IDs, record offsets, native_asset_id) are copied, never recomputed
from names.
"""
import argparse
import collections
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FR_ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
ANIM_GRAPH = os.path.join(FR_ROOT, "tools", "anim_graph")
DEFAULT_SOURCE_ROOT = ""
GENERATOR = "tools/traversal/extract_graph_traversal.py"
SCHEMA_VERSION = 1

sys.path.insert(0, ANIM_GRAPH)
import export_actor_b_graph as X  # noqa: E402  (read-only reuse of the WP1 exporter)

# ----------------------------------------------------------------------------------------------------------------
# Families. First match wins; the order matters (e.g. climb-up-jump-3m is a jump-up, not a hand-over-hand climb).
FAMILIES = [
    ("vault", r"^(idle\^vault|edge\^vault|run\^vault|vault|vault\^idle|vault\^run|vault\^edge|vault\^fall|"
              r"move\^vault-.*|idle\^vault-.*|vault-1m\^.*|vault-2m.*|(idle|run)\^test-vault-begin|test-vault.*|"
              r"vault-kick\^idle)$",
     "Vault over an obstacle: the old one-state vault (vault + hashed exit requests), the 1 m / 2 m vault-over "
     "chain, and the three-part 'test-vault' chain (begin -> mid -> end) that carries the Actor_B vault clips, "
     "including sprint-vault-1..4 under the sprint move overlay."),
    ("step_up_carry", r"^(idle\^climb-0-5-carry|climb-0-5-carry.*|run\^climb-0-5-carry-run)$",
     "0.5 m step-up while carrying an object (carry overlay; listed for completeness)."),
    ("step_up", r"^((idle|run)\^climb-0-5|climb-0-5|idle-climb-0-5|climb-0-5\^(idle|run)|auto-walk\^climb-1m|"
                r"auto-climb-1m\^(walk|run)|auto-run\^climb-1m)$",
     "Step up onto a 0.5 m or 1 m surface without a hand plant (idle / run entries, auto-climb 1 m)."),
    ("jump_onto", r"^((idle|run)-)?climb-(short|medium|high)\b.*$|^climb-onto-1-75m\^(idle|run)$",
     "Jump onto a surface (short / medium / high, with '-close' variants): run-up -> air (phase driven by code) "
     "-> knee or chest landing -> idle / run."),
    ("jump_up_ledge", r"^((idle|run)\^climb-up-jump-.*|(run-)?climb-up-jump-3m.*|climb-up-jump-fail-no-grab|"
                      r"knee\^(idle|run)|chest\^(idle|run)|swim\^climb-up)$",
     "Standing / running jump-up to a ledge at 1 / 1.5 / 2 / 3 m: knee (1-1.5 m), chest (2 m, begin-mid-end) or "
     "hang (3 m, begin-mid-end then hang-climb-up to knee), then climb-up to idle or run; the 2.75 m fail "
     "variants."),
    ("ledge_catch", r"^((idle|run)-climb-ledge-grab(-close)?|climb-ledge-grab-mid-jump(-close)?|ledge-grab-climb|"
                    r"against-wall-ledge-grab.*|knee-grab.*|vault-grab|waist-grab.*|(idle|run)-(chest|knee|waist)-grab|"
                    r"chest-grab.*|chest-hang.*|(idle|run)-[12]-hand-grab|[12]-hand-grab.*|fall-grab-edge.*)$",
     "Jump or fall to a ledge and catch it: knee / waist / chest / one-hand / two-hand contact, the falling edge "
     "grab and the jump-up-from-cover grab; most end in the ledge hang hub (ledge-grab)."),
    ("wall_jump", r"^((idle|run)-jump-to-wall.*|jump-to-wall.*|wall-jump-.*)$",
     "Run at a wall at 45 or 90 degrees, kick off, and either fail (fall) or long-jump into one of the catch "
     "families (requests knee / chest-grab / waist-grab / long / short / high / ledge ...)."),
    ("drop_to_hang", r"^(run-ledge-(hang-)?drop(-backwards)?|roll-ledge-drop|wall-shimmy-ledge-drop)$",
     "Walk / roll / step off an edge (forwards or backwards) into a hang, or drop from the narrow-ledge "
     "shimmy into a hang."),
    ("ledge_hang", r"^(ledge-grab|ledge-grab-(fw|bk)|ledge-grab-look-.*|ledge-grab-fall|ledge-shimmy-(left|right)|"
                   r"swim-ledge-grab|arms-fm-ledge)$",
     "The hang hub (ledge-grab) and its idles: swing fw/bk, look left/right/away/up-back (+fail), continuous "
     "shimmy left/right, letting go (ledge-grab-fall) and the water-edge grab."),
    ("ledge_climb", r"^climb-(up|down|rt|lt|far|in-90|out-90|dn)(-|\^|$).*",
     "Hand-over-hand moves between handholds while hanging: up / down / left / right / diagonals, 'far' "
     "(jump) variants, 90-degree inside / outside corners, up-back and down-forward, each with a settle "
     "state (^idle) that chains into the next move. Under the ledge=ladder overlay the same states play the "
     "ladder clips."),
    ("hang_reactions", r"^((aim-)?flinch-ledge-hang-[lr]|throw-grenade-hang.*|throw-grenade-ledge.*)$",
     "Partial / additive reactions while hanging (flinches, throws); started by code, no transitions."),
    ("drop_down", r"^(auto-run\^drop-.*|auto-drop-.*)$",
     "Run off / drop down 1 m or 2 m and land into idle / run, or drop into the fall loop."),
    ("ladder", r"^(ladder-auto-climb.*|ladder\^.*)$",
     "Ladder mount (bottom / top) and dismount (top, bottom). The rungs themselves are the ledge_climb / "
     "ledge_hang states under the ledge=ladder overlay (ledge-grab = ladder idle, climb-up-* = rung up, "
     "climb-down-* = rung down)."),
    ("wall_shimmy", r"^wall-shimmy-.*$",
     "Standing on a narrow ledge facing the wall and side-stepping (enter / idle / idle^move / move / "
     "move^idle / exit, climb-up from a hang)."),
    ("gap_jump", r"^((idle|run)\^jump2-5m|jump2-5m(\^idle|\^run)?|jump-facing-wall|jump\^wall-slide\^fall|"
                 r"jump-in-place(-land)?)$",
     "Authored gap jump (2.5 m; 1.5 m and left-foot variants through the jump overlay), jump facing a wall, "
     "wall-slide into fall, jump in place."),
    ("edge_balance", r"^(ledge-stop-(fw|bw|r|l)|avoid-fall)$",
     "Stopping at an edge (ledge warn fw / bw / l / r) and losing balance at an edge (avoid-fall)."),
    ("water_edge", r"^(run\^dive-jump|dive-jump(\^fall|\^land)?)$",
     "Running dive into water (ends in swim)."),
]
FAMILY_RE = [(f, re.compile(rx), d) for f, rx, d in FAMILIES]

# seed states that match traversal keywords but are not traversal states (checked: every keyword match must be in a
# family or here)
EXCLUDED = {
    "run-fw": "locomotion (source of the avoid-fall request)",
    "run-bkwd": "locomotion (source of the avoid-fall request)",
    "crouch-change-idle^idle": "locomotion crouch change",
    "crouch-change": "crouch-change additive",
    "push-pallet-weigh-down": "swim pallet interaction",
    "idle-jump-long": "jump takeoff (exported by tools/anim_graph as role takeoff)",
    "run-jump-long": "jump takeoff (exported by tools/anim_graph)",
    "run-jump-long-scaled": "jump takeoff variant (phase-rate ramp)",
    "jump-long": "jump air (exported by tools/anim_graph)",
    "jump-long-land-idle": "landing (exported by tools/anim_graph)",
    "jump-long-land-idle-med": "landing (exported by tools/anim_graph)",
    "jump-long-land-run": "landing (exported by tools/anim_graph)",
    "jump-long-land-run-hard": "landing (exported by tools/anim_graph)",
    "jump-long-land-idle-no-stumble": "landing variant",
}
SEED_RE = re.compile(r"vault|ledge|shimmy|climb|ladder|drop|jump-up|hang|onto|edge|wall-jump|jump-to-wall|(chest|knee|waist|hand)-grab|"
                     r"chest-hang|grab-hang|against-wall|balanc|beam|under|squeez|jump2-5m|jump-long|"
                     r"jump-facing-wall|perp-wall|wall-slide|jump-in-place|ledge-stop|dive-jump")
SEED_EXCL_RE = re.compile(r"^(cover|throw-grenade-cover|carry|horse|ride-horse|free-turret|interact|base-swim|"
                          r"swim-(?!ledge)|move-object|truck|convoy)")

# requests whose name hash is not in symbol_candidates: meaning from the only target(s) they reach
LEDGE_NAV_HASHES = {
    "#355f7872": "ledge-climb-out-90-rt (hashed; the only target is climb-out-90-rt)",
    "#4a901f95": "ledge-climb-out-90-lt (hashed; the only target is climb-out-90-lt)",
    "#7dd273cc": "ledge-climb-in-90-rt (hashed; target climb-in-90-rt)",
    "#9cdf301a": "ledge-climb-in-90-up-rt (hashed; target climb-in-90-up-rt)",
    "#981188ee": "ledge-climb-in-90-dn-rt (hashed; target climb-in-90-dn-rt)",
    "#021d142b": "ledge-climb-in-90-lt (hashed; target climb-in-90-lt)",
    "#e31057fd": "ledge-climb-in-90-up-lt (hashed; target climb-in-90-up-lt)",
    "#e7deef09": "ledge-climb-in-90-dn-lt (hashed; target climb-in-90-dn-lt)",
}
REQUEST_NOTES = {
    "auto": "no request: fires when the conditions hold (first match in record order wins)",
    "reverse": "abort a hand-over-hand move in its first half (phase <= 0.5) and fall back to the hang hub",
    "ledge-grab": "return to / stay in the hang hub",
    "ledge-shimmy-left": "continuous hang shimmy to the left (mirrored ledge-shimmy-right tree)",
    "ledge-shimmy-right": "continuous hang shimmy to the right",
    "swim-ledge-grab": "hanging at a water edge",
    "ledge-grab-fw": "swing forward in the hang", "ledge-grab-bk": "swing back in the hang",
    "ledge-grab-look-left": "look left while hanging", "ledge-grab-look-right": "look right while hanging",
    "ledge-grab-look-away": "look away from the wall", "ledge-grab-look-up-back": "look up and back",
    "ledge-grab-look-fail": "look, nothing to reach", "ledge-grab-look-away-fail": "look away, nothing to reach",
    "ledge-climb-up": "hand-over-hand up", "ledge-climb-dn": "hand-over-hand down",
    "ledge-climb-lt": "hand-over-hand left", "ledge-climb-rt": "hand-over-hand right",
    "ledge-climb-up-lt": "diagonal up-left", "ledge-climb-up-rt": "diagonal up-right",
    "ledge-climb-dn-lt": "diagonal down-left", "ledge-climb-dn-rt": "diagonal down-right",
    "ledge-climb-far-lt": "jump left to a far handhold", "ledge-climb-far-rt": "jump right to a far handhold",
    "ledge-climb-far-up-lt": "jump up-left to a far handhold", "ledge-climb-far-up-rt": "jump up-right",
    "ledge-climb-far-dn-lt": "drop down-left to a far handhold", "ledge-climb-far-dn-rt": "drop down-right",
    "ledge-climb-up-bk": "climb up while turning back (up-back)", "ledge-climb-dn-fw": "climb down facing out (down-forward)",
    "idle": "exit request to idle (code sends it when there is no move input)",
    "run": "exit request to run (code sends it when there is move input)",
    "run-fw": "locomotion request: move forward (graph lambdas pick start clip vs loop)",
    "#d923ebe9": "locomotion request: move backward (hashed; pairs with run-fw)",
    "change-move-mode": "movement-mode change (lambda picks idle / start / loop)",
    "fall": "no ground under the exit: go to the fall loop",
    "vault": "vault out of a knee jump-up (1 m) instead of climbing onto it",
    "carry": "carry (object in hands)", "carry-idle": "carry idle",
    "shimmy-idle": "narrow-ledge shimmy: stop at the next foot plant window",
    "#8e6fcc68": "narrow-ledge shimmy: move left (hashed; targets wall-shimmy-idle^move-left, and stops a right move)",
    "#e2d1872c": "narrow-ledge shimmy: move right (hashed; targets wall-shimmy-idle^move-right, and stops a left move)",
    "#ff499e08": "vault exit: 2 m vault to run (hashed; only target vault-2m^run)",
    "#91201877": "vault exit: 2 m vault to idle (hashed; only target vault-2m^idle)",
    "#d2318980": "vault exit: 1 m vault to run (hashed; only target vault-1m^run-a)",
    "#40d9a044": "vault exit: 1 m vault to idle (hashed; only target vault-1m^idle)",
    "knee": "wall-jump into a knee catch", "waist-grab": "wall-jump into a waist catch",
    "chest-grab": "wall-jump into a chest catch", "long": "wall-jump into a long jump",
    "short": "wall-jump onto a short climb", "high": "wall-jump onto a high climb",
    "ledge": "wall-jump to a ledge grab",
    "#d172e9ed": "wall-jump into a one-hand catch (hashed; target #9dcc9cf6, a state id not in the state table)",
    "#fc0afe65": "wall-jump into a two-hand catch (hashed; target #fe1da2d7, a state id not in the state table)",
    "#b363bb6e": "wall-jump onto a short-close climb (hashed)", "#2d91a2c6": "wall-jump onto a medium climb (hashed)",
    "#48ca7e36": "wall-jump onto a medium-close climb (hashed)", "#c8eaa2dc": "wall-jump onto a high-close climb (hashed)",
    "#124bbeb8": "wall-jump to a ledge grab, close (hashed)",
}
REQUEST_NOTES.update(LEDGE_NAV_HASHES)

# Runtime fields read by the lambdas of traversal states (symvm notation: C0 = pointer32[arg0], C8 = pointer32[arg0+8]
# for blend / condition lambdas; D0/D4/D8 = pointer32[arg1(+4/+8)] for state callbacks). Names are inferred unless
# stated; see the md for the evidence.
FIELD_INFO = {
    "f32[C8+84]": ("ledge_free_hang", "blend weight of every hand-over-hand tree: 0 = braced clip (feet on the wall), "
                   "1 = hang-* clip (legs free)", "inferred (graph_understanding blend_weights; clip names)"),
    "f32[C8+80]": ("ledge_shimmy_stride", "blend weight inside the hang-shimmy tree (shuffle / strafe / short / long "
                   "stride)", "inferred (graph_understanding blend_weights)"),
    "f32[C8+108]": ("ledge_look_dir", "look direction 0..1 while hanging; leaf phase lambdas sample the look pose "
                    "clips at lerp-scale(0,0.5) / lerp-scale(0.5,1) of it", "inferred"),
    "f32[C8+112]": ("ledge_look_weight_a", "blend weight in the ledge-grab-look trees (first level)", "unknown meaning"),
    "f32[C8+116]": ("ledge_look_weight_b", "blend weight in the ledge-grab-look trees (second level)", "unknown meaning"),
    "f32[D8+276]": ("air_progress", "phase of every '*-mid-jump' air state is SET to this value each frame (the "
                    "code drives the jump arc and the clip follows it)", "inferred (callback returns the field "
                    "instead of phase + dt)"),
    "i32[D4+32]": ("mirror_side", "mirror flag of vault / climb / jump / drop states (state +0x2c callback returns "
                   "it; the '*-mid-jump' air states return its negation)", "inferred"),
    "i32[D8+744]": ("mirror_side_auto", "mirror flag of the auto-climb / auto-drop states", "inferred"),
    "f32[D8+92]": ("shimmy_rate", "phase rate of the hang shimmy (phase += rate * dt)", "inferred"),
    "f32[D8+96]": ("ledge_climb_rate", "rate factor of the fast / far hand-over-hand moves (x f32[D4+124])",
                   "inferred"),
    "f32[D4+124]": ("ledge_climb_rate_global", "second rate factor of the fast / far hand-over-hand moves",
                    "inferred"),
    "f32[D4+128]": ("traversal_rate", "playback-rate multiplier of the vault entry/exit states; start value of the "
                    "rate ramp of climb-short-run / climb-short-close-run", "inferred"),
    "f32[D4+132]": ("traversal_rate_end", "end value of the rate ramp lerp(D4+128, D4+132, phase)", "inferred"),
    "f32[D4+136]": ("climb_rate", "playback-rate multiplier of the jump-up, knee / chest climb-up, vault-1m/2m, "
                    "ladder dismount and 3 m hang states", "inferred"),
    "i32[D4+24]": ("plain_time_step", "locomotion phase-callback switch (plain dt vs speed-matched)", "see plan §7"),
    "f32[C0+120]": ("move_speed", "tested > 0 / <= 0 only (moving or not)", "named by tools/anim_graph (plan §7)"),
    "f32[C0+124]": ("turn_delta_deg", "180-degree turn", "named by tools/anim_graph"),
    "i32[C0+128]": ("use_transition_anims", "start / stop clip gate", "named by tools/anim_graph"),
    "i32[C0+132]": ("loco_enabled", "locomotion gate", "named by tools/anim_graph"),
    "i32[C0+136]": ("crouch_change_pending", "crouch-change gate", "named by tools/anim_graph"),
    "f32[C0+144]": ("move_dir_deg", "move direction, +left; |dir| <= 90 forward", "named by tools/anim_graph"),
    "f32[C0+148]": ("cover_side", "cover", "named by tools/anim_graph"),
    "f32[C0+152]": ("cover_f152", "cover", "named by tools/anim_graph"),
}
LOCO_TARGETS = {
    "idle": "IDLE", "run-fw": "MOVE", "run-bkwd": "MOVE", "idle^run-fwd": "MOVE (start clip; G1 drops it)",
    "idle^run-bkwd": "MOVE (start clip; G1 drops it)", "run-fw^idle": "IDLE (stop clip; G1 drops it)",
    "fall": "FALL", "fall-land-soft-idle": "LAND (soft idle)", "jump-long": "JUMP", "base-swim-idle": "SWIM (n/a)",
    "carry": "CARRY (n/a)", "carry-idle": "CARRY (n/a)", "idle-turn-l-180": "IDLE turn", "idle-turn-r-180": "IDLE turn",
}
BASE_MODES = ("walk", "run", "sprint", "crouch")
UNARMED = {"weapon-base": "anim-overlay-player-weapon-base-no-weapon",
           "weapon-draw-holster": "anim-overlay-player-weapon-draw-holster-no-weapon"}
VARIANT_LAYERS = ("ledge", "jump", "ladder-entry-exit", "wall-shimmy", "crouch-under")
BALANCE_MODES = {"walk-balance": "anim-overlay-player-move-walk-balance",
                 "run-balance": "anim-overlay-player-move-run-balance"}
TRAVERSAL_CLIP_RE = re.compile(r"vault|ledge|shimmy|climb|ladder|drop|jump|balanc|beam|crouch-under|squeez|hang|"
                               r"onto|fall|land-")


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def rnd(v, nd=4):
    return X.rnd(v, nd) if isinstance(v, float) else v


def height_of(name):
    """Authoring height label in a state / clip name, in metres (a label, not a measurement)."""
    m = re.search(r"(\d)o(\d\d)", name)
    if m:
        return float(m.group(1)) + float(m.group(2)) / 100.0
    m = re.search(r"jump(\d)-(\d)m", name)
    if m:
        return float(m.group(1)) + float(m.group(2)) / 10.0
    m = re.search(r"(?<![\d.])(\d)-(\d{1,2})m?(?![\d])", name)
    if m and ("climb" in name or "jump" in name or "onto" in name or "drop" in name):
        frac = m.group(2)
        return float(m.group(1)) + float(frac) / (10.0 if len(frac) == 1 else 100.0)
    m = re.search(r"(?<![\d-])(\d)m\b", name)
    if m:
        return float(m.group(1))
    return None


def geometry_label(state, leaves):
    """What the state name / clip names say about the geometry it was authored for (labels only)."""
    txt = state + " " + " ".join(leaves)
    g = {}
    h = height_of(state)
    if h is None:
        for c in leaves:
            h = height_of(c)
            if h is not None:
                break
    if h is not None:
        g["height_m"] = h
    if "drop-1m" in state:
        g["drop_m"] = 1.0
    for k in ("knee", "chest", "waist", "hang", "1-hand", "2-hand"):
        if re.search(r"(^|[-^])%s([-^]|$)" % re.escape(k), state) or ("ledge-" + k) in txt or ("-" + k + "-") in txt:
            g.setdefault("contact", []).append(k)
    if "close" in state:
        g["close"] = True
    m = re.match(r"^(idle|run|move|walk|edge|ladder|swim|auto-run|auto-walk)[\^-]", state)
    if m:
        g["entry"] = m.group(1)
    m = re.search(r"\^(idle|run|walk|knee|fall|edge|crouch)(-|$)", state)
    if m:
        g["exit"] = m.group(1)
    if g:
        g["source"] = "state / clip name labels (authoring intent, not measured)"
    return g or None


class TraversalExtract:
    def __init__(self, source_root):
        if not source_root:
            raise X.ExportError("Set ANIMATION_SOURCE_ROOT or pass --source-root")
        self.source_root = os.path.abspath(source_root)
        self.ex = X.Exporter(self.source_root)
        self.ex._gstate_cache = {}
        self.D = self.ex.D
        self.S = self.D["states"]
        self.by_name = self.ex.states_by_name
        self.F = self.ex.F
        self.N = self.ex.N
        self.db = self.ex.db
        self.warnings = []
        self.lambdas = {}
        self.index_b = {}
        self.index_a = {}
        with open(os.path.join(self.source_root, "blender_animation_index.csv")) as fh:
            import csv
            for row in csv.DictReader(fh):
                (self.index_b if row["character"] == "Actor_B" else self.index_a).setdefault(row["original_name"], row)

    # -------------------------------------------------------------------------------------------- state sets
    def family_of(self, name):
        for f, rx, _ in FAMILY_RE:
            if rx.search(name):
                return f
        return None

    def build_state_sets(self):
        fam = collections.OrderedDict((f, []) for f, _, _ in FAMILIES)
        self.state_family = {}
        for s in self.S:
            f = self.family_of(s["name"])
            if f and s["name"] not in self.state_family:
                fam[f].append(s["name"])
                self.state_family[s["name"]] = f
        # every keyword seed must be classified
        unclassified = []
        for s in self.S:
            n = s["name"]
            if SEED_EXCL_RE.search(n) or n in self.state_family or n in EXCLUDED:
                continue
            leaves = [x["clip"] for x in self.ex.tree_leaves(s["tree"])] if s.get("tree") else []
            reqs = [t["request"] for t in s["transitions"]]
            if SEED_RE.search(n) or any(SEED_RE.search(c) for c in leaves) or \
                    any(re.match(r"^(ledge|vault|chest-grab|waist-grab|knee$|shimmy)", r) for r in reqs):
                unclassified.append(n)
        if unclassified:
            raise X.ExportError("traversal keyword states neither in a family nor EXCLUDED: %s" % unclassified)
        self.families = fam

    # -------------------------------------------------------------------------------------------- lambdas
    def lam(self, fid, used_as, where):
        if not fid or fid == "0x00000000":
            return None
        if fid not in self.F:
            self.warnings.append("lambda %s (%s) not in functions" % (fid, where))
            return fid
        rec = self.lambdas.get(fid)
        if rec is None:
            paths, loads = self.ex.lambda_paths(fid)
            f = self.F[fid]
            rec = {"id": fid, "code_start": f.get("code_start"), "straight_line_return": f.get("straight_line_return"),
                   "paths": self.ex.lambda_text(fid), "reads": sorted(loads), "used_as": set(), "used_by": set()}
            self.lambdas[fid] = rec
        rec["used_as"].add(used_as)
        rec["used_by"].add(where)
        return fid

    # -------------------------------------------------------------------------------------------- selections
    def selection(self, weapon, mode, extra=None):
        if weapon == "unarmed":
            sel = self.ex.selection("bow", mode)
            for layer in ("weapon-base", "weapon-sub-type", "weapon-draw-holster"):
                sel.pop(layer, None)
            sel.update(UNARMED)
        else:
            sel = self.ex.selection(weapon, mode)
        for layer, sn in (extra or {}).items():
            if sn not in self.db.sets or self.db.set_layer[sn] != layer:
                raise X.ExportError("overlay set %s is not a %s set" % (sn, layer))
            sel[layer] = sn
        return sel

    def base_selections(self):
        out = collections.OrderedDict()
        for w in list(self.ex.B["profiles"]) + ["unarmed"]:
            for m in BASE_MODES:
                out["%s/%s" % (w, m)] = self.selection(w, m)
        return out

    def variant_sets(self):
        out = []
        for layer in VARIANT_LAYERS:
            m = self.ex.D["overlay_maps"]
            for om in m:
                if om["name"] == "anim-overlay-player-" + layer:
                    for e in om["entries"]:
                        if e["value"] in self.db.sets:
                            out.append((layer, e["key"], e["value"]))
        return out

    # -------------------------------------------------------------------------------------------- resolution
    def role_sig(self, role):
        return json.dumps([role["clip"], role["graph_clip"], role["status"],
                           [(l["clip"], l["graph_clip"], l["slot"], rnd(l["weight"]), l.get("excluded")) for l in role["layers"]],
                           role.get("resolution")], sort_keys=True)

    def compact_role(self, role):
        c = {"graph_clip": role["graph_clip"], "final_id": role["final_id"], "clip": role["clip"],
             "status": role["status"],
             "chain": ["%s %s @%s: %s -> %s" % (x["layer"], x["set"].replace("anim-overlay-player-", ""),
                                                x["record_offset"], x["from"], x["to"]) for x in role["chain"]]}
        if role.get("reason"):
            c["reason"] = role["reason"]
        if role.get("resolution") == "ambiguous":
            c["resolution"] = "ambiguous"
            c["resolver_alternatives"] = {k: v["clip"] or v["graph_clip"] for k, v in role["resolver_alternatives"].items()}
        lay = []
        for l in role["layers"]:
            d = {"clip": l["clip"], "graph_clip": l["graph_clip"], "status": l["status"], "slot": l["slot"],
                 "kind": l["kind"], "weight": rnd(l["weight"]), "weight_source": l["weight_source"],
                 "set": l["set"].replace("anim-overlay-player-", ""), "record_offset": l["record_offset"],
                 "key": l["key"], "flags": l["flags"]}
            if l.get("excluded"):
                d["excluded"] = l["excluded"]
            if l.get("weight_curve"):
                d["weight_curve"] = [rnd(v) for v in l["weight_curve"]]
            if l.get("prop_bones_keyed"):
                d["prop_bones_keyed"] = l["prop_bones_keyed"]
            lay.append(d)
        if lay:
            c["layers"] = lay
        if role["null_layers"]:
            c["null_layers"] = ["%s -> %s" % (n["to"], n["target"]) for n in role["null_layers"]]
        if role["state_substitutions"]:
            c["state_substitutions"] = role["state_substitutions"]
        if role["status"] != "resolved":
            a = self.actor_a_name(role["graph_clip"])
            if a:
                c["actor_a_clip"] = a
        return c

    def actor_a_name(self, graph_name):
        row = self.index_a.get(graph_name)
        return None if row is None else row["action_name"]

    def resolve_leaf(self, state, leaf, bases, variants):
        """All base selections, grouped by identical result, plus overlay-variant results that differ."""
        groups = collections.OrderedDict()
        base_roles = {}
        for key, sel in bases.items():
            where = "traversal:%s:%s:%s" % (state, leaf["id"], key)
            try:
                role = self.ex.build_role_from_id(state, leaf["clip"], leaf["clip_id"], sel, where, leaf)
            except X.ExportError as e:
                self.warnings.append("resolve %s: %s" % (where, e))
                continue
            base_roles[key] = role
            sig = self.role_sig(role)
            if sig not in groups:
                groups[sig] = {"selections": [], **self.compact_role(role)}
            groups[sig]["selections"].append(key)
        # variants
        var_groups = collections.OrderedDict()
        for key, sel in bases.items():
            if key not in base_roles:
                continue
            base = base_roles[key]
            chain_ids = {leaf["clip_id"], base["final_id"]} | {c["to_id"] for c in base["chain"]}
            for layer, vkey, sn in variants:
                if sel.get(layer) == sn:
                    continue
                vsel = dict(sel)
                vsel[layer] = sn
                r = self.db.resolve_id(leaf["clip_id"], vsel, self.ex.resolver)
                touches = r.final_id != base["final_id"] or any(k in self.db.layers[sn] for k in chain_ids) or \
                    bool(self.db.state_e[sn].get(self.ex.state_name_id(self.by_name[state])))
                if not touches:
                    continue
                try:
                    role = self.ex.build_role_from_id(state, leaf["clip"], leaf["clip_id"], vsel,
                                                      "traversal:%s:%s:%s+%s" % (state, leaf["id"], key, sn), leaf)
                except X.ExportError as e:
                    self.warnings.append("resolve variant %s %s: %s" % (state, sn, e))
                    continue
                if self.role_sig(role) == self.role_sig(base):
                    continue
                sig = sn + "|" + self.role_sig(role)
                if sig not in var_groups:
                    var_groups[sig] = {"layer": layer, "variant": vkey, "set": sn, "selections": [],
                                       **self.compact_role(role)}
                var_groups[sig]["selections"].append(key)
        return list(groups.values()), list(var_groups.values()), base_roles

    # -------------------------------------------------------------------------------------------- transitions
    def classify_target(self, target):
        if target in self.state_family:
            return self.state_family[target], None
        if target in LOCO_TARGETS:
            return "outside", LOCO_TARGETS[target]
        if target not in self.by_name:
            return "unknown_state_id", "target id is not a state in the table"
        return "outside", "other state (%s)" % target

    def transition(self, state, t, order):
        d = self.ex.decode_transition(t, order)
        d["use"] = self.ex.record_use(d)
        for c in d["conditions"]:
            if c.get("lambda"):
                self.lam(c["lambda"], "condition", state)
        fam, loco = self.classify_target(t["target"])
        d["target_family"] = fam
        if loco:
            d["target_note"] = loco
        if t["request"] in REQUEST_NOTES:
            d["request_note"] = REQUEST_NOTES[t["request"]]
        return d

    # -------------------------------------------------------------------------------------------- build
    def build(self):
        ex = self.ex
        self.build_state_sets()
        bases = self.base_selections()
        variants = self.variant_sets()
        incoming = collections.defaultdict(list)
        for s in self.S:
            for i, t in enumerate(s["transitions"]):
                incoming[t["target"]].append((s["name"], i, t))

        # mirror-flag evidence: trees shared by a state whose +0x2c callback returns constant 1 and one without it
        tree_users = collections.defaultdict(list)
        for s in self.S:
            if s.get("tree"):
                tree_users[s["tree"]].append((s["name"], s.get("callbacks", {}).get("0x0000002c")))
        const1 = {fid for fid, f in self.F.items() if (f.get("straight_line_return") or "").strip() == "1"}
        mirror_pairs = [v for v in tree_users.values()
                        if any(c in const1 for _, c in v) and any(c is None for _, c in v)]

        states = collections.OrderedDict()
        clip_states = collections.defaultdict(set)
        coverage = collections.OrderedDict()
        for fam, names in self.families.items():
            fam_cov = {"states": len(names), "states_all_leaves_resolved": [], "states_partly_resolved": [],
                       "states_unresolved": [], "code_entered": []}
            for name in names:
                s = self.by_name[name]
                g = ex.graph_state(name, fam)
                cbs = {}
                for k, v in sorted(s.get("callbacks", {}).items()):
                    role = {"0x00000024": "start_phase_cb", "0x00000028": "phase_update_cb",
                            "0x0000002c": "mirror_cb"}.get(k, k)
                    self.lam(v, role, name)
                    info = {"id": v, "expr": g["callbacks"][{"mirror_cb": "int_flag_cb"}.get(role, role)]["expr"]}
                    cbs[role] = info
                tree_nodes = g["tree_nodes"]
                for n in tree_nodes:
                    if n.get("weight_lambda"):
                        self.lam(n["weight_lambda"], "blend_weight", name)
                    if n.get("clip_callback"):
                        self.lam(n["clip_callback"], "leaf_clip_id", name)
                    if n.get("phase_lambda"):
                        self.lam(n["phase_lambda"], "leaf_phase", name)
                leaves_out = []
                seen = set()
                n_res = n_tot = 0
                for leaf in ex.tree_leaves(s["tree"]) if s.get("tree") else []:
                    if leaf["id"] in seen:
                        continue
                    seen.add(leaf["id"])
                    groups, vgroups, base_roles = self.resolve_leaf(name, leaf, bases, variants)
                    parent = ex.leaf_parent_weight(name, leaf)
                    lo = {"node": leaf["id"], "clip": leaf["clip"], "clip_id": leaf["clip_id"],
                          "parent_weight_lambda": parent["lambda"] if parent else None,
                          "resolutions": groups}
                    if vgroups:
                        lo["overlay_variants"] = vgroups
                    leaves_out.append(lo)
                    n_tot += 1
                    if any(gr["status"] == "resolved" for gr in groups):
                        n_res += 1
                    for gr in groups + vgroups:
                        if gr["clip"]:
                            clip_states[gr["clip"]].add(name)
                        for l in gr.get("layers", []):
                            if l["clip"]:
                                clip_states[l["clip"]].add(name)
                trans = [self.transition(name, t, i) for i, t in enumerate(s["transitions"])]
                inc = [{"from": src, "from_family": self.state_family.get(src, "outside"), "record": t["offset"],
                        "order": i, "request": t["request"], "fade_s": t["scalar_0x1c"]}
                       for src, i, t in incoming.get(name, []) if src != name]
                entered_by = "graph" if inc else "code (no incoming transition record in the whole graph)"
                if not inc:
                    fam_cov["code_entered"].append(name)
                leaf_names = [l["clip"] for l in leaves_out]
                st = {
                    "family": fam, "state_offset": s["offset"], "state_name_id": g["state_name_id"],
                    "record_kind": s["record_kind"], "tree": s.get("tree"), "reference_clip": s.get("reference_clip"),
                    "category": s.get("category"), "callbacks": cbs, "mirrored": self.mirror_of(cbs),
                    "loop": g["loop"], "entered_by": entered_by, "incoming": inc,
                    "geometry_label": geometry_label(name, leaf_names),
                    "tree_nodes": tree_nodes, "leaves": leaves_out, "transitions": trans,
                }
                states[name] = st
                if n_tot and n_res == n_tot:
                    fam_cov["states_all_leaves_resolved"].append(name)
                elif n_res:
                    fam_cov["states_partly_resolved"].append(name)
                else:
                    fam_cov["states_unresolved"].append(name)
            coverage[fam] = fam_cov

        # ledge-chain second-condition evidence (free-hang reading)
        fast = {n for n in self.families["ledge_climb"]
                if any(nd.get("weight_lambda") and (self.F[nd["weight_lambda"]].get("straight_line_return") or "").strip() == "0"
                       for nd in states[n]["tree_nodes"] if nd["kind"] == "blend")}
        second = {"le_0_5": collections.Counter(), "ge_0_5": collections.Counter()}
        for n in self.families["ledge_climb"]:
            for t in states[n]["transitions"]:
                if len(t["conditions"]) == 2 and t["request"] != "auto":
                    c2 = t["conditions"][1]
                    kind = "le_0_5" if c2["max"] is not None else "ge_0_5"
                    second[kind]["fast" if t["target"] in fast else "blended"] += 1
                    # not 'secondary...': LocoBrain maps that prefix to move_dir_deg (landing records)
                    t["conditions"][1]["variable"] = ("ledge_free_hang (second condition; INFERRED: f32[C8+84], "
                                                      "<= 0.5 braced, >= 0.5 hanging)")
                    t["conditions"][1]["variable_key"] = "ledge_free_hang"
                    t["condition_text"] = self.ex.condition_text(t["conditions"])

        # coverage under an extra traversal overlay (e.g. ledge=ladder makes the hand-over-hand states ladder states)
        for fam, names in self.families.items():
            via = collections.defaultdict(list)
            for name in names:
                if name in coverage[fam]["states_all_leaves_resolved"]:
                    continue
                sets = collections.Counter()
                for l in states[name]["leaves"]:
                    for v in l.get("overlay_variants", []):
                        if v["status"] == "resolved":
                            sets[v["set"]] += 1
                for sn, k in sets.items():
                    via[sn].append(name)
            coverage[fam]["states_resolved_only_under_overlay"] = dict(sorted(via.items()))

        # chains: from every code-entered state, follow the graph (preferred request, else the first plain auto record)
        chains = collections.OrderedDict()
        for fam, names in self.families.items():
            for name in names:
                if not states[name]["entered_by"].startswith("code") or fam == "hang_reactions":
                    continue
                paths = {"run": self.path(states, name, ("run", "run-fw")),
                         "idle": self.path(states, name, ("idle",))}
                if paths["idle"] == paths["run"]:
                    del paths["idle"]
                chains[name] = {"family": fam, "geometry_label": states[name]["geometry_label"], "paths": paths}

        # requests
        req = collections.OrderedDict()
        for name, st in states.items():
            for t in st["transitions"]:
                r = req.setdefault(t["request"], {"records": 0, "from_states": set(), "targets": collections.Counter(),
                                                  "fades": collections.Counter()})
                r["records"] += 1
                r["from_states"].add(name)
                r["targets"][t["target"]] += 1
                r["fades"][rnd(t["fade_s"])] += 1
        req_out = collections.OrderedDict()
        for k in sorted(req, key=lambda x: (-req[x]["records"], x)):
            r = req[k]
            req_out[k] = {"records": r["records"], "note": REQUEST_NOTES.get(k), "from_states": len(r["from_states"]),
                          "from_families": sorted({self.state_family.get(s, "outside") for s in r["from_states"]}),
                          "targets": dict(sorted(r["targets"].items())),
                          "fades_s": {str(f): c for f, c in sorted(r["fades"].items())}}

        # runtime fields
        fields = collections.OrderedDict()
        for fid, rec in sorted(self.lambdas.items()):
            for rd in rec["reads"]:
                f = fields.setdefault(rd, {"lambdas": set(), "used_as": set(), "states": set()})
                f["lambdas"].add(fid)
                f["used_as"] |= rec["used_as"]
                f["states"] |= rec["used_by"]
        fields_out = collections.OrderedDict()
        for rd in sorted(fields, key=lambda x: (x not in FIELD_INFO, x)):
            f = fields[rd]
            nm, meaning, status = FIELD_INFO.get(rd, (None, "not named", "unknown"))
            fields_out[rd] = {"name": nm, "meaning": meaning, "status": status, "used_as": sorted(f["used_as"]),
                              "lambdas": sorted(f["lambdas"]), "state_count": len(f["states"]),
                              "families": sorted({self.state_family.get(s, "outside") for s in f["states"]}),
                              "example_states": sorted(f["states"])[:8]}

        lambdas_out = collections.OrderedDict()
        for fid, rec in sorted(self.lambdas.items()):
            lambdas_out[fid] = {"code_start": rec["code_start"], "paths": rec["paths"], "reads": rec["reads"],
                                "used_as": sorted(rec["used_as"]), "state_count": len(rec["used_by"]),
                                "example_states": sorted(rec["used_by"])[:6]}
            if rec["used_as"] & {"condition"}:
                lambdas_out[fid]["named"] = ex.godot_expr(fid)

        # outside edges
        entries, exits = [], []
        for name, st in states.items():
            for i in st["incoming"]:
                if i["from_family"] == "outside":
                    entries.append({"from": i["from"], "to": name, "family": st["family"], "request": i["request"],
                                    "fade_s": i["fade_s"], "record": i["record"]})
            for t in st["transitions"]:
                if t["target_family"] in ("outside", "unknown_state_id"):
                    exits.append({"from": name, "family": st["family"], "to": t["target"],
                                  "loco": t.get("target_note"), "request": t["request"], "fade_s": t["fade_s"],
                                  "scalar_0x20": t["scalar_0x20"], "gate": t["condition_text"], "record": t["record"],
                                  "order": t["order"]})

        # Actor_B traversal clips never reached by a traversal leaf or layer
        reached = set(clip_states)
        unref = collections.defaultdict(list)
        for nm, row in sorted(self.index_b.items()):
            if row.get("kind") == "pose" or not TRAVERSAL_CLIP_RE.search(nm):
                continue
            act = row["action_name"]
            if act in reached or nm in reached:
                continue
            if re.match(r"^actor_b-(p-)?(land|fall)", nm) or re.search(r"horse|facial", nm):
                continue  # landings / falls are locomotion roles (tools/anim_graph); horse is out of scope
            src = [(s["name"].replace("anim-overlay-player-", ""), r["from_clip"], r["offset"])
                   for s in self.D["overlay_sets"] for r in s["remaps"] if r["to_clip"] == nm][:4]
            if re.match(r"^actor_b-ambi-|^actor_b-climb-on-|^actor_b-run-jump-across|^actor_b-idle\^angle-ladder|"
                        r"^actor_b-angle-ladder|^actor_b-ladder-climb-up-35|^ladder-climb-.*actor_b-ambi", nm):
                grp = "npc_ambient_traversal (companion AI set: enter / loop / exit per height; no player state)"
            elif re.match(r"^actor_b-(balance-beam|crouch-under)", nm):
                grp = "npc_beam_and_crouch_under (no player state; the player graph does balance as a movement " \
                      "mode and crouch-under as an aim overlay)"
            elif re.match(r"^(out\d|hun\d|lab\d|atk-)", nm) or "--actor_b" in nm:
                grp = "cinematic_or_scripted (one-off in-game-cinematic motion)"
            elif nm.startswith("actor_b-p-") and src:
                grp = "player_clip_not_reached (named by an overlay record, but no traversal leaf reaches that " \
                      "record under the exported selections and overlay variants)"
            elif nm.startswith("actor_b-p-"):
                grp = "player_clip_unreferenced (no overlay record names it; no graph leaf can reach it)"
            else:
                grp = "other"
            if any(u["clip"] == act for u in unref[grp]):
                continue
            unref[grp].append({"clip": act, "original_name": nm, "sample_rate": rnd(float(row["sample_rate"])),
                               "sample_count": int(row["sample_count"]), "asset_id": row["asset_id"],
                               "named_by_overlay_records": [{"set": a, "from": b, "record_offset": c} for a, b, c in src]})

        # balance movement modes (locomotion states under walk-balance / run-balance)
        balance = collections.OrderedDict()
        for mk, ov in BALANCE_MODES.items():
            sel = {"actor_b": ex.B["actor_b_overlay"], "move": ov}
            rows = []
            for st_name in ("idle", "run-fw", "run-bkwd", "idle-turn-l-180", "idle-turn-r-180"):
                s = self.by_name[st_name]
                for leaf in ex.tree_leaves(s["tree"]):
                    if leaf["clip"] == "idle" or leaf.get("callback"):
                        continue
                    r = self.db.resolve_id(leaf["clip_id"], sel, ex.resolver)
                    act, _ = ex.godot_action(r.final_name)
                    rows.append({"state": st_name, "leaf": leaf["clip"], "graph_clip": r.final_name, "actor_b_clip": act,
                                 "actor_a_clip": self.actor_a_name(r.final_name)})
            mr = [m for m in self.D["movement_modes"] if m["character"] == "Actor_B" and m["name"] == mk]
            balance[mk] = {"mode_record": mr[0]["offset"] if mr else None, "overlay": ov, "leaves": rows}

        clips_out = collections.OrderedDict()
        for act in sorted(clip_states):
            if act in ex.clips:
                c = dict(ex.clips[act])
                c["graph_names"] = sorted(ex.clip_graph_names.get(act, []))
                c["states"] = sorted(clip_states[act])
                clips_out[act] = c

        warnings = sorted(set(self.warnings + ex.warnings + ["exporter error (informational): " + e for e in ex.errors]))
        paths = {
            "source/player_blending/player_blending.json": os.path.join(self.source_root, "player_blending", "player_blending.json"),
            "source/blender_animation_index.csv": os.path.join(self.source_root, "blender_animation_index.csv"),
            "FR/tools/anim_graph/export_actor_b_graph.py": os.path.join(ANIM_GRAPH, "export_actor_b_graph.py"),
            "FR/tools/anim_graph/frontier_bindings.json": os.path.join(ANIM_GRAPH, "frontier_bindings.json"),
            "FR/tools/anim_graph/vendor/resolve_overlays.py": os.path.join(ANIM_GRAPH, "vendor", "resolve_overlays.py"),
            "FR/tools/anim_graph/vendor/symvm.py": os.path.join(ANIM_GRAPH, "vendor", "symvm.py"),
            "FR/tools/anim_graph/vendor/decode_lambda.py": os.path.join(ANIM_GRAPH, "vendor", "decode_lambda.py"),
        }
        meta = {
            "generator": GENERATOR, "schema_version": SCHEMA_VERSION,
            "inputs_sha256": {k: sha256_file(p) for k, p in paths.items()},
            "resolver": {"loop": ex.resolver, "compare": ex.resolver_compare,
                         "policy": "tools/anim_graph/frontier_bindings.json resolver_policy (one loop for every leaf); "
                                   "leaves where the two loops disagree carry resolution 'ambiguous'"},
            "resolver_disagreements": [{k: d[k] for k in ("where", "state", "leaf", "asc_fix", "asc_once")}
                                       for d in ex.resolver_disagreements if d["where"].startswith("traversal:")],
            "counts": {"states": len(states), "families": len(self.families), "lambdas": len(lambdas_out),
                       "runtime_fields": len(fields_out), "requests": len(req_out),
                       "transitions": sum(len(s["transitions"]) for s in states.values()),
                       "actor_b_clips": len(clips_out)},
            "conventions": {
                "fade_s": "transition scalar +0x1c; crossfade seconds (inferred, not proven; graph_understanding)",
                "order": "record order inside a state; the first record whose request matches and whose conditions "
                         "hold wins",
                "conditions": "(mode, min, max): mode bit 2 = at least min, bit 1 = at most max; the first condition "
                              "is the normalized phase of the source state (a first value > 1 is frames at 30 Hz, "
                              "inferred); later conditions test another variable (see variable)",
                "start_phase_0x24": "target start phase (inferred)",
                "scalar_0x20": "second duration of unknown purpose (-1 = unset)",
                "flags_0x04 / byte_0x28": "undecoded; copied",
                "mirror_cb": "state +0x2c callback; returns 1 (or a runtime int) to play the tree mirrored. Evidence: "
                             "%d trees are shared by a state whose +0x2c returns constant 1 and a state without "
                             "+0x2c, and the mirrored one is always the left / '-m' / other-hand twin (inferred)"
                             % len(mirror_pairs),
                "phase_update_cb": "state +0x28 callback returns the new phase (phase + rate*dt, or a value set "
                                   "by code)",
                "selections": "weapon/mode base selections of tools/anim_graph plus 'unarmed' (weapon-base / "
                              "draw-holster no-weapon sets; Frontier has no unarmed profile, reference only)",
                "overlay_variants": "results under an extra traversal overlay set (ledge / jump / ladder-entry-exit / "
                                    "wall-shimmy / crouch-under) that differ from the base result",
                "geometry_label": "heights / contacts parsed from state and clip names; authoring labels only",
            },
            "evidence": {
                "mirror_pairs": [[a for a, _ in v] for v in mirror_pairs][:12],
                "mirror_pair_count": len(mirror_pairs),
                "ledge_chain_second_condition": {k: dict(v) for k, v in second.items()},
                "ledge_chain_fast_states": sorted(fast),
            },
            "warnings": warnings,
        }
        return collections.OrderedDict([
            ("meta", meta),
            ("families", collections.OrderedDict((f, {"description": d, "states": self.families[f],
                                                      "coverage": coverage[f]}) for f, _, d in FAMILIES)),
            ("selections", collections.OrderedDict((k, dict(ex.ordered(v))) for k, v in bases.items())),
            ("overlay_variant_sets", [{"layer": l, "key": k, "set": s} for l, k, s in variants]),
            ("requests", req_out),
            ("runtime_fields", fields_out),
            ("lambdas", lambdas_out),
            ("chains", chains),
            ("entries_from_outside", entries),
            ("exits_to_outside", exits),
            ("balance_movement_modes", balance),
            ("actor_b_traversal_clips_without_player_state", dict(sorted(unref.items()))),
            ("clips", clips_out),
            ("states", states),
        ])

    CHAIN_SELECTIONS = ("musket/sprint", "musket/run", "musket/crouch")

    def step_clips(self, st):
        """Clip of the state's first leaf under the chain reference selections (ladder overlay if that is the only
        Actor_B result)."""
        if not st["leaves"]:
            return {}
        leaf = st["leaves"][0]
        out = {}
        for key in self.CHAIN_SELECTIONS:
            for r in leaf["resolutions"]:
                if key in r["selections"]:
                    clip = r["clip"]
                    if clip is None:
                        lad = [v for v in leaf.get("overlay_variants", [])
                               if v["set"].endswith("ledge-ladder") and key in v["selections"] and v["clip"]]
                        out[key.split("/")[1]] = ("ladder overlay: " + lad[0]["clip"]) if lad else \
                            ("MISSING " + r["graph_clip"])
                    else:
                        c = self.ex.clips.get(clip, {})
                        out[key.split("/")[1]] = "%s (%.2f s)" % (clip, c.get("length") or 0.0)
        return out

    def path(self, states, start, prefer):
        steps = []
        cur = start
        seen = {start}
        for _ in range(14):
            st = states[cur]
            outs = [t for t in st["transitions"] if t["target"] != cur]
            pick = next((t for t in outs if t["request"] in prefer), None)
            if pick is None:
                pick = next((t for t in outs if t["request"] == "auto" and not any(c.get("lambda") for c in t["conditions"])), None)
            if pick is None:
                pick = next((t for t in outs if t["request"] == "auto"), None)
            step = {"state": cur, "clips": self.step_clips(st)}
            if pick is None:
                reqs = sorted({t["request"] for t in outs})
                step["end"] = "waits for a request: " + ", ".join(reqs) if reqs else "no outgoing record (code exits)"
                steps.append(step)
                break
            step.update({"request": pick["request"], "fade_s": pick["fade_s"], "gate": pick["condition_text"],
                         "record": pick["record"], "to": pick["target"]})
            if pick.get("start_phase_0x24") is not None:
                step["start_phase"] = pick["start_phase_0x24"]
            steps.append(step)
            cur = pick["target"]
            if cur not in states:
                steps.append({"state": cur, "end": "outside the traversal set (%s)" %
                              (LOCO_TARGETS.get(cur) or "other")})
                break
            if cur in seen:
                steps.append({"state": cur, "end": "already on the path"})
                break
            if cur == "ledge-grab":
                steps.append({"state": cur, "end": "hang hub (ledge navigation, see §6)", "clips": self.step_clips(states[cur])})
                break
            seen.add(cur)
        return steps

    @staticmethod
    def mirror_of(cbs):
        m = cbs.get("mirror_cb")
        if not m:
            return False
        e = " ".join(m["expr"] or [])
        if e.strip() == "1":
            return True
        return "runtime: " + e


# ------------------------------------------------------------------------------------------------ markdown
def md_escape(s):
    return str(s).replace("|", "\\|")


def fam_state_line(g, name):
    st = g["states"][name]
    clips = []
    for l in st["leaves"]:
        res = sorted({(r["clip"] or ("MISSING " + r["graph_clip"])) for r in l["resolutions"]})
        var = sorted({"%s: %s" % (v["set"].replace("anim-overlay-player-", ""), v["clip"])
                      for v in l.get("overlay_variants", []) if v["clip"]})
        clips.append("%s → %s%s" % (l["clip"], ", ".join(res[:4]) + (" …" if len(res) > 4 else ""),
                                    (" [" + ", ".join(var[:3]) + (" …" if len(var) > 3 else "") + "]") if var else ""))
    outs = []
    for t in st["transitions"]:
        if t["request"].startswith("ledge-climb") or t["request"] in LEDGE_NAV_HASHES:
            continue
        outs.append("%s→%s %gs%s" % (t["request"], t["target"], rnd(t["fade_s"]),
                                     (" [" + t["condition_text"] + "]") if t["condition_text"] != "always" else ""))
    nav = sum(1 for t in st["transitions"] if t["request"].startswith("ledge-climb") or t["request"] in LEDGE_NAV_HASHES)
    if nav:
        outs.append("+%d ledge-nav records" % nav)
    entered = "code" if st["entered_by"].startswith("code") else "graph (%d)" % len(st["incoming"])
    mir = st["mirrored"]
    mir = "" if not mir else (" (mirrored)" if mir is True else " (mirror: runtime)")
    return "| `%s`%s | %s | %s | %s |" % (md_escape(name), mir, md_escape("; ".join(clips)), entered,
                                        md_escape("; ".join(outs)))


def make_md(g):
    L = []
    m = g["meta"]
    c = m["counts"]
    L.append("# Graph traversal logic (Actor_B player graph)")
    L.append("")
    L.append("Generated by `Frontier/%s` from the decoded player graph; do not edit by hand (regenerate). "
             "Machine-readable twin: `Frontier/data/traversal/graph_traversal.json`." % GENERATOR)
    L.append("")
    L.append("> **Provenance.** Numeric IDs (state name IDs, clip IDs, record offsets, `native_asset_id`) are copied, "
             "never recomputed.")
    L.append("")
    L.append("Counts: %d states in %d families, %d transition records, %d requests, %d lambdas reading %d runtime "
             "fields, %d Actor_B clips reached." % (c["states"], c["families"], c["transitions"], c["requests"],
                                                     c["lambdas"], c["runtime_fields"], c["actor_b_clips"]))
    L.append("")
    L.append(NARRATIVE.format(**narrative_values(g)))
    # chains
    L.append("## 4. Chains from the code-entered states")
    L.append("")
    L.append("Every traversal move starts in a state that no graph record enters: gameplay code picks it by geometry "
             "and speed. From there the graph runs the move. Each row follows the graph from that state, taking the "
             "`run` / `run-fw` request where one exists (idle path listed when it differs), otherwise the first plain "
             "`auto` record. Arrows read `—request fade [gate]→`. Clips: the first leaf under musket/sprint, "
             "musket/run and musket/crouch (bow and musket add `-bow--part` / `-rifle--part` layers, see the JSON).")
    L.append("")
    for fam, fd in g["families"].items():
        rows = [(n, ch) for n, ch in g["chains"].items() if ch["family"] == fam]
        if not rows:
            continue
        L.append("### %s" % fam)
        L.append("")
        L.append("| entry (code) | label | path | clips (sprint / run / crouch) |")
        L.append("|---|---|---|---|")
        for n, ch in rows:
            for pk, steps in ch["paths"].items():
                parts = []
                clips = []
                for s in steps:
                    if "request" in s:
                        sp = (" start %g" % s["start_phase"]) if s.get("start_phase") is not None else ""
                        parts.append("`%s` —%s %g%s [%s]→" % (s["state"], s["request"], rnd(s["fade_s"]), sp, s["gate"]))
                    else:
                        parts.append("`%s` (%s)" % (s["state"], s["end"]))
                    if s.get("clips"):
                        cs = s["clips"]
                        uniq = []
                        for k in ("sprint", "run", "crouch"):
                            if cs.get(k) and cs[k] not in uniq:
                                uniq.append(cs[k])
                        clips.append(" / ".join(uniq))
                lab = ch["geometry_label"] or {}
                lab = ", ".join("%s=%s" % (k, v) for k, v in lab.items() if k != "source")
                L.append("| `%s`%s | %s | %s | %s |" % (md_escape(n), "" if pk == "run" else " (idle path)", md_escape(lab),
                                                       md_escape(" ".join(parts)), md_escape("; ".join(clips))))
        L.append("")
    # families
    L.append("## 5. Families: states, clips, exits")
    L.append("")
    L.append("Columns: state (mirrored = +0x2c returns 1), leaves → Actor_B clip(s) over the 16 base selections "
             "(MISSING = no Actor_B action for the resolved name), how the state is entered, and its outgoing "
             "records `request→target fade [gate]` in record order (ledge-navigation records are counted, see §6).")
    L.append("")
    for fam, fd in g["families"].items():
        cov = fd["coverage"]
        L.append("### %s" % fam)
        L.append("")
        L.append(fd["description"])
        L.append("")
        L.append("Actor_B: %d of %d states fully resolved, %d partly, %d unresolved; %d entered by code." % (
            len(cov["states_all_leaves_resolved"]), cov["states"], len(cov["states_partly_resolved"]),
            len(cov["states_unresolved"]), len(cov["code_entered"])))
        for sn, lst in cov.get("states_resolved_only_under_overlay", {}).items():
            L.append("Under `%s` (and only there) %d more states get Actor_B clips." % (sn.replace("anim-overlay-player-", ""),
                                                                                      len(lst)))
        L.append("")
        L.append("| state | leaves → Actor_B | entered | out (request→target fade [gate]) |")
        L.append("|---|---|---|---|")
        for name in fd["states"]:
            L.append(fam_state_line(g, name))
        L.append("")
    # ledge nav matrix
    L.append("## 6. Ledge navigation matrix")
    L.append("")
    hubs = []
    for n, st in g["states"].items():
        k = sum(1 for t in st["transitions"] if t["request"].startswith("ledge-climb") or t["request"] in LEDGE_NAV_HASHES)
        if k and not n.endswith("^idle"):
            gates = sorted({t["condition_text"] for t in st["transitions"]
                            if t["request"].startswith("ledge-climb") or t["request"] in LEDGE_NAV_HASHES})
            hubs.append("`%s` %d (%s)" % (n, k, "; ".join(gates)))
    L.append("The hang hub `ledge-grab` carries 24 navigation records (below; all fade 0.2 s). The same block, with its "
             "own phase gate, is on every state that can be steered from: " + ", ".join(hubs) + ". The shimmy states "
             "lack `ledge-climb-lt` / `-rt`; the ladder mount has only `ledge-climb-up`.")
    L.append("")
    L.append("| request | target | fade | gate (ledge-grab) | gate (fall-grab-edge) | gate (ledge-grab-climb) |")
    L.append("|---|---|---|---|---|---|")
    hub = {t["request"]: t for t in g["states"]["ledge-grab"]["transitions"]}
    fge = {t["request"]: t for t in g["states"]["fall-grab-edge"]["transitions"]}
    lgc = {t["request"]: t for t in g["states"]["ledge-grab-climb"]["transitions"]}
    for r, t in hub.items():
        if not (r.startswith("ledge-climb") or r in LEDGE_NAV_HASHES):
            continue
        label = "`%s`" % r if r not in LEDGE_NAV_HASHES else "`%s` (%s)" % (r, LEDGE_NAV_HASHES[r].split(" ")[0])
        L.append("| %s | `%s` | %g | %s | %s | %s |" % (label, t["target"], rnd(t["fade_s"]), t["condition_text"],
                                                        fge[r]["condition_text"] if r in fge else "-",
                                                        lgc[r]["condition_text"] if r in lgc else "-"))
    L.append("")
    L.append("Settle states (`climb-*^idle`) chain directly into the next move without returning to the hub. "
             "Each record has two conditions: phase ≥ a AND a second variable ≤ 0.5 or ≥ 0.5 (read here as the "
             "free-hang amount; see §3):")
    L.append("")
    L.append("| settle state | request | target | fade | gate |")
    L.append("|---|---|---|---|---|")
    for name in g["families"]["ledge_climb"]["states"]:
        if not name.endswith("^idle"):
            continue
        for t in g["states"][name]["transitions"]:
            if t["request"] == "auto":
                continue
            L.append("| `%s` | `%s` | `%s` | %g | %s |" % (name, t["request"], t["target"], rnd(t["fade_s"]),
                                                          md_escape(t["condition_text"])))
    L.append("")
    # requests
    L.append("## 7. Requests used by traversal states")
    L.append("")
    L.append("| request | records | from states | targets | fades (s: count) | meaning |")
    L.append("|---|---|---|---|---|---|")
    for r, d in g["requests"].items():
        tg = ", ".join("%s×%d" % (k, v) for k, v in list(d["targets"].items())[:5]) + (" …" if len(d["targets"]) > 5 else "")
        L.append("| `%s` | %d | %d | %s | %s | %s |" % (md_escape(r), d["records"], d["from_states"], md_escape(tg),
                                                        ", ".join("%s: %d" % (k, v) for k, v in d["fades_s"].items()),
                                                        md_escape(d["note"] or "")))
    L.append("")
    # fields
    L.append("## 8. Runtime fields read by traversal lambdas")
    L.append("")
    L.append("| field | name | meaning | status | used as | states | families |")
    L.append("|---|---|---|---|---|---|---|")
    for k, d in g["runtime_fields"].items():
        L.append("| `%s` | %s | %s | %s | %s | %d | %s |" % (md_escape(k), d["name"] or "-", md_escape(d["meaning"]),
                                                           d["status"], ", ".join(d["used_as"]), d["state_count"],
                                                           ", ".join(d["families"])))
    L.append("")
    # outside edges
    L.append("## 9. Edges to and from the rest of the graph")
    L.append("")
    L.append("Entries from non-traversal states (everything else is entered by code):")
    L.append("")
    L.append("| from | request | to | fade | record |")
    L.append("|---|---|---|---|---|")
    for e in g["entries_from_outside"]:
        L.append("| `%s` | `%s` | `%s` | %g | %s |" % (e["from"], e["request"], e["to"], rnd(e["fade_s"]), e["record"]))
    L.append("")
    L.append("Exits to non-traversal states, grouped (fade, gate):")
    L.append("")
    L.append("| to | Frontier state | request | fade | gate | from states |")
    L.append("|---|---|---|---|---|---|")
    grp = collections.OrderedDict()
    for e in g["exits_to_outside"]:
        k = (e["to"], e["loco"], e["request"], rnd(e["fade_s"]), e["gate"])
        grp.setdefault(k, []).append(e["from"])
    for (to, loco, rq, fade, gate), frs in sorted(grp.items(), key=lambda kv: (kv[0][0], kv[0][2], -len(kv[1]))):
        L.append("| `%s` | %s | `%s` | %g | %s | %s |" % (md_escape(to), loco or "-", md_escape(rq), fade, md_escape(gate),
                                                        md_escape(", ".join(frs[:6]) + (" … (%d)" % len(frs) if len(frs) > 6 else ""))))
    L.append("")
    # clips without states
    L.append("## 10. Actor_B traversal clips with no player-graph state")
    L.append("")
    for grp_name, rows in g["actor_b_traversal_clips_without_player_state"].items():
        L.append("**%s** (%d):" % (grp_name, len(rows)))
        L.append("")
        if grp_name.startswith("player_clip_not_reached"):
            L.append(", ".join("`%s` (← %s)" % (r["clip"], "; ".join("%s `%s`" % (x["set"], x["from"])
                                                                   for x in r["named_by_overlay_records"]))
                               for r in sorted(rows, key=lambda r: r["clip"])))
        else:
            L.append(", ".join("`%s`" % r["clip"] for r in sorted(rows, key=lambda r: r["clip"])))
        L.append("")
    # balance
    L.append("## 11. Balance movement modes")
    L.append("")
    L.append("| mode | Actor_B record | state | leaf | resolved | Actor_B clip | Actor_A clip |")
    L.append("|---|---|---|---|---|---|---|")
    for mk, d in g["balance_movement_modes"].items():
        for r in d["leaves"]:
            L.append("| %s | %s | `%s` | `%s` | `%s` | %s | %s |" % (mk, d["mode_record"], r["state"], r["leaf"],
                                                                  r["graph_clip"], r["actor_b_clip"] or "none",
                                                                  r["actor_a_clip"] or "none"))
    L.append("")
    L.append(TAIL.format(**narrative_values(g)))
    if m["warnings"]:
        L.append("## Appendix: generator warnings (%d)" % len(m["warnings"]))
        L.append("")
        for w in m["warnings"][:60]:
            L.append("- " + md_escape(w))
        if len(m["warnings"]) > 60:
            L.append("- … %d more in `meta.warnings`" % (len(m["warnings"]) - 60))
        L.append("")
    return "\n".join(L) + "\n"


def narrative_values(g):
    st = g["states"]
    fam = g["families"]
    code_entered = sum(len(f["coverage"]["code_entered"]) for f in fam.values())
    ev = g["meta"]["evidence"]
    sc = ev["ledge_chain_second_condition"]

    def cov(f):
        c = fam[f]["coverage"]
        return "%d/%d" % (len(c["states_all_leaves_resolved"]), c["states"])
    vals = {
        "n_states": len(st), "code_entered": code_entered, "mirror_pairs": ev["mirror_pair_count"],
        "le_fast": sc.get("le_0_5", {}).get("fast", 0), "le_blend": sc.get("le_0_5", {}).get("blended", 0),
        "ge_fast": sc.get("ge_0_5", {}).get("fast", 0), "ge_blend": sc.get("ge_0_5", {}).get("blended", 0),
        "n_fields": len(g["runtime_fields"]), "n_families": len(fam),
    }
    for f in fam:
        vals["cov_" + f] = cov(f)
    return vals


def _read_template(name):
    """Hand-written parts of the md (str.format placeholders filled by narrative_values)."""
    with open(os.path.join(HERE, name), encoding="utf-8") as fh:
        return fh.read()


NARRATIVE = _read_template("graph_traversal_narrative.md")
TAIL = _read_template("graph_traversal_tail.md")


def to_jsonable(o):
    if isinstance(o, set):
        return sorted(o)
    raise TypeError(type(o))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--source-root", default=os.environ.get("ANIMATION_SOURCE_ROOT", DEFAULT_SOURCE_ROOT))
    ap.add_argument("--out", default=os.path.join(FR_ROOT, "data", "traversal", "graph_traversal.json"))
    ap.add_argument("--md", default=None, help="default: <source_root>/graph_analysis/traversal/graph_traversal.md")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args(argv)
    if not a.source_root:
        ap.error("set ANIMATION_SOURCE_ROOT or pass --source-root")
    md_path = a.md or os.path.join(a.source_root, "graph_analysis", "traversal", "graph_traversal.md")
    try:
        g = TraversalExtract(a.source_root).build()
    except X.ExportError as e:
        print("TRAVERSAL EXTRACT FAILED: %s" % e, file=sys.stderr)
        return 1
    js = json.dumps(X.norm_floats(json.loads(json.dumps(g, default=to_jsonable))), indent=1, ensure_ascii=False) + "\n"
    md = make_md(json.loads(js))
    files = {a.out: js, md_path: md}
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
        print("CHECK OK: %s" % json.dumps(g["meta"]["counts"]))
        return 0
    for p, txt in files.items():
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as fh:
            fh.write(txt)
    print("wrote %s and %s: %s" % (a.out, md_path, json.dumps(g["meta"]["counts"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
