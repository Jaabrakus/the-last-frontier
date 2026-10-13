#!/usr/bin/env python3
"""The team-fight trailer: joins tools/ring/team_fight_film.gd's takes (one a format) into one MP4, each take's frames
with their own game sound (tools/showcase/video_audio.py cuts it out of the take's movie-writer AVI), a short dip to black
between takes, encoded once with ffmpeg (imageio-ffmpeg's binary, or FFMPEG=).

    python3 tools/ring/team_trailer_cut.py <out.mp4> <take dir> [<take dir> ...] [--dip 0.4]

Each take dir holds frames/f00000.jpg ..., frames.txt and raw.avi (as the film tool writes them). The takes' frames are
linked into one numbered sequence in <out>.work/ (the originals are never touched); the AVIs may be deleted after.
"""
import argparse
import os
import shutil
import subprocess
import sys
import wave
from pathlib import Path

HERE = Path(__file__).resolve().parent
AUDIO = HERE.parent / "showcase" / "video_audio.py"
RATE = 48000


def ffmpeg():
    if os.environ.get("FFMPEG"):
        return os.environ["FFMPEG"]
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return shutil.which("ffmpeg") or sys.exit("no ffmpeg: set FFMPEG=")


def frames_of(take):
    rows = []
    for line in (take / "frames.txt").read_text().splitlines():
        if line.startswith("#") or not line.strip():
            continue
        rows.append(int(line.split()[0]))
    return [take / "frames" / f"f{n:05d}.jpg" for n in rows]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out", type=Path)
    ap.add_argument("takes", type=Path, nargs="+")
    ap.add_argument("--fps", type=int, default=60)
    ap.add_argument("--dip", type=float, default=0.4, help="seconds of black between takes")
    a = ap.parse_args()
    work = a.out.with_suffix(".work")
    if work.exists():
        shutil.rmtree(work)
    (work / "seq").mkdir(parents=True)
    ff = ffmpeg()
    black = work / "black.jpg"
    subprocess.run([ff, "-y", "-loglevel", "error", "-f", "lavfi", "-i", "color=c=black:s=1920x1080", "-frames:v", "1",
                    str(black)], check=True)
    seq = []
    pcm = bytearray()
    for i, take in enumerate(a.takes):
        take = take.resolve()
        wav = work / f"take{i}.wav"
        subprocess.run([sys.executable, str(AUDIO), str(take / "raw.avi"), str(take / "frames.txt"), str(wav)], check=True)
        frames = frames_of(take)
        with wave.open(str(wav)) as w:
            assert (w.getnchannels(), w.getframerate(), w.getsampwidth()) == (2, RATE, 2), (take, w.getparams())
            data = w.readframes(w.getnframes())
        per = RATE // a.fps * 4                      # bytes of sound a frame (16-bit stereo)
        data = data[:len(frames) * per].ljust(len(frames) * per, b"\0")
        if i > 0 and a.dip > 0:
            n = int(round(a.dip * a.fps))
            seq += [black] * n
            pcm += b"\0" * (n * per)
        seq += frames
        pcm += data
        print(f"take {take.name}: {len(frames)} frames, {len(frames) / a.fps:.2f} s")
    for n, src in enumerate(seq):
        os.symlink(src, work / "seq" / f"f{n:05d}.jpg")
    with wave.open(str(work / "audio.wav"), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(pcm))
    subprocess.run([ff, "-y", "-loglevel", "error", "-framerate", str(a.fps), "-i", str(work / "seq" / "f%05d.jpg"),
                    "-i", str(work / "audio.wav"), "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "medium",
                    "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", str(a.out)], check=True)
    print(f"TEAM TRAILER {a.out} {len(seq)} frames, {len(seq) / a.fps:.2f} s")


if __name__ == "__main__":
    main()
