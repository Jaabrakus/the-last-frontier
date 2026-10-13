#!/usr/bin/env python3
"""Synthesize Tidebreak's original 60-second trailer arrangement.

No recordings, external music, speech, or downloaded instruments. Reuses only
the procedural instrument functions in tools/showcase/trailer_score.py and DSP
in tools/sfx/dsp.py; the old score/arrangement is not called or modified.

  services/watermark/.runtime/bin/python tools/ring/tidebreak_trailer_score.py

120 BPM / 4-4 / D-minor pentatonic melody. Output is 48 kHz stereo PCM24 with
linear normalization to -6 dBFS, no master compressor/limiter. This is a music
stem: gameplay sounds and the final mix are handled by the trailer editor.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import time
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/showcase/trailer_score.py"
SPEC = importlib.util.spec_from_file_location("tidebreak_procedural_instruments", SOURCE)
INST = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(INST)

SR = 48_000
SECONDS = 60
BPM = 120
BEAT = 0.5
BAR = 2.0
SEED = 2026100760
SECTIONS = [
    ("Brand / atmosphere", 0, 4),
    ("Four elements / build", 4, 18),
    ("Rising combat", 18, 32),
    ("Drum climax", 32, 54),
    ("Title / decay", 54, 60),
]
CHORDS = {
    "Dm": (38, [50, 57, 62, 65, 69], [62, 69, 74, 77]),
    "Bb": (34, [46, 53, 58, 62, 65], [62, 65, 69, 74]),
    "F": (41, [53, 57, 60, 65, 69], [60, 65, 69, 72]),
    "C": (36, [48, 55, 60, 64, 67], [60, 67, 72, 74]),
}
# Thirty two-second bars. D/A drones and a pentatonic flute keep one identity
# across distinct elemental beats, with chord color below the melodic line.
PROGRESSION = [
    "Dm", "Dm", "Dm", "Dm", "Bb", "Bb", "F", "C", "Dm",
    "Dm", "Bb", "F", "C", "Dm", "Bb", "C",
    "Dm", "Dm", "Bb", "Bb", "F", "C", "Dm", "Dm", "Bb", "C", "Dm",
    "Dm", "Dm", "Dm",
]


class Bus:
    """Float32 stereo buses; short reusable voices keep memory bounded."""

    def __init__(self):
        self.dry = np.zeros((SECONDS * SR, 2), np.float32)
        self.send = np.zeros_like(self.dry)
        self.events = []

    def add(self, at, signal, gain, pan=0.0, room=0.12, name="voice", note=None):
        start = round(at * SR)
        sig = np.asarray(signal, np.float32)
        stop = min(start + len(sig), len(self.dry))
        if start < 0 or stop <= start:
            raise ValueError("Event outside score")
        angle = (float(pan) + 1) * math.pi / 4
        gains = (math.cos(angle), math.sin(angle))
        for c, g in enumerate(gains):
            voice = sig[:stop-start] * np.float32(gain * g)
            self.dry[start:stop, c] += voice
            self.send[start:stop, c] += voice * np.float32(room)
        self.events.append({"time_s": round(at, 6), "voice": name, "midi": note,
                            "gain": gain, "pan": pan})

    def finish(self):
        # Sparse stereo room: no full-minute FFT or full-length float64 bus.
        # Short reflections retain drum attacks and leave space for live SFX.
        taps = [(0.037, .24), (.061, .21), (.103, .17), (.149, .14),
                (.211, .115), (.293, .095), (.397, .077), (.521, .06),
                (.677, .045), (.839, .031), (1.021, .020), (1.219, .012)]
        for i, (delay, level) in enumerate(taps):
            for c in range(2):
                offset = round((delay + c * .007) * SR)
                self.dry[offset:, c] += self.send[:-offset, (c+i) % 2] * np.float32(level)
        del self.send
        y = self.dry
        # DC removal and endpoint fades are linear; there is no brickwall stage.
        for c in range(2):
            y[:, c] -= np.float32(np.mean(y[:, c], dtype=np.float64))
        ni = round(.04 * SR)
        y[:ni] *= np.sin(np.linspace(0, math.pi/2, ni, dtype=np.float32))[:, None] ** 2
        # Musical voices ring after 54 s, then a gentle last-two-second fade.
        nf = 2 * SR
        y[-nf:] *= np.cos(np.linspace(0, math.pi/2, nf, dtype=np.float32))[:, None] ** 2
        y[0] = 0
        y[-1] = 0
        raw_peak = float(np.max(np.abs(y)))
        scale = 10 ** (-6/20) / raw_peak
        y *= np.float32(scale)
        return y, {"pre_normalization_peak": raw_peak, "linear_master_gain": scale,
                   "peak_target_dbfs": -6, "compression": "none", "limiter": "none",
                   "bus_dtype": "float32", "room": "12 short stereo reflection taps"}


def render():
    r = np.random.default_rng(SEED)
    bus = Bus()
    # Cache short pitched voices instead of synthesizing every pluck anew.
    cache = {}

    def voice(kind, note=None, duration=None):
        key = kind, note, duration
        if key not in cache:
            if kind == "pluck":
                sig = INST.dulcimer(note, SR, r, dur=duration or 1.0)
            elif kind == "bass":
                sig = INST.bass_pluck(note, SR, r, dur=duration or 1.2)
            else:
                fn = {"frame": INST.frame_drum, "taiko": INST.taiko,
                      "shaker": INST.shaker, "snare": INST.snare,
                      "wood": INST.tick}.get(kind)
                sig = fn(SR, r) if fn else INST.tom(SR, r, note)
            cache[key] = np.asarray(sig, np.float32)
        return cache[key]

    def add(at, kind, gain, pan=0.0, room=.12, note=None, duration=None):
        bus.add(at, voice(kind, note, duration), gain, pan, room, kind, note)

    def flute(at, note, dur, gain=.15, pan=-.14):
        bus.add(at, INST.flute(note, dur, SR, r), gain, pan, .32, "flute", note)

    # An original short pentatonic motif, not an imported tune or old score.
    # Every flute pitch belongs to D F G A C, with higher variants at the peak.
    def motif(at, octave=0, gain=.15):
        for offset, note, dur in [(0, 74, .65), (.75, 69, .35), (1.25, 72, .35),
                                  (1.75, 74, .85), (2.75, 77, .35), (3.25, 74, .55)]:
            flute(at+offset, note+octave, dur, gain)

    # 0–4 s: a breath of D/A, one low strike, and the recognizable flute call.
    bus.add(0, INST.pad([38, 45, 50], 3.5, SR, r, bright=420, attack=.65, release=1.3),
            .24, 0, .32, "intro_pad")
    add(.0, "frame", .28, room=.25)
    add(.5, "pluck", .13, -.25, .35, 74, 1.4)
    flute(.75, 74, .65, .13)
    flute(1.75, 69, .45, .12)
    flute(2.5, 72, .65, .12)
    bus.add(2.8, INST.riser(SR, r, 1.2), .095, 0, .08, "intro_swell")

    # Pads are short and quiet: a harmonic bed, with no wall of sustained bass.
    for bar in range(2, 27):
        root, harmony, plucks = CHORDS[PROGRESSION[bar]]
        gain = .105 if bar < 9 else (.13 if bar < 16 else .16)
        bus.add(bar*BAR, INST.pad(harmony, 1.85, SR, r, bright=900 if bar < 16 else 1300,
                                  attack=.28, release=.5), gain, .04, .22, "chord_pad")
        # Eighth-note plucks become more emphatic as combat expands.
        density = 4 if bar < 4 else 8
        pattern = [0, 1, 2, 1, 3, 1, 2, 1]
        for k in range(density):
            at = bar*BAR + k * (BAR/density)
            tone = plucks[pattern[k]]
            amount = (.095 if bar < 9 else .125 if bar < 16 else .145)
            amount *= (1.0 if k % 2 == 0 else .67)
            add(at, "pluck", amount, -.24 if k % 2 == 0 else .24, .18, tone)
        # A low pluck every half bar gives the score a clear pulse.
        add(bar*BAR, "bass", .24 if bar < 9 else .32, 0, .05, root)
        add(bar*BAR+1.25, "bass", .17 if bar < 9 else .23, 0, .05, root, .7)

        if bar < 9:
            add(bar*BAR, "frame", .44, room=.12)
            add(bar*BAR+1, "frame", .32, room=.12)
            if bar >= 4:
                for k in range(8):
                    add(bar*BAR+k*.25, "shaker", .05 if k%2 else .07, .3, .06)
            if bar >= 6:
                add(bar*BAR+1.75, "tom", .22, -.28, .12, 125)
        elif bar < 16:
            add(bar*BAR, "taiko", .49, room=.13)
            add(bar*BAR+1, "frame", .38, room=.1)
            add(bar*BAR+.75, "tom", .23, -.25, .1, 100)
            add(bar*BAR+1.5, "tom", .25, .25, .1, 135)
            for k in range(8):
                add(bar*BAR+k*.25, "shaker", .06 if k%2 else .09, .28, .05)
            add(bar*BAR+.5, "snare", .14, -.08, .12)
            add(bar*BAR+1.5, "snare", .18, -.08, .12)
        else:
            # Big drums with room between the attacks for gameplay impacts.
            add(bar*BAR, "taiko", .78, room=.16)
            add(bar*BAR+1, "taiko", .52, room=.14)
            add(bar*BAR+.5, "snare", .28, -.07, .1)
            add(bar*BAR+1.5, "snare", .34, -.07, .1)
            for offset, f, g, pan in [(.75, 100, .30, -.32), (1.25, 150, .22, .32),
                                      (1.75, 120, .34, -.2)]:
                add(bar*BAR+offset, "tom", g, pan, .11, f)
            for k in range(8):
                add(bar*BAR+k*.25, "shaker", .075 if k%2 else .115, .3, .05)
            if bar in (16, 20, 24):
                bus.add(bar*BAR, INST.crash(SR, r, 1.8), .105, .15, .2, "cymbal")
                bus.add(bar*BAR, INST.sub(SR, 38, 1.3, .5), .18, 0, .02, "sub_accent")

    motif(6, gain=.125)
    motif(14, gain=.14)
    motif(20, gain=.14)
    # Answer phrase rises into the drum reveal; retain gaps for action sounds.
    for at, note, dur in [(26, 77, .65), (27, 79, .65), (28, 81, 1.15), (29.5, 84, .7)]:
        flute(at, note, dur, .16)
    bus.add(28, INST.riser(SR, r, 3.75), .13, 0, .07, "climax_swell")
    for k in range(8):
        add(31+k*.125, "tom", .10+k*.018, -.3+k*.6/7, .08, [100, 125, 150][k%3])
    motif(34, gain=.17)
    motif(42, gain=.19)
    for at, note, dur in [(48, 81, .65), (49, 84, .65), (50, 86, 1.15),
                          (51.5, 84, .45), (52.25, 81, .55)]:
        flute(at, note, dur, .20)
    # A short final fill lands exactly on the title at 54.000 s.
    for k in range(6):
        add(53.25+k*.125, "tom", .20+k*.018, -.25+k*.1, .1, [150, 125, 100][k%3])
    add(54, "taiko", .90, room=.28)
    add(54.008, "frame", .48, .14, .22)
    bus.add(54, INST.sub(SR, 36.708, 2.6, .85), .30, 0, .04, "title_sub")
    bus.add(54, INST.crash(SR, r, 2.8), .12, .14, .25, "title_cymbal")
    bus.add(54, INST.pad([38, 50, 57, 62, 65, 74], 2.5, SR, r, bright=950,
                         attack=.04, release=3.0), .27, 0, .32, "title_chord")
    add(54.25, "pluck", .20, -.2, .32, 74, 1.6)
    flute(54.5, 77, .6, .145)
    flute(55.25, 74, 1.8, .135)
    add(56.0, "pluck", .09, .2, .35, 69, 1.6)
    y, mastering = bus.finish()
    assert y.shape == (2_880_000, 2) and np.isfinite(y).all()
    return y, bus.events, mastering


def write_pcm24(path, y):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(3)
        w.setframerate(SR)
        for start in range(0, len(y), SR):
            v = np.rint(y[start:start+SR]*8388607).astype(np.int32).reshape(-1)
            raw = np.empty((len(v), 3), np.uint8)
            raw[:, 0] = v & 255
            raw[:, 1] = (v >> 8) & 255
            raw[:, 2] = (v >> 16) & 255
            w.writeframesraw(raw.tobytes())


def read_pcm24(path):
    with wave.open(str(path), "rb") as w:
        spec = {"sample_rate": w.getframerate(), "channels": w.getnchannels(),
                "sample_width_bytes": w.getsampwidth(), "frames": w.getnframes()}
        assert spec == {"sample_rate": SR, "channels": 2, "sample_width_bytes": 3, "frames": SR*SECONDS}
        b = np.frombuffer(w.readframes(w.getnframes()), np.uint8).reshape(-1, 3)
        v = b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32)<<8) | (b[:, 2].astype(np.int32)<<16)
        v = (v ^ 0x800000)-0x800000
        y = v.astype(np.float32).reshape(-1, 2) / np.float32(8388608)
    return y, spec


def db(v):
    return 20 * math.log10(max(float(v), 1e-12))


def analyze(y, spec):
    peak = float(np.max(np.abs(y)))
    rms = math.sqrt(float(np.mean(y*y, dtype=np.float64)))
    blocks = y.reshape(120, SR//2, 2)
    block_rms = np.sqrt(np.mean(blocks*blocks, axis=(1, 2), dtype=np.float64))
    stats = {
        **spec, "duration_s": len(y)/SR, "sample_peak_dbfs": db(peak),
        "rms_dbfs": db(rms), "crest_factor_db": db(peak/rms),
        "nonfinite_samples": int((~np.isfinite(y)).sum()),
        "samples_at_or_above_full_scale": int((np.abs(y)>=1).sum()),
        "first_frame": y[0].tolist(), "last_frame": y[-1].tolist(),
        "channel_dc": np.mean(y, axis=0, dtype=np.float64).tolist(),
        "stereo_correlation": float(np.corrcoef(y[::48].T)[0, 1]),
        "half_second_rms_dbfs": [db(v) for v in block_rms],
        "sections": [], "subjective_listen_performed": False,
        "measurement_scope": "Decoded PCM24 WAV: sample peaks/RMS, not LUFS or oversampled true peak",
    }
    for title, start, stop in SECTIONS:
        part = y[start*SR:stop*SR]
        stats["sections"].append({"name": title, "start_s": start, "end_s": stop,
            "peak_dbfs": db(np.max(np.abs(part))),
            "rms_dbfs": db(np.sqrt(np.mean(part*part, dtype=np.float64)))})
    assert abs(stats["sample_peak_dbfs"]+6)<.001
    assert stats["samples_at_or_above_full_scale"] == 0
    assert stats["nonfinite_samples"] == 0
    return stats


def waveform(path, y, stats):
    """Standalone SVG envelope/RMS plot, no plotting-package dependency."""
    width, height, left, right, top = 1440, 570, 86, 1405, 100
    span = right-left
    rows = []
    rows.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">')
    rows.append('<rect width="100%" height="100%" fill="#111827"/>')
    rows.append('<g font-family="Arial, sans-serif" fill="#e5e7eb">')
    rows.append('<text x="40" y="36" font-size="23">TIDEBREAK — original synthesized score</text>')
    rows.append(f'<text x="40" y="64" font-size="15">60.000 s · 48 kHz stereo PCM24 · 120 BPM · peak {stats["sample_peak_dbfs"]:.2f} dBFS · RMS {stats["rms_dbfs"]:.2f} dBFS · no limiter</text>')
    palette = ["#304554", "#294f55", "#454c67", "#66533c", "#334957"]
    for i, (label, start, stop) in enumerate(SECTIONS):
        x, w = left+start/60*span, (stop-start)/60*span
        rows.append(f'<rect x="{x}" y="82" width="{w}" height="450" fill="{palette[i]}" opacity="0.42"/>')
        rows.append(f'<text x="{x+5}" y="97" font-size="11">{label.split(" / ")[0]}</text>')
    for sec in range(0, 61, 2):
        x = left+sec/60*span
        rows.append(f'<path d="M{x},100 V532" stroke="#9ca3af" stroke-opacity="{.35 if sec%10==0 else .12}"/>')
        if sec%10 == 0:
            rows.append(f'<text x="{x}" y="550" text-anchor="middle" font-size="12">{sec}s</text>')
    count = 1200
    frames = y.reshape(count, len(y)//count, 2)
    lows, highs = frames.min(axis=1), frames.max(axis=1)
    for c, center in enumerate((190, 355)):
        rows.append(f'<text x="30" y="{center+4}" font-size="14">{"Left" if c==0 else "Right"}</text>')
        rows.append(f'<path d="M{left},{center} H{right}" stroke="#64748b"/>')
        upper = [f'{left+i/(count-1)*span:.2f},{center-highs[i,c]*140:.2f}' for i in range(count)]
        lower = [f'{left+i/(count-1)*span:.2f},{center-lows[i,c]*140:.2f}' for i in reversed(range(count))]
        rows.append(f'<polygon points="{" ".join(upper+lower)}" fill="#57d5ca" opacity=".87"/>')
    rows.append('<text x="25" y="480" font-size="13">RMS</text>')
    points = []
    for i, value in enumerate(stats["half_second_rms_dbfs"]):
        points.append(f'{left+(i+.5)/120*span:.2f},{525-(max(value,-60)+60)/60*90:.2f}')
    rows.append(f'<polyline points="{" ".join(points)}" fill="none" stroke="#f2bf72" stroke-width="2"/>')
    rows.append('</g></svg>')
    path.write_text("\n".join(rows)+"\n")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ROOT/"artifacts/tidebreak_trailer_60/audio")
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    (out/".gdignore").touch()
    started = time.monotonic()
    y, events, mastering = render()
    write_pcm24(out/"score.wav", y)
    del y
    decoded, spec = read_pcm24(out/"score.wav")
    stats = analyze(decoded, spec)
    stats["render_and_decode_wall_s"] = round(time.monotonic()-started, 3)
    stats["score_sha256"] = digest(out/"score.wav")
    waveform(out/"waveform.svg", decoded, stats)
    (out/"analysis.json").write_text(json.dumps(stats, indent=2)+"\n")
    manifest = {
        "schema": "tidebreak-score/v1", "duration_s": 60, "bpm": BPM,
        "meter": "4/4", "beat_s": BEAT, "bar_s": BAR, "seed": SEED,
        "melody_scale": "D minor pentatonic (D F G A C)",
        "sources": [{"path": str(p.relative_to(ROOT)), "sha256": digest(p)}
                    for p in [Path(__file__), SOURCE, ROOT/"tools/sfx/dsp.py"]],
        "composition_scope": "New procedural arrangement; reusable repo instruments; no recordings, external music, downloaded samples or speech.",
        "score_sha256": stats["score_sha256"], "mastering": mastering,
        "sections": stats["sections"], "event_count": len(events),
        "events": sorted(events, key=lambda e: e["time_s"]),
        "review_scope": "Numerical/decoded-WAV validation only; not a claimed subjective listen or provenance audit of unrelated project assets.",
    }
    (out/"manifest.json").write_text(json.dumps(manifest, indent=2)+"\n")
    (out/"README.md").write_text(
        "# Tidebreak 60-second score\n\n"
        "`score.wav` is an original procedural instrumental arrangement: 60.000 seconds, "
        "48 kHz stereo PCM24, 120 BPM, D-minor pentatonic flute, plucked strings, pads and drums. "
        "It uses no recordings, external music, downloads or speech. It reuses the repository's "
        "instrument functions; the prior score was neither rendered nor modified.\n\n"
        "Cues: 0–4 s atmospheric brand introduction; 4–18 s elemental build; 18–32 s rising combat; "
        "32–54 s big drum climax; 54–60 s title hit and decay. Beats are every 0.5 s; bars every 2 s.\n\n"
        f"Decoded sample peak: **{stats['sample_peak_dbfs']:.2f} dBFS**. RMS: **{stats['rms_dbfs']:.2f} dBFS**. "
        f"Crest factor: **{stats['crest_factor_db']:.2f} dB**. No clipping/nonfinite samples; both endpoints "
        "are zero. Only a linear master gain and endpoint fades are used; no master limiter/compressor. "
        "These are sample measurements, not LUFS or an oversampled true-peak claim.\n\n"
        "`waveform.svg` shows both channels and half-second RMS. `analysis.json` contains decoded-WAV "
        "measurements; `manifest.json` records hashes, seed, cues and every note/strike. No subjective "
        "listening claim is made. The trailer editor owns the final music/SFX balance and peak ceiling.\n\n"
        "Reproduce from workspace root:\n\n"
        "```sh\nservices/watermark/.runtime/bin/python tools/ring/tidebreak_trailer_score.py\n```\n"
    )
    print(json.dumps({k:stats[k] for k in ["duration_s", "sample_rate", "channels", "sample_peak_dbfs", "rms_dbfs", "crest_factor_db", "render_and_decode_wall_s", "score_sha256"]}, indent=2))


if __name__ == "__main__":
    main()
