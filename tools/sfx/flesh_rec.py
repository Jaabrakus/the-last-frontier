#!/usr/bin/env python3
"""Flesh impacts for Frontier (user 2026-09-27: thrown weapons stick in animals): what an arrow, a thrown weapon or a
musket ball sounds like going into an animal (the hit zones' surface "flesh", Sfx.surface_of), built from CC0
recordings (Kenney's Impact Sounds: the soft and punch impacts) the way tools/sfx/gathering_rec.py builds the
gathering sounds.
Usage (from the project root):
  python3 tools/sfx/flesh_rec.py [--seed 3] [--src ~/Downloads/Frontier_assets_staging/cc0_sfx] [--out audio/sfx/impacts]
Then python3 tools/sfx/gen_manifest.py, a Godot import pass, and gen_manifest.py again (see gen_manifest.py).
The takes are decoded by Blender (tools/sfx/cc0_decode.py) into gathering_rec.py's cache; only the layered WAVs are
kept in the project.
  arrow_hit_flesh (4) a blade or a point going into a body: a soft, dull thud (impactSoft_medium, a little lower) with
                  a muffled slap on top (impactPunch_medium, low-passed); arrows and the thrown weapons
  ball_hit_flesh  (4) a musket ball: a heavier punch (impactPunch_heavy, lower) over a deep body thud
                  (impactSoft_heavy) and a short low knock
Every variant of an id is matched in short-term loudness and the id peaks at -1 dBFS; the in-game levels are the
straw hits' (impacts_manifest.json: arrow_hit_flesh -5 dB like arrow_hit_straw, ball_hit_flesh -1 dB like
ball_hit_straw). Output: audio/sfx/impacts/<id>_<NN>.wav, 44.1 kHz 16-bit mono, and audio/sfx/impacts/FLESH_SOURCE.md
(the pack, its licence and the takes each sound uses with their SHA-256).
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dsp  # noqa: E402
import gathering_rec as gr  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
SOFT_M = ["impactSoft_medium_%03d" % i for i in range(5)]
PUNCH_M = ["impactPunch_medium_%03d" % i for i in range(5)]
SOFT_H = ["impactSoft_heavy_%03d" % i for i in range(5)]
PUNCH_H = ["impactPunch_heavy_%03d" % i for i in range(5)]
SOUNDS = {
    "arrow_hit_flesh": {"n": 4, "volume_db": -5.0, "speed_ref": 62.0, "speed_min": 0.25},
    "ball_hit_flesh": {"n": 4, "volume_db": -1.0, "speed_ref": 180.0, "speed_min": 0.3},
}


def arrow_flesh(r: np.random.Generator, v: int) -> np.ndarray:
    soft = gr.repitch(gr.from_onset(gr.S.get(SOFT_M[v % 5]), 0.4), 0.88 + 0.05 * r.random())
    slap = gr.repitch(gr.from_onset(gr.S.get(PUNCH_M[(v + 2) % 5]), 0.25), 0.82 + 0.05 * r.random())
    slap = gr.band(slap, hi=3200.0)
    return gr.finish(gr.mix(0.45, (gr.norm(soft), 0.0, 1.0), (gr.norm(slap), 0.004, 0.42)))


def ball_flesh(r: np.random.Generator, v: int) -> np.ndarray:
    punch = gr.band(gr.repitch(gr.from_onset(gr.S.get(PUNCH_H[v % 5]), 0.3), 0.8 + 0.05 * r.random()), hi=4200.0)
    body = gr.repitch(gr.from_onset(gr.S.get(SOFT_H[(v + 1) % 5]), 0.45), 0.85)
    knock = dsp.damped_sine(0.14, 72.0 + 10.0 * r.random(), 0.05)
    return gr.finish(gr.mix(0.5, (gr.norm(punch), 0.0, 1.0), (gr.norm(body), 0.003, 0.7), (gr.norm(knock), 0.0, 0.35)))


BUILD = {"arrow_hit_flesh": arrow_flesh, "ball_hit_flesh": ball_flesh}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=3)
    ap.add_argument("--src", default=os.path.expanduser("~/Downloads/Frontier_assets_staging/cc0_sfx"))
    ap.add_argument("--cache", default=gr.CACHE)
    ap.add_argument("--blender", default=gr.BLENDER)
    ap.add_argument("--out", default=os.path.join(ROOT, "audio", "sfx", "impacts"))
    a = ap.parse_args()
    gr.S = gr.Sources(a.src, a.cache, a.blender)
    gr.S.prefetch(SOFT_M + PUNCH_M + SOFT_H + PUNCH_H)
    os.makedirs(a.out, exist_ok=True)
    made = {}
    for sid, cfg in SOUNDS.items():
        gr.S.current = sid
        r = np.random.default_rng(a.seed * 1009 + len(sid))
        takes = [BUILD[sid](r, v) for v in range(int(cfg["n"]))]
        # the variants matched in short-term loudness, the id peaking at -1 dBFS
        lo = [gr.st_loudness(x) for x in takes]
        ref = min(lo)
        takes = [x * dsp.db2lin(ref - l) for x, l in zip(takes, lo)]
        pk = max(float(np.max(np.abs(x))) for x in takes)
        files = []
        for i, x in enumerate(takes):
            path = os.path.join(a.out, "%s_%02d.wav" % (sid, i + 1))
            dsp.write_wav(path, x * (dsp.db2lin(-1.0) / pk), seed=a.seed + i)
            files.append(os.path.relpath(path, ROOT))
        made[sid] = files
        print("%s: %d variants" % (sid, len(files)))
    # the levels in the impacts family manifest (read by gen_manifest.py)
    mp = os.path.join(a.out, "impacts_manifest.json")
    man = json.load(open(mp))
    for sid, cfg in SOUNDS.items():
        base = dict(man["sounds"].get("arrow_hit_straw" if sid.startswith("arrow") else "ball_hit_straw", {}))
        base.update({"volume_db": cfg["volume_db"], "speed_ref": cfg["speed_ref"], "speed_min": cfg["speed_min"],
                     "files": ["res://" + f for f in made[sid]]})
        man["sounds"][sid] = base
    with open(mp, "w") as fh:
        json.dump(man, fh, indent=1)
        fh.write("\n")
    # provenance
    pk_info = gr.PACKS["kenney_impact-sounds"]
    lines = ["# Flesh impacts: sources", "",
             "Built by `tools/sfx/flesh_rec.py` (seed %d) from real recordings in **%s** by %s (%s), licensed %s. "
             "The pack stays where it was unpacked (`~/Downloads/Frontier_assets_staging/cc0_sfx/`); only the layered "
             "WAVs are in the project. Credited in CREDITS.md with the pack." % (a.seed, pk_info["title"],
                                                                                 pk_info["author"], pk_info["url"], gr.LICENSE), ""]
    for sid in SOUNDS:
        lines.append("## %s" % sid)
        lines.append("")
        lines.append("Files: " + ", ".join("`%s`" % os.path.basename(f) for f in made[sid]))
        lines.append("")
        for t in sorted(gr.S.used.get(sid, [])):
            lines.append("- `%s` sha256 %s" % (gr._take_path(t), gr.S.sha256(t)))
        lines.append("")
    with open(os.path.join(a.out, "FLESH_SOURCE.md"), "w") as fh:
        fh.write("\n".join(lines))
    print("wrote", os.path.join(a.out, "FLESH_SOURCE.md"))


if __name__ == "__main__":
    main()
