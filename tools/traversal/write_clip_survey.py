#!/usr/bin/env python3
"""Writes the Actor_B traversal clip survey (Markdown) from data/traversal/clip_geometry.json and
data/traversal/traversal_catalog.json.

    python3 tools/traversal/write_clip_survey.py            # writes PAP/graph_analysis/traversal/clip_survey.md
    python3 tools/traversal/write_clip_survey.py --check    # exit 1 when the committed survey is stale

Pipeline: build_traversal_catalog.py (clip list, names, graph links) -> measure_traversal_clips.gd
(Godot, measures the clips on the rig) -> this script. Standard library only, Python 3.9.
"""
from __future__ import annotations

import argparse
import collections
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
PAP = os.environ.get("ANIM_GRAPH_PAP", "/Users/kiwimango/Downloads/Player_Animation_Project")
GEOMETRY = os.path.join(ROOT, "data", "traversal", "clip_geometry.json")
CATALOG = os.path.join(ROOT, "data", "traversal", "traversal_catalog.json")
OUT = os.path.join(PAP, "graph_analysis", "traversal", "clip_survey.md")

FAMILY_ORDER = ["vault", "climb_up", "ledge_hang", "wall_shimmy", "edge_warn", "ladder", "drop",
                "gap_jump", "beam", "crouch_under", "squeeze"]
FAMILY_TITLE = {
    "vault": "Vaults", "climb_up": "Climb-ups and jump-ups to a ledge", "ledge_hang": "Ledge hang, catch and hang climb-up",
    "wall_shimmy": "Wall shimmy (standing sidle on a narrow ledge)", "edge_warn": "Edge warnings (stop at a drop)",
    "ladder": "Ladders", "drop": "Drops and climb-downs", "gap_jump": "Gap jumps", "beam": "Balance beam",
    "crouch_under": "Crouch-under", "squeeze": "Squeeze-through",
}


def short(n):
    return n[len("actor_b-"):] if n.startswith("actor_b-") else n


def f2(x, nd=2):
    if x is None:
        return "-"
    if isinstance(x, bool):
        return "yes" if x else "no"
    if isinstance(x, (int, float)):
        return ("%." + str(nd) + "f") % x
    return str(x)


def pose(e):
    if not e:
        return "-"
    p = e.get("pose", "-")
    d = e.get("pose_dist")
    tag = p if d is None or d <= 20 else "(%s?)" % p
    return "%s %s" % (e.get("gait", "-"), tag)


def first_top(c):
    im = c.get("implied", {})
    fh = im.get("first_hand_contact")
    if not fh:
        return "-"
    return "%s %.1fs @ %.2f m, fwd %.2f" % (fh["side"], fh["t"], fh["h"], fh["fwd"])


def hint(c):
    h = c.get("name_hints", {})
    for k in ("height_m", "gap_m"):
        if k in h:
            return "%s %g" % ("h" if k == "height_m" else "gap", h[k])
    if "height_range_m" in h:
        return "h %g-%g" % tuple(h["height_range_m"])
    return ""


def graph_states(c, limit=4):
    sts = sorted({g["state"] for g in c.get("graph", []) if g["role"] == "leaf"})
    if not sts:
        return ""
    s = ", ".join(sts[:limit])
    return s + (" +%d" % (len(sts) - limit) if len(sts) > limit else "")


def base_rows(clips, names):
    rows = []
    for n in names:
        c = clips[n]
        if "travel" not in c:
            continue
        t = c["travel"]
        im = c["implied"]
        o = c["odometry"]
        rows.append("| `%s` | %s | %s | %s | %s | %s / %s | %s | %s | %s | %s | %s |" % (
            short(n), f2(c["length"], 1), pose(c["entry"]), pose(c["exit"]),
            "%s -> %s" % (f2(c["entry"]["speed_h"], 1), f2(c["exit"]["speed_h"], 1)),
            f2(t["fwd"]), f2(t["up_max"]), f2(im.get("hand_top_h_median")), first_top(c),
            f2(t.get("height_change")), f2(o["flight_s"], 1), o["confidence"] + (" " + hint(c) if hint(c) else "")))
    head = ("| clip | s | entry (gait pose) | exit (gait pose) | speed in -> out | fwd / pelvis up max m | hand top m | "
            "first hand plant (hand t @ top, fwd) | end support m | flight s | confidence, name hint |")
    sep = "|" + "---|" * 11
    return [head, sep] + rows


