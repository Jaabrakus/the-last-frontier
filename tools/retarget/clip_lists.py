#!/usr/bin/env python3
"""Write clips_A.txt / clips_B.txt (dump_clips.gd inputs) for a retarget config.

  python3 tools/retarget/clip_lists.py <config.json> <out dir>
Actor_A: every configured clip + the seat-calibration clip. Actor_B: the native
validation clips + the seat-calibration clip + the native clips named in native_seams + the
weapon-frame reference clips (weapon_frames.*.reference_b, e.g. the knife clips).
"""
import json
import sys

cfg = json.load(open(sys.argv[1]))
out = sys.argv[2]
a = [c["name"] for c in cfg["clips"]]
b = [c["native"] for c in cfg["clips"] if c.get("native")]
for pair in cfg.get("native_seams", []):
    b += [n for n in pair if n.startswith("actor_b-")]
for fam in cfg.get("weapon_frames", {}).values():
    b += fam.get("reference_b", [])
cal = cfg.get("seat_calibration")
if cal:
    a.append(cal["a"])
    b.append(cal["b"])
open(out + "/clips_A.txt", "w").write("\n".join(dict.fromkeys(a)) + "\n")
open(out + "/clips_B.txt", "w").write("\n".join(dict.fromkeys(b)) + "\n")
print("clip_lists: %d Actor_A, %d Actor_B" % (len(dict.fromkeys(a)), len(dict.fromkeys(b))))
