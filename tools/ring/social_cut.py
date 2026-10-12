#!/usr/bin/env python3
"""Short clips for posting (the owner, 2026-10-11: "make me a bunch of twitter videos i can post to get people to play 4v4 is
chaotic as fuck though"): stretches of tools/ring/team_fight_film.gd takes with their own game sound, a hook line over the
first seconds (most people watch muted), a short end card, faded in and out; encoded once with ffmpeg (imageio-ffmpeg's
binary, or FFMPEG=) as H.264 + AAC, 1920x1080 at the take's rate (X takes up to 1920x1200, 60 fps, 2:20).

    python3 tools/ring/social_cut.py <out.mp4> <take dir> [<take dir> ...]
        (--from S --to S | --auto S | --montage S [--seg 4] | --pieces 0:9-12,1:45-49.2,...) [--min-on N] [--hook TEXT]
        [--hook-s 2.6] [--shots follow,low]
        [--end "LINE ONE|line two"] [--end-s 2.2] [--fps 60] [--crf 18]

--from/--to: one stretch of the first take. --auto S: the first take's S-second stretch with the most in it (its events.json:
a fall 3, a big launch 1; ties the earliest; never its first second). --montage S: about S seconds from the best --seg-second
pieces of every take given (scored by the events in them and the fighters in the picture), none overlapping, in the takes'
order, cut together (a few milliseconds of fade on the sound at each cut). --pieces: those stretches, in that order
(<take index>:<from>-<to> seconds), cut together the same way: picked by eye from contact sheets. --min-on N (takes with shots.json): leaves out any
stretch with fewer than N fighters in the picture on average, or a second in it with fewer than half that (the camera on a
bare wall). --shots follow,low: only frames of those shots count as having anyone in the picture (the wide shot holds all
eight, but small). A take dir holds frames/f00000.jpg ..., frames.txt, raw.avi, events.json and shots.json (as the film tool writes
them); its frames are never changed (its sound is kept there once cut out, audio_full.wav).
Prints "SOCIAL CUT <out> <frames> frames <s> s" and the pieces used.
"""
import argparse
import array
import json
import os
import shutil
import subprocess
import sys
import wave
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
AUDIO = HERE.parent / "showcase" / "video_audio.py"
FONT = ROOT / "assets" / "fonts" / "barlow" / "BarlowCondensed-ExtraBold.ttf"
FONT_B = ROOT / "assets" / "fonts" / "barlow" / "BarlowSemiCondensed-SemiBold.ttf"
RATE = 48000
JOIN_FADE = 240                     # samples of fade on each side of a cut (5 ms)


def ffmpeg():
    if os.environ.get("FFMPEG"):
        return os.environ["FFMPEG"]
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return shutil.which("ffmpeg") or sys.exit("no ffmpeg: set FFMPEG=")