def variant_rows(clips, names):
    rows = []
    for n in names:
        c = clips[n]
        k = c["variant"]["kind"]
        if k == "base":
            continue
        p = c.get("part") or {}
        g = c["keyed"]["groups"]
        grp = ", ".join("%s %d" % (x, g[x]) for x in sorted(g) if g[x])
        lost = p.get("supporting_hands_lost")
        rows.append("| `%s` | %s%s | `%s` | %s | %s | %s | %s | %s |" % (
            short(n), k, (" " + c["variant"]["weapon"]) if c["variant"].get("weapon") else "",
            short(p.get("base_clip") or c["variant"].get("base_missing") or "-"),
            c["keyed"]["slot"], c["keyed"]["count"], grp,
            "yes" if p.get("length_match") else ("no (%s vs %s s)" % (f2(p.get("length"), 1), f2(p.get("base_length"), 1)) if p.get("base_clip") else "no base"),
            (", ".join(lost) if lost else ("none" if lost is not None else "-")) + (
                "; palm offset l %.2f r %.2f" % (p["palm_offset_max"]["l"], p["palm_offset_max"]["r"]) if p.get("palm_offset_max") else "")))
    if not rows:
        return []
    return ["| variant | kind | base | slot | keyed bones | keyed groups | length matches base | supporting hands lost; max palm offset m |",
            "|" + "---|" * 8] + rows


def chain_rows(chains, fam_names):
    out = []
    for ch in chains:
        if not any(p in fam_names for p in ch["parts"]):
            continue
        pt = ch["pelvis_travel"]
        out.append("- %s: %.1f s, pelvis travel fwd %.2f m, up %.2f m, side %.2f m" % (
            " -> ".join("`%s`" % short(p) for p in ch["parts"]), ch["duration"], pt["fwd"], pt["up"], pt["side"]))
    return out


