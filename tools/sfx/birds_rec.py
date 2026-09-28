#!/usr/bin/env python3
"""Bird calls and songs from public-domain / CC0 recordings (2026-09-26; the owner approved the 14 files).

    python3 tools/sfx/birds_rec.py [--src ~/Downloads/Frontier_assets_staging/pd_bird_sfx]
    python3 tools/sfx/gen_manifest.py

Decodes the staged originals (MP3 with macOS afconvert, Ogg Vorbis with Blender's aud through tools/sfx/cc0_decode.py,
WAV as is; the staging folder's PROVENANCE.md has URLs, sizes, SHA-256 and licences), finds each recording's calls or
song phrases on an energy envelope (50 ms hops; events over the floor merged across short gaps, then grouped into
takes of the species' length), keeps the clearest takes spread over the recording, and writes mono 16-bit clips to
audio/sfx/birds_rec/bird_rec_<species>_NN.wav with short fades, peak-normalised. SOURCE.md and MANIFEST.json list
every take. The files are the project's own cuts; the originals stay in the staging folder.

Night: barred owl, great horned owl, whip-poor-will. Dusk and dawn: wood thrush, veery, hermit thrush. Day: American
robin, red-eyed vireo, black-capped chickadee, blue jay, pileated woodpecker, ruffed grouse drumming, wild turkey,
American crow. AmbienceBed picks them by the sun's height.
"""
import argparse
import hashlib
import json
import os
import subprocess
import wave

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "audio", "sfx", "birds_rec")
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
SR_OGG = 44100
PEAK_DB = -3.0

# id: file, (min s, max s) of a take, merge gap (s), how many takes, threshold (share of floor..peak), lead, tail
SPECIES = {
    "barred_owl": ("owl_barred_nps_weirfarm.mp3", (1.5, 7.0), 0.7, 5, 0.42, 0.25, 0.8),
    "great_horned_owl": ("owl_great_horned_blume.mp3", (1.2, 6.0), 0.6, 5, 0.45, 0.2, 0.8),
    "whip_poor_will": ("whip_poor_will_commons.ogg", (2.5, 5.0), 0.5, 4, 0.4, 0.15, 0.5),
    "wood_thrush": ("wood_thrush_commons.ogg", (1.2, 4.0), 0.45, 7, 0.45, 0.15, 0.7),
    "veery": ("veery_commons.ogg", (1.2, 4.0), 0.45, 5, 0.45, 0.15, 0.7),
    "hermit_thrush": ("hermit_thrush_nps.mp3", (1.2, 4.0), 0.45, 5, 0.45, 0.15, 0.7),
    "robin": ("robin_nps.mp3", (1.5, 5.0), 0.85, 5, 0.4, 0.15, 0.5),     # caroling: short notes, 0.4-0.9 s apart
    "red_eyed_vireo": ("red_eyed_vireo_commons.ogg", (1.5, 4.5), 0.6, 5, 0.42, 0.12, 0.4),
    "chickadee": ("chickadee_commons.wav", (0.6, 3.0), 0.3, 4, 0.4, 0.1, 0.35),
    "blue_jay": ("blue_jay_commons.ogg", (0.25, 2.5), 0.5, 4, 0.35, 0.1, 0.4),  # single jeers, 0.2-0.4 s
    "pileated_woodpecker": ("pileated_woodpecker_commons.ogg", (0.8, 4.0), 0.4, 3, 0.45, 0.1, 0.5),
    "ruffed_grouse": ("ruffed_grouse_nps.mp3", (3.0, 12.0), 1.2, 1, 0.3, 0.3, 1.0),
    "wild_turkey": ("wild_turkey_nps.mp3", (0.6, 3.5), 0.4, 3, 0.5, 0.15, 0.6),
    "crow": ("crow_nps.mp3", (0.8, 4.0), 0.4, 4, 0.45, 0.1, 0.5),
}


def decode_oggs(src: str, cache: str, files: list[str]) -> None:
    rels = ["%s/%s" % (os.path.basename(src), f) for f in files]
    todo = [r for r in rels if not os.path.exists(os.path.join(cache, os.path.basename(src), os.path.splitext(os.path.basename(r))[0] + ".npy"))]
    if todo:
        subprocess.run([BLENDER, "-b", "--python", os.path.join(ROOT, "tools", "sfx", "cc0_decode.py"), "--",
                        os.path.dirname(src), cache] + todo, check=True, capture_output=True)


def load(src: str, cache: str, name: str) -> tuple[np.ndarray, int]:
    path = os.path.join(src, name)
    ext = os.path.splitext(name)[1]
    if ext == ".ogg":
        a = np.load(os.path.join(cache, os.path.basename(src), os.path.splitext(name)[0] + ".npy")).astype(np.float32)
        if a.ndim > 1:
            a = a.mean(1)
        return a, SR_OGG
    wav = path if ext == ".wav" else path[:-4] + ".wav"
    if ext == ".mp3" and not os.path.exists(wav):
        subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16", path, wav], check=True)
    w = wave.open(wav)
    sr, ch, n, sw = w.getframerate(), w.getnchannels(), w.getnframes(), w.getsampwidth()
    raw = w.readframes(n)
    if sw == 2:
        a = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    elif sw == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3)
        a = ((b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (b[:, 2].astype(np.int32) << 16)) << 8 >> 8).astype(np.float32) / 8388608.0
    else:
        a = np.frombuffer(raw, dtype=np.int32).astype(np.float32) / 2147483648.0
    if ch > 1:
        a = a.reshape(-1, ch).mean(1)
    return a, sr


