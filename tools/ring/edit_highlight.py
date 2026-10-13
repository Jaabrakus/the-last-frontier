#!/usr/bin/env python3
"""Select continuous, frame-accurate gameplay excerpts without changing their images.

python3 tools/ring/edit_highlight.py TAKE_DIR EDIT_DIR water:5:8 fire:12:7 earth:7:7 air:18:8

Each cut is element:start_seconds:duration_seconds. Frames are hard-linked into a
new directory. Its frames.txt retains the original engine frames so the existing
showcase/video_audio.py cuts the matching game audio from TAKE_DIR/raw.avi.
"""
import argparse
import json
import os
from pathlib import Path
import re


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("take", type=Path)
    parser.add_argument("edit", type=Path)
    parser.add_argument("cuts", nargs="+")
    args = parser.parse_args()
    source = (args.take / "frames.txt").read_text().splitlines()
    header = next(line for line in source if line.startswith("# frame"))
    fps = int(re.search(r"fps (\d+)", header).group(1))
    rows = [line.split() for line in source if line and not line.startswith("#")]
    output = args.edit / "frames"
    output.mkdir(parents=True, exist_ok=False)
    selected = []
    manifest = []
    for cut in args.cuts:
        name, start_text, duration_text = cut.split(":")
        start = round(float(start_text) * fps)
        length = round(float(duration_text) * fps)
        clip = [r for r in rows if r[2] == name and start <= round(float(r[3]) * fps) < start + length]
        if len(clip) != length:
            raise SystemExit(f"{cut}: requested {length} frames, found {len(clip)}")
        manifest.append({"element": name, "source_start_s": start / fps, "duration_s": length / fps,
                         "output_start_s": len(selected) / fps})
        for row in clip:
            index = len(selected)
            source_frame = args.take / "frames" / f"f{int(row[0]):05d}.jpg"
            os.link(source_frame, output / f"f{index:05d}.jpg")
            selected.append(f"{index} {row[1]} {row[2]} {row[3]}")
    (args.edit / "frames.txt").write_text(header + "\n" + "\n".join(selected) + "\n")
    (args.edit / "edit.json").write_text(json.dumps({"fps": fps, "cuts": manifest}, indent=2) + "\n")
    print(f"Selected {len(selected)} unchanged frames, {len(selected) / fps:.2f}s at {fps}fps")


if __name__ == "__main__":
    main()
