#!/usr/bin/env python3
"""The opening of the systems films and clips: the game's own painted start-up splash (user 2026-09-28: "it like the
frontier start up load like that painted beautifullneesss"; assets/ui/splash.png, the boot splash), faded in from
black, drifting slowly nearer, faded out to black, with silence under it.

    python3 tools/showcase/splash_intro.py <out dir> [seconds, default 3.8]

Writes <out dir>/frames/f00000.jpg ... (1920x1080, 30 fps) and <out dir>/audio.wav, for
video_encode encode <out dir>/frames 30 <intro>.mp4 <out dir>/audio.wav. Needs Pillow.
"""
import os
import sys
import wave

from PIL import Image

W, H, FPS = 1920, 1080, 30
FADE_IN, FADE_OUT = 0.6, 0.6
DRIFT = 0.035
SPLASH = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui", "splash.png")


def main():
    out = sys.argv[1]
    secs = float(sys.argv[2]) if len(sys.argv) > 2 else 3.8
    os.makedirs(os.path.join(out, "frames"), exist_ok=True)
    src = Image.open(SPLASH).convert("RGB").resize((W, H), Image.LANCZOS)
    black = Image.new("RGB", (W, H), (0, 0, 0))
    n = int(round(secs * FPS))
    for i in range(n):
        t = i / FPS
        s = 1.0 + DRIFT * t / secs
        cw, ch = W / s, H / s
        box = ((W - cw) / 2, (H - ch) / 2, (W + cw) / 2, (H + ch) / 2)
        frame = src.resize((W, H), Image.BICUBIC, box=box)
        a = max(0.0, min(1.0, t / FADE_IN, (secs - t) / FADE_OUT))
        Image.blend(black, frame, a).save(os.path.join(out, "frames", "f%05d.jpg" % i), quality=93)
    with wave.open(os.path.join(out, "audio.wav"), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(48000)
        w.writeframes(b"\0\0\0\0" * int(48000 * n / FPS))
    print("SPLASH INTRO %s: %d frames" % (out, n))


if __name__ == "__main__":
    main()
