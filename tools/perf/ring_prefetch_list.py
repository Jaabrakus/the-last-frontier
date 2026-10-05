"""Records data/ring/prefetch.json, the resources Tidebreak's ring requests on worker threads as it starts building behind
the loading screen (RingLevel._prefetch; improvement round 1, PERF: the ring's build a part a frame, each part's files read
on the worker threads meanwhile instead of on the main thread in the part's own frame).

Runs tests/perf/test_ring_hitches.gd once windowed with --verbose (the way in from the menu's Begin: the loading screen, the
stepped build) with startup_profile=1 and ring_prefetch=0 (so the log has the level's own load order), and keeps every
"Loading resource:" path between the STARTUP_MARK lines of the ring's build, by the part it was loaded in (the mark that
ends it: environment, structures, dressing, player, audio, first_frame), except:
  - scripts and shader includes (their parents load them), imported-file remaps (res://.godot/...);
  - shader files (.gdshader): small text files compiled on the main thread anyway, and loading them on a worker left
    RefCounted objects leaked at exit (Godot 4.7.2, measured for the open world's list: tools/perf/startup_prefetch_list.py);
  - the rig BackgroundLoad already loads (characters/Actor_B.tscn, animations/Actor_B.res) and what the game requests
    threaded itself (GatherTools: animations_extra/Actor_B_from_A.res);
  - the ring's scene itself.

    python3 tools/perf/ring_prefetch_list.py [--godot PATH] [--lock SCRIPT] [--dry-run]

Run it from the project folder (through the one-Godot lock script when given: --lock path/to/godot_run.sh); it writes
data/ring/prefetch.json. Re-record it after big content changes (a path that is gone is skipped; one no longer used only
costs a worker-thread load).
"""
import argparse
import json
import os
import re
import subprocess
import sys

GODOT = "/Applications/Godot_mono.app/Contents/MacOS/Godot"
OUT = "data/ring/prefetch.json"
SKIP_EXT = (".gd", ".gdshaderinc", ".gdshader")
SKIP = {
    "res://scenes/ring.tscn",
    "res://characters/Actor_B.tscn",          # BackgroundLoad (the level requests it first)
    "res://animations/Actor_B.res",
    "res://animations_extra/Actor_B_from_A.res",  # GatherTools requests it threaded itself
}
PHASES = ["environment", "structures", "dressing", "player", "audio", "first_frame"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=GODOT)
    ap.add_argument("--lock", default="", help="a wrapper script that runs Godot under a lock (its args: Godot's)")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    args = ["--verbose", "--path", ".", "-s", "tests/perf/test_ring_hitches.gd", "--",
            "startup_profile=1", "ring_prefetch=0", "load_ms=0", "restart_ms=0"]
    cmd = (["zsh", a.lock] if a.lock else [a.godot]) + args
    log = subprocess.run(cmd, capture_output=True, text=True, timeout=600).stdout
    inside = False
    phase_paths = {p: [] for p in PHASES}
    pending = []
    seen = set()
    for line in log.splitlines():
        line = re.sub(r"\x1b\[[0-9;]*m", "", line)
        m = re.match(r"STARTUP_MARK (\S+)", line)
        if m:
            mark = m.group(1)
            if mark == "boot":
                inside = True
            elif inside and mark in phase_paths:
                phase_paths[mark].extend(pending)
                pending = []
                if mark == "first_frame":
                    break
            continue
        m = re.match(r"Loading resource: (\S+)", line)
        if not m or not inside:
            continue
        p = m.group(1)
        if p.startswith("res://.godot/") or p.endswith(SKIP_EXT) or p in SKIP or p in seen:
            continue
        seen.add(p)
        pending.append(p)
    if not seen:
        sys.exit("no loads found between STARTUP_MARK boot and first_frame (was the run windowed and verbose?)")
    doc = {
        "schema": "frontier.ring_prefetch/1",
        "about": "Resources Tidebreak's ring loads while it builds, by the part of the build that loads them, in that order; "
                 "RingLevel._prefetch (scripts/ring/ring_level.gd) requests them all on worker threads as its stepped build "
                 "starts and waits for a part's own before building it. Recorded by tools/perf/ring_prefetch_list.py.",
        "phases": {p: phase_paths[p] for p in PHASES},
    }
    if a.dry_run:
        print(json.dumps(doc["phases"], indent=1))
    else:
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        with open(OUT, "w") as f:
            json.dump(doc, f, indent=1)
            f.write("\n")
    print("%d paths%s" % (len(seen), "" if a.dry_run else " -> " + OUT), file=sys.stderr)


if __name__ == "__main__":
    main()
