"""Startup timing of the Frontier level (faster-loading push, 2026-09-26).

Runs the game N times with the user arg startup_profile=quit (scripts/core/startup_profile.gd) and
prints, per phase, the minimum and the median over the runs (ms), then the time to the first frame
and to the settled frame (the first 5 frames shorter than 50 ms in a row). Min of N is the number
to compare: other processes on the machine only ever add time.

    python3 tools/perf/startup_times.py [--runs 3] [--headless] [--editor] [--godot PATH]
                                        [--project DIR] [-- extra user args, e.g. startup_prefetch=0]

  (windowed by default, 1280x720; --headless for the headless run; --editor times opening the
  project in the editor instead: `Godot --headless --path . --import` starts the editor, scans the
  files, reopens the last scenes and quits; the steps come from the editor's own progress lines)

Every run is under a time limit (--timeout, default 240 s). Nothing is written.
"""
import argparse
import os
import re
import statistics
import subprocess
import sys
import time

GODOT = "/Applications/Godot_mono.app/Contents/MacOS/Godot"
PHASES = ["boot", "environment", "terrain", "structures", "vegetation", "player", "audio",
          "first_frame", "settled"]


def run_game(godot, project, headless, extra, timeout):
    cmd = [godot]
    if headless:
        cmd.append("--headless")
    cmd += ["--path", project]
    if not headless:
        cmd += ["--resolution", "1280x720"]
    cmd += ["--", "startup_profile=quit"] + extra
    t0 = time.time()
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    wall = (time.time() - t0) * 1000.0
    at = {}
    for line in out.splitlines():
        m = re.match(r"STARTUP (\S+) at_ms=([\d.]+)", line)
        if m:
            at[m.group(1)] = float(m.group(2))
    if "settled" not in at:
        raise RuntimeError("no STARTUP table in the output:\n" + out[-2000:])
    at["process_exit"] = wall
    return at


def phase_ms(at):
    """Duration of each phase: from the previous listed mark to this one."""
    out = {}
    prev = 0.0
    for p in PHASES:
        if p in at:
            out[p] = at[p] - prev
            prev = at[p]
    out["to_first_frame"] = at.get("first_frame", 0.0)
    out["to_settled"] = at.get("settled", 0.0)
    out["process_exit"] = at["process_exit"]
    return out


def run_editor(godot, project, timeout):
    """Wall time of the editor start (headless) and of its 'Reopening scenes' step."""
    cmd = [godot, "--headless", "--path", project, "--import"]
    t0 = time.time()
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    stamps = {}
    try:
        for line in p.stdout:
            now = (time.time() - t0) * 1000.0
            line = re.sub(r"\x1b\[[0-9;]*m", "", line)
            for key, pat in [("scan_start", "Scanning file structure"), ("scan_done", r"first_scan_filesystem.*DONE|DONE \] first_scan_filesystem"),
                             ("reopen", "Reopening scenes"), ("layout_next", "Loading central editor layout"),
                             ("layout_done", r"DONE \] loading_editor_layout")]:
                if key not in stamps and re.search(pat, line):
                    stamps[key] = now
        p.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        p.kill()
        raise
    stamps["exit"] = (time.time() - t0) * 1000.0
    out = {"editor_ready": stamps.get("layout_done", stamps["exit"]), "process_exit": stamps["exit"]}
    if "reopen" in stamps and "layout_next" in stamps:
        out["reopen_scenes"] = stamps["layout_next"] - stamps["reopen"]
    if "scan_start" in stamps:
        out["to_scan_start"] = stamps["scan_start"]
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--headless", action="store_true")
    ap.add_argument("--editor", action="store_true")
    ap.add_argument("--godot", default=GODOT)
    ap.add_argument("--project", default=os.getcwd())
    ap.add_argument("--timeout", type=float, default=240.0)
    ap.add_argument("extra", nargs="*")
    a = ap.parse_args()
    rows = []
    for i in range(a.runs):
        if a.editor:
            r = run_editor(a.godot, a.project, a.timeout)
        else:
            r = phase_ms(run_game(a.godot, a.project, a.headless, a.extra, a.timeout))
        rows.append(r)
        print("run %d: %s" % (i + 1, " ".join("%s=%.0f" % (k, v) for k, v in r.items())), file=sys.stderr)
    keys = list(rows[0].keys())
    mode = "editor" if a.editor else ("headless" if a.headless else "windowed 1280x720")
    print("STARTUP_TIMES %s runs=%d project=%s extra=%s" % (mode, a.runs, a.project, " ".join(a.extra)))
    print("| phase | min ms | median ms |")
    print("|---|---:|---:|")
    for k in keys:
        vals = [r[k] for r in rows if k in r]
        print("| %s | %.0f | %.0f |" % (k, min(vals), statistics.median(vals)))


if __name__ == "__main__":
    main()