def median(xs):
    xs = sorted(x for x in xs if x is not None)
    if not xs:
        return None
    return xs[len(xs) // 2]


def rng(xs):
    xs = [x for x in xs if x is not None]
    if not xs:
        return "-"
    return "%.2f-%.2f" % (min(xs), max(xs))


def family_notes(fam, clips, names, geo_chains=()):
    """Data-derived bullet points per family (numbers from clip_geometry.json)."""
    C = {n: clips[n] for n in names if "travel" in clips[n]}
    notes = []
    if fam == "vault":
        tops = {n: c["implied"].get("hand_top_h_median") for n, c in C.items() if c["implied"].get("hand_top_h_median") is not None}
        p1 = {n: v for n, v in tops.items() if "-p-" in n and "1m" in n}
        notes.append("Supporting hand-plant heights (top of the obstacle above the start support): all vault clips with a plant "
                     "%s m; player `-1m` vaults %s m (%s). `p-idle^vault-over-2m` plants at %s m." % (
                         rng(tops.values()), rng(p1.values()), ", ".join("`%s` %.2f" % (short(n), v) for n, v in sorted(p1.items())),
                         f2(tops.get("actor_b-p-idle^vault-over-2m"))))
        chs = [ch for ch in geo_chains if ch["parts"][0].endswith("p-sprint-vault-1")]
        if chs:
            ch = chs[0]
            first = clips[ch["parts"][0]]
            last = clips[ch["parts"][-1]]
            notes.append("The sprint vault is four chained parts (`p-sprint-vault-1..4`, exact pose links, %.1f s) that the graph "
                         "plays as the test-vault states under the sprint move set (`run^test-vault-begin` -> `test-vault-mid` -> "
                         "`test-vault^test-vault-end-run` -> `test-vault-end^run`): entry %.1f m/s, one-hand plant, exit %.1f m/s, "
                         "chain travel %.2f m forward, %.2f m up. It is the only vault the graph plays from sprint." % (
                             ch["duration"], first["entry"]["speed_h"], last["exit"]["speed_h"], ch["pelvis_travel"]["fwd"],
                             ch["pelvis_travel"]["up"]))
        notes.append("Ambient `ambi-run^vault-over-*` sets (enter / loop / exit, `-in-place`, `-width0-5m`, `round`, `up` / `down`) "
                     "have a run-up loop between enter and exit; no player graph state plays them, but they are Actor_B motion and "
                     "add vault-onto (`up`) and vault-off (`down`) variants.")
    elif fam == "climb_up":
        notes.append("Jump-up to ledge clips (`p-idle-/run-/crouch-jump-up-*^ledge*`) end with the hands on the ledge top; the chest "
                     "variants (2 m) are begin / mid / end parts. Their exits are `p-ledge-knee-climb-up^*` (from a knee on the ledge) "
                     "and `p-ledge-chest-climb-up^*` (from the chest), each with idle / crouch / run / walk exits.")
        notes.append("`climb-on-{0-5,1,1-5,2,2-5,3}m-up^{run-enter,run-loop,run-exit,idle-exit}` are ambient climb-onto sets for six "
                     "heights with left / right / in-place entries; no player graph state plays them, but they give a height-graded "
                     "climb-onto family for free-running (hand-top heights measured below).")
    elif fam == "ledge_hang":
        hc = C.get("actor_b-p-ledge-hang-climb-up^ledge-knee")
        hang_txt = "-"
        if hc:
            hands = [h for h in hc["contacts"]["hands"] if h["supporting"]]
            hang_txt = "%.1f s; supporting hand contacts %s; the align rises %.2f m while the hands stay on the ledge top, hand top %.2f m above the hanging feet" % (
                hc["length"], ", ".join("%s %.1f-%.1f s" % (h["hand"], h["t0"], h["t1"]) for h in hands[:4]) or "-",
                hc["travel"]["align_up"], (hands[0]["surface_up"] if hands else float("nan")))
        notes.append("Actor_B has no hanging idle loop, no hanging shimmy and no ledge-to-ledge jumps: the graph's `ledge-grab` / "
                     "`ledge-shimmy-*` / `ledge-climb-{up,dn,lt,rt}*` / `climb-far-*` / corner states resolve to clip names that are in "
                     "neither library (see Graph gaps). What exists: the 3 m jump-up to hang (begin / mid / end), the hang climb-up to "
                     "a knee on the ledge (%s), the falling ledge catch, the failed grab and the "
                     "2.75 m grab sequence. A hang idle can be held on the last frame of `p-idle-jump-up-3m^ledge-hang-end` (the same "
                     "pose starts `p-ledge-hang-climb-up^ledge-knee`); shimmy and ledge-to-ledge moves need hand IK / procedural motion "
                     "or the ladder clips (which the graph itself reuses for ledge climbing via the ledge-ladder overlay)." % hang_txt)
    elif fam == "ladder":
        up = {n: c["travel"]["up_net"] for n, c in C.items() if n.endswith(("climb-up-fast--a", "climb-up-fast--b"))}
        dn = {n: c["travel"]["up_net"] for n, c in C.items() if n.endswith(("climb-down-fast--a", "climb-down-fast--b"))}
        slow = [C[n]["travel"]["up_net"] for n in ("actor_b-p-ladder-climb-up", "actor_b-p-ladder-climb-up^idle") if n in C]
        notes.append("The graph's ledge-climb states double as the ladder: under the `ledge-ladder` overlay `climb-up` / `climb-down` / "
                     "`-fast--a/b` / `ledge-grab-base` resolve to `p-ladder-climb-*` / `p-ladder-idle`. Fast climb-up halves rise %s m "
                     "in %.1f s (%s); fast climb-down halves descend %s m (%s); the slow `p-ladder-climb-up` + `p-ladder-climb-up^idle` "
                     "pair rises %s m in total." % (
                         rng(up.values()), C["actor_b-p-ladder-climb-up-fast--a"]["length"] if "actor_b-p-ladder-climb-up-fast--a" in C else 0.0,
                         ", ".join("`%s` %.2f" % (short(n), v) for n, v in sorted(up.items())),
                         rng([-v for v in dn.values()]), ", ".join("`%s` %.2f" % (short(n), -v) for n, v in sorted(dn.items())),
                         f2(sum(slow)) if len(slow) == 2 else "-"))
        notes.append("Mount / dismount clips cover bottom and top, top with a vault over a rail, and the ambient `angle-ladder` "
                     "(inclined ladder) and `ambi-idle^ladder-*` sets; these are the best Actor_B source for vertical climbing on "
                     "tree trunks and walls (alternating hand-over-hand grips).")
    elif fam == "beam":
        lp = C.get("actor_b-balance-beam-loop")
        if lp:
            notes.append("`balance-beam-loop` travels %.2f m in %.1f s (%.2f m/s) with feet placed on one line (lateral spread %.2f m): "
                         "usable for thick branches and fallen logs. The exits (`-exit`, `-exit-quarter`, `-exit-half`, `-exit-3-quarters`, "
                         "named for where on the beam they step off) travel %s m forward." % (
                             lp["travel"]["fwd"], lp["length"], lp["travel"]["fwd"] / lp["length"], lp["implied"].get("foot_side_spread", 0.0),
                             rng(C[n]["travel"]["fwd"] for n in C if "exit" in n)))
    elif fam == "crouch_under":
        lp = C.get("actor_b-crouch-under-loop")
        if lp:
            notes.append("`crouch-under-loop`: %.2f m/s, head top %.2f-%.2f m above the floor: needs about %.2f m clearance "
                         "(roots, fallen trunks, low branches)." % (lp["travel"]["fwd"] / lp["length"], lp["travel"]["head_top_min"],
                                                                     lp["travel"]["head_top_max"], lp["travel"]["head_top_max"] + 0.05))
    elif fam == "wall_shimmy":
        lp = C.get("actor_b-p-ledge-walk-r-loop")
        if lp:
            notes.append("`p-ledge-walk-r-loop` sidles %.2f m to the right per %.1f s loop (%.2f m/s); mirror for the left (the graph "
                         "plays the same `-r` clips for `wall-shimmy-move-left`). Enter / exit / idle clips complete the set; the "
                         "graph's wall-shimmy climb-up / ledge-drop links have Actor_A clips only." % (
                             -lp["travel"]["side"], lp["length"], -lp["travel"]["side"] / lp["length"]))
    elif fam == "drop":
        notes.append("`p-drop-down^fall` / `p-crouch-drop-down^fall` (+ `--bow` / `--rifle`) step off an edge into the fall state; "
                     "the fall itself is gameplay physics. `climb-on-{0-5..3}m-down^*` are ambient controlled climb-downs "
                     "(enter / loop / exit); `p-jump-down-2m` is a standing hop down.")
    elif fam == "gap_jump":
        notes.append("Long jump (`p-run^jump-long` -> `p-jump-long`), one-foot 1.5 m jumps (`p-jump-lfoot/rfoot-1-5m` with idle / run "
                     "exits and `p-run^` entries), the standing `p-idle^jump-1-5m`, and the ambient `run-jump-across-2m` set. In "
                     "`p-jump-long` the pelvis stays at ~0.8 m in skeleton space through the flight while the feet tuck and land "
                     "0.3 m below the skeleton origin: the jump arc is carried by the unexported align, so flight distance and "
                     "height are gameplay physics and the clips give the takeoff and landing timing.")
    elif fam == "edge_warn":
        notes.append("Stand and crouch stop-at-edge clips for four directions (graph `ledge-stop-*`): short step back of 0.1-0.3 m.")
    elif fam == "squeeze":
        notes.append("Only the cinematic `out4-actor_b-squeeze-through--actor_b` (8.3 s) exists; usable as reference or cut into a "
                     "gap-squeeze move.")
    return notes


def build(geo, cat):
    clips = geo["clips"]
    fams = collections.defaultdict(list)
    for n, c in clips.items():
        fams[c["family"]].append(n)
    for f in fams:
        fams[f].sort()
    L = []
    L.append("# Actor_B traversal clip survey")
    L.append("")
    L.append("Generated by `Frontier/tools/traversal/write_clip_survey.py` from `Frontier/data/traversal/clip_geometry.json` "
             "(`measure_traversal_clips.gd`, measured in Godot %s on `characters/Actor_B.tscn` with the null-add bind rest) and "
             "`traversal_catalog.json` (`build_traversal_catalog.py`). Do not edit by hand." % geo["meta"].get("godot_version", "?"))
    L.append("")
    L.append("**Provenance.** Native asset IDs and original names are kept in the JSON (`native_asset_id`, `original_name`, "
             "`index[].asset_id`).")
    L.append("")
    counts = collections.Counter()
    for n, c in clips.items():
        counts[(c["family"], "base" if c["variant"]["kind"] == "base" else "variant")] += 1
    L.append("## Summary")
    L.append("")
    L.append("| family | clips | base / variants (weapon arm layers, finger layers) | player graph states with an Actor_B clip |")
    L.append("|---|---|---|---|")
    for f in FAMILY_ORDER:
        names = fams.get(f, [])
        sts = sorted({g["state"] for n in names for g in clips[n].get("graph", []) if g["role"] == "leaf"})
        L.append("| %s | %d | %d / %d | %d |" % (f, len(names), counts[(f, "base")], counts[(f, "variant")], len(sts)))
    L.append("")
    conf = collections.Counter(c["odometry"]["confidence"] for c in clips.values() if "odometry" in c)
    gaps = cat.get("graph_gaps", [])
    gap_f = collections.Counter(g["family"] for g in gaps)
    L.append("Key findings for the free-running / free-climbing design:")
    L.append("")
    L.append("- **No root motion.** No clip keys travel on a ground-level root: the rig has no such bone (its `root` bone is "
             "the hips, at pelvis height), and the game's align / trajectory channel was not exported. Travel, obstacle heights and contact "
             "positions below are reconstructed from contacts (feet, palms, knees are static in the world while planted). "
             "Confidence: %d high, %d medium, %d low of %d measured full-body clips." % (conf["high"], conf["medium"], conf["low"], sum(conf.values())))
    insk = sorted(n for n, c in clips.items() if (c.get("root_motion") or {}).get("in_skeleton"))
    L.append("- **Travel in the skeleton.** %d clips move the hips themselves >= 0.5 m through skeleton space (their travel is "
             "in the skeleton rather than the align): %s. The contact reconstruction handles both cases; the runtime must not "
             "add the align path on top of the hips' own travel for these." % (len(insk), ", ".join("`%s`" % short(n) for n in insk)))
    L.append("- **Hanging ledge navigation is the big gap.** %d traversal graph states have no Actor_B clip (%s). All hang shimmy, "
             "hang idle, directional ledge-to-ledge climbs (`ledge-climb-up/dn/lt/rt`, `far-*`), corners and hang looks resolve to "
             "clip names that exist in neither library. The graph reuses these states for ladders through the `ledge-ladder` "
             "overlay, which is the only way they reach Actor_B clips." % (len(gaps), ", ".join("%s %d" % (k, v) for k, v in sorted(gap_f.items()))))
    L.append("- **What free-running can use directly:** sprint / run / idle vaults over ~1 m (with bow / rifle arm parts), "
             "jump-up to knee (1-1.5 m by name), chest (2 m) and hang (3 m) ledges with knee / chest climb-up exits, the hang climb-up, "
             "the ledge catch from a fall, height-graded ambient climb-onto (0.5-3 m) and climb-down sets, ladders (loops, fast "
             "alternates, mounts, dismounts, inclined ladder), a balance-beam walk, crouch-under, wall shimmy, edge stops, "
             "drops into the fall state, and long / one-foot jumps.")
    L.append("- **Tree climbing** has no dedicated clips: the ladder and inclined-ladder climb loops (hand-over-hand, ~0.5 m per "
             "half-cycle) and the hang climb-up are the closest motion; branches as ledges use the jump-up / hang / climb-up "
             "set, and thick branches / fallen logs use the balance beam.")
    parts = [c for c in clips.values() if c["variant"]["kind"] == "part"]
    lost = [c for c in parts if (c.get("part") or {}).get("supporting_hands_lost")]
    L.append("- **Weapons.** %d weapon layers (`-bow--part` / `-rifle--part`, and `--bow` / `--rifle` on the hang clips and "
             "`p-drop-down^fall`) key only the arms, hands and prop bones (56 bones) over their base clip; the graph adds them as "
             "weapon-base layer records. In %d of them a hand that supports the body in the base clip no longer stays planted "
             "once the layer is applied (the layer moves that arm, e.g. to carry the weapon), and palms move up to %.2f m from "
             "the base pose: two-handed moves with a weapon out need hand IK or a holster. `--hands` clips (%d) are finger "
             "poses at 2 Hz." % (
                 len(parts), len(lost),
                 max([max(c["part"]["palm_offset_max"]["l"], c["part"]["palm_offset_max"]["r"]) for c in parts
                      if (c.get("part") or {}).get("palm_offset_max")] or [0.0]),
                 sum(1 for c in clips.values() if c["variant"]["kind"] == "hands")))
    L.append("")
    L.append("## How the clips were measured")
    L.append("")
    L.append("Every catalogue clip was evaluated on the real rig in Godot (track interpolation at the clip's key times, "
             "skeleton space: +Z forward, +X left, +Y up). Because the clips are in place relative to an unexported moving "
             "align, the tool rebuilds the align path from contacts: per step it picks a planted anchor (a foot as a rolling "
             "heel-ball sole, a palm, or a kneeling knee) or flight, with a Viterbi path over physics costs (centre-of-mass "
             "smoothness; supported bodies cannot fall faster than gravity; feet obey friction; flights are ballistic and "
             "landings may absorb an upward, friction-bounded impact). Short or chained parts are measured together with "
             "their context (authored pose chains, ambient enter / loop / exit sets, graph successions, or locomotion-loop phases). "
             "World frame = the character's position at the clip's first sample. Full parameters: `clip_geometry.json` "
             "`meta.method`.")
    L.append("")
    L.append("Limits: contact times are at the key rate (10 Hz for most traversal clips, +-0.1 s), heights are within about "
             "0.1-0.2 m, and motion carried by the align with the body posed in place (flights, falls) is unobservable "
             "(ballistic assumption; confidence `low`). The per-clip entry prior (bank speed of the gait the name enters from) "
             "is recorded in `odometry.context.entry_prior_speed`. Name hints (`1m`, `2m` ...) are the designers' labels; the "
             "measured top can differ, especially for exit parts of a set.")
    L.append("")
    L.append("Columns in the tables: *entry / exit* = gait by speed and the nearest reference pose (`(pose?)` when no reference "
             "is within 20 deg); *speed* = centre-of-mass horizontal speed over the first / last 0.2 s; *fwd* = pelvis world "
             "displacement; *pelvis up max* = highest pelvis rise; *hand top* = median supporting hand-plant surface height above "
             "the start support; *first hand plant* = hand, time, top height and forward distance of the first supporting plant; "
             "*end support* = height change of the feet between the first and last sample.")
    L.append("")
    for f in FAMILY_ORDER:
        names = fams.get(f, [])
        if not names:
            continue
        L.append("## %s (`%s`, %d clips)" % (FAMILY_TITLE[f], f, len(names)))
        L.append("")
        L.append(cat["families"][f]["description"] + ".")
        L.append("")
        for b in family_notes(f, clips, names, geo.get("chains", [])):
            L.append("- " + b)
        L.append("")
        base = [n for n in names if clips[n]["variant"]["kind"] == "base"]
        L.extend(base_rows(clips, base))
        L.append("")
        ch = chain_rows(geo.get("chains", []), set(names))
        if ch:
            L.append("Pose-continuous sequences (the last pose of a clip equals the first pose of the next, <= 3 mm; measured as "
                     "one sequence). Most are authored parts of one move; a link can also be a coincidence of identical idle poses "
                     "(e.g. an `-end` clip followed by a `-start` clip):")
            L.append("")
            L.extend(ch)
            L.append("")
        gl = [(n, graph_states(clips[n])) for n in base if graph_states(clips[n])]
        if gl:
            L.append("Graph states that play these clips (leaf resolution, any weapon / mode selection):")
            L.append("")
            for n, s in gl:
                L.append("- `%s`: %s" % (short(n), s))
            L.append("")
        vr = variant_rows(clips, names)
        if vr:
            L.append("Variants:")
            L.append("")
            L.extend(vr)
            L.append("")
    L.append("## Graph gaps (traversal states without an Actor_B clip)")
    L.append("")
    L.append("States of the decoded player graph in the traversal families whose leaves resolve to no Actor_B traversal clip "
             "under any of the 13 weapon x mode selections and the extra overlays (ledge, jump, ladder-entry-exit, crouch-under, "
             "wall-shimmy). *A* marks leaves that exist in the Actor_A library.")
    L.append("")
    by = collections.defaultdict(list)
    for g in gaps:
        by[g["family"]].append(g)
    for f in FAMILY_ORDER:
        if f not in by:
            continue
        items = []
        for g in by[f]:
            a = " (A)" if g["leaf_in_actor_a_library"] else ""
            items.append("`%s`%s" % (g["state"], a))
        L.append("- **%s** (%d): %s" % (f, len(by[f]), ", ".join(items)))
    L.append("")
    lad = sorted(st for st, info in cat.get("graph_states", {}).items()
                 if info.get("family") == "ledge_hang" and info.get("only_with_extras") == ["ledge:ladder"])
    if lad:
        L.append("Hang states that reach Actor_B clips only as a ladder (`ledge-ladder` overlay; without it their leaves resolve "
                 "to clips that are in neither library): %s." % ", ".join("`%s`" % x for x in lad))
        L.append("")
    L.append("## Integration hooks the traversal runtime will need")
    L.append("")
    L.append("This survey only adds files. Wiring traversal into the game later needs these hooks in existing files "
             "(not edited here):")
    L.append("")
    for h in HOOKS:
        L.append("- " + h)
    L.append("")
    L.append("## Files")
    L.append("")
    L.append("- `Frontier/tools/traversal/build_traversal_catalog.py` -> `Frontier/data/traversal/traversal_catalog.json` "
             "(clip list, families, name hints, variant / base pairs, graph links and successions, graph gaps)")
    L.append("- `Frontier/tools/traversal/measure_traversal_clips.gd` -> `Frontier/data/traversal/clip_geometry.json` "
             "(per clip: basics, keyed bones, root motion check, odometry, travel, entry / exit, contacts, implied geometry, "
             "series, variant composites; authored chains)")
    L.append("- `Frontier/tools/traversal/write_clip_survey.py` -> this file")
    L.append("- `Frontier/tests/traversal/test_clip_geometry.py` (contract and sanity tests)")
    L.append("")
    return "\n".join(L) + "\n"


HOOKS = [
    "`scripts/player/player_anim.gd` (facade) and `scripts/player/anim/tree_builder.gd`: a full-body traversal slot / state "
    "(one-shot and loop clips with graph fades from `traversal_catalog.json` `graph_states[*].transitions`) that suspends "
    "LocoBrain and UpperBody, plus weapon-part layers (`-bow--part` / `-rifle--part`) on the upper body while traversing.",
    "`scripts/player/anim/loco_brain.gd`: enter / exit traversal (hand control over, resume locomotion at the clip's exit "
    "gait and phase; `entry` / `exit` speeds and poses here pick the resume state).",
    "`scripts/player/player.gd` / `scripts/player/character_body.gd`: a traversal movement mode that moves the body along the "
    "measured align path (`series.align_*`) warped onto the detected ledge / obstacle (hand-plant and landing targets from "
    "`contacts` / `implied`), with collision disabled or shaped during the move, and sprint (Shift) as the free-run trigger.",
    "Input map (`project.godot` actions): sprint rebound to Shift; optional drop / let-go and climb-up actions.",
    "Weapons (`scripts/weapons/*`): holster or lower the weapon during two-handed moves (hang, ladder, climb-up) where the "
    "part layers are missing or a supporting hand would hold the weapon.",
    "World / level scripts (`scripts/world/*`): ledge / climbable markers (tags, metadata or generated edges) that the "
    "traversal detector queries; physics layers for climbable surfaces.",
    "Camera (player camera script): follow the warped path and widen during climbs / hangs.",
    "Audio (`scripts/audio/*`): footstep / hand-plant events at the measured contact frames (`contacts.*.f0`).",
]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--geometry", default=GEOMETRY)
    ap.add_argument("--catalog", default=CATALOG)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    geo = json.load(open(a.geometry))
    cat = json.load(open(a.catalog))
    text = build(geo, cat)
    if a.check:
        old = open(a.out).read() if os.path.exists(a.out) else ""
        if old != text:
            print("clip survey: %s is stale (rerun without --check)" % a.out)
            sys.exit(1)
        print("clip survey: %s is current" % a.out)
        return
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with open(a.out, "w") as fh:
        fh.write(text)
    print("clip survey: wrote %s (%d lines)" % (a.out, text.count("\n")))


if __name__ == "__main__":
    main()
