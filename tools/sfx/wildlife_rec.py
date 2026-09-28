#!/usr/bin/env python3
"""Wildlife calls from public-domain recordings (2026-09-26; the owner approved the three files).

    python3 tools/sfx/wildlife_rec.py [--src ~/Downloads/Frontier_assets_staging/pd_wildlife_sfx]
    python3 tools/sfx/gen_manifest.py

Reads the staged originals (MP3 decoded to WAV with macOS afconvert; the staging folder's PROVENANCE.md has the
URLs, sizes and SHA-256) and writes audio/sfx/wildlife_rec/:

    wild_rec_wolf_chorus_NN.wav   a wolf pack howling (USFWS "Wolves howl", 28 s cut in three overlapping takes)
    wild_rec_fox_call_NN.wav      red fox barks / yowls (NPS Yellowstone, Shan Burson)
    wild_rec_raven_call_NN.wav    common raven croaks (NPS Yellowstone, David Restivo)

Mono 16-bit at the source rate, each take cut at its event (energy envelope, 50 ms hops, merged over gaps < 0.35 s)
with a lead-in and a tail, short fades, peak-normalised to PEAK_DB. The files are the project's own cuts of the
recordings; the originals stay in the staging folder. SOURCE.md and MANIFEST.json list every take.

Licence: the recordings are works of the U.S. Government (National Park Service; U.S. Fish and Wildlife Service),
public domain. NPS asks for credit ("National Park Service"); "No claim to original U.S. Government works."
"""
import argparse
import hashlib
import json
import os
import subprocess
import wave

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "audio", "sfx", "wildlife_rec")
PEAK_DB = -3.0

SOURCES = {
    "usfws_wolf_howls": {
        "title": "Wolves howl (11 wolf howls)", "author": "U.S. Fish and Wildlife Service",
        "page": "https://archive.org/details/WolvesHowl_571",
        "url": "https://archive.org/download/WolvesHowl_571/11wolfhowls.mp3",
        "licence": "Public domain (U.S. Government work; the archive.org record: public domain, may be used without prior permission)",
    },
    "nps_yell_red_fox": {
        "title": "Red fox (Yellowstone sound library)", "author": "National Park Service / Shan Burson",
        "page": "https://www.nps.gov/yell/learn/photosmultimedia/sounds-redfox.htm",
        "url": "https://www.nps.gov/nps-audiovideo/legacy/mp3/imr/avElement/yell-YELLMJ23200837redfox.mp3",
        "licence": "Public domain (recorded in the park; NPS: may be used without limitation, please credit the National Park Service)",
    },
    "nps_yell_raven": {
        "title": "Common raven (Yellowstone sound library)", "author": "National Park Service / David Restivo",
        "page": "https://www.nps.gov/yell/learn/photosmultimedia/sounds-raven.htm",
        "url": "https://www.nps.gov/nps-audiovideo/legacy/mp3/imr/avElement/yell-RavenBlackSandBasin.mp3",
        "licence": "Public domain (recorded in the park; NPS: may be used without limitation, please credit the National Park Service)",
    },
}


def load(path: str) -> tuple[np.ndarray, int]:
    wav = path[:-4] + ".wav"
    if not os.path.exists(wav):
        subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16", path, wav], check=True)
    w = wave.open(wav)
    sr, ch, n = w.getframerate(), w.getnchannels(), w.getnframes()
    a = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float32) / 32768.0
    if ch > 1:
        a = a.reshape(-1, ch).mean(1)
    return a, sr


def events(a: np.ndarray, sr: int, k: float = 0.45) -> list[tuple[float, float]]:
    hop = int(sr * 0.05)
    env = np.sqrt(np.convolve(a * a, np.ones(hop) / hop, "same"))[::hop]
    db = 20 * np.log10(env + 1e-6)
    floor, peak = np.percentile(db, 20), db.max()
    on = db > floor + k * (peak - floor)
    segs, s = [], None
    for i, v in enumerate(on):
        if v and s is None:
            s = i
        if not v and s is not None:
            if i - s >= 3:
                segs.append((s * 0.05, i * 0.05))
            s = None
    if s is not None:
        segs.append((s * 0.05, len(on) * 0.05))
    merged = []
    for x in segs:
        if merged and x[0] - merged[-1][1] < 0.35:
            merged[-1] = (merged[-1][0], x[1])
        else:
            merged.append(x)
    return merged


