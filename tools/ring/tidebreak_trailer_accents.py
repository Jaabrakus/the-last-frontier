#!/usr/bin/env python3
"""Optional two-KO music accents; does not read or alter the base score audio.

Only mix this stem if the chosen edit places earned KOs at 37.0 and 52.0 s.
Procedural drum + brief D bass, no samples/speech. Exactly 60 s / 48 kHz stereo
PCM24. Each event is at most 1.2 s long, with stem peak normalized to -10 dBFS.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np

import tidebreak_trailer_score as score

SR = 48_000
TIMES = (37.0, 52.0)
TAIL_S = 1.2
SEED = 202610073752
OUT = score.ROOT / "artifacts/tidebreak_trailer_60/audio"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / ".gdignore").touch()
    base = OUT / "score.wav"
    before = sha(base) if base.exists() else None
    r = np.random.default_rng(SEED)
    y = np.zeros((60*SR, 2), np.float32)
    n = round(TAIL_S*SR)
    for at in TIMES:
        drum = score.INST.drum(SR, r, 155, 59, .035, .34,
                               .24, 75, 1150, .046, TAIL_S)
        bass = score.INST.sub(SR, 36.708, TAIL_S, .25)
        mono = np.asarray(.78*drum + .22*bass, np.float32)
        # Taper the whole voice; silence outside its declared interval is exact.
        fade = round(.22*SR)
        mono[-fade:] *= np.cos(np.linspace(0, np.pi/2, fade, dtype=np.float32))**2
        mono[0] = mono[-1] = 0
        # Keep this low impact centered; the music already supplies stereo width.
        start = round(at*SR)
        y[start:start+n, 0] += mono
        y[start:start+n, 1] += mono
    y *= np.float32(10**(-10/20)/np.max(np.abs(y)))
    score.write_pcm24(OUT / "ko_accents.wav", y)
    del y
    decoded, header = score.read_pcm24(OUT / "ko_accents.wav")
    peak = 20*np.log10(np.max(np.abs(decoded)))
    # Independent decoded-WAV placement test: only these two windows have sound.
    allowed = np.zeros(len(decoded), dtype=bool)
    events = []
    for at in TIMES:
        start = round(at*SR)
        allowed[start:start+n] = True
        active = np.flatnonzero(np.any(decoded[start:start+n] != 0, axis=1))
        events.append({"cue_s": at, "declared_duration_s": TAIL_S,
                       "first_nonzero_s": (start+int(active[0]))/SR,
                       "last_nonzero_s": (start+int(active[-1]))/SR,
                       "peak_dbfs": float(20*np.log10(np.max(np.abs(decoded[start:start+n]))))})
    bins = np.any(decoded.reshape(6000, 480, 2) != 0, axis=(1,2))
    regions = int(np.sum(bins & ~np.r_[False, bins[:-1]]))
    checks = {
        "exact_60s_48k_stereo_pcm24": header == {
            "sample_rate": 48000, "channels": 2, "sample_width_bytes": 3, "frames": 2880000},
        "two_audible_regions": regions == 2,
        "only_requested_windows_nonzero": bool(np.all(decoded[~allowed] == 0)),
        "all_tails_under_1_3s": all(e["last_nonzero_s"]-e["cue_s"] <= 1.3 for e in events),
        "stem_peak_below_minus9_dbfs": bool(peak <= -9),
        "title_at54_clear": bool(np.all(decoded[round(54*SR):] == 0)),
        "base_score_unchanged": (sha(base) if base.exists() else None) == before,
    }
    report = {
        "schema": "tidebreak-ko-accents/v1", "seed": SEED,
        "usage": "Optional music accents only when the final edit selects earned KOs at 37 and 52 seconds. Final music/SFX balance belongs to editor.",
        "duration_s": 60, "header": header, "peak_dbfs": float(peak),
        "events": events, "audible_regions_at10ms": regions,
        "checks": checks, "passed": sum(checks.values()), "total": len(checks),
        "score_sha256_unchanged": before, "accent_sha256": sha(OUT/"ko_accents.wav"),
        "source_sha256": sha(Path(__file__)),
        "source_dependencies": [{"path": str(p.relative_to(score.ROOT)), "sha256": sha(p)}
                                for p in [Path(score.__file__), score.SOURCE, score.ROOT/"tools/sfx/dsp.py"]],
        "subjective_listen_performed": False,
    }
    (OUT/"ko_accents_verification.json").write_text(json.dumps(report, indent=2)+"\n")
    assert all(checks.values()), checks
    print(json.dumps({"checks_passed": report["passed"], "total": report["total"],
                      "peak_dbfs": report["peak_dbfs"], "events": events}, indent=2))


if __name__ == "__main__":
    main()
