#!/usr/bin/env python3
"""The climbing part of the Actor_C player animation tree as data for Frontier (user 2026-09-27: "load the climbing part
of the tree as data"): the motion states linked to the 117 grip / hang clips and every transition row entering or
leaving them, from the decoded tree in ~/Downloads/giants_data/animation_tree/ (climbing_motion_graph.json,
climbing_transitions.csv), with the pendulum setup table and the player parameter, into data/climb/climb_tree.json.
PlayerGrip reads the blend times (field_10, in 30 fps frames) and the follow-on of each clip ("上記" rows: at the
clip's end) from it.

The giants' graphs and AI are not read here.

Usage (from the project root):
  python3 tools/climb/extract_climb_tree.py [--tree ~/Downloads/giants_data/animation_tree] [--out data/climb/climb_tree.json]
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

## English glosses of the trigger labels (control modes / inputs); the Japanese label stays the key.
GLOSS = {
    "へばり②モード": "grip2 mode (cling to a steep surface)",
    "へばり①モード": "grip1 mode (cling to a gentle surface)",
    "へばり①モード（揺れ時）": "grip1 mode (while shaken)",
    "跳ばされ": "flung off",
    "浮くY+（大）": "float Y+ (large)",
    "浮くY+（中）": "float Y+ (medium)",
    "浮く【大】": "float (large)",
    "浮く【中】": "float (medium)",
    "浮きやめ": "stop floating",
    "しゃがみモード": "crouch mode",
    "フィールドモード": "field mode (on foot)",
    "傾斜モード": "slope mode",
    "左回転": "turn left",
    "右回転": "turn right",
    "攻撃": "attack",
    "跳躍（大）": "jump (large)",
    "跳躍（上）": "jump (up)",
    "跳躍（前）": "jump (forward)",
    "つかまり": "catch",
    "エッジつかまり": "edge catch",
    "壁つかまり": "wall catch",
    "下りる": "get down",
    "右スライド": "slide right",
    "左スライド": "slide left",
    "移動（大）": "move (large)",
    "移動（小）": "move (small)",
    "後ろ移動": "move back",
    "よじ登る": "climb up",
    "よじ登る（急傾斜）": "climb up (steep)",
    "よじ登る（ジャンプ）": "climb up (jump)",
    "よじ登る（エッジ降り）": "climb (down over the edge)",
    "両足すべり": "both feet slip",
    "ぶら下がりから落下": "fall from the hang",
    "落下（へばり①）": "fall (grip1)",
    "コケ（右）【へばり時】": "stumble right (gripping)",
    "コケ（左）【へばり時】": "stumble left (gripping)",
    "待機": "wait",
    "両手ぶら下がり": "hang by both hands",
    "片手ぶら下がり（エッジ）": "hang by one hand (edge)",
    "片手ぶら下がり（へばり）": "hang by one hand (grip)",
}
FOLLOW_ON = "上記"      ## "the above": the row taken when the clip ends


def short(clip: str) -> str:
    return clip.replace("anim/player_A_", "").replace(".anb", "") if clip else ""


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        h.update(fh.read())
    return h.hexdigest()


def floats(words: list) -> list:
    return [round(struct.unpack("<f", struct.pack("<I", int(w, 16)))[0], 6) for w in words]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tree", default=os.path.expanduser("~/Downloads/giants_data/animation_tree"))
    ap.add_argument("--out", default=os.path.join(ROOT, "data", "climb", "climb_tree.json"))
    a = ap.parse_args()
    graph_p = os.path.join(a.tree, "climbing_motion_graph.json")
    rows_p = os.path.join(a.tree, "climbing_transitions.csv")
    pend_p = os.path.join(a.tree, "MotRootDyn_PendulumSetupParamPLAYER.json")
    param_p = os.path.join(a.tree, "PlayerParamDEFAULT.json")
    graph = json.load(open(graph_p))
    rows = list(csv.DictReader(open(rows_p, encoding="utf-8")))
    used = set()
    edges = []
    for r in rows:
        s, t = int(r["source_motion"]), int(r["target_motion"])
        used.add(s)
        used.add(t)
        edges.append([int(r["row"]), s, t, r["trigger_label"], float(r["field_0c_float"]), float(r["field_10_float"])])
    states = {}
    for n in graph["nodes"]:
        if int(n["id"]) in used:
            states[str(n["id"])] = {"label": n.get("label", ""), "clip": short(n.get("clip") or ""),
                                    "climbing": bool(n.get("climbing", False))}
    pend = json.load(open(pend_p))
    param = json.load(open(param_p))
    out = {
        "source": {
            "files": {os.path.basename(p): sha256(p) for p in (graph_p, rows_p, pend_p, param_p)},
            "evidence": graph.get("evidence", ""),
            "unresolved": graph.get("unresolved", []),
        },
        "fps": 30,
        "edge_fields": ["row", "source_state", "target_state", "trigger", "start_frame", "blend_frames"],
        "notes": "start_frame -1: at the clip's end (the follow-on rows, trigger '上記...'); blend_frames: the "
                 "cross-fade in 30 fps frames (field_10). Both field meanings are inferred from the rows, not decoded "
                 "from the engine. The pendulum table's fields are raw floats; their meaning is not decoded.",
        "states": states,
        "edges": edges,
        "triggers": {k: GLOSS.get(k, "") for k in sorted({e[3] for e in edges})},
        "pendulum_setup": [floats(r["raw_words"]) for r in pend["records"]],
        "player_param": floats(param["records"][0]["raw_words"]),
    }
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with open(a.out, "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=0)
        fh.write("\n")
    print("climb tree: %d states, %d transitions -> %s" % (len(states), len(edges), os.path.relpath(a.out, ROOT)))


if __name__ == "__main__":
    main()
