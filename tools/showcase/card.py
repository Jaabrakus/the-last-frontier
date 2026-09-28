#!/usr/bin/env python3
"""A title or end card for the systems films: black, the lines centred, faded in and out, with silence under it.

    python3 tools/showcase/card.py <out dir> <seconds> <title> [<subtitle> [<small lines, \\n between>]]

Writes <out dir>/frames/f00000.jpg ... (1920x1080, 30 fps) and <out dir>/audio.wav (48 kHz stereo silence), ready for
video_encode encode <out dir>/frames 30 <card>.mp4 <out dir>/audio.wav. Needs Pillow; the fonts are macOS's own.
"""
import os
import sys
import wave

from PIL import Image, ImageDraw, ImageFont

W, H, FPS = 1920, 1080, 30
FADE_S = 0.5
SERIF = "/System/Library/Fonts/Supplemental/Baskerville.ttc"
SANS = "/System/Library/Fonts/Avenir Next.ttc"


def font(path, size, index=0):
    try:
        return ImageFont.truetype(path, size, index=index)
    except OSError:
        return ImageFont.load_default()


def main():
    out, secs, title = sys.argv[1], float(sys.argv[2]), sys.argv[3]
    sub = sys.argv[4] if len(sys.argv) > 4 else ""
    small = sys.argv[5].replace("\\n", "\n") if len(sys.argv) > 5 else ""
    os.makedirs(os.path.join(out, "frames"), exist_ok=True)
    base = Image.new("RGB", (W, H), (0, 0, 0))
    d = ImageDraw.Draw(base)
    f_title = font(SERIF, 120 if len(title) < 20 else 84)
    f_sub = font(SERIF, 44)
    f_small = font(SANS, 25)
    rows = [(title, f_title, (246, 240, 224), 26)]
    if sub:
        rows.append((sub, f_sub, (230, 214, 180), 34))
    for line in small.split("\n") if small else []:
        rows.append((line, f_small, (200, 200, 196), 10))
    heights = []
    for text, f, _, gap in rows:
        box = d.textbbox((0, 0), text, font=f)
        heights.append(box[3] - box[1] + gap)
    y = (H - sum(heights)) // 2
    for (text, f, col, gap), h in zip(rows, heights):
        box = d.textbbox((0, 0), text, font=f)
        d.text(((W - (box[2] - box[0])) // 2 - box[0], y - box[1]), text, font=f, fill=col)
        y += h
    n = int(round(secs * FPS))
    black = Image.new("RGB", (W, H), (0, 0, 0))
    for i in range(n):
        t = i / FPS
        a = min(1.0, t / FADE_S, (secs - t) / FADE_S)
        Image.blend(black, base, max(0.0, a)).save(os.path.join(out, "frames", "f%05d.jpg" % i), quality=93)
    with wave.open(os.path.join(out, "audio.wav"), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(48000)
        w.writeframes(b"\0\0\0\0" * int(48000 * n / FPS))
    print("CARD %s: %d frames" % (out, n))


if __name__ == "__main__":
    main()