def cut(a: np.ndarray, sr: int, t0: float, t1: float, fade_in: float, fade_out: float) -> np.ndarray:
    i0, i1 = max(int(t0 * sr), 0), min(int(t1 * sr), len(a))
    x = a[i0:i1].copy()
    fi, fo = int(fade_in * sr), int(fade_out * sr)
    if fi > 0:
        x[:fi] *= np.linspace(0.0, 1.0, fi)
    if fo > 0:
        x[-fo:] *= np.linspace(1.0, 0.0, fo) ** 1.5
    x -= x.mean()
    peak = np.abs(x).max() + 1e-9
    return x * (10 ** (PEAK_DB / 20.0) / peak)


def write(name: str, x: np.ndarray, sr: int) -> dict:
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    return {"file": name, "seconds": round(len(x) / sr, 2)}


def sha(path: str) -> str:
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.expanduser("~/Downloads/Frontier_assets_staging/pd_wildlife_sfx"))
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    takes = []
    # wolves: one continuous chorus; three long takes with slow fades (a pack heard across the valley)
    a, sr = load(os.path.join(args.src, "usfws_wolf_howls.mp3"))
    dur = len(a) / sr
    for i, (t0, t1) in enumerate([(0.0, 10.5), (8.5, 19.5), (17.5, dur)]):
        takes.append({"id": "wild_rec_wolf_chorus", "source": "usfws_wolf_howls", "from": t0, "to": round(t1, 2),
                      **write("wild_rec_wolf_chorus_%02d.wav" % (i + 1), cut(a, sr, t0, t1, 0.6, 1.4), sr)})
    # fox and raven: one take per call, a short lead-in and a tail
    for key, sid, lead, tail in [("nps_yell_red_fox", "wild_rec_fox_call", 0.12, 0.45),
                                 ("nps_yell_raven", "wild_rec_raven_call", 0.08, 0.35)]:
        a, sr = load(os.path.join(args.src, key + ".mp3"))
        n = 0
        for t0, t1 in events(a, sr):
            n += 1
            takes.append({"id": sid, "source": key, "from": round(max(t0 - lead, 0.0), 2), "to": round(t1 + tail, 2),
                          **write("%s_%02d.wav" % (sid, n), cut(a, sr, t0 - lead, t1 + tail, 0.01, 0.12), sr)})
    src = {}
    for key, meta in SOURCES.items():
        mp3 = os.path.join(args.src, key + ".mp3")
        src[key] = {**meta, "bytes": os.path.getsize(mp3), "sha256": sha(mp3)}
    manifest = {
        "note": "The project's own cuts of public-domain recordings (U.S. Government works); the originals stay in "
                "the staging folder (Frontier_assets_staging/pd_wildlife_sfx, PROVENANCE.md).",
        "approved_by_user": "2026-09-26 (\"lets use the public domain sounds\")",
        "generator": "tools/sfx/wildlife_rec.py",
        "credit": "National Park Service; U.S. Fish and Wildlife Service. No claim to original U.S. Government works.",
        "sources": src, "takes": takes,
    }
    with open(os.path.join(OUT, "MANIFEST.json"), "w") as f:
        json.dump(manifest, f, indent=1)
    lines = ["# Wildlife calls (public domain)", "",
             "The project's own cuts (tools/sfx/wildlife_rec.py) of three public-domain recordings, approved by the owner "
             "on 2026-09-26. Credit: National Park Service; U.S. Fish and Wildlife Service. No claim to original U.S. "
             "Government works.", "", "| Source | Author | Page | File | Bytes | SHA-256 | Licence |", "| --- | --- | --- | --- | --- | --- | --- |"]
    for key, m in src.items():
        lines.append("| %s | %s | %s | %s | %d | %s | %s |" % (m["title"], m["author"], m["page"], m["url"], m["bytes"], m["sha256"], m["licence"]))
    lines += ["", "Takes: MANIFEST.json (source, seconds from / to)."]
    with open(os.path.join(OUT, "SOURCE.md"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote %d takes to %s" % (len(takes), OUT))


if __name__ == "__main__":
    main()
