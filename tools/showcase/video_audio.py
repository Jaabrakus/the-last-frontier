#!/usr/bin/env python3
"""The tour video's sound: cuts the recorded frames' audio out of the movie writer's AVI.

    python3 tools/environment/tour_video_audio.py <out>/tour_raw.avi <out>/frames.txt <out>/tour_audio.wav \
        [--offset N]

tools/environment/tour_video.gd saves only the recorded frames as JPEGs (each shot's warm-up frames are not in the
video), but Godot's movie writer (--write-movie <file>.avi, MJPEG + PCM) writes every engine frame, each with its
own block of sound. frames.txt lists, for every saved frame, the engine frame it was rendered in; this takes that
frame's audio block from the AVI (AVI frame = engine frame + 1 + offset: measured with Godot 4.7.2 by matching the
AVI's pictures, which mirror the saved frames, to the JPEGs; --offset corrects it should another version differ) and
joins them into a WAV that runs frame for frame with the JPEGs. Where the recording skips (a cut between shots) the
sound fades out over FADE_OUT_S and back in over FADE_IN_S, so a cut does not click. The level is raised so the
loudest peak reaches PEAK_DBFS (at most MAX_GAIN_DB; --no-gain keeps the game's mix level).

Standard library only. Prints the AVI's audio format, the frames used and the offset.
"""
import argparse
import array
import math
import struct
import sys
import wave

FADE_OUT_S = 0.12
FADE_IN_S = 0.35
PEAK_DBFS = -1.0
MAX_GAIN_DB = 9.0


def read_avi(path):
    """Returns (wave format dict, [audio bytes per video frame]) from a Godot MJPEG AVI."""
    with open(path, "rb") as f:
        data = f.read()
    if data[0:4] != b"RIFF" or data[8:12] != b"AVI ":
        raise SystemExit("not an AVI: %s" % path)
    fmt = None
    frames = []            # audio bytes that follow each video chunk
    pending_audio = []

    def walk(start, end, in_movi):
        nonlocal fmt
        pos = start
        stream_type = None
        while pos + 8 <= end:
            cid = data[pos:pos + 4]
            size = struct.unpack("<I", data[pos + 4:pos + 8])[0]
            body = pos + 8
            if cid in (b"RIFF", b"LIST"):
                kind = data[body:body + 4]
                walk(body + 4, body + size, in_movi or kind == b"movi")
            elif cid == b"strh":
                stream_type = data[body:body + 4]
            elif cid == b"strf" and stream_type == b"auds":
                tag, ch, rate, _bps, align, bits = struct.unpack("<HHIIHH", data[body:body + 16])
                fmt = {"tag": tag, "channels": ch, "rate": rate, "align": align, "bits": bits}
            elif in_movi and cid[2:4] in (b"dc", b"db"):
                frames.append(bytearray())
            elif in_movi and cid[2:4] == b"wb":
                if frames:
                    frames[-1] += data[body:body + size]
                else:
                    pending_audio.append(data[body:body + size])
            pos = body + size + (size & 1)

    walk(12, len(data), False)
    if fmt is None:
        raise SystemExit("no audio stream in %s" % path)
    if pending_audio and frames:
        frames[0] = bytearray(b"".join(pending_audio)) + frames[0]
    return fmt, frames


def read_log(path):
    rows = []
    with open(path) as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            parts = line.split()
            rows.append((int(parts[0]), int(parts[1]), parts[2]))
    return rows


def fade(samples, channels, start, count, fade_in):
    """Linear fade over `count` sample frames starting at frame `start` (int16 interleaved, in place)."""
    for i in range(count):
        g = (i + 1) / count if fade_in else 1.0 - (i + 1) / count
        for c in range(channels):
            k = (start + i) * channels + c
            if 0 <= k < len(samples):
                samples[k] = int(samples[k] * g)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("avi")
    ap.add_argument("frames_txt")
    ap.add_argument("out_wav")
    ap.add_argument("--offset", type=int, default=0,
                    help="AVI frame = engine frame + 1 + offset (default 0)")
    ap.add_argument("--no-gain", action="store_true", help="keep the game's level (default: peaks to -1 dBFS)")
    a = ap.parse_args()
    fmt, blocks = read_avi(a.avi)
    if fmt["tag"] != 1 or fmt["bits"] != 16:
        raise SystemExit("expected 16-bit PCM audio, got %s" % fmt)
    rows = read_log(a.frames_txt)
    ch = fmt["channels"]
    print("AVI: %d frames, audio %d Hz x %d ch, %d bytes per frame" % (
        len(blocks), fmt["rate"], ch, len(blocks[1]) if len(blocks) > 1 else 0))
    out = array.array("h")
    prev = None
    missing = 0
    fade_ins = []          # sample frames where the sound comes back after a cut
    for _frame, engine, _shot in rows:
        i = engine + 1 + a.offset
        if 0 <= i < len(blocks):
            block = array.array("h", bytes(blocks[i]))
            if sys.byteorder != "little":
                block.byteswap()
        else:
            missing += 1
            block = array.array("h", bytes(len(blocks[1]) if len(blocks) > 1 else 0))
        if prev is not None and engine != prev + 1:
            n_out = int(FADE_OUT_S * fmt["rate"])
            fade(out, ch, len(out) // ch - n_out, n_out, False)
            fade_ins.append(len(out) // ch)
        out.extend(block)
        prev = engine
    for start in fade_ins:
        fade(out, ch, start, int(FADE_IN_S * fmt["rate"]), True)
    first = rows[0][1] if rows else 0
    fade(out, ch, 0, int(0.5 * fmt["rate"]), True)          # the video fades in from black
    n_end = int(1.0 * fmt["rate"])
    fade(out, ch, len(out) // ch - n_end, n_end, False)      # ... and out at the end
    # level: peaks to PEAK_DBFS, at most MAX_GAIN_DB louder than the game's own mix
    peak = max((abs(v) for v in out), default=0)
    gain = 1.0
    if peak > 0 and not a.no_gain:
        gain = min(10 ** (PEAK_DBFS / 20.0) * 32767.0 / peak, 10 ** (MAX_GAIN_DB / 20.0))
        for k in range(len(out)):
            out[k] = max(-32768, min(32767, int(out[k] * gain)))
    if sys.byteorder != "little":
        out.byteswap()
    with wave.open(a.out_wav, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(fmt["rate"])
        w.writeframes(out.tobytes())
    secs = len(out) / ch / fmt["rate"]
    print("WAV: %s, %.2f s from %d video frames (first engine frame %d, %d cuts, %d missing blocks, offset %d, "
          "gain %+.1f dB)" % (a.out_wav, secs, len(rows), first, len(fade_ins), missing, a.offset,
                              20.0 * math.log10(gain)))

if __name__ == "__main__":
    main()
