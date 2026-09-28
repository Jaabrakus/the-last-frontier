"""Summarise long_gun_clip_probe.py samples: what each hand and the weapon do in a clip.

  python3 tools/weapons/long_gun_clip_report.py samples.jsonl INDEX.csv OUT.json

Frame of reference: the weapon (r_hand_prop_attachment; prop +Z along the barrel toward the
muzzle, +Y up, +X the character's left). Reported gun-frame coordinates are
(forward, up, right) in cm, right = the lock side (-X of the prop).

The reference grip is the standing aim hold: actor_b-p-rifle-idle-aim (sample 0, arm chain)
with the actor_b-p-rifle-idle-aim--hands pose (palms and prop bones) on top, combined through
the wrists (the --hands clip keys the palm / prop bones only). A hand is "off grip" while it is
more than OFF_CM from its reference grip in the gun frame. "Off line" is the angle between the
barrel at a sample and at the clip's last sample (the partial clips end in the ready pose).

Asset IDs are copied from blender_animation_index.csv.
"""

import csv
import json
import math
import sys

import numpy as np

OFF_CM = 3.0
OFFLINE_DEG = 20.0
AIM = "actor_b-p-rifle-idle-aim"
AIM_HANDS = "actor_b-p-rifle-idle-aim--hands"


def qm(q):
    w, x, y, z = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def tf(rec):
    m = np.eye(4)
    m[:3, :3] = qm(rec["q"])
    m[:3, 3] = rec["p"]
    return m


def in_gun(g, p):
    """World point -> gun frame (forward, up, right) in cm."""
    v = (np.linalg.inv(g) @ np.r_[p, 1.0])[:3]
    return np.array([v[2], v[1], -v[0]]) * 100.0


def windows(ts, flags):
    out, start = [], None
    for t, f in zip(ts, flags):
        if f and start is None:
            start = t
        if not f and start is not None:
            out.append([start, t])
            start = None
    if start is not None:
        out.append([start, ts[-1]])
    return [[round(a, 3), round(b, 3)] for a, b in out]


def main():
    samples, index_csv, out_json = sys.argv[1:4]
    clips = {}
    for line in open(samples):
        r = json.loads(line)
        if "frames" in r:
            clips[r["action"]] = r
    ids = {}
    for row in csv.DictReader(open(index_csv)):
        if row["character"] == "Actor_B":
            ids.setdefault(row["action_name"], row["asset_id"])

    a0 = clips[AIM]["frames"][0]
    h0 = clips[AIM_HANDS]["frames"][0]

    def comb(side, bone):
        return tf(a0[side + "_wrist"]) @ np.linalg.inv(tf(h0[side + "_wrist"])) @ tf(h0[bone])

    g_aim = comb("r", "r_hand_prop_attachment")
    ref_l = in_gun(g_aim, comb("l", "l_palm")[:3, 3])
    ref_r = in_gun(g_aim, comb("r", "r_palm")[:3, 3])
    report = {"meta": {
        "reference": "aim hold: %s sample 0 + %s" % (AIM, AIM_HANDS),
        "frame": "gun frame (forward, up, right) cm; origin r_hand_prop_attachment = model grip origin",
        "ref_left_palm_cm": [round(float(x), 1) for x in ref_l],
        "ref_right_palm_cm": [round(float(x), 1) for x in ref_r],
        "off_grip_cm": OFF_CM, "offline_deg": OFFLINE_DEG,
        "authorization": "owner-stated; see Player_Animation_Project/ASSET_AUTHORIZATION.md",
    }, "clips": {}}
    for name, r in clips.items():
        fr = r["frames"]
        # Clips that do not key the prop bone (e.g. the aim base) leave the weapon at its rest
        # pose here: nothing to measure against the weapon.
        if len(fr) < 2 or "r_hand_prop_attachment" not in r.get("keyed_bones", []):
            continue
        ts = [f["t"] for f in fr]
        g_end = tf(fr[-1]["r_hand_prop_attachment"])
        lp, rp, off_deg, grip_move = [], [], [], []
        for f in fr:
            g = tf(f["r_hand_prop_attachment"])
            lp.append(in_gun(g, f["l_palm"]["p"]))
            rp.append(in_gun(g, f["r_palm"]["p"]))
            c = float(np.clip(g_end[:3, 2] @ g[:3, 2], -1, 1))
            off_deg.append(math.degrees(math.acos(c)))
            grip_move.append(float(np.linalg.norm(g[:3, 3] - g_end[:3, 3]) * 100))
        dl = [float(np.linalg.norm(p - ref_l)) for p in lp]
        dr = [float(np.linalg.norm(p - ref_r)) for p in rp]
        k_r = int(np.argmax(dr))
        report["clips"][name] = {
            "asset_id": ids.get(name),
            "library": r.get("library"),
            "sample_rate": r["sample_rate"], "sample_count": r["sample_count"], "length_s": r["length_s"],
            "left_palm_forward_cm": [round(float(min(p[0] for p in lp)), 1), round(float(max(p[0] for p in lp)), 1)],
            "left_max_off_grip_cm": round(max(dl), 1),
            "left_off_grip_windows_s": windows(ts, [d > OFF_CM for d in dl]),
            "right_max_off_grip_cm": round(max(dr), 1),
            "right_farthest_at": {"t": ts[k_r], "gun_cm": [round(float(x), 1) for x in rp[k_r]]},
            "right_off_grip_windows_s": windows(ts, [d > OFF_CM for d in dr]),
            "barrel_max_off_end_deg": round(max(off_deg), 1),
            "barrel_off_line_windows_s": windows(ts, [a > OFFLINE_DEG for a in off_deg]),
            "grip_max_move_from_end_cm": round(max(grip_move), 1),
            "per_sample": [{"t": t, "left_cm": [round(float(x), 1) for x in a], "right_cm": [round(float(x), 1) for x in b],
                            "barrel_off_end_deg": round(o, 1)}
                           for t, a, b, o in zip(ts, lp, rp, off_deg)],
        }
    with open(out_json, "w") as fh:
        json.dump(report, fh, indent=1)
        fh.write("\n")
    print("| clip | len s | left fwd range cm | left off grip s | right max off cm (t, fwd/up/right) "
          "| right off grip s | barrel max off deg | off line s |")
    print("|---|---|---|---|---|---|---|---|")
    for name, c in report["clips"].items():
        fa = c["right_farthest_at"]
        print("| %s | %.3f | %s | %s | %.1f (%.2f, %s) | %s | %.1f | %s |" % (
            name, c["length_s"], c["left_palm_forward_cm"], c["left_off_grip_windows_s"] or "-",
            c["right_max_off_grip_cm"], fa["t"], "/".join("%.0f" % x for x in fa["gun_cm"]),
            c["right_off_grip_windows_s"] or "-", c["barrel_max_off_end_deg"],
            c["barrel_off_line_windows_s"] or "-"))


main()