def envelope(a: np.ndarray, sr: int) -> np.ndarray:
    hop = int(sr * 0.05)
    # a gentle high-pass (bird calls sit above wind and traffic rumble): first difference
    d = np.diff(a, prepend=a[:1])
    env = np.sqrt(np.convolve(d * d, np.ones(hop) / hop, "same"))[::hop]
    return 20 * np.log10(env + 1e-7)


def takes(db: np.ndarray, spec: tuple) -> list[tuple[float, float, float]]:
    _, (lo, hi), gap, count, k, _, _ = spec
    floor, peak = np.percentile(db, 25), np.percentile(db, 99.5)
    on = db > floor + k * (peak - floor)
    ev, s = [], None
    for i, v in enumerate(on):
        if v and s is None:
            s = i
        if not v and s is not None:
            ev.append((s * 0.05, i * 0.05))
            s = None
    if s is not None:
        ev.append((s * 0.05, len(on) * 0.05))
    merged = []
    for e in ev:
        if merged and e[0] - merged[-1][1] < gap and e[1] - merged[-1][0] <= hi:
            merged[-1] = (merged[-1][0], e[1])
        else:
            merged.append(e)
    out = []
    for t0, t1 in merged:
        if t1 - t0 < lo:
            continue
        seg = db[int(t0 / 0.05):max(int(t1 / 0.05), int(t0 / 0.05) + 1)]
        out.append((t0, min(t1, t0 + hi), float(np.percentile(seg, 90) - floor)))
    # the clearest, spread over the recording (no two within 1.5 s)
    out.sort(key=lambda x: -x[2])
    pick = []
    for t in out:
        if all(abs(t[0] - p[0]) > 1.5 for p in pick):
            pick.append(t)
        if len(pick) >= count:
            break
    return sorted(pick)


def cut(a: np.ndarray, sr: int, t0: float, t1: float) -> np.ndarray:
    i0, i1 = max(int(t0 * sr), 0), min(int(t1 * sr), len(a))
    x = a[i0:i1].astype(np.float64).copy()
    fi, fo = int(0.02 * sr), int(min(0.25, (t1 - t0) * 0.25) * sr)
    x[:fi] *= np.linspace(0.0, 1.0, fi)
    x[-fo:] *= np.linspace(1.0, 0.0, fo) ** 1.5
    x -= x.mean()
    return x * (10 ** (PEAK_DB / 20.0) / (np.abs(x).max() + 1e-9))


def write(name: str, x: np.ndarray, sr: int) -> None:
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.expanduser("~/Downloads/Frontier_assets_staging/pd_bird_sfx"))
    ap.add_argument("--cache", default=os.path.expanduser("~/Downloads/Frontier_assets_staging/.decode_cache"))
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.startswith("bird_rec_") and f.endswith(".wav"):
            os.remove(os.path.join(OUT, f))
    decode_oggs(args.src, args.cache, [s[0] for s in SPECIES.values() if s[0].endswith(".ogg")])
    all_takes = []
    for sid, spec in SPECIES.items():
        a, sr = load(args.src, args.cache, spec[0])
        chosen = takes(envelope(a, sr), spec)
        lead, tail = spec[5], spec[6]
        for i, (t0, t1, snr) in enumerate(chosen):
            name = "bird_rec_%s_%02d.wav" % (sid, i + 1)
            x = cut(a, sr, t0 - lead, t1 + tail)
            write(name, x, sr)
            all_takes.append({"id": "bird_rec_" + sid, "file": name, "source": spec[0], "from": round(max(t0 - lead, 0), 2),
                              "to": round(t1 + tail, 2), "seconds": round(len(x) / sr, 2), "clarity_db": round(snr, 1)})
        print("%-20s %d takes" % (sid, len(chosen)))
    prov = open(os.path.join(args.src, "PROVENANCE.md")).read()
    manifest = {"note": "The project's own cuts of public-domain / CC0 recordings; the originals and their provenance "
                        "stay in the staging folder (Frontier_assets_staging/pd_bird_sfx/PROVENANCE.md, copied in SOURCE.md).",
                "approved_by_user": "2026-09-26 (\"lets do it\")", "generator": "tools/sfx/birds_rec.py",
                "credit": "National Park Service (NPS files). No claim to original U.S. Government works.", "takes": all_takes}
    with open(os.path.join(OUT, "MANIFEST.json"), "w") as f:
        json.dump(manifest, f, indent=1)
    with open(os.path.join(OUT, "SOURCE.md"), "w") as f:
        f.write("# Bird calls and songs (public domain / CC0)\n\nThe project's own cuts (tools/sfx/birds_rec.py) of the "
                "recordings below, approved by the owner on 2026-09-26. Takes: MANIFEST.json.\n\n" + prov.split("\n", 2)[2])
    print("wrote %d takes to %s" % (len(all_takes), OUT))


if __name__ == "__main__":
    main()
