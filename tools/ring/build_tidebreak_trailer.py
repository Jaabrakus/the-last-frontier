#!/usr/bin/env python3
"""Build a frame-exact Tidebreak trailer from captured gameplay and title layers.

Run with the local watermark Python runtime (numpy, imageio-ffmpeg). The edit
document names each take, element, source start and duration in seconds. Cuts
retain one captured frame per output frame and its corresponding audio samples.
The output directory and MP4 must be new. Original captures remain unchanged.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import wave

import imageio_ffmpeg
import numpy as np


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def read_wave(path):
    with wave.open(str(path)) as w:
        assert (w.getnchannels(), w.getframerate()) == (2, 48000), path
        width = w.getsampwidth()
        raw = w.readframes(w.getnframes())
        if width == 2:
            samples = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768
        elif width == 3:
            b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
            signed = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
            signed = (signed ^ 0x800000) - 0x800000
            samples = signed.astype(np.float32) / 8388608
        else:
            raise ValueError(f"Expected PCM16 or PCM24: {path}")
        return samples.reshape(-1, 2)


def write_wave(path, data):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(48000)
        w.writeframes(np.rint(np.clip(data, -1, 32767 / 32768) * 32768).astype("<i2").tobytes())


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--edit", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()
    assert not args.out.exists(), "Use a new edit directory"
    assert not args.output.exists(), "Refusing an existing MP4"
    edit = json.loads(args.edit.read_text())
    fps, rate = 60, 48000
    assert edit["fps"] == fps and edit["duration_s"] == 60
    frames = args.out / "frames"
    frames.mkdir(parents=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    count, cuts, mapping, sounds = 0, [], [], []
    taken = set()
    take_cache = {}
    for cut in edit["cuts"]:
        take = Path(cut["take"]).resolve()
        if take not in take_cache:
            rows = []
            for line in (take / "frames.txt").read_text().splitlines():
                if line and not line.startswith("#"):
                    i, engine, element, t = line.split()
                    rows.append((int(i), int(engine), element, round(float(t) * fps)))
            take_cache[take] = (rows, read_wave(take / "audio.wav"))
        rows, sound = take_cache[take]
        first, length = round(cut["start_s"] * fps), round(cut["duration_s"] * fps)
        chosen = [r for r in rows if r[2] == cut["element"] and first <= r[3] < first + length]
        assert len(chosen) == length, f"Insufficient frames: {cut}, got {len(chosen)}"
        assert all(b[1] == a[1] + 1 and b[3] == a[3] + 1 for a, b in zip(chosen, chosen[1:])), "Non-continuous source cut"
        excerpt = np.empty((length * rate // fps, 2), dtype=np.float32)
        for local, row in enumerate(chosen):
            key = (str(take), row[0])
            assert key not in taken, "No duplicated gameplay frames"
            taken.add(key)
            source = take / "frames" / f"f{row[0]:05d}.jpg"
            os.link(source, frames / f"f{count:05d}.jpg")
            audio_first = row[0] * rate // fps
            block = sound[audio_first:audio_first + rate // fps]
            assert len(block) == rate // fps, "Missing synchronized audio samples"
            excerpt[local * rate // fps:(local + 1) * rate // fps] = block
            mapping.append(f"{count},{take},{row[0]},{row[1]},{row[2]},{row[3]}")
            count += 1
        # Tiny de-click envelopes do not alter timing or silence the action.
        ramp = min(480, len(excerpt) // 2)
        excerpt[:ramp] *= np.linspace(0, 1, ramp, dtype=np.float32)[:, None]
        excerpt[-ramp:] *= np.linspace(1, 0, ramp, dtype=np.float32)[:, None]
        sounds.append(excerpt)
        cuts.append({**cut, "output_start_s": (count - length) / fps, "output_end_s": count / fps,
                     "first_source_frame": chosen[0][0], "last_source_frame": chosen[-1][0]})
    assert count == 3600, f"Expected 60 seconds, got {count / fps}"
    sfx = np.concatenate(sounds)
    score_path = Path(edit["score"])
    score = read_wave(score_path)
    assert len(score) == len(sfx) == 60 * rate
    # Leave game transients above the score; no time stretching or hard limiter.
    mixed = sfx * 10 ** (edit.get("sfx_gain_db", -3) / 20) + score * 10 ** (edit.get("score_gain_db", 0) / 20)
    accent_hash = None
    if edit.get("accents"):
        accent_path = Path(edit["accents"])
        accents = read_wave(accent_path)
        assert len(accents) == len(mixed)
        mixed += accents * 10 ** (edit.get("accent_gain_db", 0) / 20)
        accent_hash = digest(accent_path)
    intro = int(0.25 * rate)
    outro = int(1.2 * rate)
    mixed[:intro] *= np.linspace(0, 1, intro, dtype=np.float32)[:, None]
    mixed[-outro:] *= np.linspace(1, 0, outro, dtype=np.float32)[:, None]
    before_peak = float(np.max(np.abs(mixed)))
    gain = min(1.0, 10 ** (-1.5 / 20) / max(before_peak, 1e-9))
    mixed *= gain
    write_wave(args.out / "mix.wav", mixed)
    write_wave(args.out / "game_sfx.wav", sfx)
    audio = {"rate": rate, "channels": 2, "samples": len(mixed), "duration_s": len(mixed) / rate,
             "peak_dbfs": float(20 * np.log10(np.max(np.abs(mixed)) + 1e-12)),
             "rms_dbfs": float(20 * np.log10(np.sqrt(np.mean(mixed ** 2)) + 1e-12)),
             "clipped_samples": int(np.count_nonzero(np.abs(mixed) >= 1)),
             "master_attenuation_db": float(20 * np.log10(gain)),
             "sfx_gain_db": edit.get("sfx_gain_db", -3), "score_gain_db": edit.get("score_gain_db", 0)}
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    cmd = [ff, "-hide_banner", "-nostdin", "-n", "-filter_complex_threads", "2",
           "-framerate", "60", "-i", str(frames / "f%05d.jpg"), "-i", str(args.out / "mix.wav")]
    filters = ["[0:v]format=yuv420p,setsar=1[base]"]
    previous = "base"
    for n, title in enumerate(edit["titles"]):
        path = Path(title["file"]).resolve()
        cmd += ["-loop", "1", "-framerate", "60", "-i", str(path)]
        start, end, fade = title["start_s"], title["end_s"], title.get("fade_s", 0.4)
        assert 0 <= start < end <= 60 and 2 * fade < end - start
        layer, dest = f"title{n}", f"stage{n}"
        filters.append(f"[{n+2}:v]format=rgba,fade=t=in:st={start}:d={fade}:alpha=1,fade=t=out:st={end-fade}:d={fade}:alpha=1[{layer}]")
        filters.append(f"[{previous}][{layer}]overlay=0:0:shortest=1:enable='between(t,{start},{end})'[{dest}]")
        previous = dest
    # Normal-rate live footage under every title, including the end card.
    filters.append(f"[{previous}]fade=t=in:st=0:d=0.2,fade=t=out:st=59.7:d=0.3,format=yuv420p[video]")
    graph = args.out / "filters.txt"
    graph.write_text(";\n".join(filters) + "\n")
    cmd += ["-filter_complex_script", str(graph), "-map", "[video]", "-map", "1:a:0",
            "-c:v", "libx264", "-preset", "fast", "-crf", str(edit.get("crf", 18)),
            "-threads", "4", "-r", "60", "-fps_mode", "cfr", "-frames:v", "3600", "-t", "60",
            "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-movflags", "+faststart",
            "-metadata", "title=Tidebreak — Gameplay Trailer", "-metadata", "comment=Early playable demo. Recorded in game; automated controls. Edited at normal speed.",
            str(args.output)]
    (args.out / "encode_command.json").write_text(json.dumps(cmd, indent=2) + "\n")
    (args.out / "frame_map.csv").write_text("output_frame,take,source_frame,engine_frame,element,element_frame\n" + "\n".join(mapping) + "\n")
    manifest = {"schema": "tidebreak-trailer-edit/v1", "fps": fps, "frames": count, "duration_s": 60,
                "cuts": cuts, "titles": edit["titles"], "audio": audio, "source_frames_reused": False,
                "speed_changes": False, "gameplay_input": "automated normal controls; no forced damage or results",
                "source_map": str((args.out / "frame_map.csv").resolve()), "score_sha256": digest(score_path),
                "accent_sha256": accent_hash,
                "builder_sha256": digest(__file__), "status": "encoding"}
    record = args.out / "manifest.json"
    record.write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"frames": count, "cuts": cuts, "audio": audio}), flush=True)
    with (args.out / "encode.log").open("w") as log:
        subprocess.run(cmd, check=True, stdout=log, stderr=subprocess.STDOUT)
    manifest.update(status="encoded", output=str(args.output.resolve()), output_sha256=digest(args.output), bytes=args.output.stat().st_size)
    record.write_text(json.dumps(manifest, indent=2) + "\n")
    print("Encoded " + str(args.output), flush=True)


if __name__ == "__main__":
    main()
