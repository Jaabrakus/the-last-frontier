#!/usr/bin/env python3
"""The devlog cut (user 2026-10-02: "make it look and feel like some new dev doesnt know what to do and needs help from
the community about the prototype he just released"): the clean clips (tools/showcase/clips.gd) one after the other, each
with a plain caption at the bottom in a first-person, lowercase voice, and an end card asking for feedback. No splash, no
titles: it starts on the game.

    python3 tools/showcase/devlog.py <clips work dir>[,<another>] <out.mp4> <scratch dir>

The work dirs are make_clips.sh's (<dir>/<clip>/clean/f00000.jpg ..., <dir>/<clip>/audio.wav). CUT below is the order,
each clip's captions ([text, from s, to s]; to < 0: to the clip's end) and its length cap. Needs Pillow; the encoder
(video_encode.swift) is built into the scratch dir.
"""
import os
import subprocess
import sys
import wave

from PIL import Image, ImageDraw, ImageFont

FPS = 30
SANS = "/System/Library/Fonts/Avenir Next.ttc"
BOLD, DEMI = 0, 2
FADE_S = 0.25

# (clip, max seconds, [(caption, from, to)])
CUT = [
    ("fell", 18.0, [("so this is my first game. a frontier survival thing, set in 1765", 0.3, 6.0),
                    ("you can fell trees, limb them and buck them into logs", 6.2, -1)]),
    ("build", 22.0, [("then build a cabin out of the logs, piece by piece", 0.3, 8.0),
                     ("you place pieces anywhere, or hold alt to snap them together", 8.2, -1)]),
    ("forage", 14.0, [("forage berries, nuts and herbs", 0.3, -1)]),
    ("bow", 14.0, [("hunting bow. not sure the aiming feels right yet?", 0.3, -1)]),
    ("hunt", 14.0, [("sneak up on deer, then skin and butcher them", 0.3, -1)]),
    ("camp", 13.0, [("build a fire and cook what you hunted", 0.3, -1)]),
    ("ride", 13.0, [("you can ride horses too", 0.3, -1)]),
    ("rest", 14.0, [("and sleep by the fire through the night", 0.3, -1)]),
]
END = ["that's where it's at right now",
       "what feels off? what would you want to do next?",
       "any feedback helps, I honestly don't know what to work on first"]
END_SMALL = "made in Godot and Blender, with AI help"


def font(size, index):
    try:
        return ImageFont.truetype(SANS, size, index=index)
    except OSError:
        return ImageFont.load_default()


def caption(img, text, alpha):
    """The caption centred near the bottom: white with a dark outline, faded by `alpha`."""
    w, h = img.size
    f = font(int(h * 0.042), DEMI)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    box = d.textbbox((0, 0), text, font=f, stroke_width=4)
    x = (w - (box[2] - box[0])) // 2 - box[0]
    y = int(h * 0.86) - (box[3] - box[1])
    a = int(255 * alpha)
    d.text((x, y), text, font=f, fill=(255, 255, 255, a), stroke_width=4, stroke_fill=(0, 0, 0, int(a * 0.85)))
    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


def find_clip(dirs, clip):
    for d in dirs:
        if os.path.isdir(os.path.join(d, clip, "clean")):
            return os.path.join(d, clip)
    return None


def trim_wav(src, dst, frames):
    with wave.open(src, "rb") as r:
        p = r.getparams()
        n = min(r.getnframes(), int(p.framerate * frames / FPS))
        data = r.readframes(n)
    with wave.open(dst, "wb") as w:
        w.setparams(p)
        w.writeframes(data)


def encode(enc, frames_dir, out, wav):
    subprocess.run([enc, "encode", frames_dir, str(FPS), out, wav], check=True, stdout=subprocess.DEVNULL)


