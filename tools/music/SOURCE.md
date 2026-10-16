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
`~/Downloads/VSCO-2-CE` (or anywhere, with `VSCO=<folder>`; since 2026-10-16 the copy lives on the external drive at
`/Volumes/The one/VSCO-2-CE`, which orch.py finds on its own when the drive is plugged in), then `python3 tools/music/render.py`. Downloaded
2026-10-03 (3,187 files, sizes checked against the repository's tree). The sampler caches each sample's measured level
in `<VSCO>/.frontier_zone_levels.json`.

Tuning: **A = 432 Hz** (user 2026-10-03; `orch.A4`, `A4=<Hz>` to render at another): every pitched note is played
31.8 cents under the samples' A = 440; the unpitched percussion as recorded.

The piano is VSCO 2 CE's upright, sampled by **Simon Dalzell (Ivy Audio)** and redistributed by Versilian Studios
(its `Info.txt`: credit to both is encouraged). The choir and the music box are synthesized (formant tables of sung
vowels; a steel tine's partials), no samples.

Styles (user 2026-10-03): the giants' music and the land's after Shadow of the Colossus's soundtrack; the night's pieces,
the home's and the story's after Fullmetal Alchemist's (melody first: solo violin, cello, piano, a waltz, a music box).
Again only the manner: the themes are our own.

Drums and bass (user 2026-10-03): VSCO 1's big drums, tenor drums, bass drums, frame drum, congas, bongos, log drum,
tambourine and maracas (all in VSCO 2 CE's repository, CC0), and a synthesized sub bass (`orch.sub`).

The peoples' themes (`cues/peoples.py`, user 2026-10-03: music for each people in the character creator) suggest each
people's music with the orchestra's instruments; the Eastern Woodlands nations' themes are landscapes, not their songs,
and like the Native dress they want those nations' word before they are final.

Tidebreak's ring (round 4, the owner's FEEL list: "Tidebreak's own music"): `cues/ring_fight.py` is the ring's own score,
a festival sport on the water in D major at 132 BPM with its own Tide motif (A D E F# A), split into three stems of one
length and loop (base, drive, peak) that MusicDirector's ring mode lays over each other as a match rises, and the go (its
first downbeat); `cues/ring_stings.py` the stingers (a fall dealt or taken, a last life, sudden death, a game and a match
won or lost, the countdown's bed), each quoting the motif. Rendered like every cue from VSCO 2 CE and the synthesized
choir, A = 432, horns at D4 or under (asserted in the cue code: `ring_fight.check_horns`). The stems' targets are measured
so the three keep the full mix's balance (`python3 tools/music/cues/ring_fight.py --targets`). 37.5 MiB in all.
