"""Deformation limits of the military garments (plain python3, runs Godot headless).

For every garment of assets/character/garments/military/ it runs
tools/character/check_body_deform.gd (the 44 gameplay / knockdown clips x 8 samples) on
the full-skin body plus the garment, for the female (sex=0) and male (sex=1) fit, reads the
garment's collapse / flip / stretch shares and max edge ratio, and sets its limits 25 %
above the worse fit (the method of the legacy and body limits; floors 0.5 %, 0.5 %, 0.2 %,
1.3x). The limits go to military_lib/_limits.json (read by MilSpec on the next build) and
into the garment's catalog fragment ("deform_limits", "deform_scan"), which
military_check_deform.gd applies. Each result is also compared with the legacy limit of
its kind of garment ("deform_class": the quality bar, e.g. a coat must not deform worse
than the legacy hunting frock did).

    python3 tools/character/garments/military_lib/_scan_limits.py [ids...] [--jobs 4]
"""

import argparse
import concurrent.futures as cf
import datetime
import glob
import json
import math
import os
import re
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
FRONTIER = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
MIL = os.path.join(FRONTIER, "assets", "character", "garments", "military")
GODOT = os.environ.get("GODOT", "/Applications/Godot_mono.app/Contents/MacOS/Godot")
LIMITS_JSON = os.path.join(HERE, "_limits.json")
FLOORS = [0.005, 0.005, 0.002, 1.3]
LINE = re.compile(r"^\s+(?:ok  |FAIL) (\S+)\s+tris\s+(\d+)\s+collapse\s+([\d.]+) % \([^)]*\)\s+flip\s+([\d.]+) % "
                  r"\([^)]*\)\s+stretch>\S+\s+([\d.]+) % \([^)]*\)\s+max edge\s+([\d.]+)x")


def scan(gid, sex, timeout=900):
    parts = "res://assets/character/body/body.glb,res://assets/character/garments/military/%s.glb" % gid
    cmd = [GODOT, "--headless", "--path", FRONTIER, "-s", "tools/character/check_body_deform.gd", "--",
           "parts=" + parts, "sex=%d" % sex]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    for line in out.splitlines():
        m = LINE.match(line)
        if m and m.group(1) == gid:
            return [float(m.group(3)) / 100, float(m.group(4)) / 100, float(m.group(5)) / 100, float(m.group(6))]
    raise RuntimeError("no result for %s sex %d:\n%s" % (gid, sex, out[-3000:]))


def ceil_to(x, q):
    return math.ceil(x / q - 1e-9) * q


def limit_of(m0, m1):
    worst = [max(a, b) for a, b in zip(m0, m1)]
    lim = [max(1.25 * w, f) for w, f in zip(worst, FLOORS)]
    return [round(ceil_to(lim[0], 0.0005), 4), round(ceil_to(lim[1], 0.0005), 4), round(ceil_to(lim[2], 0.0005), 4),
            round(ceil_to(lim[3], 0.1), 1)], worst


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--jobs", type=int, default=4)
    args = ap.parse_args()
    frags = {os.path.basename(f)[:-5]: f for f in glob.glob(os.path.join(MIL, "*.json"))
             if os.path.basename(f) != "catalog.json"}
    ids = args.ids or sorted(frags)
    data = {"limits": {}, "measured": {}}
    if os.path.exists(LIMITS_JSON):
        with open(LIMITS_JSON) as f:
            data = json.load(f)
    jobs = [(g, s) for g in ids for s in (0, 1)]
    res = {}
    with cf.ThreadPoolExecutor(args.jobs) as ex:
        futs = {ex.submit(scan, g, s): (g, s) for g, s in jobs}
        for fu in cf.as_completed(futs):
            g, s = futs[fu]
            res[(g, s)] = fu.result()
            print("scanned %-26s sex %d: collapse %.2f %% flip %.2f %% stretch %.2f %% max edge %.2fx"
                  % (g, s, 100 * res[(g, s)][0], 100 * res[(g, s)][1], 100 * res[(g, s)][2], res[(g, s)][3]), flush=True)
    today = datetime.date.today().isoformat()
    for g in ids:
        lim, worst = limit_of(res[(g, 0)], res[(g, 1)])
        with open(frags[g]) as f:
            e = json.load(f)
        cls = e.get("deform_class", {})
        legacy = cls.get("legacy_limit")
        within = None if legacy is None else all(w <= l + 1e-9 for w, l in zip(worst, legacy))
        data["limits"][g] = lim
        data["measured"][g] = {"female": res[(g, 0)], "male": res[(g, 1)], "worst": worst, "limit": lim,
                               "legacy_class": cls.get("class"), "legacy_limit": legacy,
                               "within_legacy_class": within, "scanned": today}
        e["deform_limits"] = {g: lim}
        e["deform_scan"] = data["measured"][g]
        with open(frags[g], "w") as f:
            json.dump(e, f, indent=1)
        print("%-26s limit %s (worst %s) legacy %s %s" % (g, lim, [round(w, 4) for w in worst], cls.get("class"),
                                                         "within" if within else ("OVER" if within is False else "-")))
    data["note"] = ("check_body_deform limits of the military garments: 25 %% above the worse of the female and male "
                    "scans (44 clips x 8), floors %s; written by _scan_limits.py." % FLOORS)
    with open(LIMITS_JSON, "w") as f:
        json.dump(data, f, indent=1, sort_keys=True)


if __name__ == "__main__":
    main()