def end_card(out, secs, size):
    w, h = size
    os.makedirs(os.path.join(out, "frames"), exist_ok=True)
    base = Image.new("RGB", (w, h), (12, 12, 12))
    d = ImageDraw.Draw(base)
    rows = [(END[0], font(int(h * 0.05), BOLD), (255, 255, 255), int(h * 0.045))]
    rows += [(t, font(int(h * 0.036), DEMI), (225, 225, 225), int(h * 0.025)) for t in END[1:]]
    rows.append((END_SMALL, font(int(h * 0.024), DEMI), (150, 150, 150), 0))
    hs = []
    for t, f, _, gap in rows:
        b = d.textbbox((0, 0), t, font=f)
        hs.append(b[3] - b[1] + gap)
    y = (h - sum(hs)) // 2
    for (t, f, col, gap), hh in zip(rows, hs):
        b = d.textbbox((0, 0), t, font=f)
        d.text(((w - (b[2] - b[0])) // 2 - b[0], y - b[1]), t, font=f, fill=col)
        y += hh
    n = int(secs * FPS)
    black = Image.new("RGB", (w, h), (0, 0, 0))
    for i in range(n):
        t = i / FPS
        a = max(0.0, min(1.0, t / 0.5, (secs - t) / 0.5))
        Image.blend(black, base, a).save(os.path.join(out, "frames", "f%05d.jpg" % i), quality=93)
    with wave.open(os.path.join(out, "audio.wav"), "wb") as wv:
        wv.setnchannels(2)
        wv.setsampwidth(2)
        wv.setframerate(48000)
        wv.writeframes(b"\0\0\0\0" * int(48000 * n / FPS))


def main():
    dirs = sys.argv[1].split(",")
    out = sys.argv[2]
    scratch = sys.argv[3]
    os.makedirs(scratch, exist_ok=True)
    enc = os.path.join(scratch, "video_encode")
    if not os.access(enc, os.X_OK):
        here = os.path.dirname(os.path.abspath(__file__))
        subprocess.run(["swiftc", "-O", os.path.join(here, "video_encode.swift"), "-o", enc], check=True)
    films = []
    size = (1920, 1080)
    for clip, cap_s, caps in CUT:
        src = find_clip(dirs, clip)
        if src is None:
            print("DEVLOG no frames for %s" % clip)
            continue
        names = sorted(f for f in os.listdir(os.path.join(src, "clean")) if f.endswith(".jpg"))
        names = names[:int(cap_s * FPS)]
        dst = os.path.join(scratch, clip)
        os.makedirs(os.path.join(dst, "frames"), exist_ok=True)
        n = len(names)
        dur = n / FPS
        for i, name in enumerate(names):
            img = Image.open(os.path.join(src, "clean", name)).convert("RGB")
            size = img.size
            t = i / FPS
            # the clip's own fade out at a cut short end (its recorded fade is at its full end)
            tail = min(1.0, (dur - t) / FADE_S)
            for text, a, b in caps:
                b = dur - 0.2 if b < 0 else b
                if a <= t <= b:
                    img = caption(img, text, max(0.0, min(1.0, (t - a) / FADE_S, (b - t) / FADE_S)))
            if tail < 1.0:
                img = Image.blend(Image.new("RGB", img.size, (0, 0, 0)), img, max(0.0, tail))
            img.save(os.path.join(dst, "frames", "f%05d.jpg" % i), quality=93)
        trim_wav(os.path.join(src, "audio.wav"), os.path.join(dst, "audio.wav"), n)
        film = os.path.join(scratch, clip + ".mp4")
        encode(enc, os.path.join(dst, "frames"), film, os.path.join(dst, "audio.wav"))
        films.append(film)
        print("DEVLOG %s %.1f s" % (clip, dur))
    end = os.path.join(scratch, "end")
    end_card(end, 6.5, size)
    encode(enc, os.path.join(end, "frames"), os.path.join(scratch, "end.mp4"), os.path.join(end, "audio.wav"))
    subprocess.run([enc, "join", out] + films + [os.path.join(scratch, "end.mp4")], check=True)


if __name__ == "__main__":
    main()
