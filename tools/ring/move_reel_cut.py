#!/usr/bin/env python3
"""The move reel's pieces (tools/ring/move_reel.gd's take): one MP4 a move and one contact sheet a move, for the review (the
owner, 2026-10-12: "do a recording of each move and then do a critique of each move").

    python3 tools/ring/move_reel_cut.py <take dir> <out dir> [--fps 60] [--cells 12] [--cell 400] [--no-clips]

<out>/clips/<nn>_<element>_<move>.mp4: the shot with its own sound (tools/showcase/video_audio.py's cut of the movie writer's
AVI), H.264 + AAC. <out>/sheets/<nn>_<element>_<move>.jpg: --cells frames evenly over the shot, four a row, each stamped with
its time from the shot's start. <out>/index.json: each shot with its clip, its sheet and its frames' times.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import wave
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
AUDIO = HERE.parent / "showcase" / "video_audio.py"
FONT = ROOT / "assets" / "fonts" / "barlow" / "BarlowSemiCondensed-SemiBold.ttf"
RATE = 48000


def ffmpeg():
    if os.environ.get("FFMPEG"):
        return os.environ["FFMPEG"]
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return shutil.which("ffmpeg") or sys.exit("no ffmpeg: set FFMPEG=")


def slug(s):
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("take", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--fps", type=int, default=60)
    ap.add_argument("--cells", type=int, default=12)
    ap.add_argument("--cell", type=int, default=400)
    ap.add_argument("--no-clips", action="store_true")
    a = ap.parse_args()
    take = a.take.resolve()
    rows = [int(l.split()[0]) for l in (take / "frames.txt").read_text().splitlines() if l.strip() and not l.startswith("#")]
    frames = [take / "frames" / f"f{n:05d}.jpg" for n in rows]
    shots = json.loads((take / "shots.json").read_text())
    (a.out / "clips").mkdir(parents=True, exist_ok=True)
    (a.out / "sheets").mkdir(parents=True, exist_ok=True)
    ff = ffmpeg()
    pcm = b""
    if not a.no_clips:
        wav_all = take / "audio_full.wav"
        if not wav_all.exists():
            subprocess.run([sys.executable, str(AUDIO), str(take / "raw.avi"), str(take / "frames.txt"), str(wav_all)], check=True)
        with wave.open(str(wav_all)) as w:
            pcm = w.readframes(w.getnframes())
    per = RATE // a.fps * 4
    index = []
    for k, sh in enumerate(shots):
        i0, i1 = int(round(float(sh["t0"]) * a.fps)), int(round(float(sh["t1"]) * a.fps))
        i1 = min(i1, len(frames))
        name = "%02d_%s_%s%s" % (k + 1, sh["element"], slug(sh["label"].replace("▲", "")), "")
        work = a.out / ("_work_" + name)
        if work.exists():
            shutil.rmtree(work)
        work.mkdir()
        pick = frames[i0:i1]
        for n, src in enumerate(pick):
            os.symlink(src, work / f"f{n:05d}.jpg")
        # the sheet: cells frames evenly over the shot, each stamped with its time
        n_c = min(a.cells, len(pick))
        idx = [round(j * (len(pick) - 1) / max(n_c - 1, 1)) for j in range(n_c)]
        cells = []
        for j, fi in enumerate(idx):
            c = work / f"c{j:02d}.jpg"
            t = fi / a.fps
            subprocess.run([ff, "-y", "-loglevel", "error", "-i", str(pick[fi]), "-vf",
                            f"scale={a.cell}:-1,drawtext=fontfile='{FONT}':text='{t:.2f} s':fontsize=22:fontcolor=white:"
                            f"borderw=3:bordercolor=black:x=8:y=8", str(c)], check=True)
            cells.append(c)
        cols = 4
        rows_n = (len(cells) + cols - 1) // cols
        inputs = []
        for c in cells:
            inputs += ["-i", str(c)]
        # (a grid of equal cells: x the sum of j % cols widths, y of j // cols heights)
        layout = "|".join("%s_%s" % ("+".join(["w0"] * (j % cols)) or "0", "+".join(["h0"] * (j // cols)) or "0")
                          for j in range(len(cells)))
        sheet = a.out / "sheets" / f"{name}.jpg"
        subprocess.run([ff, "-y", "-loglevel", "error", *inputs, "-filter_complex",
                        f"xstack=inputs={len(cells)}:layout={layout}:fill=black", "-q:v", "3", str(sheet)], check=True)
        clip = a.out / "clips" / f"{name}.mp4"
        if not a.no_clips:
            with wave.open(str(work / "a.wav"), "wb") as w:
                w.setnchannels(2)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes(pcm[i0 * per:i1 * per].ljust(len(pick) * per, b"\0"))
            subprocess.run([ff, "-y", "-loglevel", "error", "-framerate", str(a.fps), "-i", str(work / "f%05d.jpg"), "-i",
                            str(work / "a.wav"), "-vf", "scale=in_range=pc:out_range=tv:in_color_matrix=bt601:out_color_matrix=bt709,"
                            "format=yuv420p", "-c:v", "libx264", "-crf", "20", "-preset", "medium", "-c:a", "aac", "-b:a", "160k",
                            "-shortest", "-movflags", "+faststart", str(clip)], check=True)
        shutil.rmtree(work)
        index.append({**sh, "name": name, "clip": str(clip.relative_to(a.out)), "sheet": str(sheet.relative_to(a.out)),
                      "cell_times": [round(fi / a.fps, 2) for fi in idx], "frames": len(pick)})
        print(f"REEL CUT {name}: {len(pick)} frames")
    (a.out / "index.json").write_text(json.dumps(index, indent=2, ensure_ascii=False))
    print(f"REEL CUT DONE {len(index)} shots -> {a.out}")


if __name__ == "__main__":
    main()
