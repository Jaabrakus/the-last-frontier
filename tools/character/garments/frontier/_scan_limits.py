"""Deformation scan of the frontier garments and their limits (plain Python, not Blender).

    python3 tools/character/garments/frontier/_scan_limits.py [--write] [ids...]

Runs tools/character/check_body_deform.gd (headless Godot, hard time limit) with the body
and one garment glb at a time (every envelope variant of the horn and pouch too), for
both body fits, parses the per-surface lines and prints the worst values. With --write it
stores the limits, 25 % above the worst measured value (the method of the existing
limits; floors: 0.5 % shares, max edge 1.3 for rigid pieces), in deform_limits.json next
to this file; the generators copy them into their catalog fragments ("deform_limits"),
which check_body_deform.gd reads. Rebuild the set afterwards (build_character.sh
--garments frontier) so the fragments carry the limits.
"""

import glob
import json
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
FRONTIER = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
GODOT = os.environ.get("GODOT", "/Applications/Godot_mono.app/Contents/MacOS/Godot")
GDIR = os.path.join(FRONTIER, "assets", "character", "garments", "frontier")
LINE = re.compile(r"^\s*(ok|FAIL)\s+(\S+)\s+tris\s+(\d+)\s+collapse\s+([\d.]+) %.*?flip\s+([\d.]+) %.*?"
                  r"stretch>\d+x\s+([\d.]+) %.*?max edge\s+([\d.]+)x")


def glbs(ids):
    out = []
    for f in sorted(glob.glob(os.path.join(GDIR, "*.glb"))):
        base = os.path.basename(f)[:-4]
        item = re.sub(r"_env\d+$", "", base)
        if ids and item not in ids:
            continue
        out.append((item, "res://assets/character/garments/frontier/" + os.path.basename(f)))
    return out


def scan(glb, sex, timeout=900):
    cmd = [GODOT, "--headless", "--path", FRONTIER, "-s", "tools/character/check_body_deform.gd", "--",
           "parts=res://assets/character/body/body.glb," + glb, "sex=%s" % sex]
    t = time.time()
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        out = p.stdout
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
        print("  TIME LIMIT", glb, sex)
    res = {}
    for line in out.splitlines():
        m = LINE.match(line)
        if m and not m.group(2).startswith(("skin:", "hair")):
            res[m.group(2)] = [float(m.group(4)) / 100, float(m.group(5)) / 100, float(m.group(6)) / 100,
                               float(m.group(7))]
    print("  %-48s sex %s  %s  (%.0fs)" % (glb.split("/")[-1], sex, res, time.time() - t))
    return res


def main():
    write = "--write" in sys.argv
    ids = [a for a in sys.argv[1:] if not a.startswith("--")]
    worst = {}
    for item, glb in glbs(ids):
        for sex in ("0", "1"):
            for surf, v in scan(glb, sex).items():
                w = worst.setdefault(surf, [0.0, 0.0, 0.0, 0.0])
                for k in range(4):
                    w[k] = max(w[k], v[k])
    limits = {}
    for surf, (c, f, s, e) in sorted(worst.items()):
        limits[surf] = [round(max(c * 1.25, 0.005), 4), round(max(f * 1.25, 0.005), 4), round(max(s * 1.25, 0.005), 4),
                        round(max(e * 1.25, 1.3), 2)]
        print("%-34s measured c %.4f f %.4f s %.4f e %.2f -> limits %s" % (surf, c, f, s, e, limits[surf]))
    if write:
        path = os.path.join(HERE, "deform_limits.json")
        old = {}
        if os.path.exists(path):
            with open(path) as fh:
                old = json.load(fh).get("limits", {})
        old.update(limits)
        with open(path, "w") as fh:
            json.dump({"note": "25 % above the worst scan of both fits (tools/character/garments/frontier/_scan_limits.py); "
                               "[collapse share, flip share, stretch>2x share, max edge ratio] per surface",
                       "scanned": time.strftime("%Y-%m-%d %H:%M"), "limits": old}, fh, indent=1)
        print("wrote", path)


if __name__ == "__main__":
    main()