class Take:
    def __init__(self, path, fps, shots=None):
        self.path = path.resolve()
        self.fps = fps
        rows = []
        for line in (self.path / "frames.txt").read_text().splitlines():
            if line.startswith("#") or not line.strip():
                continue
            rows.append(int(line.split()[0]))
        self.frames = [self.path / "frames" / f"f{n:05d}.jpg" for n in rows]
        self.total = len(self.frames) / fps
        self.events = []
        p = self.path / "events.json"
        if p.exists():
            w = {"ko": 3.0, "launch": 1.0}
            self.events = [(float(e["time"]), w[e["kind"]]) for e in json.loads(p.read_text())
                           if e.get("kind") in w and float(e.get("time", -1)) >= 0]
        self.on = None
        p = self.path / "shots.json"
        if p.exists():
            self.on = [int(r[2]) if not shots or r[1] in shots else 0 for r in json.loads(p.read_text())]
        self._pcm = None

    def weight(self, t0, t1):
        return sum(wt for t, wt in self.events if t0 + 0.6 <= t <= t1 - 0.8)

    def on_ok(self, t0, t1, min_on):
        """(ok, mean fighters in the picture) over [t0, t1)."""
        if self.on is None or min_on <= 0:
            return True, 0.0
        a, b = int(t0 * self.fps), min(int(t1 * self.fps), len(self.on))
        if b <= a:
            return False, 0.0
        mean = sum(self.on[a:b]) / (b - a)
        step = self.fps
        for s in range(a, b - step + 1, step // 2):
            if sum(self.on[s:s + step]) / step < min_on * 0.5:
                return False, mean
        return mean >= min_on, mean

    def pcm(self):
        if self._pcm is None:
            wav_all = self.path / "audio_full.wav"
            if not wav_all.exists():
                subprocess.run([sys.executable, str(AUDIO), str(self.path / "raw.avi"), str(self.path / "frames.txt"),
                                str(wav_all)], check=True)
            with wave.open(str(wav_all)) as w:
                assert (w.getnchannels(), w.getframerate(), w.getsampwidth()) == (2, RATE, 2), w.getparams()
                self._pcm = w.readframes(w.getnframes())
        return self._pcm


def best_window(take, length, min_on):
    best, best_s = None, -1.0
    t = 1.0
    while t + length <= take.total + 1e-6:
        ok, mean = take.on_ok(t, t + length, min_on)
        if ok:
            s = take.weight(t, t + length) + mean * 0.05
            if s > best_s:
                best, best_s = t, s
        t += 0.25
    if best is None:
        sys.exit(f"no {length:.1f} s stretch of {take.path.name} keeps {min_on} fighters in the picture")
    return best


def montage(takes, total, seg, min_on):
    cands = []
    for ti, tk in enumerate(takes):
        t = 1.0
        while t + seg <= tk.total + 1e-6:
            ok, mean = tk.on_ok(t, t + seg, min_on)
            if ok:
                cands.append((tk.weight(t, t + seg) + mean * 0.25, ti, t))
            t += 0.5
    cands.sort(key=lambda c: -c[0])
    picked = []
    for score, ti, t in cands:
        if len(picked) * seg >= total:
            break
        if any(pi == ti and abs(pt - t) < seg + 1.0 for _, pi, pt in picked):
            continue
        picked.append((score, ti, t))
    if not picked:
        sys.exit("no piece keeps the fighters in the picture: lower --min-on")
    picked.sort(key=lambda c: (c[1], c[2]))
    return [(ti, t, t + seg) for _, ti, t in picked]


def esc(s):
    return s.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’").replace("%", "\\%")


def fade_edges(part, head, tail):
    """A few milliseconds of fade at a piece's cut ends (16-bit stereo little-endian, in place): no click at the cut."""
    s = array.array("h")
    s.frombytes(bytes(part))
    frames = len(s) // 2
    k = min(JOIN_FADE, frames // 2)
    for i in range(k):
        g = i / k
        if head:
            s[2 * i] = int(s[2 * i] * g)
            s[2 * i + 1] = int(s[2 * i + 1] * g)
        if tail:
            j = frames - 1 - i
            s[2 * j] = int(s[2 * j] * g)
            s[2 * j + 1] = int(s[2 * j + 1] * g)
    part[:] = s.tobytes()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out", type=Path)
    ap.add_argument("takes", type=Path, nargs="+")
    ap.add_argument("--from", dest="t0", type=float)
    ap.add_argument("--to", dest="t1", type=float)
    ap.add_argument("--auto", type=float)
    ap.add_argument("--montage", type=float)
    ap.add_argument("--seg", type=float, default=4.0)
    ap.add_argument("--pieces", default="")
    ap.add_argument("--min-on", type=float, default=0.0)
    ap.add_argument("--shots", default="")
    ap.add_argument("--hook", default="")
    ap.add_argument("--hook-s", type=float, default=2.6)
    ap.add_argument("--end", default="")
    ap.add_argument("--end-s", type=float, default=2.2)
    ap.add_argument("--fps", type=int, default=60)
    ap.add_argument("--crf", type=int, default=18)
    a = ap.parse_args()
    shots = [x for x in a.shots.split(",") if x]
    takes = [Take(p, a.fps, shots) for p in a.takes]
    if a.pieces:
        pieces = []
        for p in a.pieces.split(","):
            ti, span = p.split(":")
            t0, t1 = span.split("-")
            pieces.append((int(ti), float(t0), min(float(t1), takes[int(ti)].total)))
    elif a.montage:
        pieces = montage(takes, a.montage, a.seg, a.min_on)
    elif a.auto:
        t0 = best_window(takes[0], a.auto, a.min_on)
        pieces = [(0, t0, t0 + a.auto)]
    elif a.t0 is not None and a.t1 is not None:
        pieces = [(0, a.t0, min(a.t1, takes[0].total))]
    else:
        sys.exit("give --from and --to, --auto or --montage")

    work = a.out.with_suffix(".work")
    if work.exists():
        shutil.rmtree(work)
    (work / "seq").mkdir(parents=True)
    per = RATE // a.fps * 4                      # bytes of sound a frame (16-bit stereo)
    pcm = bytearray()
    n = 0
    for k, (ti, t0, t1) in enumerate(pieces):
        tk = takes[ti]
        i0, i1 = int(round(t0 * a.fps)), int(round(t1 * a.fps))
        pick = tk.frames[i0:i1]
        for src in pick:
            os.symlink(src, work / "seq" / f"f{n:05d}.jpg")
            n += 1
        part = bytearray(tk.pcm()[i0 * per:i1 * per].ljust(len(pick) * per, b"\0"))
        if len(pieces) > 1:
            fade_edges(part, k > 0, k < len(pieces) - 1)
        pcm += part
        print(f"  piece {k + 1}: {tk.path.name} {t0:.2f}-{t1:.2f} s")
    dur = n / a.fps
    with wave.open(str(work / "audio.wav"), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(pcm))

    # the picture's dressing: the hook line, the end card, the fades
    # (the JPEGs are full-range BT.601: to video range BT.709, tagged so, as players and X expect)
    vf = ["scale=in_range=pc:out_range=tv:in_color_matrix=bt601:out_color_matrix=bt709"]
    if a.hook:
        out_at = min(a.hook_s, dur)
        alpha = f"if(lt(t,0.15),t/0.15,if(gt(t,{out_at - 0.35:.2f}),max(0,({out_at:.2f}-t)/0.35),1))"
        vf.append(f"drawtext=fontfile='{FONT}':text='{esc(a.hook)}':fontsize=104:fontcolor=white:borderw=7:bordercolor=black@0.85"
                  f":x=(w-text_w)/2:y=h*0.15:alpha='{alpha}':enable='lt(t,{out_at:.2f})'")
    if a.end:
        e0 = max(dur - a.end_s, 0.0)
        lines = a.end.split("|")
        vf.append(f"drawbox=x=0:y=0:w=iw:h=ih:color=black@0.62:t=fill:enable='gte(t,{e0:.2f})'")
        vf.append(f"drawtext=fontfile='{FONT}':text='{esc(lines[0])}':fontsize=150:fontcolor=white:x=(w-text_w)/2:y=h*0.36"
                  f":enable='gte(t,{e0:.2f})'")
        if len(lines) > 1:
            vf.append(f"drawtext=fontfile='{FONT_B}':text='{esc(lines[1])}':fontsize=54:fontcolor=0x21d4c2:x=(w-text_w)/2:y=h*0.58"
                      f":enable='gte(t,{e0:.2f})'")
    vf.append("fade=t=in:st=0:d=0.2")
    vf.append(f"fade=t=out:st={max(dur - 0.35, 0):.2f}:d=0.35")
    vf.append("format=yuv420p")
    af = f"afade=t=in:st=0:d=0.15,afade=t=out:st={max(dur - 0.5, 0):.2f}:d=0.5"
    subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-framerate", str(a.fps), "-i", str(work / "seq" / "f%05d.jpg"),
                    "-i", str(work / "audio.wav"), "-vf", ",".join(vf), "-af", af, "-c:v", "libx264",
                    "-crf", str(a.crf), "-preset", "slow", "-profile:v", "high", "-maxrate", "16M", "-bufsize", "32M",
                    "-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709",
                    "-c:a", "aac", "-b:a", "192k", "-ar", str(RATE), "-shortest", "-movflags", "+faststart", str(a.out)],
                   check=True)
    shutil.rmtree(work)
    print(f"SOCIAL CUT {a.out} {n} frames {dur:.2f} s")


if __name__ == "__main__":
    main()
