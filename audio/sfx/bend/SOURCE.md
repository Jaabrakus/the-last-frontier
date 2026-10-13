# The ring's sounds (Tidebreak)

Every file here is synthesized by `tools/sfx/bend/bend_sfx.py` (numpy on `tools/sfx/dsp.py`: filtered noise, struck
modes, bubbles, a formant-filtered buzz for the crowd's voices). Nothing is recorded, sampled or downloaded, and nothing
is taken from any show or game. Made 2026-10-05 (improvement round 1); rerun the script to make them again (the same
files for the same `--seed`).

- `<id>_<NN>.wav`: 44.1 kHz 16-bit mono, 2-4 variants an id; `crowd_murmur_*` are 12 s loops (RIFF `smpl` chunk).
- `levels.json`: each file's loudness (the loudest 100 ms, K-weighted, dB), peak (dBFS), the limiter's deepest cut and
  its length.
- Played by `scripts/bending/bend_sounds.gd` (BendSounds: the table of levels, 3D ranges and jitter).
- Round 2 (2026-10-05, CORE; `tools/sfx/bend/guards.py`, synthesized the same way): each element's guard on the beat and
  late (`guard_<element>_clean`, `guard_<element>_late`; earth's late catch keeps `stone_catch`), the grow's second click
  (`lock_grow`), the sputter on the hands (`lock_sputter`) and Carried wind's whistle (`carried_whistle`).
