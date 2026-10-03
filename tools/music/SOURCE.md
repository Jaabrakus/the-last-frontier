# The music's tools and samples

The game's music (`audio/music/`) is written as code here and rendered by `render.py` (user 2026-10-03: a soundtrack
"like" Shadow of the Colossus's — its manner: a quiet land, an orchestra and choir for the giants. Every theme,
harmony and arrangement is our own; nothing is taken from that soundtrack.)

- `cues/*.py` — the cues: the notes, chords and orchestration (`_lib.py` holds the Frontier theme they share)
- `orch.py` — the sampler, the hall (a synthetic impulse response) and the master; `choir.py` — the synthesized choir
- `render.py` — renders the cues into `audio/music/` and writes `scripts/audio/music_manifest.gd`
- `levels.py`, `look.py` — checks without ears: each instrument's level by section; a loudness plot and spectrogram

## Samples: VSCO 2 Community Edition

The orchestra's recorded instruments are **VSCO 2: Community Edition** by **Versilian Studios (Sam Gossner)**,
<https://versilian-studios.com/vsco-community/>, source <https://github.com/sgossner/VSCO-2-CE>. Licence: **CC0 1.0
Universal** (the repository's `LICENSE`). Its readme asks for credit to Versilian Studios / Sam Gossner and a link to
the homepage, and that the samples themselves not be sold; we ship only the rendered music, not the samples.

The samples (3 GB) are not in this repository. To render, download the repository's files into
`~/Downloads/VSCO-2-CE` (or anywhere, with `VSCO=<folder>`), then `python3 tools/music/render.py`. Downloaded
2026-10-03 (3,187 files, sizes checked against the repository's tree). The sampler caches each sample's measured level
in `<VSCO>/.frontier_zone_levels.json`.

The piano is VSCO 2 CE's upright, sampled by **Simon Dalzell (Ivy Audio)** and redistributed by Versilian Studios
(its `Info.txt`: credit to both is encouraged). The choir and the music box are synthesized (formant tables of sung
vowels; a steel tine's partials), no samples.

Styles (user 2026-10-03): the giants' music and the land's after Shadow of the Colossus's soundtrack; the night's pieces,
the home's and the story's after Fullmetal Alchemist's (melody first: solo violin, cello, piano, a waltz, a music box).
Again only the manner: the themes are our own.
