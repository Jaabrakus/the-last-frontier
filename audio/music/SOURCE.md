# audio/music

Rendered by `tools/music/render.py` from the cues in `tools/music/cues/` (composed for this game, 2026-10-03), played
on **VSCO 2: Community Edition** samples by **Versilian Studios (Sam Gossner)**, CC0 1.0
(<https://versilian-studios.com/vsco-community/>; the piano Simon Dalzell's, Ivy Audio), with a synthesized choir and
music box. Tuned to A = 432 Hz. See `tools/music/SOURCE.md`.

| file | what | where it plays |
|---|---|---|
| `main_theme.wav` | "Frontier", the main theme (D dorian, 66 BPM) | the main menu |
| `explore_day.wav` | open country: flute, oboe, harp | now and then by day |
| `explore_dusk.wav` | long shadows: a lone horn in B minor | now and then at dusk and dawn |
| `explore_night.wav` | embers: clarinet, far flute, glockenspiel | now and then at night |
| `giant_battle.wav` | a giant's fight (D minor, 144 BPM): 2 bars of intro, then a 32-bar loop (smpl chunk) | a mammoth turns on the player |
| `giant_upper_hand.wav` (not rendered since the 2026-10-06 cleanup: `python3 tools/music/render.py giant_upper_hand`) | the theme turned heroic (D major, 144 BPM), a 32-bar loop | a knee buckles, or the player is on it |
| `giant_lament.wav` (not rendered since the 2026-10-06 cleanup: `python3 tools/music/render.py giant_lament`) | the lament (D minor, 54 BPM) | the giant dies |
| `night_waltz.wav` | "Hearth", the family theme as a waltz: piano, solo violin, cellos (E minor, 3/4) | at night; at home at dusk and night |
| `lullaby.wav` | a music box's tune, the piano, the harp (G major, 3/4), winding down | at night; by the sleeping baby |
| `night_elegy.wav` | the cellos' song over the piano, a violin's lift, the choir (B minor) | at night |
| `story_wonder.wav` (not rendered since the 2026-10-06 cleanup: `python3 tools/music/render.py story_wonder`) | the sky galleons: the choir's rising motif, the whole orchestra (C Lydian) | *Two Fires*: "Look up at the broken sky" |
| `story_sorrow.wav` | the Frontier theme on a solo violin over the piano (D minor) | *Ash*: the farms burned |
| `story_home.wav` | the family theme for orchestra, ending in E major | *A House and a Home*: the roof on |
| `loc_fort.wav` (not rendered since the 2026-10-06 cleanup: `python3 tools/music/render.py loc_fort`) | the settlers' hymn and a fife-and-drum tune (G major) | the fort |
| `loc_farms.wav` | a Palatine country dance (Laendler): fiddle, clarinet, plucked strings (A major) | the farms and the mill |
| `loc_river.wav` | the harp rippling, a flute in F Lydian | the ford, the lake shore |
| `loc_woods.wav` | a low drone, a clarinet, a far horn and its echo (E dorian) | deep woods, old woods, the ridge |
| `loc_cliffs.wav` | horn calls and echoes on open fifths, a broad tune (A mixolydian) | the cliffs |
| `loc_marsh.wav` | a bassoon, odd plucks, trembling violas (F-sharp minor) | the marsh |
| `loc_wreck.wav` (not rendered since the 2026-10-06 cleanup: `python3 tools/music/render.py loc_wreck`) | the wonder's motif hushed on a solo violin (C Lydian) | the wreck's pine grove (story) |
| `people_<id>.wav` (3: vietnamese, thai, malay; the other 32 retired 2026-10-06) | each people's theme (tools/music/cues/peoples.py): its mode or maqam, metre, lead and drums, a 16-bar loop | the character creator, while that people is chosen |

`scripts/audio/music_director.gd` decides what plays; `scripts/audio/music_manifest.gd` (generated) holds each cue's
tempo, length and loop.
