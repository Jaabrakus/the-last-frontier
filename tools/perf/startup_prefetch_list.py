"""Records data/startup/prefetch.json, the resources StartupPrefetch requests on worker threads
as the level starts (scripts/core/startup_prefetch.gd; faster-loading push, 2026-09-26).

Runs the level once windowed with --verbose and startup_prefetch=0 (so the log has the level's own
load order), and keeps every "Loading resource:" path between the STARTUP_MARK boot line (the level's
_ready starts) and STARTUP_MARK first_frame, in that order, except:
  - scripts and shader includes (their parents load them), imported-file remaps (res://.godot/...);
  - shader files (.gdshader): small text files; the level's materials compile them on the main thread,
    and loading them on a worker left 6 RefCounted objects leaked at exit (Godot 4.7.2, measured);
  - the rig BackgroundLoad already loads (characters/Actor_B.tscn, animations/Actor_B.res);
  - what the game itself requests threaded (GatherTools: animations_extra/Actor_B_from_A.res).

    python3 tools/perf/startup_prefetch_list.py [--godot PATH] [--dry-run]

Run it from the project folder; it writes data/startup/prefetch.json (under a time limit of 240 s).
"""
import argparse
import json
import os
import re
import subprocess
import sys

GODOT = "/Applications/Godot_mono.app/Contents/MacOS/Godot"
OUT = "data/startup/prefetch.json"
SKIP_EXT = (".gd", ".gdshaderinc", ".gdshader")
SKIP = {
    "res://scenes/main.tscn",
    "res://characters/Actor_B.tscn",          # BackgroundLoad (the level requests it first)
    "res://animations/Actor_B.res",
    "res://animations_extra/Actor_B_from_A.res",  # GatherTools requests it threaded itself
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=GODOT)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    cmd = [a.godot, "--verbose", "--path", ".", "--resolution", "1280x720", "--",
           "startup_profile=quit", "startup_prefetch=0"]
    log = subprocess.run(cmd, capture_output=True, text=True, timeout=240).stdout
    inside = False
    seen = set()
    paths = []
    for line in log.splitlines():
        line = re.sub(r"\x1b\[[0-9;]*m", "", line)
        m = re.match(r"STARTUP_MARK (\S+)", line)
        if m:
            if m.group(1) == "boot":
                inside = True
            elif m.group(1) == "first_frame":
                break
            continue
        m = re.match(r"Loading resource: (\S+)", line)
        if not m or not inside:
            continue
        p = m.group(1)
        if p.startswith("res://.godot/") or p.endswith(SKIP_EXT) or p in SKIP or p in seen:
            continue
        seen.add(p)
        paths.append(p)
    if not paths:
        sys.exit("no loads found between STARTUP_MARK boot and first_frame (was the run windowed?)")
    doc = {
        "schema": "frontier.startup_prefetch/1",
        "about": "Resources the level loads while it builds, in that order; StartupPrefetch (scripts/core/startup_prefetch.gd) "
                 "requests them on worker threads as the level starts. Recorded by tools/perf/startup_prefetch_list.py.",
        "paths": paths,
    }
    if a.dry_run:
        print("\n".join(paths))
    else:
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        with open(OUT, "w") as f:
            json.dump(doc, f, indent=1)
            f.write("\n")
    print("%d paths%s" % (len(paths), "" if a.dry_run else " -> " + OUT), file=sys.stderr)


if __name__ == "__main__":
    main()
