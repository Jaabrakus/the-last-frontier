#!/usr/bin/env python3
"""A short film of the earth kit from the move reel's clips (tools/ring/move_reel.gd only=earth, cut by move_reel_cut.py into
<dir>/clips/<nn>_<element>_<move>.mp4, each with its caption in the picture and its own sound): the chosen moves, each trimmed
to its best stretch and joined, with a short dip to black between them.

    python3 tools/ring/earth_reel_film.py <cut dir> <out.mp4> [--plan "jab:0:1.9,spike:0.2:2.6,..."]

The plan is `match:start:length` items: `match` a lowercase part of the clip's file name (the first clip that has it), `start`
and `length` in seconds into the clip. The default is the whole kit in about 25 s.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

DEFAULT_PLAN = "jab_string:0.0:1.9,spike_grown:0.0:2.8,boulder:0.3:2.4,boulder_grown:0.3:2.6,fissure:0.2:2.6,column:0.3:2.4," \
               "burrow:0.0:2.2,wall:0.4:2.4,guard:0.0:3.4"


def ffmpeg():
    if os.environ.get("FFMPEG"):
        return os.environ["FFMPEG"]
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return shutil.which("ffmpeg") or sys.exit("no ffmpeg: set FFMPEG=")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cut")
    ap.add_argument("out")
    ap.add_argument("--plan", default=DEFAULT_PLAN)
    a = ap.parse_args()
    ff = ffmpeg()
    clips = sorted((Path(a.cut) / "clips").glob("*.mp4"))
    work = Path(tempfile.mkdtemp(prefix="earth_film_"))
    parts = []
    for i, item in enumerate(a.plan.split(",")):
        match, start, length = item.rsplit(":", 2)
        hit = [c for c in clips if match.lower() in c.name.lower() and (match != "boulder" or "grown" not in c.name)
               and (match != "spike" or "grown" not in c.name) and (match != "fissure" or "grown" not in c.name)]
        if not hit:
            print("no clip for", match)
            continue
        part = work / f"p{i:02d}.mp4"
        subprocess.run([ff, "-y", "-loglevel", "error", "-ss", start, "-t", length, "-i", str(hit[0]),
                        "-vf", f"fade=t=in:st=0:d=0.12,fade=t=out:st={max(float(length) - 0.12, 0):.2f}:d=0.12",
                        "-af", f"afade=t=in:st=0:d=0.1,afade=t=out:st={max(float(length) - 0.12, 0):.2f}:d=0.12",
                        "-c:v", "libx264", "-crf", "19", "-pix_fmt", "yuv420p", "-c:a", "aac", str(part)], check=True)
        parts.append(part)
        print("part", hit[0].name, start, length)
    lst = work / "list.txt"
    lst.write_text("".join(f"file '{p}'\n" for p in parts))
    subprocess.run([ff, "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", a.out], check=True)
    shutil.rmtree(work)
    print("film", a.out)


if __name__ == "__main__":
    main()
